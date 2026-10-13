import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/local_import_composition.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/create/data/create_local_import_store.dart';
import 'package:recharge/features/create/data/datasources/create_local_datasource.dart';
import 'package:recharge/features/create/data/functions_local_import_gateway.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/data/repositories/create_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/repositories/local_import_gateway.dart';
import 'package:recharge/app/di/event_publication_composition.dart';

import '../fixtures/create/user_place_draft.dart';

/// D4 §5.1, §5.6, §6: the inventory over the real Create storage, the guarded
/// removal of the local original, and the default-off test entry.
void main() {
  late CreateLocalDataSource datasource;
  late CreateRepositoryImpl repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    datasource = CreateLocalDataSource(const FlutterSecureStorage());
    repository = CreateRepositoryImpl(
      localDataSource: datasource,
      idGenerator: UuidV4IdGenerator(),
    );
  });

  CreateDraftEntity place(String localId, {String title = 'Pond'}) =>
      userPlaceDraft(
        pageId: 'page-1',
        coverPath: 'C:/photos/cover.png',
        localId: localId,
        title: title,
      );

  test(
    'the inventory holds the current draft and lists the library drafts',
    () async {
      await repository.saveDraft('user-1', place('loc_place_1'));
      final CreateDraftEntity scenario =
          CreateDraftEntity.defaults(
            organizerId: 'user-1',
            organizerEmail: 'user@example.com',
            organizerName: 'User',
          ).copyWith(
            id: 'loc_scenario_1',
            objectType: CreateObjectType.scenario,
            title: 'Weekend',
          );
      // Saving a Scenario through the slot also files it in the library.
      await repository.saveDraft('user-1', scenario);
      await repository.saveDraft('user-1', place('loc_place_1'));
      final List<LocalImportSourceItem> items = await CreateLocalImportSource(
        repository: repository,
        library: datasource,
      ).inventory('user-1');
      expect(
        items.map(
          (item) => (item.localDraftId, item.localType, item.draft != null),
        ),
        <(String, String, bool)>[
          ('loc_place_1', 'place', true),
          ('loc_scenario_1', 'scenario', false),
        ],
      );
      expect(
        await CreateLocalImportSource(
          repository: repository,
          library: datasource,
        ).inventory('someone-else'),
        isEmpty,
      );
    },
  );

  test(
    'the local original is removed only while it is the exact unchanged draft',
    () async {
      final CreateLocalImportOriginalStore store =
          CreateLocalImportOriginalStore(datasource);
      await repository.saveDraft('user-1', place('loc_place_1'));
      expect(
        await store.deleteIfUnchanged(
          accountId: 'user-1',
          localDraftId: 'loc_other',
          unchanged: (_) => true,
        ),
        isFalse,
      );
      expect(
        await store.deleteIfUnchanged(
          accountId: 'user-1',
          localDraftId: 'loc_place_1',
          unchanged: (CreateDraftEntity draft) =>
              draft.title == 'Something else',
        ),
        isFalse,
      );
      expect(await repository.loadDraft('user-1'), isNotNull);
      expect(
        await store.deleteIfUnchanged(
          accountId: 'user-1',
          localDraftId: 'loc_place_1',
          unchanged: (CreateDraftEntity draft) => draft.title == 'Pond',
        ),
        isTrue,
      );
      expect(await repository.loadDraft('user-1'), isNull);
      // Nothing left to remove.
      expect(
        await datasource.deleteDraftIfUnchanged(
          'user-1',
          (CreateDraftModel _) => true,
        ),
        isFalse,
      );
    },
  );

  group('test entry', () {
    final Uri base = Uri.parse(
      'http://127.0.0.1:5001/demo-recharge/europe-west1',
    );

    LocalImportTestEntryGuard guard({
      bool flag = true,
      bool release = false,
      BackendBindingMode mode = BackendBindingMode.testBackend,
      Uri? emulatorBase,
    }) => LocalImportTestEntryGuard(
      flag: flag,
      releaseMode: release,
      binding: BookingBackendBindingController(
        emulatorBase: emulatorBase ?? base,
        releaseMode: release,
        initial: mode,
      ),
    );

    test('allowed only when every condition holds at once', () {
      expect(guard().allowed, isTrue);
      expect(guard(flag: false).allowed, isFalse);
      expect(guard(release: true).allowed, isFalse);
      expect(guard(mode: BackendBindingMode.localOnly).allowed, isFalse);
      expect(
        guard(
          emulatorBase: Uri.parse(
            'http://127.0.0.1:5001/real-project/europe-west1',
          ),
        ).allowed,
        isFalse,
      );
      expect(localImportTestEntryRedirect(null, fallback: '/x'), '/x');
      expect(
        localImportTestEntryRedirect(guard(flag: false), fallback: '/x'),
        '/x',
      );
      expect(localImportTestEntryRedirect(guard(), fallback: '/x'), isNull);
    });

    test(
      'the compile-time define is off unless set',
      () => expect(localImportTestEntryDefined, isFalse),
      skip: localImportTestEntryDefined ? 'run with the define on' : false,
    );

    test('a closed entry reaches no transport', () async {
      final _CountingPort port = _CountingPort();
      final FunctionsLocalImportGateway gateway = FunctionsLocalImportGateway(
        port: BookingPortContentAdapter(port),
        gate: guard(flag: false),
      );
      await expectLater(gateway.draft('draft'), throwsStateError);
      await expectLater(
        gateway.createImportDraft(
          typeId: 'place',
          publisherRef: const PublisherRef(type: PublisherType.page, id: 'p'),
          marketId: 'LV',
          importSourceKey: 'loc_1',
          idempotencyKey: 'li1-key',
        ),
        throwsStateError,
      );
      expect(port.calls, 0);
    });

    test(
      'the import create sends the source key and an empty body only',
      () async {
        final _CountingPort port = _CountingPort();
        final FunctionsLocalImportGateway gateway = FunctionsLocalImportGateway(
          port: BookingPortContentAdapter(port),
          gate: guard(),
        );
        final LocalImportServerDraft draft = await gateway.createImportDraft(
          typeId: 'place',
          publisherRef: const PublisherRef(type: PublisherType.page, id: 'p'),
          marketId: 'LV',
          importSourceKey: 'loc_1',
          idempotencyKey: 'li1-key:create',
        );
        expect(draft.importSourceKey, 'loc_1');
        expect(port.last, <String, Object?>{
          'schemaVersion': 1,
          'commandType': 'createDraft',
          'idempotencyKey': 'li1-key:create',
          'payload': <String, Object?>{
            'typeId': 'place',
            'publisherRef': <String, Object?>{'type': 'page', 'id': 'p'},
            'marketId': 'LV',
            'body': <String, Object?>{},
            'importSourceKey': 'loc_1',
          },
        });
      },
    );
  });
}

final class _CountingPort implements BookingCallablePort {
  int calls = 0;
  Map<String, Object?>? last;

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> data,
  ) async {
    calls += 1;
    last = data;
    return <String, Object?>{
      'kind': 'succeeded',
      'data': <String, Object?>{
        'contentId': 'c-1',
        'draftId': 'd-1',
        'revision': 1,
        'createdByUserId': 'server-user',
        'importSourceKey': 'loc_1',
        'body': <String, Object?>{},
      },
    };
  }
}
