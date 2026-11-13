import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/create_draft_entity.dart';
import 'activity_publication_controller.dart';
import 'activity_validation_feedback.dart';

/// Transient, one-account feedback. Never persisted into old drafts.
final activityValidationFeedbackProvider =
    ChangeNotifierProvider<ActivityValidationFeedbackStore>(
      (ref) => ActivityValidationFeedbackStore(),
    );

final class ActivityValidationFeedbackStore extends ChangeNotifier {
  String? _key;
  DateTime? _updatedAt;
  Map<String, String> _fields = const {};
  bool _hasRefusal = false;

  static String _scope(String account, CreateDraftEntity draft) =>
      '$account:${draft.activityData?.publisherRef.type.wireName}:'
      '${draft.activityData?.publisherRef.id}:${draft.id}';

  void capture(ActivityPublicationController controller) {
    final draft = controller.currentDraft;
    _key = draft == null ? null : _scope(controller.accountId, draft);
    _updatedAt = draft?.updatedAtUtc;
    _hasRefusal = controller.state.message == 'validation_failed';
    _fields = _hasRefusal
        ? activityFieldFeedback(controller.state.violations)
        : const {};
    notifyListeners();
  }

  bool matches(String account, CreateDraftEntity draft) =>
      _hasRefusal &&
      _key == _scope(account, draft) &&
      _updatedAt == draft.updatedAtUtc;

  Map<String, String> fieldsFor(String account, CreateDraftEntity draft) =>
      matches(account, draft) ? _fields : const {};
}
