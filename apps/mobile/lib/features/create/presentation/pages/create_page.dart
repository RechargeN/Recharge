import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/config/recharge_category_criteria.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/controllers/create_controller.dart';
import '../../application/create_providers.dart';
import '../../application/create_taxonomy.dart';
import '../../application/get_category_criteria_usecase.dart';
import '../../application/state/create_state.dart';
import '../../domain/entities/create_draft_entity.dart';

class CreatePage extends ConsumerStatefulWidget {
  const CreatePage({super.key, this.seedParameters = const <String, String>{}});

  final Map<String, String> seedParameters;

  @override
  ConsumerState<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends ConsumerState<CreatePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _subcategoryController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _shortDescriptionController =
      TextEditingController();
  final TextEditingController _fullDescriptionController =
      TextEditingController();
  final TextEditingController _coverController = TextEditingController();
  final TextEditingController _galleryInputController = TextEditingController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String? _loadKey;
  String? _appliedSeedKey;

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _subcategoryController.dispose();
    _cityController.dispose();
    _venueController.dispose();
    _addressController.dispose();
    _shortDescriptionController.dispose();
    _fullDescriptionController.dispose();
    _coverController.dispose();
    _galleryInputController.dispose();
    _startController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider).state;
    final user = authState.user;
    final CreateController controller = ref.watch(createControllerProvider);
    final CreateState state = controller.state;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Требуется авторизация')));
    }

    _scheduleLoad(
      userId: user.id,
      organizerEmail: user.email,
      organizerName: user.email.split('@').first,
    );
    _syncControllers(state);
    _scheduleSeedApply(controller, state);
    final _CreateReadiness readiness = _createReadinessFor(state.draft);
    final CreateBlockConfig blockConfig = createBlockConfigFor(
      state.draft.objectType,
    );
    final _CreateSeedContext? seedContext = _CreateSeedContext.fromParameters(
      widget.seedParameters,
    );
    final _ScenarioRouteSeedContext? scenarioSeedContext =
        _ScenarioRouteSeedContext.fromParameters(widget.seedParameters);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Hub')),
      body: switch (state.status) {
        CreateStatus.initial || CreateStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        CreateStatus.error => _CreateStateMessage(
          text: state.message ?? 'Ошибка create flow',
        ),
        CreateStatus.ready ||
        CreateStatus.saving ||
        CreateStatus.publishing ||
        CreateStatus.publishSuccess => ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _CreateHubHeader(draft: state.draft),
            if (_needsRentalReview(state.draft)) ...<Widget>[
              const SizedBox(height: 12),
              _RentalReviewBanner(
                onKeepSession: () =>
                    controller.resolveRentalReview(convertToRental: false),
                onConvertToRental: () =>
                    controller.resolveRentalReview(convertToRental: true),
              ),
            ],
            if (seedContext != null) ...<Widget>[
              const SizedBox(height: 12),
              _CreateSeedBanner(seedContext: seedContext),
            ],
            if (scenarioSeedContext != null) ...<Widget>[
              const SizedBox(height: 12),
              _ScenarioRouteSeedPanel(
                seedContext: scenarioSeedContext,
                onEditRoute: () =>
                    context.go(scenarioSeedContext.builderLocation),
                onMapRoute: () => context.go(scenarioSeedContext.mapLocation),
              ),
            ],
            const SizedBox(height: 16),
            _CreateWorkspace(
              draft: state.draft,
              readiness: readiness,
              onObjectTypeSelected: controller.setObjectType,
              onPresetSelected: (_CreatePreset preset) {
                _applyPreset(controller, preset);
              },
            ),
            const SizedBox(height: 12),
            _CreateTaxonomyPicker(
              objectType: state.draft.objectType,
              selectedCategoryId: state.draft.mainCategory,
              selectedSubcategoryId: state.draft.subcategory,
              onCategorySelected: (CreateTaxonomyCategory category) {
                final CreateTaxonomySubcategory? defaultSubcategory =
                    createDefaultSubcategoryFor(category);
                controller.applyTaxonomySelection(
                  mainCategory: category.id,
                  subcategory: defaultSubcategory?.id ?? '',
                );
              },
              onSubcategorySelected:
                  (
                    CreateTaxonomyCategory category,
                    CreateTaxonomySubcategory subcategory,
                  ) {
                    controller.applyTaxonomySelection(
                      mainCategory: category.id,
                      subcategory: subcategory.id,
                    );
                  },
            ),
            if (state.draft.subcategory.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              _DynamicCriteriaSection(
                draft: state.draft,
                onChanged: controller.updateCategoryCriterion,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Details',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _LabeledField(
              label: 'Title *',
              controller: _titleController,
              errorText: state.validationErrors['title'],
              onChanged: controller.updateTitle,
            ),
            _LabeledField(
              label: 'Main category *',
              controller: _categoryController,
              errorText: state.validationErrors['mainCategory'],
              onChanged: controller.updateMainCategory,
            ),
            _LabeledField(
              label: 'Subcategory',
              controller: _subcategoryController,
              onChanged: controller.updateSubcategory,
            ),
            _LabeledField(
              label: 'City *',
              controller: _cityController,
              errorText: state.validationErrors['city'],
              onChanged: controller.updateCity,
            ),
            _LabeledField(
              label: blockConfig.locationLabel,
              controller: _venueController,
              onChanged: controller.updateVenueName,
            ),
            _LabeledField(
              label: 'Address',
              controller: _addressController,
              onChanged: controller.updateAddress,
            ),
            _LabeledField(
              label: 'Short description',
              controller: _shortDescriptionController,
              onChanged: controller.updateShortDescription,
            ),
            _LabeledField(
              label: 'Full description',
              controller: _fullDescriptionController,
              maxLines: 4,
              onChanged: controller.updateFullDescription,
            ),
            _LabeledField(
              label: 'Cover image *',
              controller: _coverController,
              errorText: state.validationErrors['coverImage'],
              onChanged: controller.updateCoverImage,
            ),
            if (blockConfig.requiresStartDateTime)
              _LabeledField(
                label:
                    '${blockConfig.title} start datetime UTC (YYYY-MM-DDTHH:mm:ssZ) *',
                controller: _startController,
                errorText: state.validationErrors['startDateTimeUtc'],
                onChanged: controller.updateStartDateTime,
              ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _galleryInputController,
                    decoration: const InputDecoration(
                      labelText: 'Gallery image URL/path',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    controller.addGalleryImage(_galleryInputController.text);
                    _galleryInputController.clear();
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
            if (state.draft.media.gallery.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List<Widget>.generate(
                  state.draft.media.gallery.length,
                  (int index) => InputChip(
                    label: Text(state.draft.media.gallery[index]),
                    onDeleted: () => controller.removeGalleryImageAt(index),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              value: state.draft.isFree,
              onChanged: controller.updateIsFree,
              title: Text('Free ${blockConfig.title.toLowerCase()}'),
            ),
            if (!state.draft.isFree)
              _LabeledField(
                label: blockConfig.priceLabel,
                controller: _priceController,
                onChanged: controller.updateBasePrice,
              ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        state.status == CreateStatus.saving ||
                            state.status == CreateStatus.publishing
                        ? null
                        : controller.saveDraft,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save draft'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        state.status == CreateStatus.saving ||
                            state.status == CreateStatus.publishing
                        ? null
                        : () async {
                            final bool success = await controller
                                .publishDraft();
                            if (!success) return;
                            ref
                                .read(appRouterProvider)
                                .go(RouteNames.createSuccess);
                          },
                    icon: const Icon(Icons.publish_outlined),
                    label: Text(
                      state.status == CreateStatus.publishing
                          ? 'Publishing...'
                          : 'Publish',
                    ),
                  ),
                ),
              ],
            ),
            if (state.message != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                state.message!,
                style: TextStyle(
                  color: state.validationErrors.isNotEmpty
                      ? Colors.red
                      : Colors.green,
                ),
              ),
            ],
          ],
        ),
      },
    );
  }

  void _scheduleLoad({
    required String userId,
    required String organizerEmail,
    required String organizerName,
  }) {
    final String key = '$userId:$organizerEmail';
    if (_loadKey == key) return;
    _loadKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(createControllerProvider)
          .ensureLoaded(
            userId: userId,
            organizerEmail: organizerEmail,
            organizerName: organizerName,
          );
    });
  }

  void _syncControllers(CreateState state) {
    if (!state.isLoaded) return;
    _syncController(_titleController, state.draft.title);
    _syncController(_categoryController, state.draft.mainCategory);
    _syncController(_subcategoryController, state.draft.subcategory);
    _syncController(_cityController, state.draft.city);
    _syncController(_venueController, state.draft.venueName);
    _syncController(_addressController, state.draft.addressLine1);
    _syncController(_shortDescriptionController, state.draft.shortDescription);
    _syncController(_fullDescriptionController, state.draft.fullDescription);
    _syncController(_coverController, state.draft.media.coverImage);
    _syncController(
      _startController,
      state.draft.startDateTimeUtc?.toIso8601String() ?? '',
    );
    _syncController(_priceController, state.draft.basePrice?.toString() ?? '');
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  void _scheduleSeedApply(CreateController controller, CreateState state) {
    if (!state.isLoaded || widget.seedParameters.isEmpty) return;
    final String seedKey = _seedKeyFor(widget.seedParameters);
    if (_appliedSeedKey == seedKey) return;
    final _CreateSeed seed = _CreateSeed.fromParameters(widget.seedParameters);
    if (!seed.hasValues) return;
    _appliedSeedKey = seedKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applySeed(controller, seed);
    });
  }

  void _applySeed(CreateController controller, _CreateSeed seed) {
    controller.setObjectType(seed.objectType);
    controller.applyTaxonomySelection(
      mainCategory: seed.categoryId,
      subcategory: seed.subcategoryId,
    );
    controller.updateTitle(seed.title);
    controller.updateShortDescription(seed.shortDescription);
    controller.updateFullDescription(seed.fullDescription);
    controller.updateCity(seed.city);
    controller.updateVenueName(seed.venueName);
    controller.updateAddress(seed.addressLine1);
    controller.updateCoverImage(seed.coverImage);
    controller.updateIsFree(seed.isFree);
    if (!seed.isFree && seed.basePrice != null) {
      controller.updateBasePrice(seed.basePrice!.toStringAsFixed(0));
    }
    if (createBlockConfigFor(seed.objectType).requiresStartDateTime) {
      controller.updateStartDateTime(seed.startDateTimeUtc.toIso8601String());
    } else {
      controller.updateStartDateTime('');
    }
  }

  void _applyPreset(CreateController controller, _CreatePreset preset) {
    controller.setObjectType(preset.objectType);
    controller.applyTaxonomySelection(
      mainCategory: preset.categoryId,
      subcategory: preset.subcategoryId,
    );
    controller.updateTitle(preset.title);
    controller.updateShortDescription(preset.shortDescription);
    controller.updateFullDescription(preset.fullDescription);
    controller.updateCity(preset.city);
    controller.updateVenueName(preset.venueName);
    controller.updateAddress(preset.addressLine1);
    controller.updateCoverImage(preset.coverImage);
    controller.updateIsFree(preset.isFree);
    if (!preset.isFree && preset.basePrice != null) {
      controller.updateBasePrice(preset.basePrice!.toStringAsFixed(0));
    }
    if (createBlockConfigFor(preset.objectType).requiresStartDateTime) {
      controller.updateStartDateTime(
        DateTime.now().toUtc().add(const Duration(days: 3)).toIso8601String(),
      );
    } else {
      controller.updateStartDateTime('');
    }
  }
}

