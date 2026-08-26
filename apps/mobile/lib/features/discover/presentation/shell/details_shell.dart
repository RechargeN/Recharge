import 'package:flutter/material.dart';

import 'details_renderer.dart';

/// Why a Details screen currently has no content to show. Mirrors the
/// enumeration-safe viewer states from
/// `docs/product/DISCOVER_DETAILS_SYSTEM_SPEC.md` §12 (DTL-D10): never a
/// Create-domain lifecycle enum (`DraftStatus`/`ModerationStatus`), and
/// [unavailable]/[notFound] deliberately render identical copy so a viewer
/// cannot distinguish "hidden by moderation" from "never existed".
enum DetailsUnavailableReason { temporarilyUnavailable, unavailable, notFound }

/// The shell's content state. Deliberately a small `sealed` union — unlike
/// [DetailsRenderer] (see `details_renderer.dart`), there is no reason for
/// callers outside this library to add their own state, so `sealed` is the
/// right tool here
/// (`docs/product/DTL_FND_01_DETAILS_SHELL_SLICE_SPEC.md` §2: "`sealed`
/// remains a valid tool ... for a typed read-model union").
sealed class DetailsScreenState {
  const DetailsScreenState();
}

class DetailsScreenLoading extends DetailsScreenState {
  const DetailsScreenLoading();
}

class DetailsScreenAvailable extends DetailsScreenState {
  const DetailsScreenAvailable({required this.renderer});

  final DetailsRenderer renderer;
}

class DetailsScreenUnavailable extends DetailsScreenState {
  const DetailsScreenUnavailable({required this.reason, this.onRetry});

  final DetailsUnavailableReason reason;

  /// Offered only for [DetailsUnavailableReason.temporarilyUnavailable];
  /// [DetailsShell] does not render a retry action for the other reasons,
  /// since retrying a `notFound`/`unavailable` object cannot succeed.
  final VoidCallback? onRetry;
}

/// Presentation-only Details host. Owns the app bar, hero slot, sticky
/// action container and the loading/unavailable representation — nothing
/// here requires a coordinate, a single date, a price, a single publisher
/// CTA, a single location or a single schedule
/// (`docs/product/DISCOVER_DETAILS_SYSTEM_SPEC.md` §4).
///
/// [DetailsShell] never resolves data and never picks a renderer for an
/// `objectType` — it is handed an already-resolved [DetailsScreenState] by
/// its caller.
class DetailsShell extends StatelessWidget {
  const DetailsShell({super.key, required this.state});

  final DetailsScreenState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      DetailsScreenLoading() => _buildLoading(),
      DetailsScreenAvailable(:final renderer) => _buildAvailable(
        context,
        renderer,
      ),
      DetailsScreenUnavailable(:final reason, :final onRetry) =>
        _buildUnavailable(reason, onRetry),
    };
  }

  Widget _buildLoading() {
    return const Scaffold(
      appBar: _DetailsShellAppBar(actions: <Widget>[]),
      body: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildAvailable(BuildContext context, DetailsRenderer renderer) {
    return Scaffold(
      appBar: _DetailsShellAppBar(
        actions: renderer.buildAppBarActions(context),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          renderer.buildHero(context),
          renderer.buildBody(context),
        ],
      ),
      // A renderer with nothing for the sticky action slot must not get an
      // empty sticky container — the same principle
      // `DTL_CLG_01_COLLECTION_SHELL_MIGRATION_SLICE_SPEC.md` (CLG-D-AC-10)
      // requires of its own renderer, enforced once here at the shell.
      bottomNavigationBar: renderer.buildStickyAction(context),
    );
  }

  Widget _buildUnavailable(
    DetailsUnavailableReason reason,
    VoidCallback? onRetry,
  ) {
    return Scaffold(
      appBar: const _DetailsShellAppBar(actions: <Widget>[]),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_messageFor(reason)),
              if (reason == DetailsUnavailableReason.temporarilyUnavailable &&
                  onRetry != null) ...<Widget>[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Повторить'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // `unavailable` and `notFound` deliberately share one string (DTL-D10):
  // neither `DTL-LINK-01` nor any renderer registered in this slice
  // produces them yet — today's single real caller
  // (`CompatibilityObjectRenderer`'s data source) only ever reaches
  // `temporarilyUnavailable`, mapped from a plain load error. The other two
  // branches are proven by the shell contract test in isolation
  // (`details_shell_test.dart`) ahead of `DTL-LINK-01`/`DTL-OBJ-01`, which
  // will be the first real producers of them.
  static String _messageFor(DetailsUnavailableReason reason) {
    return switch (reason) {
      DetailsUnavailableReason.temporarilyUnavailable =>
        'Не удалось загрузить details',
      DetailsUnavailableReason.unavailable => 'Недоступно',
      DetailsUnavailableReason.notFound => 'Недоступно',
    };
  }
}

class _DetailsShellAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _DetailsShellAppBar({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('RECHARGE'), actions: actions);
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
