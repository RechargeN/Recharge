import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/content_validation_violation.dart';
import '../domain/entities/create_draft_entity.dart';
import 'content_server_requirements.dart';

/// What the Create form knows about the server publication path of a type
/// (M1 stage 3, owner decision 3-Б). Off by default: the app overrides it from
/// the publication test-entry guards, so features never import `app/di`.
final class ContentServerPath {
  const ContentServerPath({
    required this.isEnabled,
    required this.marketCurrencyCode,
    this.clock,
  });

  /// True while the server path of [CreateObjectType] is enabled (test entry,
  /// non-release, testBackend, loopback Emulator).
  final bool Function(CreateObjectType type) isEnabled;

  /// The market currency of the Create runtime (`CreateRuntimeDefaults`).
  final String marketCurrencyCode;
  final DateTime Function()? clock;

  static bool _never(CreateObjectType _) => false;

  static const ContentServerPath disabled = ContentServerPath(
    isEnabled: _never,
    marketCurrencyCode: '',
  );
}

final Provider<ContentServerPath> contentServerPathProvider =
    Provider<ContentServerPath>((Ref ref) => ContentServerPath.disabled);

/// The server requirements of [draft] while its type's server path is on;
/// empty otherwise, for other types and for a draft that cannot be mapped
/// (the publication path refuses that one with its own code).
List<ContentValidationViolation> serverRequirementsFor(
  CreateDraftEntity draft, {
  required String accountId,
  required ContentServerPath path,
}) {
  if (!path.isEnabled(draft.objectType)) {
    return const <ContentValidationViolation>[];
  }
  try {
    return switch (draft.objectType) {
      CreateObjectType.place => placeServerRequirements(
        draft,
        accountId: accountId,
        marketCurrencyCode: path.marketCurrencyCode,
      ),
      CreateObjectType.rental => rentalServerRequirements(
        draft,
        accountId: accountId,
        nowUtc: (path.clock ?? () => DateTime.now().toUtc())(),
      ),
      CreateObjectType.collection => collectionServerRequirements(
        draft,
        accountId: accountId,
      ),
      _ => const <ContentValidationViolation>[],
    };
  } on ArgumentError {
    return const <ContentValidationViolation>[];
  } on StateError {
    return const <ContentValidationViolation>[];
  }
}

/// The last validation refusal of a type's publication path for one account
/// and one draft revision; transient, never persisted (as for Activity).
final class ContentValidationFeedbackStore extends ChangeNotifier {
  String? _key;
  DateTime? _updatedAt;
  List<ContentValidationViolation> _violations =
      const <ContentValidationViolation>[];
  bool _hasRefusal = false;

  static String _scope(String account, CreateDraftEntity draft) =>
      '$account:${draft.id}';

  void capture({
    required String accountId,
    required CreateDraftEntity? draft,
    required String? message,
    required List<ContentValidationViolation> violations,
  }) {
    _key = draft == null ? null : _scope(accountId, draft);
    _updatedAt = draft?.updatedAtUtc;
    _hasRefusal = message == 'validation_failed';
    _violations = _hasRefusal
        ? violations
        : const <ContentValidationViolation>[];
    notifyListeners();
  }

  bool matches(String account, CreateDraftEntity draft) =>
      _hasRefusal &&
      _key == _scope(account, draft) &&
      _updatedAt == draft.updatedAtUtc;

  List<ContentValidationViolation> violationsFor(
    String account,
    CreateDraftEntity draft,
  ) => matches(account, draft)
      ? _violations
      : const <ContentValidationViolation>[];
}

final contentValidationFeedbackProvider =
    ChangeNotifierProvider.family<
      ContentValidationFeedbackStore,
      CreateObjectType
    >((Ref ref, CreateObjectType type) => ContentValidationFeedbackStore());
