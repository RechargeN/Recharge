// D1 image pipeline on the real sharp/libvips (amendment §4.4–4.7, §5, §6, §9).
// Runs under `npm run test:media-tools`; needs the installed native sharp.
import assert from 'node:assert/strict';
import test from 'node:test';

import sharp from 'sharp';

import {
  configurePipeline,
  processImage,
  type PipelineOutcome,
} from '../../src/modules/media/infrastructure/image_pipeline.js';
import { maxVariantBytes } from '../../src/modules/media/infrastructure/media_tool_limits.js';
import * as samples from '../support/media_samples.js';

const profiles = ['display', 'thumb'];

// Every sharp-made sample first: the pipeline blocks libvips loaders for the
// whole process once it is configured.
const built = {
  gps: await samples.jpegWithGps(),
  jpeg: await samples.jpeg(),
  png: await samples.png(),
  png16: await samples.png(64, 48, true),
  webp: await samples.webp(),
  animated: await samples.animatedWebp(),
  gif: await samples.gif(),
  tiff: await samples.tiff(),
  polyglot: await samples.jpegWithHtmlTail(),
  bigPng: await samples.png(4000, 4000),
  decompressionBomb: await samples.decompressionBombPng(),
  wide: await samples.png(6001, 2),
};
const pngForTruncation = await samples.png(256, 256);

function succeeded(outcome: PipelineOutcome) {
  assert.equal(outcome.result, 'succeeded', JSON.stringify(outcome));
  if (outcome.result !== 'succeeded') throw new Error('unreachable');
  return outcome;
}

function rejectedWith(outcome: PipelineOutcome, reason: string) {
  if (outcome.result !== 'rejected') assert.fail(`expected rejected: ${JSON.stringify(outcome)}`);
  assert.equal(outcome.reason, reason);
}

void test('the native win32/linux binding is loaded, never the WebAssembly fallback', () => {
  const runtime = configurePipeline();
  assert.equal(runtime.native, true);
  assert.match(runtime.binding ?? '', /sharp-(win32|linux)-x64[\\/]lib[\\/]sharp-/u);
  assert.match(runtime.toolRevision, /^sharp-0\.35\.5\/libvips-[\d.]+\/\w+-x64-native$/u);
});

void test('EXIF and GPS never survive: orientation applied, every variant bare', async () => {
  const source = await sharp(built.gps).metadata();
  assert.ok(source.exif !== undefined, 'the sample carries EXIF');
  assert.ok(built.gps.includes(Buffer.from('Exif\0\0', 'binary')));
  const outcome = succeeded(await processImage(built.gps, profiles));
  assert.deepEqual(
    outcome.variants.map((variant) => variant.profile),
    profiles,
  );
  for (const variant of outcome.variants) {
    const metadata = await sharp(variant.bytes).metadata();
    assert.equal(metadata.format, 'webp');
    assert.equal(metadata.exif, undefined);
    assert.equal(metadata.icc, undefined);
    assert.equal(metadata.xmp, undefined);
    assert.equal(metadata.iptc, undefined);
    for (const marker of ['Exif\0\0', 'EXIF', 'XMP ', 'ICCP', 'GPS', 'Recharge'])
      assert.equal(variant.bytes.includes(Buffer.from(marker, 'binary')), false, marker);
    assert.ok(variant.byteLength <= maxVariantBytes);
  }
  const display = outcome.variants.find((variant) => variant.profile === 'display');
  assert.ok(display !== undefined && display.height > display.width, 'orientation 6 applied');
});

void test('JPEG, PNG (8 and 16 bit) and WebP are processed into bounded WebP variants', async () => {
  for (const bytes of [built.jpeg, built.png, built.png16, built.webp]) {
    const outcome = succeeded(await processImage(bytes, profiles));
    for (const variant of outcome.variants) {
      assert.equal(variant.format, 'image/webp');
      assert.ok(variant.width <= 1600 && variant.height <= 1600);
    }
  }
  const large = succeeded(await processImage(built.bigPng, profiles));
  const display = large.variants.find((variant) => variant.profile === 'display');
  const thumb = large.variants.find((variant) => variant.profile === 'thumb');
  assert.deepEqual([display?.width, display?.height], [1600, 1600]);
  assert.deepEqual([thumb?.width, thumb?.height], [320, 320]);
});

void test('SVG, GIF, TIFF, HTML and executables are refused by the first bytes', async () => {
  for (const bytes of [
    samples.svg,
    samples.xmlSvg,
    built.gif,
    built.tiff,
    samples.html,
    samples.exeHeader,
  ])
    rejectedWith(await processImage(bytes, profiles), 'signature_mismatch');
});

void test('the blocked libvips loaders refuse SVG, GIF and TIFF even past the byte check', async () => {
  configurePipeline();
  for (const bytes of [samples.svg, built.gif, built.tiff])
    await assert.rejects(sharp(bytes).metadata(), /unsupported image format/u);
  await sharp(built.jpeg).metadata();
});

void test('pixel and decompression bombs are refused from the header, before decoding', async () => {
  assert.ok(built.decompressionBomb.length < 1_048_576, 'the bomb fits the byte limit');
  const before = process.memoryUsage().rss;
  // sharp's own limitInputPixels fires on the header read.
  rejectedWith(await processImage(samples.pixelBombPng(), profiles), 'pixel_limit');
  rejectedWith(await processImage(built.decompressionBomb, profiles), 'pixel_limit');
  assert.ok(process.memoryUsage().rss - before < 150 * 1024 * 1024, 'nothing was decoded');
  // Few pixels but wider than 6000: the service's own dimension check.
  rejectedWith(await processImage(built.wide, profiles), 'dimension_limit');
});

void test('truncated and corrupt files are rejected', async () => {
  rejectedWith(await processImage(samples.truncated(built.jpeg), profiles), 'decode_failed');
  rejectedWith(await processImage(samples.truncated(pngForTruncation), profiles), 'decode_failed');
  const corrupt = await processImage(samples.corruptHeader(built.png), profiles);
  assert.equal(corrupt.result, 'rejected');
});

void test('an animated WebP is refused; only one frame is allowed', async () => {
  rejectedWith(await processImage(built.animated, profiles), 'multiple_frames');
});

void test('a polyglot tail is not carried into the variants', async () => {
  const outcome = succeeded(await processImage(built.polyglot, profiles));
  for (const variant of outcome.variants)
    assert.equal(variant.bytes.includes(Buffer.from('RECHARGE-POLYGLOT-TAIL')), false);
});

void test('the transform is deterministic: the same input gives the same variants', async () => {
  const first = succeeded(await processImage(built.gps, profiles));
  const second = succeeded(await processImage(built.gps, profiles));
  assert.deepEqual(
    first.variants.map((variant) => variant.sha256),
    second.variants.map((variant) => variant.sha256),
  );
});

void test('oversized input and unknown profiles fail closed', async () => {
  rejectedWith(await processImage(Buffer.alloc(1_048_577, 0xff), profiles), 'too_large');
  const unknown = await processImage(built.jpeg, ['display', 'poster']);
  assert.equal(unknown.result, 'failed');
});
