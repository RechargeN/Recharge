import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/class_workshop_create_coordinator.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/data/repositories/event_timezone_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/class_workshop_draft_data.dart';
import 'package:recharge/features/create/domain/entities/create_availability.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/build_class_workshop_content_body.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/widgets/class_workshop_create_block.dart';

import '../support/event_create_test_support.dart';

CreateController _controller(CreateRepository repository) => CreateController(
  loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
  saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
  publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
  analyticsService: _NoopAnalytics(),
  eventCreateCoordinator: createTestEventCoordinator(),
  classWorkshopCreateCoordinator: ClassWorkshopCreateCoordinator(
    mapper: ClassWorkshopContentBodyMapper(EventTimezoneRepositoryImpl()),
  ),
  runtimeDefaults: const CreateRuntimeDefaults(
    marketCityId: 'riga',
    timezone: 'Europe/Riga',
    country: 'LV',
    city: 'Riga',
    currency: 'EUR',
  ),
);

Future<CreateController> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final controller = _controller(_MemoryRepository());
  addTearDown(controller.dispose);
  await controller.ensureLoaded(
    userId: 'user-1',
    organizerEmail: 'user@example.com',
    organizerName: 'Creator',
  );
  controller.setObjectType(CreateObjectType.classWorkshop);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? child) =>
              SingleChildScrollView(
                child: ClassWorkshopCreateBlock(
                  controller: controller,
                  state: controller.state,
                  onPublished: () {},
                ),
              ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Flush the autosave timer scheduled by setObjectType.
  await tester.pump(const Duration(milliseconds: 800));
  return controller;
}

void main() {
  testWidgets(
    'renders the four config sections and readiness gaps of a fresh draft',
    (WidgetTester tester) async {
      final controller = await _pump(tester);
      for (final id in <String>[
        'basics',
        'learning',
        'schedule',
        'participation',
      ]) {
        expect(find.byKey(Key('class-workshop-section-$id')), findsOneWidget);
      }
      expect(controller.state.draft.classWorkshopData, isNotNull);
      expect(
        find.byKey(const Key('class-workshop-issue-offering_kind')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('class-workshop-issue-occurrences')),
        findsOneWidget,
      );
      // Unknown price is never shown as free.
      expect(
        controller.state.draft.classWorkshopData!.price.mode,
        ClassWorkshopPriceMode.notProvided,
      );
    },
  );

  testWidgets(
    'typing in the block edits the typed draft through the controller',
    (WidgetTester tester) async {
      final controller = await _pump(tester);
      await tester.enterText(
        find.byKey(const Key('class-workshop-title')),
        'Riga pottery',
      );
      await tester.enterText(
        find.byKey(const Key('class-workshop-outcomes')),
        'Centre clay\nThrow a cup\nCentre clay',
      );
      await tester.enterText(
        find.byKey(const Key('class-workshop-modules')),
        'Wedging\nThrowing',
      );
      await tester.enterText(
        find.byKey(const Key('class-workshop-new-date')),
        '2027-05-15',
      );
      await tester.enterText(
        find.byKey(const Key('class-workshop-new-start')),
        '10:00',
      );
      await tester.enterText(
        find.byKey(const Key('class-workshop-new-end')),
        '13:00',
      );
      await tester.tap(find.byKey(const Key('class-workshop-add-date')));
      await tester.tap(find.byKey(const Key('class-workshop-timezone')));
      await tester.pump(const Duration(milliseconds: 800));
      final draft = controller.state.draft;
      final data = draft.classWorkshopData!;
      expect(draft.title, 'Riga pottery');
      expect(data.outcomes, <String>['Centre clay', 'Throw a cup']);
      expect(data.modules.map((m) => m.title), <String>['Wedging', 'Throwing']);
      expect(data.modules.every((m) => m.id.startsWith('loc_')), isTrue);
      expect(data.occurrences.single.localDate, '2027-05-15');
      expect(data.timezoneConfirmed, isTrue);
      // The envelope follows the first declared class (UTC+3 in May).
      expect(draft.startDateTimeUtc, DateTime.utc(2027, 5, 15, 7));
      expect(draft.endDateTimeUtc, DateTime.utc(2027, 5, 15, 10));
      expect(
        find.byKey(const Key('class-workshop-issue-occurrences')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'an ambiguous DST time asks for the offset; others keep no fold',
    (WidgetTester tester) async {
      final controller = await _pump(tester);
      controller.addClassWorkshopOccurrence(
        localDate: '2027-10-31',
        startMinuteLocal: 210,
        endMinuteLocal: 300,
      );
      await tester.pump(const Duration(milliseconds: 800));
      final occurrence =
          controller.state.draft.classWorkshopData!.occurrences.single;
      expect(find.text('First (summer time)'), findsOneWidget);
      controller.setClassWorkshopFold(occurrence.id, ClassWorkshopFold.earlier);
      await tester.pump(const Duration(milliseconds: 800));
      expect(
        controller.state.draft.classWorkshopData!.occurrences.single.fold,
        ClassWorkshopFold.earlier,
      );
      controller.addClassWorkshopOccurrence(
        localDate: '2027-05-15',
        startMinuteLocal: 600,
        endMinuteLocal: 780,
      );
      await tester.pump(const Duration(milliseconds: 800));
      final may = controller.state.draft.classWorkshopData!.occurrences.first;
      expect(may.localDate, '2027-05-15', reason: 'occurrences are sorted');
      controller.setClassWorkshopFold(may.id, ClassWorkshopFold.later);
      await tester.pump(const Duration(milliseconds: 800));
      expect(
        controller.state.draft.classWorkshopData!.occurrences.first.fold,
        isNull,
        reason: 'a fold is dropped where the time is not ambiguous',
      );
    },
  );

  testWidgets(
    'a legacy generic schedule is only cleared by the explicit action',
    (WidgetTester tester) async {
      final controller = await _pump(tester);
      controller.replaceScheduleSlots(<CreateTimeSlotDraft>[
        CreateTimeSlotDraft(
          localId: 'loc_slot',
          startAtUtc: DateTime.utc(2027, 5, 15, 7),
          endAtUtc: DateTime.utc(2027, 5, 15, 10),
        ),
      ]);
      await tester.pump(const Duration(milliseconds: 800));
      expect(
        find.byKey(const Key('class-workshop-legacy-schedule')),
        findsOneWidget,
      );
      expect(controller.state.draft.scheduleSlots, isNotEmpty);
      await tester.tap(find.text('Clear'));
      await tester.pump(const Duration(milliseconds: 800));
      expect(controller.state.draft.scheduleSlots, isEmpty);
      expect(
        find.byKey(const Key('class-workshop-legacy-schedule')),
        findsNothing,
      );
    },
  );
}

class _NoopAnalytics implements AnalyticsService {
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
