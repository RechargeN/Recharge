import '../../shared/models/catalog_object_ref.dart';

class RouteNames {
  static const String splash = '/splash';
  static const String discover = '/discover';
  static const String categories = '/discover/categories';
  static const String search = '/search';
  static const String smartSearch = '/smart-search';
  static const String discoverDetails = '/discover/details';
  static const String collectionDetails = '/collection/details';
  static const String discoverMap = '/discover/map';
  static const String discoverResults = '/discover/results';
  static const String legacyScenarioBuilder = '/scenario-builder';
  @Deprecated('Compatibility-only; use typed Scenario or Quick Plan routes.')
  static const String scenarioBuilder = legacyScenarioBuilder;
  static const String quickPlan = '/quick-plan';
  static const String favorites = '/favorites';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String professionalPage = '/page';
  static const String professionalPageContent = '/page/content';
  static const String professionalPageCreate = '/page/create';
  static const String professionalPageAccount = '/page/account';
  static const String professionalPagePreview = '/page/public-preview';
  static const String publicProfessionalPages = '/professional-pages';
  static const String publicProfessionalPagesById = '/professional-pages/id';
  static const String signIn = '/auth/sign-in';
  static const String profile = '/profile';
  static const String profileWorkspace = '/profile/workspace';
  static const String visitedPlaces = '/profile/visited';
  static const String create = '/create';
  static const String createObject = '/create/new';
  static const String createSuccess = '/create/success';
  static const String routeModeration = '/create/routes/moderation';

  static String createObjectFor(String objectTypeId) {
    return '$createObject/$objectTypeId';
  }

  /// The new canonical Details link (`DTL-LINK-01`,
  /// `docs/product/DISCOVER_DETAILS_SYSTEM_SPEC.md` §11, DTL-D09) — used
  /// wherever [ref]'s `objectType` is already known at the call site.
  /// Resolved through `ResolveDetailsUseCase`
  /// (`app/application/resolve_details_usecase.dart`), which verifies the
  /// claimed type against the actual object before rendering.
  static String discoverDetailsCanonicalFor(CatalogObjectRef ref) {
    return '$discoverDetails/${ref.objectType.taxonomyId}/'
        '${Uri.encodeComponent(ref.objectId)}';
  }

  /// The pre-`DTL-LINK-01` untyped Details link. Still fully supported —
  /// `ResolveDetailsUseCase` classifies it exactly as today's code does —
  /// but a call site that already knows the `objectType` should use
  /// [discoverDetailsCanonicalFor] instead of reaching for this.
  @Deprecated(
    'Prefer discoverDetailsCanonicalFor(ref) when the objectType is '
    'already known at the call site. This legacy, untyped form remains '
    'fully supported.',
  )
  static String discoverDetailsFor(String itemId) {
    return '$discoverDetails/${Uri.encodeComponent(itemId)}';
  }

  static String quickPlanFor(String quickPlanId) =>
      '$quickPlan/${Uri.encodeComponent(quickPlanId)}';

  static String professionalPagePreviewFor(String pageId) =>
      '$professionalPagePreview/${Uri.encodeComponent(pageId)}';

  static String publicProfessionalPageForId(String pageId) =>
      '$publicProfessionalPagesById/${Uri.encodeComponent(pageId)}';

  static String publicProfessionalPageForSlug(String slug) =>
      '$publicProfessionalPages/${Uri.encodeComponent(slug)}';
}
