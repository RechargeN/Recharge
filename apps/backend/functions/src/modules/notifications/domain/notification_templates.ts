import { createHash } from 'node:crypto';

import type { NotificationCategory } from './notification_policy.js';

/**
 * F1 versioned templates. A revision is immutable and pinned by sha256 in its
 * test: changing revision 1 wording fails the lock, a new revision is required.
 * Revision 1 wording is a local fixture, not approved copy (BCK13-OD-05 open).
 * There is no fallback between locales.
 */
export type NotificationLocale = 'lv-LV' | 'en' | 'ru';
export const notificationLocales: readonly NotificationLocale[] = ['lv-LV', 'en', 'ru'];

export interface NotificationTemplateRevision {
  readonly templateKey: string;
  readonly revision: number;
  readonly category: NotificationCategory;
  /** Allowlisted typed variables; `deadline` is a UTC instant. */
  readonly variables: readonly 'deadline'[];
  readonly locales: Readonly<
    Partial<Record<NotificationLocale, Readonly<{ title: string; body: string }>>>
  >;
}

export interface NotificationTemplateVariables {
  readonly deadline?: string;
}

/** Market LV default zone (BCK-20); used only to format a deadline variable. */
const renderTimeZone = 'Europe/Riga';

function revision(
  templateKey: string,
  category: NotificationCategory,
  locales: NotificationTemplateRevision['locales'],
  variables: readonly 'deadline'[] = [],
): NotificationTemplateRevision {
  return Object.freeze({
    templateKey,
    revision: 1,
    category,
    variables: Object.freeze([...variables]),
    locales: Object.freeze(locales),
  });
}

export const notificationTemplateRevisionsOne: readonly NotificationTemplateRevision[] =
  Object.freeze([
    revision('booking.confirmed', 'booking.receipts', {
      'lv-LV': {
        title: 'Rezervācija apstiprināta',
        body: 'Jūsu vieta pasākumā ir rezervēta.',
      },
      en: { title: 'Booking confirmed', body: 'Your place at the event is booked.' },
      ru: { title: 'Бронь подтверждена', body: 'Ваше место на событии забронировано.' },
    }),
    revision('booking.cancelled.byUser', 'booking.receipts', {
      'lv-LV': { title: 'Rezervācija atcelta', body: 'Jūs atcēlāt rezervāciju.' },
      en: { title: 'Booking cancelled', body: 'You cancelled your booking.' },
      ru: { title: 'Бронь отменена', body: 'Вы отменили бронь.' },
    }),
    revision('booking.reconfirmed', 'booking.receipts', {
      'lv-LV': {
        title: 'Dalība apstiprināta',
        body: 'Jūs apstiprinājāt dalību pēc pasākuma izmaiņām.',
      },
      en: {
        title: 'Attendance confirmed',
        body: 'You confirmed your attendance after the event changed.',
      },
      ru: {
        title: 'Участие подтверждено',
        body: 'Вы подтвердили участие после изменения события.',
      },
    }),
    revision('booking.cancelled.occurrence', 'booking.changes', {
      'lv-LV': {
        title: 'Pasākums atcelts',
        body: 'Organizators atcēla šo pasākumu, jūsu rezervācija ir atcelta.',
      },
      en: {
        title: 'Event cancelled',
        body: 'The organizer cancelled this event and your booking was released.',
      },
      ru: {
        title: 'Событие отменено',
        body: 'Организатор отменил это событие, ваша бронь снята.',
      },
    }),
    revision('booking.cancelled.missedReconfirmation', 'booking.changes', {
      'lv-LV': {
        title: 'Rezervācija atcelta',
        body: 'Dalība netika laikus apstiprināta pēc pasākuma izmaiņām.',
      },
      en: {
        title: 'Booking released',
        body: 'Attendance was not confirmed in time after the event changed.',
      },
      ru: {
        title: 'Бронь снята',
        body: 'Участие не было подтверждено вовремя после изменения события.',
      },
    }),
    revision(
      'booking.reconfirmationRequired',
      'booking.changes',
      {
        'lv-LV': {
          title: 'Apstipriniet dalību',
          body: 'Pasākums ir mainījies. Apstipriniet dalību līdz {deadline}.',
        },
        en: {
          title: 'Confirm your attendance',
          body: 'The event has changed. Confirm your attendance by {deadline}.',
        },
        ru: {
          title: 'Подтвердите участие',
          body: 'Событие изменилось. Подтвердите участие до {deadline}.',
        },
      },
      ['deadline'],
    ),
  ]);

