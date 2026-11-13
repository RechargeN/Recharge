import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import type { Firestore } from 'firebase-admin/firestore';

import { PrivacyDomainTaskRunner } from '../../../src/modules/privacy_orchestration/application/privacy_domain_task_runner.js';
import { PrivacyOrchestrationService } from '../../../src/modules/privacy_orchestration/application/privacy_orchestration_service.js';
import {
  privacyErasureDomainIds,
  privacyRegistryGaps,
  privacyWriterRegistry,
} from '../../../src/modules/privacy_orchestration/domain/privacy_writer_registry.js';
import { InMemoryPrivacyOrchestrationRepository } from '../../../src/modules/privacy_orchestration/infrastructure/in_memory_privacy_orchestration_repository.js';

/**
 * L1-T-REG: every collection the backend writes is in the writer registry and
 * every erasure domain has a handler. The scan reads the TypeScript sources:
 * collection maps, collection-name constants, literal `.collection('…')` calls,
 * the access matrix and dynamic `owner + 'Suffix'` names.
 */
function collectionsIn(sources: readonly string[]): string[] {
  const names = new Set<string>();
  for (const source of sources) {
    for (const block of source.matchAll(
      /export const \w*[Cc]ollections\w*\s*=\s*Object\.freeze\(\{([\s\S]*?)\}\)/gu,
    ))
      for (const literal of block[1]!.matchAll(/:\s*'([A-Za-z][A-Za-z0-9]*)'/gu))
        names.add(literal[1]!);
    for (const pattern of [
      /export const \w*Collection\w*\s*=\s*'([A-Za-z][A-Za-z0-9]*)'/gu,
      /\.collection\(\s*'([A-Za-z][A-Za-z0-9]*)'\s*\)/gu,
      /collectionId:\s*'([A-Za-z][A-Za-z0-9]*)'/gu,
    ])
      for (const match of source.matchAll(pattern)) names.add(match[1]!);
    for (const match of source.matchAll(/\.collection\(\s*\w+\s*\+\s*'([A-Za-z0-9]+)'\s*\)/gu))
      names.add(`*${match[1]!}`);
  }
  return [...names].sort();
}

/** A dynamic `*Suffix` name is covered by the registered collections with that suffix. */
function expand(scanned: readonly string[]): string[] {
  const registered = privacyWriterRegistry.map((entry) => entry.collection);
  return scanned.flatMap((name) => {
    if (!name.startsWith('*')) return [name];
    const matches = registered.filter((candidate) => candidate.endsWith(name.slice(1)));
    return matches.length > 0 ? matches : [name];
  });
}

function sourceFiles(root: string): string[] {
  return readdirSync(root).flatMap((entry) => {
    const absolute = path.join(root, entry);
    if (statSync(absolute).isDirectory()) return sourceFiles(absolute);
    return entry.endsWith('.ts') ? [absolute] : [];
  });
}

function handlerDomainIds(): readonly string[] {
  const repository = new InMemoryPrivacyOrchestrationRepository();
  // The constructor only composes handlers; no Firestore call is made here.
  return new PrivacyDomainTaskRunner(
    {} as Firestore,
    repository,
    new PrivacyOrchestrationService(repository, repository, repository),
  ).handlerDomainIds;
}

void test('L1-T-REG: the registry covers every written collection and every domain has a handler', () => {
  const sources = sourceFiles(path.resolve(process.cwd(), 'src')).map((file) =>
    readFileSync(file, 'utf8'),
  );
  const written = expand(collectionsIn(sources));
  // The scan itself must see the known writers, or an empty scan would pass.
  for (const known of ['bookings', 'libraryEntries', 'quickPlans', 'routes', 'contentSafetyHolds'])
    assert.ok(written.includes(known), known);
  assert.ok(written.length > 100);
  assert.deepEqual(
    privacyRegistryGaps({ writtenCollections: written, handlerDomainIds: handlerDomainIds() }),
    [],
  );
});

void test('L1-T-REG positive controls: a missing writer, handler or domain makes the check fail', () => {
  const phantom = collectionsIn([
    "const ref = db.collection('l1PhantomWriter');",
    "export const phantomCollections = Object.freeze({ items: 'l1PhantomItems' });",
    "db.collection(owner + 'PhantomHolds');",
  ]);
  assert.deepEqual(phantom, ['*PhantomHolds', 'l1PhantomItems', 'l1PhantomWriter']);
  assert.deepEqual(
    privacyRegistryGaps({
      writtenCollections: expand(phantom),
      handlerDomainIds: handlerDomainIds(),
    }),
    [
      'collection_unregistered:*PhantomHolds',
      'collection_unregistered:l1PhantomItems',
      'collection_unregistered:l1PhantomWriter',
    ],
  );
  assert.deepEqual(
    privacyRegistryGaps({
      writtenCollections: [],
      handlerDomainIds: handlerDomainIds().filter((domainId) => domainId !== 'route'),
    }),
    ['handler_missing:route'],
  );
  assert.deepEqual(
    privacyRegistryGaps({
      writtenCollections: [],
      handlerDomainIds: handlerDomainIds(),
      registry: [
        ...privacyWriterRegistry,
        {
          collection: 'l1Orphan',
          writer: 'W0',
          domainId: null,
          subjectField: 'ownerId',
          erasure: { kind: 'delete' },
        },
        {
          collection: 'l1Unknown',
          writer: 'W0',
          domainId: 'catalog',
          subjectField: 'ownerId',
          erasure: { kind: 'blocked', blocker: 'PB-02' },
        },
      ],
    }),
    ['domain_missing:l1Orphan', 'domain_unknown:catalog:l1Unknown'],
  );
});

void test('every erasure domain answers for at least one registry row', () => {
  for (const domainId of privacyErasureDomainIds)
    assert.ok(
      privacyWriterRegistry.some((entry) => entry.domainId === domainId),
      domainId,
    );
});
