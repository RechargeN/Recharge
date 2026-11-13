import { emulatorFirestore } from '../support/booking_emulator.js';
import { runModerate } from './stand_moderation.js';
import { assertStandEnvironment } from './stand_guard.js';

/** Entry used by scripts/stand-moderate.mjs after it has verified the running stand. */
function option(args: readonly string[], name: string): string | undefined {
  const index = args.indexOf(name);
  return index < 0 ? undefined : args[index + 1];
}

async function main(args: readonly string[]): Promise<void> {
  assertStandEnvironment(process.env);
  const [command, ...rest] = args;
  if (command === undefined) throw new Error('missing command');
  const flags = new Set(['--as', '--reason', '--key', '--decision']);
  const positional = rest.filter(
    (value, index) => !flags.has(value) && !flags.has(rest[index - 1] ?? ''),
  );
  const reason = option(rest, '--reason');
  const key = option(rest, '--key');
  const decision = option(rest, '--decision');
  const result = await runModerate(emulatorFirestore(), {
    as: option(rest, '--as') ?? 'staff',
    command,
    args: positional,
    ...(reason === undefined ? {} : { reason }),
    ...(key === undefined ? {} : { key }),
    ...(decision === undefined ? {} : { decision }),
  });
  process.stdout.write(`${JSON.stringify(result)}\n`);
  const refused =
    result.kind !== 'succeeded' ||
    ('receipt' in result.data && result.data.receipt.outcome === 'refused');
  if (refused) process.exitCode = 2;
}

main(process.argv.slice(2)).catch((error: unknown) => {
  process.stderr.write(`failed: ${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
});
