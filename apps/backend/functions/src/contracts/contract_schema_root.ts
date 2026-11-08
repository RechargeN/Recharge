import { existsSync } from 'node:fs';
import path from 'node:path';

/**
 * Where a contract group's JSON Schemas live. In the repository: the shared
 * `packages/api_contracts/schema/<group>/v1`, three levels above the functions
 * working directory. A deployed bundle (N3a.2, A34 2026-11-08: the cloud runtime
 * failed with ENOENT) carries its own copy at `<cwd>/contracts/<group>/v1`.
 */
export function contractSchemaRoot(group: string, cwd: string = process.cwd()): string {
  const staged = path.resolve(cwd, 'contracts', group, 'v1');
  if (existsSync(staged)) return staged;
  return path.resolve(cwd, '..', '..', '..', 'packages', 'api_contracts', 'schema', group, 'v1');
}
