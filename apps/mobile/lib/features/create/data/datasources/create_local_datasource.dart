import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/create_draft_model.dart';

enum CreateConditionalSaveStatus { saved, conflict, invalidExistingData }

enum CreateCollectionConditionalSaveStatus {
  saved,
  replayed,
  conflict,
  invalidDraft,
  invalidExistingData,
}

class CreateConditionalSaveResult {
  const CreateConditionalSaveResult({
    required this.status,
    this.persistedRevision,
  });

  final CreateConditionalSaveStatus status;
  final int? persistedRevision;
}

class CreateCollectionConditionalSaveResult {
  const CreateCollectionConditionalSaveResult({
    required this.status,
    this.persistedRevision,
  });

  final CreateCollectionConditionalSaveStatus status;
  final int? persistedRevision;
}

class CreateLocalDataSource {
  CreateLocalDataSource(
    this._storage, {
    required this.activeCurrency,
    this.activeMarketCityId = '',
    this.activeTimezone = 'UTC',
    this.activeCountry = '',
    this.activeCity = '',
  });

  final FlutterSecureStorage _storage;
  final String activeCurrency;
  final String activeMarketCityId;
  final String activeTimezone;
  final String activeCountry;
  final String activeCity;
  final Map<String, Future<void>> _conditionalSaveQueues =
      <String, Future<void>>{};

  String _draftKey(String userId) => 'create_draft_$userId';

  static const int _collectionSchemaVersion = 1;
  static const int _maxReceiptsPerOwner = 100;

