import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  attest,
  commandHash,
  maxReasonLength,
  validReason,
  type ModerationDecision,
  type StaffModerationCommand,
} from '../../../src/modules/moderation/domain/moderation.js';

const command: StaffModerationCommand = {
  schemaVersion: 1,
  action: 'restrict',
  idempotencyKey: 'op-00000001',
  reason: 'misleading cover image',
  target: { contentId: 'content-1' },
};

void test('a reason is 3..500 characters of single-line text', () => {
  assert.equal(validReason('ok!'), true);
  for (const bad of [
    '',
    'ab',
    ' padded ',
    'two\nlines',
    'tab\there',
    'x'.repeat(maxReasonLength + 1),
  ])
    assert.equal(validReason(bad), false, JSON.stringify(bad));
  assert.equal(validReason(undefined), false);
  assert.equal(validReason('x'.repeat(maxReasonLength)), true);
});

void test('the command hash separates every meaningful field and ignores the key', () => {
  const base = commandHash(command);
  assert.equal(commandHash({ ...command, idempotencyKey: 'op-00000002' }), base);
  assert.notEqual(commandHash({ ...command, reason: 'another reason' }), base);
  assert.notEqual(commandHash({ ...command, action: 'withdraw' }), base);
  assert.notEqual(commandHash({ ...command, target: { contentId: 'content-2' } }), base);
  assert.notEqual(commandHash({ ...command, restoresDecisionId: 'decision-1' }), base);
});

void test('the attestation binds the decision to its exact content', () => {
  const unsigned: Omit<ModerationDecision, 'attestation'> = {
    schemaVersion: 1,
    decisionId: 'decision-1',
    action: 'restrict',
    staffUserId: 'staff-1',
    staffSessionId: 'session-1',
    reason: 'misleading cover image',
    reasonCategory: 'operator_decision',
    target: { contentId: 'content-1', publishedRevisionId: 'rev-1', pointerRevision: 1 },
    policyRevision: 'policy-1',
    decidedAtUtc: '2026-10-06T10:00:00.000Z',
    idempotencyKey: 'op-00000001',
    semanticHash: 'hash',
  };
  const signed = attest(unsigned);
  assert.equal(attest({ ...unsigned }), signed);
  assert.notEqual(attest({ ...unsigned, action: 'withdraw' }), signed);
  assert.notEqual(attest({ ...unsigned, staffUserId: 'staff-2' }), signed);
  assert.notEqual(
    attest({ ...unsigned, target: { ...unsigned.target, pointerRevision: 2 } }),
    signed,
  );
  assert.notEqual(attest({ ...unsigned, reason: 'a different reason' }), signed);
});
