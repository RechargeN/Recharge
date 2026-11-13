import 'package:uuid/uuid.dart';

import '../../domain/entities/collection_content_publication.dart';
import '../../domain/entities/collection_item_draft.dart';
import '../../domain/repositories/collection_catalog_search_repository.dart';
import '../../domain/repositories/collection_content_publication_gateway.dart';

/// The Catalog listing type of each Collection item type (D3.4 §2.3).
const Map<CollectionCatalogObjectType, String> collectionListingTypeIds =
    <CollectionCatalogObjectType, String>{
      CollectionCatalogObjectType.place: 'place',
      CollectionCatalogObjectType.route: 'route',
      CollectionCatalogObjectType.bookableSession: 'session',
      CollectionCatalogObjectType.classWorkshop: 'class_workshop',
      CollectionCatalogObjectType.rental: 'rental',
    };

/// The Collection item picker over the server Catalog (D3.4 §5.1): candidates
/// and exact statuses come from the Catalog-owned evaluator through the
/// existing `discoverQueryV1` envelope (`publishedObjectCandidates`,
/// `publishedObject`). It never creates an index or a Collection model of its
/// own and never falls back to mock data: an unreadable answer is an empty
/// page or `unavailable`.
final class CatalogCollectionCatalogSearchRepository
    implements CollectionCatalogSearchRepository, CollectionMembershipReader {
  CatalogCollectionCatalogSearchRepository({
    required this.query,
    required this.marketId,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final Future<Map<String, Object?>> Function(Map<String, Object?>) query;
  final String marketId;
  final DateTime Function() _clock;

  /// Results kept per type, and the bound on Catalog pages read for them: a
  /// candidate page is a page of source pointers, filtered by the evaluator.
  static const int resultsPerType = 20;
  static const int pageSize = 50;
  static const int maxPages = 10;

  Future<Object?> _ask(String type, Map<String, Object?> payload) async {
    try {
      final Map<String, Object?> result = await query(<String, Object?>{
        'schemaVersion': 1,
        'requestId': const Uuid().v4(),
        'queryType': type,
        'payload': <String, Object?>{'marketId': marketId, ...payload},
      });
      return result['schemaVersion'] == 1 && result['kind'] == 'succeeded'
          ? result[type]
          : null;
    } catch (_) {
      return null;
    }
  }

  /// An eligible object exactly as the contract allows it, or null.
  ({String contentId, String title})? _object(Object? value, String typeId) {
    if (value is! Map ||
        value['typeId'] != typeId ||
        value['marketId'] != marketId ||
        value['contentId'] is! String ||
        (value['contentId'] as String).isEmpty ||
        value['title'] is! String ||
        (value['title'] as String).isEmpty ||
        value['publishedRevisionId'] is! String ||
        value['pointerRevision'] is! int) {
      return null;
    }
    return (
      contentId: value['contentId'] as String,
      title: value['title'] as String,
    );
  }

  @override
  Future<List<CollectionCatalogSearchResult>> search(
    CollectionCatalogSearchQuery query,
  ) async {
    final DateTime checkedAt = _clock();
    final List<CollectionCatalogSearchResult> results =
        <CollectionCatalogSearchResult>[];
    for (final CollectionCatalogObjectType type
        in CollectionCatalogObjectType.values) {
      if (!query.allowedTypes.contains(type)) continue;
      final String typeId = collectionListingTypeIds[type]!;
      int kept = 0;
      String? after;
      for (int index = 0; index < maxPages && kept < resultsPerType; index++) {
        final Object? page =
            await _ask('publishedObjectCandidates', <String, Object?>{
              'typeId': typeId,
              'text': query.text.length > 100
                  ? query.text.substring(0, 100)
                  : query.text,
              'limit': pageSize,
              if (after != null) 'after': after,
            });
        if (page is! Map ||
            page['status'] != 'available' ||
            page['items'] is! List) {
          break;
        }
        for (final Object? item in page['items'] as List) {
          final ({String contentId, String title})? object = _object(
            item,
            typeId,
          );
          if (object == null || kept >= resultsPerType) continue;
          final CollectionObjectRef ref = CollectionObjectRef(
            objectId: object.contentId,
            objectType: type,
          );
          if (query.excludeRefs.contains(ref)) continue;
          kept += 1;
          results.add(
            CollectionCatalogSearchResult(
              ref: ref,
              snapshot: CollectionItemSnapshotDraft(
                title: object.title,
                checkedAtUtc: checkedAt,
              ),
            ),
          );
        }
        final Object? next = page['nextCursor'];
        if (next is! String) break;
        after = next;
      }
    }
    return results;
  }

  /// Only eligible objects resolve; anything else is absent and therefore
  /// unavailable in the authoring preview (the exact reason is [statusOf]).
  @override
  Future<Map<String, CollectionCatalogSearchResult>> resolve(
    List<CollectionObjectRef> refs,
  ) async {
    final DateTime checkedAt = _clock();
    final Map<String, CollectionCatalogSearchResult> resolved =
        <String, CollectionCatalogSearchResult>{};
    for (final CollectionObjectRef ref in refs) {
      final CollectionMemberStatus status = await statusOf(ref);
      final String? title = status.title;
      if (status.status == 'eligible' && title != null) {
        resolved[ref.stableKey] = CollectionCatalogSearchResult(
          ref: ref,
          snapshot: CollectionItemSnapshotDraft(
            title: title,
            checkedAtUtc: checkedAt,
          ),
        );
      }
    }
    return resolved;
  }

  @override
  Future<CollectionMemberStatus> statusOf(CollectionObjectRef ref) async {
    final String typeId = collectionListingTypeIds[ref.objectType]!;
    final Object? answer = await _ask('publishedObject', <String, Object?>{
      'typeId': typeId,
      'contentId': ref.objectId,
    });
    final Object? status = answer is Map ? answer['status'] : null;
    if (status == 'eligible') {
      final ({String contentId, String title})? object = _object(
        (answer as Map)['object'],
        typeId,
      );
      return object == null || object.contentId != ref.objectId
          ? CollectionMemberStatus(ref: ref, status: 'unavailable')
          : CollectionMemberStatus(
              ref: ref,
              status: 'eligible',
              title: object.title,
            );
    }
    return CollectionMemberStatus(
      ref: ref,
      status:
          const <String>{'withheld', 'unknown', 'forbidden'}.contains(status)
          ? status! as String
          : 'unavailable',
    );
  }
}
