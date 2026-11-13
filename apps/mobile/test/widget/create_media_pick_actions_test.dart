import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
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
import 'package:recharge/features/create/presentation/widgets/create_media_pick_actions.dart';
import 'package:recharge/features/create/presentation/widgets/event_create_block.dart';
import 'package:recharge/generated/l10n/app_localizations.dart';

import '../support/event_create_test_support.dart';

/// MEDIA-PICK-01 §4, §9, MP-AC-01/05/06/07: the picker next to the existing
/// media fields, through a fake platform port and an in-memory store.
void main() {
  late _FakePicker picker;
  late _FakeNormalizer normalizer;
  late _MemoryStore store;

  setUp(() {
    picker = _FakePicker();
    normalizer = _FakeNormalizer();
    store = _MemoryStore();
  });

  Future<CreateController> controllerFor(
    CreateObjectType type, {
    CreateMediaPickerConfig config = const CreateMediaPickerConfig(),
  }) async {
    final _MemoryRepository repository = _MemoryRepository();
    final controller = CreateController(
      loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
      saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
      publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
      analyticsService: _NoopAnalyticsService(),
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
        normalizer: normalizer,
        store: store,
        config: config,
      ),
    );
    await controller.ensureLoaded(
      userId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'Creator',
    );
    controller.setObjectType(type);
    return controller;
  }

  Future<void> pump(
    WidgetTester tester,
    CreateController controller, {
    CreateMediaTarget target = CreateMediaTarget.cover,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AnimatedBuilder(
            animation: controller,
            builder: (context, _) =>
                CreateMediaPickActions(controller: controller, target: target),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('a picked photo becomes the cover as a private copy', (
    tester,
  ) async {
    final controller = await controllerFor(CreateObjectType.activity);
    addTearDown(controller.dispose);
    await pump(tester, controller);

    picker.next = PickedImage(bytes: Uint8List.fromList(<int>[1, 2, 3]));
    await tapAndSettle(tester, 'create-media-pick-cover');

    final String cover = controller.state.draft.media.coverImage;
    expect(store.owns(cover), isTrue);
    expect(store.saved[cover], <int>[1, 2, 3, 99], reason: 'normalized');
    expect(picker.sources, <CreateImageSource>[CreateImageSource.gallery]);
    expect(find.text('Cover photo selected'), findsOneWidget);
    expect(find.byKey(const Key('create-media-cover-preview')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('a new cover deletes the copy it replaces', (tester) async {
    final controller = await controllerFor(CreateObjectType.activity);
    addTearDown(controller.dispose);
    await pump(tester, controller);
    picker.next = PickedImage(bytes: Uint8List.fromList(<int>[1]));
    await tapAndSettle(tester, 'create-media-pick-cover');
    final String first = controller.state.draft.media.coverImage;
    picker.next = PickedImage(bytes: Uint8List.fromList(<int>[2]));
    await tapAndSettle(tester, 'create-media-camera-cover');
    expect(controller.state.draft.media.coverImage, isNot(first));
    expect(store.removed, <String>[first]);
    expect(picker.sources.last, CreateImageSource.camera);
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('closing the picker changes nothing and says nothing', (
    tester,
  ) async {
    final controller = await controllerFor(CreateObjectType.activity);
    addTearDown(controller.dispose);
    await pump(tester, controller);
    picker.next = null;
    await tapAndSettle(tester, 'create-media-pick-cover');
    expect(controller.state.draft.media.coverImage, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
    expect(store.saved, isEmpty);
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('a refusal is shown in words, never as its code', (tester) async {
    for (final (Locale locale, String text) in <(Locale, String)>[
      (const Locale('en'), 'This image is too large even after compression.'),
      (const Locale('ru'), 'Изображение слишком большое даже после сжатия.'),
    ]) {
      final controller = await controllerFor(CreateObjectType.activity);
      await pump(tester, controller, locale: locale);
      picker.next = PickedImage(bytes: Uint8List.fromList(<int>[1]));
      normalizer.refuseWith = 'media_too_large';
      await tapAndSettle(tester, 'create-media-pick-cover');
      expect(find.text(text), findsOneWidget);
      expect(find.textContaining('media_too_large'), findsNothing);
      expect(controller.state.draft.media.coverImage, isEmpty);
      normalizer.refuseWith = null;
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('the Place gallery keeps its limit of 12; the extra copy goes', (
    tester,
  ) async {
    final controller = await controllerFor(CreateObjectType.place);
    addTearDown(controller.dispose);
    for (var i = 0; i < 12; i++) {
      controller.addGalleryImage('https://example.org/$i.jpg');
    }
    await pump(tester, controller, target: CreateMediaTarget.gallery);
    picker.next = PickedImage(bytes: Uint8List.fromList(<int>[5]));
    await tapAndSettle(tester, 'create-media-pick-gallery');
    expect(controller.state.draft.media.gallery, hasLength(12));
    expect(store.removed, hasLength(1), reason: 'not added, so not kept');
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('removing a picked gallery photo deletes its copy', (
    tester,
  ) async {
    final controller = await controllerFor(CreateObjectType.activity);
    addTearDown(controller.dispose);
    await pump(tester, controller, target: CreateMediaTarget.gallery);
    picker.next = PickedImage(bytes: Uint8List.fromList(<int>[7]));
    await tapAndSettle(tester, 'create-media-pick-gallery');
    final String copy = controller.state.draft.media.gallery.single;
    controller.removeGalleryImageAt(0);
    await tester.pumpAndSettle();
    expect(store.removed, <String>[copy]);
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('kill switch off and camera off', (tester) async {
    final off = await controllerFor(
      CreateObjectType.activity,
      config: const CreateMediaPickerConfig(enabled: false),
    );
    addTearDown(off.dispose);
    await pump(tester, off);
    expect(find.byKey(const Key('create-media-pick-cover')), findsNothing);
    expect(showCreateMediaPathField(off), isTrue);
    await tester.pump(const Duration(milliseconds: 800));

    final noCamera = await controllerFor(
      CreateObjectType.activity,
      config: const CreateMediaPickerConfig(cameraEnabled: false),
    );
    addTearDown(noCamera.dispose);
    await pump(tester, noCamera);
    expect(find.byKey(const Key('create-media-pick-cover')), findsOneWidget);
    expect(find.byKey(const Key('create-media-camera-cover')), findsNothing);
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('the Event form offers the picker for cover and gallery', (
    tester,
  ) async {
    final controller = await controllerFor(CreateObjectType.event);
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => SingleChildScrollView(
              child: EventCreateBlock(
                controller: controller,
                state: controller.state,
                taxonomySection: const SizedBox.shrink(),
                onPublished: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-media-pick-cover')), findsOneWidget);
    expect(find.byKey(const Key('create-media-pick-gallery')), findsOneWidget);
    // Debug build (MP-OD-04): the URL/path fields stay for stand tests.
    expect(find.byKey(const Key('event-gallery-input')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
  });
}

class _FakePicker implements CreateImagePickerPort {
  PickedImage? next;
  final List<CreateImageSource> sources = <CreateImageSource>[];

  @override
  Future<PickedImage?> pick(CreateImageSource source) async {
    sources.add(source);
    return next;
  }
}

class _FakeNormalizer implements CreateImageNormalizer {
  String? refuseWith;

  @override
  Future<Uint8List> normalize(Uint8List input) async {
    final String? code = refuseWith;
    if (code != null) throw CreateMediaException(code);
    return Uint8List.fromList(<int>[...input, 99]);
  }
}

class _MemoryStore implements CreateMediaStore {
  final Map<String, List<int>> saved = <String, List<int>>{};
  final List<String> removed = <String>[];
  int _next = 0;

  @override
  bool owns(String path) => path.startsWith('/mem/create_media/');

  @override
  Future<String> save(String draftKey, Uint8List jpeg) async {
    final path = '/mem/create_media/d/${_next++}.jpg';
    saved[path] = jpeg;
    return path;
  }

  @override
  Future<void> remove(String path) async {
    if (!owns(path)) return;
    removed.add(path);
    saved.remove(path);
  }

  @override
  Future<int> removePartialWrites() async => 0;
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _MemoryRepository implements CreateRepository {
  CreateDraftEntity? stored;

  @override
  Future<CreateDraftEntity?> loadDraft(String userId) async => stored;

  @override
  Future<void> saveDraft(String userId, CreateDraftEntity draft) async {
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
