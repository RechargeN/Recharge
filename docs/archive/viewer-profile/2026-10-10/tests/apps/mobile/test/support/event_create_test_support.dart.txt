import 'package:recharge/features/create/application/event_create_coordinator.dart';
import 'package:recharge/features/create/data/repositories/event_timezone_repository_impl.dart';
import 'package:recharge/features/create/domain/usecases/materialize_event_schedule_usecase.dart';

EventCreateCoordinator createTestEventCoordinator() {
  return EventCreateCoordinator(
    materializeSchedule: MaterializeEventScheduleUseCase(
      EventTimezoneRepositoryImpl(),
    ),
  );
}
