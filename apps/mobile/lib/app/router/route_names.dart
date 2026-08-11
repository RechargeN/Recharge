class RouteNames {
  static const String splash = '/splash';
  static const String discover = '/discover';
  static const String categories = '/discover/categories';
  static const String search = '/search';
  static const String smartSearch = '/smart-search';
  static const String discoverDetails = '/discover/details';
  static const String discoverMap = '/discover/map';
  static const String discoverResults = '/discover/results';
  static const String scenarioBuilder = '/scenario-builder';
  static const String favorites = '/favorites';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String workspaceSwitcher = '/settings/workspace';
  static const String professionalPage = '/page';
  static const String professionalPageContent = '/page/content';
  static const String professionalPageCreate = '/page/create';
  static const String professionalPageAccount = '/page/account';
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
}
