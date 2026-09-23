import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

void test('security/privacy collections are explicit deny and unknown collections remain denied', async () => {
  const rules = await readFile('../firestore.rules', 'utf8');
  for (const collection of ['privacyRequests', 'privacyDomainTasks', 'securityAuditEvents']) {
    assert.match(
      rules,
      new RegExp(`match /${collection}/\\{document\\} \\{ allow read, write: if false; \\}`),
    );
  }
  assert.match(rules, /match \/\{document=\*\*\} \{\s*allow read, write: if false;/u);
  assert.equal(/isAdmin|admin\s*==\s*true/u.test(rules), false);
});
