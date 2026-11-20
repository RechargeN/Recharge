import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/create/application/event_publication_controller.dart';
import '../../features/create/data/file_event_publication_journal.dart';
import '../../features/create/data/functions_event_publication_gateway.dart';
import '../../features/create/domain/entities/create_draft_entity.dart';
import '../../features/create/domain/entities/event_publication.dart';
import '../../features/create/domain/entities/publisher_ref.dart';
import '../../features/create/domain/repositories/create_repository.dart';
import '../../features/create/domain/repositories/event_publication_gateway.dart';
import '../../features/media/data/functions_media_upload_gateway.dart';
import '../../features/media/domain/repositories/media_upload_gateway.dart';
import 'backend_binding_manifest.dart';
import 'booking_backend_selection.dart';
import 'booking_test_entry_guard.dart';
import 'media_composition.dart';
import 'dev_content_media_port.dart';
import 'service_locator.dart';

/// Compile-time switch, separate from the Booking one. `bool.fromEnvironment`
/// only recognises `true`: `--dart-define=RECHARGE_TEST_EVENT_PUBLICATION=true`.
const bool eventPublicationTestEntryDefined = bool.fromEnvironment(
  'RECHARGE_TEST_EVENT_PUBLICATION',
);

/// Default-off test entry for the Event publication path (C3). All four
/// conditions must hold at once, and the same check protects the route, every
/// Content command and the cover upload: the define is `true`, the build is not
/// release, the binding is `testBackend`, and the endpoint is the loopback
/// `demo-recharge/europe-west1` Emulator.
final class EventPublicationTestEntryGuard
    implements EventPublicationCommandGate, MediaCommandGate {
  EventPublicationTestEntryGuard({
    required this.flag,
    required this.releaseMode,
    required BookingBackendBindingController binding,
    this.devFlag = false,
    this.devPort,
  }) : _binding = binding;

  factory EventPublicationTestEntryGuard.fromEnvironment(
    BookingBackendBindingController binding,
  ) => EventPublicationTestEntryGuard(
    flag: eventPublicationTestEntryDefined,
    releaseMode: kReleaseMode,
    binding: binding,
    devFlag: eventPublicationTestEntryDefined && n3a2DevPlaceDraftDefined,
    devPort: sl.isRegistered<DevContentMediaPort>()
        ? sl<DevContentMediaPort>()
        : null,
  );

  /// Owner decision 2026-11-19 (publish without pre-review): the dev/stage
  /// cloud Content runtime over the N2c Session, as the Place path (N3a.2).
  final bool devFlag;
  final DevContentMediaPort? devPort;
  bool get devCloudAllowed => devFlag && !releaseMode && devPort != null;

  final bool flag;
  final bool releaseMode;
  final BookingBackendBindingController _binding;

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
      throw StateError('Event publication test entry is not enabled');
    }
  }
}

/// Route guard: where to send a visitor of the test route, or null to let them
/// in. A missing guard (nothing registered) is a refusal.
String? eventPublicationTestEntryRedirect(
  EventPublicationTestEntryGuard? guard, {
  required String fallback,
}) => guard != null && guard.allowed ? null : fallback;

/// Lets Content use the authenticated Functions transport without the Create
/// feature importing the Booking feature.
final class BookingPortContentAdapter implements ContentCallablePort {
  const BookingPortContentAdapter(this._port);

  final BookingCallablePort _port;

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> data,
  ) async {
    try {
      return await _port.invoke(callableName, data);
    } on BookingCallableFailure catch (error) {
      throw ContentTransportFailure(error.code);
    }
  }
}

/// The Event cover goes through the C1 Media adapter, gated by this entry.
final class MediaEventCoverUploader implements EventCoverUploader {
  const MediaEventCoverUploader(this._media);

  final MediaUploadGateway _media;

  @override
  Future<String> upload({
    required String intentId,
    required Uint8List bytes,
    required String declaredMediaType,
    required PublisherRef publisherRef,
    required String contentId,
  }) async {
    final MediaUploadResult result = await _media.upload(
      MediaUploadRequest(
        intentId: intentId,
        bytes: bytes,
        declaredMediaType: declaredMediaType,
        publisherType: publisherRef.type.wireName,
        publisherId: publisherRef.id,
        contentId: contentId,
      ),
    );
    switch (result.outcome) {
      case MediaUploadOutcome.ready:
        return result.assetId!;
      case MediaUploadOutcome.rejected:
        throw EventPublicationRejected(result.failureCode ?? 'media_rejected');
      case MediaUploadOutcome.unavailable:
        throw const EventPublicationUnavailable('media_unavailable');
    }
  }
}

/// The user's current Create draft, read through the Create repository.
final class CreateRepositoryEventDraftSource implements EventDraftSource {
  const CreateRepositoryEventDraftSource(this._repository, this._userId);

  final CreateRepository _repository;
  final String _userId;

  @override
  Future<CreateDraftEntity?> current() => _repository.loadDraft(_userId);
}

/// Wires the controller from explicit parts (used by tests and production).
EventPublicationController eventPublicationControllerFor({
  required BookingCallablePort port,
  required EventPublicationTestEntryGuard guard,
  required EventDraftSource drafts,
  required File journalFile,
  EventCoverSource coverSource = const FileEventCoverSource(),
}) => EventPublicationController(
  drafts: drafts,
  gateway: FunctionsEventPublicationGateway(
    port: BookingPortContentAdapter(port),
    gate: guard,
  ),
  covers: MediaEventCoverUploader(
    mediaUploadGatewayFor(port: port, gate: guard),
  ),
  coverSource: coverSource,
  journal: FileEventPublicationJournal(journalFile),
  gate: guard,
);

/// Builds the controller from the real `testBackend` runtime and the user's
/// Create repository, or null unless the whole test entry is allowed.
Future<EventPublicationController?> createEventPublicationController({
  required String userId,
}) async {
  if (!sl.isRegistered<EventPublicationTestEntryGuard>()) return null;
  final EventPublicationTestEntryGuard guard =
      sl<EventPublicationTestEntryGuard>();
  if (!guard.allowed) return null;
  final BookingCallablePort? port;
  if (guard.devCloudAllowed) {
    port = guard.devPort!.port;
  } else {
    final BookingTransportRuntime runtime = await sl
        .getAsync<BookingTransportRuntime>();
    port = runtime.remoteCommandsEnabled ? runtime.port : null;
  }
  if (port == null) return null;
  final Directory support = await sl<BookingSupportDirectoryProvider>()();
  final String separator = Platform.pathSeparator;
  return eventPublicationControllerFor(
    port: port,
    guard: guard,
    drafts: CreateRepositoryEventDraftSource(sl<CreateRepository>(), userId),
    journalFile: File(
      '${support.path}${separator}content${separator}event-publications-v1.json',
    ),
  );
}
