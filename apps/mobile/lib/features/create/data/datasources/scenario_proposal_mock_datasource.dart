import '../../domain/entities/scenario_draft_data.dart';
import '../../domain/entities/scenario_generation_proposal.dart';
import '../../domain/entities/scenario_logistics_draft.dart';
import '../../domain/repositories/catalog_object_picker_port.dart';
import '../../domain/repositories/scenario_proposal_generator_port.dart';

class MockScenarioProposalDataSource implements ScenarioProposalGeneratorPort {
  static const int _maximumProposalItems = 3;

  MockScenarioProposalDataSource({required CatalogObjectPickerPort catalog})
    : _catalog = catalog;

  final CatalogObjectPickerPort _catalog;
  int _sequence = 0;

  @override
  Future<ScenarioGenerationProposal> generate(
    ScenarioGenerationRequest request,
  ) async {
    final List<ScenarioCatalogObjectCandidate> catalog = await _catalog.search(
      '',
    );
    final String prompt = request.prompt.toLowerCase();
    final List<_ScoredCandidate> scored =
        <_ScoredCandidate>[
          for (int index = 0; index < catalog.length; index++)
            if (!request.existingCatalogObjectIds.contains(catalog[index].id))
              _ScoredCandidate(
                candidate: catalog[index],
                score: _score(catalog[index], prompt),
                originalIndex: index,
              ),
        ]..sort((_ScoredCandidate left, _ScoredCandidate right) {
          final int scoreOrder = right.score.compareTo(left.score);
          if (scoreOrder != 0) return scoreOrder;
          return left.originalIndex.compareTo(right.originalIndex);
        });

    final List<_ScoredCandidate> selected = scored
        .take(_maximumProposalItems)
        .toList(growable: false);
    final List<ScenarioGeneratedCatalogItem> items = selected
        .map(
          (_ScoredCandidate item) => ScenarioGeneratedCatalogItem(
            objectId: item.candidate.id,
            objectType: item.candidate.objectType,
            title: item.candidate.title,
            subtitle: item.candidate.subtitle,
            durationMinutes: item.candidate.durationMinutes,
            reason: _reason(item.candidate, prompt),
            confidence: ScenarioGenerationConfidence.catalogSnapshot,
            coverMediaId: item.candidate.coverMediaId,
            publisherId: item.candidate.publisherId,
          ),
        )
        .toList(growable: false);

    return ScenarioGenerationProposal(
      id: 'local-demo-${request.sourceRevision}-${++_sequence}',
      mode: ScenarioGenerationMode.localDemo,
      sourceRevision: request.sourceRevision,
      generatedAtUtc: DateTime.now().toUtc(),
      context: ScenarioGenerationContext(
        marketLabel: request.marketCityId.isEmpty
            ? 'Configured market'
            : request.marketCityId,
        formatLabel: _formatLabel(request.format),
        partyLabel: _partyLabel(request.peopleCount, request.partyKind),
        paceLabel: '${_enumLabel(request.pace.name)} pace',
        travelLabel: _travelLabel(request.travelMode),
        intentLabels: _intentLabels(prompt),
      ),
      items: items,
      evidence: <ScenarioGenerationEvidence>[
        for (final ScenarioGeneratedCatalogItem item in items)
          ScenarioGenerationEvidence(
            objectId: item.objectId,
            label: 'Matched local Recharge catalog snapshot',
            confidence: ScenarioGenerationConfidence.catalogSnapshot,
          ),
      ],
      issues: <ScenarioGenerationIssue>[
        if (items.isEmpty)
          const ScenarioGenerationIssue(
            code: ScenarioGenerationIssueCode.noCandidates,
            message: 'No new catalog candidates match this local demo.',
          ),
        const ScenarioGenerationIssue(
          code: ScenarioGenerationIssueCode.travelNotCalculated,
          message: 'Travel time is not calculated in the local demo.',
        ),
        const ScenarioGenerationIssue(
          code: ScenarioGenerationIssueCode.liveAvailabilityNotChecked,
          message: 'Opening hours and live availability are not checked.',
        ),
        const ScenarioGenerationIssue(
          code: ScenarioGenerationIssueCode.costsUnknown,
          message: 'Costs remain unknown until verified data are available.',
        ),
      ],
      activityMinutes: items.fold<int>(
        0,
        (int total, ScenarioGeneratedCatalogItem item) =>
            total + item.durationMinutes,
      ),
    );
  }

