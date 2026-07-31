import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/config/recharge_taxonomy.dart';
import '../../application/discover_providers.dart';
import '../widgets/discover_category_icon.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  final TextEditingController _searchController = TextEditingController();
  late final Future<Map<String, int>> _countsFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _countsFuture = ref
        .read(discoverFeedControllerProvider)
        .loadCategoryResultCounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<RechargeContentGroup> groups = rechargeVisibleContentGroups
        .where(_matchesQuery)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              key: const Key('categories-search-field'),
              controller: _searchController,
              onChanged: (String value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search categories',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('categories-search-clear'),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, int>>(
              future: _countsFuture,
              builder: (BuildContext context, snapshot) {
                if (groups.isEmpty) return const _EmptyCategorySearch();
                return ListView.separated(
                  key: const Key('categories-list'),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final RechargeContentGroup group = groups[index];
                    return _CategoryRow(
                      group: group,
                      count: snapshot.hasData
                          ? snapshot.data![group.id] ?? 0
                          : null,
                      onTap: () =>
                          context.push('${RouteNames.categories}/${group.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesQuery(RechargeContentGroup group) {
    final String normalized = _query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return group.title.toLowerCase().contains(normalized) ||
        group.id.replaceAll('_', ' ').contains(normalized);
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.group,
    required this.count,
    required this.onTap,
  });

  final RechargeContentGroup group;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: count == null ? group.title : '${group.title}, $count results',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('category-row-${group.id}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: <Widget>[
                  Container(
                    key: Key('category-icon-${group.id}'),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      discoverCategoryIcon(group.id),
                      size: 20,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      group.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 34,
                    child: Text(
                      count == null ? '—' : '$count',
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCategorySearch extends StatelessWidget {
  const _EmptyCategorySearch();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('No categories found'),
    ),
  );
}
