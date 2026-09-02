export interface ServerClock {
  now(): Date;
}

export const systemServerClock: ServerClock = Object.freeze({
  now: () => new Date(),
});

export function requireValidInstant(value: Date): Date {
  if (!Number.isFinite(value.getTime())) throw new Error('invalid_server_time');
  return value;
}
