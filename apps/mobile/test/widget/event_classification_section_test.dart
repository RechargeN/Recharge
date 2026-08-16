import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/application/event_classification_section.dart';
import 'package:recharge/features/create/domain/entities/event_classification.dart';
import 'package:recharge/features/create/domain/entities/event_validation_issue.dart';
import 'package:recharge/features/create/domain/usecases/suggest_event_classification_usecase.dart';
import 'package:recharge/features/create/presentation/widgets/event_classification_section.dart';

void main() {
  testWidgets('suggestion stays explicit and calls confirmation command', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var confirmations = 0;

    await tester.pumpWidget(
      _host(
        state: const EventClassificationSectionState(
          enabled: true,
          classification: null,
          suggestion: EventClassificationSuggestion(
            archetype: EventArchetype.competition,
            reasonCode: 'canonical_subcategory_exact',
            confidence: EventClassificationSuggestionConfidence.high,
          ),
          issues: <EventValidationIssue>[],
        ),
        onConfirmSuggestion: () => confirmations += 1,
      ),
    );

    expect(find.text('Suggested: Competition'), findsOneWidget);
    expect(find.textContaining('only a suggestion'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('event-classification-confirm-suggestion')),
    );
    expect(confirmations, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('works at 360 dp and 150% text without horizontal overflow', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final List<(ParticipationMode, bool)> changes =
        <(ParticipationMode, bool)>[];

    await tester.pumpWidget(
      _host(
        textScaler: const TextScaler.linear(1.5),
        state: EventClassificationSectionState(
          enabled: true,
          classification: EventClassificationDraft(
            archetype: EventArchetype.other,
            primaryParticipationMode: ParticipationMode.attend,
            additionalParticipationModes: const <ParticipationMode>{
              ParticipationMode.learn,
              ParticipationMode.create,
              ParticipationMode.support,
            },
          ),
          suggestion: null,
          issues: const <EventValidationIssue>[
            EventValidationIssue(
              code: 'event_archetype_other_reason_required',
              fieldId: 'eventArchetypeOtherReason',
              step: 0,
              message: 'Explain the event mechanics when choosing Other.',
            ),
          ],
        ),
        onAdditionalParticipationChanged: (ParticipationMode mode, bool value) {
          changes.add((mode, value));
        },
      ),
    );

    expect(
      find.text('Explain the event mechanics when choosing Other.'),
      findsOneWidget,
    );
    final FilterChip disabled = tester.widget<FilterChip>(
      find.byKey(const Key('event-additional-watch')),
    );
    expect(disabled.onSelected, isNull);
    final FilterChip selected = tester.widget<FilterChip>(
      find.byKey(const Key('event-additional-learn')),
    );
    selected.onSelected!(false);
    expect(changes, <(ParticipationMode, bool)>[
      (ParticipationMode.learn, false),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled flag hides section but preserves caller state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        state: EventClassificationSectionState(
          enabled: false,
          classification: EventClassificationDraft(
            archetype: EventArchetype.performance,
            primaryParticipationMode: ParticipationMode.watch,
          ),
          suggestion: null,
          issues: const <EventValidationIssue>[],
        ),
      ),
    );

    expect(find.byKey(const Key('event-classification-section')), findsNothing);
  });
}

Widget _host({
  required EventClassificationSectionState state,
  TextScaler textScaler = TextScaler.noScaling,
  VoidCallback? onConfirmSuggestion,
  void Function(ParticipationMode mode, bool selected)?
  onAdditionalParticipationChanged,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: EventClassificationSection(
            state: state,
            onArchetypeChanged: (_) {},
            onPrimaryParticipationChanged: (_) {},
            onAdditionalParticipationChanged:
                onAdditionalParticipationChanged ?? (_, _) {},
            onOtherReasonChanged: (_) {},
            onConfirmSuggestion: onConfirmSuggestion ?? () {},
            onClear: () {},
          ),
        ),
      ),
    ),
  );
}
