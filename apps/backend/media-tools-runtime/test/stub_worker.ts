// Test double of cloud_tools_worker (no sharp): answers `succeeded` with one
// variant per profile, or never answers when the bytes start with `HANG`.
import { createHash } from 'node:crypto';

const send = (message: unknown) => process.send?.(message);

process.on(
  'message',
  (message: { kind?: string; id?: string; bytes?: Uint8Array; profiles?: string[] }) => {
    if (typeof message.id !== 'string' || !(message.bytes instanceof Uint8Array)) return;
    const bytes = Buffer.from(message.bytes);
    if (bytes.subarray(0, 4).toString('latin1') === 'HANG') return;
    const variant = Buffer.from(`variant-of-${bytes.length}`);
    send({
      kind: 'result',
      id: message.id,
      outcome: {
        result: 'succeeded',
        toolRevision: 'sharp-stub',
        transformProfileRevision: 'd1-local-1',
        variants: (message.profiles ?? []).map((profile) => ({
          profile,
          format: 'image/webp',
          width: 10,
          height: 10,
          byteLength: variant.length,
          sha256: createHash('sha256').update(variant).digest('hex'),
          bytes: variant,
        })),
      },
    });
  },
);

send({
  kind: 'ready',
  toolRevision: 'sharp-stub',
  native: true,
  pid: process.pid,
});
