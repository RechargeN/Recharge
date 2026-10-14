import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/content_server_path.dart';
import '../../application/content_validation_feedback.dart';
import '../../domain/entities/content_validation_violation.dart';
import '../../domain/entities/create_draft_entity.dart';

/// What the server publication still needs from this Create draft (M1 stage
/// 3, owner decision 3-Б). Shown only while the type's server path is enabled;
/// the local Create rules and their messages are unchanged. Each line names
/// the form field; a refusal without a known field shows the general text.
class ServerPublicationRequirements extends StatelessWidget {
  const ServerPublicationRequirements({
    super.key,
    required this.fields,
    required this.labelFor,
    this.generalRefusal = false,
  });

  /// Field path → what to fix.
  final Map<String, String> fields;
  final String Function(String fieldPath) labelFor;

  /// The server refused the draft and no detail maps to a field.
  final bool generalRefusal;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty && !generalRefusal) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    return Card(
      key: const Key('server-publication-requirements'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Needed for server publication',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final MapEntry<String, String> entry in fields.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${labelFor(entry.key)}: ${entry.value}',
                  key: Key('server-requirement-${entry.key}'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (fields.isEmpty && generalRefusal)
              Text(
                'The server refused this draft. Check the draft and try again.',
                key: const Key('server-requirement-general'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}

/// M1 stage 3 (3-Б): the server requirements of this draft and its last
/// server refusal, only while the server publication path of its type is on.
class DraftServerRequirements extends ConsumerWidget {
  const DraftServerRequirements({
    super.key,
    required this.draft,
    required this.accountId,
  });

  final CreateDraftEntity draft;
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ContentServerPath path = ref.watch(contentServerPathProvider);
    if (!path.isEnabled(draft.objectType)) return const SizedBox.shrink();
    final ContentValidationFeedbackStore store = ref.watch(
      contentValidationFeedbackProvider(draft.objectType),
    );
    final List<ContentValidationViolation> refusal = store.violationsFor(
      accountId,
      draft,
    );
    final Map<String, String> answered = contentFieldFeedback(
      draft.objectType,
      refusal,
    );
    final Map<String, String> fields = <String, String>{
      ...contentFieldFeedback(
        draft.objectType,
        serverRequirementsFor(draft, accountId: accountId, path: path),
      ),
      // The server answer wins for the same field.
      ...answered,
    };
    return ServerPublicationRequirements(
      fields: fields,
      labelFor: contentFieldLabel,
      generalRefusal: store.matches(accountId, draft) && answered.isEmpty,
    );
  }
}
