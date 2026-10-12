import type { TaxonomyRead } from '../../../reference_data/domain/taxonomy_dataset.js';
import type {
  ContentReferenceRevisionsV1,
  ContentTypeId,
} from '../../../../contracts/content_v1.js';
import type { MarketId } from '../../../reference_data/domain/identifiers.js';
import type { ReferenceLookups } from '../../domain/type_rules/validation_context.js';

export type ReferenceResolution =
  | {
      readonly ok: true;
      readonly revisions: ContentReferenceRevisionsV1;
      /** Market currency/timezone taken from the pinned MarketConfig. */
      readonly market: { readonly currencyCode: string; readonly timezoneId: string };
      /** Lookups answered by the pinned BCK-20 revisions; `undefined` fails closed. */
      readonly lookups: ReferenceLookups;
    }
  | { readonly ok: false; readonly code: 'market_disabled' | 'policy_unavailable' };

/** BCK-20 MarketConfig/taxonomy/localization revisions pinned at command time. */
export interface ReferenceDataPort {
  /** Additive exact-revision capability: absence is explicitly unavailable to consumers. */
  readTaxonomyRevision?(input: { readonly taxonomyRevisionId: string }): Promise<TaxonomyRead>;
  resolve(input: {
    readonly marketId: MarketId;
    readonly typeId: ContentTypeId;
    readonly nowUtc: string;
  }): Promise<ReferenceResolution>;
}
