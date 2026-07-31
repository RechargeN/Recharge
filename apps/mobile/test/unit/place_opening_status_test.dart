import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/place_draft_data.dart';
import 'package:recharge/features/create/domain/usecases/evaluate_place_opening_status_usecase.dart';

void main() {
  const EvaluatePlaceOpeningStatusUseCase evaluate =
      EvaluatePlaceOpeningStatusUseCase();

  test('evaluates explicit overnight across midnight', () {
    final PlaceDraftData place = _base().copyWith(
      hours: const PlaceHoursDraft(
        mode: PlaceHoursMode.regular,
        weeklyPeriods: <LocalOpeningPeriod>[
          LocalOpeningPeriod(
            id: 'period-1',
            dayOfWeek: DateTime.friday,
            openMinute: 22 * 60,
            closeMinute: 2 * 60,
            closesNextDay: true,
          ),
        ],
      ),
    );

    expect(evaluate(place, DateTime(2026, 7, 18, 1)), PlaceOpeningState.open);
    expect(evaluate(place, DateTime(2026, 7, 18, 3)), PlaceOpeningState.closed);
  });

  test('today exception cancels interval that started yesterday', () {
    final PlaceDraftData place = _base().copyWith(
      hours: const PlaceHoursDraft(
        mode: PlaceHoursMode.regular,
        weeklyPeriods: <LocalOpeningPeriod>[
          LocalOpeningPeriod(
            id: 'period-1',
            dayOfWeek: DateTime.friday,
            openMinute: 22 * 60,
            closeMinute: 2 * 60,
            closesNextDay: true,
          ),
        ],
        exceptions: <OpeningException>[
          OpeningException(
            id: 'exception-1',
            localDate: '2026-07-18',
            kind: OpeningExceptionKind.closedAllDay,
          ),
        ],
      ),
    );

    expect(evaluate(place, DateTime(2026, 7, 18, 1)), PlaceOpeningState.closed);
  });

  test('temporary closure end date is inclusive in Place timezone', () {
    final PlaceDraftData place = _base().copyWith(
      hours: const PlaceHoursDraft(mode: PlaceHoursMode.alwaysOpen),
      operationalStatus: const PlaceOperationalStatusDraft(
        status: PlaceOperationalStatus.temporarilyClosed,
        closedFromLocalDate: '2026-07-10',
        closedUntilLocalDate: '2026-07-20',
      ),
    );

    expect(
      evaluate(place, DateTime(2026, 7, 20, 23, 59)),
      PlaceOpeningState.closed,
    );
    expect(evaluate(place, DateTime(2026, 7, 21)), PlaceOpeningState.open);
  });

  test('always open supports closed holiday exception', () {
    final PlaceDraftData place = _base().copyWith(
      hours: const PlaceHoursDraft(
        mode: PlaceHoursMode.alwaysOpen,
        exceptions: <OpeningException>[
          OpeningException(
            id: 'exception-1',
            localDate: '2026-12-25',
            kind: OpeningExceptionKind.closedAllDay,
          ),
        ],
      ),
    );

    expect(
      evaluate(place, DateTime(2026, 12, 25, 12)),
      PlaceOpeningState.closed,
    );
    expect(evaluate(place, DateTime(2026, 12, 26, 12)), PlaceOpeningState.open);
  });
}

PlaceDraftData _base() => PlaceDraftData.defaults(
  userId: 'user-1',
  marketCityId: 'riga',
  countryCode: 'LV',
  city: 'Riga',
  timezoneId: 'Europe/Riga',
  currencyCode: 'EUR',
);
