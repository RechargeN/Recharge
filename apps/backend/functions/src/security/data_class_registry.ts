import { deepFreeze, type DeepReadonly } from '../shared/immutable.js';

export type DataClassification = 'public' | 'internal' | 'personal' | 'sensitive' | 'restricted';

export interface DataClassDefinition {
  readonly dataClassId: string;
  readonly classification: DataClassification;
  readonly containsDirectIdentifiers: boolean;
  readonly containsSecrets: false;
  readonly exportEligible: boolean;
  readonly deletionEligible: boolean;
  readonly retentionPolicyId: string;
}

export class DataClassRegistry {
  readonly #entries: ReadonlyMap<string, DeepReadonly<DataClassDefinition>>;

  constructor(entries: readonly DataClassDefinition[]) {
    if (entries.length < 1 || entries.length > 128)
      throw new TypeError('data_class_registry_size_invalid');
    const map = new Map<string, DeepReadonly<DataClassDefinition>>();
    for (const entry of entries) {
      if (
        !/^[a-z][a-z0-9._-]{0,95}$/.test(entry.dataClassId) ||
        !/^[a-z][a-z0-9._-]{0,95}$/.test(entry.retentionPolicyId) ||
        map.has(entry.dataClassId) ||
        entry.containsSecrets !== false
      ) {
        throw new TypeError('data_class_definition_invalid');
      }
      map.set(entry.dataClassId, deepFreeze({ ...entry }));
    }
    this.#entries = map;
  }

  get(dataClassId: string): DeepReadonly<DataClassDefinition> | null {
    return this.#entries.get(dataClassId) ?? null;
  }

  list(): readonly DeepReadonly<DataClassDefinition>[] {
    return Object.freeze([...this.#entries.values()]);
  }
}
