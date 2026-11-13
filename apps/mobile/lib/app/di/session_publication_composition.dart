import '../../features/create/application/create_runtime_defaults.dart';
import 'dart:convert';
import '../../features/create/data/models/session_draft_mapper.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/booking/data/booking_callable_adapter.dart';
import '../../features/booking/data/booking_transport_runtime.dart';
import '../../features/create/application/session_publication_controller.dart';
import '../../features/create/data/file_event_publication_journal.dart';
import '../../features/create/data/file_session_publication_journal.dart';
import '../../features/create/data/functions_event_publication_gateway.dart';
import '../../features/create/domain/entities/create_draft_entity.dart';
import '../../features/create/domain/repositories/create_repository.dart';
import '../../features/create/domain/repositories/event_publication_gateway.dart';
import '../../features/create/domain/repositories/session_publication_gateway.dart';
import '../../features/media/data/functions_media_upload_gateway.dart';
import 'backend_binding_manifest.dart';
import 'booking_backend_selection.dart';
import 'booking_test_entry_guard.dart';
import 'event_publication_composition.dart';
import 'media_composition.dart';
import 'service_locator.dart';

/// Compile-time switch of its own, separate from the Booking and Event ones.
/// `bool.fromEnvironment` only recognises `true`:
/// `--dart-define=RECHARGE_TEST_SESSION_PUBLICATION=true`.
const bool sessionPublicationTestEntryDefined = bool.fromEnvironment(
  'RECHARGE_TEST_SESSION_PUBLICATION',
);

/// Default-off test entry for the Session publication path (D3.5 §5.1). All
/// four conditions must hold at once, and the same check protects the route,
/// every Content command and every Media upload: the define is `true`, the
/// build is not release, the binding is `testBackend`, and the endpoint is the
/// loopback `demo-recharge/europe-west1` Emulator.
final class SessionPublicationTestEntryGuard
    implements
        SessionPublicationCommandGate,
        EventPublicationCommandGate,
        MediaCommandGate {
  SessionPublicationTestEntryGuard({
    required this.flag,
    required this.releaseMode,
    required BookingBackendBindingController binding,
  }) : _binding = binding;

  factory SessionPublicationTestEntryGuard.fromEnvironment(
    BookingBackendBindingController binding,
  ) => SessionPublicationTestEntryGuard(
    flag: sessionPublicationTestEntryDefined,
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
      throw StateError('Session publication test entry is not enabled');
    }
  }
}

/// Route guard: where to send a visitor of the test route, or null to let them
/// in. A missing guard (nothing registered) is a refusal.
String? sessionPublicationTestEntryRedirect(
  SessionPublicationTestEntryGuard? guard, {
  required String fallback,
}) => guard != null && guard.allowed ? null : fallback;

/// The user's current Create draft, read through the Create repository.
final class CreateRepositorySessionDraftSource implements SessionDraftSource {
  const CreateRepositorySessionDraftSource(this._repository, this._userId);

  final CreateRepository _repository;
  final String _userId;

  @override
  Future<CreateDraftEntity?> current() async {
    final draft = await _repository.loadDraft(_userId);
    final mirror = draft?.sectionData['session_details'];
    if (draft == null || draft.sessionData == null || mirror == null) {
      return draft;
    }
    // Omit only an exact persistence mirror, never a lossy parsed payload.
    Object? canonical(Object? value) {
      if (value is Map<String, Object?>) {
        final keys = value.keys.toList()..sort();
        return <String, Object?>{
          for (final key in keys) key: canonical(value[key]),
        };
      }
      if (value is List) return value.map(canonical).toList();
      return value;
    }

    if (jsonEncode(canonical(mirror)) !=
        jsonEncode(canonical(SessionDraftMapper.toJson(draft.sessionData!)))) {
      return draft;
    }
    return draft.copyWith(
      sectionData: <String, Object?>{
        for (final entry in draft.sectionData.entries)
          if (entry.key != 'session_details') entry.key: entry.value,
      },
    );
  }
}

/// Wires the controller from explicit parts (used by tests and production).
SessionPublicationController sessionPublicationControllerFor({
  required String accountId,
  required String defaultContentLocale,
  required BookingCallablePort port,
  required SessionPublicationTestEntryGuard guard,
  required SessionDraftSource drafts,
  required File journalFile,
  EventCoverSource mediaSource = const FileEventCoverSource(),
}) {
  final FunctionsEventPublicationGateway gateway =
      FunctionsEventPublicationGateway(
        port: BookingPortContentAdapter(port),
        gate: guard,
        typeId: 'session',
      );
  return SessionPublicationController(
    accountId: accountId,
    defaultContentLocale: defaultContentLocale,
    drafts: drafts,
    gateway: gateway,
    reader: gateway,
    // Every photo goes through the C1 Media adapter, gated by this entry.
    uploader: MediaEventCoverUploader(
      mediaUploadGatewayFor(port: port, gate: guard),
    ),
    mediaSource: mediaSource,
    journal: FileSessionPublicationJournal(journalFile),
    gate: guard,
  );
}

/// Builds the controller from the real `testBackend` runtime and the user's
/// Create repository, or null unless the whole test entry is allowed.
Future<SessionPublicationController?> createSessionPublicationController({
  required String userId,
}) async {
  if (!sl.isRegistered<SessionPublicationTestEntryGuard>()) return null;
  final SessionPublicationTestEntryGuard guard =
      sl<SessionPublicationTestEntryGuard>();
  if (!guard.allowed) return null;
  final BookingTransportRuntime runtime = await sl
      .getAsync<BookingTransportRuntime>();
  final BookingCallablePort? port = runtime.port;
  if (!runtime.remoteCommandsEnabled || port == null) return null;
  final Directory support = await sl<BookingSupportDirectoryProvider>()();
  final String separator = Platform.pathSeparator;
  return sessionPublicationControllerFor(
    accountId: userId,
    defaultContentLocale: sl<CreateRuntimeDefaults>().defaultContentLocale,
    // The market currency of the Create runtime, never a literal (AGENTS 5).
    port: port,
    guard: guard,
    drafts: CreateRepositorySessionDraftSource(sl<CreateRepository>(), userId),
    journalFile: File(
      '${support.path}${separator}content${separator}session-publications-v1.json',
    ),
  );
}
