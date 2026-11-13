import type { Firestore } from 'firebase-admin/firestore';

import { handleDiscoverQueryRequest } from './modules/catalog/application/discover_query_handler.js';
import { createEmulatorCatalogComposition } from './modules/catalog/infrastructure/emulator_catalog_composition.js';

/** The verified Session behind a Discover read; the query itself is not per user. */
export interface DiscoverCaller {
  readonly firestore: Firestore;
  readonly userId?: string;
  /** D3.7: the local `catalog.findPeople` flag (default off). */
  readonly findPeopleEnabled?: boolean;
}

function stripTransport(data: unknown): unknown {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) return data;
  const { sessionContext, ...rest } = data as Record<string, unknown>;
  void sessionContext;
  return rest;
}

/**
 * E2 Emulator-only Discover read: Feed, Search, Map and Details over the local
 * Catalog (E1) query service. Read-only; delivery is the Content effect trigger.
 */
export function handleDiscoverQuery(
  caller: DiscoverCaller,
  data: unknown,
): Promise<Readonly<Record<string, unknown>>> {
  const catalog = createEmulatorCatalogComposition(caller.firestore, {
    ...(caller.userId ? { viewerId: caller.userId } : {}),
    findPeopleEnabled: caller.findPeopleEnabled === true,
  });
  return handleDiscoverQueryRequest(catalog.query, stripTransport(data));
}
