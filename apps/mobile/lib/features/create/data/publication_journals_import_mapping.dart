import 'dart:io';

import 'file_activity_publication_journal.dart';
import 'file_collection_publication_journal.dart';
import 'file_event_publication_journal.dart';
import 'file_place_publication_journal.dart';
import '../domain/entities/publisher_ref.dart';
import '../domain/repositories/local_import_gateway.dart';

/// Server objects the test publication paths already created for a local
/// draft (C3, D3.1, D3.2, D3.4), read from their own journals (D4 §5.5). The
/// Event journal predates account binding and is matched by local id only.
final class PublicationJournalsImportMapping
    implements LocalImportExistingPublications {
  const PublicationJournalsImportMapping({
    required this.event,
    required this.place,
    required this.activity,
    required this.collection,
  });

  /// Files at the same paths the test publication compositions use.
  factory PublicationJournalsImportMapping.inDirectory(Directory content) {
    String path(String name) => '${content.path}${Platform.pathSeparator}$name';
    return PublicationJournalsImportMapping(
      event: File(path('event-publications-v1.json')),
      place: File(path('place-publications-v1.json')),
      activity: File(path('activity-publications-v1.json')),
      collection: File(path('collection-publications-v1.json')),
    );
  }

  final File event;
  final File place;
  final File activity;
  final File collection;

  @override
  Future<String?> contentIdFor({
    required String typeId,
    required String accountId,
    required PublisherRef publisherRef,
    required String localDraftId,
  }) async {
    switch (typeId) {
      case 'event':
        return (await FileEventPublicationJournal(
          event,
        ).forLocalDraft(localDraftId))?.contentId;
      case 'place':
        return (await FilePlacePublicationJournal(place).forLocalDraft(
          accountId: accountId,
          publisherRef: publisherRef,
          localDraftId: localDraftId,
        ))?.contentId;
      case 'activity':
        return (await FileActivityPublicationJournal(activity).forLocalDraft(
          accountId: accountId,
          publisherRef: publisherRef,
          localDraftId: localDraftId,
        ))?.contentId;
      case 'collection':
        return (await FileCollectionPublicationJournal(
              collection,
            ).forLocalDraft(
              accountId: accountId,
              publisherRef: publisherRef,
              localDraftId: localDraftId,
            ))
            ?.contentId;
    }
    return null;
  }
}
