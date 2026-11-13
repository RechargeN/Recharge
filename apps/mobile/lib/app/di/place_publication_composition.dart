import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/create/application/create_runtime_defaults.dart';
import '../../features/create/application/place_publication_controller.dart';
import '../../features/create/data/file_event_publication_journal.dart';
import '../../features/create/data/file_place_publication_journal.dart';
import '../../features/create/data/functions_event_publication_gateway.dart';
import '../../features/create/domain/entities/create_draft_entity.dart';
import '../../features/create/domain/repositories/create_repository.dart';
import '../../features/create/domain/repositories/event_publication_gateway.dart';
import '../../features/create/domain/repositories/place_publication_gateway.dart';
import '../../features/media/data/functions_media_upload_gateway.dart';
import 'backend_binding_manifest.dart';
import 'booking_backend_selection.dart';
import 'booking_test_entry_guard.dart';
import 'dev_content_media_port.dart';
import 'event_publication_composition.dart';
import 'media_composition.dart';
import 'service_locator.dart';

/// Compile-time switch of its own, separate from the Booking and Event ones.
/// `bool.fromEnvironment` only recognises `true`:
/// `--dart-define=RECHARGE_TEST_PLACE_PUBLICATION=true`.
const bool placePublicationTestEntryDefined = bool.fromEnvironment(
  'RECHARGE_TEST_PLACE_PUBLICATION',
);

/// Default-off test entry for the Place publication path (D3.1 §5.1). All
/// four conditions must hold at once, and the same check protects the route,
/// every Content command and every Media upload: the define is `true`, the
/// build is not release, the binding is `testBackend`, and the endpoint is the
/// loopback `demo-recharge/europe-west1` Emulator.
final class PlacePublicationTestEntryGuard
    implements
        PlacePublicationCommandGate,
        EventPublicationCommandGate,
        MediaCommandGate {
  PlacePublicationTestEntryGuard({
    required this.flag,
    required this.releaseMode,
    required BookingBackendBindingController binding,
    this.devFlag = false,
    this.devPort,
  }) : _binding = binding;

  factory PlacePublicationTestEntryGuard.fromEnvironment(
    BookingBackendBindingController binding,
  ) => PlacePublicationTestEntryGuard(
    flag: placePublicationTestEntryDefined,
    releaseMode: kReleaseMode,
    binding: binding,
    devFlag: n3a2DevPlaceDraftDefined,
    devPort: sl.isRegistered<DevContentMediaPort>()
        ? sl<DevContentMediaPort>()
        : null,
  );

  final bool flag;
  final bool releaseMode;
  final BookingBackendBindingController _binding;

  /// N3a.2: the dev-cloud Place draft path (own define, debug dev build, the
  /// dev auth bundle's port). Publication itself is refused by that runtime.
  final bool devFlag;
  final DevContentMediaPort? devPort;

  bool get devCloudAllowed => devFlag && !releaseMode && devPort != null;

  @override
  bool get allowed =>
      devCloudAllowed ||
      (flag &&
          !releaseMode &&
          _binding.mode == BackendBindingMode.testBackend &&
          isLoopbackDemoEmulatorBinding(_binding));

  @override
  void assertAllowed() {
    if (!allowed) {
      throw StateError('Place publication test entry is not enabled');
    }
  }
}

/// Route guard: where to send a visitor of the test route, or null to let them
/// in. A missing guard (nothing registered) is a refusal.
String? placePublicationTestEntryRedirect(
  PlacePublicationTestEntryGuard? guard, {
  required String fallback,
}) => guard != null && guard.allowed ? null : fallback;

/// The user's current Create draft, read through the Create repository.
final class CreateRepositoryPlaceDraftSource implements PlaceDraftSource {
  const CreateRepositoryPlaceDraftSource(this._repository, this._userId);

  final CreateRepository _repository;
  final String _userId;

  @override
  Future<CreateDraftEntity?> current() => _repository.loadDraft(_userId);
}

/// Wires the controller from explicit parts (used by tests and production).
PlacePublicationController placePublicationControllerFor({
  required String accountId,
  required BookingCallablePort port,
  required PlacePublicationTestEntryGuard guard,
  required PlaceDraftSource drafts,
  required File journalFile,
  required String marketCurrencyCode,
  EventCoverSource mediaSource = const FileEventCoverSource(),
}) {
  final FunctionsEventPublicationGateway gateway =
      FunctionsEventPublicationGateway(
        port: BookingPortContentAdapter(port),
        gate: guard,
        typeId: 'place',
      );
  return PlacePublicationController(
    accountId: accountId,
    drafts: drafts,
    gateway: gateway,
    reader: gateway,
    // Every photo goes through the C1 Media adapter, gated by this entry.
    uploader: MediaEventCoverUploader(
      mediaUploadGatewayFor(port: port, gate: guard),
    ),
    mediaSource: mediaSource,
    journal: FilePlacePublicationJournal(journalFile),
    gate: guard,
    marketCurrencyCode: marketCurrencyCode,
  );
}

/// Builds the controller from the real `testBackend` runtime and the user's
/// Create repository, or null unless the whole test entry is allowed.
Future<PlacePublicationController?> createPlacePublicationController({
  required String userId,
}) async {
  if (!sl.isRegistered<PlacePublicationTestEntryGuard>()) return null;
  final PlacePublicationTestEntryGuard guard =
      sl<PlacePublicationTestEntryGuard>();
  if (!guard.allowed) return null;
  final BookingCallablePort? port;
  if (guard.devCloudAllowed) {
    // N3a.2: the dev-cloud Content + Media codebase over the N2c Session.
    port = guard.devPort!.port;
  } else {
    final BookingTransportRuntime runtime = await sl
        .getAsync<BookingTransportRuntime>();
    port = runtime.remoteCommandsEnabled ? runtime.port : null;
  }
  if (port == null) return null;
  final Directory support = await sl<BookingSupportDirectoryProvider>()();
  final String separator = Platform.pathSeparator;
  return placePublicationControllerFor(
    accountId: userId,
    // The market currency of the Create runtime, never a literal (AGENTS 5).
    marketCurrencyCode: sl<CreateRuntimeDefaults>().currency,
    port: port,
    guard: guard,
    drafts: CreateRepositoryPlaceDraftSource(sl<CreateRepository>(), userId),
    journalFile: File(
      '${support.path}${separator}content${separator}place-publications-v1.json',
    ),
  );
}
