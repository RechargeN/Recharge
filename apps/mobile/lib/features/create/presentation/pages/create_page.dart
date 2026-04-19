import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/controllers/create_controller.dart';
import '../../application/create_providers.dart';
import '../../application/state/create_state.dart';
import '../../domain/entities/create_draft_entity.dart';

class CreatePage extends ConsumerStatefulWidget {
  const CreatePage({super.key});

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
  final TextEditingController _shortDescriptionController = TextEditingController();
  final TextEditingController _fullDescriptionController = TextEditingController();
  final TextEditingController _coverController = TextEditingController();
  final TextEditingController _galleryInputController = TextEditingController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String? _loadKey;

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
      return const Scaffold(
        body: Center(child: Text('Требуется авторизация')),
      );
    }

    _scheduleLoad(
      userId: user.id,
      organizerEmail: user.email,
      organizerName: user.email.split('@').first,
    );
    _syncControllers(state);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create'),
      ),
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
        CreateStatus.publishSuccess =>
          ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              SegmentedButton<CreateObjectType>(
                segments: const <ButtonSegment<CreateObjectType>>[
                  ButtonSegment<CreateObjectType>(
                    value: CreateObjectType.event,
                    label: Text('Event'),
                  ),
                  ButtonSegment<CreateObjectType>(
                    value: CreateObjectType.place,
                    label: Text('Place'),
                  ),
                ],
                selected: <CreateObjectType>{state.draft.objectType},
                onSelectionChanged: (Set<CreateObjectType> values) {
                  controller.setObjectType(values.first);
                },
              ),
              const SizedBox(height: 12),
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
                label: 'Venue',
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
              if (state.draft.objectType == CreateObjectType.event)
                _LabeledField(
                  label: 'Start datetime UTC (YYYY-MM-DDTHH:mm:ssZ) *',
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
                title: const Text('Free event/place'),
              ),
              if (!state.draft.isFree)
                _LabeledField(
                  label: 'Base price',
                  controller: _priceController,
                  onChanged: controller.updateBasePrice,
                ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state.status == CreateStatus.saving ||
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
                      onPressed: state.status == CreateStatus.saving ||
                              state.status == CreateStatus.publishing
                          ? null
                          : () async {
                              final bool success = await controller.publishDraft();
                              if (!success) return;
                              ref.read(appRouterProvider).go(RouteNames.createSuccess);
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
      ref.read(createControllerProvider).ensureLoaded(
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
    _syncController(
      _priceController,
      state.draft.basePrice?.toString() ?? '',
    );
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

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
  const _CreateStateMessage({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text),
      ),
    );
  }
}
