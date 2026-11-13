export type ReferenceMarketId = 'LV' | 'EE' | 'LT';
export type ReferenceEnvironmentId = 'local' | 'dev' | 'stage' | 'prod';

export interface LocalizedTextV1Contract {
  readonly schemaVersion: 1;
  readonly defaultLocale: string;
  readonly values: Readonly<Record<string, string>>;
}

export interface MarketCapabilityEntryV1Contract {
  readonly capabilityId: string;
  readonly status: 'disabled';
  readonly requiresMandatoryCopy: boolean;
  readonly mandatoryCopyPurposeId: string | null;
  readonly requiresEligibleSources: boolean;
}

export interface MarketConfigRevisionV1Contract {
  readonly schemaVersion: 1;
  readonly revisionId: string;
  readonly revisionNumber: number;
  readonly environmentId: ReferenceEnvironmentId;
  readonly marketId: ReferenceMarketId;
  readonly countryCode: ReferenceMarketId;
  readonly status: 'disabled';
  readonly primaryLocale: string;
  readonly supportedLocales: readonly string[];
  readonly fallbackLocaleOrder: readonly string[];
  readonly languageFallbacks: Readonly<Record<string, readonly string[]>>;
  readonly currencyCodes: readonly string[];
  readonly defaultIanaZone: string;
  readonly allowedIanaZones: readonly string[];
  readonly taxonomyRevisionRef: { readonly taxonomyId: string; readonly revision: string };
  readonly mandatoryCopyManifestRevision: string | null;
  readonly sourceRecordIds: readonly string[];
  readonly policyPointers: Readonly<Record<string, string | null>>;
  readonly capabilityMatrix: readonly MarketCapabilityEntryV1Contract[];
  readonly compatibilityKey: 'reference-data-v1';
  readonly contentHash: string;
  readonly supersedesRevisionId: string | null;
  readonly createdAtUtc: string;
}

export interface MandatoryCopyReferenceV1Contract {
  readonly schemaVersion: 1;
  readonly referenceId: string;
  readonly marketId: ReferenceMarketId;
  readonly capabilityId: string;
  readonly purposeId: string;
  readonly locale: string;
  readonly copyId: string;
  readonly copyRevision: number;
  readonly contentSha256: string;
  readonly approvalState: 'pending' | 'accepted' | 'rejected';
  readonly approvalEvidenceRevision: string | null;
  readonly effectiveAtUtc: string;
  readonly expiresAtUtc: string | null;
  readonly fallbackPolicy: 'forbidden';
}

export interface SourceRecordV1Contract {
  readonly schemaVersion: 1;
  readonly sourceRecordId: string;
  readonly sourceKind: 'internal' | 'external';
  readonly sourceRevision: string;
  readonly originUri: string | null;
  readonly evidenceSha256: string | null;
  readonly licenseDecision: 'pending' | 'accepted' | 'rejected';
  readonly licenseEvidenceRevision: string | null;
  readonly eligibility: 'candidate' | 'eligible' | 'rejected';
  readonly marketScope: readonly ReferenceMarketId[];
  readonly capturedAtUtc: string;
  readonly expiresAtUtc: string | null;
}

export interface ReferenceActivationPointerV1Contract {
  readonly schemaVersion: 1;
  readonly environmentId: ReferenceEnvironmentId;
  readonly marketId: ReferenceMarketId;
  readonly capabilityId: 'reference-data.bootstrap';
  readonly activeRevisionId: string;
  readonly pointerRevision: number;
}
