import 'package:uuid/uuid.dart';
import '../../domain/repositories/activity_place_link_repository.dart';

class CatalogActivityPlaceLinkRepository
    implements ActivityPlaceLinkRepository {
  const CatalogActivityPlaceLinkRepository({
    required this.query,
    required this.marketId,
    this.enabled = false,
  });
  final Future<Map<String, Object?>> Function(Map<String, Object?>) query;
  final String marketId;
  final bool enabled;
  Future<Map<String, Object?>?> _ask(
    String type,
    Map<String, Object?> payload,
  ) async {
    if (!enabled) return null;
    try {
      final result = await query(<String, Object?>{
        'schemaVersion': 1,
        'requestId': const Uuid().v4(),
        'queryType': type,
        'payload': <String, Object?>{'marketId': marketId, ...payload},
      });
      return result['schemaVersion'] == 1 && result['kind'] == 'succeeded'
          ? result
          : null;
    } catch (_) {
      return null;
    }
  }

  ActivityPlaceCandidate _place(Object? value) {
    if (value is! Map ||
        value['marketId'] != marketId ||
        value['contentId'] is! String ||
        (value['contentId'] as String).isEmpty ||
        value['title'] is! String ||
        (value['title'] as String).isEmpty ||
        value['publishedRevisionId'] is! String ||
        value['pointerRevision'] is! int ||
        (value['pointerRevision'] as int) < 1) {
      throw const FormatException('Place link contract');
    }
    return ActivityPlaceCandidate(
      id: value['contentId'] as String,
      title: value['title'] as String,
      publishedRevisionId: value['publishedRevisionId'] as String,
      pointerRevision: value['pointerRevision'] as int,
    );
  }

  @override
  Future<ActivityPlaceResolution> resolve(String id) async {
    final result = (await _ask('placeLink', <String, Object?>{
      'placeId': id,
    }))?['placeLink'];
    if (result is! Map ||
        !<String>[
          'eligible',
          'unknown',
          'forbidden',
          'unavailable',
        ].contains(result['status'])) {
      return const ActivityPlaceResolution('unavailable');
    }
    try {
      final place = result['status'] == 'eligible'
          ? _place(result['place'])
          : null;
      if (place != null && place.id != id) {
        return const ActivityPlaceResolution('unavailable');
      }
      return ActivityPlaceResolution(result['status'] as String, place);
    } catch (_) {
      return const ActivityPlaceResolution('unavailable');
    }
  }

  @override
  Future<ActivityPlacePage> candidates(String text, {String? after}) async {
    final result = (await _ask('placeCandidates', <String, Object?>{
      'text': text,
      'limit': 20,
      if (after != null) 'after': after,
    }))?['placeCandidates'];
    if (result is! Map ||
        result['status'] != 'available' ||
        result['items'] is! List ||
        (result['nextCursor'] != null && result['nextCursor'] is! String)) {
      return const ActivityPlacePage(available: false);
    }
    try {
      return ActivityPlacePage(
        available: true,
        items: (result['items'] as List).map(_place).toList(growable: false),
        nextCursor: result['nextCursor'] as String?,
      );
    } catch (_) {
      return const ActivityPlacePage(available: false);
    }
  }
}
