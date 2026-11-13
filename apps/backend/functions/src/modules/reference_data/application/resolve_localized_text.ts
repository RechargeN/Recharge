import type { LocalizedText } from '../domain/localized_text.js';
import type { MarketConfigRevision } from '../domain/market_config.js';
import { parseLocaleId, type LocaleId } from '../domain/identifiers.js';

export type LocalizedTextResolution =
  | {
      readonly ok: true;
      readonly text: string;
      readonly requestedLocale: LocaleId;
      readonly resolvedLocale: LocaleId;
      readonly resolutionKind: 'exact' | 'language_fallback' | 'market_fallback' | 'default';
      readonly requestedLocaleSupported: boolean;
    }
  | {
      readonly ok: false;
      readonly code:
        'unsupported_schema' | 'unsupported_locale' | 'translation_missing' | 'fallback_forbidden';
      readonly requestedLocale: string;
    };

export function resolveLocalizedText(input: {
  readonly text: LocalizedText;
  readonly requestedLocale: string;
  readonly marketConfig: MarketConfigRevision;
  readonly fallbackPolicy?: 'allowed' | 'forbidden';
}): LocalizedTextResolution {
  if (input.text.schemaVersion !== 1 || input.marketConfig.schemaVersion !== 1) {
    return { ok: false, code: 'unsupported_schema', requestedLocale: input.requestedLocale };
  }
  let requestedLocale: LocaleId;
  try {
    requestedLocale = parseLocaleId(input.requestedLocale);
  } catch {
    return { ok: false, code: 'unsupported_locale', requestedLocale: input.requestedLocale };
  }
  const supported = input.marketConfig.supportedLocales.includes(requestedLocale);
  const exact = input.text.values[requestedLocale];
  if (exact !== undefined)
    return success(exact, requestedLocale, requestedLocale, 'exact', supported);
  if (input.fallbackPolicy === 'forbidden') {
    return { ok: false, code: 'fallback_forbidden', requestedLocale };
  }
  const candidates: Array<{
    readonly locale: LocaleId;
    readonly kind: 'language_fallback' | 'market_fallback' | 'default';
  }> = [];
  for (const locale of input.marketConfig.languageFallbacks[requestedLocale] ?? [])
    candidates.push({ locale, kind: 'language_fallback' });
  for (const locale of input.marketConfig.fallbackLocaleOrder)
    candidates.push({ locale, kind: 'market_fallback' });
  candidates.push({ locale: input.text.defaultLocale, kind: 'default' });
  const seen = new Set<LocaleId>();
  for (const candidate of candidates) {
    if (seen.has(candidate.locale)) continue;
    seen.add(candidate.locale);
    const value = input.text.values[candidate.locale];
    if (value !== undefined)
      return success(value, requestedLocale, candidate.locale, candidate.kind, supported);
  }
  return {
    ok: false,
    code: supported ? 'translation_missing' : 'unsupported_locale',
    requestedLocale,
  };
}

function success(
  text: string,
  requestedLocale: LocaleId,
  resolvedLocale: LocaleId,
  resolutionKind: 'exact' | 'language_fallback' | 'market_fallback' | 'default',
  requestedLocaleSupported: boolean,
): Extract<LocalizedTextResolution, { readonly ok: true }> {
  return {
    ok: true,
    text,
    requestedLocale,
    resolvedLocale,
    resolutionKind,
    requestedLocaleSupported,
  };
}
