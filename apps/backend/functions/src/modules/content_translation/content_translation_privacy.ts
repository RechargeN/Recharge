import type { PrivacyApplier } from '../privacy_orchestration/infrastructure/firestore_privacy_subject_sweep.js';
import { contentTranslationCollections as cols } from './content_translation_contract.js';

/** L1: the module's own delete of the account's daily counter, inside the sweep page. */
export const contentTranslationPrivacyAppliers: Readonly<Record<string, PrivacyApplier>> = {
  [cols.accountUsage]: {
    inTransaction: (tx, ref) => Promise.resolve({ outcome: 'erased', write: () => tx.delete(ref) }),
  },
};
