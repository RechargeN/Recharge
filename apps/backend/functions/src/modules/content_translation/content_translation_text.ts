import type { TranslatedField, TranslationFields } from './content_translation_contract.js';

const emailPattern = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/gu;
const phonePattern = /\+?\d[\d\s().-]{5,}\d/gu;
const tokenPattern = /⟦\d+⟧/gu;
const minPhoneDigits = 7;

export interface RedactedFields {
  readonly fields: TranslationFields;
  /** Token → original contact, per field. Kept in memory only. */
  readonly tokens: Readonly<Partial<Record<TranslatedField, ReadonlyMap<string, string>>>>;
}

/** Emails and phone numbers never reach a provider; tokens are restored in the answer. */
export function redactContacts(source: TranslationFields): RedactedFields {
  const fields: TranslationFields = {};
  const tokens: Partial<Record<TranslatedField, Map<string, string>>> = {};
  let next = 1;
  for (const field of Object.keys(source) as TranslatedField[]) {
    const own = new Map<string, string>();
    const replace = (match: string): string => {
      if (match.replace(/\D/gu, '').length < minPhoneDigits && !match.includes('@')) return match;
      const token = '⟦' + String(next++) + '⟧';
      own.set(token, match);
      return token;
    };
    fields[field] = source[field]!.replace(emailPattern, replace).replace(phonePattern, replace);
    tokens[field] = own;
  }
  return { fields, tokens };
}

const markupPatterns: readonly RegExp[] = [
  /<\/?[A-Za-z!][^>]*>/u,
  /\[[^\]]*\]\([^)]*\)/u,
  /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/u,
];

/**
 * Provider output is untrusted (ADR 0022): exact field set, plain text, bounded
 * length and every token exactly once. Returns the restored fields or null.
 */
export function acceptProviderOutput(
  redacted: RedactedFields,
  output: unknown,
): TranslationFields | null {
  if (typeof output !== 'object' || output === null || Array.isArray(output)) return null;
  const answer = output as Record<string, unknown>;
  const expected = Object.keys(redacted.fields) as TranslatedField[];
  if (Object.keys(answer).length !== expected.length) return null;
  const restored: TranslationFields = {};
  for (const field of expected) {
    const value = answer[field];
    const source = redacted.fields[field]!;
    if (
      typeof value !== 'string' ||
      value.trim().length === 0 ||
      value.length > Math.max(200, source.length * 4) ||
      markupPatterns.some((pattern) => pattern.test(value))
    )
      return null;
    const own = redacted.tokens[field] ?? new Map<string, string>();
    const seen = [...value.matchAll(tokenPattern)].map((match) => match[0]).sort();
    if (seen.join() !== [...own.keys()].sort().join()) return null;
    restored[field] = value.replace(tokenPattern, (token) => own.get(token)!);
  }
  return restored;
}

export function characterCount(fields: TranslationFields): number {
  return Object.values(fields).reduce((sum, value) => sum + value.length, 0);
}
