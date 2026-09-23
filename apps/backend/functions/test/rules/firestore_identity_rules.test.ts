import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const identityCollections = [
  'identityAccounts',
  'identityProviderLinks',
  'identitySessions',
  'identityAccessSnapshots',
  'identityCreatorVerifications',
  'identityManagedPages',
  'identityPageMemberships',
] as const;

void test('Identity and Publisher collections are explicit client deny-all', async () => {
  const rules = await readFile('../firestore.rules', 'utf8');
  for (const collection of identityCollections) {
    assert.match(
      rules,
      new RegExp(`match /${collection}/\\{document\\} \\{ allow read, write: if false; \\}`),
    );
  }
  assert.equal(/isAdmin|creatorVerified|pageIds/u.test(rules), false);
});
