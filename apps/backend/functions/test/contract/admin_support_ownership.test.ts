import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import ts from 'typescript';

// All writes must resolve to fixed Admin-owned collection references. Reject
// dynamic collections, foreign references, root paths and storage API escapes.
function violations(source: string): string[] {
  const file = ts.createSourceFile('admin.ts', source, ts.ScriptTarget.Latest, true);
  const errors: string[] = [];
  const refs = new Set<string>();
  const owned = (n: ts.Node | undefined): boolean => {
    if (!n) return false;
    if (ts.isIdentifier(n)) return refs.has(n.text);
    return (
      ts.isCallExpression(n) &&
      ts.isPropertyAccessExpression(n.expression) &&
      n.expression.name.text === 'doc' &&
      ts.isCallExpression(n.expression.expression) &&
      ts.isPropertyAccessExpression(n.expression.expression.expression) &&
      n.expression.expression.expression.name.text === 'collection' &&
      /^adminCollections\.(cases|proposals|approvals|executions|audit)$/.test(
        n.expression.expression.arguments[0]?.getText(file) ?? '',
      )
    );
  };
  const collect = (n: ts.Node) => {
    if (ts.isVariableDeclaration(n) && ts.isIdentifier(n.name) && owned(n.initializer))
      refs.add(n.name.text);
    ts.forEachChild(n, collect);
  };
  collect(file);
  const visit = (n: ts.Node) => {
    if (ts.isCallExpression(n) && ts.isPropertyAccessExpression(n.expression)) {
      const method = n.expression.name.text;
      if (
        method === 'collection' &&
        !/^adminCollections\.(cases|proposals|approvals|executions|audit)$/.test(
          n.arguments[0]?.getText(file) ?? '',
        )
      )
        errors.push('foreign collection');
      if (['batch', 'bulkWriter', 'collectionGroup', 'recursiveDelete'].includes(method))
        errors.push('unbounded storage API');
      if (method === 'doc' && !ts.isCallExpression(n.expression.expression))
        errors.push('root or aliased document path');
      if (
        ['set', 'update', 'create', 'delete'].includes(method) &&
        (n.expression.expression.getText(file) !== 'tx' || !owned(n.arguments[0]))
      )
        errors.push('foreign write reference');
    }
    if (
      ts.isElementAccessExpression(n) &&
      /^(?:this\.)?(?:db|tx)$/.test(n.expression.getText(file))
    )
      errors.push('dynamic storage API');
    if (
      ts.isPropertyAccessExpression(n) &&
      ['collection', 'doc', 'batch', 'bulkWriter'].includes(n.name.text) &&
      (!ts.isCallExpression(n.parent) || n.parent.expression !== n)
    )
      errors.push('storage API alias');
    if (
      ts.isImportDeclaration(n) &&
      /(?:repository|safety_commands)/.test(n.moduleSpecifier.getText(file)) &&
      !n.moduleSpecifier.getText(file).includes('firestore_content_repository.js')
    )
      errors.push('owner storage import');
    ts.forEachChild(n, visit);
  };
  visit(file);
  return errors;
}
void test('K3 Admin module can only write its own fixed collections', () => {
  const scan = (dir: string): void => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const name = path.join(dir, entry.name);
      if (entry.isDirectory()) scan(name);
      else if (name.endsWith('.ts'))
        assert.deepEqual(violations(readFileSync(name, 'utf8')), [], name);
    }
  };
  scan(path.resolve('src/modules/admin_support'));
});
void test('K3 positive controls detect forbidden writes, foreign refs and storage escapes', () => {
  for (const source of [
    `db.collection('bookings').doc('x').set({state:'cancelled'})`,
    `db.collection(domainCollection).doc(id).update(patch)`,
    `db.doc('contentDrafts/x').set(patch)`,
    `db.bulkWriter().set(ref, patch)`,
    `tx.update(foreignRef, patch)`,
    `const collection = db.collection; collection('bookings')`,
    `db['collection']('bookings')`,
    `import { repo } from '../booking/repository.js'`,
  ])
    assert.ok(violations(source).length > 0, source);
  assert.deepEqual(
    violations(
      `const ref = db.collection(adminCollections.proposals).doc(id); tx.create(ref, proposal)`,
    ),
    [],
  );
});

void test('K3 collections have explicit client deny and Firebase CLI manifest ownership', async () => {
  const { adminCollections } =
    await import('../../src/modules/admin_support/admin_support_service.js');
  const names = Object.values(adminCollections);
  const rules = readFileSync('../firestore.rules', 'utf8');
  const manifest = JSON.parse(
    readFileSync('../config/manifests/execution-manifest.json', 'utf8'),
  ) as {
    firestore: {
      collections: {
        name: string;
        clientAccess: string;
        owner: string;
        ttlFields: string[];
        compositeIndexes: string[][];
      }[];
    };
  };
  const check = (text: string, rows: typeof manifest.firestore.collections) =>
    names.every(
      (name) =>
        text.includes(`match /${name}/{document} { allow read, write: if false; }`) &&
        rows.filter((row) => row.name === name).length === 1 &&
        rows.some(
          (row) =>
            row.name === name &&
            row.clientAccess === 'deny' &&
            row.owner === 'firebase_cli' &&
            row.ttlFields.length === 0 &&
            row.compositeIndexes.length === 0,
        ),
    );
  assert.equal(check(rules, manifest.firestore.collections), true);
  assert.equal(
    check(
      rules.replace(`match /${names[0]}/{document} { allow read, write: if false; }`, ''),
      manifest.firestore.collections,
    ),
    false,
  );
  assert.equal(
    check(
      rules,
      manifest.firestore.collections.filter((row) => row.name !== names[0]),
    ),
    false,
  );
});
