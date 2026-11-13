const forbiddenKey =
  /(?:authorization|cookie|token|secret|password|private.?key|credential|email|phone|birth|address|latitude|longitude|payload|narrative)/iu;

export type RedactedSecurityMetadata = Readonly<Record<string, string | number | boolean | null>>;

export function redactSecurityMetadata(
  input: Readonly<Record<string, unknown>>,
): RedactedSecurityMetadata {
  const output: Record<string, string | number | boolean | null> = {};
  for (const [key, value] of Object.entries(input)) {
    if (forbiddenKey.test(key)) continue;
    if (
      value === null ||
      typeof value === 'string' ||
      typeof value === 'number' ||
      typeof value === 'boolean'
    ) {
      if (typeof value === 'string' && value.length > 128) continue;
      if (typeof value === 'number' && !Number.isFinite(value)) continue;
      output[key] = value;
    }
  }
  return Object.freeze(output);
}
