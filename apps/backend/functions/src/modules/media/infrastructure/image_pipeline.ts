import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';

import sharp, { type Metadata, type OutputInfo } from 'sharp';

import {
  imageFormats,
  imageInputLimits,
  maxVariantBytes,
  processorDeadlines,
  transformProfileRevision,
  variantProfiles,
  type ImageFormat,
} from './media_tool_limits.js';

/**
 * D1 image pipeline (amendment §4.4–4.7, §5, §6), run only inside the local
 * tools service's worker process — never in the Functions runtime. Only the
 * JPEG, PNG and WebP loaders of libvips stay unblocked, so SVG, GIF, TIFF,
 * HEIF, PDF and the rest are refused by the decoder itself. Output carries no
 * metadata: no EXIF, XMP, IPTC or ICC.
 */

const allowedLoaders = ['VipsForeignLoadJpeg', 'VipsForeignLoadPng', 'VipsForeignLoadWebp'];
let configured = false;

export interface PipelineRuntime {
  readonly toolRevision: string;
  readonly native: boolean;
  readonly binding: string | null;
}

/** Blocks every libvips loader except JPEG/PNG/WebP; one thread, no cache. */
export function configurePipeline(): PipelineRuntime {
  if (!configured) {
    sharp.block({ operation: ['VipsForeignLoad'] });
    sharp.unblock({ operation: allowedLoaders });
    sharp.concurrency(1);
    sharp.cache(false);
    configured = true;
  }
  const binding = loadedBinding();
  return {
    toolRevision: `sharp-${sharp.versions.sharp}/libvips-${sharp.versions.vips}/${process.platform}-${process.arch}-${binding === null ? 'not-native' : 'native'}`,
    native: binding !== null,
    binding,
  };
}

/** The native `@img/sharp-<platform>` binding, or null if anything else is loaded. */
export function loadedBinding(): string | null {
  const keys = Object.keys(createRequire(import.meta.url).cache);
  if (keys.some((key) => /sharp-wasm32/u.test(key))) return null;
  const expected = new RegExp(
    `[\\\\/]@img[\\\\/]sharp-${process.platform}-${process.arch}[\\\\/]lib[\\\\/]sharp-${process.platform}-${process.arch}-[\\d.]+\\.node$`,
    'u',
  );
  return keys.find((key) => expected.test(key)) ?? null;
}

export interface PipelineVariant {
  readonly profile: string;
  readonly format: 'image/webp';
  readonly width: number;
  readonly height: number;
  readonly byteLength: number;
  readonly sha256: string;
  readonly bytes: Buffer;
}

export type PipelineOutcome =
  | {
      readonly result: 'succeeded';
      readonly toolRevision: string;
      readonly transformProfileRevision: string;
      readonly variants: readonly PipelineVariant[];
    }
  | {
      readonly result: 'rejected' | 'failed';
      readonly toolRevision: string;
      readonly reason: string;
    };

/** First-bytes type, the same rule as `detectMediaType` in the object store. */
export function sniffFormat(bytes: Buffer): ImageFormat | null {
  if (
    bytes.length >= 8 &&
    bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
  )
    return 'png';
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff)
    return 'jpeg';
  if (
    bytes.length >= 12 &&
    bytes.subarray(0, 4).toString('ascii') === 'RIFF' &&
    bytes.subarray(8, 12).toString('ascii') === 'WEBP'
  )
    return 'webp';
  return null;
}

const inputOptions = Object.freeze({
  failOn: 'warning',
  limitInputPixels: imageInputLimits.maxPixels,
  unlimited: false,
  sequentialRead: true,
  pages: 1,
  page: 0,
  animated: false,
} as const);

/** Resource failures stay retryable (`failed`); content failures block (`rejected`). */
function classify(error: unknown): { result: 'rejected' | 'failed'; reason: string } {
  const message = error instanceof Error ? error.message : String(error);
  if (/timeout/iu.test(message)) return { result: 'failed', reason: 'pipeline_timeout' };
  if (/out of memory|memory allocation|bad_alloc/iu.test(message))
    return { result: 'failed', reason: 'pipeline_memory' };
  if (/pixel limit/iu.test(message)) return { result: 'rejected', reason: 'pixel_limit' };
  if (/unsupported image format/iu.test(message))
    return { result: 'rejected', reason: 'format_not_allowed' };
  return { result: 'rejected', reason: 'decode_failed' };
}

