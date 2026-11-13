import { deepFreeze, type DeepReadonly } from '../../shared/immutable.js';

export const metricNames = [
  'platform_config_resolution_total',
  'platform_pointer_swap_total',
  'platform_release_rollback_total',
  'platform_authorization_denied_total',
] as const;
export type MetricName = (typeof metricNames)[number];

export type MetricDimensions = Readonly<{
  environment: 'local' | 'dev' | 'stage' | 'prod';
  market: 'LV' | 'EE' | 'LT' | 'none';
  outcome: 'success' | 'failure' | 'denied';
}>;

export interface MetricRecord {
  readonly name: MetricName;
  readonly value: number;
  readonly dimensions: MetricDimensions;
}

export interface MetricsPort {
  record(metric: MetricRecord): void;
}

export class InMemoryMetricsPort implements MetricsPort {
  readonly records: DeepReadonly<MetricRecord>[] = [];

  record(metric: MetricRecord): void {
    if (!metricNames.includes(metric.name) || !Number.isFinite(metric.value) || metric.value < 0) {
      throw new TypeError('metric_invalid');
    }
    this.records.push(deepFreeze({ ...metric, dimensions: { ...metric.dimensions } }));
  }
}
