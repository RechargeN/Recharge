import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_functions_transport.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/create/application/create_runtime_defaults.dart';
import '../../features/create/application/route_content_publication_controller.dart';
import '../../features/create/data/file_event_publication_journal.dart';
import '../../features/create/data/file_route_content_publication_journal.dart';
import '../../features/create/data/functions_event_publication_gateway.dart';
import '../../features/create/data/functions_route_distribution_gateway.dart';
import '../../features/create/data/repositories/route_sync_client.dart';
import '../../features/create/domain/entities/create_draft_entity.dart';
import '../../features/create/domain/entities/publisher_ref.dart';
import '../../features/create/domain/repositories/create_repository.dart';
import '../../features/create/domain/repositories/event_publication_gateway.dart';
import '../../features/create/domain/repositories/route_content_publication_gateway.dart';
import '../../features/create/domain/repositories/route_sync_repository.dart';
import '../../features/media/data/functions_media_upload_gateway.dart';
import 'backend_binding_manifest.dart';
import 'booking_backend_selection.dart';
import 'booking_test_entry_guard.dart';
import 'event_publication_composition.dart';
import 'media_composition.dart';
import 'service_locator.dart';

/// Compile-time switch of its own (J2):
/// `--dart-define=RECHARGE_TEST_ROUTE_PUBLICATION=true`.
const bool routePublicationTestEntryDefined = bool.fromEnvironment(
  'RECHARGE_TEST_ROUTE_PUBLICATION',
);

/// Default-off test entry for the Route publication path (J2). All four
/// conditions hold at once for the route, every Route, Content and Media
/// command: the define is `true`, the build is not release, the binding is
/// `testBackend`, and the endpoint is the loopback Emulator.
final class RoutePublicationTestEntryGuard
    implements EventPublicationCommandGate, MediaCommandGate {
  RoutePublicationTestEntryGuard({
    required this.flag,
    required this.releaseMode,
    required BookingBackendBindingController binding,
  }) : _binding = binding;

  factory RoutePublicationTestEntryGuard.fromEnvironment(
    BookingBackendBindingController binding,
  ) => RoutePublicationTestEntryGuard(
    flag: routePublicationTestEntryDefined,
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
      throw StateError('Route publication test entry is not enabled');
    }
  }
}

String? routePublicationTestEntryRedirect(
  RoutePublicationTestEntryGuard? guard, {
  required String fallback,
}) => guard != null && guard.allowed ? null : fallback;

/// The J1 Route owner surfaces, behind this entry's guard only.
RouteInvoke routePublicationInvoke({
  required RoutePublicationTestEntryGuard guard,
  required BookingCallablePort port,
}) => (surface, request) async {
  if (!guard.allowed ||
      !const <String>['routeCommandV1', 'routeQueryV1'].contains(surface)) {
    throw const RouteSyncFailure('test_entry_disabled');
  }
  try {
    return await port.invoke(surface, request);
  } on BookingCallableFailure catch (error) {
    throw RouteSyncFailure(error.code);
  }
};

/// The user's current Create draft, read through the Create repository.
final class CreateRepositoryRouteDraftSource implements RouteDraftSource {
  const CreateRepositoryRouteDraftSource(this._repository, this._userId);

  final CreateRepository _repository;
  final String _userId;

  @override
  Future<CreateDraftEntity?> current() => _repository.loadDraft(_userId);
}

/// Wires the controller from explicit parts (used by tests and production).
RouteContentPublicationController routeContentPublicationControllerFor({
  required String accountId,
  required String defaultContentLocale,
  required PublisherRef publisherRef,
  required BookingCallablePort port,
  required RoutePublicationTestEntryGuard guard,
  required RouteDraftSource drafts,
  required RouteSyncRepository sync,
  required File journalFile,
  EventCoverSource mediaSource = const FileEventCoverSource(),
}) {
  final ContentCallablePort content = BookingPortContentAdapter(port);
  return RouteContentPublicationController(
    accountId: accountId,
    defaultContentLocale: defaultContentLocale,
    publisherRef: publisherRef,
    drafts: drafts,
    sync: sync,
    distribution: FunctionsRouteDistributionGateway(
      port: content,
      gate: guard,
      accountId: accountId,
    ),
    content: FunctionsEventPublicationGateway(
      port: content,
      gate: guard,
      typeId: 'route',
    ),
    uploader: MediaEventCoverUploader(
      mediaUploadGatewayFor(port: port, gate: guard),
    ),
    mediaSource: mediaSource,
    journal: FileRouteContentPublicationJournal(journalFile),
    gate: guard,
  );
}

/// Builds the controller from the real `testBackend` runtime, or null unless
/// the whole test entry is allowed. [publisherRef] is the active workspace's
/// publisher (personal profile or Professional Page, RP-04).
Future<RouteContentPublicationController?>
createRouteContentPublicationController({
  required String userId,
  required PublisherRef? publisherRef,
}) async {
  if (!sl.isRegistered<RoutePublicationTestEntryGuard>()) return null;
  final RoutePublicationTestEntryGuard guard =
      sl<RoutePublicationTestEntryGuard>();
  if (!guard.allowed) return null;
  final BookingTransportRuntime runtime = await sl
      .getAsync<BookingTransportRuntime>();
  final BookingCallablePort? port = runtime.port;
  if (!runtime.remoteCommandsEnabled || port == null) return null;
  final Directory support = await sl<BookingSupportDirectoryProvider>()();
  final String separator = Platform.pathSeparator;
  final String installationId = await sl<BookingInstallationIdProvider>()
      .current();
  return routeContentPublicationControllerFor(
    accountId: userId,
    defaultContentLocale: sl<CreateRuntimeDefaults>().defaultContentLocale,
    publisherRef: publisherRef != null && publisherRef.isValid
        ? publisherRef
        : PublisherRef(type: PublisherType.user, id: userId),
    port: port,
    guard: guard,
    drafts: CreateRepositoryRouteDraftSource(sl<CreateRepository>(), userId),
    sync: RouteSyncClient(
      invoke: routePublicationInvoke(guard: guard, port: port),
      storage: sl<FlutterSecureStorage>(),
      installationId: installationId,
      currentOwner: () => userId,
    ),
    journalFile: File(
      '${support.path}${separator}content${separator}route-publications-v1.json',
    ),
  );
}
