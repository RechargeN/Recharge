import 'package:flutter/widgets.dart';

/// The closed set of Details renderer families defined by
/// `docs/product/DISCOVER_DETAILS_SYSTEM_SPEC.md` §3. Adding a member here
/// is an architecture-level change to the Details System, not a per-slice
/// decision — it mirrors the four target renderer contracts
/// (`ObjectOfferDetailsRenderer`, `RouteDetailsRenderer`,
/// `ScenarioDetailsRenderer`, `CollectionDetailsRenderer`).
enum DetailsRendererFamily { objectOffer, route, scenario, collection }

/// Typed contract every Details renderer implements. Deliberately **not**
/// `sealed`: `sealed` would restrict implementations to this library, which
/// would prevent future renderers (`DTL-RTE-01`, `DTL-CLG-01`,
/// `DTL-SCN-01`) from living in their own files/libraries, as required by
/// `docs/product/DTL_FND_01_DETAILS_SHELL_SLICE_SPEC.md` §2.
///
/// A renderer supplies content for the slots [DetailsShell] owns (app bar
/// actions, hero, body, sticky action) — it never owns the shell chrome
/// itself, and it never resolves or verifies an object's type: that
/// responsibility belongs to the application-layer resolver introduced by
/// `DTL-LINK-01`, not to this presentation-layer contract.
abstract interface class DetailsRenderer {
  /// Widgets shown in the shell's AppBar actions row (e.g. favorite,
  /// share).
  List<Widget> buildAppBarActions(BuildContext context);

  /// Hero content shown directly below the app bar.
  Widget buildHero(BuildContext context);

  /// Main scrollable body content, shown below the hero.
  Widget buildBody(BuildContext context);

  /// Sticky bottom action bar content, or `null` when this renderer has
  /// nothing to put there. [DetailsShell] must not render an empty sticky
  /// container when this returns `null`.
  Widget? buildStickyAction(BuildContext context);
}

/// Builds a [DetailsRenderer] for one already-resolved family instance.
///
/// Takes no id/typed-projection parameter: this slice (`DTL-FND-01`) has
/// exactly one real caller (`DiscoverDetailsPage`), which already holds a
/// loaded item by the time it builds a renderer. A later slice that
/// introduces its own typed read model is free to shape its own factory
/// closure however it needs — this typedef does not constrain it.
typedef DetailsRendererBuilder = DetailsRenderer Function();

/// Presentation-only lookup from an already-known [DetailsRendererFamily]
/// to the widget that renders it. This registry is **not** a data
/// authority: it never decides which family a given object belongs to, and
/// it never reads from a repository. That responsibility is
/// `DetailsLookupRegistry`/`ResolveDetailsUseCase`, introduced in
/// `DTL-LINK-01`'s application layer (see
/// `docs/product/DISCOVER_DETAILS_SYSTEM_SPEC.md` §11: router parses,
/// application resolver verifies, presentation registry only dispatches).
class DetailsRendererRegistry {
  DetailsRendererRegistry(
    Map<DetailsRendererFamily, DetailsRendererBuilder> builders,
  ) : _builders = Map<DetailsRendererFamily, DetailsRendererBuilder>.of(
        builders,
      );

  final Map<DetailsRendererFamily, DetailsRendererBuilder> _builders;

  /// Returns the renderer registered for [family].
  ///
  /// Throws a [StateError] when nothing is registered for it — a missing
  /// registration is a wiring bug in the caller, not a runtime state to
  /// degrade gracefully from. A genuinely absent/unavailable *object* is a
  /// `DetailsScreenState.unavailable` concern (see `details_shell.dart`),
  /// not a renderer-lookup concern.
  DetailsRenderer build(DetailsRendererFamily family) {
    final DetailsRendererBuilder? builder = _builders[family];
    if (builder == null) {
      throw StateError(
        'No DetailsRenderer registered for family $family. Every '
        'DetailsRendererFamily in use must have a builder registered where '
        'the registry is constructed.',
      );
    }
    return builder();
  }
}
