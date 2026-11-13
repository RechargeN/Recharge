export interface RateLimitRequest {
  readonly bucket: string;
  readonly subjectHash: string;
  readonly cost: number;
}

export type RateLimitDecision =
  | { readonly allowed: true; readonly remaining: number }
  | { readonly allowed: false; readonly retryAfterSeconds: number };

export interface RateLimitPort {
  decide(request: RateLimitRequest): Promise<RateLimitDecision>;
}

export class LocalDenyRateLimitPort implements RateLimitPort {
  decide(request: RateLimitRequest): Promise<RateLimitDecision> {
    if (
      !/^[a-z][a-z0-9._-]{0,63}$/.test(request.bucket) ||
      !/^[0-9a-f]{64}$/.test(request.subjectHash)
    ) {
      throw new TypeError('rate_limit_request_invalid');
    }
    if (!Number.isSafeInteger(request.cost) || request.cost < 1 || request.cost > 100) {
      throw new TypeError('rate_limit_cost_invalid');
    }
    return Promise.resolve({ allowed: false, retryAfterSeconds: 60 });
  }
}
