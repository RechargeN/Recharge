import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/application/route_publication_coordinator.dart';
import 'package:recharge/features/create/application/route_quality_workflow_coordinator.dart';
import 'package:recharge/features/create/data/datasources/route_publication_memory_datasource.dart';
import 'package:recharge/features/create/data/datasources/route_quality_workflow_memory_datasource.dart';
import 'package:recharge/features/create/data/policies/demo_route_authoring_policy.dart';
import 'package:recharge/features/create/data/repositories/route_publication_repository_impl.dart';
import 'package:recharge/features/create/data/repositories/route_quality_workflow_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/route_draft_data.dart';
import 'package:recharge/features/create/domain/entities/route_publication_data.dart';
import 'package:recharge/features/create/domain/entities/route_quality_data.dart';
import 'package:recharge/features/create/domain/entities/route_quality_workflow_data.dart';
import 'package:recharge/features/create/domain/repositories/route_publication_index_sink.dart';
import 'package:recharge/features/create/domain/usecases/build_route_publication_bundle_usecase.dart';

import '../support/route_domain_fixtures.dart';

void main() {
  group('immutable Route publication', () {
    test('builds one coherent version, geometry and search projection', () {
      final bundle = _bundle(
        draft: _draft(),
        routeId: 'route-1',
        versionId: 'version-1',
        attemptId: 'attempt-1',
      );

      expect(bundle.version.routeId, 'route-1');
      expect(bundle.version.geometry.routeId, 'route-1');
      expect(bundle.version.projection.routeId, 'route-1');
      expect(bundle.version.geometry.versionId, 'version-1');
      expect(bundle.version.projection.versionId, 'version-1');
      expect(
        bundle.version.geometry.geometryHash,
        bundle.version.projection.geometryHash,
      );
      expect(bundle.version.geometry.segments, hasLength(1));
      expect(bundle.version.contentSnapshot.id, 'route-1');
      expect(
        bundle.version.contentSnapshot.publishStatus,
        PublishStatus.published,
      );
    });

    test('submission does not activate until an admin approves it', () async {
      final indexSink = _RecordingRouteIndexSink();
      final repository = RoutePublicationRepositoryImpl(
        RoutePublicationMemoryDataSource(),
        indexSink: indexSink,
      );
      final bundle = _bundle(
        draft: _draft(),
        routeId: 'route-1',
        versionId: 'version-1',
        attemptId: 'submit-1',
      );

      final submitted = await repository.submitForReview(
        requestId: 'request-1',
        bundle: bundle,
      );

      expect(submitted.status, RoutePublishReceiptStatus.submitted);
      expect(indexSink.activated, isEmpty);
      expect(await repository.routeById('route-1'), isNull);
      expect(await repository.pendingRequests(), hasLength(1));

      final approved = await repository.decide(
        RouteModerationDecision(
          requestId: 'request-1',
          approved: true,
          actorId: 'admin-1',
          attemptId: 'decision-1',
          decidedAtUtc: DateTime.utc(2026, 7, 25, 10),
        ),
      );
      final route = await repository.routeById('route-1');

      expect(approved.isPublished, isTrue);
      expect(indexSink.activated.single.versionId, 'version-1');
      expect(route?.activeVersionId, 'version-1');
      expect(route?.auditTrail.map((event) => event.action), <String>[
        'route_submitted',
        'route_moderation_approved',
      ]);
    });

    test(
      'published version stays active while its revision awaits review',
      () async {
        final repository = RoutePublicationRepositoryImpl(
          RoutePublicationMemoryDataSource(),
        );
        final first = _bundle(
          draft: _draft(),
          routeId: 'route-1',
          versionId: 'version-1',
          attemptId: 'direct-1',
          mode: RoutePublicationMode.trustedDirect,
        );
        await repository.publishDirect(first);
        final current = await repository.routeById('route-1');
        final second = _bundle(
          draft: _draft(title: 'Revised forest loop'),
          routeId: 'route-1',
          versionId: 'version-2',
          attemptId: 'submit-2',
          current: current,
        );

        await repository.submitForReview(
          requestId: 'request-2',
          bundle: second,
        );

        expect(
          (await repository.routeById('route-1'))?.activeVersionId,
          'version-1',
        );

        await repository.decide(
          RouteModerationDecision(
            requestId: 'request-2',
            approved: true,
            actorId: 'admin-1',
            attemptId: 'decision-2',
            decidedAtUtc: DateTime.utc(2026, 7, 25, 11),
          ),
        );

        expect(
          (await repository.routeById('route-1'))?.activeVersionId,
          'version-2',
        );
      },
    );

    test(
      'rejection needs a reason and never changes the active version',
      () async {
        final repository = RoutePublicationRepositoryImpl(
          RoutePublicationMemoryDataSource(),
        );
        final bundle = _bundle(
          draft: _draft(),
          routeId: 'route-1',
          versionId: 'version-1',
          attemptId: 'submit-1',
        );
        await repository.submitForReview(
          requestId: 'request-1',
          bundle: bundle,
        );

        final missingReason = await repository.decide(
          RouteModerationDecision(
            requestId: 'request-1',
            approved: false,
            actorId: 'admin-1',
            attemptId: 'reject-1',
            decidedAtUtc: DateTime.utc(2026, 7, 25, 12),
          ),
        );
        expect(missingReason.status, RoutePublishReceiptStatus.invalid);
        expect(missingReason.reasonCode, 'rejection_reason_required');
        expect(await repository.pendingRequests(), hasLength(1));

        final rejected = await repository.decide(
          RouteModerationDecision(
            requestId: 'request-1',
            approved: false,
            actorId: 'admin-1',
            attemptId: 'reject-2',
            decidedAtUtc: DateTime.utc(2026, 7, 25, 12, 5),
            reasonCode: 'unsafe_crossing',
          ),
        );
        expect(rejected.status, RoutePublishReceiptStatus.denied);
        expect(await repository.routeById('route-1'), isNull);
        expect(await repository.pendingRequests(), isEmpty);
      },
    );

    test('same publication attempt is idempotent', () async {
      final repository = RoutePublicationRepositoryImpl(
        RoutePublicationMemoryDataSource(),
      );
      final bundle = _bundle(
        draft: _draft(),
        routeId: 'route-1',
        versionId: 'version-1',
        attemptId: 'direct-1',
        mode: RoutePublicationMode.trustedDirect,
      );

      final first = await repository.publishDirect(bundle);
      final repeated = await repository.publishDirect(bundle);
      final route = await repository.routeById('route-1');

      expect(repeated.routeId, first.routeId);
      expect(repeated.versionId, first.versionId);
      expect(route?.versions, hasLength(1));
    });

    test('injected pre-commit failure leaves no partial route', () {
      final dataSource = RoutePublicationMemoryDataSource(
        shouldFail: (point) =>
            point == RoutePublicationFaultPoint.beforePublishCommit,
      );
      final bundle = _bundle(
        draft: _draft(),
        routeId: 'route-1',
        versionId: 'version-1',
        attemptId: 'direct-1',
        mode: RoutePublicationMode.trustedDirect,
      );

      expect(
        () => dataSource.publishDirect(bundle),
        throwsA(isA<RoutePublicationInjectedFault>()),
      );
      expect(dataSource.routeById('route-1'), isNull);
    });

    test(
      'standard creator submits; trusted creator publishes directly',
      () async {
        final repository = RoutePublicationRepositoryImpl(
          RoutePublicationMemoryDataSource(),
        );
        final ids = _SequenceIdGenerator();
        final coordinator = RoutePublicationCoordinator(
          idGenerator: ids,
          repository: repository,
          authoringPolicy: const DemoRouteAuthoringPolicy(),
          buildBundle: const BuildRoutePublicationBundleUseCase(),
          buildPolicy: _buildPolicy,
          clock: () => DateTime.utc(2026, 7, 25, 13),
        );

        final submitted = await coordinator.publish(
          actorId: 'creator-1',
          capabilities: const <String>{'create.route', 'submit.route'},
          draft: _draft(),
        );
        final published = await coordinator.publish(
          actorId: 'creator-1',
          capabilities: const <String>{
            'create.route',
            'submit.route',
            'publish.route.direct',
          },
          draft: _draft(title: 'Trusted route'),
        );

        expect(submitted.status, RoutePublishReceiptStatus.submitted);
        expect(published.status, RoutePublishReceiptStatus.published);
      },
    );

    test(
      'revoking direct capability affects the next publication only',
      () async {
        final repository = RoutePublicationRepositoryImpl(
          RoutePublicationMemoryDataSource(),
        );
        final coordinator = RoutePublicationCoordinator(
          idGenerator: _SequenceIdGenerator(),
          repository: repository,
          authoringPolicy: const DemoRouteAuthoringPolicy(),
          buildBundle: const BuildRoutePublicationBundleUseCase(),
          buildPolicy: _buildPolicy,
          clock: () => DateTime.utc(2026, 7, 25, 14),
        );
        final trusted = await coordinator.publish(
          actorId: 'creator-1',
          capabilities: const <String>{
            'create.route',
            'submit.route',
            'publish.route.direct',
          },
          draft: _draft(),
        );
        final revision = await coordinator.createRevision(
          actorId: 'creator-1',
          capabilities: const <String>{'manage.route'},
          versionId: trusted.versionId,
        );

        final submitted = await coordinator.publish(
          actorId: 'creator-1',
          capabilities: const <String>{'create.route', 'submit.route'},
          draft: revision.copyWith(title: 'Review this revision'),
        );

        expect(submitted.status, RoutePublishReceiptStatus.submitted);
        expect(
          (await repository.routeById(trusted.routeId))?.activeVersionId,
          trusted.versionId,
        );
      },
    );

    test(
      'page publishing stays closed until ManagedPage ownership exists',
      () async {
        final coordinator = RoutePublicationCoordinator(
          idGenerator: _SequenceIdGenerator(),
          repository: RoutePublicationRepositoryImpl(
            RoutePublicationMemoryDataSource(),
          ),
          authoringPolicy: const DemoRouteAuthoringPolicy(),
          buildBundle: const BuildRoutePublicationBundleUseCase(),
          buildPolicy: _buildPolicy,
        );

        expect(
          () => coordinator.publish(
            actorId: 'creator-1',
            capabilities: const <String>{
              'create.route',
              'publish.route.direct',
            },
            draft: _draft(),
            publisherType: RoutePublisherType.page,
            publisherId: 'page-1',
          ),
          throwsA(
            isA<RoutePublicationAuthorizationException>().having(
              (error) => error.reasonCode,
              'reasonCode',
              'page_publisher_not_enabled',
            ),
          ),
        );
      },
    );

    test(
      'archive hides the aggregate without deleting immutable versions',
      () async {
        final indexSink = _RecordingRouteIndexSink();
        final repository = RoutePublicationRepositoryImpl(
          RoutePublicationMemoryDataSource(),
          indexSink: indexSink,
        );
        final coordinator = RoutePublicationCoordinator(
          idGenerator: _SequenceIdGenerator(),
          repository: repository,
          authoringPolicy: const DemoRouteAuthoringPolicy(),
          buildBundle: const BuildRoutePublicationBundleUseCase(),
          buildPolicy: _buildPolicy,
          clock: () => DateTime.utc(2026, 7, 25, 15),
        );
        final published = await coordinator.publish(
          actorId: 'creator-1',
          capabilities: const <String>{'create.route', 'publish.route.direct'},
          draft: _draft(),
        );

        final archived = await coordinator.archive(
          actorId: 'creator-1',
          capabilities: const <String>{'archive.route'},
          routeId: published.routeId,
        );

        expect(archived?.lifecycleStatus, RouteLifecycleStatus.archived);
        expect(archived?.versions, hasLength(1));
        expect(archived?.activeVersionId, published.versionId);
        expect(archived?.auditTrail.last.action, 'route_archived');
        expect(indexSink.activated.single.versionId, published.versionId);
        expect(indexSink.archived, <String>[published.routeId]);
      },
    );

    test(
      'critical safety report hides projection and admin restore keeps history',
      () async {
        final indexSink = _RecordingRouteIndexSink();
        final publication = RoutePublicationRepositoryImpl(
          RoutePublicationMemoryDataSource(),
          indexSink: indexSink,
        );
        final workflow = RouteQualityWorkflowCoordinator(
          idGenerator: _SequenceIdGenerator(),
          workflowRepository: RouteQualityWorkflowRepositoryImpl(
            RouteQualityWorkflowMemoryDataSource(),
          ),
          publicationRepository: publication,
          authoringPolicy: const DemoRouteAuthoringPolicy(),
          clock: () => DateTime.utc(2026, 7, 25, 16),
        );
        await publication.publishDirect(
          _bundle(
            draft: _draft(),
            routeId: 'route-1',
            versionId: 'version-1',
            attemptId: 'publish-1',
            mode: RoutePublicationMode.trustedDirect,
          ),
        );

        final report = await workflow.submitSafetyReport(
          routeId: 'route-1',
          reporterId: 'user-2',
          reasonCode: 'trail_closed',
          severity: RouteSafetySeverity.critical,
        );

        final suspended = await publication.routeById('route-1');
        expect(suspended?.lifecycleStatus, RouteLifecycleStatus.suspended);
        expect(suspended?.versions, hasLength(1));
        expect(indexSink.archived, <String>['route-1']);

        await workflow.decideSafetyReport(
          reportId: report.id,
          state: RouteSafetyReportState.resolved,
          actorId: 'admin-1',
          capabilities: const <String>{'moderate.route'},
          reasonCode: 'field_check_complete',
          restoreRoute: true,
        );

        final restored = await publication.routeById('route-1');
        expect(restored?.lifecycleStatus, RouteLifecycleStatus.active);
        expect(restored?.versions, hasLength(1));
        expect(indexSink.activated, hasLength(2));
        expect(restored?.auditTrail.last.action, 'route_safety_restored');
      },
    );

    test(
      'accepted map candidate creates a revision draft without live mutation',
      () async {
        final publication = RoutePublicationRepositoryImpl(
          RoutePublicationMemoryDataSource(),
        );
        final workflow = RouteQualityWorkflowCoordinator(
          idGenerator: _SequenceIdGenerator(),
          workflowRepository: RouteQualityWorkflowRepositoryImpl(
            RouteQualityWorkflowMemoryDataSource(),
          ),
          publicationRepository: publication,
          authoringPolicy: const DemoRouteAuthoringPolicy(),
          clock: () => DateTime.utc(2026, 7, 25, 17),
        );
        await publication.publishDirect(
          _bundle(
            draft: _draft(),
            routeId: 'route-1',
            versionId: 'version-1',
            attemptId: 'publish-1',
            mode: RoutePublicationMode.trustedDirect,
          ),
        );
        final candidateRoute = _draft().routeData!.copyWith(
          conditions: RouteConditionsDraft(
            difficultyId: 'moderate.v1',
            surfaceIds: const <String>['mixed'],
          ),
        );

        final candidate = await workflow.createCandidate(
          actorId: 'creator-1',
          capabilities: const <String>{'manage.route'},
          routeId: 'route-1',
          baseVersionId: 'version-1',
          sourceSnapshotId: 'osm-2026-07-25',
          sourceAttribution: 'OpenStreetMap contributors',
          candidateDraft: candidateRoute,
        );
        expect(
          (await publication.routeById('route-1'))?.activeVersionId,
          'version-1',
        );

        final decision = await workflow.decideCandidate(
          candidateId: candidate.id,
          decision: RouteCandidateDecision.accepted,
          actorId: 'creator-1',
          capabilities: const <String>{'manage.route'},
        );

        expect(decision.revisionDraft, isNotNull);
        expect(
          decision.revisionDraft?.basedOnPublishedVersionId,
          'version-1',
        );
        expect(decision.revisionDraft?.publishStatus, PublishStatus.draft);
        expect(
          (await publication.routeById('route-1'))?.activeVersionId,
          'version-1',
        );
      },
    );

    test('field verification requires manage capability and is audited', () async {
      final publication = RoutePublicationRepositoryImpl(
        RoutePublicationMemoryDataSource(),
      );
      final workflow = RouteQualityWorkflowCoordinator(
        idGenerator: _SequenceIdGenerator(),
        workflowRepository: RouteQualityWorkflowRepositoryImpl(
          RouteQualityWorkflowMemoryDataSource(),
        ),
        publicationRepository: publication,
        authoringPolicy: const DemoRouteAuthoringPolicy(),
        clock: () => DateTime.utc(2026, 7, 25, 18),
      );

      final verified = await workflow.verifyDraft(
        draft: _draft(),
        actorId: 'creator-1',
        capabilities: const <String>{'manage.route'},
        kind: RouteVerificationKind.field,
        evidenceMediaIds: const <String>['media-1'],
        note: 'Walked the complete track.',
      );

      final record = verified.routeData!.quality!.verifications.single;
      expect(record.kind, RouteVerificationKind.field);
      expect(record.actorId, 'creator-1');
      expect(record.geometryRevision, verified.routeData!.geometryRevision);
      expect(record.evidenceMediaIds, <String>['media-1']);
    });

    test('rollback publishes a new immutable version', () async {
      final repository = RoutePublicationRepositoryImpl(
        RoutePublicationMemoryDataSource(),
      );
      final first = _bundle(
        draft: _draft(title: 'Original Route'),
        routeId: 'route-1',
        versionId: 'version-1',
        attemptId: 'publish-1',
        mode: RoutePublicationMode.trustedDirect,
      );
      await repository.publishDirect(first);
      final second = _bundle(
        draft: _draft(title: 'Changed Route'),
        routeId: 'route-1',
        versionId: 'version-2',
        attemptId: 'publish-2',
        current: await repository.routeById('route-1'),
        mode: RoutePublicationMode.trustedDirect,
      );
      await repository.publishDirect(second);
      final coordinator = RoutePublicationCoordinator(
        idGenerator: _SequenceIdGenerator(),
        repository: repository,
        authoringPolicy: const DemoRouteAuthoringPolicy(),
        buildBundle: const BuildRoutePublicationBundleUseCase(),
        buildPolicy: _buildPolicy,
        clock: () => DateTime.utc(2026, 7, 25, 19),
      );

      final receipt = await coordinator.rollback(
        actorId: 'creator-1',
        capabilities: const <String>{
          'manage.route',
          'publish.route.direct',
        },
        routeId: 'route-1',
        targetVersionId: 'version-1',
      );
      final aggregate = await repository.routeById('route-1');

      expect(receipt.isPublished, isTrue);
      expect(aggregate?.versions, hasLength(3));
      expect(aggregate?.activeVersionId, isNot('version-1'));
      expect(aggregate?.activeVersion?.rollbackSourceVersionId, 'version-1');
      expect(aggregate?.activeVersion?.versionNumber, 3);
      expect(
        aggregate?.auditTrail.last.action,
        'route_rollback_published',
      );
    });
  });
}

