import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/localization/l10n_context.dart';
import '../../application/identity_workspace_providers.dart';
import '../../application/state/public_professional_page_state.dart';
import '../../domain/entities/public_professional_page.dart';
import '../../domain/usecases/resolve_public_professional_page_usecase.dart';

class PublicProfessionalPage extends ConsumerStatefulWidget {
  const PublicProfessionalPage({
    super.key,
    required this.reference,
    required this.lookup,
    required this.userId,
    this.preview = false,
  });

  final String reference;
  final PublicProfessionalPageLookup lookup;
  final String userId;
  final bool preview;

  @override
  ConsumerState<PublicProfessionalPage> createState() =>
      _PublicProfessionalPageState();
}

class _PublicProfessionalPageState
    extends ConsumerState<PublicProfessionalPage> {
  String? _loadKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant PublicProfessionalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference ||
        oldWidget.lookup != widget.lookup ||
        oldWidget.preview != widget.preview) {
      _loadKey = null;
      _scheduleLoad();
    }
  }

  void _scheduleLoad() {
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final String key =
        '${widget.preview}|${widget.lookup.name}|'
        '${widget.reference}|$locale|${widget.userId}';
    if (_loadKey == key) return;
    _loadKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(publicProfessionalPageControllerProvider);
      if (widget.preview) {
        controller.loadPreview(
          userId: widget.userId,
          pageId: widget.reference,
          requestedLocale: locale,
        );
      } else {
        controller.loadPublic(
          userId: widget.userId,
          lookup: widget.lookup,
          reference: widget.reference,
          requestedLocale: locale,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final PublicProfessionalPageState state = ref
        .watch(publicProfessionalPageControllerProvider)
        .state;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.identityProfessionalPage)),
      body: switch (state.status) {
        PublicProfessionalPageStatus.initial ||
        PublicProfessionalPageStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        PublicProfessionalPageStatus.ready => PublicProfessionalPageView(
          projection: state.projection!,
          viewerContext: state.viewerContext!,
        ),
        PublicProfessionalPageStatus.notFound ||
        PublicProfessionalPageStatus.forbidden =>
          const _PublicPageUnavailable(),
        PublicProfessionalPageStatus.error => _PublicPageError(
          message: context.l10n.identityPublicPageNotice(
            state.message ?? 'page_load_failed',
          ),
          onRetry: () {
            _loadKey = null;
            _scheduleLoad();
          },
        ),
      },
    );
  }
}

class PublicProfessionalPageView extends StatelessWidget {
  const PublicProfessionalPageView({
    super.key,
    required this.projection,
    required this.viewerContext,
  });

  final PublicManagedPageProjection projection;
  final PublicPageViewerContext viewerContext;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ListView(
      key: const ValueKey<String>('public-professional-page-content'),
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        if (viewerContext.isPreview) ...<Widget>[
          Semantics(
            label: context.l10n.identityPreviewNotPublic,
            child: Card(
              color: colors.secondaryContainer,
              child: ListTile(
                key: ValueKey<String>('public-page-preview-banner'),
                leading: Icon(Icons.visibility_outlined),
                title: Text(context.l10n.identityPublicPagePreview),
                subtitle: Text(context.l10n.identityPreviewDoesNotPublish),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 32,
                      child: projection.avatarMediaRef == null
                          ? const Icon(Icons.business_outlined, size: 30)
                          : const Icon(Icons.image_outlined, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            projection.displayName,
                            key: const ValueKey<String>(
                              'public-page-display-name',
                            ),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 5),
                          if (projection.verificationBadge)
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 5,
                              children: <Widget>[
                                Icon(Icons.verified, size: 18),
                                Text(context.l10n.identityVerifiedPage),
                              ],
                            )
                          else
                            Text(context.l10n.identityVerificationPending),
                          const SizedBox(height: 4),
                          Text(projection.countryCode),
                        ],
                      ),
                    ),
                  ],
                ),
                if (projection.shortDescription != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(projection.shortDescription!),
                ],
                if (projection.description != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(projection.description!),
                ],
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      key: const ValueKey<String>('share-public-page'),
                      onPressed: () => Share.share(
                        RouteNames.publicProfessionalPageForSlug(
                          projection.slug,
                        ),
                      ),
                      icon: const Icon(Icons.share_outlined),
                      label: Text(context.l10n.identityShare),
                    ),
                    if (viewerContext.canOpenPageWorkspace)
                      FilledButton.tonalIcon(
                        key: const ValueKey<String>('manage-public-page'),
                        onPressed: () =>
                            context.push(RouteNames.professionalPage),
                        icon: const Icon(Icons.dashboard_outlined),
                        label: Text(context.l10n.identityManagePage),
                      ),
                    if (viewerContext.canEditPage)
                      OutlinedButton.icon(
                        key: const ValueKey<String>('edit-public-page'),
                        onPressed: () =>
                            context.push(RouteNames.professionalPageAccount),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(context.l10n.identityEditPage),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.identityPublishedContent,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (projection.contentSummary.publishedCount == 0)
          Card(
            child: ListTile(
              key: ValueKey<String>('public-page-empty-content'),
              leading: Icon(Icons.inventory_2_outlined),
              title: Text(context.l10n.identityNoPublishedContent),
              subtitle: Text(context.l10n.identityContentViaProjection),
            ),
          )
        else
          Card(
            child: ListTile(
              leading: const Icon(Icons.grid_view_outlined),
              title: Text(
                context.l10n.identityPublishedItems(
                  projection.contentSummary.publishedCount,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PublicPageUnavailable extends StatelessWidget {
  const _PublicPageUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.search_off_outlined, size: 48),
            SizedBox(height: 12),
            Text(
              context.l10n.identityPageNotFound,
              key: ValueKey<String>('public-page-not-found'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicPageError extends StatelessWidget {
  const _PublicPageError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(context.l10n.identityRetry),
            ),
          ],
        ),
      ),
    );
  }
}
