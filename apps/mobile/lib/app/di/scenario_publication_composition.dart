import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/create/application/create_runtime_defaults.dart';
import '../../features/create/application/scenario_publication_controller.dart';
import '../../features/create/data/file_event_publication_journal.dart';
import '../../features/create/data/file_scenario_publication_journal.dart';
import '../../features/create/data/functions_event_publication_gateway.dart';
import '../../features/create/data/functions_scenario_planning_gateway.dart';
import '../../features/create/domain/entities/create_draft_entity.dart';
import '../../features/create/domain/repositories/create_repository.dart';
import '../../features/create/domain/repositories/event_publication_gateway.dart';
import '../../features/create/domain/repositories/scenario_publication_gateway.dart';
import '../../features/media/data/functions_media_upload_gateway.dart';
import 'backend_binding_manifest.dart';
import 'booking_backend_selection.dart';
import 'booking_test_entry_guard.dart';
import 'event_publication_composition.dart';
import 'media_composition.dart';
import 'service_locator.dart';

/// Compile-time switch of its own (I3):
/// `--dart-define=RECHARGE_TEST_SCENARIO_PUBLICATION=true`.
const bool scenarioPublicationTestEntryDefined = bool.fromEnvironment(
  'RECHARGE_TEST_SCENARIO_PUBLICATION',
);

/// Default-off test entry for the Scenario publication path (I3). All four
/// conditions hold at once for the route, every Planning and Content command
/// and every Media upload: the define is `true`, the build is not release, the
/// binding is `testBackend`, and the endpoint is the loopback Emulator.
final class ScenarioPublicationTestEntryGuard
    implements EventPublicationCommandGate, MediaCommandGate {
  ScenarioPublicationTestEntryGuard({
    required this.flag,
    required this.releaseMode,
    required BookingBackendBindingController binding,
  }) : _binding = binding;

  factory ScenarioPublicationTestEntryGuard.fromEnvironment(
    BookingBackendBindingController binding,
  ) => ScenarioPublicationTestEntryGuard(
    flag: scenarioPublicationTestEntryDefined,
    releaseMode: kReleaseMode,
    binding: binding,
  );

  final bool flag;
  final bool releaseMode;
  final BookingBackendBindingController _binding;

  @override
  bool get allowed =>
      flag &&
      !releaseMode &&
      _binding.mode == BackendBindingMode.testBackend &&
      isLoopbackDemoEmulatorBinding(_binding);

  @override
  void assertAllowed() {
    if (!allowed) {
      throw StateError('Scenario publication test entry is not enabled');
    }
  }
}

String? scenarioPublicationTestEntryRedirect(
  ScenarioPublicationTestEntryGuard? guard, {
  required String fallback,
}) => guard != null && guard.allowed ? null : fallback;

/// The user's current Create draft, read through the Create repository.
final class CreateRepositoryScenarioDraftSource implements ScenarioDraftSource {
  const CreateRepositoryScenarioDraftSource(this._repository, this._userId);

  final CreateRepository _repository;
  final String _userId;

  @override
  Future<CreateDraftEntity?> current() => _repository.loadDraft(_userId);
}

/// Wires the controller from explicit parts (used by tests and production).
ScenarioPublicationController scenarioPublicationControllerFor({
  required String accountId,
  required String defaultContentLocale,
  required BookingCallablePort port,
  required ScenarioPublicationTestEntryGuard guard,
  required ScenarioDraftSource drafts,
  required File journalFile,
  EventCoverSource mediaSource = const FileEventCoverSource(),
}) {
  final ContentCallablePort content = BookingPortContentAdapter(port);
  return ScenarioPublicationController(
    accountId: accountId,
    defaultContentLocale: defaultContentLocale,
    drafts: drafts,
    planning: FunctionsScenarioPlanningGateway(
      port: content,
      gate: guard,
      accountId: accountId,
    ),
    content: FunctionsEventPublicationGateway(
      port: content,
      gate: guard,
      typeId: 'scenario',
    ),
    uploader: MediaEventCoverUploader(
      mediaUploadGatewayFor(port: port, gate: guard),
    ),
    mediaSource: mediaSource,
    journal: FileScenarioPublicationJournal(journalFile),
    gate: guard,
  );
}

/// Builds the controller from the real `testBackend` runtime, or null unless
/// the whole test entry is allowed.
Future<ScenarioPublicationController?> createScenarioPublicationController({
  required String userId,
}) async {
  if (!sl.isRegistered<ScenarioPublicationTestEntryGuard>()) return null;
  final ScenarioPublicationTestEntryGuard guard =
      sl<ScenarioPublicationTestEntryGuard>();
  if (!guard.allowed) return null;
  final BookingTransportRuntime runtime = await sl
      .getAsync<BookingTransportRuntime>();
  final BookingCallablePort? port = runtime.port;
  if (!runtime.remoteCommandsEnabled || port == null) return null;
  final Directory support = await sl<BookingSupportDirectoryProvider>()();
  final String separator = Platform.pathSeparator;
  return scenarioPublicationControllerFor(
    accountId: userId,
    defaultContentLocale: sl<CreateRuntimeDefaults>().defaultContentLocale,
    port: port,
    guard: guard,
    drafts: CreateRepositoryScenarioDraftSource(sl<CreateRepository>(), userId),
    journalFile: File(
      '${support.path}${separator}content${separator}scenario-publications-v1.json',
    ),
  );
}
