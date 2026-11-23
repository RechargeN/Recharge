/**
 * The published body of a Content revision as Content stores it: the JSON
 * string `bodyJson` (firestore_content_repository). A34 staging 2026-11-23:
 * Library read a `body` field that is never written, so every save was
 * refused `object_unavailable`. Anything but a JSON object is no target.
 */
export function publishedRevisionBody(
  revision: Readonly<Record<string, unknown>> | undefined,
): Record<string, unknown> | null {
  const raw = revision?.bodyJson;
  if (typeof raw !== 'string') return null;
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }
  return typeof parsed === 'object' && parsed !== null && !Array.isArray(parsed)
    ? (parsed as Record<string, unknown>)
    : null;
}
