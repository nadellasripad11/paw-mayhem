// tiny png encoder + noise helpers for the lobby texture generator (no deps).
const zlib = require('zlib');

const CRC = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
// rgba: uint8array of w*h*4
function encode(w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    Buffer.from(rgba.buffer, rgba.byteOffset + y * w * 4, w * 4).copy(raw, y * (w * 4 + 1) + 1);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8;
  ihdr[9] = 6; // rgba
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

// seeded random + tileable value noise / fbm.
function rng(seed) {
  let s = seed >>> 0 || 1;
  return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296);
}
function makeNoise(seed, period) {
  const r = rng(seed);
  const g = new Float32Array(period * period).map(() => r());
  const at = (x, y) => g[((y % period + period) % period) * period + ((x % period + period) % period)];
  const sm = (t) => t * t * (3 - 2 * t);
  return (x, y) => {
    const xi = Math.floor(x), yi = Math.floor(y);
    const fx = sm(x - xi), fy = sm(y - yi);
    const a = at(xi, yi), b = at(xi + 1, yi), c = at(xi, yi + 1), d = at(xi + 1, yi + 1);
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
  };
}
// fbm over [0,1) uv, tileable: base period p doubles per octave.
function fbm(seed, p, oct) {
  const ns = [];
  for (let o = 0; o < oct; o++) ns.push(makeNoise(seed + o * 101, p << o));
  return (u, v) => {
    let s = 0, amp = 0.5, tot = 0;
    for (let o = 0; o < oct; o++) {
      const per = p << o;
      s += ns[o](u * per, v * per) * amp;
      tot += amp;
      amp *= 0.5;
    }
    return s / tot;
  };
}

// height field (float32 w*h, 0..1) -> tangent-space normal map rgba (opengl / gltf: +y up).
function normalFromHeight(w, h, H, strength) {
  const out = new Uint8Array(w * h * 4);
  const at = (x, y) => H[((y + h) % h) * w + ((x + w) % w)];
  for (let y = 0; y < h; y++)
    for (let x = 0; x < w; x++) {
      const dx = (at(x + 1, y) - at(x - 1, y)) * strength;
      const dy = (at(x, y + 1) - at(x, y - 1)) * strength;
      let nx = -dx, ny = dy, nz = 1;
      const l = Math.hypot(nx, ny, nz);
      const i = (y * w + x) * 4;
      out[i] = ((nx / l) * 0.5 + 0.5) * 255;
      out[i + 1] = ((ny / l) * 0.5 + 0.5) * 255;
      out[i + 2] = ((nz / l) * 0.5 + 0.5) * 255;
      out[i + 3] = 255;
    }
  return out;
}

module.exports = { encode, rng, makeNoise, fbm, normalFromHeight };
