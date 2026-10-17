import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../../shared/primitives/money/money.dart';
import '../domain/entities/scenario_draft_entity.dart';

/// Persistence DTO for the existing Quick Plan aggregate, not a second model.
Map<String, Object?> encodeQuickPlan(ScenarioDraftEntity p) => {
  'id': p.id,
  'revision': p.revision,
  'mood': p.mood.name,
  'maxDurationMinutes': p.maxDurationMinutes,
  'freeOnly': p.freeOnly,
  'walkingOnly': p.walkingOnly,
  'sourcePrompt': p.sourcePrompt,
  'currencyCode': p.currencyCode,
  'steps': p.steps
      .map(
        (s) => <String, Object?>{
          'id': s.id,
          'sourceObjectId': s.sourceObjectId,
          'sourceObjectType': s.sourceObjectType,
          'title': s.title,
          'subtitle': s.subtitle,
          'category': s.category,
          'durationMinutes': s.durationMinutes,
          'distanceKm': s.distanceKm,
          'priceAmount': s.priceAmount.toJson(),
          'isFree': s.isFree,
          'latitude': s.latitude,
          'longitude': s.longitude,
        },
      )
      .toList(),
};
final _id = RegExp(
  r'^(?:[0-9A-HJKMNP-TV-Z]{26}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})$',
);
bool _keys(Map m, List<String> allowed) => m.keys.every(allowed.contains);
bool _text(Object? s, int max) => s is String && s.length <= max;
bool _int(Object? n, int max) => n is int && n >= 0 && n <= max;
bool _num(Object? n, num min, num max) =>
    n is num && n.isFinite && n >= min && n <= max;
ScenarioDraftEntity decodeQuickPlan(Object? raw) {
  if (raw is! Map ||
      !_keys(raw, [
        'id',
        'revision',
        'mood',
        'maxDurationMinutes',
        'freeOnly',
        'walkingOnly',
        'sourcePrompt',
        'currencyCode',
        'steps',
      ]) ||
      raw['id'] is! String ||
      !_id.hasMatch(raw['id'] as String) ||
      !_int(raw['revision'], 9007199254740991) ||
      !ScenarioMood.values.any((m) => m.name == raw['mood']) ||
      !_int(raw['maxDurationMinutes'], 1440) ||
      raw['freeOnly'] is! bool ||
      raw['walkingOnly'] is! bool ||
      !_text(raw['sourcePrompt'], 4096) ||
      raw['currencyCode'] is! String ||
      !RegExp(r'^[A-Z]{3}$').hasMatch(raw['currencyCode'] as String) ||
      raw['steps'] is! List ||
      (raw['steps'] as List).length > 32 ||
      utf8.encode(jsonEncode(raw)).length > 65536) {
    throw const FormatException('invalid Quick Plan');
  }
  final ids = <String>{};
  final steps = <ScenarioStepEntity>[];
  for (final s in raw['steps'] as List) {
    if (s is! Map ||
        !_keys(s, [
          'id',
          'sourceObjectId',
          'sourceObjectType',
          'title',
          'subtitle',
          'category',
          'durationMinutes',
          'distanceKm',
          'priceAmount',
          'isFree',
          'latitude',
          'longitude',
        ]) ||
        s['id'] is! String ||
        !_id.hasMatch(s['id'] as String) ||
        !ids.add(s['id'] as String) ||
        !_text(s['title'], 256) ||
        !_text(s['subtitle'], 1024) ||
        !_text(s['category'], 256) ||
        !_int(s['durationMinutes'], 1440) ||
        !_num(s['distanceKm'], 0, 10000) ||
        s['isFree'] is! bool ||
        !_num(s['latitude'], -90, 90) ||
        !_num(s['longitude'], -180, 180) ||
        (s['sourceObjectId'] != null &&
            (s['sourceObjectId'] is! String ||
                !_id.hasMatch(s['sourceObjectId'] as String))) ||
        (s['sourceObjectType'] != null && !_text(s['sourceObjectType'], 64))) {
      throw const FormatException('invalid stop');
    }
    final money = s['priceAmount'];
    if (money is! Map ||
        !_keys(money, ['minorUnits', 'currencyCode']) ||
        !_int(money['minorUnits'], 100000000000) ||
        money['currencyCode'] != raw['currencyCode']) {
      throw const FormatException('invalid money');
    }
    steps.add(
      ScenarioStepEntity(
        id: s['id'] as String,
        sourceObjectId: s['sourceObjectId'] as String?,
        sourceObjectType: s['sourceObjectType'] as String?,
        title: s['title'] as String,
        subtitle: s['subtitle'] as String,
        category: s['category'] as String,
        durationMinutes: s['durationMinutes'] as int,
        distanceKm: (s['distanceKm'] as num).toDouble(),
        priceAmount: Money(
          minorUnits: money['minorUnits'] as int,
          currencyCode: money['currencyCode'] as String,
        ),
        isFree: s['isFree'] as bool,
        latitude: (s['latitude'] as num).toDouble(),
        longitude: (s['longitude'] as num).toDouble(),
      ),
    );
  }
  return ScenarioDraftEntity(
    id: raw['id'] as String,
    revision: raw['revision'] as int,
    mood: ScenarioMood.values.byName(raw['mood'] as String),
    maxDurationMinutes: raw['maxDurationMinutes'] as int,
    freeOnly: raw['freeOnly'] as bool,
    walkingOnly: raw['walkingOnly'] as bool,
    sourcePrompt: raw['sourcePrompt'] as String,
    currencyCode: raw['currencyCode'] as String,
    steps: List.unmodifiable(steps),
  );
}

ScenarioDraftEntity parseQuickPlanImport(String source) {
  if (utf8.encode(source).length > 70000) {
    throw const FormatException('import too large');
  }
  final r = jsonDecode(source);
  if (r is! Map ||
      !_keys(r, ['format', 'schemaVersion', 'plan']) ||
      r['format'] != 'recharge.quickPlan' ||
      r['schemaVersion'] != 1) {
    throw const FormatException('unsupported import');
  }
  return decodeQuickPlan(r['plan']);
}

Object? _canonical(Object? v) {
  if (v is Map) {
    final keys = v.keys.cast<String>().toList()..sort();
    return {for (final k in keys) k: _canonical(v[k])};
  }
  if (v is List) return v.map(_canonical).toList();
  return v;
}

String quickPlanImportKey(ScenarioDraftEntity p) =>
    'import:${sha256.convert(utf8.encode(jsonEncode(_canonical(encodeQuickPlan(p)))))}';
