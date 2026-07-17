# ADR 0014: Time-Fit Ranking

- Status: Accepted
- Date: 2026-07-17
- Deciders: Recharge team, product owner
- Related: [ADR 0013](0013-domain-policy-baseline.md),
  [Search / Filters / Time-Fit Specification](../product/SEARCH_FILTERS_TIME_SPEC.md)

## Context

ADR 0013 defines `geo + freshness` as the MVP ranking baseline. The accepted
Search specification adds a time-window fit evaluation, but intentionally does
not choose its ranking weight. A fixed decision and a release-independent kill
switch are required before time-fit can affect ordering.

## Decision

1. When a query has no `timeWindow`, ranking remains exactly the ADR 0013
   `geoFreshness` baseline.
2. When a query has a `timeWindow`, hard eligibility rules run before ranking:
   `doesNotFit` is excluded, while `unknown` is kept in a separate unconfirmed
   group and receives no time-fit boost.
3. Eligible confirmed results use:

   ```text
   finalScore =
     (1 - timeFitWeight) * baseScore +
     timeFitWeight * normalizedTimeFitScore
   ```

4. `baseScore` and `normalizedTimeFitScore` are normalized to `[0, 1]`.
5. The default `timeFitWeight` is **0.20**. Configuration must clamp it to
   `[0, 0.30]`; values outside that range are invalid configuration and fall
   back to `0`.
6. A time-fit ranking feature flag is mandatory. When disabled, the effective
   weight is `0`; filtering, grouping and explanatory badges remain active.
7. `unknown` evaluations use a normalized score of `0` and cannot outrank a
   confirmed result through time-fit. Group ordering remains confirmed first,
   unknown second.
8. Zero-result relaxation is suggestion-only. The system never changes the
   query without user confirmation.

## Rollout And Rollback

- Roll out with the flag disabled by default outside development until metrics
  for unknown rate, exclusions and zero-result rate are available.
- Enable gradually by market/configuration.
- Roll back without an app release by disabling the flag or setting the weight
  to `0`.
- Log the configured and effective weights with the evaluation version.

## Consequences

- Time relevance can influence ordering without replacing the established geo
  and freshness baseline.
- Queries without a time window remain backward compatible.
- The maximum weight limits ranking instability while product metrics are still
  based on mock data.
- The application needs explicit configuration, telemetry and tests for both
  enabled and disabled states.

## Supersession

This ADR narrows ADR 0013 policy 11 only for queries with a `timeWindow`.
All other search-ranking policy in ADR 0013 remains in force.
