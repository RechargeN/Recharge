import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/create/application/local_import_controller.dart';
import '../../features/create/data/create_local_import_store.dart';
import '../../features/create/data/datasources/create_local_datasource.dart';
import '../../features/create/data/file_event_publication_journal.dart';
import '../../features/create/data/file_local_import_journal.dart';
import '../../features/create/data/functions_local_import_gateway.dart';
import '../../features/create/data/publication_journals_import_mapping.dart';
import '../../features/create/domain/repositories/create_repository.dart';
import '../../features/create/domain/repositories/event_publication_gateway.dart';
import '../../features/create/domain/repositories/local_import_gateway.dart';
import '../../features/create/domain/repositories/publisher_access_check.dart';
import '../../features/media/data/functions_media_upload_gateway.dart';
import 'backend_binding_manifest.dart';
import 'booking_backend_selection.dart';
import 'booking_test_entry_guard.dart';
import 'event_publication_composition.dart';
import 'media_composition.dart';
import 'service_locator.dart';

/// Compile-time switch of its own, separate from every publication path:
/// `--dart-define=RECHARGE_TEST_LOCAL_IMPORT=true`.
const bool localImportTestEntryDefined = bool.fromEnvironment(
  'RECHARGE_TEST_LOCAL_IMPORT',
);

/// Default-off test entry for the local→server import (D4 §5.6). All four
/// conditions must hold at once, and the same check protects the route, every
/// Content command and every Media upload: the define is `true`, the build is
/// not release, the binding is `testBackend`, and the endpoint is the loopback
/// `demo-recharge/europe-west1` Emulator.
final class LocalImportTestEntryGuard
    implements LocalImportCommandGate, MediaCommandGate {
  LocalImportTestEntryGuard({
    required this.flag,
    required this.releaseMode,
    required BookingBackendBindingController binding,
  }) : _binding = binding;

  factory LocalImportTestEntryGuard.fromEnvironment(
    BookingBackendBindingController binding,
  ) => LocalImportTestEntryGuard(
    flag: localImportTestEntryDefined,
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
    if (!allowed) throw StateError('Local import test entry is not enabled');
  }
}

/// Route guard: where to send a visitor of the test route, or null to let them
/// in. A missing guard (nothing registered) is a refusal.
String? localImportTestEntryRedirect(
  LocalImportTestEntryGuard? guard, {
  required String fallback,
}) => guard != null && guard.allowed ? null : fallback;

/// Wires the controller from explicit parts (used by tests and production).
/// Receipts and sessions live under `<support>/import`; the publication
/// journals it consults are those of the test paths under `<support>/content`.
LocalImportController localImportControllerFor({
  required String accountId,
  required BookingCallablePort port,
  required LocalImportTestEntryGuard guard,
  required LocalImportSource source,
  required LocalImportOriginalStore originals,
  required PublisherAccessCheck publisherAccess,
  required Directory support,
  EventCoverSource mediaSource = const FileEventCoverSource(),
  DateTime Function()? clock,
}) {
  final String separator = Platform.pathSeparator;
  final String importDir = '${support.path}${separator}import$separator';
  return LocalImportController(
    accountId: accountId,
    source: source,
    journal: FileLocalImportJournal(
      receipts: File('${importDir}local-import-receipts-v1.json'),
      sessions: File('${importDir}local-import-sessions-v1.json'),
    ),
    existing: PublicationJournalsImportMapping.inDirectory(
      Directory('${support.path}${separator}content'),
    ),
    gateway: FunctionsLocalImportGateway(
      port: BookingPortContentAdapter(port),
      gate: guard,
    ),
    // Every photo goes through the C1 Media adapter, gated by this entry.
    uploader: MediaEventCoverUploader(
      mediaUploadGatewayFor(port: port, gate: guard),
    ),
    mediaSource: mediaSource,
    publisherAccess: publisherAccess,
    originals: originals,
    gate: guard,
    clock: clock,
  );
}

/// Builds the controller from the real `testBackend` runtime and the user's
/// Create storage, or null unless the whole test entry is allowed.
Future<LocalImportController?> createLocalImportController({
  required String userId,
}) async {
  if (!sl.isRegistered<LocalImportTestEntryGuard>()) return null;
  final LocalImportTestEntryGuard guard = sl<LocalImportTestEntryGuard>();
  if (!guard.allowed) return null;
  final BookingTransportRuntime runtime = await sl
      .getAsync<BookingTransportRuntime>();
  final BookingCallablePort? port = runtime.port;
  if (!runtime.remoteCommandsEnabled || port == null) return null;
  final CreateLocalDataSource datasource = sl<CreateLocalDataSource>();
  return localImportControllerFor(
    accountId: userId,
    port: port,
    guard: guard,
    source: CreateLocalImportSource(
      repository: sl<CreateRepository>(),
      library: datasource,
    ),
    originals: CreateLocalImportOriginalStore(datasource),
    publisherAccess: sl<PublisherAccessCheck>(),
    support: await sl<BookingSupportDirectoryProvider>()(),
  );
}
