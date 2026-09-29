import '../../features/create/domain/entities/create_draft_entity.dart';
import '../../features/create/domain/entities/scenario_item_draft.dart';
import '../../features/notifications/domain/entities/notification_item_entity.dart';

class ScenarioObjectUpdate {
  const ScenarioObjectUpdate({
    required this.updateId,
    required this.subjectRef,
    required this.title,
    required this.body,
    required this.createdAtUtc,
  });

  final String updateId;
  final NotificationSubjectRef subjectRef;
  final String title;
  final String body;
  final DateTime createdAtUtc;
}

class ProjectScenarioObjectNotifications {
  const ProjectScenarioObjectNotifications();

  List<NotificationItemEntity> call({
    required CreateDraftEntity scenarioDraft,
    required ScenarioObjectUpdate update,
  }) {
    final scenario = scenarioDraft.scenarioData;
    if (scenario == null || !scenario.updatesEnabled) {
      return const <NotificationItemEntity>[];
    }
    return scenario.items
        .where((item) {
          final source = item.source;
          return source is ScenarioCatalogObjectSourceDraft &&
              source.objectId == update.subjectRef.id &&
              _subjectKind(source.objectType) == update.subjectRef.kind;
        })
        .map(
          (item) => NotificationItemEntity(
            id: '${update.updateId}:${scenarioDraft.id}:${item.id}',
            title: update.title,
            body: update.body,
            type: NotificationType.activity,
            createdAtUtc: update.createdAtUtc.toUtc(),
            isRead: false,
            // New Scenario object notifications navigate by the typed subject
            // reference. Raw URLs remain a legacy-read concern only.
            targetRoute: null,
            subjectRef: update.subjectRef,
            scenarioContext: ScenarioNotificationContext(
              scenarioDraftId: scenarioDraft.id,
              scenarioItemId: item.id,
            ),
          ),
        )
        .toList(growable: false);
  }

  NotificationSubjectKind _subjectKind(ScenarioCatalogObjectType kind) =>
      switch (kind) {
        ScenarioCatalogObjectType.event => NotificationSubjectKind.event,
        ScenarioCatalogObjectType.place => NotificationSubjectKind.place,
        ScenarioCatalogObjectType.route => NotificationSubjectKind.route,
        ScenarioCatalogObjectType.activity => NotificationSubjectKind.activity,
        ScenarioCatalogObjectType.bookableSession =>
          NotificationSubjectKind.bookableSession,
      };
}
