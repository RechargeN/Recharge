import '../../domain/entities/managed_page_field_moderation_overlay.dart';

enum ManagedPageProfileEditorStatusFlag {
  initial,
  loading,
  ready,
  submitting,
  error,
}

class ManagedPageProfileEditorState {
  const ManagedPageProfileEditorState({
    required this.status,
    this.pageId,
    this.overlays = const <ManagedPageFieldModerationOverlay>[],
    this.message,
  });

  const ManagedPageProfileEditorState.initial()
    : this(status: ManagedPageProfileEditorStatusFlag.initial);

  final ManagedPageProfileEditorStatusFlag status;
  final String? pageId;
  final List<ManagedPageFieldModerationOverlay> overlays;
  final String? message;

  bool get isBusy => status == ManagedPageProfileEditorStatusFlag.submitting;

  ManagedPageFieldModerationOverlay? overlayFor(
    ManagedPageModeratedFieldKey fieldKey,
  ) {
    for (final ManagedPageFieldModerationOverlay overlay in overlays) {
      if (overlay.fieldKey == fieldKey) return overlay;
    }
    return null;
  }

  ManagedPageProfileEditorState copyWith({
    ManagedPageProfileEditorStatusFlag? status,
    String? pageId,
    List<ManagedPageFieldModerationOverlay>? overlays,
    String? message,
    bool clearMessage = false,
  }) {
    return ManagedPageProfileEditorState(
      status: status ?? this.status,
      pageId: pageId ?? this.pageId,
      overlays: overlays ?? this.overlays,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
