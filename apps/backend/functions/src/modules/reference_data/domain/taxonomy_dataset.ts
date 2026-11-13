export interface TaxonomyDataset {
  readonly schemaVersion: 1;
  readonly taxonomyId: string;
  readonly sourceDocumentSha256: string;
  readonly categories: readonly {
    readonly id: string;
    readonly subcategories: readonly {
      readonly id: string;
      readonly profileId: string;
      readonly applicableTypes: readonly string[];
    }[];
  }[];
  readonly profiles: readonly {
    readonly id: string;
    readonly fieldIds: readonly string[];
    readonly requiredFieldIds: readonly string[];
  }[];
}
export type TaxonomyRead =
  | {
      readonly ok: true;
      readonly revisionId: string;
      readonly artifactSha256: string;
      readonly dataset: TaxonomyDataset;
    }
  | {
      readonly ok: false;
      readonly code:
        'taxonomy_revision_unknown' | 'taxonomy_revision_unavailable' | 'taxonomy_integrity_failed';
    };
