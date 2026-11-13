import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/class_workshop_publication_composition.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/data/repositories/event_timezone_repository_impl.dart';
import 'package:uuid/uuid.dart';
import '../fixtures/create/user_class_workshop_draft.dart';
import 'support/content_fault_client.dart';
import 'support/stand_backend.dart';

void main() {
  final stand = StandBackend.fromEnvironment();
  test(
    'real Class Create repository/controller publishes personal content through Emulator',
    () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      final temp = await Directory.systemTemp.createTemp('d36-stand-mobile-');
      try {
        await stand!.classWorkshopSeed();
        final manifest = await stand.classWorkshopManifest();
        final user = manifest['createdByUserId']! as String;
        final cover = await File(
          'test/fixtures/media/stand_cover.png',
        ).copy('${temp.path}/cover.png');
        final binding = BookingBackendBindingController(
          emulatorBase: StandBackend.functionsBase,
          releaseMode: false,
          initial: BackendBindingMode.testBackend,
        );
        final sessions = FileSessionStore(File('${temp.path}/session.json'));
        final faults = ContentFaultClient();
        final runtime = await BookingTransportRuntimeFactory(
          endpoint: binding.endpoint,
          client: faults,
          tokens: AuthEmulatorTokenProvider('stand-user-creator'),
          sessions: sessions,
          installations: const FixedInstallationId('d36-mobile-creator'),
          supportDirectory: () =>
              Directory('${temp.path}/support').create(recursive: true),
        ).create();
        await runtime.identitySessions!.establish(requestId: const Uuid().v4());
        final repository = CreateRepositoryImpl(
          localDataSource: CreateLocalDataSource(const FlutterSecureStorage()),
          idGenerator: UuidV4IdGenerator(),
        );
        await repository.saveDraft(
          user,
          userClassWorkshopDraft(
            userId: user,
            coverPath: cover.path,
            localId: 'loc_d36_${const Uuid().v4()}',
          ),
        );
        final guard = ClassWorkshopPublicationTestEntryGuard(
          flag: true,
          releaseMode: false,
          binding: binding,
        );
        final controller = classWorkshopPublicationControllerFor(
          accountId: user,
          defaultContentLocale: 'en',
          port: runtime.port!,
          guard: guard,
          drafts: CreateRepositoryClassWorkshopDraftSource(repository, user),
          journalFile: File('${temp.path}/journal.json'),
          timezones: EventTimezoneRepositoryImpl(),
        );
        await controller.load();
        await controller.save();
        expect(
          controller.state.message,
          isNull,
          reason: controller.state.message,
        );
        await controller.uploadMedia();
        expect(
          controller.state.message,
          isNull,
          reason: controller.state.message,
        );
        await controller.submit();
        expect(
          controller.state.message,
          isNull,
          reason: controller.state.message,
        );
        final submission = controller.state.record!.submissionId!;
        final approval = await stand.moderate(<String>[
          'approve',
          submission,
          '--reason',
          'D3.6 Class review',
        ]);
        expect(approval.exitCode, 0, reason: '${approval.json}');
        await controller.refresh();
        await controller.publish();
        expect(
          controller.state.message,
          isNull,
          reason: controller.state.message,
        );
        expect(controller.state.status?.visibility, 'visible');
        // Q4: no edit after publication; nothing more is written.
        await controller.save();
        expect(
          controller.state.message,
          'editing_after_publication_not_supported',
        );
        await controller.hide();
        expect(controller.state.status?.visibility, 'withdrawn');
        controller.dispose();
      } finally {
        await temp.delete(recursive: true);
      }
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