  int _score(ScenarioCatalogObjectCandidate candidate, String prompt) {
    final String haystack = '${candidate.title} ${candidate.subtitle}'
        .toLowerCase();
    var score = 0;
    for (final String token
        in prompt
            .split(RegExp(r'[\s,.;:!?()\-/]+'))
            .where((String value) => value.length >= 3)) {
      if (haystack.contains(token)) score += 5;
    }
    score += _semanticScore(
      prompt,
      haystack,
      const <String>['calm', 'quiet', 'relaxed', 'спокой', 'тих', 'mier'],
      const <String>['quiet', 'coffee', 'museum', 'canal', 'walk'],
    );
    score += _semanticScore(
      prompt,
      haystack,
      const <String>['culture', 'art', 'museum', 'cinema', 'культур', 'музе'],
      const <String>['art', 'museum', 'cinema', 'screening'],
    );
    score += _semanticScore(
      prompt,
      haystack,
      const <String>['food', 'dinner', 'coffee', 'еда', 'ужин', 'кофе'],
      const <String>['coffee', 'dinner', 'food'],
    );
    score += _semanticScore(
      prompt,
      haystack,
      const <String>['walk', 'walking', 'photo', 'прогул', 'пеш', 'maršrut'],
      const <String>['walk', 'walking', 'route', 'canal', 'photo'],
    );
    score += _semanticScore(
      prompt,
      haystack,
      const <String>['evening', 'night', 'вечер', 'ноч', 'vakar'],
      const <String>['evening', 'cinema', 'dinner', 'sunset'],
    );
    return score;
  }

  int _semanticScore(
    String prompt,
    String haystack,
    List<String> intentTerms,
    List<String> candidateTerms,
  ) {
    if (!intentTerms.any(prompt.contains)) return 0;
    return candidateTerms.any(haystack.contains) ? 3 : 0;
  }

  String _reason(ScenarioCatalogObjectCandidate candidate, String prompt) {
    final String haystack = '${candidate.title} ${candidate.subtitle}'
        .toLowerCase();
    if (<String>['quiet', 'coffee', 'museum', 'canal'].any(haystack.contains) &&
        <String>[
          'calm',
          'quiet',
          'спокой',
          'тих',
          'mier',
        ].any(prompt.contains)) {
      return 'Matches the calm pace in your request';
    }
    if (<String>['art', 'museum', 'cinema'].any(haystack.contains) &&
        <String>['culture', 'art', 'культур', 'музе'].any(prompt.contains)) {
      return 'Matches your culture interest';
    }
    if (<String>['dinner', 'coffee', 'food'].any(haystack.contains) &&
        <String>[
          'food',
          'dinner',
          'еда',
          'ужин',
          'кофе',
        ].any(prompt.contains)) {
      return 'Matches the food stop in your request';
    }
    if (<String>['walk', 'route', 'photo', 'canal'].any(haystack.contains) &&
        <String>[
          'walk',
          'walking',
          'прогул',
          'пеш',
          'maršrut',
        ].any(prompt.contains)) {
      return 'Matches your walking preference';
    }
    return 'Balanced local catalog suggestion';
  }

  List<String> _intentLabels(String prompt) {
    final List<String> labels = <String>[];
    if (<String>[
      'calm',
      'quiet',
      'relaxed',
      'спокой',
      'тих',
      'mier',
    ].any(prompt.contains)) {
      labels.add('Calm');
    }
    if (<String>[
      'culture',
      'art',
      'museum',
      'культур',
      'музе',
    ].any(prompt.contains)) {
      labels.add('Culture');
    }
    if (<String>[
      'food',
      'dinner',
      'coffee',
      'еда',
      'ужин',
      'кофе',
    ].any(prompt.contains)) {
      labels.add('Food');
    }
    if (<String>[
      'walk',
      'walking',
      'прогул',
      'пеш',
      'maršrut',
    ].any(prompt.contains)) {
      labels.add('Walking');
    }
    return labels;
  }

  String _formatLabel(ScenarioFormat format) => switch (format) {
    ScenarioFormat.city => 'City plan',
    ScenarioFormat.day => 'Day plan',
    ScenarioFormat.weekend => 'Weekend plan',
    ScenarioFormat.trip => 'Trip plan',
  };

  String _partyLabel(int peopleCount, ScenarioPartyKind partyKind) =>
      '$peopleCount ${peopleCount == 1 ? 'person' : 'people'} · '
      '${_enumLabel(partyKind.name)}';

  String _travelLabel(ScenarioTravelMode mode) => switch (mode) {
    ScenarioTravelMode.car => 'Own car',
    ScenarioTravelMode.walking => 'Walking',
    ScenarioTravelMode.bicycle => 'Bicycle',
    ScenarioTravelMode.transit => 'Public transport',
    ScenarioTravelMode.taxi => 'Taxi',
    ScenarioTravelMode.other => 'Other travel',
  };

  String _enumLabel(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}

class _ScoredCandidate {
  const _ScoredCandidate({
    required this.candidate,
    required this.score,
    required this.originalIndex,
  });

  final ScenarioCatalogObjectCandidate candidate;
  final int score;
  final int originalIndex;
}
