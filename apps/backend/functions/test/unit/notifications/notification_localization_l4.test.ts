import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

import { NotificationEffectConsumer } from '../../../src/modules/notifications/application/consume_notification_effect.js';
import {
  handleNotificationsQueryRequest,
  inboxItemWire,
} from '../../../src/modules/notifications/application/notifications_query_handler.js';
import type { InboxItemRecord } from '../../../src/modules/notifications/domain/inbox_item.js';
import { parseNotificationEffect } from '../../../src/modules/notifications/domain/notification_effect.js';
import type { NotificationEffect } from '../../../src/modules/notifications/domain/notification_effect.js';
import {
  notificationPolicyRevisionOne,
  type NotificationPolicyRevision,
} from '../../../src/modules/notifications/domain/notification_policy.js';
import {
  defaultNotificationTemplates,
  notificationLocales,
  notificationTemplateRevisionsOne,
  NotificationTemplateRegistry,
  renderNotificationTemplate,
  type NotificationTemplateRevision,
} from '../../../src/modules/notifications/domain/notification_templates.js';
import { InMemoryNotificationsStore } from '../../../src/modules/notifications/infrastructure/in_memory_notifications_repository.js';
import { FakeClock } from '../../support/fake_clock.js';
import { bookingEffect, FaultyNotificationsStore } from '../../support/notifications_world.js';

/**
 * L4 contract: every effect Booking can produce routes to a registered, active,
 * versioned template that renders in each R1 locale (`lv-LV`, `en`, `ru`) with
 * the same typed placeholders; the recipient's own query decides the language.
 */

const schemaUrl = new URL(
  '../../../../../../../packages/api_contracts/schema/notifications/v1/notification_effect.schema.json',
  import.meta.url,
);
const effectSchema = JSON.parse(readFileSync(schemaUrl, 'utf8')) as {
  properties: Record<string, { enum?: string[]; properties?: Record<string, { enum?: string[] }> }>;
};

/** Every (eventType, cause) the wire contract allows. */
function producedEffects(): { eventType: string; cause?: string }[] {
  const eventTypes = effectSchema.properties.eventType!.enum!;
  const causes = effectSchema.properties.payload!.properties!.cause!.enum!;
  return eventTypes.flatMap((eventType) =>
    eventType === 'booking.cancelled'
      ? causes.map((cause) => ({ eventType, cause }))
      : [{ eventType }],
  );
}

function placeholders(text: string): string[] {
  return [...text.matchAll(/\{([a-zA-Z]+)\}/gu)].map((match) => match[1]!).sort();
}

/**
 * Findings for a policy + template registry: an unregistered or inactive
 * template key, a missing R1 locale, or placeholders that differ between
 * locales or from the declared typed variables.
 */
function localizationFindings(
  policy: NotificationPolicyRevision,
  templates: NotificationTemplateRegistry,
  revisions: readonly NotificationTemplateRevision[],
): string[] {
  const findings: string[] = [];
  for (const produced of producedEffects()) {
    const route = policy.route(produced as unknown as NotificationEffect);
    if (route.kind !== 'deliver') continue;
    const active = templates.activeRevision(route.templateKey);
    if (active === undefined || templates.get(route.templateKey, active) === undefined)
      findings.push(`unregistered:${route.templateKey}`);
  }
  for (const template of revisions) {
    const declared = [...template.variables].sort();
    for (const locale of notificationLocales) {
      const text = template.locales[locale];
      const id = `${template.templateKey}#${String(template.revision)}:${locale}`;
      if (text === undefined) {
        findings.push(`missing_locale:${id}`);
        continue;
      }
      if (text.title.trim() === '' || text.body.trim() === '') findings.push(`empty:${id}`);
      const used = placeholders(`${text.title} ${text.body}`);
      if (JSON.stringify(used) !== JSON.stringify(declared))
        findings.push(`placeholders:${id}:${used.join(',')}`);
    }
  }
  return findings;
}

void test('every producible effect routes to an active template rendered in lv-LV, en and ru', () => {
  assert.deepEqual([...notificationLocales].sort(), ['en', 'lv-LV', 'ru']);
  assert.deepEqual(
    localizationFindings(
      notificationPolicyRevisionOne,
      defaultNotificationTemplates,
      notificationTemplateRevisionsOne,
    ),
    [],
  );
  const delivered = producedEffects()
    .map((produced) =>
      notificationPolicyRevisionOne.route(produced as unknown as NotificationEffect),
    )
    .filter((route) => route.kind === 'deliver')
    .map((route) => (route.kind === 'deliver' ? route.templateKey : ''))
    .sort();
  assert.deepEqual(delivered, notificationTemplateRevisionsOne.map((t) => t.templateKey).sort());
});