  String _safeKeyPart(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');

  String _collectionPrefix(String ownerId) =>
      'create_draft_collection_v1_${_safeKeyPart(ownerId)}_';

  String _collectionIndexKey(String ownerId) =>
      '${_collectionPrefix(ownerId)}index';

  String _collectionDraftKey(String ownerId, String draftId) =>
      '${_collectionPrefix(ownerId)}draft_${_safeKeyPart(draftId)}';

  String _collectionStageKey(String ownerId, String draftId) =>
      '${_collectionPrefix(ownerId)}stage_${_safeKeyPart(draftId)}';

  Future<CreateDraftModel?> loadDraft(String userId) async {
    try {
      return await _loadDraftStrict(userId);
    } on Object {
      return null;
    }
  }

  Future<CreateDraftModel?> _loadDraftStrict(String userId) async {
    final String? raw = await _storage.read(key: _draftKey(userId));
    if (raw == null || raw.isEmpty) return null;
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    return CreateDraftModel.fromJson(
      json,
      activeCurrency: activeCurrency,
      activeMarketCityId: activeMarketCityId,
      activeTimezone: activeTimezone,
      activeCountry: activeCountry,
      activeCity: activeCity,
    );
  }

  Future<void> saveDraft(String userId, CreateDraftModel model) async {
    if (model.objectType == 'scenario' && model.organizerId == userId) {
      await _saveCollectionUnconditional(ownerId: userId, model: model);
    }
    await _storage.write(
      key: _draftKey(userId),
      value: jsonEncode(model.toJson()),
    );
  }

  Future<List<CreateDraftModel>> listCollectionDrafts({
    required String ownerId,
    required String objectType,
  }) async {
    if (!_validNamespacePart(ownerId)) return const <CreateDraftModel>[];
    await _migrateLegacyScenario(ownerId);
    final index = await _recoverCollectionIndex(ownerId);
    final valid = <CreateDraftModel>[];
    var changed = false;
    for (final entry in Map<String, Object?>.from(index.entries).entries) {
      final draftId = entry.key;
      CreateDraftModel? model;
      try {
        model = await _loadCollectionDraftStrict(ownerId, draftId);
        model?.toEntity();
      } on Object {
        changed = true;
        index.entries.remove(draftId);
        continue;
      }
      if (model == null ||
          model.id != draftId ||
          model.organizerId != ownerId) {
        changed = true;
        index.entries.remove(draftId);
        continue;
      }
      if (model.objectType == objectType) valid.add(model);
    }
    valid.sort((a, b) => b.updatedAtUtcIso.compareTo(a.updatedAtUtcIso));
    if (changed) await _writeCollectionIndex(ownerId, index);
    return List<CreateDraftModel>.unmodifiable(valid);
  }

  Future<CreateDraftModel?> loadCollectionDraft({
    required String ownerId,
    required String draftId,
  }) async {
    if (!_validNamespacePart(ownerId) || !_validNamespacePart(draftId)) {
      return null;
    }
    await _migrateLegacyScenario(ownerId);
    try {
      final model = await _loadCollectionDraftStrict(ownerId, draftId);
      model?.toEntity();
      if (model == null ||
          model.id != draftId ||
          model.organizerId != ownerId) {
        return null;
      }
      return model;
    } on Object {
      return null;
    }
  }

  Future<CreateCollectionConditionalSaveResult> saveCollectionDraftIfCurrent({
    required String ownerId,
    required CreateDraftModel model,
    required int expectedScenarioRevision,
    required String idempotencyKey,
  }) {
    if (!_validNamespacePart(ownerId) ||
        !_validNamespacePart(model.id) ||
        !_validNamespacePart(idempotencyKey) ||
        model.organizerId != ownerId ||
        model.objectType != 'scenario' ||
        model.scenarioRevision == null ||
        model.scenarioRevision! != expectedScenarioRevision + 1) {
      return Future<CreateCollectionConditionalSaveResult>.value(
        const CreateCollectionConditionalSaveResult(
          status: CreateCollectionConditionalSaveStatus.invalidDraft,
        ),
      );
    }
    final queueKey = _collectionDraftKey(ownerId, model.id);
    final completer = Completer<CreateCollectionConditionalSaveResult>();
    final previous = _conditionalSaveQueues[queueKey] ?? Future<void>.value();
    late final Future<void> operation;
    operation = previous
        .catchError((Object _) {})
        .then((_) async {
          await _migrateLegacyScenario(ownerId);
          _CollectionIndex index;
          try {
            index = await _recoverCollectionIndex(ownerId);
          } on Object {
            completer.complete(
              const CreateCollectionConditionalSaveResult(
                status:
                    CreateCollectionConditionalSaveStatus.invalidExistingData,
              ),
            );
            return;
          }
          final receipt = index.receipts[idempotencyKey];
          if (receipt != null) {
            if (receipt.draftId != model.id) {
              completer.complete(
                const CreateCollectionConditionalSaveResult(
                  status: CreateCollectionConditionalSaveStatus.invalidDraft,
                ),
              );
              return;
            }
            await _deleteStageBestEffort(ownerId, model.id);
            completer.complete(
              CreateCollectionConditionalSaveResult(
                status: CreateCollectionConditionalSaveStatus.replayed,
                persistedRevision: receipt.revision,
              ),
            );
            return;
          }

          CreateDraftModel? current;
          _CollectionStage? stage;
          try {
            current = await _loadCollectionDraftStrict(ownerId, model.id);
            current?.toEntity();
            stage = await _readCollectionStage(ownerId, model.id);
          } on Object {
            completer.complete(
              const CreateCollectionConditionalSaveResult(
                status:
                    CreateCollectionConditionalSaveStatus.invalidExistingData,
              ),
            );
            return;
          }
          final currentRevision = current?.scenarioRevision;
          final requestedPayload = jsonEncode(model.toJson());
          if (stage != null &&
              (stage.idempotencyKey != idempotencyKey ||
                  stage.draftId != model.id ||
                  stage.expectedRevision != expectedScenarioRevision ||
                  stage.nextRevision != model.scenarioRevision ||
                  stage.payloadJson != requestedPayload)) {
            completer.complete(
              CreateCollectionConditionalSaveResult(
                status:
                    CreateCollectionConditionalSaveStatus.invalidExistingData,
                persistedRevision: currentRevision,
              ),
            );
            return;
          }
          if (current != null &&
              (current.id != model.id ||
                  current.organizerId != ownerId ||
                  current.objectType != 'scenario')) {
            completer.complete(
              const CreateCollectionConditionalSaveResult(
                status:
                    CreateCollectionConditionalSaveStatus.invalidExistingData,
              ),
            );
            return;
          }
          if (stage != null && currentRevision == model.scenarioRevision) {
            if (current == null ||
                jsonEncode(current.toJson()) != stage.payloadJson) {
              completer.complete(
                CreateCollectionConditionalSaveResult(
                  status:
                      CreateCollectionConditionalSaveStatus.invalidExistingData,
                  persistedRevision: currentRevision,
                ),
              );
              return;
            }
            index.entries[model.id] = _CollectionIndexEntry.fromModel(current);
            index.receipts[idempotencyKey] = _CollectionReceipt(
              draftId: model.id,
              revision: model.scenarioRevision!,
            );
            _trimReceipts(index);
            await _writeCollectionIndex(ownerId, index);
            await _deleteStageBestEffort(ownerId, model.id);
            completer.complete(
              CreateCollectionConditionalSaveResult(
                status: CreateCollectionConditionalSaveStatus.replayed,
                persistedRevision: model.scenarioRevision,
              ),
            );
            return;
          }
          if (current != null && currentRevision != expectedScenarioRevision) {
            completer.complete(
              CreateCollectionConditionalSaveResult(
                status: CreateCollectionConditionalSaveStatus.conflict,
                persistedRevision: currentRevision,
              ),
            );
            return;
          }

          final nextStage =
              stage ??
              _CollectionStage(
                idempotencyKey: idempotencyKey,
                draftId: model.id,
                expectedRevision: expectedScenarioRevision,
                nextRevision: model.scenarioRevision!,
                payloadJson: requestedPayload,
              );
          await _writeAndVerifyCollectionStage(ownerId, nextStage);
          await _writeAndVerifyCollectionDraft(ownerId, model);
          index.entries[model.id] = _CollectionIndexEntry.fromModel(model);
          index.receipts[idempotencyKey] = _CollectionReceipt(
            draftId: model.id,
            revision: model.scenarioRevision!,
          );
          _trimReceipts(index);
          await _writeCollectionIndex(ownerId, index);
          await _deleteStageBestEffort(ownerId, model.id);
          completer.complete(
            CreateCollectionConditionalSaveResult(
              status: CreateCollectionConditionalSaveStatus.saved,
              persistedRevision: model.scenarioRevision,
            ),
          );
        })
        .catchError((Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        })
        .whenComplete(() {
          if (identical(_conditionalSaveQueues[queueKey], operation)) {
            _conditionalSaveQueues.remove(queueKey);
          }
        });
    _conditionalSaveQueues[queueKey] = operation;
    return completer.future;
  }

  Future<void> _saveCollectionUnconditional({
    required String ownerId,
    required CreateDraftModel model,
  }) async {
    if (!_validNamespacePart(ownerId) ||
        !_validNamespacePart(model.id) ||
        model.organizerId != ownerId) {
      return;
    }
    final index = await _recoverCollectionIndex(ownerId);
    await _writeAndVerifyCollectionDraft(ownerId, model);
    index.entries[model.id] = _CollectionIndexEntry.fromModel(model);
    await _writeCollectionIndex(ownerId, index);
  }

  Future<void> _migrateLegacyScenario(String ownerId) async {
    CreateDraftModel? legacy;
    try {
      legacy = await _loadDraftStrict(ownerId);
      legacy?.toEntity();
    } on Object {
      return;
    }
    if (legacy == null ||
        legacy.objectType != 'scenario' ||
        legacy.organizerId != ownerId ||
        !_validNamespacePart(legacy.id)) {
      return;
    }
    CreateDraftModel? existing;
    try {
      existing = await _loadCollectionDraftStrict(ownerId, legacy.id);
    } on Object {
      return;
    }
    if (existing != null) return;
    await _saveCollectionUnconditional(ownerId: ownerId, model: legacy);
  }

  Future<CreateDraftModel?> _loadCollectionDraftStrict(
    String ownerId,
    String draftId,
  ) async {
    final raw = await _storage.read(key: _collectionDraftKey(ownerId, draftId));
    if (raw == null || raw.isEmpty) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return CreateDraftModel.fromJson(
      json,
      activeCurrency: activeCurrency,
      activeMarketCityId: activeMarketCityId,
      activeTimezone: activeTimezone,
      activeCountry: activeCountry,
      activeCity: activeCity,
    );
  }

  Future<void> _writeAndVerifyCollectionDraft(
    String ownerId,
    CreateDraftModel model,
  ) async {
    await _storage.write(
      key: _collectionDraftKey(ownerId, model.id),
      value: jsonEncode(model.toJson()),
    );
    final verified = await _loadCollectionDraftStrict(ownerId, model.id);
    verified?.toEntity();
    if (verified == null ||
        verified.id != model.id ||
        verified.organizerId != ownerId ||
        verified.scenarioRevision != model.scenarioRevision) {
      throw StateError('Scenario collection draft verification failed.');
    }
  }

  Future<_CollectionIndex> _recoverCollectionIndex(String ownerId) async {
    _CollectionIndex index;
    try {
      index = await _readCollectionIndex(ownerId);
    } on Object {
      index = _CollectionIndex.empty();
    }
    final all = await _storage.readAll();
    final prefix = '${_collectionPrefix(ownerId)}draft_';
    var changed = false;
    for (final entry in all.entries) {
      if (!entry.key.startsWith(prefix) || entry.value.isEmpty) continue;
      try {
        final json = jsonDecode(entry.value) as Map<String, dynamic>;
        final model = CreateDraftModel.fromJson(
          json,
          activeCurrency: activeCurrency,
          activeMarketCityId: activeMarketCityId,
          activeTimezone: activeTimezone,
          activeCountry: activeCountry,
          activeCity: activeCity,
        );
        model.toEntity();
        if (model.organizerId == ownerId &&
            _collectionDraftKey(ownerId, model.id) == entry.key &&
            !index.entries.containsKey(model.id)) {
          index.entries[model.id] = _CollectionIndexEntry.fromModel(model);
          changed = true;
        }
      } on Object {
        // A corrupt staged entry stays isolated and is never listed/editable.
      }
    }
    if (changed) await _writeCollectionIndex(ownerId, index);
    return index;
  }

  Future<_CollectionIndex> _readCollectionIndex(String ownerId) async {
    final raw = await _storage.read(key: _collectionIndexKey(ownerId));
    if (raw == null || raw.isEmpty) return _CollectionIndex.empty();
    return _CollectionIndex.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _writeCollectionIndex(String ownerId, _CollectionIndex index) =>
      _storage.write(
        key: _collectionIndexKey(ownerId),
        value: jsonEncode(index.toJson()),
      );

  Future<_CollectionStage?> _readCollectionStage(
    String ownerId,
    String draftId,
  ) async {
    final raw = await _storage.read(key: _collectionStageKey(ownerId, draftId));
    if (raw == null || raw.isEmpty) return null;
    return _CollectionStage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _writeAndVerifyCollectionStage(
    String ownerId,
    _CollectionStage stage,
  ) async {
    await _storage.write(
      key: _collectionStageKey(ownerId, stage.draftId),
      value: jsonEncode(stage.toJson()),
    );
    final verified = await _readCollectionStage(ownerId, stage.draftId);
    if (verified == null ||
        verified.idempotencyKey != stage.idempotencyKey ||
        verified.expectedRevision != stage.expectedRevision ||
        verified.nextRevision != stage.nextRevision ||
        verified.payloadJson != stage.payloadJson) {
      throw StateError('Scenario collection stage verification failed.');
    }
  }

  Future<void> _deleteStageBestEffort(String ownerId, String draftId) async {
    try {
      await _storage.delete(key: _collectionStageKey(ownerId, draftId));
    } on Object {
      // A verified receipt makes a leftover stage harmless on the next retry.
    }
  }

  static void _trimReceipts(_CollectionIndex index) {
    while (index.receipts.length > _maxReceiptsPerOwner) {
      index.receipts.remove(index.receipts.keys.first);
    }
  }

  static bool _validNamespacePart(String value) {
    final normalized = value.trim();
    return normalized == value &&
        normalized.isNotEmpty &&
        normalized.runes.length <= 256;
  }

  Future<CreateConditionalSaveResult> saveRouteDraftIfCurrent({
    required String userId,
    required CreateDraftModel model,
    required int? expectedRevision,
  }) {
    final key = _draftKey(userId);
    final completer = Completer<CreateConditionalSaveResult>();
    final previous = _conditionalSaveQueues[key] ?? Future<void>.value();
    late final Future<void> operation;
    operation = previous
        .catchError((Object _) {})
        .then((_) async {
          CreateDraftModel? current;
          try {
            current = await _loadDraftStrict(userId);
          } on Object {
            completer.complete(
              const CreateConditionalSaveResult(
                status: CreateConditionalSaveStatus.invalidExistingData,
              ),
            );
            return;
          }

          final nextRevision = model.routeRevision;
          if (nextRevision == null) {
            completer.complete(
              CreateConditionalSaveResult(
                status: CreateConditionalSaveStatus.conflict,
                persistedRevision: current?.routeRevision,
              ),
            );
            return;
          }

          final sameDraft = current != null && current.id == model.id;
          final currentRevision = sameDraft ? current.routeRevision : null;
          final matchesExpected = sameDraft
              ? currentRevision == expectedRevision
              : expectedRevision == null;
          if (!matchesExpected ||
              (currentRevision != null && nextRevision <= currentRevision)) {
            completer.complete(
              CreateConditionalSaveResult(
                status: CreateConditionalSaveStatus.conflict,
                persistedRevision: currentRevision,
              ),
            );
            return;
          }

          await saveDraft(userId, model);
          completer.complete(
            CreateConditionalSaveResult(
              status: CreateConditionalSaveStatus.saved,
              persistedRevision: nextRevision,
            ),
          );
        })
        .catchError((Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        })
        .whenComplete(() {
          if (identical(_conditionalSaveQueues[key], operation)) {
            _conditionalSaveQueues.remove(key);
          }
        });
    _conditionalSaveQueues[key] = operation;
    return completer.future;
  }
}

class _CollectionIndex {
  _CollectionIndex({required this.entries, required this.receipts});

  factory _CollectionIndex.empty() => _CollectionIndex(
    entries: <String, _CollectionIndexEntry>{},
    receipts: <String, _CollectionReceipt>{},
  );

  factory _CollectionIndex.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] !=
        CreateLocalDataSource._collectionSchemaVersion) {
      throw const FormatException('Unsupported Create collection index.');
    }
    final rawEntries = json['entries'];
    final rawReceipts = json['receipts'];
    if (rawEntries is! Map || rawReceipts is! Map) {
      throw const FormatException('Invalid Create collection index.');
    }
    return _CollectionIndex(
      entries: <String, _CollectionIndexEntry>{
        for (final entry in rawEntries.entries)
          entry.key.toString(): _CollectionIndexEntry.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      },
      receipts: <String, _CollectionReceipt>{
        for (final entry in rawReceipts.entries)
          entry.key.toString(): _CollectionReceipt.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      },
    );
  }

