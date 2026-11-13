import { environmentIds, type EnvironmentId } from '../../../config/environment.js';

declare const localeIdBrand: unique symbol;
declare const currencyCodeBrand: unique symbol;

export const marketIds = ['LV', 'EE', 'LT'] as const;
export type MarketId = (typeof marketIds)[number];
export type LocaleId = string & { readonly [localeIdBrand]: 'LocaleId' };
export type CurrencyCode = string & { readonly [currencyCodeBrand]: 'CurrencyCode' };
export type ReferenceEnvironmentId = EnvironmentId;

const supportedCurrencies = new Set(Intl.supportedValuesOf('currency'));

export function parseMarketId(value: unknown): MarketId {
  if (typeof value !== 'string' || !marketIds.includes(value as MarketId)) {
    throw new TypeError('reference_data_market_unknown');
  }
  return value as MarketId;
}

export function parseReferenceEnvironmentId(value: unknown): ReferenceEnvironmentId {
  if (typeof value !== 'string' || !environmentIds.includes(value as EnvironmentId)) {
    throw new TypeError('reference_data_environment_unknown');
  }
  return value as EnvironmentId;
}

export function parseLocaleId(value: unknown): LocaleId {
  if (typeof value !== 'string' || value.length < 2 || value.length > 35) {
    throw new TypeError('reference_data_locale_invalid');
  }
  let canonical: string;
  try {
    canonical = Intl.getCanonicalLocales(value)[0] ?? '';
  } catch {
    throw new TypeError('reference_data_locale_invalid');
  }
  if (canonical !== value) throw new TypeError('reference_data_locale_not_canonical');
  return value as LocaleId;
}

export function parseCurrencyCode(value: unknown): CurrencyCode {
  if (typeof value !== 'string' || !/^[A-Z]{3}$/.test(value) || !supportedCurrencies.has(value)) {
    throw new TypeError('reference_data_currency_invalid');
  }
  return value as CurrencyCode;
}

export function localeLanguage(locale: LocaleId): string {
  return new Intl.Locale(locale).language;
}
