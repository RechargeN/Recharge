import 'package:recharge/shared/primitives/money/money_parse_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/application/session_create_coordinator.dart';
import 'package:recharge/features/create/data/repositories/event_timezone_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/session_draft_data.dart';
import 'package:recharge/features/create/domain/entities/session_schedule.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/materialize_session_schedule_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/widgets/session_create_block.dart';

import '../support/event_create_test_support.dart';

CreateController _buildController(
  CreateRepository repository, {
  SessionCreateCoordinator? sessionCoordinator,
}) {
  final CreateController controller = CreateController(
    loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
    saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
    publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
    analyticsService: _NoopAnalyticsService(),
    eventCreateCoordinator: createTestEventCoordinator(),
    sessionCreateCoordinator:
        sessionCoordinator ??
        SessionCreateCoordinator(
          materializeSchedule: MaterializeSessionScheduleUseCase(
            EventTimezoneRepositoryImpl(),
          ),
        ),
    runtimeDefaults: const CreateRuntimeDefaults(
      marketCityId: 'riga',
      timezone: 'Europe/Riga',
      country: 'LV',
      city: 'Riga',
      currency: 'EUR',
    ),
  );
  return controller;
}

Future<void> _pumpSessionBlock(
  WidgetTester tester,
  CreateController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AnimatedBuilder(
          animation: controller,
          builder: (BuildContext context, Widget? child) {
            return SingleChildScrollView(
              child: SessionCreateBlock(
                controller: controller,
                state: controller.state,
                onPublished: () {},
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Flush the 700ms autosave timer scheduled by setObjectType(session) so no
  // pending Timer remains when the test ends.
  await tester.pump(const Duration(milliseconds: 800));
}

void main() {
  testWidgets(
    'preview renders listing-zone wall time and skipped-clock reason',
    (tester) async {
      final repository = _MemoryRepository();
      repository.stored =
          CreateDraftEntity.defaults(
            organizerId: 'u',
            organizerEmail: '',
            organizerName: '',
            timezone: 'Europe/Riga',
            currency: 'EUR',
          ).copyWith(
            objectType: CreateObjectType.session,
            sessionData:
                SessionDraftData.defaults(
                  resourceName: 'Sauna',
                  timezoneId: 'Europe/Riga',
                ).copyWith(
                  timezoneConfirmed: true,
                  schedule: const SessionSchedule(
                    scheduleRevision: 1,
                    slotDurationMinutes: 30,
                    projectionWindowDays: 1,
                    weeklyRules: [
                      SessionWeeklyRule(
                        id: 'r',
                        isoWeekday: 7,
                        startMinuteLocal: 120,
                        endMinuteLocalExclusive: 300,
                      ),
                    ],
                  ),
                ),
          );
      final controller = _buildController(
        repository,
        sessionCoordinator: _FixedClockCoordinator(
          DateTime.utc(2026, 3, 28, 22),
        ),
      );
      addTearDown(controller.dispose);
      await controller.ensureLoaded(
        userId: 'u',
        organizerEmail: '',
        organizerName: '',
      );
      await _pumpSessionBlock(tester, controller);
      expect(find.text('Next offers'), findsOneWidget);
      expect(find.text('2026-03-29 02:00–02:30 · Europe/Riga'), findsOneWidget);
      expect(find.text('2026-03-29 04:00–04:30 · Europe/Riga'), findsOneWidget);
      expect(find.text('Skipped because clocks change'), findsOneWidget);
      expect(find.text('2026-03-29 02:30–03:00 · Europe/Riga'), findsOneWidget);
      expect(find.text('dst_transition_skipped'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('preview retains nonmarket zone and previous UTC calendar day', (
    tester,
  ) async {
    final repository = _MemoryRepository();
    repository.stored =
        CreateDraftEntity.defaults(
          organizerId: 'u',
          organizerEmail: '',
          organizerName: '',
          timezone: 'Pacific/Honolulu',
          currency: 'EUR',
        ).copyWith(
          objectType: CreateObjectType.session,
          sessionData:
              SessionDraftData.defaults(
                resourceName: 'Sauna',
                timezoneId: 'Pacific/Honolulu',
              ).copyWith(
                timezoneConfirmed: true,
                schedule: const SessionSchedule(
                  scheduleRevision: 1,
                  slotDurationMinutes: 60,
                  projectionWindowDays: 1,
                  weeklyRules: [
                    SessionWeeklyRule(
                      id: 'r',
                      isoWeekday: 7,
                      startMinuteLocal: 1200,
                      endMinuteLocalExclusive: 1260,
                    ),
                  ],
                ),
              ),
        );
    final controller = _buildController(
      repository,
      sessionCoordinator: _FixedClockCoordinator(DateTime.utc(2026, 8, 24, 5)),
    );
    addTearDown(controller.dispose);
    await controller.ensureLoaded(
      userId: 'u',
      organizerEmail: '',
      organizerName: '',
    );
    await _pumpSessionBlock(tester, controller);
    expect(
      find.text('2026-08-23 20:00–21:00 · Pacific/Honolulu'),
      findsOneWidget,
    );
    expect(find.text('Skipped because clocks change'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Session price input rejects excess scale and preserves the exact value',
    (tester) async {
      final controller = _buildController(_MemoryRepository());
      addTearDown(controller.dispose);
      await controller.ensureLoaded(
        userId: 'u',
        organizerEmail: '',
        organizerName: '',
      );
      controller.setObjectType(CreateObjectType.session);
      controller.setSessionPriceFixed(amountMinor: 1234, currencyCode: 'EUR');
      await _pumpSessionBlock(tester, controller);
      final price = find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.labelText == 'Price per slot, EUR',
      );
      await tester.ensureVisible(price);
      await tester.enterText(price, '1.005');
      await tester.pump();
      expect(
        controller.moneyInputErrors['session.price'],
        MoneyParseError.excessiveFractionDigits,
      );
      expect(
        controller.state.draft.sessionData?.price.amount?.amountMinor,
        1234,
      );
      await tester.enterText(price, '0.29');
      await tester.pump();
      expect(controller.moneyInputErrors, isEmpty);
      expect(controller.state.draft.sessionData?.price.amount?.amountMinor, 29);
      expect(controller.state.draft.basePrice?.minorUnits, 29);
      await tester.pump(const Duration(milliseconds: 800));
    },
  );

  testWidgets(
    'renders the required blocks and an optional-fields toggle for a fresh Session draft',
    (WidgetTester tester) async {
      final _MemoryRepository repository = _MemoryRepository();
      final CreateController controller = _buildController(repository);
      addTearDown(controller.dispose);
      await controller.ensureLoaded(
        userId: 'user-1',
        organizerEmail: 'user@example.com',
        organizerName: 'Creator',
      );
      controller.setObjectType(CreateObjectType.session);

      await _pumpSessionBlock(tester, controller);

      expect(find.text('What and where'), findsOneWidget);
      expect(find.text('When'), findsOneWidget);
      expect(find.text('Price and booking'), findsOneWidget);
      expect(
        find.text('Optional — add now or after publishing'),
        findsOneWidget,
      );
      expect(find.text('Publish'), findsOneWidget);
      // Everything not marked "required" stays collapsed by default.
      expect(find.text('Blocked dates'), findsNothing);
    },
  );

  testWidgets('a weekly preset tap materializes offers shown as chips', (
    WidgetTester tester,
  ) async {
    final _MemoryRepository repository = _MemoryRepository();
    final CreateController controller = _buildController(repository);
    addTearDown(controller.dispose);
    await controller.ensureLoaded(
      userId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'Creator',
    );
    controller.setObjectType(CreateObjectType.session);
    controller.confirmSessionTimezone('Europe/Riga');

    await _pumpSessionBlock(tester, controller);

    expect(find.text('Every day 9:00–21:00'), findsOneWidget);
    await tester.ensureVisible(find.text('Every day 9:00–21:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every day 9:00–21:00'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 800));

    expect(
      controller.state.draft.sessionData!.schedule.weeklyRules,
      hasLength(7),
    );
    expect(find.text('Next offers'), findsOneWidget);
  });
}

class _NoopAnalyticsService implements AnalyticsService {
  @override
  void track(String eventName, {Map<String, Object?> params = const {}}) {}
}

class _FixedClockCoordinator extends SessionCreateCoordinator {
  _FixedClockCoordinator(this.now)
    : super(
        materializeSchedule: MaterializeSessionScheduleUseCase(
          EventTimezoneRepositoryImpl(),
        ),
      );
  final DateTime now;
  @override
  SessionScheduleMaterializationResult materialize(
    CreateDraftEntity draft, {
    DateTime? nowUtc,
  }) => super.materialize(draft, nowUtc: nowUtc ?? now);
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
