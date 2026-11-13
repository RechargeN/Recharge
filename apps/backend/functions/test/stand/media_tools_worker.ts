// D1 worker process of the local Media tools service (amendment §4.7). STAND
// CODE: forked by media_tools_host inside the same Windows Job Object. It runs
// the image pipeline; the memory probes exist only for `media-tools selftest`
// and answer only when the host passed `--selftest-probes`.
import {
  configurePipeline,
  processImage,
} from '../../src/modules/media/infrastructure/image_pipeline.js';

const probesEnabled = process.argv.includes('--selftest-probes');
const send = (message: unknown) => process.send?.(message);
const held: Buffer[] = [];

function allocate(mib: number): { reached: number; refused: boolean } {
  let reached = 0;
  try {
    while (reached < mib) {
      held.push(Buffer.alloc(16 * 1024 * 1024, 1));
      reached += 16;
    }
    return { reached, refused: false };
  } catch {
    return { reached, refused: true };
  }
}

process.on(
  'message',
  (message: {
    kind?: string;
    id?: string;
    bytes?: Uint8Array;
    profiles?: string[];
    probe?: string;
    mib?: number;
  }) => {
    const { id } = message;
    if (typeof id !== 'string') return;
    if (message.kind === 'process' && message.bytes instanceof Uint8Array) {
      const bytes = Buffer.from(
        message.bytes.buffer,
        message.bytes.byteOffset,
        message.bytes.byteLength,
      );
      void processImage(bytes, message.profiles ?? []).then(
        (outcome) => send({ kind: 'result', id, outcome }),
        () =>
          send({
            kind: 'result',
            id,
            outcome: { result: 'failed', toolRevision: 'sharp-error', reason: 'pipeline_error' },
          }),
      );
      return;
    }
    if (message.kind === 'probe' && probesEnabled && Number.isSafeInteger(message.mib)) {
      const result = allocate(message.mib ?? 0);
      // `hang` keeps the memory and never answers: the host's deadline must end it.
      // After `allocate` the worker leaves, so the next job gets a fresh one.
      if (message.probe === 'allocate') {
        send({ kind: 'probe', id, ...result });
        setTimeout(() => process.exit(3), 50);
      }
      return;
    }
  },
);

const runtime = configurePipeline();
send({
  kind: 'ready',
  toolRevision: runtime.toolRevision,
  native: runtime.native,
  pid: process.pid,
});