function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (typeof value === 'object' && value !== null)
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${canonical((value as Record<string, unknown>)[key])}`)
      .join(',')}}`;
  return JSON.stringify(value);
}

export function notificationTemplateSha256(template: NotificationTemplateRevision): string {
  return createHash('sha256').update(canonical(template), 'utf8').digest('hex');
}

export class NotificationTemplateRegistry {
  readonly #revisions: ReadonlyMap<string, NotificationTemplateRevision>;

  constructor(
    revisions: readonly NotificationTemplateRevision[],
    private readonly activeRevisions: Readonly<Record<string, number>>,
  ) {
    const map = new Map<string, NotificationTemplateRevision>();
    for (const template of revisions) {
      const key = `${template.templateKey}#${String(template.revision)}`;
      if (map.has(key)) throw new TypeError('notification_template_duplicate');
      for (const [name, text] of Object.entries(template.locales)) {
        const placeholders = [...`${text.title} ${text.body}`.matchAll(/\{([a-zA-Z]+)\}/gu)].map(
          (match) => match[1],
        );
        if (
          placeholders.some(
            (placeholder) => !template.variables.includes(placeholder as 'deadline'),
          )
        )
          throw new TypeError(
            `notification_template_variable_unlisted:${template.templateKey}:${name}`,
          );
      }
      map.set(key, template);
    }
    this.#revisions = map;
    for (const [templateKey, active] of Object.entries(activeRevisions))
      if (!map.has(`${templateKey}#${String(active)}`))
        throw new TypeError('notification_template_active_missing');
  }

  activeRevision(templateKey: string): number | undefined {
    return this.activeRevisions[templateKey];
  }

  get(templateKey: string, revisionNumber: number): NotificationTemplateRevision | undefined {
    return this.#revisions.get(`${templateKey}#${String(revisionNumber)}`);
  }
}

export const defaultNotificationTemplates = new NotificationTemplateRegistry(
  notificationTemplateRevisionsOne,
  Object.fromEntries(notificationTemplateRevisionsOne.map((template) => [template.templateKey, 1])),
);

export function isNotificationLocale(value: unknown): value is NotificationLocale {
  return notificationLocales.includes(value as NotificationLocale);
}

/**
 * Renders a pinned revision in one locale; `null` when the revision has no
 * text for that locale (fail closed, no fallback) or a declared variable is
 * missing.
 */
export function renderNotificationTemplate(
  template: NotificationTemplateRevision,
  locale: NotificationLocale,
  variables: NotificationTemplateVariables,
): Readonly<{ title: string; body: string }> | null {
  const text = template.locales[locale];
  if (text === undefined) return null;
  const values: Record<string, string> = {};
  for (const name of template.variables) {
    const value = variables[name];
    if (value === undefined || !Number.isFinite(Date.parse(value))) return null;
    values[name] = new Intl.DateTimeFormat(locale, {
      dateStyle: 'medium',
      timeStyle: 'short',
      timeZone: renderTimeZone,
    }).format(new Date(value));
  }
  const fill = (source: string) =>
    source.replace(/\{([a-zA-Z]+)\}/gu, (_, name: string) => values[name] ?? '');
  return { title: fill(text.title), body: fill(text.body) };
}
