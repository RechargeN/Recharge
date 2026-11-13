// N3b worker process of the processor service (forked by cloud_tools_host).
// Same pipeline as the D1 stand worker; no memory probes in the cloud.
import {
  configurePipeline,
  processImage,
} from '../../functions/src/modules/media/infrastructure/image_pipeline.js';

const send = (message: unknown) => process.send?.(message);

process.on(
  'message',
  (message: { kind?: string; id?: string; bytes?: Uint8Array; profiles?: string[] }) => {
    const { id } = message;
    if (typeof id !== 'string') return;
    if (message.kind !== 'process' || !(message.bytes instanceof Uint8Array)) return;
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
          outcome: {
            result: 'failed',
            toolRevision: 'sharp-error',
            reason: 'pipeline_error',
          },
        }),
    );
  },
);

const runtime = configurePipeline();
// Fail closed: only the native linux-x64 binding may process images.
if (!runtime.native) process.exit(4);
send({
  kind: 'ready',
  toolRevision: runtime.toolRevision,
  native: runtime.native,
  pid: process.pid,
});