void test('positive control: a new unregistered key, a missing locale and a placeholder drift are found', () => {
  const routeToNew: NotificationPolicyRevision = {
    ...notificationPolicyRevisionOne,
    route: (effect) =>
      effect.eventType === 'booking.reconfirmed'
        ? { kind: 'deliver', category: 'booking.receipts', templateKey: 'booking.waitlistOffered' }
        : notificationPolicyRevisionOne.route(effect),
  };
  const base = notificationTemplateRevisionsOne.find(
    (template) => template.templateKey === 'booking.reconfirmationRequired',
  )!;
  const missingLv: NotificationTemplateRevision = {
    ...base,
    templateKey: 'booking.missingLv',
    locales: { en: base.locales.en!, ru: base.locales.ru! },
  };
  const drift: NotificationTemplateRevision = {
    ...base,
    templateKey: 'booking.drift',
    locales: { ...base.locales, ru: { title: 'Подтвердите участие', body: 'Событие изменилось.' } },
  };
  const findings = localizationFindings(routeToNew, defaultNotificationTemplates, [
    ...notificationTemplateRevisionsOne,
    missingLv,
    drift,
  ]);
  assert.deepEqual(findings, [
    'unregistered:booking.waitlistOffered',
    'missing_locale:booking.missingLv#1:lv-LV',
    'placeholders:booking.drift#1:ru:',
  ]);
});

void test('an effect cannot carry the initiator language: unknown envelope members are refused', () => {
  const schemaText = JSON.stringify(effectSchema).toLowerCase();
  assert.equal(schemaText.includes('locale'), false);
  assert.equal(schemaText.includes('language'), false);
  const effect = bookingEffect({ effect: { kind: 'cancelled', cause: 'occurrenceCancelled' } });
  assert.equal(parseNotificationEffect(effect.id, effect.data).kind, 'effect');
  assert.deepEqual(
    parseNotificationEffect(effect.id, { ...effect.data, initiatorLocale: 'lv-LV' }),
    {
      kind: 'invalid',
      code: 'invalid_effect',
    },
  );
});

async function oneItem(
  effect = bookingEffect({
    effect: {
      kind: 'reconfirmationRequired',
      reconfirmationDeadlineUtc: '2026-08-30T15:30:00.000Z',
    },
  }),
): Promise<{ store: InMemoryNotificationsStore; item: InboxItemRecord }> {
  const store = new InMemoryNotificationsStore();
  store.setAccount('recipient-1', 'active');
  const consumer = new NotificationEffectConsumer({
    store,
    clock: new FakeClock(new Date('2026-08-29T12:00:00.000Z')),
  });
  assert.equal(await consumer.consume(effect.id, effect.data), 'created');
  const [item] = [...store.snapshot().items.values()] as InboxItemRecord[];
  return { store, item: item! };
}

void test('one stored item reads in three languages; ids, routing, timestamps and the instant never change', async () => {
  const { item } = await oneItem();
  const wires = notificationLocales.map((locale) =>
    inboxItemWire(item, locale, defaultNotificationTemplates),
  );
  const invariant = (wire: Readonly<Record<string, unknown>>) => {
    const rest: Record<string, unknown> = { ...wire };
    delete rest.content;
    return rest;
  };
  for (const wire of wires) {
    assert.equal(wire.contentStatus, 'rendered');
    assert.deepEqual(invariant(wire), invariant(wires[0]!));
  }
  const bodies = wires.map((wire) => (wire.content as { body: string }).body);
  assert.equal(new Set(bodies).size, 3);
  // The stored variable is the UTC instant; every language shows the same
  // Riga wall-clock time of it.
  assert.equal(item.variables.deadline !== undefined, true);
  assert.equal(JSON.stringify(item).includes('lv-LV'), false);
});

