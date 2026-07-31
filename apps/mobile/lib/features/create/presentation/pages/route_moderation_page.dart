import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/create_providers.dart';
import '../../domain/entities/route_publication_data.dart';
import '../../domain/entities/route_quality_workflow_data.dart';

class RouteModerationPage extends ConsumerStatefulWidget {
  const RouteModerationPage({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.capabilities,
  });

  final String userId;
  final String userEmail;
  final List<String> capabilities;

  @override
  ConsumerState<RouteModerationPage> createState() =>
      _RouteModerationPageState();
}

class _RouteModerationPageState extends ConsumerState<RouteModerationPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final controller = ref.read(createControllerProvider);
    if (widget.userId.isNotEmpty) {
      await controller.ensureLoaded(
        userId: widget.userId,
        organizerEmail: widget.userEmail,
        organizerName: widget.userEmail.split('@').first,
        capabilities: widget.capabilities,
      );
      await controller.loadRouteModerationQueue();
      await ref.read(routeQualityAdminControllerProvider).load();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(createControllerProvider);
    final qualityController = ref.watch(
      routeQualityAdminControllerProvider,
    );
    final requests = controller.state.routeModerationRequests;
    final canManageQuality = widget.capabilities.contains('manage.route');
    final canModerateSafety = widget.capabilities.contains('moderate.route');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route moderation'),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading || qualityController.loading
          ? const Center(child: CircularProgressIndicator())
          : !controller.canModerateRoute &&
                !canManageQuality &&
                !canModerateSafety
          ? const _AccessDenied()
          : requests.isEmpty &&
                qualityController.candidates.isEmpty &&
                qualityController.reports.isEmpty
          ? const _EmptyQueue()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (qualityController.errorCode case final error?)
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (controller.canModerateRoute) ...<Widget>[
                  const _QueueHeading('Publication review'),
                  for (final request in requests) ...<Widget>[
                    _RequestCard(
                      request: request,
                      onApprove: () => _decide(request, approved: true),
                      onReject: () => _reject(request),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                if (canManageQuality) ...<Widget>[
                  const _QueueHeading('Map update candidates'),
                  for (final candidate
                      in qualityController.candidates) ...<Widget>[
                    _CandidateCard(
                      candidate: candidate,
                      onAccept: () => _decideCandidate(
                        candidate,
                        RouteCandidateDecision.accepted,
                      ),
                      onReject: () => _decideCandidate(
                        candidate,
                        RouteCandidateDecision.rejected,
                      ),
                      onDefer: () => _decideCandidate(
                        candidate,
                        RouteCandidateDecision.deferred,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                if (canModerateSafety) ...<Widget>[
                  const _QueueHeading('Safety reports'),
                  for (final report in qualityController.reports) ...<Widget>[
                    _SafetyReportCard(
                      report: report,
                      onDismiss: () => _decideSafety(
                        report,
                        RouteSafetyReportState.dismissed,
                      ),
                      onResolve: () => _decideSafety(
                        report,
                        RouteSafetyReportState.resolved,
                        restore: report.severity ==
                            RouteSafetySeverity.critical,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                if (qualityController.lastCreatedRevision != null)
                  const Text(
                    'A new Route revision draft was created. Published '
                    'geometry was not changed.',
                  ),
              ],
            ),
    );
  }

  Future<void> _decide(
    RouteModerationRequest request, {
    required bool approved,
    String? reasonCode,
  }) async {
    setState(() => _loading = true);
    await ref
        .read(createControllerProvider)
        .moderateRouteRequest(
          requestId: request.id,
          approved: approved,
          reasonCode: reasonCode,
        );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reject(RouteModerationRequest request) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _RejectDialog(),
    );
    if (reason == null || reason.trim().isEmpty) return;
    await _decide(request, approved: false, reasonCode: reason.trim());
  }

  Future<void> _decideCandidate(
    RouteMapSnapshotCandidate candidate,
    RouteCandidateDecision decision,
  ) async {
    String? reason;
    if (decision != RouteCandidateDecision.accepted) {
      reason = await _reason('Candidate decision reason');
      if (reason == null) return;
    }
    await ref.read(routeQualityAdminControllerProvider).decideCandidate(
      candidateId: candidate.id,
      decision: decision,
      actorId: widget.userId,
      capabilities: widget.capabilities.toSet(),
      reasonCode: reason,
    );
  }

  Future<void> _decideSafety(
    RouteSafetyReport report,
    RouteSafetyReportState state, {
    bool restore = false,
  }) async {
    final reason = await _reason('Safety decision reason');
    if (reason == null) return;
    await ref.read(routeQualityAdminControllerProvider).decideSafety(
      reportId: report.id,
      state: state,
      actorId: widget.userId,
      capabilities: widget.capabilities.toSet(),
      reasonCode: reason,
      restoreRoute: restore,
    );
  }

  Future<String?> _reason(String title) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Reason code'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value == null || value.isEmpty ? null : value;
  }
}

class _QueueHeading extends StatelessWidget {
  const _QueueHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
    ),
  );
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.onAccept,
    required this.onReject,
    required this.onDefer,
  });

  final RouteMapSnapshotCandidate candidate;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onDefer;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Route ${candidate.routeId}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(
            '${candidate.diff.distanceDeltaMeters.toStringAsFixed(0)} m · '
            '${candidate.diff.candidatePointCount} points · '
            '${candidate.sourceSnapshotId}',
          ),
          Text(candidate.sourceAttribution),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: <Widget>[
              TextButton(onPressed: onDefer, child: const Text('Defer')),
              OutlinedButton(onPressed: onReject, child: const Text('Reject')),
              FilledButton(onPressed: onAccept, child: const Text('Accept')),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SafetyReportCard extends StatelessWidget {
  const _SafetyReportCard({
    required this.report,
    required this.onDismiss,
    required this.onResolve,
  });

  final RouteSafetyReport report;
  final VoidCallback onDismiss;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '${report.severity.name.toUpperCase()} · ${report.reasonCode}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text('Route ${report.routeId} · version ${report.versionId}'),
          if (report.safeNote != null) Text(report.safeNote!),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss,
                  child: const Text('Dismiss'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onResolve,
                  child: Text(
                    report.severity == RouteSafetySeverity.critical
                        ? 'Resolve & restore'
                        : 'Resolve',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final RouteModerationRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final version = request.bundle.version;
    final route = version.contentSnapshot.routeData;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              version.contentSnapshot.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '${((route?.metrics.distanceMeters ?? 0) / 1000).toStringAsFixed(2)} km · '
              'version ${version.versionNumber}',
            ),
            const SizedBox(height: 6),
            Text(
              'Route ${version.routeId}\n'
              'Geometry ${version.geometryHash}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reject Route version'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'Reason code or concise reason',
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Reject'),
      ),
    ],
  );
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('The moderate.route capability is required.'),
    ),
  );
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('No Route versions are waiting for review.'),
    ),
  );
}
