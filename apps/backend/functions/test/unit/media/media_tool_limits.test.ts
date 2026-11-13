import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';

import {
  admissionLimits,
  clientDeadlines,
  imageInputLimits,
  maxVariantBytes,
  processorDeadlines,
  scannerDeadlines,
  standMarker,
  standSignatureName,
} from '../../../src/modules/media/infrastructure/media_tool_limits.js';

const backend = path.resolve(process.cwd(), '..');

void test('the stand marker is the same in the service limits, media-tools and its lock', () => {
  const script = readFileSync(path.join(backend, 'scripts', 'media-tools.mjs'), 'utf8');
  assert.match(script, new RegExp(`export const standMarker = "${standMarker}";`, 'u'));
  const lock = JSON.parse(readFileSync(path.join(backend, 'media-tools.lock.json'), 'utf8')) as {
    mode: string;
    databases: { stand: { signature: string; sha256: string } | null; official: unknown };
  };
  assert.equal(lock.mode, 'L1');
  assert.equal(lock.databases.official, null, 'L1: no official database is recorded');
  const database = `${standSignatureName}:0:*:${Buffer.from(standMarker, 'ascii').toString('hex')}\n`;
  assert.equal(lock.databases.stand?.signature, standSignatureName);
  assert.equal(lock.databases.stand?.sha256, createHash('sha256').update(database).digest('hex'));
});

void test('deadlines nest: the worker ends first, then the service, then the client', () => {
  assert.ok(processorDeadlines.pipelineSeconds * 1000 < processorDeadlines.jobMs);
  assert.ok(processorDeadlines.jobMs < clientDeadlines.processMs);
  assert.ok(scannerDeadlines.totalMs <= clientDeadlines.scanMs);
  assert.ok(clientDeadlines.processMs < 30_000, 'below the Media service last-resort deadline');
});

void test('two variants in base64 fit the client answer cap; queues stay small', () => {
  assert.ok(Math.ceil((2 * maxVariantBytes * 4) / 3) + 4096 < clientDeadlines.maxResponseBytes);
  assert.equal(admissionLimits.scan.active, 2, 'equals clamd MaxThreads');
  assert.ok(admissionLimits.process.active === 1 && admissionLimits.process.waiting <= 2);
  assert.ok(imageInputLimits.maxPixels <= imageInputLimits.maxWidth * imageInputLimits.maxHeight);
});
