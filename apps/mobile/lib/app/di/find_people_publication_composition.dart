import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/create/application/create_runtime_defaults.dart';
import '../../features/create/application/find_people_publication_controller.dart';
import '../../features/create/data/file_find_people_publication_journal.dart';
import '../../features/create/data/functions_event_publication_gateway.dart';
import '../../features/create/data/functions_find_people_consent_gateway.dart';
import '../../features/create/domain/entities/create_draft_entity.dart';
import '../../features/create/domain/repositories/create_repository.dart';
import '../../features/create/domain/repositories/event_publication_gateway.dart';
import '../../features/create/domain/repositories/find_people_publication_gateway.dart';
import 'backend_binding_manifest.dart';
import 'booking_backend_selection.dart';
import 'booking_test_entry_guard.dart';
import 'event_publication_composition.dart';
import 'service_locator.dart';

/// Compile-time switch of its own, separate from every other test entry.
/// `bool.fromEnvironment` only recognises `true`:
/// `--dart-define=RECHARGE_TEST_FIND_PEOPLE_PUBLICATION=true`.
const bool findPeoplePublicationTestEntryDefined = bool.fromEnvironment(
  'RECHARGE_TEST_FIND_PEOPLE_PUBLICATION',
);

/// Default-off test entry for the Find People publication path (D3.7). All
/// four conditions must hold at once, and the same check protects the route,
/// every Content command and every consent command: the define is `true`, the
/// build is not release, the binding is `testBackend`, and the endpoint is the
/// loopback `demo-recharge/europe-west1` Emulator.
final class FindPeoplePublicationTestEntryGuard
    implements FindPeoplePublicationCommandGate, EventPublicationCommandGate {
  FindPeoplePublicationTestEntryGuard({
    required this.flag,
    required this.releaseMode,
    required BookingBackendBindingController binding,
  }) : _binding = binding;

  factory FindPeoplePublicationTestEntryGuard.fromEnvironment(
    BookingBackendBindingController binding,
  ) => FindPeoplePublicationTestEntryGuard(
    flag: findPeoplePublicationTestEntryDefined,
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
      throw StateError('Find People publication test entry is not enabled');
    }
  }
}

/// Route guard: where to send a visitor of the test route, or null to let them
/// in. A missing guard (nothing registered) is a refusal.
String? findPeoplePublicationTestEntryRedirect(
  FindPeoplePublicationTestEntryGuard? guard, {
  required String fallback,
}) => guard != null && guard.allowed ? null : fallback;

/// The user's current Create draft, read through the Create repository.
final class CreateRepositoryFindPeopleDraftSource
    implements FindPeopleDraftSource {
  const CreateRepositoryFindPeopleDraftSource(this._repository, this._userId);

  final CreateRepository _repository;
  final String _userId;

  @override
  Future<CreateDraftEntity?> current() => _repository.loadDraft(_userId);
}

/// Wires the controller from explicit parts (used by tests and production).
FindPeoplePublicationController findPeoplePublicationControllerFor({
  required String accountId,
  required String defaultContentLocale,
  required BookingCallablePort port,
  required FindPeoplePublicationTestEntryGuard guard,
  required FindPeopleDraftSource drafts,
  required File journalFile,
}) {
  final ContentCallablePort content = BookingPortContentAdapter(port);
  final FunctionsEventPublicationGateway gateway =
      FunctionsEventPublicationGateway(
        port: content,
        gate: guard,
        typeId: 'find_people',
      );
  return FindPeoplePublicationController(
    accountId: accountId,
    defaultContentLocale: defaultContentLocale,
    drafts: drafts,
    gateway: gateway,
    reader: gateway,
    consents: FunctionsFindPeopleConsentGateway(port: content, gate: guard),
    journal: FileFindPeoplePublicationJournal(journalFile),
    gate: guard,
  );
}

/// Builds the controller from the real `testBackend` runtime and the user's
/// Create repository, or null unless the whole test entry is allowed.
Future<FindPeoplePublicationController?> createFindPeoplePublicationController({
  required String userId,
}) async {
  if (!sl.isRegistered<FindPeoplePublicationTestEntryGuard>()) return null;
  final FindPeoplePublicationTestEntryGuard guard =
      sl<FindPeoplePublicationTestEntryGuard>();
  if (!guard.allowed) return null;
  final BookingTransportRuntime runtime = await sl
      .getAsync<BookingTransportRuntime>();
  final BookingCallablePort? port = runtime.port;
  if (!runtime.remoteCommandsEnabled || port == null) return null;
  final Directory support = await sl<BookingSupportDirectoryProvider>()();
  final String separator = Platform.pathSeparator;
  return findPeoplePublicationControllerFor(
    accountId: userId,
    defaultContentLocale: sl<CreateRuntimeDefaults>().defaultContentLocale,
    port: port,
    guard: guard,
    drafts: CreateRepositoryFindPeopleDraftSource(
      sl<CreateRepository>(),
      userId,
    ),
    journalFile: File(
      '${support.path}${separator}content${separator}find-people-publications-v1.json',
    ),
  );
}
