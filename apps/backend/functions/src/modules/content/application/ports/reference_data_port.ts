import type {
  ContentReferenceRevisionsV1,
  ContentTypeId,
} from '../../../../contracts/content_v1.js';
import type { MarketId } from '../../../reference_data/domain/identifiers.js';

export type ReferenceResolution =
  | { readonly ok: true; readonly revisions: ContentReferenceRevisionsV1 }
  | { readonly ok: false; readonly code: 'market_disabled' | 'policy_unavailable' };

/** BCK-20 MarketConfig/taxonomy/localization revisions pinned at command time. */
export interface ReferenceDataPort {
  resolve(input: {
    readonly marketId: MarketId;
    readonly typeId: ContentTypeId;
    readonly nowUtc: string;
  }): Promise<ReferenceResolution>;
}
