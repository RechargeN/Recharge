import '../../domain/entities/public_professional_page.dart';

enum PublicProfessionalPageStatus {
  initial,
  loading,
  ready,
  notFound,
  forbidden,
  error,
}

class PublicProfessionalPageState {
  const PublicProfessionalPageState({
    required this.status,
    this.projection,
    this.viewerContext,
    this.message,
  });

  const PublicProfessionalPageState.initial()
    : this(status: PublicProfessionalPageStatus.initial);

  final PublicProfessionalPageStatus status;
  final PublicManagedPageProjection? projection;
  final PublicPageViewerContext? viewerContext;
  final String? message;
}
