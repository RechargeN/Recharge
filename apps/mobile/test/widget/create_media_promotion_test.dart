import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_media_asset_ref.dart';
import 'package:recharge/features/create/application/create_media_picking.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/repositories/create_image_normalizer.dart';
import 'package:recharge/features/create/domain/repositories/create_image_picker_port.dart';
import 'package:recharge/features/create/domain/repositories/create_media_store.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';

import '../support/event_create_test_support.dart';

/// MEDIA-PICK-02 (owner conditions 2026-11-18): a local copy is released only
/// after the asset was ready and the draft was saved with `asset:`; a failed
/// save loses nothing; copies and sweeps are per account.
void main() {
  late _Picker picker;
  late _Store store;
  late _Repository repository;

  setUp(() {
    picker = _Picker();
    store = _Store();
    repository = _Repository(store);
  });

  Future<CreateController> controllerFor({String userId = 'user-1'}) async {
    final controller = CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
      analyticsService: _NoAnalytics(),
      eventCreateCoordinator: createTestEventCoordinator(),
      runtimeDefaults: const CreateRuntimeDefaults(
        marketCityId: 'riga',
        timezone: 'Europe/Riga',
        country: 'LV',
        city: 'Riga',
        currency: 'EUR',
      ),
      mediaPicking: CreateMediaPicking(
        picker: picker,
        normalizer: _Normalizer(),
        store: store,
      ),
    );
    await controller.ensureLoaded(
      userId: userId,
      organizerEmail: 'user@example.com',
      organizerName: 'User',
    );
    return controller;
  }

  Future<(CreateController, String, String)> withTwoPhotos() async {
    final controller = await controllerFor();
    controller.setObjectType(CreateObjectType.place);
    picker.next = PickedImage(
      bytes: Uint8List.fromList(<int>[1]),
      mediaType: 'image/jpeg',
    );
    await controller.pickCoverImage(CreateImageSource.gallery);
    await controller.pickGalleryImage(CreateImageSource.gallery);
    final String cover = controller.state.draft.media.coverImage;
    final String gallery = controller.state.draft.media.gallery.single;
    return (controller, cover, gallery);
  }

  test('copies are stored under the account of the draft', () async {
    final (controller, cover, _) = await withTwoPhotos();
    expect(store.keys, everyElement(startsWith('account/user-1/')));
    expect(store.owns(cover), isTrue);
    controller.dispose();
  });

  test(
    'ready assets replace the fields; the draft is saved before any copy is released',
    () async {
      final (controller, cover, gallery) = await withTwoPhotos();
      final bool ok = await controller.promoteReadyMedia(<String, String>{
        cover: 'asset_cover_1',
        gallery: 'asset_gallery_1',
      });
      expect(ok, isTrue);
      final media = controller.state.draft.media;
      expect(media.coverImage, promotedMediaRef('asset_cover_1'));
      expect(media.gallery, <String>[promotedMediaRef('asset_gallery_1')]);
      expect(repository.stored!.media.coverImage, media.coverImage);
      expect(
        repository.storedCoverAtFirstRelease,
        promotedMediaRef('asset_cover_1'),
        reason: 'the saved draft already pointed at the asset',
      );
      expect(store.released, unorderedEquals(<String>[cover, gallery]));
      expect(store.releasedOwner, 'user-1');
      controller.dispose();
    },
  );

  test('a failed save replaces nothing and deletes nothing', () async {
    final (controller, cover, gallery) = await withTwoPhotos();
    repository.failSaves = true;
    final bool ok = await controller.promoteReadyMedia(<String, String>{
      cover: 'asset_cover_1',
    });
    expect(ok, isFalse);
    expect(controller.state.draft.media.coverImage, cover);
    expect(store.released, isEmpty);
    expect(store.removed, isEmpty);
    expect(store.saved.keys, containsAll(<String>[cover, gallery]));
    controller.dispose();
  });

  test('photo descriptions follow the photo to its asset reference', () async {
    final (controller, _, gallery) = await withTwoPhotos();
    await repository.saveDraft(
      'user-1',
      controller.state.draft.copyWith(
        sectionData: <String, Object?>{
          ...controller.state.draft.sectionData,
          'class_workshop_media': <String, Object?>{
            'galleryAltText': <String, Object?>{gallery: 'A quiet room'},
          },
        },
      ),
    );
    controller.dispose();
    final CreateController reloaded = await controllerFor();
    await reloaded.promoteReadyMedia(<String, String>{gallery: 'asset_g'});
    final Map<String, Object?> section =
        reloaded.state.draft.sectionData['class_workshop_media']!
            as Map<String, Object?>;
    expect(section['galleryAltText'], <String, Object?>{
      promotedMediaRef('asset_g'): 'A quiet room',
    });
    reloaded.dispose();
  });

  test('a sweep on load looks at the signed-in account only', () async {
    final CreateController controller = await controllerFor(userId: 'user-2');
    expect(store.sweptOwners, <String>['user-2']);
    controller.dispose();
  });
}

class _Picker implements CreateImagePickerPort {
  PickedImage? next;
  @override
  Future<PickedImage?> pick(CreateImageSource source) async => next;
}

class _Normalizer implements CreateImageNormalizer {
  @override
  Future<Uint8List> normalize(Uint8List input) async => input;
}

class _Store implements CreateMediaStore {
  final Map<String, List<int>> saved = <String, List<int>>{};
  final List<String> keys = <String>[];
  final List<String> removed = <String>[];
  final List<String> released = <String>[];
  final List<String> sweptOwners = <String>[];
  String? releasedOwner;
  void Function()? onFirstRelease;
  int _next = 0;

  @override
  bool owns(String path) => path.startsWith('/mem/create_media/');

  @override
  Future<String> save(String draftKey, Uint8List jpeg) async {
    keys.add(draftKey);
    final String path = '/mem/create_media/${_next++}.jpg';
    saved[path] = jpeg;
    return path;
  }

  @override
  Future<void> remove(String path) async {
    removed.add(path);
    saved.remove(path);
  }

  @override
  Future<int> removePartialWrites() async => 0;

  @override
  Future<void> release({required String ownerId, required String path}) async {
    if (released.isEmpty) onFirstRelease?.call();
    releasedOwner = ownerId;
    released.add(path);
    saved.remove(path);
  }

  @override
  Future<int> sweepReleased({
    required String ownerId,
    required bool Function(String path) referenced,
  }) async {
    sweptOwners.add(ownerId);
    return 0;
  }
}

class _NoAnalytics implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _Repository implements CreateRepository {
  _Repository(_Store store) {
    store.onFirstRelease = () =>
        storedCoverAtFirstRelease = stored?.media.coverImage;
  }

  CreateDraftEntity? stored;
  bool failSaves = false;
  String? storedCoverAtFirstRelease;

  @override
  Future<CreateDraftEntity?> loadDraft(String userId) async => stored;

  @override
  Future<void> saveDraft(String userId, CreateDraftEntity draft) async {
    if (failSaves) throw StateError('disk full');
    stored = draft;
  }

  @override
  Future<CreateDraftEntity> publishDraft(
    String userId,
    CreateDraftEntity draft,
  ) async {
    stored = draft;
    return draft;
  }
}
