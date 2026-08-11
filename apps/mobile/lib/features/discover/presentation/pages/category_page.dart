import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/config/recharge_taxonomy.dart';
import '../../application/controllers/discover_feed_controller.dart';
import '../../application/discover_providers.dart';
import '../../domain/entities/discover_query.dart';
import '../widgets/discover_category_icon.dart';
import '../widgets/discover_feed_section.dart';

class CategoryPage extends ConsumerStatefulWidget {
  const CategoryPage({super.key, required this.categoryId});

  final String categoryId;

  @override
  ConsumerState<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends ConsumerState<CategoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RechargeContentGroup? group = rechargeContentGroupById(
        widget.categoryId,
      );
      if (group == null) return;
      ref
          .read(discoverFeedControllerProvider)
          .applySearchConditions(
            selectedCategoryIds: <String>[group.id],
            selectedSubcategoryIds: const <String>[],
            sourceScreen: 'category',
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final RechargeContentGroup? group = rechargeContentGroupById(
      widget.categoryId,
    );
    if (group == null || group.isHidden) {
      return Scaffold(
        appBar: AppBar(title: const Text('Categories')),
        body: const Center(child: Text('Category not found')),
      );
    }

    final DiscoverFeedController controller = ref.watch(
      discoverFeedControllerProvider,
    );
    final DiscoverQuery query = controller.state.appliedQuery;
    final String? selectedSubcategoryId = query.selectedSubcategoryIds.isEmpty
        ? null
        : query.selectedSubcategoryIds.first;
    final List<RechargeActivityCategory> subcategories = group.categorySlugs
        .map(
          (String slug) => rechargeActivityCategoryByPath(
            contentGroupId: group.id,
            categorySlug: slug,
          ),
        )
        .whereType<RechargeActivityCategory>()
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(group.title),
        actions: <Widget>[
          IconButton(
            tooltip: 'Map ${group.title}',
            onPressed: () => context.push(RouteNames.discoverMap),
            icon: const Icon(Icons.map_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: <Widget>[
          _CategoryHeading(group: group),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Text(
                'Subcategories',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '${controller.state.resultCount} found',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: ListView.separated(
              key: const Key('subcategory-rail'),
              scrollDirection: Axis.horizontal,
              itemCount: subcategories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return _SubcategoryTile(
                    key: const Key('subcategory-all'),
                    label: 'All',
                    icon: Icons.grid_view_rounded,
                    selected: selectedSubcategoryId == null,
                    onTap: () => _selectSubcategory(controller, group.id, null),
                  );
                }
                final RechargeActivityCategory subcategory =
                    subcategories[index - 1];
                return _SubcategoryTile(
                  key: Key('subcategory-${subcategory.slug}'),
                  label: subcategory.title,
                  icon: discoverCategoryIcon(group.id),
                  selected: selectedSubcategoryId == subcategory.slug,
                  onTap: () => _selectSubcategory(
                    controller,
                    group.id,
                    subcategory.slug,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          DiscoverFeedSection(
            onOpenDetails: (String itemId) =>
                context.push('${RouteNames.discoverDetails}/$itemId'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectSubcategory(
    DiscoverFeedController controller,
    String categoryId,
    String? subcategoryId,
  ) {
    return controller.applySearchConditions(
      selectedCategoryIds: <String>[categoryId],
      selectedSubcategoryIds: subcategoryId == null
          ? const <String>[]
          : <String>[subcategoryId],
      sourceScreen: 'category',
    );
  }
}

class _CategoryHeading extends StatelessWidget {
  const _CategoryHeading({required this.group});

  final RechargeContentGroup group;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            discoverCategoryIcon(group.id),
            color: colors.primary,
            size: 32,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                group.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                group.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubcategoryTile extends StatelessWidget {
  const _SubcategoryTile({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: SizedBox(
        width: 82,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: selected ? colors.primary : colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? colors.primary : colors.outlineVariant,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? colors.onPrimary : colors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? colors.primary : colors.onSurface,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
