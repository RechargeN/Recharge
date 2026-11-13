import assert from 'node:assert/strict';
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';

import {
  productAnalyticsEventRegistry,
  productAnalyticsSinkRegistry,
} from '../../../src/modules/product_analytics/product_analytics_contract.js';
import { privacyWriterRegistry } from '../../../src/modules/privacy_orchestration/domain/privacy_writer_registry.js';

/**
 * L3-T-INV (amendment §2, §12 п.11): a product analytics producer, sink or SDK
 * that is not registered with purpose, schema and policy fails this test. The
 * scans read the backend sources and both dependency manifests; the positive
 * controls feed synthetic sources and prove each scan can fail.
 */
const repoRoot = path.resolve(process.cwd(), '../../..');
const moduleDir = 'modules/product_analytics/';
/** Backend files allowed to import the analytics module; none outside it yet. */
const registeredBackendProducers: readonly string[] = [];
/** Operational telemetry and security audit never exchange payload with L3. */
const separatedFiles = [
  'platform/observability/structured_logger.ts',
  'platform/observability/metrics.ts',
  'security/security_audit_port.ts',
];
const analyticsSdk =
  /(^|[/@"'])(firebase_analytics|firebase-analytics|@firebase\/analytics|@google-analytics|googleapis\/analytics|analytics-node|@segment|segment_analytics|amplitude|mixpanel|posthog|appsflyer|adjust_sdk|branch_sdk|sentry|crashlytics|@datadog|newrelic|bigquery)/iu;

function sourceFiles(root: string, base = root): Map<string, string> {
  const files = new Map<string, string>();
  for (const entry of readdirSync(root)) {
    const absolute = path.join(root, entry);
    if (statSync(absolute).isDirectory())
      for (const [name, text] of sourceFiles(absolute, base)) files.set(name, text);
    else if (entry.endsWith('.ts'))
      files.set(
        path.relative(base, absolute).replaceAll('\\', '/'),
        readFileSync(absolute, 'utf8'),
      );
  }
  return files;
}

function dependencyNames(manifests: readonly string[]): string[] {
  return manifests.flatMap((text) => {
    if (text.trimStart().startsWith('{')) {
      const json = JSON.parse(text) as Record<string, Record<string, string> | undefined>;
      return [...Object.keys(json.dependencies ?? {}), ...Object.keys(json.devDependencies ?? {})];
    }
    return [...text.matchAll(/^\s{2}([a-z_][a-z0-9_]*):/gmu)].map((match) => match[1]!);
  });
}

/** Every gap of the inventory; an empty list means each producer and sink is registered. */
function inventoryGaps(input: {
  readonly sources: ReadonlyMap<string, string>;
  readonly manifests: readonly string[];
  readonly sinks?: readonly string[];
  readonly producers?: readonly string[];
}): string[] {
  const sinks = new Set(input.sinks ?? productAnalyticsSinkRegistry.map((sink) => sink.collection));
  const producers = new Set(input.producers ?? registeredBackendProducers);
  const gaps: string[] = [];
  for (const [file, text] of input.sources) {
    for (const match of text.matchAll(/'(productAnalytics[A-Z][A-Za-z0-9]*)'/gu))
      if (!sinks.has(match[1]!)) gaps.push(`sink_unregistered:${match[1]!}`);
    const importsModule = /from '[^']*product_analytics\//u.test(text);
    if (!file.startsWith(moduleDir) && importsModule && !producers.has(file))
      gaps.push(`producer_unregistered:${file}`);
    if (file.startsWith(moduleDir)) {
      if (/\bconsole\.|structured_logger|observability\/metrics|security_audit_port/u.test(text))
        gaps.push(`telemetry_mixed:${file}`);
      if (/\bfetch\(|node:https?|node:net|http\.request/u.test(text))
        gaps.push(`network_path:${file}`);
    }
    if (separatedFiles.includes(file) && importsModule) gaps.push(`telemetry_mixed:${file}`);
  }
  for (const name of dependencyNames(input.manifests))
    if (analyticsSdk.test(name)) gaps.push(`sdk_unregistered:${name}`);
  return [...new Set(gaps)].sort();
}

const src = sourceFiles(path.resolve(process.cwd(), 'src'));
const manifests = [
  readFileSync(path.resolve(process.cwd(), 'package.json'), 'utf8'),
  readFileSync(path.join(repoRoot, 'apps/mobile/pubspec.yaml'), 'utf8'),
];

void test('L3-T-INV: every analytics sink, producer and dependency is registered', () => {
  // The scans must see the real module and manifests, or an empty scan would pass.
  assert.ok([...src.keys()].some((file) => file.startsWith(moduleDir)));
  assert.ok(dependencyNames(manifests).includes('firebase-admin'));
  assert.ok(dependencyNames(manifests).includes('firebase_auth'));
  assert.deepEqual(inventoryGaps({ sources: src, manifests }), []);
  // Each sink is in the L1 writer registry with a DSR rule.
  const registered = new Set(privacyWriterRegistry.map((entry) => entry.collection));
  for (const sink of productAnalyticsSinkRegistry) assert.ok(registered.has(sink.collection));
  // Each event names an existing producer file on the client.
  for (const definition of productAnalyticsEventRegistry)
    assert.ok(existsSync(path.join(repoRoot, definition.producer)), definition.producer);
});

void test('L3-T-INV positive controls: an unregistered sink, producer, SDK or mixed telemetry fails', () => {
  const synthetic = new Map([
    ['modules/booking/new_counter.ts', "db.collection('productAnalyticsShadowCounts');"],
    [
      'modules/library/library_tracker.ts',
      "import { x } from '../product_analytics/product_analytics_contract.js';",
    ],
    ['modules/product_analytics/debug.ts', "console.log('payload');"],
    ['modules/product_analytics/remote.ts', "await fetch('https://collector.l3synth.test');"],
    [
      'platform/observability/metrics.ts',
      "import { y } from '../../modules/product_analytics/product_analytics_contract.js';",
    ],
  ]);
  assert.deepEqual(
    inventoryGaps({
      sources: synthetic,
      manifests: [
        '{"dependencies":{"@segment/analytics-node":"1.0.0"}}',
        '  amplitude_flutter: ^4.0.0\n',
      ],
    }),
    [
      'network_path:modules/product_analytics/remote.ts',
      'producer_unregistered:modules/library/library_tracker.ts',
      'producer_unregistered:platform/observability/metrics.ts',
      'sdk_unregistered:@segment/analytics-node',
      'sdk_unregistered:amplitude_flutter',
      'sink_unregistered:productAnalyticsShadowCounts',
      'telemetry_mixed:modules/product_analytics/debug.ts',
      'telemetry_mixed:platform/observability/metrics.ts',
    ],
  );
  // Registering the producer and the sink closes exactly those gaps.
  assert.deepEqual(
    inventoryGaps({
      sources: new Map([...synthetic].slice(0, 2)),
      manifests: [],
      sinks: ['productAnalyticsShadowCounts'],
      producers: ['modules/library/library_tracker.ts'],
    }),
    [],
  );
});
