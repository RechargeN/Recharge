import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:design_system/design_system.dart';

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
  const DetailsScreenAvailable({
    required this.renderer,
    this.immersiveHero = false,
  });

  final DetailsRenderer renderer;

  /// When `true`, [DetailsShell] makes its `AppBar` transparent and
  /// extends the body behind it (edge-to-edge hero, `DTL-EVT-01` §1.1
  /// п.12) instead of the default opaque toolbar strip above the hero.
  /// Chrome (back/save/share) still comes from [renderer]'s
  /// `buildAppBarActions`/automatic leading — only its background and
  /// the body's layout change, never who owns it (`details_renderer.dart`:
  /// "a renderer... never owns the shell chrome itself").
  ///
  /// Deliberately a field on this concrete state, not a method on
  /// [DetailsRenderer]: the interface has no default implementations
  /// (`abstract interface class`), so a new required method there would
  /// force every existing implementer (including the two test fakes in
  /// `details_shell_test.dart`/`details_shell_accessibility_test.dart`) to
  /// add a trivial override. A field with a default here needs none of
  /// that — see `DTL_EVT_01_EVENT_DETAILS_SLICE_SPEC.md` "Что изменилось
  /// относительно v0.1" п.3.
  final bool immersiveHero;
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
      DetailsScreenAvailable(:final renderer, :final immersiveHero) =>
        _buildAvailable(context, renderer, immersiveHero),
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

  Widget _buildAvailable(
    BuildContext context,
    DetailsRenderer renderer,
    bool immersiveHero,
  ) {
    return Scaffold(
      backgroundColor: immersiveHero
          ? RechargeTheme.objectOfferScreenBackground
          : null,
      extendBodyBehindAppBar: immersiveHero,
      appBar: _DetailsShellAppBar(
        actions: renderer.buildAppBarActions(context),
        transparent: immersiveHero,
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
  const _DetailsShellAppBar({required this.actions, this.transparent = false});

  final List<Widget> actions;

  /// `DTL-EVT-01` §1.1 п.12 — immersive hero mode: transparent background,
  /// no title, white status-bar icons (the hero photo sits directly under
  /// them), and a top scrim so back/save/share stay legible over an
  /// arbitrary photo. Chrome ownership does not change — this widget still
  /// renders [actions] exactly as any other renderer's shell would.
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    if (!transparent) {
      return AppBar(title: const Text('RECHARGE'), actions: actions);
    }
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: Navigator.of(context).canPop()
          ? Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Material(
                color: RechargeTheme.objectOfferCardSurface,
                shape: const CircleBorder(),
                elevation: 2,
                shadowColor: RechargeTheme.objectOfferHeroActionShadow,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
                  color: RechargeTheme.objectOfferPrimaryText,
                ),
              ),
            )
          : null,
      leadingWidth: 68,
      automaticallyImplyLeading: false,
      iconTheme: const IconThemeData(
        color: RechargeTheme.objectOfferPrimaryText,
      ),
      actionsIconTheme: const IconThemeData(
        color: RechargeTheme.objectOfferPrimaryText,
      ),
      flexibleSpace: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                RechargeTheme.objectOfferHeroScrim,
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
