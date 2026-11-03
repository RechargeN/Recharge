import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../../../core/localization/user_message_catalog.dart';
import '../../application/controllers/create_controller.dart';
import '../../domain/repositories/create_image_picker_port.dart';

/// Which existing media field a picked photo goes into.
enum CreateMediaTarget { cover, gallery }

/// MP-OD-04: the URL/path field stays for debug builds (stand tests) and
/// whenever the picker is switched off; release users get the picker only.
bool showCreateMediaPathField(CreateController controller) =>
    kDebugMode || !controller.mediaPickerEnabled;

/// MEDIA-PICK-01: "Choose photo" and "Take photo" next to a cover or gallery
/// field of any Create section. The controller picks, removes metadata and
/// stores a private copy; this widget only shows progress, the picked cover
/// and the refusal in words (never the code). Nothing is shown while the
/// kill switch is off.
class CreateMediaPickActions extends StatefulWidget {
  const CreateMediaPickActions({
    required this.controller,
    required this.target,
    super.key,
  });

  final CreateController controller;
  final CreateMediaTarget target;

  @override
  State<CreateMediaPickActions> createState() => _CreateMediaPickActionsState();
}

class _CreateMediaPickActionsState extends State<CreateMediaPickActions> {
  bool _busy = false;

  String get _name =>
      widget.target == CreateMediaTarget.cover ? 'cover' : 'gallery';

  Future<void> _pick(CreateImageSource source) async {
    setState(() => _busy = true);
    final String? code = widget.target == CreateMediaTarget.cover
        ? await widget.controller.pickCoverImage(source)
        : await widget.controller.pickGalleryImage(source);
    if (!mounted) return;
    setState(() => _busy = false);
    if (code == null) return;
    final String text =
        UserMessageCatalog.message(
          context.l10n,
          UserMessageFamily.clientLocal,
          code,
        ) ??
        context.l10n.localErrorMediaDecodeFailed;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final CreateController controller = widget.controller;
    if (!controller.mediaPickerEnabled) return const SizedBox.shrink();
    final String cover = controller.state.draft.media.coverImage;
    final bool pickedCover =
        widget.target == CreateMediaTarget.cover &&
        controller.isPickedMediaCopy(cover);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (pickedCover)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(cover),
                      key: const Key('create-media-cover-preview'),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.square(
                        dimension: 56,
                        child: Icon(Icons.image_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(context.l10n.createMediaCoverSelected)),
                ],
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              OutlinedButton.icon(
                key: Key('create-media-pick-$_name'),
                onPressed: _busy
                    ? null
                    : () => _pick(CreateImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(context.l10n.createMediaChoosePhoto),
              ),
              if (controller.mediaCameraEnabled)
                OutlinedButton.icon(
                  key: Key('create-media-camera-$_name'),
                  onPressed: _busy
                      ? null
                      : () => _pick(CreateImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(context.l10n.createMediaTakePhoto),
                ),
              if (_busy)
                Row(
                  key: Key('create-media-preparing-$_name'),
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(context.l10n.createMediaPreparing),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
