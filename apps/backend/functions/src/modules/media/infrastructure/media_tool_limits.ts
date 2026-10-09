/**
 * D1 local tool limits (docs/product/MEDIA_D1_REAL_TOOLS_AMENDMENT.md §4).
 * LOCAL TEST VALUES of the Emulator stand: they do not decide BCK14-OD-03
 * (formats and limits), OD-04 (variant profiles) or OD-05 (scanner, timeout,
 * inconclusive).
 */

/** The harmless stand signature (L1); `scripts/media-tools.mjs` writes the same. */
export const standMarker = 'RECHARGE-D1-STAND-MARKER-NOT-MALWARE';
export const standSignatureName = 'Recharge.Test.Marker';
export const standDatabaseRevision = 'stand-marker-1';

export const imageFormats = Object.freeze(['jpeg', 'png', 'webp'] as const);
export type ImageFormat = (typeof imageFormats)[number];

export const imageInputLimits = Object.freeze({
  maxBytes: 1_048_576,
  maxPixels: 24_000_000,
  maxWidth: 6000,
  maxHeight: 6000,
  maxChannels: 4,
  depths: Object.freeze(['uchar', 'ushort']),
  pages: 1,
});

export interface VariantProfile {
  readonly fit: 'inside' | 'cover';
  readonly width: number;
  readonly height: number;
  readonly quality: number;
  readonly effort: number;
}

export const variantProfiles: Readonly<Record<string, VariantProfile>> = Object.freeze({
  display: Object.freeze({ fit: 'inside', width: 1600, height: 1600, quality: 80, effort: 4 }),
  thumb: Object.freeze({ fit: 'cover', width: 320, height: 320, quality: 75, effort: 4 }),
});

export const maxVariantBytes = 409_600;
export const transformProfileRevision = 'd1-local-1';

export const processorDeadlines = Object.freeze({
  pipelineSeconds: 8,
  jobMs: 15_000,
  recycleAfterJobs: 100,
});

export const admissionLimits = Object.freeze({
  process: Object.freeze({ active: 1, waiting: 2, waitMs: 5_000 }),
  scan: Object.freeze({ active: 2, waiting: 4, waitMs: 5_000 }),
  maxConnections: 11,
});

export const scannerDeadlines = Object.freeze({
  connectMs: 2_000,
  replyMs: 10_000,
  totalMs: 20_000,
  chunkBytes: 65_536,
});

export const clientDeadlines = Object.freeze({
  connectMs: 2_000,
  scanMs: 20_000,
  processMs: 25_000,
  maxResponseBytes: 1_200_000,
});

/** An official `daily` older than this is stale (§7). */
export const databaseMaxAgeMs = 7 * 24 * 60 * 60 * 1000;
