import { randomUUID } from 'node:crypto';

import type { ServerClock } from '../../../shared/server_clock.js';
import { catalogTestOnlyConfig } from '../domain/catalog_config.js';
import type {
  CatalogFinding,
  CatalogRepository,
  CatalogReportRecord,
  ItemVersionRecord,
} from '../domain/repositories.js';
import type { CatalogProjector } from './catalog_projector.js';
import type { ContentCatalogSource, SourcePointer } from './ports.js';

export interface ReconcileReport {
  readonly setId: string;
  readonly checked: number;
  readonly findings: readonly CatalogFinding[];
  /** Gaps closed by replaying the facts Content had stored. */
  readonly recovered: number;
  /** No open finding: every object matches its current Content pointer. */
  readonly complete: boolean;
}

/** Findings that a replay can close; every other finding stays open. */
const repairable = new Set<CatalogFinding['code']>(['gap']);

/**
 * Compares a projection set with the current Content pointers and repairs it
 * from the facts Content stored, through the same projector. It never edits
 * Content, never invents a missing fact (a missing one is reported), and only
 * a reconciliation without open findings refreshes the set's sync time.
 */
export class CatalogReconciler {
  constructor(
    private readonly repository: CatalogRepository,
    private readonly source: ContentCatalogSource,
    private readonly projector: CatalogProjector,
    private readonly clock: ServerClock,
  ) {}

  async reconcile(
    setId: string,
    options: { readonly repair?: boolean; readonly kind?: 'reconcile' | 'rebuild' } = {},
  ): Promise<ReconcileReport> {
    const repair = options.repair ?? true;
    const findings: CatalogFinding[] = [];
    const seen = new Set<string>();
    let recovered = 0;
    let checked = 0;
    let after: string | null = null;
    for (;;) {
      let pointers: readonly SourcePointer[];
      try {
        pointers = await this.source.pointersPage(after, catalogTestOnlyConfig.reconcileBatchSize);
      } catch {
        findings.push({ code: 'source_unavailable', contentId: '', detail: 'pointers' });
        break;
      }
      for (const pointer of pointers) {
        checked += 1;
        seen.add(pointer.contentId);
        const outcome = await this.#check(setId, pointer, repair);
        findings.push(...outcome.findings);
        recovered += outcome.recovered;
      }
      if (pointers.length < catalogTestOnlyConfig.reconcileBatchSize) break;
      after = pointers[pointers.length - 1]?.contentId ?? null;
    }
    // Objects the Catalog holds but Content does not know are reported.
    let stateAfter: string | null = null;
    for (;;) {
      const states = await this.repository.sourceStates(
        setId,
        stateAfter,
        catalogTestOnlyConfig.reconcileBatchSize,
      );
      for (const state of states)
        if (!seen.has(state.contentId))
          findings.push({
            code: 'orphan',
            contentId: state.contentId,
            detail: 'no Content pointer',
          });
      if (states.length < catalogTestOnlyConfig.reconcileBatchSize) break;
      stateAfter = states[states.length - 1]?.contentId ?? null;
    }
    const open = findings.filter((finding) => !repairable.has(finding.code) || !repair);
    // A gap counts as closed only when its object no longer reports one.
    const unrecoveredGaps = findings.filter(
      (finding) =>
        finding.code === 'gap' &&
        findings.some(
          (other) =>
            other.contentId === finding.contentId && other.code === 'source_effect_missing',
        ),
    );
    const complete = open.length === 0 && unrecoveredGaps.length === 0;
    if (complete && repair) await this.projector.markSynced(setId);
    const report: CatalogReportRecord = {
      reportId: `${options.kind ?? 'reconcile'}-${Date.now()}-${randomUUID().slice(0, 8)}`,
      setId,
      kind: options.kind ?? 'reconcile',
      findings,
      recovered,
      complete,
      createdAtUtc: this.clock.now().toISOString(),
    };
    await this.repository.putReport(report);
    return { setId, checked, findings, recovered, complete };
  }

  async #check(
    setId: string,
    pointer: SourcePointer,
    repair: boolean,
  ): Promise<{ findings: CatalogFinding[]; recovered: number }> {
    const findings: CatalogFinding[] = [];
    let applied = await this.#applied(setId, pointer.contentId);
    if (applied < pointer.revision) {
      findings.push({
        code: 'gap',
        contentId: pointer.contentId,
        detail: `catalog ${applied} < source ${pointer.revision}`,
      });
      if (!repair) return { findings, recovered: 0 };
      // Replay the stored facts after the applied revision, in source order.
      let cursor: { pointerRevision: number; effectId: string } | null = null;
      for (;;) {
        const facts = await this.source.effectsForContent(
          pointer.contentId,
          cursor,
          catalogTestOnlyConfig.reconcileBatchSize,
        );
        for (const fact of facts) {
          if (fact.pointerRevision <= applied) continue;
          const receipt = await this.projector.consumeContentFact(setId, fact);
          if (receipt.outcome === 'refused') {
            findings.push({
              code: 'source_unavailable',
              contentId: pointer.contentId,
              detail: receipt.code,
            });
            return { findings, recovered: 0 };
          }
          if (receipt.outcome === 'conflict')
            findings.push({
              code: 'fact_conflict',
              contentId: pointer.contentId,
              detail: fact.effectId,
            });
        }
        const last = facts[facts.length - 1];
        if (last === undefined || facts.length < catalogTestOnlyConfig.reconcileBatchSize) break;
        cursor = { pointerRevision: last.pointerRevision, effectId: last.effectId };
      }
      applied = await this.#applied(setId, pointer.contentId);
      if (applied < pointer.revision) {
        // Content itself lacks the fact: reported, never invented.
        findings.push({
          code: 'source_effect_missing',
          contentId: pointer.contentId,
          detail: `catalog ${applied} < source ${pointer.revision}`,
        });
        return { findings, recovered: 0 };
      }
      return { findings, recovered: 1 };
    }
    if (applied > pointer.revision) {
      findings.push({
        code: 'catalog_ahead',
        contentId: pointer.contentId,
        detail: `catalog ${applied} > source ${pointer.revision}`,
      });
      return { findings, recovered: 0 };
    }
    // Same revision: a visible object must show exactly the current revision.
    const current = await this.#currentVersion(setId, pointer.contentId);
    if (
      pointer.visibility === 'visible' &&
      current?.state === 'listed' &&
      current.publishedRevisionId !== pointer.currentPublishedRevisionId
    )
      findings.push({
        code: 'revision_mismatch',
        contentId: pointer.contentId,
        detail: `${current.publishedRevisionId} != ${pointer.currentPublishedRevisionId ?? 'none'}`,
      });
    if (pointer.visibility !== 'visible' && current?.state === 'listed')
      findings.push({
        code: 'revision_mismatch',
        contentId: pointer.contentId,
        detail: `listed while source is ${pointer.visibility}`,
      });
    return { findings, recovered: 0 };
  }

  async #applied(setId: string, contentId: string): Promise<number> {
    return this.repository.transact(
      async (tx) => (await tx.sourceState(setId, contentId))?.lastAppliedPointerRevision ?? 0,
    );
  }

  async #currentVersion(setId: string, contentId: string): Promise<ItemVersionRecord | null> {
    const versions = await this.repository.versionsForContent(setId, contentId);
    return versions.find((version) => version.validToRevision === null) ?? null;
  }
}
