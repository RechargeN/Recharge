import { deepFreeze, type DeepReadonly } from '../../../shared/immutable.js';
import { parseLocaleId, type LocaleId } from './identifiers.js';

export interface LocalizedText {
  readonly schemaVersion: 1;
  readonly defaultLocale: LocaleId;
  readonly values: Readonly<Record<string, string>>;
}

export function createLocalizedText(input: {
  readonly defaultLocale: string;
  readonly values: Readonly<Record<string, string>>;
}): DeepReadonly<LocalizedText> {
  const defaultLocale = parseLocaleId(input.defaultLocale);
  const entries = Object.entries(input.values);
  if (entries.length < 1 || entries.length > 32) {
    throw new TypeError('localized_text_values_invalid');
  }
  const values: Record<string, string> = {};
  for (const [rawLocale, text] of entries) {
    const locale = parseLocaleId(rawLocale);
    if (Object.hasOwn(values, locale) || text.trim().length === 0 || text.length > 10_000) {
      throw new TypeError('localized_text_value_invalid');
    }
    values[locale] = text;
  }
  if (!Object.hasOwn(values, defaultLocale)) {
    throw new TypeError('localized_text_default_missing');
  }
  return deepFreeze({ schemaVersion: 1, defaultLocale, values });
}
