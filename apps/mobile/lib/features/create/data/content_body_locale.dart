import '../../../core/localization/app_locale_policy.dart';

/// L4.9.1: a Content body as it goes to the server names languages by their
/// canonical identifiers (`lv-LV`, `en`, `ru`). Create keeps the internal `lv`
/// in its forms and saved drafts; this is the one place it crosses to the API.
/// Saved drafts are not rewritten: an old `lv` draft is mapped on each send.
Map<String, Object?> canonicalContentBody(Map<String, Object?> body) =>
    _map(body, atBodyLevel: true);

Map<String, Object?> _map(
  Map<String, Object?> value, {
  bool atBodyLevel = false,
}) {
  return <String, Object?>{
    for (final MapEntry<String, Object?> entry in value.entries)
      entry.key: switch ((entry.key, entry.value)) {
        ('contentLocale', final String tag) => AppLocalePolicy.canonicalTag(
          tag,
        ),
        ('languages', final List<Object?> tags) when atBodyLevel => <Object?>[
          for (final Object? tag in tags)
            tag is String ? AppLocalePolicy.canonicalTag(tag) : tag,
        ],
        ('altText', final Map<String, Object?> texts) => <String, Object?>{
          for (final MapEntry<String, Object?> text in texts.entries)
            AppLocalePolicy.canonicalTag(text.key): text.value,
        },
        (_, final Map<String, Object?> nested) => _map(nested),
        (_, final List<Object?> items) => <Object?>[
          for (final Object? item in items)
            item is Map<String, Object?> ? _map(item) : item,
        ],
        (_, final Object? other) => other,
      },
  };
}
