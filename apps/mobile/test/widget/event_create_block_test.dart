import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/widgets/event_create_block.dart';

import '../support/event_create_test_support.dart';

void main() {
  testWidgets('Event five-step flow works at 360 dp and autosaves', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final _MemoryRepository repository = _MemoryRepository();
    final CreateController controller = CreateController(
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
    );
    addTearDown(controller.dispose);
    await controller.ensureLoaded(
      userId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'Host',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: controller,
            builder: (BuildContext context, Widget? child) {
              return SingleChildScrollView(
                child: EventCreateBlock(
                  controller: controller,
                  state: controller.state,
                  taxonomySection: const Text('Event taxonomy'),
                  onPublished: () {},
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('event-create-block')), findsOneWidget);
    expect(find.text('1. Basics & media'), findsOneWidget);

    controller.applyTaxonomySelection(
      mainCategory: 'entertainment',
      subcategory: 'community_event',
    );
    await tester.enterText(
      find.byKey(const Key('event-title')),
      'Riga community evening',
    );
    await tester.enterText(
      find.byKey(const Key('event-short-description')),
      'A welcoming evening for the local community.',
    );
    await tester.enterText(find.byKey(const Key('event-cover')), 'cover.jpg');
    await tester.enterText(
      find.byKey(const Key('event-cover-alt')),
      'People meeting in a bright community hall',
    );
    await tester.ensureVisible(find.byKey(const Key('event-media-rights')));
    await tester.tap(find.byKey(const Key('event-media-rights')));
    await tester.pumpAndSettle();

    await _tapVisible(tester, const Key('event-step-next'));
    expect(find.text('2. Location & schedule'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('event-address')),
      'Brivibas iela 1',
    );
    controller.updateEventLocation(latitude: 56.9496, longitude: 24.1052);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('event-location-pin-confirmed')),
    );
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(
              of: find.byKey(const Key('event-location-pin-confirmed')),
              matching: find.byType(Checkbox),
            ),
          )
          .onChanged,
      isNotNull,
    );
    controller.updateEventLocation(pinConfirmed: true);
    await tester.pumpAndSettle();

    await _tapVisible(tester, const Key('event-step-next'));
    expect(
      controller.state.eventValidationIssues,
      isEmpty,
      reason: controller.state.eventValidationIssues
          .map((issue) => '${issue.code}:${issue.message}')
          .join(', '),
    );
    expect(find.text('3. Requirements & amenities'), findsOneWidget);
    await _tapVisible(tester, const Key('event-step-next'));
    expect(find.text('4. Price & participants'), findsOneWidget);
    await _tapVisible(tester, const Key('event-step-next'));
    expect(find.text('5. Preview & publish'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(controller.state.saveStatus.name, 'saved');
    expect(repository.stored?.eventData, isNotNull);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tapVisible(WidgetTester tester, Key key) async {
  final Finder finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
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
