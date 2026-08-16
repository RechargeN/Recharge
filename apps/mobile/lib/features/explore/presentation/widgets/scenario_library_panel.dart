import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/application/planning_navigation_intent.dart';
import '../../../../app/application/planning_navigation_resolver.dart';
import '../../../../app/application/scenario_library_facade.dart';

class ScenarioLibraryPanel extends StatefulWidget {
  const ScenarioLibraryPanel({super.key, required this.userId});

  final String userId;

  @override
  State<ScenarioLibraryPanel> createState() => _ScenarioLibraryPanelState();
}

class _ScenarioLibraryPanelState extends State<ScenarioLibraryPanel> {
  final _resolver = const PlanningNavigationResolver();
  late Future<List<ScenarioLibraryItem>> _drafts = _load();

  Future<List<ScenarioLibraryItem>> _load() {
    final facade = scenarioLibraryFacadeOrNull();
    if (facade == null) {
      return Future<List<ScenarioLibraryItem>>.value(
        const <ScenarioLibraryItem>[],
      );
    }
    return facade.list(ownerId: widget.userId, nowUtc: DateTime.now().toUtc());
  }

  Future<void> _setUpdates(ScenarioLibraryItem summary, bool enabled) async {
    final facade = scenarioLibraryFacadeOrNull();
    if (facade == null) return;
    final saved = await facade.setUpdatesEnabled(
      ownerId: widget.userId,
      scenarioDraftId: summary.id,
      enabled: enabled,
    );
    if (!mounted) return;
    if (saved) {
      setState(() => _drafts = _load());
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<ScenarioLibraryItem>>(
        future: _drafts,
        builder: (context, snapshot) {
          final drafts = snapshot.data ?? const <ScenarioLibraryItem>[];
          if (drafts.isEmpty) return const SizedBox.shrink();
          final active = drafts.where((draft) => !draft.completed);
          final completed = drafts.where((draft) => draft.completed);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Scenarios',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (active.isNotEmpty) ...<Widget>[
                    const Text('Active and upcoming'),
                    ...active.map((draft) => _tile(context, draft)),
                  ],
                  if (completed.isNotEmpty) ...<Widget>[
                    const Divider(),
                    const Text('Completed'),
                    ...completed.map((draft) => _tile(context, draft)),
                  ],
                ],
              ),
            ),
          );
        },
      );

  Widget _tile(BuildContext context, ScenarioLibraryItem draft) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: draft.updatesEnabled,
        onChanged: (value) => _setUpdates(draft, value),
        title: InkWell(
          onTap: () => context.push(
            _resolver.resolve(PlanningNavigationIntent.openScenario(draft.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(draft.title.trim().isEmpty ? 'Untitled' : draft.title),
          ),
        ),
        subtitle: Text(
          draft.updatesEnabled ? 'Object updates on' : 'Object updates off',
        ),
      );
}
