// D1 test samples (amendment §9). Everything is built at run time; nothing
// harmful is stored in the repository. Generate all sharp-based samples
// before the image pipeline blocks the libvips loaders in this process.
import { constants, crc32, createDeflate, deflateRawSync } from 'node:zlib';

import sharp from 'sharp';

import { standMarker } from '../../src/modules/media/infrastructure/media_tool_limits.js';

const grey = { r: 120, g: 130, b: 140 };

export async function jpeg(width = 64, height = 48): Promise<Buffer> {
  return sharp({ create: { width, height, channels: 3, background: grey } })
    .jpeg()
    .toBuffer();
}

/** A JPEG whose EXIF carries a GPS position and an orientation of 6 (rotate 90°). */
export async function jpegWithGps(): Promise<Buffer> {
  return sharp({ create: { width: 64, height: 32, channels: 3, background: grey } })
    .jpeg()
    .withMetadata({ orientation: 6 })
    .withExif({
      IFD0: { Make: 'Recharge', Model: 'D1 sample' },
      IFD3: {
        GPSLatitudeRef: 'N',
        GPSLatitude: '56/1 57/1 0/1',
        GPSLongitudeRef: 'E',
        GPSLongitude: '24/1 6/1 0/1',
      },
    })
    .toBuffer();
}

export async function png(width = 64, height = 48, sixteenBit = false): Promise<Buffer> {
  const image = sharp({ create: { width, height, channels: 3, background: grey } });
  return (sixteenBit ? image.toColourspace('rgb16') : image).png().toBuffer();
}

export async function webp(): Promise<Buffer> {
  return sharp({ create: { width: 64, height: 48, channels: 3, background: grey } })
    .webp()
    .toBuffer();
}

/** Two 32×32 raw frames: `pageHeight` makes the tall canvas an animation. */
export async function animatedWebp(): Promise<Buffer> {
  const frames = Buffer.alloc(32 * 64 * 3, 120);
  frames.fill(30, 32 * 32 * 3);
  return sharp(frames, { raw: { width: 32, height: 64, channels: 3, pageHeight: 32 } })
    .webp({ loop: 0, delay: [100, 100] })
    .toBuffer();
}

export async function gif(): Promise<Buffer> {
  return sharp({ create: { width: 16, height: 16, channels: 3, background: grey } })
    .gif()
    .toBuffer();
}

export async function tiff(): Promise<Buffer> {
  return sharp({ create: { width: 16, height: 16, channels: 3, background: grey } })
    .tiff()
    .toBuffer();
}

export const svg = Buffer.from(
  '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><rect width="16" height="16"/></svg>',
);
export const xmlSvg = Buffer.from(
  '<?xml version="1.0"?><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"></svg>',
);
export const html = Buffer.from(
  '<!doctype html><html><body><script>alert(1)</script></body></html>',
);
/** "MZ" and a PE header shape: an executable pretending to be a picture. */
export const exeHeader = Buffer.concat([
  Buffer.from('MZ'),
  Buffer.alloc(58),
  Buffer.from('PE\0\0'),
]);

export function truncated(bytes: Buffer, keep = 0.6): Buffer {
  return bytes.subarray(0, Math.floor(bytes.length * keep));
}

export function corruptHeader(bytes: Buffer): Buffer {
  const copy = Buffer.from(bytes);
  copy.fill(0, 4, 24);
  return copy;
}

function pngChunk(type: string, data: Buffer): Buffer {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length, 0);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body), 0);
  return Buffer.concat([length, body, crc]);
}

function pngHeader(width: number, height: number): Buffer {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr.writeUInt8(8, 8); // bit depth
  ihdr.writeUInt8(0, 9); // greyscale
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    pngChunk('IHDR', ihdr),
  ]);
}

/** 30000×30000 declared, a few bytes of pixels: the header alone must refuse it. */
export function pixelBombPng(): Buffer {
  return Buffer.concat([
    pngHeader(30_000, 30_000),
    pngChunk('IDAT', deflateRawSync(Buffer.alloc(64))),
    pngChunk('IEND', Buffer.alloc(0)),
  ]);
}

