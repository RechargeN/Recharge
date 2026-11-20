/// N4a/N4b (owner-approved 2026-11-13): the reviewed non-production cloud
/// projects a debug build may bind to, chosen by the Android flavor. The same
/// list exists on the server (`cloud_runtime_projects.ts`); production is
/// never listed, so no flavor can reach it.
enum CloudEnvironment {
  dev(
    flavor: 'dev',
    projectId: 'recharge-dev-n2a01',
    projectNumber: '420479958348',
    firebaseAppName: 'recharge-dev-android',
    storageScope: 'recharge_dev_n2a01',
  ),
  staging(
    flavor: 'stage',
    projectId: 'recharge-staging-y9y2y',
    projectNumber: '30205452447',
    firebaseAppName: 'recharge-stage-android',
    storageScope: 'recharge_staging_y9y2y',
  );

  const CloudEnvironment({
    required this.flavor,
    required this.projectId,
    required this.projectNumber,
    required this.firebaseAppName,
    required this.storageScope,
  });

  final String flavor;
  final String projectId;
  final String projectNumber;
  final String firebaseAppName;

  /// Prefix of device storage; dev keeps its N2c names so a signed-in A34 stays signed in.
  final String storageScope;

  /// The Cloud Functions base of the project (callable protocol over HTTPS).
  String get functionsBase =>
      'https://europe-west1-$projectId.cloudfunctions.net';

  bool isAndroidAppId(String value) =>
      RegExp('^1:$projectNumber:android:[a-f0-9]+\$').hasMatch(value);

  bool isGoogleServerClientId(String value) => RegExp(
    '^$projectNumber-[a-z0-9]+\\.apps\\.googleusercontent\\.com\$',
  ).hasMatch(value);

  /// The cloud project of a flavor, or null (local and any other flavor).
  static CloudEnvironment? forFlavor(String? flavor) {
    for (final CloudEnvironment environment in values) {
      if (environment.flavor == flavor) return environment;
    }
    return null;
  }

  static CloudEnvironment? forFunctionsBase(String value) {
    for (final CloudEnvironment environment in values) {
      if (environment.functionsBase == value) return environment;
    }
    return null;
  }
}
