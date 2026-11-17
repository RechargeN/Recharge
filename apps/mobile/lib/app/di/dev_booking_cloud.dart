import 'dart:io';

import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_persistence_store.dart';
import '../../features/booking/data/booking_transport_runtime.dart';

/// Debt plan round 1 (2026-11-17): the Booking test entry over the cloud
/// Booking runtime of the flavor's project. Enabled only with
/// `--dart-define=N4C_DEV_BOOKING=true` in a debug dev/stage build, together
/// with `RECHARGE_TEST_BOOKING_ENTRY=true`.
const bool n4cDevBookingDefined = bool.fromEnvironment('N4C_DEV_BOOKING');

/// Builds the cloud Booking runtime over the authenticated dev transport. The
/// operation and receipt journals live next to the Emulator ones, in their
/// own file, so the two never mix.
Future<BookingTransportRuntime> createDevCloudBookingRuntime({
  required BookingCallablePort port,
  required Future<Directory> Function() supportDirectory,
}) async {
  final Directory support = await supportDirectory();
  final String separator = Platform.pathSeparator;
  final FileBookingPersistenceStore persistence = FileBookingPersistenceStore(
    File(
      '${support.path}${separator}booking${separator}cloud-transport-v1.json',
    ),
  );
  return BookingTransportRuntime.devCloud(
    adapter: BookingCallableAdapter(
      port: port,
      operations: persistence.operationStore,
      receipts: persistence.receiptStore,
    ),
    port: port,
  );
}