  final Map<String, _CollectionIndexEntry> entries;
  final Map<String, _CollectionReceipt> receipts;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': CreateLocalDataSource._collectionSchemaVersion,
    'entries': <String, Object?>{
      for (final entry in entries.entries) entry.key: entry.value.toJson(),
    },
    'receipts': <String, Object?>{
      for (final entry in receipts.entries) entry.key: entry.value.toJson(),
    },
  };
}

class _CollectionIndexEntry {
  const _CollectionIndexEntry({
    required this.objectType,
    required this.title,
    required this.updatedAtUtcIso,
  });

  factory _CollectionIndexEntry.fromModel(CreateDraftModel model) =>
      _CollectionIndexEntry(
        objectType: model.objectType,
        title: model.title,
        updatedAtUtcIso: model.updatedAtUtcIso,
      );

  factory _CollectionIndexEntry.fromJson(Map<String, dynamic> json) =>
      _CollectionIndexEntry(
        objectType: json['objectType'] as String,
        title: json['title'] as String? ?? '',
        updatedAtUtcIso: json['updatedAtUtcIso'] as String,
      );

  final String objectType;
  final String title;
  final String updatedAtUtcIso;

  Map<String, Object?> toJson() => <String, Object?>{
    'objectType': objectType,
    'title': title,
    'updatedAtUtcIso': updatedAtUtcIso,
  };
}

