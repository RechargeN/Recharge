import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/create_draft_model.dart';

enum CreateConditionalSaveStatus { saved, conflict, invalidExistingData }

class CreateConditionalSaveResult {
  const CreateConditionalSaveResult({
    required this.status,
    this.persistedRevision,
  });

  final CreateConditionalSaveStatus status;
  final int? persistedRevision;
}

class CreateLocalDataSource {
  CreateLocalDataSource(
    this._storage, {
    this.activeMarketCityId = '',
    this.activeTimezone = 'UTC',
    this.activeCountry = '',
    this.activeCity = '',
  });

  final FlutterSecureStorage _storage;
  final String activeMarketCityId;
  final String activeTimezone;
  final String activeCountry;
  final String activeCity;
  final Map<String, Future<void>> _conditionalSaveQueues =
      <String, Future<void>>{};

  String _draftKey(String userId) => 'create_draft_$userId';

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
      activeMarketCityId: activeMarketCityId,
      activeTimezone: activeTimezone,
      activeCountry: activeCountry,
      activeCity: activeCity,
    );
  }

  Future<void> saveDraft(String userId, CreateDraftModel model) {
    return _storage.write(
      key: _draftKey(userId),
      value: jsonEncode(model.toJson()),
    );
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
