import '../../domain/entities/scenario_item_draft.dart';
import '../../domain/repositories/catalog_object_picker_port.dart';

class MockCatalogObjectPickerDataSource implements CatalogObjectPickerPort {
  const MockCatalogObjectPickerDataSource();

  static const List<ScenarioCatalogObjectCandidate> _objects =
      <ScenarioCatalogObjectCandidate>[
        ScenarioCatalogObjectCandidate(
          id: '01JSCENARIOPLACE001',
          objectType: ScenarioCatalogObjectType.place,
          title: 'Quiet coffee stop',
          subtitle: 'Riga centre · Place',
          durationMinutes: 45,
        ),
        ScenarioCatalogObjectCandidate(
          id: '01JSCENARIOEVENT001',
          objectType: ScenarioCatalogObjectType.event,
          title: 'Evening cinema screening',
          subtitle: 'Riga centre · Event',
          durationMinutes: 120,
        ),
        ScenarioCatalogObjectCandidate(
          id: '01JSCENARIOACTIVITY1',
          objectType: ScenarioCatalogObjectType.activity,
          title: 'Old town photo walk',
          subtitle: 'Riga centre · Activity',
          durationMinutes: 90,
        ),
        ScenarioCatalogObjectCandidate(
          id: '01JSCENARIOROUTE001',
          objectType: ScenarioCatalogObjectType.route,
          title: 'Canal-side walking route',
          subtitle: '4.2 km · Route object',
          durationMinutes: 75,
        ),
        ScenarioCatalogObjectCandidate(
          id: '01JSCENARIOPLACE002',
          objectType: ScenarioCatalogObjectType.place,
          title: 'Riga art museum visit',
          subtitle: 'Riga centre · Place demo',
          durationMinutes: 90,
        ),
        ScenarioCatalogObjectCandidate(
          id: '01JSCENARIOSESSION1',
          objectType: ScenarioCatalogObjectType.bookableSession,
          title: 'Old town dinner table',
          subtitle: 'Riga centre · Bookable session demo',
          durationMinutes: 90,
        ),
        ScenarioCatalogObjectCandidate(
          id: '01JSCENARIOACTIVITY2',
          objectType: ScenarioCatalogObjectType.activity,
          title: 'Canal sunset walk',
          subtitle: 'Riga centre · Activity demo',
          durationMinutes: 60,
        ),
      ];

  @override
  Future<List<ScenarioCatalogObjectCandidate>> search(String query) async {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) return _objects;
    return _objects
        .where(
          (ScenarioCatalogObjectCandidate item) =>
              item.title.toLowerCase().contains(needle) ||
              item.subtitle.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }
}
