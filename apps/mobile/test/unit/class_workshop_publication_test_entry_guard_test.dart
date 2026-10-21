import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/data/models/class_workshop_draft_mapper.dart';
import '../fixtures/create/user_class_workshop_draft.dart';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/event_publication_composition.dart';
import 'package:recharge/app/di/media_composition.dart';
import 'package:recharge/app/di/class_workshop_publication_composition.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/create/data/functions_event_publication_gateway.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';

/// D3.6: the Class / Workshop test entry is its own default-off switch with the same
/// four conditions as the Event one, and it closes the route, every Content
/// command and every Media upload.
void main() {
  final Uri base = Uri.parse(
    'http://127.0.0.1:5001/demo-recharge/europe-west1',
  );

  ClassWorkshopPublicationTestEntryGuard guard({
    bool flag = true,
    bool release = false,
    BackendBindingMode mode = BackendBindingMode.testBackend,
    Uri? emulatorBase,
  }) => ClassWorkshopPublicationTestEntryGuard(
    flag: flag,
    releaseMode: release,
    binding: BookingBackendBindingController(
      emulatorBase: emulatorBase ?? base,
      releaseMode: release,
      initial: mode,
    ),
  );

  test(
    'persistence mirror is stripped only when lossless; conflicting input stays explicit',
    () async {
      final draft = userClassWorkshopDraft(
        userId: 'user',
        coverPath: 'cover.png',
      );
      final mirror = ClassWorkshopDraftMapper.toJson(draft.classWorkshopData!);
      final source = CreateRepositoryClassWorkshopDraftSource(
        _ClassWorkshopRepo(
          draft.copyWith(
            sectionData: <String, Object?>{
              ...draft.sectionData,
              'class_workshop_details': mirror,
            },
          ),
        ),
        'user',
      );
      expect(
        (await source.current())!.sectionData.containsKey(
          'class_workshop_details',
        ),
        isFalse,
      );
      mirror['schema_version'] = 2;
      expect(
        (await source.current())!.sectionData.containsKey(
          'class_workshop_details',
        ),
        isTrue,
      );
    },
  );

  test('allowed only when every condition holds at once', () {
    expect(guard().allowed, isTrue);
    expect(guard(flag: false).allowed, isFalse);
    expect(guard(release: true).allowed, isFalse);
    expect(guard(mode: BackendBindingMode.localOnly).allowed, isFalse);
    expect(guard(mode: BackendBindingMode.disabled).allowed, isFalse);
    expect(
      guard(
        emulatorBase: Uri.parse(
          'http://10.0.2.2:5001/demo-recharge/europe-west1',
        ),
      ).allowed,
      isFalse,
    );
    expect(
      guard(
        emulatorBase: Uri.parse(
          'http://127.0.0.1:5001/real-project/europe-west1',
        ),
      ).allowed,
      isFalse,
    );
  });

  test(
    'the compile-time define is off unless set, and separate from the Event one',
    () {
      expect(classWorkshopPublicationTestEntryDefined, isFalse);
      expect(
        ClassWorkshopPublicationTestEntryGuard.fromEnvironment(
          BookingBackendBindingController(
            emulatorBase: base,
            releaseMode: false,
            initial: BackendBindingMode.testBackend,
          ),
        ).allowed,
        isFalse,
      );
    },
    skip: classWorkshopPublicationTestEntryDefined
        ? 'run with the define on'
        : false,
  );

  test('the route redirect refuses unless the guard allows', () {
    expect(
      classWorkshopPublicationTestEntryRedirect(null, fallback: '/x'),
      '/x',
    );
    expect(
      classWorkshopPublicationTestEntryRedirect(
        guard(flag: false),
        fallback: '/x',
      ),
      '/x',
    );
    expect(
      classWorkshopPublicationTestEntryRedirect(guard(), fallback: '/x'),
      isNull,
    );
  });

  test('neither Content nor Media is reached when the gate denies', () async {
    final _CountingPort port = _CountingPort();
    final ClassWorkshopPublicationTestEntryGuard closed = guard(flag: false);
    final FunctionsEventPublicationGateway gateway =
        FunctionsEventPublicationGateway(
          port: BookingPortContentAdapter(port),
          gate: closed,
          typeId: 'class_workshop',
        );
    await expectLater(gateway.status('content'), throwsStateError);
    await expectLater(gateway.draft('draft'), throwsStateError);
    await expectLater(
      gateway.createDraft(
        publisherRef: const PublisherRef(type: PublisherType.page, id: 'p'),
        marketId: 'LV',
        body: const <String, Object?>{},
        idempotencyKey: 'key-00000001',
      ),
      throwsStateError,
    );
    final MediaEventCoverUploader uploader = MediaEventCoverUploader(
      mediaUploadGatewayFor(port: port, gate: closed),
    );
    await expectLater(
      uploader.upload(
        intentId: '7dd283c2-0e3c-41e1-b60f-7ed6bb9e0735',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        declaredMediaType: 'image/png',
        publisherRef: const PublisherRef(type: PublisherType.page, id: 'p'),
        contentId: 'content',
      ),
      throwsA(anything),
    );
    expect(port.calls, 0, reason: 'nothing may reach the transport');
  });
}

final class _CountingPort implements BookingCallablePort {
  int calls = 0;

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> data,
  ) async {
    calls += 1;
    return <String, Object?>{};
  }
}

final class _ClassWorkshopRepo extends Fake implements CreateRepository {
  _ClassWorkshopRepo(this.draft);
  final CreateDraftEntity draft;
  @override
  Future<CreateDraftEntity?> loadDraft(String userId) async => draft;
}
