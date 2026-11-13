/**
 * A34 2026-11-08: every failure was a bare 503. Only the error class and a
 * short machine code reach the log — never a message, payload or credential.
 */
export function failureShape(error: unknown): {
  readonly error: string;
  readonly code: string | null;
} {
  const safe = (value: unknown): string | null =>
    typeof value === 'string' && /^[A-Za-z0-9_.:-]{1,64}$/u.test(value) ? value : null;
  const record =
    typeof error === 'object' && error !== null ? (error as Record<string, unknown>) : {};
  return {
    error: safe(record.name) ?? typeof error,
    code:
      safe(record.reason) ??
      safe(record.code) ??
      (typeof record.code === 'number' ? String(record.code) : null),
  };
}
