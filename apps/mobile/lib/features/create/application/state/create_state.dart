import '../../domain/entities/create_draft_entity.dart';

enum CreateStatus {
  initial,
  loading,
  ready,
  saving,
  publishing,
  publishSuccess,
  error,
}

class CreateState {
  const CreateState({
    required this.status,
    required this.userId,
    required this.draft,
    required this.message,
    required this.validationErrors,
    required this.publishedDraft,
  });

  factory CreateState.initial() {
    return CreateState(
      status: CreateStatus.initial,
      userId: '',
      draft: CreateDraftEntity.defaults(
        organizerId: '',
        organizerEmail: '',
        organizerName: '',
      ),
      message: null,
      validationErrors: const <String, String>{},
      publishedDraft: null,
    );
  }

  final CreateStatus status;
  final String userId;
  final CreateDraftEntity draft;
  final String? message;
  final Map<String, String> validationErrors;
  final CreateDraftEntity? publishedDraft;

  bool get isLoaded =>
      status == CreateStatus.ready ||
      status == CreateStatus.saving ||
      status == CreateStatus.publishing ||
      status == CreateStatus.publishSuccess;

  CreateState copyWith({
    CreateStatus? status,
    String? userId,
    CreateDraftEntity? draft,
    String? message,
    bool clearMessage = false,
    Map<String, String>? validationErrors,
    bool clearValidationErrors = false,
    CreateDraftEntity? publishedDraft,
    bool clearPublishedDraft = false,
  }) {
    return CreateState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      draft: draft ?? this.draft,
      message: clearMessage ? null : (message ?? this.message),
      validationErrors: clearValidationErrors
          ? const <String, String>{}
          : (validationErrors ?? this.validationErrors),
      publishedDraft: clearPublishedDraft
          ? null
          : (publishedDraft ?? this.publishedDraft),
    );
  }
}