class _CollectionReceipt {
  const _CollectionReceipt({required this.draftId, required this.revision});

  factory _CollectionReceipt.fromJson(Map<String, dynamic> json) =>
      _CollectionReceipt(
        draftId: json['draftId'] as String,
        revision: (json['revision'] as num).toInt(),
      );

  final String draftId;
  final int revision;

  Map<String, Object?> toJson() => <String, Object?>{
    'draftId': draftId,
    'revision': revision,
  };
}

class _CollectionStage {
  const _CollectionStage({
    required this.idempotencyKey,
    required this.draftId,
    required this.expectedRevision,
    required this.nextRevision,
    required this.payloadJson,
  });

  factory _CollectionStage.fromJson(Map<String, dynamic> json) =>
      _CollectionStage(
        idempotencyKey: json['idempotencyKey'] as String,
        draftId: json['draftId'] as String,
        expectedRevision: (json['expectedRevision'] as num).toInt(),
        nextRevision: (json['nextRevision'] as num).toInt(),
        payloadJson: json['payloadJson'] as String,
      );

  final String idempotencyKey;
  final String draftId;
  final int expectedRevision;
  final int nextRevision;
  final String payloadJson;

  Map<String, Object?> toJson() => <String, Object?>{
    'idempotencyKey': idempotencyKey,
    'draftId': draftId,
    'expectedRevision': expectedRevision,
    'nextRevision': nextRevision,
    'payloadJson': payloadJson,
  };
}
