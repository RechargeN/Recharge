import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  defaultNotificationTemplates,
  notificationLocales,
  notificationTemplateRevisionsOne,
  notificationTemplateSha256,
  NotificationTemplateRegistry,
  renderNotificationTemplate,
} from '../../../src/modules/notifications/domain/notification_templates.js';

/**
 * Revision lock: a revision is immutable. Changing any wording, variable or
 * category of revision 1 must fail here; the change needs a new revision.
 */
const revisionOneLock: Readonly<Record<string, string>> = {
  'booking.confirmed': 'ba0e8e808f6e88d607ac449c02d1ca9b3b70dd437c397d3f682cf19fab73319c',
  'booking.cancelled.byUser': '1b209a30e04515db5b2fd853e7378075495e14ee584d053df48e14cf43890046',
  'booking.reconfirmed': 'c87fbe3ce123f705e8344cf36db39114e1572bb654ee7f7c5421a878e50bdd6c',
  'booking.cancelled.occurrence':
    '0c4e045a229e49711cf3f91bbc3b041cdd11b11f2552de27d8e5d3f12667ce13',
  'booking.cancelled.missedReconfirmation':
    'c36614201420e4ffadcdf5df06b2fd65f25db2ee79ea0b14f86793e3f129c18f',
  'booking.reconfirmationRequired':
    '27ac139892234a53e75a6bc6c3d05b19d2e1c855de43417893a83923438ddc2b',
};

void test('revision 1 is locked by sha256 and every key is active at revision 1', () => {
  assert.deepEqual(
    Object.fromEntries(
      notificationTemplateRevisionsOne.map((template) => [
        template.templateKey,
        notificationTemplateSha256(template),
      ]),
    ),
    revisionOneLock,
  );
  for (const template of notificationTemplateRevisionsOne) {
    assert.equal(template.revision, 1);
    assert.equal(defaultNotificationTemplates.activeRevision(template.templateKey), 1);
    assert.deepEqual(Object.keys(template.locales).sort(), [...notificationLocales].sort());
  }
});

void test('rendering uses only the requested locale and formats the deadline in Riga time', () => {
  const template = defaultNotificationTemplates.get('booking.reconfirmationRequired', 1)!;
  const deadline = '2026-08-30T15:30:00.000Z';
  assert.match(renderNotificationTemplate(template, 'ru', { deadline })!.body, /18:30/u);
  assert.match(renderNotificationTemplate(template, 'lv-LV', { deadline })!.body, /18:30/u);
  assert.match(renderNotificationTemplate(template, 'en', { deadline })!.body, /6:30/u);
  assert.equal(renderNotificationTemplate(template, 'ru', {}), null);
  const confirmed = defaultNotificationTemplates.get('booking.confirmed', 1)!;
  assert.deepEqual(renderNotificationTemplate(confirmed, 'ru', {}), {
    title: 'Бронь подтверждена',
    body: 'Ваше место на событии забронировано.',
  });
});

void test('a missing locale fails closed with no fallback, and placeholders must be declared', () => {
  const partial = {
    templateKey: 'test.partial',
    revision: 1,
    category: 'booking.receipts' as const,
    variables: [] as const,
    locales: { en: { title: 'T', body: 'B' } },
  };
  assert.equal(renderNotificationTemplate(partial, 'ru', {}), null);
  assert.throws(
    () =>
      new NotificationTemplateRegistry(
        [{ ...partial, locales: { en: { title: 'T', body: 'by {deadline}' } } }],
        { 'test.partial': 1 },
      ),
    /notification_template_variable_unlisted/u,
  );
  assert.throws(
    () => new NotificationTemplateRegistry([partial], { 'test.partial': 2 }),
    /notification_template_active_missing/u,
  );
});
