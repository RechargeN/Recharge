import type {
  CatalogQueryFailure,
  CatalogQueryService,
  DetailsResult,
  FeedPage,
  MapResult,
} from './catalog_query_service.js';

/**
 * Transport-agnostic `discoverQuery` v1 envelope over the local Catalog query
 * service (E2). Read-only: it never projects, delivers or writes. A malformed
 * envelope is a typed refusal; nothing is mapped to a default query.
 *
 * ```text
 * { schemaVersion: 1, requestId, queryType: 'feed' | 'search' | 'map' | 'details',
 *   payload: feed/search { query, snapshotToken?, cursor? }
 *            map         { query, snapshotToken?, viewport? }
 *            details     { contentId, snapshotToken?, query? } }
 * ```
 */
export type DiscoverQueryType = 'feed' | 'search' | 'map' | 'details';

export type DiscoverWireResult = Readonly<Record<string, unknown>>;

type MapViewport = NonNullable<Parameters<CatalogQueryService['map']>[0]['viewport']>;

const queryTypes = new Set<string>(['feed', 'search', 'map', 'details']);
const payloadKeys: Readonly<Record<DiscoverQueryType, ReadonlySet<string>>> = {
  feed: new Set(['query', 'snapshotToken', 'cursor']),
  search: new Set(['query', 'snapshotToken', 'cursor']),
  map: new Set(['query', 'snapshotToken', 'viewport']),
  details: new Set(['contentId', 'snapshotToken', 'query']),
};
const requestIdPattern = /^[A-Za-z0-9_.:-]{1,128}$/u;
const contentIdPattern = /^[A-Za-z0-9_-]{1,128}$/u;
const maxTokenLength = 4096;

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function optionalToken(value: unknown): value is string | undefined {
  return (
    value === undefined ||
    (typeof value === 'string' && value.length > 0 && value.length <= maxTokenLength)
  );
}

function refusal(
  queryType: string | null,
  requestId: string | null,
  kind: 'rejected' | 'unsupported',
  code: string,
): DiscoverWireResult {
  return {
    schemaVersion: 1,
    ...(queryType === null ? {} : { queryType }),
    ...(requestId === null ? {} : { requestId }),
    kind,
    code,
  };
}

function failure(
  queryType: DiscoverQueryType,
  requestId: string,
  result: CatalogQueryFailure,
): DiscoverWireResult {
  return { schemaVersion: 1, queryType, requestId, kind: result.kind, code: result.code };
}

function feedPage(page: FeedPage): Readonly<Record<string, unknown>> {
  return {
    snapshotToken: page.snapshotToken,
    projectionSetId: page.snapshot.projectionSetId,
    projectionSetRevision: page.snapshot.projectionSetRevision,
    freshness: page.freshness,
    items: page.items,
    nextCursor: page.nextCursor,
    totalEligible: page.totalEligible,
  };
}

function mapPage(result: MapResult): Readonly<Record<string, unknown>> {
  return {
    snapshotToken: result.snapshotToken,
    projectionSetId: result.snapshot.projectionSetId,
    projectionSetRevision: result.snapshot.projectionSetRevision,
    freshness: result.freshness,
    leaves: result.leaves,
    notMappable: result.notMappable,
    totalEligible: result.totalEligible,
  };
}

function detailsBody(result: DetailsResult): Readonly<Record<string, unknown>> {
  // An excluded or absent object carries no item: hidden content never leaks.
  return {
    state: result.state,
    reason: result.reason,
    item: result.state === 'listed' ? result.item : null,
    changedSinceSnapshot: result.changedSinceSnapshot,
  };
}

export async function handleDiscoverQueryRequest(
  service: CatalogQueryService,
  raw: unknown,
): Promise<DiscoverWireResult> {
  const request = record(raw);
  if (request === null) return refusal(null, null, 'rejected', 'invalid_request');
  for (const key of Object.keys(request))
    if (!['schemaVersion', 'requestId', 'queryType', 'payload'].includes(key))
      return refusal(null, null, 'unsupported', `unknown_field:${key}`);
  const requestId =
    typeof request.requestId === 'string' && requestIdPattern.test(request.requestId)
      ? request.requestId
      : null;
  const rawType = typeof request.queryType === 'string' ? request.queryType : null;
  if (requestId === null) return refusal(rawType, null, 'rejected', 'request_id_invalid');
  if (request.schemaVersion !== 1)
    return refusal(rawType, requestId, 'unsupported', 'unsupported_version');
  if (rawType === null || !queryTypes.has(rawType))
    return refusal(rawType, requestId, 'unsupported', 'query_type_unsupported');
  const queryType = rawType as DiscoverQueryType;
  const payload = record(request.payload);
  if (payload === null) return refusal(queryType, requestId, 'rejected', 'payload_invalid');
  for (const key of Object.keys(payload))
    if (!payloadKeys[queryType].has(key))
      return refusal(queryType, requestId, 'unsupported', `unknown_field:${key}`);
  if (!optionalToken(payload.snapshotToken))
    return refusal(queryType, requestId, 'rejected', 'snapshot_token_invalid');

  const ok = (body: Readonly<Record<string, unknown>>): DiscoverWireResult => ({
    schemaVersion: 1,
    queryType,
    requestId,
    kind: 'succeeded',
    ...body,
  });
  const snapshotToken = payload.snapshotToken;

  if (queryType === 'details') {
    if (typeof payload.contentId !== 'string' || !contentIdPattern.test(payload.contentId))
      return refusal(queryType, requestId, 'rejected', 'content_id_invalid');
    if ((snapshotToken === undefined) !== (payload.query === undefined))
      return refusal(queryType, requestId, 'rejected', 'snapshot_requires_query');
    const result = await service.details({
      contentId: payload.contentId,
      ...(snapshotToken === undefined ? {} : { snapshotToken, query: payload.query }),
    });
    return 'code' in result
      ? failure(queryType, requestId, result)
      : ok({ details: detailsBody(result) });
  }

  if (payload.query === undefined)
    return refusal(queryType, requestId, 'rejected', 'query_required');
  if (queryType === 'map') {
    const viewport = payload.viewport;
    if (viewport !== undefined && record(viewport) === null)
      return refusal(queryType, requestId, 'rejected', 'viewport_invalid');
    const result = await service.map({
      query: payload.query,
      ...(snapshotToken === undefined ? {} : { snapshotToken }),
      ...(viewport === undefined ? {} : { viewport: viewport as MapViewport }),
    });
    return 'code' in result ? failure(queryType, requestId, result) : ok({ map: mapPage(result) });
  }

  if (!optionalToken(payload.cursor))
    return refusal(queryType, requestId, 'rejected', 'cursor_invalid');
  const pageRequest = {
    query: payload.query,
    ...(snapshotToken === undefined ? {} : { snapshotToken }),
    ...(payload.cursor === undefined ? {} : { cursor: payload.cursor }),
  };
  const result =
    queryType === 'search' ? await service.search(pageRequest) : await service.feed(pageRequest);
  return 'code' in result ? failure(queryType, requestId, result) : ok({ page: feedPage(result) });
}