/** No metadata may survive into a variant; the WebP chunks are checked too. */
function carriesMetadata(bytes: Buffer, metadata: Metadata): boolean {
  if (
    metadata.exif !== undefined ||
    metadata.icc !== undefined ||
    metadata.iptc !== undefined ||
    metadata.xmp !== undefined ||
    metadata.hasProfile === true
  )
    return true;
  for (let offset = 12; offset + 8 <= bytes.length;) {
    const chunk = bytes.subarray(offset, offset + 4).toString('ascii');
    if (chunk === 'EXIF' || chunk === 'XMP ' || chunk === 'ICCP') return true;
    const size = bytes.readUInt32LE(offset + 4);
    offset += 8 + size + (size % 2);
  }
  return false;
}

export async function processImage(
  bytes: Buffer,
  profiles: readonly string[],
): Promise<PipelineOutcome> {
  const runtime = configurePipeline();
  const toolRevision = runtime.toolRevision;
  if (!runtime.native) return { result: 'failed', toolRevision, reason: 'native_binding_missing' };
  if (bytes.length > imageInputLimits.maxBytes)
    return { result: 'rejected', toolRevision, reason: 'too_large' };
  const sniffed = sniffFormat(bytes);
  if (sniffed === null) return { result: 'rejected', toolRevision, reason: 'signature_mismatch' };
  for (const profile of profiles)
    if (variantProfiles[profile] === undefined)
      return { result: 'failed', toolRevision, reason: 'unknown_profile' };

  let metadata: Metadata;
  try {
    metadata = await sharp(bytes, inputOptions).metadata();
  } catch (error) {
    return { toolRevision, ...classify(error) };
  }
  const format = metadata.format as string | undefined;
  if (!(imageFormats as readonly string[]).includes(format ?? '') || format !== sniffed)
    return { result: 'rejected', toolRevision, reason: 'format_mismatch' };
  const width = metadata.width;
  const height = metadata.height;
  if (
    width === undefined ||
    height === undefined ||
    width < 1 ||
    height < 1 ||
    width > imageInputLimits.maxWidth ||
    height > imageInputLimits.maxHeight ||
    width * height > imageInputLimits.maxPixels
  )
    return { result: 'rejected', toolRevision, reason: 'dimension_limit' };
  if (
    metadata.channels === undefined ||
    metadata.channels < 1 ||
    metadata.channels > imageInputLimits.maxChannels
  )
    return { result: 'rejected', toolRevision, reason: 'channel_limit' };
  if (!imageInputLimits.depths.includes(metadata.depth ?? ''))
    return { result: 'rejected', toolRevision, reason: 'depth_not_allowed' };
  if ((metadata.pages ?? 1) !== imageInputLimits.pages)
    return { result: 'rejected', toolRevision, reason: 'multiple_frames' };

  const variants: PipelineVariant[] = [];
  for (const profile of profiles) {
    const spec = variantProfiles[profile];
    if (spec === undefined) return { result: 'failed', toolRevision, reason: 'unknown_profile' };
    let output: { data: Buffer; info: OutputInfo };
    try {
      output = await sharp(bytes, { ...inputOptions, autoOrient: true })
        .timeout({ seconds: processorDeadlines.pipelineSeconds })
        .resize({
          width: spec.width,
          height: spec.height,
          fit: spec.fit,
          withoutEnlargement: true,
        })
        .webp({ quality: spec.quality, effort: spec.effort })
        .toBuffer({ resolveWithObject: true });
    } catch (error) {
      return { toolRevision, ...classify(error) };
    }
    const { data } = output;
    if (data.length > maxVariantBytes)
      return { result: 'rejected', toolRevision, reason: 'variant_too_large' };
    let check: Metadata;
    try {
      check = await sharp(data, inputOptions).metadata();
    } catch {
      return { result: 'failed', toolRevision, reason: 'variant_unreadable' };
    }
    if (
      check.format !== 'webp' ||
      check.width === undefined ||
      check.height === undefined ||
      check.width > spec.width ||
      check.height > spec.height ||
      carriesMetadata(data, check)
    )
      return { result: 'failed', toolRevision, reason: 'variant_check_failed' };
    variants.push({
      profile,
      format: 'image/webp',
      width: check.width,
      height: check.height,
      byteLength: data.length,
      sha256: createHash('sha256').update(data).digest('hex'),
      bytes: data,
    });
  }
  return { result: 'succeeded', toolRevision, transformProfileRevision, variants };
}
