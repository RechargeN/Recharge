import '../../features/booking/application/event_booking_controller.dart';
import '../../features/booking/data/booking_transport_event_booking_gateway.dart';
import '../../features/booking/domain/repositories/event_booking_gateway.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/booking/data/file_event_booking_operation_store.dart';
import '../testing/seeded_event_fixture.dart';
import 'booking_test_entry_guard.dart';
import 'service_locator.dart';
import 'dart:io';

/// Builds the Event Booking controller from the real `testBackend` runtime.
/// Returns null unless the whole test entry is allowed and the runtime really
/// is the Emulator transport, so nothing is wired in any other mode.
Future<EventBookingController?> createEventBookingController() async {
  if (!sl.isRegistered<BookingTestEntryGuard>()) return null;
  final BookingTestEntryGuard guard = sl<BookingTestEntryGuard>();
  if (!guard.allowed) return null;
  final BookingTransportRuntime runtime = await sl
      .getAsync<BookingTransportRuntime>();
  final adapter = runtime.adapter;
  final port = runtime.port;
  if (!runtime.remoteCommandsEnabled || adapter == null || port == null) {
    return null;
  }
  final Directory support = await sl<BookingSupportDirectoryProvider>()();
  final String separator = Platform.pathSeparator;
  return EventBookingController(
    gateway: BookingTransportEventBookingGateway(
      adapter: adapter,
      port: port,
      gate: guard,
    ),
    store: FileEventBookingOperationStore(
      File(
        '${support.path}${separator}booking${separator}event-operations-v1.json',
      ),
    ),
    occurrenceId: seededBookingOccurrenceId,
    inventoryPoolId: seededBookingPoolId,
    channel: seededBookingChannel,
    eventRevision: seededBookingEventRevision,
  );
}

/// E2b: the controller for one exact occurrence of a published Content Event.
/// Pool, channel and revision come from Booking's own terms of that
/// occurrence, never from the Catalog or the client. Null unless the whole test
/// entry is allowed and Booking offers terms for the occurrence.
Future<EventBookingController?> createEventBookingControllerFor({
  required String eventId,
  required String occurrenceId,
  String? channel,
}) async {
  if (!sl.isRegistered<BookingTestEntryGuard>()) return null;
  final BookingTestEntryGuard guard = sl<BookingTestEntryGuard>();
  if (!guard.allowed) return null;
  final BookingTransportRuntime runtime = await sl
      .getAsync<BookingTransportRuntime>();
  final adapter = runtime.adapter;
  final port = runtime.port;
  if (!runtime.remoteCommandsEnabled || adapter == null || port == null) {
    return null;
  }
  final gateway = BookingTransportEventBookingGateway(
    adapter: adapter,
    port: port,
    gate: guard,
  );
  final EventBookingTermsResult result = await gateway.termsFor(
    eventId: eventId,
    occurrenceId: occurrenceId,
    channel: channel,
  );
  final EventBookingTerms? terms = result.terms;
  if (result.outcome != EventBookingTermsOutcome.succeeded || terms == null) {
    return null;
  }
  final Directory support = await sl<BookingSupportDirectoryProvider>()();
  final String separator = Platform.pathSeparator;
  return EventBookingController(
    gateway: gateway,
    store: FileEventBookingOperationStore(
      File(
        '${support.path}${separator}booking${separator}event-operations-v1.json',
      ),
    ),
    occurrenceId: terms.occurrenceId,
    inventoryPoolId: terms.inventoryPoolId,
    channel: terms.channel,
    eventRevision: terms.eventRevision,
    // F2: the party limit from Booking terms bounds the seat selector.
    maxParticipantUnits: terms.maxParticipantUnits,
  );
}
