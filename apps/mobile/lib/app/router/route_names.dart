class RouteNames {
  static const String splash = '/splash';
  static const String discover = '/discover';
  static const String categories = '/discover/categories';
  static const String search = '/search';
  static const String smartSearch = '/smart-search';
  static const String discoverDetails = '/discover/details';
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

  static String quickPlanFor(String quickPlanId) =>
      '$quickPlan/${Uri.encodeComponent(quickPlanId)}';

  static String professionalPagePreviewFor(String pageId) =>
      '$professionalPagePreview/${Uri.encodeComponent(pageId)}';

  static String publicProfessionalPageForId(String pageId) =>
      '$publicProfessionalPagesById/${Uri.encodeComponent(pageId)}';

  static String publicProfessionalPageForSlug(String slug) =>
      '$publicProfessionalPages/${Uri.encodeComponent(slug)}';
}