/** 20000×20000 of zeros compressed below 1 MiB: 400 MB once decoded. */
export function decompressionBombPng(): Promise<Buffer> {
  const side = 20_000;
  return new Promise((resolve, reject) => {
    const deflate = createDeflate({ level: constants.Z_BEST_COMPRESSION });
    const chunks: Buffer[] = [];
    deflate.on('data', (chunk: Buffer) => chunks.push(chunk));
    deflate.on('error', reject);
    deflate.on('end', () =>
      resolve(
        Buffer.concat([
          pngHeader(side, side),
          pngChunk('IDAT', Buffer.concat(chunks)),
          pngChunk('IEND', Buffer.alloc(0)),
        ]),
      ),
    );
    const row = Buffer.alloc(side + 1); // filter byte + pixels
    let written = 0;
    const pump = () => {
      while (written < side) {
        written += 1;
        if (!deflate.write(row)) return deflate.once('drain', pump);
      }
      deflate.end();
    };
    pump();
  });
}

interface ZipEntry {
  readonly name: string;
  readonly data: Buffer;
}

/** A minimal deflate ZIP (local headers, central directory, end record). */
export function zip(entries: readonly ZipEntry[]): Buffer {
  const locals: Buffer[] = [];
  const centrals: Buffer[] = [];
  let offset = 0;
  for (const entry of entries) {
    const name = Buffer.from(entry.name, 'utf8');
    const packed = deflateRawSync(entry.data);
    const crc = crc32(entry.data);
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(8, 8); // deflate
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(packed.length, 18);
    local.writeUInt32LE(entry.data.length, 22);
    local.writeUInt16LE(name.length, 26);
    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4);
    central.writeUInt16LE(20, 6);
    central.writeUInt16LE(8, 10);
    central.writeUInt32LE(crc, 16);
    central.writeUInt32LE(packed.length, 20);
    central.writeUInt32LE(entry.data.length, 24);
    central.writeUInt16LE(name.length, 28);
    central.writeUInt32LE(offset, 42);
    locals.push(local, name, packed);
    centrals.push(central, name);
    offset += local.length + name.length + packed.length;
  }
  const directory = Buffer.concat(centrals);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(entries.length, 8);
  end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(directory.length, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...locals, directory, end]);
}

/** The stand signature as plain bytes (harmless; only clamd's stand database knows it). */
export const markerText = Buffer.from(`report ${standMarker} end`, 'ascii');

/** A JPEG with the stand marker inside a deflated ZIP appended after the image. */
export async function jpegWithZippedMarker(): Promise<Buffer> {
  return Buffer.concat([await jpeg(), zip([{ name: 'note.txt', data: markerText }])]);
}

/** A JPEG followed by an HTML/JS tail: scans clean, the variants must drop the tail. */
export const polyglotTail = 'RECHARGE-POLYGLOT-TAIL-<script>alert(1)</script>';
export async function jpegWithHtmlTail(): Promise<Buffer> {
  return Buffer.concat([await jpeg(), Buffer.from(polyglotTail, 'ascii')]);
}

/** ZIPs nested deeper than clamd's MaxRecursion (8). */
export function nestedZip(depth: number): Buffer {
  let inner = zip([{ name: 'leaf.txt', data: Buffer.from('leaf') }]);
  for (let level = 1; level < depth; level += 1)
    inner = zip([{ name: `level-${level}.zip`, data: inner }]);
  return inner;
}

/** EICAR, assembled only in memory, never written anywhere (Linux gate only, §8). */
export function eicarInMemory(): Buffer {
  const parts = ['X5O!P%@AP[4\\PZX54(P^)7CC)7}$', 'EICAR-STANDARD-ANTIVIRUS-TEST-FILE!', '$H+H*'];
  return Buffer.from(parts.join(''), 'ascii');
}
