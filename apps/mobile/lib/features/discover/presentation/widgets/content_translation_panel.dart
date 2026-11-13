import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../../../core/localization/user_message_catalog.dart';
import '../../application/discover_providers.dart';
import '../../domain/repositories/content_translation_port.dart';

/// The Details supplement for a server-published revision; `null` when the app
/// did not compose translation or the object has no server revision.
Widget? contentTranslationSupplement(
  BuildContext context,
  WidgetRef ref, {
  required String contentId,
  required String publishedRevisionId,
}) {
  final ContentTranslationPort? port = ref.watch(
    contentTranslationPortProvider,
  );
  if (port == null || publishedRevisionId.isEmpty) return null;
  final String targetLocale = Localizations.localeOf(context).languageCode;
  return ContentTranslationPanel(
    key: ValueKey<String>('$contentId:$publishedRevisionId:$targetLocale'),
    port: port,
    contentId: contentId,
    publishedRevisionId: publishedRevisionId,
    targetLocale: targetLocale,
  );
}

/// ADR 0022: "Перевести" in Details. The original stays where it is; the
/// translation is shown here, labeled, as plain text, and only in this
/// screen's memory. Every refusal or failure leaves the original and a
/// localized message; with nothing to offer the panel takes no space.
class ContentTranslationPanel extends StatefulWidget {
  const ContentTranslationPanel({
    super.key,
    required this.port,
    required this.contentId,
    required this.publishedRevisionId,
    required this.targetLocale,
  });

  final ContentTranslationPort port;
  final String contentId;
  final String publishedRevisionId;
  final String targetLocale;

  @override
  State<ContentTranslationPanel> createState() =>
      _ContentTranslationPanelState();
}

class _ContentTranslationPanelState extends State<ContentTranslationPanel> {
  bool _offered = false;
  bool _loading = false;
  bool _showing = false;
  ContentTranslation? _translation;
  String? _failureCode;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ContentTranslationOffer offer = await widget.port.offer(
      contentId: widget.contentId,
      publishedRevisionId: widget.publishedRevisionId,
      targetLocale: widget.targetLocale,
    );
    if (!mounted) return;
    switch (offer) {
      case ContentTranslationUnavailable():
        return;
      case ContentTranslationAvailable():
        setState(() => _offered = true);
      case ContentTranslationReady(:final ContentTranslation translation):
        // Amendment 1: shown at once, still labeled, original one tap away.
        setState(() {
          _offered = true;
          _translation = translation;
          _showing = true;
        });
    }
  }

  Future<void> _translate() async {
    if (_translation != null) {
      setState(() => _showing = true);
      return;
    }
    setState(() {
      _loading = true;
      _failureCode = null;
    });
    try {
      final ContentTranslation translation = await widget.port.translate(
        contentId: widget.contentId,
        publishedRevisionId: widget.publishedRevisionId,
        targetLocale: widget.targetLocale,
      );
      if (!mounted) return;
      setState(() {
        _translation = translation;
        _showing = true;
        _loading = false;
      });
    } on ContentTranslationFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _failureCode = failure.code;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_offered) return const SizedBox.shrink();
    final ContentTranslation? translation = _translation;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _loading
          ? _Loading(key: const Key('content-translation-loading'))
          : _showing && translation != null
          ? _Translated(
              translation: translation,
              onShowOriginal: () => setState(() => _showing = false),
            )
          : _Offer(
              failureCode: _failureCode,
              hasTranslation: translation != null,
              onTranslate: _translate,
            ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(context.l10n.contentTranslationLoading)),
      ],
    );
  }
}

class _Offer extends StatelessWidget {
  const _Offer({
    required this.failureCode,
    required this.hasTranslation,
    required this.onTranslate,
  });

  final String? failureCode;
  final bool hasTranslation;
  final VoidCallback onTranslate;

  @override
  Widget build(BuildContext context) {
    final String? failure = failureCode == null
        ? null
        : UserMessageCatalog.message(
            context.l10n,
            UserMessageFamily.contentTranslation,
            failureCode,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (failure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              failure,
              key: const Key('content-translation-failure'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextButton.icon(
          key: const Key('content-translation-action'),
          onPressed: onTranslate,
          icon: const Icon(Icons.translate, size: 20),
          label: Text(
            hasTranslation
                ? context.l10n.contentTranslationShowTranslation
                : context.l10n.contentTranslationAction,
          ),
        ),
      ],
    );
  }
}

class _Translated extends StatelessWidget {
  const _Translated({required this.translation, required this.onShowOriginal});

  final ContentTranslation translation;
  final VoidCallback onShowOriginal;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('content-translation-result'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.contentTranslationLabel,
            key: const Key('content-translation-label'),
            style: text.labelMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (translation.title != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(translation.title!, style: text.titleMedium),
          ],
          if (translation.shortDescription != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(translation.shortDescription!, style: text.bodyMedium),
          ],
          if (translation.fullDescription != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(translation.fullDescription!, style: text.bodyMedium),
          ],
          const SizedBox(height: 8),
          Text(
            context.l10n.contentTranslationKeptOriginal,
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          TextButton(
            key: const Key('content-translation-show-original'),
            onPressed: onShowOriginal,
            child: Text(context.l10n.contentTranslationShowOriginal),
          ),
        ],
      ),
    );
  }
}