final RoutePublicationBuildPolicy _buildPolicy = RoutePublicationBuildPolicy(
  validationPolicy: routeValidationPolicy(),
  locallyAllowedProviderCodes: const <String>{},
);

CreateDraftEntity _draft({String title = 'Forest route'}) =>
    CreateDraftEntity.defaults(
      organizerId: 'creator-1',
      organizerEmail: 'creator@example.com',
      organizerName: 'Creator',
      marketCityId: 'riga',
      timezone: 'Europe/Riga',
      country: 'LV',
      city: 'Riga',
      currency: 'EUR',
    ).copyWith(
      objectType: CreateObjectType.route,
      title: title,
      shortDescription: 'A verified continuous walking track.',
      mainCategory: 'outdoor_nature',
      subcategory: 'walking_route',
      city: 'Riga',
      media: const MediaEntity(
        coverImage: 'asset://route-cover.jpg',
        gallery: <String>[],
      ),
      routeData: routeFixture(),
      clearEventData: true,
    );

RoutePublicationBundle _bundle({
  required CreateDraftEntity draft,
  required String routeId,
  required String versionId,
  required String attemptId,
  RoutePublicationAggregate? current,
  RoutePublicationMode mode = RoutePublicationMode.reviewed,
}) => const BuildRoutePublicationBundleUseCase()(
  draft: draft,
  current: current,
  publisher: const RoutePublisherRef(
    type: RoutePublisherType.user,
    id: 'creator-1',
  ),
  mode: mode,
  policy: _buildPolicy,
  routeId: routeId,
  versionId: versionId,
  auditEventId: 'audit-$attemptId',
  attemptId: attemptId,
  actorId: 'creator-1',
  nowUtc: DateTime.utc(2026, 7, 25, 9),
  generateId: _unusedId,
);

String _unusedId() => '01GENERATED000000000000000';

class _SequenceIdGenerator implements IdGenerator {
  int _value = 0;

  @override
  String generate() {
    _value += 1;
    return 'id-${_value.toString().padLeft(4, '0')}';
  }
}

class _RecordingRouteIndexSink implements RoutePublicationIndexSink {
  final List<PublishedRouteVersion> activated = <PublishedRouteVersion>[];
  final List<String> archived = <String>[];

  @override
  Future<void> activate(PublishedRouteVersion version) async {
    activated.add(version);
  }

  @override
  Future<void> archive(String routeId) async {
    archived.add(routeId);
  }
}
