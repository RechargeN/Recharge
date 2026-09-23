import type { EntityId, IdempotencyKey } from '../shared/ids.js';
import type { IanaTimezone, UtcInstant } from '../shared/utc_instant.js';

declare const currencyBrand: unique symbol;
declare const semanticHashBrand: unique symbol;
declare const cursorBrand: unique symbol;

export type IsoCurrencyCode = string & { readonly [currencyBrand]: 'IsoCurrencyCode' };
export type SemanticPayloadHash = string & {
  readonly [semanticHashBrand]: 'SemanticPayloadHash';
};
export type OpaqueCursor = string & { readonly [cursorBrand]: 'OpaqueCursor' };

export type JsonPrimitive = string | number | boolean | null;
export type JsonValue = JsonPrimitive | readonly JsonValue[] | JsonObject;
export interface JsonObject {
  readonly [key: string]: JsonValue;
}

export interface Money {
  readonly minorUnits: number;
  readonly currency: IsoCurrencyCode;
}

export type ClientPlatform = 'android' | 'ios' | 'web';

export interface ClientContext {
  readonly appId: string;
  readonly platform: ClientPlatform;
  readonly appVersion: string;
  readonly buildNumber: number;
}

export interface RequestContext<Payload extends JsonObject = JsonObject> {
  readonly contractVersion: 1;
  readonly requestId: EntityId;
  readonly client: ClientContext;
  readonly locale: string;
  readonly marketId?: string;
  readonly payload: Payload;
}

export interface CommandEnvelope<
  Payload extends JsonObject = JsonObject,
> extends RequestContext<Payload> {
  readonly commandType: string;
  readonly commandVersion: number;
  readonly idempotencyKey: IdempotencyKey;
  readonly expectedRevision?: number;
}

export interface PageRequest {
  readonly limit: number;
  readonly cursor: OpaqueCursor | null;
}

export interface QueryEnvelope<Filters extends JsonObject = JsonObject> {
  readonly contractVersion: 1;
  readonly queryType: string;
  readonly queryVersion: number;
  readonly requestId: EntityId;
  readonly client: ClientContext;
  readonly locale: string;
  readonly marketId?: string;
  readonly filters: Filters;
  readonly sort: string;
  readonly page: PageRequest;
}

export type ApiErrorCode =
  | 'invalid_argument'
  | 'unauthenticated'
  | 'permission_denied'
  | 'not_found'
  | 'conflict'
  | 'idempotency_conflict'
  | 'failed_precondition'
  | 'rate_limited'
  | 'unavailable'
  | 'deadline_exceeded'
  | 'unsupported_client'
  | 'unsupported_contract'
  | 'unsupported_schema'
  | 'stale_revision'
  | 'internal';

export interface FieldViolation {
  readonly field: string;
  readonly code: string;
}

export interface ApiError {
  readonly code: ApiErrorCode;
  readonly domainCode?: string;
  readonly messageKey?: string;
  readonly retryable: boolean;
  readonly retryAfterSeconds?: number;
  readonly fieldViolations: readonly FieldViolation[];
  readonly details: JsonObject;
}

export interface MinimumClientPolicy {
  readonly policyRevision: number;
  readonly platform: ClientPlatform;
  readonly minSupportedBuild: number;
  readonly recommendedBuild: number;
  readonly supportedContractMajors: readonly number[];
  readonly hardBlockReasonCode?: string;
  readonly sunsetAt?: UtcInstant;
  readonly updateTargetRef?: string;
  readonly effectiveAt: UtcInstant;
}

interface ResultBase {
  readonly contractVersion: 1;
  readonly requestId: EntityId;
  readonly correlationId: EntityId;
  readonly serverTime: UtcInstant;
  readonly resourceRevision?: number;
  readonly clientPolicy?: MinimumClientPolicy;
}

export interface SuccessResult<Result extends JsonObject = JsonObject> extends ResultBase {
  readonly outcome: 'success';
  readonly result: Result;
}

export interface FailureResult extends ResultBase {
  readonly outcome: 'failure';
  readonly error: ApiError;
}

export interface CancelledResult extends ResultBase {
  readonly outcome: 'cancelled';
  readonly cancelReasonCode: string;
}

export type UnknownOutcomeReason =
  'transportTimeout' | 'connectionLost' | 'clientCancelledAfterSend' | 'responseLost';

export interface UnknownResult extends ResultBase {
  readonly outcome: 'unknown';
  readonly unknownReason: UnknownOutcomeReason;
  readonly reconciliation: Readonly<{
    idempotencyKey: IdempotencyKey;
    semanticPayloadHash: SemanticPayloadHash;
    statusQuerySupported: boolean;
  }>;
}

export type ResultEnvelope<Result extends JsonObject = JsonObject> =
  SuccessResult<Result> | FailureResult | CancelledResult | UnknownResult;

export interface CursorPage<Item extends JsonObject = JsonObject> {
  readonly contractVersion: 1;
  readonly requestId: EntityId;
  readonly items: readonly Item[];
  readonly nextCursor: OpaqueCursor | null;
  readonly sourceRevision?: number;
  readonly projectionRevision?: number;
  readonly queryRevision: EntityId;
  readonly freshness: 'fresh' | 'stale' | 'unknown';
  readonly fetchedAt: UtcInstant;
  readonly freshUntilUtc?: UtcInstant;
}

export type DataClass = 'public' | 'protected' | 'sensitive' | 'operational' | 'derived';

export interface EventEnvelope<Payload extends JsonObject = JsonObject> {
  readonly eventId: EntityId;
  readonly eventType: string;
  readonly eventVersion: number;
  readonly producer: string;
  readonly aggregateType: string;
  readonly aggregateId: EntityId;
  readonly aggregateRevision: number;
  readonly occurredAt: UtcInstant;
  readonly correlationId: EntityId;
  readonly causationId?: EntityId;
  readonly marketId?: string;
  readonly dataClass: DataClass;
  readonly payload: Payload;
}

export type AsyncOperationState = 'accepted' | 'running' | 'succeeded' | 'failed' | 'cancelled';

export interface AsyncOperation {
  readonly operationId: EntityId;
  readonly operationType: string;
  readonly state: AsyncOperationState;
  readonly submittedAt: UtcInstant;
  readonly updatedAt: UtcInstant;
  readonly resultRef?: EntityId;
  readonly error?: ApiError;
  readonly revision: number;
}

export interface SemanticCommandInput<Payload extends JsonObject = JsonObject> {
  readonly actorScope: string;
  readonly commandType: string;
  readonly commandVersion: number;
  readonly payload: Payload;
}

export type IdempotencyDecision =
  | Readonly<{ kind: 'execute'; semanticPayloadHash: SemanticPayloadHash }>
  | Readonly<{ kind: 'replay'; semanticPayloadHash: SemanticPayloadHash; result: JsonValue }>
  | Readonly<{ kind: 'inProgress'; semanticPayloadHash: SemanticPayloadHash }>
  | Readonly<{
      kind: 'reject';
      code: 'idempotency_conflict';
      semanticPayloadHash: SemanticPayloadHash;
    }>;

export type ClientCompatibilityDecision =
  | Readonly<{ kind: 'supported'; updateRecommended: boolean }>
  | Readonly<{ kind: 'rejected'; code: 'unsupported_client' | 'unsupported_contract' }>;

export type PlatformTimezone = IanaTimezone;
