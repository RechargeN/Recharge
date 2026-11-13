import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../application/controllers/create_controller.dart';

/// ADR 0022: the language the author wrote this text in. Nothing is preselected:
/// only the author knows it, and a wrong value would mislead a translation.
class ContentLanguageField extends StatelessWidget {
  const ContentLanguageField({super.key, required this.controller});

  final CreateController controller;

  static String _name(AppLocalizations l10n, String code) => switch (code) {
    'en' => l10n.languageNameEn,
    'lv' => l10n.languageNameLv,
    'ru' => l10n.languageNameRu,
    _ => code,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return DropdownButtonFormField<String>(
      key: const Key('content-language-field'),
      isExpanded: true,
      initialValue: controller.draftContentLanguage,
      decoration: InputDecoration(
        labelText: l10n.createContentLanguageLabel,
        helperText: l10n.createContentLanguageHelp,
        helperMaxLines: 3,
      ),
      items: <DropdownMenuItem<String>>[
        for (final String code in controller.supportedContentLocales)
          DropdownMenuItem<String>(value: code, child: Text(_name(l10n, code))),
      ],
      onChanged: controller.updateDraftContentLanguage,
    );
  }
}
