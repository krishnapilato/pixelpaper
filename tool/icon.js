// Draws the PixelPaper mark and writes every raster the project needs:
// the launcher mipmaps and the 512 px icon Google Play asks for.
//
//   node tool/icon.js
//
// The mark is an A4 sheet whose corner comes away as pixels — paper turning
// into an image. The vector version lives in
// android/app/src/main/res/drawable/ic_launcher_foreground.xml and must be
// kept in step with the geometry below.
//
// No dependencies: PNGs are encoded here with zlib from Node's standard
// library, so the icon can be regenerated on any machine with Node.

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const SS = 4; // supersampling, for antialiased edges

// Geometry in the 108x108 adaptive-icon viewport, inside the 66 dp safe circle.
const PAGE = { x0: 31, y0: 32, x1: 59, y1: 72, r: 3 };
const PIXELS = [
  { x0: 62, y0: 52, x1: 72, y1: 62, r: 1.5 },
  { x0: 74, y0: 65, x1: 81, y1: 72, r: 1 },
];

const BLUE = [0x4c, 0x8d, 0xff]; // the theme seed
const WHITE = [0xff, 0xff, 0xff];

function inRoundedRect(x, y, s) {
  if (x < s.x0 || x > s.x1 || y < s.y0 || y > s.y1) return false;
  const cx = Math.min(Math.max(x, s.x0 + s.r), s.x1 - s.r);
  const cy = Math.min(Math.max(y, s.y0 + s.r), s.y1 - s.r);
  return (x - cx) ** 2 + (y - cy) ** 2 <= s.r * s.r + 1e-9;
}

/// scale: how much of the canvas the mark fills. rounded: bake rounded corners
/// (launcher icons) or leave the square full-bleed (Play, which masks itself).
function sample(u, v, { scale, rounded }) {
  const x = 54 + (u * 108 - 54) / scale;
  const y = 54 + (v * 108 - 54) / scale;
  if (inRoundedRect(x, y, PAGE)) return WHITE;
  for (const p of PIXELS) if (inRoundedRect(x, y, p)) return WHITE;
  const bg = { x0: 0, y0: 0, x1: 108, y1: 108, r: rounded ? 24 : 0 };
  if (inRoundedRect(u * 108, v * 108, bg)) return BLUE;
  return null; // transparent
}

let table = null;
function crc32(buf) {
  if (!table) {
    table = [];
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      table[n] = c >>> 0;
    }
  }
  let c = 0xffffffff;
  for (const b of buf) c = table[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function png(size, opts) {
  const raw = Buffer.alloc(size * (size * 4 + 1));
  for (let y = 0; y < size; y++) {
    raw[y * (size * 4 + 1)] = 0; // filter: none
    for (let x = 0; x < size; x++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let sy = 0; sy < SS; sy++) {
        for (let sx = 0; sx < SS; sx++) {
          const c = sample((x + (sx + 0.5) / SS) / size, (y + (sy + 0.5) / SS) / size, opts);
          if (c) { r += c[0]; g += c[1]; b += c[2]; a += 255; }
        }
      }
      const n = SS * SS;
      const o = y * (size * 4 + 1) + 1 + x * 4;
      raw[o] = a ? Math.round(r / (a / 255)) : 0;
      raw[o + 1] = a ? Math.round(g / (a / 255)) : 0;
      raw[o + 2] = a ? Math.round(b / (a / 255)) : 0;
      raw[o + 3] = Math.round(a / n);
    }
  }

  const chunk = (type, data) => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(body));
    return Buffer.concat([len, body, crc]);
  };

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // colour type: RGBA

  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function write(file, buffer) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, buffer);
  console.log(`${file}  ${Math.round(buffer.length / 1024)} KB`);
}

// Launcher icons: rounded, mark filling more of the square since there is no
// adaptive-icon mask to respect.
const launcher = { scale: 1.22, rounded: true };
for (const [density, size] of Object.entries({
  mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192,
})) {
  write(`android/app/src/main/res/mipmap-${density}/ic_launcher.png`, png(size, launcher));
}

// Google Play store listing: 512x512, square, no transparency in the corners —
// Play rounds and shadows it itself, and a pre-rounded icon ends up clipped.
write('store/play-icon-512.png', png(512, { scale: 1.22, rounded: false }));