void test('the recipient language comes from the reader query; a missing or unsupported locale is refused', async () => {
  const { store } = await oneItem(
    bookingEffect({ effect: { kind: 'cancelled', cause: 'occurrenceCancelled' } }),
  );
  const clock = new FakeClock(new Date('2026-08-29T12:05:00.000Z'));
  const query = (payload: Record<string, unknown>) =>
    handleNotificationsQueryRequest(
      { store, clock, features: { inbox: true, preferences: true } },
      'recipient-1',
      { schemaVersion: 1, requestId: 'req-l4', queryType: 'listInbox', payload },
    );
  // The organizer who cancelled is not the recipient; nothing of their
  // language exists to read. The recipient chooses per query.
  const titles: Record<string, string> = {};
  for (const locale of notificationLocales) {
    const answer = await query({ locale });
    assert.equal(answer.kind, 'succeeded');
    const [first] = answer.items as { content: { title: string } }[];
    titles[locale] = first!.content.title;
  }
  assert.deepEqual(titles, {
    'lv-LV': 'Pasākums atcelts',
    en: 'Event cancelled',
    ru: 'Событие отменено',
  });
  for (const payload of [{}, { locale: 'lv' }, { locale: 'et-EE' }, { locale: 'de' }]) {
    const answer = await query(payload);
    assert.equal(answer.kind, 'rejected');
    assert.equal(answer.code === 'unsupported_locale' || answer.code === 'invalid_query', true);
  }
});

void test('a retried delivery creates one item and still reads in every locale', async () => {
  const store = new InMemoryNotificationsStore();
  store.setAccount('recipient-1', 'active');
  const faulty = new FaultyNotificationsStore(store);
  const clock = new FakeClock(new Date('2026-08-29T12:00:00.000Z'));
  const consumer = new NotificationEffectConsumer({ store: faulty, clock });
  const effect = bookingEffect();
  faulty.faults.add('inbox_write');
  assert.equal(await consumer.consume(effect.id, effect.data), 'retry_scheduled');
  faulty.faults.clear();
  clock.set(new Date('2026-08-29T12:00:30.000Z'));
  assert.equal(await consumer.consume(effect.id, effect.data), 'created');
  assert.equal(await consumer.consume(effect.id, effect.data), 'duplicate');
  const items = [...store.snapshot().items.values()] as InboxItemRecord[];
  assert.equal(items.length, 1);
  for (const locale of notificationLocales)
    assert.equal(
      inboxItemWire(items[0]!, locale, defaultNotificationTemplates).contentStatus,
      'rendered',
    );
});

void test('stored items keep their pinned revision; a retired revision reads as unavailable, never rewritten', async () => {
  const { item } = await oneItem(bookingEffect());
  assert.equal(item.templateRevision, 1);
  const one = notificationTemplateRevisionsOne.find((t) => t.templateKey === 'booking.confirmed')!;
  const two: NotificationTemplateRevision = {
    ...one,
    revision: 2,
    locales: {
      'lv-LV': { title: 'Rezervācija apstiprināta (2)', body: 'v2' },
      en: { title: 'Booking confirmed (2)', body: 'v2' },
      ru: { title: 'Бронь подтверждена (2)', body: 'v2' },
    },
  };
  const both = new NotificationTemplateRegistry([...notificationTemplateRevisionsOne, two], {
    ...Object.fromEntries(notificationTemplateRevisionsOne.map((t) => [t.templateKey, 1])),
    'booking.confirmed': 2,
  });
  const wire = inboxItemWire(item, 'en', both);
  assert.deepEqual(wire.template, { key: 'booking.confirmed', revision: 1 });
  assert.deepEqual(wire.content, {
    title: 'Booking confirmed',
    body: 'Your place at the event is booked.',
  });
  const retired = new NotificationTemplateRegistry([two], { 'booking.confirmed': 2 });
  const unavailable = inboxItemWire(item, 'ru', retired);
  assert.equal(unavailable.contentStatus, 'template_unavailable');
  assert.equal(unavailable.content, null);
  assert.equal(item.templateRevision, 1);
});

void test('deadline variables keep the instant: midnight and the Riga DST fall-back hour', () => {
  const template = defaultNotificationTemplates.get('booking.reconfirmationRequired', 1)!;
  const render = (deadline: string, locale: (typeof notificationLocales)[number]) =>
    renderNotificationTemplate(template, locale, { deadline })!.body;
  // 2026-08-30T21:00Z is midnight in Riga (EEST, UTC+3): the next calendar day.
  assert.match(render('2026-08-30T21:00:00.000Z', 'ru'), /31.*0?0:00/u);
  assert.match(render('2026-08-30T21:00:00.000Z', 'lv-LV'), /31.*0?0:00/u);
  assert.match(render('2026-08-30T21:00:00.000Z', 'en'), /31.*12:00/u);
  // 2026-10-25 01:00Z: Riga leaves summer time at 04:00 EEST -> 03:00 EET, so
  // 00:30Z and 01:30Z are both 03:30 local; neither shifts to another hour.
  for (const locale of notificationLocales) {
    assert.match(render('2026-10-25T00:30:00.000Z', locale), /3:30/u);
    assert.match(render('2026-10-25T01:30:00.000Z', locale), /3:30/u);
  }
});
