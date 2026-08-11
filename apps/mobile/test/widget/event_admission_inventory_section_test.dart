import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/telemetry/analytics_service.dart';
import 'package:recharge/features/create/application/controllers/create_controller.dart';
import 'package:recharge/features/create/application/create_runtime_defaults.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_admission.dart';
import 'package:recharge/features/create/domain/entities/event_inventory.dart';
import 'package:recharge/features/create/domain/repositories/create_repository.dart';
import 'package:recharge/features/create/domain/usecases/load_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/publish_create_draft_usecase.dart';
import 'package:recharge/features/create/domain/usecases/save_create_draft_usecase.dart';
import 'package:recharge/features/create/presentation/widgets/event_admission_section.dart';
import 'package:recharge/features/create/presentation/widgets/event_inventory_section.dart';

import '../support/event_create_test_support.dart';

void main() {
  testWidgets('sections fit 360 dp at 150% and disclose local-only behavior', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final CreateController controller = _controller();
    addTearDown(controller.dispose);
    await controller.ensureLoaded(
      userId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'Creator',
    );
    controller.previewEventAdmissionPreset(EventAdmissionPreset.noRegistration);
    controller.selectEventInventoryAuthority(InventoryAuthority.recharge);
    controller.selectEventInventoryShapes(
      primaryShape: InventoryShape.generalCapacity,
    );
    controller.addEventInventoryPool(
      label: 'Onsite',
      shape: InventoryShape.generalCapacity,
      channel: InventoryChannel.onsite,
      capacityMode: EventCapacityMode.known,
      capacity: 20,
    );

    await tester.pumpWidget(_host(controller));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byKey(const Key('event-admission-section')), findsOneWidget);
    expect(find.byKey(const Key('event-inventory-section')), findsOneWidget);
    expect(find.textContaining('does not create a booking'), findsOneWidget);
    expect(find.textContaining('not live availability'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preset remains preview until explicit Apply tap', (
    WidgetTester tester,
  ) async {
    final CreateController controller = _controller();
    addTearDown(controller.dispose);
    await controller.ensureLoaded(
      userId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'Creator',
    );
    controller.previewEventAdmissionPreset(EventAdmissionPreset.noRegistration);
    final int revision = controller.state.draft.eventData!.revision;
    await tester.pumpWidget(_host(controller));

    expect(controller.state.draft.eventData!.admission, isNull);
    await tester.tap(find.byKey(const Key('event-admission-apply-preset')));
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      controller.state.draft.eventData!.admission!.admissionMode,
      AdmissionMode.openEntry,
    );
    expect(controller.state.draft.eventData!.revision, revision + 1);
  });
}

Widget _host(CreateController controller) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
    child: Scaffold(
      body: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              EventAdmissionSection(
                state: controller.eventAdmissionState,
                controller: controller,
                externalRegistrationUrl:
                    controller.state.draft.eventData!.externalBookingUrl,
              ),
              EventInventorySection(
                state: controller.eventInventoryState,
                controller: controller,
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

CreateController _controller() {
  final _MemoryRepository repository = _MemoryRepository();
  return CreateController(
    loadCreateDraftUseCase: LoadCreateDraftUseCase(repository),
    saveCreateDraftUseCase: SaveCreateDraftUseCase(repository),
    publishCreateDraftUseCase: PublishCreateDraftUseCase(repository),
    analyticsService: _NoopAnalyticsService(),
    eventCreateCoordinator: createTestEventCoordinator(),
    eventAdmissionConfigurationEnabled: true,
    eventMockAvailabilityEnabled: true,
    runtimeDefaults: const CreateRuntimeDefaults(
      marketCityId: 'riga',
      timezone: 'Europe/Riga',
      country: 'LV',
      city: 'Riga',
      currency: 'EUR',
    ),
  );
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
  ) async => draft;
}
