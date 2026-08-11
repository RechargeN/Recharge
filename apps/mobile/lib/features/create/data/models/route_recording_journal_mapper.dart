import '../../../../core/geo/geo_point.dart';
import '../../domain/entities/route_recording_data.dart';

class RouteRecordingJournalMapper {
  const RouteRecordingJournalMapper();

  Map<String, Object?> sampleToJson(RouteRecordingSample sample) =>
      <String, Object?>{
        'latitude': sample.position.latitude,
        'longitude': sample.position.longitude,
        if (sample.position.elevationMeters != null)
          'elevationMeters': sample.position.elevationMeters,
        'horizontalAccuracyMeters': sample.horizontalAccuracyMeters,
        'elapsedMilliseconds': sample.elapsedMilliseconds,
        'capturedAtUtc': sample.capturedAtUtc.toIso8601String(),
        'source': sample.source.name,
        'isMocked': sample.isMocked,
      };

  RouteRecordingSample sampleFromJson(Map<String, Object?> json) {
    final capturedAtUtc = DateTime.parse(
      _requiredString(json, 'capturedAtUtc'),
    );
    final sample = RouteRecordingSample(
      position: GeoPoint(
        latitude: _requiredNum(json, 'latitude').toDouble(),
        longitude: _requiredNum(json, 'longitude').toDouble(),
        elevationMeters: (json['elevationMeters'] as num?)?.toDouble(),
      ),
      horizontalAccuracyMeters: _requiredNum(
        json,
        'horizontalAccuracyMeters',
      ).toDouble(),
      elapsedMilliseconds: _requiredNum(json, 'elapsedMilliseconds').toInt(),
      capturedAtUtc: capturedAtUtc,
      source: RouteRecordingSampleSource.values.byName(
        _requiredString(json, 'source'),
      ),
      isMocked: json['isMocked'] as bool? ?? false,
    );
    if (!sample.isValid) {
      throw const FormatException('Invalid route recording sample.');
    }
    return sample;
  }

  Map<String, Object?> manifestToJson(
    RouteRecordingJournal journal, {
    required int chunkSize,
  }) => <String, Object?>{
    'schemaVersion': journal.schemaVersion,
    'revision': journal.revision,
    'sessionId': journal.sessionId,
    'draftId': journal.draftId,
    'startedAtUtc': journal.startedAtUtc.toIso8601String(),
    'updatedAtUtc': journal.updatedAtUtc.toIso8601String(),
    'status': journal.status.name,
    'chunkSize': chunkSize,
    'legs': journal.legs
        .map(
          (leg) => <String, Object?>{
            'id': leg.id,
            'sampleCount': leg.samples.length,
            'chunkCount': (leg.samples.length + chunkSize - 1) ~/ chunkSize,
          },
        )
        .toList(growable: false),
  };

  RouteRecordingJournal journalFromParts({
    required Map<String, Object?> manifest,
    required Map<String, List<RouteRecordingSample>> samplesByLegId,
    required int expectedChunkSize,
  }) {
    if (_requiredNum(manifest, 'schemaVersion').toInt() != 1 ||
        _requiredNum(manifest, 'chunkSize').toInt() != expectedChunkSize) {
      throw const FormatException('Unsupported GPS journal schema.');
    }
    final rawLegs = manifest['legs'];
    if (rawLegs is! List<Object?> || rawLegs.isEmpty) {
      throw const FormatException('GPS journal has no legs.');
    }
    final legs = rawLegs
        .map((raw) {
          if (raw is! Map<Object?, Object?>) {
            throw const FormatException('Invalid GPS journal leg.');
          }
          final legJson = raw.cast<String, Object?>();
          final id = _requiredString(legJson, 'id');
          final expectedCount = _requiredNum(legJson, 'sampleCount').toInt();
          final samples = samplesByLegId[id];
          if (samples == null || samples.length != expectedCount) {
            throw const FormatException('Incomplete GPS journal leg.');
          }
          return RouteRecordingLeg(id: id, samples: samples);
        })
        .toList(growable: false);
    final journal = RouteRecordingJournal(
      schemaVersion: _requiredNum(manifest, 'schemaVersion').toInt(),
      revision: _requiredNum(manifest, 'revision').toInt(),
      sessionId: _requiredString(manifest, 'sessionId'),
      draftId: _requiredString(manifest, 'draftId'),
      startedAtUtc: DateTime.parse(_requiredString(manifest, 'startedAtUtc')),
      updatedAtUtc: DateTime.parse(_requiredString(manifest, 'updatedAtUtc')),
      status: RouteRecordingJournalStatus.values.byName(
        _requiredString(manifest, 'status'),
      ),
      legs: legs,
    );
    if (!journal.isValid) {
      throw const FormatException('Invalid GPS journal.');
    }
    return journal;
  }

  String legId(Map<String, Object?> leg) => _requiredString(leg, 'id');

  int legSampleCount(Map<String, Object?> leg) =>
      _requiredNum(leg, 'sampleCount').toInt();

  int legChunkCount(Map<String, Object?> leg) =>
      _requiredNum(leg, 'chunkCount').toInt();

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Missing $key.');
    }
    return value;
  }

  static num _requiredNum(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! num) throw FormatException('Missing $key.');
    return value;
  }
}