class _CreateHubHeader extends StatelessWidget {
  const _CreateHubHeader({required this.draft});

  final CreateDraftEntity draft;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final CreateBlockConfig config = createBlockConfigFor(draft.objectType);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.auto_awesome, color: colorScheme.onPrimary),
                const SizedBox(width: 8),
                Text(
                  'Recharge Create',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              draft.title.trim().isEmpty
                  ? 'New ${config.title.toLowerCase()}'
                  : draft.title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _HeaderChip(icon: Icons.layers, label: config.title),
                if (draft.mainCategory.isNotEmpty)
                  _HeaderChip(
                    icon: Icons.category,
                    label: createTaxonomyLabelForPath(draft.mainCategory),
                  ),
                if (draft.subcategory.isNotEmpty)
                  _HeaderChip(
                    icon: Icons.sell,
                    label: createTaxonomyLabelForPath(
                      '${draft.mainCategory}.${draft.subcategory}',
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

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: colorScheme.onPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateWorkspace extends StatelessWidget {
  const _CreateWorkspace({
    required this.draft,
    required this.readiness,
    required this.onObjectTypeSelected,
    required this.onPresetSelected,
  });

  final CreateDraftEntity draft;
  final _CreateReadiness readiness;
  final ValueChanged<CreateObjectType> onObjectTypeSelected;
  final ValueChanged<_CreatePreset> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Create type',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.15,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          children: rechargeCreateBlockConfigs
              .map(
                (CreateBlockConfig config) => _CreateTypeCard(
                  title: config.title,
                  subtitle: config.description,
                  icon: _iconForCreateBlock(config.objectType),
                  selected: draft.objectType == config.objectType,
                  onTap: () => onObjectTypeSelected(config.objectType),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 14),
        _CreatePresetRail(onPresetSelected: onPresetSelected),
        const SizedBox(height: 14),
        _CreateReadinessPanel(readiness: readiness),
        const SizedBox(height: 14),
        _CreatePreviewCard(draft: draft, readiness: readiness),
      ],
    );
  }
}

class _CreateTypeCard extends StatelessWidget {
  const _CreateTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primaryContainer : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: colorScheme.primary),
                const Spacer(),
                if (selected)
                  Icon(Icons.check_circle, color: colorScheme.primary),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePresetRail extends StatelessWidget {
  const _CreatePresetRail({required this.onPresetSelected});

  final ValueChanged<_CreatePreset> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Fast presets',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _createPresets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int index) {
              final _CreatePreset preset = _createPresets[index];
              return _CreatePresetCard(
                preset: preset,
                onTap: () => onPresetSelected(preset),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CreatePresetCard extends StatelessWidget {
  const _CreatePresetCard({required this.preset, required this.onTap});

  final _CreatePreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 210,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(_iconForCategory(preset.categoryId)),
                  const Spacer(),
                  Flexible(
                    child: _CreatePill(
                      label: createBlockConfigFor(preset.objectType).title,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                preset.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                preset.pathLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateReadinessPanel extends StatelessWidget {
  const _CreateReadinessPanel({required this.readiness});

  final _CreateReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: readiness.requiredReady
            ? colorScheme.primaryContainer.withValues(alpha: 0.46)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: readiness.requiredReady
              ? colorScheme.primary.withValues(alpha: 0.38)
              : colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  readiness.requiredReady
                      ? Icons.verified
                      : Icons.fact_check_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Publish readiness',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _CreatePill(
                  label:
                      '${readiness.readyCount}/${readiness.items.length} ready',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              children: readiness.items
                  .map((_CreateReadinessItem item) => _ReadinessRow(item: item))
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({required this.item});

  final _CreateReadinessItem item;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Icon(
            item.ready ? Icons.check_circle : Icons.radio_button_unchecked,
            color: item.ready ? colorScheme.primary : colorScheme.outline,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: item.required ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            item.ready ? 'Ready' : item.emptyLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: item.ready
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatePreviewCard extends StatelessWidget {
  const _CreatePreviewCard({required this.draft, required this.readiness});

  final CreateDraftEntity draft;
  final _CreateReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final CreateBlockConfig config = createBlockConfigFor(draft.objectType);
    final CreateTaxonomyCategory? category = createTaxonomyCategoryById(
      draft.mainCategory,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                draft.media.coverImage.trim().isEmpty
                    ? Icons.image
                    : Icons.image_outlined,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Listing preview',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      _CreatePill(
                        label: readiness.requiredReady
                            ? 'Publishable'
                            : 'Draft',
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    draft.title.trim().isEmpty
                        ? 'Untitled ${config.title.toLowerCase()}'
                        : draft.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _previewSubtitle(draft, category),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _CreatePill(label: config.title),
                      if (category != null)
                        _CreatePill(label: category.defaultParticipationMode),
                      _CreatePill(
                        label: draft.isFree
                            ? 'Free'
                            : '${draft.basePrice?.toStringAsFixed(0) ?? '?'} ${draft.currency}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _previewSubtitle(
    CreateDraftEntity draft,
    CreateTaxonomyCategory? category,
  ) {
    final List<String> parts = <String>[
      if (category != null) category.title,
      if (draft.subcategory.trim().isNotEmpty) draft.subcategory,
      if (draft.city.trim().isNotEmpty) draft.city,
    ];
    if (parts.isEmpty) {
      return draft.shortDescription.trim().isEmpty
          ? 'Choose taxonomy and add details'
          : draft.shortDescription;
    }
    return parts.join(' · ');
  }
}

bool _needsRentalReview(CreateDraftEntity draft) {
  final Map<String, Object?>? migration =
      draft.sectionData['migration'] as Map<String, Object?>?;
  return migration?['review_as_rental'] == true;
}

class _RentalReviewBanner extends StatelessWidget {
  const _RentalReviewBanner({
    required this.onKeepSession,
    required this.onConvertToRental,
  });

  final VoidCallback onKeepSession;
  final VoidCallback onConvertToRental;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey<String>('rental-review-banner'),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Could this be a rental?',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'This legacy offer was migrated safely as a Bookable session. '
              'Choose Rental only if equipment or transport is being rented.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: onKeepSession,
                  child: const Text('Keep session'),
                ),
                FilledButton(
                  onPressed: onConvertToRental,
                  child: const Text('Convert to rental'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePill extends StatelessWidget {
  const _CreatePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _CreateTaxonomyPicker extends StatelessWidget {
  const _CreateTaxonomyPicker({
    required this.objectType,
    required this.selectedCategoryId,
    required this.selectedSubcategoryId,
    required this.onCategorySelected,
    required this.onSubcategorySelected,
  });

  final CreateObjectType objectType;
  final String selectedCategoryId;
  final String selectedSubcategoryId;
  final ValueChanged<CreateTaxonomyCategory> onCategorySelected;
  final void Function(
    CreateTaxonomyCategory category,
    CreateTaxonomySubcategory subcategory,
  )
  onSubcategorySelected;

  @override
  Widget build(BuildContext context) {
    final List<CreateTaxonomyCategory> categories = createTaxonomyForObjectType(
      objectType,
    );
    final CreateTaxonomyCategory? selectedCategory = createTaxonomyCategoryById(
      selectedCategoryId,
    );
    final CreateTaxonomyCategory? activeCategory =
        selectedCategory != null && selectedCategory.allows(objectType)
        ? selectedCategory
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Scenario taxonomy',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 132,
          child: ListView.separated(
            key: const ValueKey<String>('create-taxonomy-group-rail'),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int index) {
              final CreateTaxonomyCategory category = categories[index];
              return _TaxonomyCategoryCard(
                category: category,
                selected: category.id == selectedCategoryId,
                onTap: () => onCategorySelected(category),
              );
            },
          ),
        ),
        if (activeCategory != null) ...<Widget>[
          const SizedBox(height: 14),
          _SelectedTaxonomySummary(
            category: activeCategory,
            selectedSubcategoryId: selectedSubcategoryId,
            objectType: objectType,
          ),
          const SizedBox(height: 10),
          _TaxonomySubcategoryPicker(
            key: ValueKey<String>(activeCategory.id),
            category: activeCategory,
            selectedSubcategoryId: selectedSubcategoryId,
            onSelected: (CreateTaxonomySubcategory subcategory) {
              onSubcategorySelected(activeCategory, subcategory);
            },
          ),
        ],
      ],
    );
  }
}

class _DynamicCriteriaSection extends StatelessWidget {
  const _DynamicCriteriaSection({required this.draft, required this.onChanged});

  final CreateDraftEntity draft;
  final void Function(String fieldId, Object? value) onChanged;

  @override
  Widget build(BuildContext context) {
    final CategoryCriteriaResult? result = const GetCategoryCriteriaUseCase()(
      draft.subcategory,
    );
    if (result == null || result.fields.isEmpty) {
      return const SizedBox.shrink();
    }
    final Map<String, Object?> values = <String, Object?>{
      ...?draft.sectionData['criteria'] as Map<String, Object?>?,
    };
    return Card(
      key: const ValueKey<String>('dynamic-criteria-section'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Activity criteria',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Profile: ${result.profile.id.replaceAll('_', ' ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final RechargeCriteriaFieldDefinition field
                in result.fields) ...<Widget>[
              if (field.type == 'bool')
                SwitchListTile.adaptive(
                  key: ValueKey<String>('criteria-${field.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(_criteriaLabel(result, field)),
                  subtitle: field.description.isEmpty
                      ? null
                      : Text(field.description),
                  value: values[field.id] as bool? ?? false,
                  onChanged: (bool value) => onChanged(field.id, value),
                )
              else
                TextFormField(
                  key: ValueKey<String>('criteria-${field.id}'),
                  initialValue: values[field.id]?.toString() ?? '',
                  keyboardType: field.type == 'number' || field.type == 'range'
                      ? TextInputType.number
                      : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: _criteriaLabel(result, field),
                    helperText: field.description.isEmpty
                        ? null
                        : field.description,
                  ),
                  onChanged: (String value) => onChanged(field.id, value),
                ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  String _criteriaLabel(
    CategoryCriteriaResult result,
    RechargeCriteriaFieldDefinition field,
  ) {
    final String label = field.id.replaceAll('_', ' ');
    return result.profile.requiredFieldIds.contains(field.id)
        ? '$label *'
        : label;
  }
}

class _TaxonomySubcategoryPicker extends StatefulWidget {
  const _TaxonomySubcategoryPicker({
    super.key,
    required this.category,
    required this.selectedSubcategoryId,
    required this.onSelected,
  });

  final CreateTaxonomyCategory category;
  final String selectedSubcategoryId;
  final ValueChanged<CreateTaxonomySubcategory> onSelected;

  @override
  State<_TaxonomySubcategoryPicker> createState() =>
      _TaxonomySubcategoryPickerState();
}

class _TaxonomySubcategoryPickerState
    extends State<_TaxonomySubcategoryPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final String normalizedQuery = _query.trim().toLowerCase();
    final List<CreateTaxonomySubcategory> visibleSubcategories = widget
        .category
        .subcategories
        .where((CreateTaxonomySubcategory subcategory) {
          if (normalizedQuery.isEmpty) return true;
          return subcategory.title.toLowerCase().contains(normalizedQuery) ||
              subcategory.id.contains(normalizedQuery) ||
              subcategory.activityCategory.aliases.any(
                (String alias) => alias.toLowerCase().contains(normalizedQuery),
              ) ||
              subcategory.activityCategory.searchKeywords.any(
                (String keyword) =>
                    keyword.toLowerCase().contains(normalizedQuery),
              );
        })
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          key: const ValueKey<String>('taxonomy-category-search'),
          decoration: InputDecoration(
            labelText:
                'Search ${widget.category.subcategories.length} categories',
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (String value) => setState(() => _query = value),
        ),
        const SizedBox(height: 10),
        if (visibleSubcategories.isEmpty)
          const Text('No categories match this search.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visibleSubcategories
                .map(
                  (CreateTaxonomySubcategory subcategory) => ChoiceChip(
                    label: Text(subcategory.title),
                    selected: subcategory.id == widget.selectedSubcategoryId,
                    onSelected: (_) => widget.onSelected(subcategory),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _TaxonomyCategoryCard extends StatelessWidget {
  const _TaxonomyCategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final CreateTaxonomyCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color background = selected
        ? colorScheme.primaryContainer
        : colorScheme.surface;
    final Color border = selected
        ? colorScheme.primary
        : colorScheme.outline.withValues(alpha: 0.32);
    return SizedBox(
      width: 186,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(_iconForCategory(category.id), size: 22),
                  const Spacer(),
                  if (selected)
                    Icon(
                      Icons.check_circle,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                category.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                category.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedTaxonomySummary extends StatelessWidget {
  const _SelectedTaxonomySummary({
    required this.category,
    required this.selectedSubcategoryId,
    required this.objectType,
  });

  final CreateTaxonomyCategory category;
  final String selectedSubcategoryId;
  final CreateObjectType objectType;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String path = selectedSubcategoryId.isEmpty
        ? category.id
        : '${category.id}.$selectedSubcategoryId';
    CreateTaxonomySubcategory? selectedSubcategory;
    for (final CreateTaxonomySubcategory subcategory
        in category.subcategories) {
      if (subcategory.id == selectedSubcategoryId) {
        selectedSubcategory = subcategory;
        break;
      }
    }
    final String participationMode =
        selectedSubcategory?.participationModeFor(objectType) ??
        category.defaultParticipationMode;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(Icons.account_tree, color: colorScheme.secondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$path · $participationMode',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconForCategory(String id) {
  return switch (id) {
    'music_nightlife' => Icons.music_note,
    'comedy_theatre_performance' => Icons.theater_comedy,
    'cinema_screenings' => Icons.movie_outlined,
    'education_talks' => Icons.school_outlined,
    'business_networking' => Icons.handshake_outlined,
    'workshops_masterclasses' => Icons.build_outlined,
    'language_social_learning' => Icons.translate,
    'sport' => Icons.sports_tennis,
    'outdoor_nature_walking' => Icons.park,
    'water_activities' => Icons.kayaking_outlined,
    'winter_seasonal' => Icons.ac_unit,
    'wellness_recharge' => Icons.self_improvement,
    'food_drinks' => Icons.local_cafe,
    'art_culture_museums' => Icons.museum,
    'games_indoor' => Icons.casino,
    'dance' => Icons.nightlife_outlined,
    'travel_tours' => Icons.tour,
    'family_kids' => Icons.family_restroom,
    'pets_animals' => Icons.pets_outlined,
    'community_charity' => Icons.volunteer_activism,
    'markets_fairs' => Icons.storefront_outlined,
    'holidays_seasonal' => Icons.celebration_outlined,
    'adrenaline_entertainment' => Icons.bolt,
    'attractions' => Icons.attractions,
    'auto_moto' => Icons.directions_car,
    'geek_tech' => Icons.memory,
    'dating_singles' => Icons.favorite_outline,
    'other' => Icons.more_horiz,
    _ => Icons.category,
  };
}

IconData _iconForCreateBlock(CreateObjectType objectType) {
  return switch (objectType) {
    CreateObjectType.event => Icons.event_available,
    CreateObjectType.activity => Icons.directions_walk,
    CreateObjectType.route => Icons.route,
    CreateObjectType.place => Icons.place,
    CreateObjectType.session => Icons.calendar_month,
    CreateObjectType.quickPlan => Icons.flash_on,
    CreateObjectType.findPeople => Icons.group_add,
    CreateObjectType.classWorkshop => Icons.school_outlined,
    CreateObjectType.rental => Icons.inventory_2_outlined,
    CreateObjectType.collection => Icons.collections_bookmark_outlined,
  };
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.onChanged,
    this.errorText,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        minLines: maxLines > 1 ? maxLines : null,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          errorText: errorText,
        ),
      ),
    );
  }
}

class _CreateStateMessage extends StatelessWidget {
  const _CreateStateMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
    );
  }
}

class _CreateSeedBanner extends StatelessWidget {
  const _CreateSeedBanner({required this.seedContext});

  final _CreateSeedContext seedContext;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.auto_awesome, color: colorScheme.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Seeded from ${seedContext.sourceLabel}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              seedContext.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (seedContext.chips.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: seedContext.chips
                    .map((String chip) => _CreatePill(label: chip))
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScenarioRouteSeedPanel extends StatelessWidget {
  const _ScenarioRouteSeedPanel({
    required this.seedContext,
    required this.onEditRoute,
    required this.onMapRoute,
  });

  final _ScenarioRouteSeedContext seedContext;
  final VoidCallback onEditRoute;
  final VoidCallback onMapRoute;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.route, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Scenario route seed',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${seedContext.stopCount} stops',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              seedContext.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (seedContext.prompt.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                seedContext.prompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: seedContext.chips
                  .map((String chip) => _CreatePill(label: chip))
                  .toList(growable: false),
            ),
            if (seedContext.stepCategories.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: seedContext.stepCategories
                    .map(
                      (String step) =>
                          _CreatePill(label: createTaxonomyLabelForPath(step)),
                    )
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onEditRoute,
                    icon: const Icon(Icons.edit_location_alt),
                    label: const Text('Edit route'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMapRoute,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Map route'),
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

class _CreateSeedContext {
  const _CreateSeedContext({
    required this.sourceLabel,
    required this.title,
    required this.chips,
  });

  static _CreateSeedContext? fromParameters(Map<String, String> params) {
    final String source = _seedParam(params, <String>['source']);
    final String prompt = _seedParam(params, <String>['q', 'prompt', 'query']);
    final String title = _seedParam(params, <String>['title', 'name']);
    final String category = _firstSeedValue(
      _seedParam(params, <String>['category', 'mainCategory']),
    );
    final String budget = _seedParam(params, <String>['budgetMax', 'price']);
    final String free = _seedParam(params, <String>['free', 'isFree']);
    final String radius = _seedParam(params, <String>['radius']);
    final String mood = _seedParam(params, <String>['mood']);
    final String duration = _seedParam(params, <String>['duration']);
    final String walking = _seedParam(params, <String>['walking']);
    final String steps = _seedParam(params, <String>['steps']);
    final double? radiusMeters = double.tryParse(radius);
    final int stepsCount = steps
        .split(',')
        .where((String step) => step.trim().isNotEmpty)
        .length;
    final bool hasContext =
        source.isNotEmpty ||
        prompt.isNotEmpty ||
        title.isNotEmpty ||
        category.isNotEmpty;
    if (!hasContext) return null;

    return _CreateSeedContext(
      sourceLabel: _seedSourceLabel(params),
      title: title.isNotEmpty
          ? title
          : prompt.isNotEmpty
          ? prompt
          : 'Recharge idea',
      chips: <String>[
        if (category.isNotEmpty) category,
        if (free == '1' || free.toLowerCase() == 'true') 'Free',
        if (budget.isNotEmpty) 'up to $budget',
        if (radiusMeters != null) '${(radiusMeters / 1000).round()} km',
        if (mood.isNotEmpty) mood,
        if (duration.isNotEmpty) '$duration min',
        if (walking == '1') 'Walking',
        if (stepsCount > 0) '$stepsCount stops',
      ],
    );
  }

  final String sourceLabel;
  final String title;
  final List<String> chips;
}

class _ScenarioRouteSeedContext {
  const _ScenarioRouteSeedContext({
    required this.title,
    required this.prompt,
    required this.mood,
    required this.duration,
    required this.free,
    required this.walking,
    required this.stepCategories,
  });

  static _ScenarioRouteSeedContext? fromParameters(Map<String, String> params) {
    final String source = _seedParam(params, <String>['source']).toLowerCase();
    final String category = _firstSeedValue(
      _seedParam(params, <String>['category', 'mainCategory']),
    ).toLowerCase();
    if (source != 'scenario' && category != 'scenario') return null;

    final List<String> steps = _seedParam(params, <String>['steps'])
        .split(',')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    if (steps.isEmpty) return null;

    return _ScenarioRouteSeedContext(
      title: _seedParam(params, <String>['title', 'name']).isEmpty
          ? 'Scenario route'
          : _seedParam(params, <String>['title', 'name']),
      prompt: _seedParam(params, <String>['q', 'prompt', 'query']),
      mood: _seedParam(params, <String>['mood']),
      duration: _seedParam(params, <String>['duration']),
      free: _seedParam(params, <String>['free', 'isFree']),
      walking: _seedParam(params, <String>['walking']),
      stepCategories: steps,
    );
  }

  final String title;
  final String prompt;
  final String mood;
  final String duration;
  final String free;
  final String walking;
  final List<String> stepCategories;

  int get stopCount => stepCategories.length;

  List<String> get chips {
    return <String>[
      if (mood.isNotEmpty) mood,
      if (duration.isNotEmpty) '$duration min',
      if (free == '1' || free.toLowerCase() == 'true') 'Free',
      if (walking == '1' || walking.toLowerCase() == 'true') 'Walking',
    ];
  }

  String get builderLocation {
    return Uri(
      path: RouteNames.scenarioBuilder,
      queryParameters: _routeParameters(includeMode: false),
    ).toString();
  }

  String get mapLocation {
    return Uri(
      path: RouteNames.discoverMap,
      queryParameters: _routeParameters(includeMode: true),
    ).toString();
  }

  Map<String, String> _routeParameters({required bool includeMode}) {
    return <String, String>{
      if (includeMode) 'mode': 'scenario',
      if (mood.isNotEmpty) 'mood': mood,
      if (duration.isNotEmpty) 'duration': duration,
      if (free.isNotEmpty) 'free': free,
      if (walking.isNotEmpty) 'walking': walking,
      if (prompt.isNotEmpty) 'prompt': prompt,
      'steps': stepCategories.join(','),
    };
  }
}

class _CreateSeed {
  const _CreateSeed({
    required this.hasValues,
    required this.objectType,
    required this.categoryId,
    required this.subcategoryId,
    required this.title,
    required this.shortDescription,
    required this.fullDescription,
    required this.city,
    required this.venueName,
    required this.addressLine1,
    required this.coverImage,
    required this.isFree,
    required this.startDateTimeUtc,
    this.basePrice,
  });

  factory _CreateSeed.fromParameters(Map<String, String> params) {
    final String prompt = _seedParam(params, <String>['q', 'prompt', 'query']);
    final String rawCategory = _firstSeedValue(
      _seedParam(params, <String>['category', 'mainCategory']),
    );
    final String rawSubcategory = _seedParam(params, <String>[
      'subcategory',
      'subCategory',
    ]);
    final String rawTitle = _seedParam(params, <String>['title', 'name']);
    final String source = _seedParam(params, <String>['source']);
    final _TaxonomySeed taxonomy = _taxonomySeedFor(
      rawCategory: rawCategory,
      rawSubcategory: rawSubcategory,
      prompt: prompt,
    );
    final String title = _seedTitle(rawTitle, prompt, taxonomy.categoryId);
    final CreateObjectType objectType = _seedObjectType(params);
    final double? basePrice = _seedPrice(params);
    final bool isFree = _seedIsFree(params, basePrice);

    return _CreateSeed(
      hasValues:
          prompt.isNotEmpty ||
          rawTitle.isNotEmpty ||
          rawCategory.isNotEmpty ||
          rawSubcategory.isNotEmpty ||
          source.isNotEmpty,
      objectType: objectType,
      categoryId: taxonomy.categoryId,
      subcategoryId: taxonomy.subcategoryId,
      title: title,
      shortDescription: _seedShortDescription(params, prompt, title),
      fullDescription: _seedFullDescription(params, prompt, title),
      city: _seedParam(params, <String>['city', 'location']).isEmpty
          ? 'Rezekne'
          : _seedParam(params, <String>['city', 'location']),
      venueName: _seedVenueName(params, objectType, title),
      addressLine1: _seedAddress(params),
      coverImage: _seedCoverImage(params, taxonomy.categoryId),
      isFree: isFree,
      basePrice: basePrice,
      startDateTimeUtc: _seedStartDateTime(params),
    );
  }

  final bool hasValues;
  final CreateObjectType objectType;
  final String categoryId;
  final String subcategoryId;
  final String title;
  final String shortDescription;
  final String fullDescription;
  final String city;
  final String venueName;
  final String addressLine1;
  final String coverImage;
  final bool isFree;
  final double? basePrice;
  final DateTime startDateTimeUtc;
}

class _TaxonomySeed {
  const _TaxonomySeed({required this.categoryId, required this.subcategoryId});

  final String categoryId;
  final String subcategoryId;
}

String _seedKeyFor(Map<String, String> params) {
  final List<MapEntry<String, String>> entries =
      params.entries.toList(growable: false)
        ..sort((MapEntry<String, String> a, MapEntry<String, String> b) {
          return a.key.compareTo(b.key);
        });
  return entries
      .map((MapEntry<String, String> entry) => '${entry.key}=${entry.value}')
      .join('&');
}

String _seedParam(Map<String, String> params, List<String> keys) {
  for (final String key in keys) {
    final String? value = params[key];
    if (value != null && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _firstSeedValue(String value) {
  for (final String part in value.split(',')) {
    final String trimmed = part.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

CreateObjectType _seedObjectType(Map<String, String> params) {
  final String value = _seedParam(params, <String>[
    'type',
    'objectType',
  ]).toLowerCase();
  final String source = _seedParam(params, <String>['source']).toLowerCase();
  final String category = _firstSeedValue(
    _seedParam(params, <String>['category', 'mainCategory']),
  ).toLowerCase();
  final bool routeSeed =
      source == 'scenario' || category == 'scenario' || category == 'route';
  if (routeSeed && (value.isEmpty || value == 'event' || value == 'route')) {
    return CreateObjectType.route;
  }
  if (value.isEmpty) return CreateObjectType.event;
  return createObjectTypeFromId(value);
}

_TaxonomySeed _taxonomySeedFor({
  required String rawCategory,
  required String rawSubcategory,
  required String prompt,
}) {
  final String category = rawCategory.toLowerCase();
  final CreateTaxonomyCategory? exactCategory = createTaxonomyCategoryById(
    category,
  );
  if (exactCategory != null) {
    return _taxonomySeedFromCategory(exactCategory, rawSubcategory);
  }

  switch (category) {
    case 'sport':
      return _knownTaxonomySeed('sport', 'tennis');
    case 'outdoor':
      return _knownTaxonomySeed('outdoor_nature_walking', 'city_walk');
    case 'wellness':
      return _knownTaxonomySeed('wellness_recharge', 'calm_walk');
    case 'food':
    case 'food_drinks':
      return _knownTaxonomySeed('food_drinks', 'coffee');
    case 'art':
    case 'music':
      return _knownTaxonomySeed('art_culture_museums', 'museum');
    case 'family':
      return _knownTaxonomySeed('family_kids', 'family_activity');
    case 'route':
    case 'scenario':
      return _knownTaxonomySeed('travel_tours', 'walking_tour');
  }

  final String text = '$category $rawSubcategory $prompt'.toLowerCase();
  if (text.contains('museum') ||
      text.contains('gallery') ||
      text.contains('art')) {
    return _knownTaxonomySeed('art_culture_museums', 'museum');
  }
  if (text.contains('coffee') ||
      text.contains('cafe') ||
      text.contains('brunch') ||
      text.contains('food')) {
    return _knownTaxonomySeed('food_drinks', 'coffee');
  }
  if (text.contains('walk') ||
      text.contains('park') ||
      text.contains('outdoor')) {
    return _knownTaxonomySeed('outdoor_nature_walking', 'city_walk');
  }
  if (text.contains('family') || text.contains('kids')) {
    return _knownTaxonomySeed('family_kids', 'family_activity');
  }
  if (text.contains('sport') ||
      text.contains('tennis') ||
      text.contains('yoga')) {
    return _knownTaxonomySeed('sport', 'tennis');
  }
  return _knownTaxonomySeed('wellness_recharge', 'calm_walk');
}

_TaxonomySeed _knownTaxonomySeed(String categoryId, String subcategoryId) {
  final CreateTaxonomyCategory? category = createTaxonomyCategoryById(
    categoryId,
  );
  if (category == null) {
    return const _TaxonomySeed(
      categoryId: 'wellness_recharge',
      subcategoryId: 'calm_walk',
    );
  }
  return _taxonomySeedFromCategory(category, subcategoryId);
}

_TaxonomySeed _taxonomySeedFromCategory(
  CreateTaxonomyCategory category,
  String rawSubcategory,
) {
  final String subcategory = rawSubcategory.trim();
  final bool hasSubcategory = category.subcategories.any(
    (CreateTaxonomySubcategory item) => item.id == subcategory,
  );
  return _TaxonomySeed(
    categoryId: category.id,
    subcategoryId: hasSubcategory
        ? subcategory
        : createDefaultSubcategoryFor(category)?.id ?? '',
  );
}

String _seedTitle(String rawTitle, String prompt, String categoryId) {
  if (rawTitle.isNotEmpty) return rawTitle;
  if (prompt.isNotEmpty) return _sentenceTitle(prompt);
  final CreateTaxonomyCategory? category = createTaxonomyCategoryById(
    categoryId,
  );
  return '${category?.title ?? 'Recharge'} idea';
}

String _sentenceTitle(String value) {
  final String cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) return '';
  final String capped = cleaned.length > 48
      ? '${cleaned.substring(0, 48).trim()} idea'
      : cleaned;
  return capped[0].toUpperCase() + capped.substring(1);
}

String _seedShortDescription(
  Map<String, String> params,
  String prompt,
  String title,
) {
  final String subtitle = _seedParam(params, <String>[
    'subtitle',
    'shortDescription',
    'description',
  ]);
  if (subtitle.isNotEmpty) return subtitle;
  final String subject = prompt.isEmpty ? title : prompt;
  return 'Drafted from ${_seedSourceLabel(params)} for $subject.';
}

String _seedFullDescription(
  Map<String, String> params,
  String prompt,
  String title,
) {
  final String fullDescription = _seedParam(params, <String>[
    'fullDescription',
  ]);
  if (fullDescription.isNotEmpty) return fullDescription;
  final String subject = prompt.isEmpty ? title : prompt;
  final String routeSteps = _seedParam(params, <String>['steps']);
  final String routeStepsSentence = routeSteps.isEmpty
      ? ''
      : 'Route steps: $routeSteps. ';
  return 'Seeded from ${_seedSourceLabel(params)}. '
      'Original context: $subject. '
      '$routeStepsSentence'
      'Review capacity, schedule, booking, and moderation details before '
      'publishing.';
}

String _seedSourceLabel(Map<String, String> params) {
  final String source = _seedParam(params, <String>['source']).toLowerCase();
  switch (source) {
    case 'details':
      return 'details';
    case 'saved_search':
      return 'saved search';
    case 'search':
      return 'search conditions';
    case 'smart_search':
      return 'smart search';
    case 'profile':
      return 'profile workspace';
    case 'scenario':
      return 'scenario route';
    case 'map':
      return 'map area';
  }
  return 'Recharge';
}

String _seedVenueName(
  Map<String, String> params,
  CreateObjectType objectType,
  String title,
) {
  final String venue = _seedParam(params, <String>['venue', 'venueName']);
  if (venue.isNotEmpty) return venue;
  if (objectType == CreateObjectType.place ||
      objectType == CreateObjectType.session ||
      objectType == CreateObjectType.rental) {
    return title;
  }
  if (objectType == CreateObjectType.route) return 'Route start point';
  return 'Meeting point';
}

String _seedAddress(Map<String, String> params) {
  final String address = _seedParam(params, <String>[
    'address',
    'addressLine',
    'addressLine1',
  ]);
  if (address.isNotEmpty) return address;
  final String city = _seedParam(params, <String>['city', 'location']);
  return city.isEmpty ? 'City center' : city;
}

String _seedCoverImage(Map<String, String> params, String categoryId) {
  final String cover = _seedParam(params, <String>[
    'cover',
    'coverImage',
    'coverImageUrl',
  ]);
  if (cover.isNotEmpty) return cover;
  switch (categoryId) {
    case 'art_culture_museums':
      return 'https://images.unsplash.com/photo-1518998053901-5348d3961a04';
    case 'food_drinks':
      return 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085';
    case 'outdoor_nature_walking':
      return 'https://images.unsplash.com/photo-1469474968028-56623f02e42e';
    case 'sport':
      return 'https://images.unsplash.com/photo-1517649763962-0c623066013b';
    default:
      return 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee';
  }
}

double? _seedPrice(Map<String, String> params) {
  final String value = _seedParam(params, <String>[
    'price',
    'budgetMax',
    'basePrice',
  ]);
  if (value.isEmpty) return null;
  return double.tryParse(value.replaceAll(',', '.'));
}

bool _seedIsFree(Map<String, String> params, double? basePrice) {
  final String value = _seedParam(params, <String>[
    'free',
    'isFree',
    'freeOnly',
  ]).toLowerCase();
  if (value == '1' || value == 'true' || value == 'yes') return true;
  if (value == '0' || value == 'false' || value == 'no') return false;
  return basePrice == null || basePrice <= 0;
}

DateTime _seedStartDateTime(Map<String, String> params) {
  for (final String key in <String>['start', 'startsAt', 'dateFrom']) {
    final String raw = _seedParam(params, <String>[key]);
    final DateTime? parsed = DateTime.tryParse(raw)?.toUtc();
    if (parsed != null) return parsed;
  }
  return DateTime.now().toUtc().add(const Duration(days: 3));
}

class _CreatePreset {
  const _CreatePreset({
    required this.label,
    required this.objectType,
    required this.categoryId,
    required this.subcategoryId,
    required this.title,
    required this.shortDescription,
    required this.fullDescription,
    required this.city,
    required this.venueName,
    required this.addressLine1,
    required this.coverImage,
    required this.isFree,
    this.basePrice,
  });

  final String label;
  final CreateObjectType objectType;
  final String categoryId;
  final String subcategoryId;
  final String title;
  final String shortDescription;
  final String fullDescription;
  final String city;
  final String venueName;
  final String addressLine1;
  final String coverImage;
  final bool isFree;
  final double? basePrice;

  String get pathLabel => '$categoryId.$subcategoryId';
}

const List<_CreatePreset> _createPresets = <_CreatePreset>[
  _CreatePreset(
    label: 'Calm walk',
    objectType: CreateObjectType.activity,
    categoryId: 'wellness_recharge',
    subcategoryId: 'calm_walk',
    title: 'Calm walk in Rezekne',
    shortDescription: 'Low-pressure recharge walk with a quiet finish.',
    fullDescription:
        'A small group walk for people who want a calm reset, light movement, and space to breathe.',
    city: 'Rezekne',
    venueName: 'Rezekne city center',
    addressLine1: 'Atbrivosanas aleja',
    coverImage: 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee',
    isFree: true,
  ),
  _CreatePreset(
    label: 'Quick coffee',
    objectType: CreateObjectType.quickPlan,
    categoryId: 'food_drinks',
    subcategoryId: 'coffee',
    title: 'Coffee reset tonight',
    shortDescription: 'Simple coffee plan for a quick recharge today.',
    fullDescription:
        'A lightweight plan for people who want to meet for coffee without heavy scheduling.',
    city: 'Rezekne',
    venueName: 'Local cafe',
    addressLine1: 'City center',
    coverImage: 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085',
    isFree: false,
    basePrice: 5,
  ),
  _CreatePreset(
    label: 'Tennis partner',
    objectType: CreateObjectType.findPeople,
    categoryId: 'sport',
    subcategoryId: 'tennis',
    title: 'Looking for a tennis partner',
    shortDescription: 'Find one or two people for a friendly tennis session.',
    fullDescription:
        'A social request for people who want to play a friendly beginner-friendly tennis match.',
    city: 'Rezekne',
    venueName: 'Public tennis court',
    addressLine1: 'Sports center',
    coverImage: 'https://images.unsplash.com/photo-1517649763962-0c623066013b',
    isFree: true,
  ),
  _CreatePreset(
    label: 'Pottery workshop',
    objectType: CreateObjectType.classWorkshop,
    categoryId: 'workshops_masterclasses',
    subcategoryId: 'pottery',
    title: 'Beginner pottery workshop',
    shortDescription: 'Hands-on pottery workshop for a small group.',
    fullDescription:
        'A guided beginner workshop with materials, practical support, and a finished piece to take home.',
    city: 'Rezekne',
    venueName: 'Creative studio',
    addressLine1: 'City center',
    coverImage: 'https://images.unsplash.com/photo-1610701596007-11502861dcfa',
    isFree: false,
    basePrice: 20,
  ),
  _CreatePreset(
    label: 'Walking route',
    objectType: CreateObjectType.route,
    categoryId: 'travel_tours',
    subcategoryId: 'walking_tour',
    title: 'Hidden gems walking tour',
    shortDescription: 'Local route through small places worth noticing.',
    fullDescription:
        'A guided local walk through calm corners, stories, and small recharge points around the city.',
    city: 'Rezekne',
    venueName: 'Old town meeting point',
    addressLine1: 'Central square',
    coverImage: 'https://images.unsplash.com/photo-1469474968028-56623f02e42e',
    isFree: false,
    basePrice: 12,
  ),
  _CreatePreset(
    label: 'Coffee spot',
    objectType: CreateObjectType.place,
    categoryId: 'food_drinks',
    subcategoryId: 'coffee',
    title: 'Quiet coffee recharge spot',
    shortDescription: 'A calm cafe stop for reading, planning, or recovery.',
    fullDescription:
        'A creator-recommended coffee place with a quiet atmosphere and enough space for solo recharge time.',
    city: 'Rezekne',
    venueName: 'Local cafe',
    addressLine1: 'City center',
    coverImage: 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085',
    isFree: false,
    basePrice: 5,
  ),
  _CreatePreset(
    label: 'Wellness guide',
    objectType: CreateObjectType.collection,
    categoryId: 'wellness_recharge',
    subcategoryId: 'nature_reset',
    title: 'Local wellness guide',
    shortDescription: 'A collection of calm sessions and recovery places.',
    fullDescription:
        'A curated guide for people looking for calm recharge sessions, nature resets, and quiet recovery spaces.',
    city: 'Rezekne',
    venueName: 'Recharge studio',
    addressLine1: 'Main street',
    coverImage: 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee',
    isFree: true,
  ),
  _CreatePreset(
    label: 'Yoga slot',
    objectType: CreateObjectType.session,
    categoryId: 'sport',
    subcategoryId: 'yoga',
    title: 'Morning yoga slot',
    shortDescription: 'Bookable small-group yoga class.',
    fullDescription:
        'A bookable wellness slot with limited places, simple booking, and a beginner-friendly pace.',
    city: 'Rezekne',
    venueName: 'Recharge studio',
    addressLine1: 'Main street',
    coverImage: 'https://images.unsplash.com/photo-1506126613408-eca07ce68773',
    isFree: false,
    basePrice: 10,
  ),
  _CreatePreset(
    label: 'Bike rental',
    objectType: CreateObjectType.rental,
    categoryId: 'sport',
    subcategoryId: 'cycling',
    title: 'City bike rental',
    shortDescription: 'Comfortable bicycles for a local recharge ride.',
    fullDescription:
        'Hourly bicycle rental with a lock and helmet for independent city routes and nature rides.',
    city: 'Rezekne',
    venueName: 'Bike pickup point',
    addressLine1: 'City center',
    coverImage: 'https://images.unsplash.com/photo-1571068316344-75bc76f77890',
    isFree: false,
    basePrice: 8,
  ),
  _CreatePreset(
    label: 'Community update',
    objectType: CreateObjectType.event,
    categoryId: 'community_charity',
    subcategoryId: 'neighborhood_event',
    title: 'Weekend recharge update',
    shortDescription: 'Short update from a local creator or venue.',
    fullDescription:
        'An announcement for followers about upcoming recharge ideas, schedule changes, or community updates.',
    city: 'Rezekne',
    venueName: 'Recharge community',
    addressLine1: 'City center',
    coverImage: 'https://images.unsplash.com/photo-1529156069898-49953e39b3ac',
    isFree: true,
  ),
];

class _CreateReadiness {
  const _CreateReadiness({required this.items});

  final List<_CreateReadinessItem> items;

  int get readyCount {
    return items.where((_CreateReadinessItem item) => item.ready).length;
  }

  bool get requiredReady {
    return items
        .where((_CreateReadinessItem item) => item.required)
        .every((_CreateReadinessItem item) => item.ready);
  }
}

class _CreateReadinessItem {
  const _CreateReadinessItem({
    required this.label,
    required this.ready,
    required this.required,
    required this.emptyLabel,
  });

  final String label;
  final bool ready;
  final bool required;
  final String emptyLabel;
}

_CreateReadiness _createReadinessFor(CreateDraftEntity draft) {
  final CreateBlockConfig config = createBlockConfigFor(draft.objectType);
  return _CreateReadiness(
    items: <_CreateReadinessItem>[
      _CreateReadinessItem(
        label: 'Taxonomy selected',
        ready: draft.mainCategory.trim().isNotEmpty,
        required: true,
        emptyLabel: 'Choose',
      ),
      _CreateReadinessItem(
        label: 'Title added',
        ready: draft.title.trim().isNotEmpty,
        required: true,
        emptyLabel: 'Missing',
      ),
      _CreateReadinessItem(
        label: 'City added',
        ready: draft.city.trim().isNotEmpty,
        required: true,
        emptyLabel: 'Missing',
      ),
      _CreateReadinessItem(
        label: 'Cover image added',
        ready: draft.media.coverImage.trim().isNotEmpty,
        required: true,
        emptyLabel: 'Missing',
      ),
      _CreateReadinessItem(
        label: config.requiresStartDateTime
            ? '${config.title} start time added'
            : '${config.title} does not need start time',
        ready: !config.requiresStartDateTime || draft.startDateTimeUtc != null,
        required: true,
        emptyLabel: 'Missing',
      ),
      _CreateReadinessItem(
        label: 'Pricing clear',
        ready: draft.isFree || draft.basePrice != null,
        required: false,
        emptyLabel: 'Optional',
      ),
    ],
  );
}
