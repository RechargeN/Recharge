import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/managed_page_field_moderation_overlay.dart';

class ManagedPageFieldModerationLocalDataSource {
  const ManagedPageFieldModerationLocalDataSource(this._storage);

  static const int schemaVersion = 1;

  final FlutterSecureStorage _storage;

  String _key(String pageId) => 'identity_field_moderation_$pageId';

  Future<List<ManagedPageFieldModerationOverlay>> loadForPage(
    String pageId,
  ) async {
    final String? raw = await _storage.read(key: _key(pageId));
    if (raw == null || raw.isEmpty) {
      return const <ManagedPageFieldModerationOverlay>[];
    }

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const <ManagedPageFieldModerationOverlay>[];
      }
      if (decoded['schemaVersion'] != schemaVersion) {
        return const <ManagedPageFieldModerationOverlay>[];
      }
      final List<dynamic> items =
          decoded['overlays'] as List<dynamic>? ?? const <dynamic>[];
      return items
          .map((dynamic item) => _overlayFromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } on FormatException {
      return const <ManagedPageFieldModerationOverlay>[];
    } on TypeError {
      return const <ManagedPageFieldModerationOverlay>[];
    } on StateError {
      return const <ManagedPageFieldModerationOverlay>[];
    }
  }

  Future<void> saveForPage(
    String pageId,
    List<ManagedPageFieldModerationOverlay> overlays,
  ) {
    return _storage.write(
      key: _key(pageId),
      value: jsonEncode(<String, Object>{
        'schemaVersion': schemaVersion,
        'overlays': overlays.map(_overlayToJson).toList(growable: false),
      }),
    );
  }

  static Map<String, Object?> _overlayToJson(
    ManagedPageFieldModerationOverlay overlay,
  ) {
    return <String, Object?>{
      'pageId': overlay.pageId,
      'fieldKey': overlay.fieldKey.name,
      'lastApprovedValue': overlay.lastApprovedValue == null
          ? null
          : _valueToJson(overlay.lastApprovedValue!),
      'lastApprovedAtUtc': overlay.lastApprovedAtUtc?.toUtc().toIso8601String(),
      'approvedForVerificationRevision':
          overlay.approvedForVerificationRevision,
      'pendingSubmission': overlay.pendingSubmission == null
          ? null
          : _pendingToJson(overlay.pendingSubmission!),
      'latestRejection': overlay.latestRejection == null
          ? null
          : _rejectionToJson(overlay.latestRejection!),
      'clearedAtUtc': overlay.clearedAtUtc?.toUtc().toIso8601String(),
      'revision': overlay.revision,
      'schemaVersion': overlay.schemaVersion,
    };
  }

  static ManagedPageFieldModerationOverlay _overlayFromJson(
    Map<String, dynamic> json,
  ) {
    final Map<String, dynamic>? pending =
        json['pendingSubmission'] as Map<String, dynamic>?;
    final Map<String, dynamic>? rejection =
        json['latestRejection'] as Map<String, dynamic>?;
    final Map<String, dynamic>? lastApproved =
        json['lastApprovedValue'] as Map<String, dynamic>?;
    final String? lastApprovedAtUtc = json['lastApprovedAtUtc'] as String?;
    final String? clearedAtUtc = json['clearedAtUtc'] as String?;
    return ManagedPageFieldModerationOverlay(
      pageId: json['pageId'] as String,
      fieldKey: _enumByName(
        ManagedPageModeratedFieldKey.values,
        json['fieldKey'] as String,
      ),
      lastApprovedValue: lastApproved == null
          ? null
          : _valueFromJson(lastApproved),
      lastApprovedAtUtc: lastApprovedAtUtc == null
          ? null
          : DateTime.parse(lastApprovedAtUtc).toUtc(),
      approvedForVerificationRevision:
          json['approvedForVerificationRevision'] as int?,
      pendingSubmission: pending == null ? null : _pendingFromJson(pending),
      latestRejection: rejection == null ? null : _rejectionFromJson(rejection),
      clearedAtUtc: clearedAtUtc == null
          ? null
          : DateTime.parse(clearedAtUtc).toUtc(),
      revision: json['revision'] as int,
      schemaVersion: json['schemaVersion'] as int,
    );
  }

  static Map<String, Object?> _pendingToJson(
    ManagedPageFieldPendingSubmission pending,
  ) {
    return <String, Object?>{
      'submissionId': pending.submissionId,
      'value': pending.value == null ? null : _valueToJson(pending.value!),
      'clearRequested': pending.clearRequested,
      'submittedAtUtc': pending.submittedAtUtc.toUtc().toIso8601String(),
      'basedOnOverlayRevision': pending.basedOnOverlayRevision,
    };
  }

  static ManagedPageFieldPendingSubmission _pendingFromJson(
    Map<String, dynamic> json,
  ) {
    final Map<String, dynamic>? value = json['value'] as Map<String, dynamic>?;
    return ManagedPageFieldPendingSubmission(
      submissionId: json['submissionId'] as String,
      value: value == null ? null : _valueFromJson(value),
      clearRequested: json['clearRequested'] as bool,
      submittedAtUtc: DateTime.parse(json['submittedAtUtc'] as String).toUtc(),
      basedOnOverlayRevision: json['basedOnOverlayRevision'] as int,
    );
  }

  static Map<String, Object?> _rejectionToJson(
    ManagedPageFieldRejection rejection,
  ) {
    return <String, Object?>{
      'submissionId': rejection.submissionId,
      'rejectedValue': rejection.rejectedValue == null
          ? null
          : _valueToJson(rejection.rejectedValue!),
      'rejectedAtUtc': rejection.rejectedAtUtc.toUtc().toIso8601String(),
      'rejectionReasonCode': rejection.rejectionReasonCode,
    };
  }

  static ManagedPageFieldRejection _rejectionFromJson(
    Map<String, dynamic> json,
  ) {
    final Map<String, dynamic>? rejectedValue =
        json['rejectedValue'] as Map<String, dynamic>?;
    return ManagedPageFieldRejection(
      submissionId: json['submissionId'] as String,
      rejectedValue: rejectedValue == null
          ? null
          : _valueFromJson(rejectedValue),
      rejectedAtUtc: DateTime.parse(json['rejectedAtUtc'] as String).toUtc(),
      rejectionReasonCode: json['rejectionReasonCode'] as String,
    );
  }

  static Map<String, Object?> _valueToJson(
    ManagedPageModeratedFieldValue value,
  ) {
    return switch (value) {
      ManagedPageLocalizedTextValue v => <String, Object?>{
        'type': 'localizedText',
        'valuesByLocale': v.valuesByLocale,
      },
      ManagedPageShortTextValue v => <String, Object?>{
        'type': 'shortText',
        'value': v.value,
      },
      ManagedPageMediaValue v => <String, Object?>{
        'type': 'media',
        'mediaId': v.mediaId,
      },
      ManagedPageActivityLabelValue v => <String, Object?>{
        'type': 'activityLabel',
        'value': v.value,
      },
    };
  }

  static ManagedPageModeratedFieldValue _valueFromJson(
    Map<String, dynamic> json,
  ) {
    final String type = json['type'] as String;
    switch (type) {
      case 'localizedText':
        final Map<String, dynamic> raw =
            json['valuesByLocale'] as Map<String, dynamic>;
        return ManagedPageLocalizedTextValue(
          raw.map(
            (String key, dynamic value) => MapEntry(key, value as String),
          ),
        );
      case 'shortText':
        return ManagedPageShortTextValue(json['value'] as String);
      case 'media':
        return ManagedPageMediaValue(json['mediaId'] as String);
      case 'activityLabel':
        return ManagedPageActivityLabelValue(json['value'] as String);
      default:
        throw const FormatException('unknown_moderated_field_value_type');
    }
  }

  static T _enumByName<T extends Enum>(List<T> values, String name) {
    return values.firstWhere((T value) => value.name == name);
  }
}
