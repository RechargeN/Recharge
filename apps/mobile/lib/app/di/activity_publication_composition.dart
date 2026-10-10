import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/create/application/activity_publication_controller.dart';
import '../../features/create/data/file_event_publication_journal.dart';
import '../../features/create/data/file_activity_publication_journal.dart';
import '../../features/create/data/functions_event_publication_gateway.dart';
import '../../features/create/domain/entities/create_draft_entity.dart';
import '../../features/create/domain/repositories/create_repository.dart';
import '../../features/create/domain/repositories/event_publication_gateway.dart';
import '../../features/create/domain/repositories/activity_publication_gateway.dart';
import '../../features/media/data/functions_media_upload_gateway.dart';
import 'backend_binding_manifest.dart';
import 'booking_backend_selection.dart';
import 'booking_test_entry_guard.dart';
import 'event_publication_composition.dart';
import 'media_composition.dart';
import 'service_locator.dart';

/// Compile-time switch of its own, separate from the Booking, Event and Place
/// ones. `bool.fromEnvironment` only recognises `true`:
/// `--dart-define=RECHARGE_TEST_ACTIVITY_PUBLICATION=true`.
const bool activityPublicationTestEntryDefined = bool.fromEnvironment(
  'RECHARGE_TEST_ACTIVITY_PUBLICATION',
);

/// Default-off test entry for the Recharge Activity publication path (D3.2
/// §5.1). All four conditions must hold at once, and the same check protects
/// the route, every Content command and every Media upload: the define is
/// `true`, the build is not release, the binding is `testBackend`, and the
/// endpoint is the loopback `demo-recharge/europe-west1` Emulator.
final class ActivityPublicationTestEntryGuard
    implements
        ActivityPublicationCommandGate,
        EventPublicationCommandGate,
        MediaCommandGate {
  ActivityPublicationTestEntryGuard({
    required this.flag,
    required this.releaseMode,
    required BookingBackendBindingController binding,
  }) : _binding = binding;

  factory ActivityPublicationTestEntryGuard.fromEnvironment(
    BookingBackendBindingController binding,
  ) => ActivityPublicationTestEntryGuard(
    flag: activityPublicationTestEntryDefined,
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
      throw StateError('Activity publication test entry is not enabled');
    }
  }
}

/// Route guard: where to send a visitor of the test route, or null to let them
/// in. A missing guard (nothing registered) is a refusal.
String? activityPublicationTestEntryRedirect(
  ActivityPublicationTestEntryGuard? guard, {
  required String fallback,
}) => guard != null && guard.allowed ? null : fallback;

/// The user's current Create draft, read through the Create repository.
final class CreateRepositoryActivityDraftSource implements ActivityDraftSource {
  const CreateRepositoryActivityDraftSource(this._repository, this._userId);

  final CreateRepository _repository;
  final String _userId;

  @override
  Future<CreateDraftEntity?> current() => _repository.loadDraft(_userId);
}

/// Wires the controller from explicit parts (used by tests and production).
ActivityPublicationController activityPublicationControllerFor({
  required String accountId,
  required BookingCallablePort port,
  required ActivityPublicationTestEntryGuard guard,
  required ActivityDraftSource drafts,
  required File journalFile,
  EventCoverSource mediaSource = const FileEventCoverSource(),
}) {
  final FunctionsEventPublicationGateway gateway =
      FunctionsEventPublicationGateway(
        port: BookingPortContentAdapter(port),
        gate: guard,
        typeId: 'activity',
      );
  return ActivityPublicationController(
    accountId: accountId,
    drafts: drafts,
    gateway: gateway,
    reader: gateway,
    // Every photo goes through the C1 Media adapter, gated by this entry.
    uploader: MediaEventCoverUploader(
      mediaUploadGatewayFor(port: port, gate: guard),
    ),
    mediaSource: mediaSource,
    journal: FileActivityPublicationJournal(journalFile),
    gate: guard,
  );
}

/// Builds the controller from the real `testBackend` runtime and the user's
/// Create repository, or null unless the whole test entry is allowed.
Future<ActivityPublicationController?> createActivityPublicationController({
  required String userId,
}) async {
  if (!sl.isRegistered<ActivityPublicationTestEntryGuard>()) return null;
  final ActivityPublicationTestEntryGuard guard =
      sl<ActivityPublicationTestEntryGuard>();
  if (!guard.allowed) return null;
  final BookingTransportRuntime runtime = await sl
      .getAsync<BookingTransportRuntime>();
  final BookingCallablePort? port = runtime.port;
  if (!runtime.remoteCommandsEnabled || port == null) return null;
  final Directory support = await sl<BookingSupportDirectoryProvider>()();
  final String separator = Platform.pathSeparator;
  return activityPublicationControllerFor(
    accountId: userId,
    port: port,
    guard: guard,
    drafts: CreateRepositoryActivityDraftSource(sl<CreateRepository>(), userId),
    journalFile: File(
      '${support.path}${separator}content${separator}activity-publications-v1.json',
    ),
  );
}
