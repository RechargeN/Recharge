import type { ServerClock } from '../../src/shared/server_clock.js';

export class FakeClock implements ServerClock {
  constructor(private instant: Date) {}

  now(): Date {
    return new Date(this.instant);
  }

  set(value: Date): void {
    this.instant = new Date(value);
  }
}
