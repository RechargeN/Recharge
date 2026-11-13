import type { TranslationFields } from './content_translation_contract.js';

export interface TranslationProviderRequest {
  readonly sourceLocale: string;
  readonly targetLocale: string;
  readonly fields: TranslationFields;
}

/** Backend-only provider port; a real adapter needs the stage 2 decision. */
export interface TranslationProvider {
  readonly providerRef: string;
  readonly engineRevision: string;
  /** Integer minor units of `currency` per million source characters. */
  readonly rateMinorPerMillionChars: number;
  readonly currency: string;
  translate(request: TranslationProviderRequest): Promise<unknown>;
}

/** Stage 1 adapter: no network, keys or spend; its rate only exercises the budget path. */
export class MockTranslationProvider implements TranslationProvider {
  readonly providerRef = 'mock-local';
  readonly engineRevision = 'mock-1';
  readonly rateMinorPerMillionChars = 1000;
  readonly currency = 'EUR';

  translate(request: TranslationProviderRequest): Promise<unknown> {
    const output: Record<string, string> = {};
    for (const [field, value] of Object.entries(request.fields))
      output[field] = '[' + request.sourceLocale + '→' + request.targetLocale + '] ' + value;
    return Promise.resolve(output);
  }
}
