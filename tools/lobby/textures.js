// paw mayhem lobby — procedural pbr textures.
//
//   node tools/lobby/textures.js
//
// writes tools/lobby/textures/<set>_{color,normal,orm}.png. two kinds:
//   * tiling sets (stone, plaster, metal, marble, fabric): near-white colour
//     maps that the part's own color tints, turned into materialvariants
//     (pawstone, pawplaster, ...) by tools/lobby/setup_lobby.lua;
//   * baked sets (gold, stoneblock, navy, carpet): real colours (orange paint,
//     cream stone, peach plaster, the patterned carpet).
// "orm" is gltf's metallicroughness map: g = roughness, b = metalness.
// everything tiles seamlessly.

const fs = require('fs');
const path = require('path');
const { encode, rng, fbm, normalFromHeight } = require('./png');

const OUT = path.join(__dirname, 'textures');
fs.mkdirSync(OUT, { recursive: true });

const clamp = (x, a = 0, b = 1) => Math.max(a, Math.min(b, x));

// a set is a function (u, v) -> { h, c: [r,g,b] 0..1, rough, metal }.
function bake(name, size, fn, normalStrength) {
  const H = new Float32Array(size * size);
  const col = new Uint8Array(size * size * 4);
  const orm = new Uint8Array(size * size * 4);
  for (let y = 0; y < size; y++)
    for (let x = 0; x < size; x++) {
      const s = fn(x / size, y / size);
      const i = y * size + x;
      H[i] = s.h;
      col[i * 4] = clamp(s.c[0]) * 255;
      col[i * 4 + 1] = clamp(s.c[1]) * 255;
      col[i * 4 + 2] = clamp(s.c[2]) * 255;
      col[i * 4 + 3] = 255;
      orm[i * 4] = 255;
      orm[i * 4 + 1] = clamp(s.rough) * 255;
      orm[i * 4 + 2] = clamp(s.metal) * 255;
      orm[i * 4 + 3] = 255;
    }
  const nrm = normalFromHeight(size, size, H, normalStrength * size / 256);
  fs.writeFileSync(path.join(OUT, name + '_color.png'), encode(size, size, col));
  fs.writeFileSync(path.join(OUT, name + '_normal.png'), encode(size, size, nrm));
  fs.writeFileSync(path.join(OUT, name + '_orm.png'), encode(size, size, orm));
  console.log('  ' + name);
}

const tint = (k, rgb) => rgb.map((c) => c * k);

// ── stone: 2 x 2 slabs per tile (6 studs each at 12 studs per tile), bevelled
// grout, per-slab tone, fine grain and a few pits.
function stone(base) {
  const grain = fbm(11, 8, 6), cloud = fbm(12, 2, 3), pits = fbm(13, 256, 1), speck = fbm(15, 128, 2);
  const slabTone = rng(14);
  const tones = [0, 1, 2, 3].map(() => 0.93 + slabTone() * 0.1);
  return (u, v) => {
    const su = (u * 2) % 1, sv = (v * 2) % 1;
    const slab = Math.floor(u * 2) + Math.floor(v * 2) * 2;
    const edge = Math.min(su, 1 - su, sv, 1 - sv); // 0 at grout
    const groutW = 0.006, bevel = 0.02;
    const inGrout = edge < groutW;
    const lip = clamp((edge - groutW) / bevel);
    const g = grain(u, v), c = cloud(u, v), p = pits(u, v);
    const pit = p > 0.9 ? (p - 0.9) * 6 : 0;
    const sp = speck(u, v);
    const fleck = sp > 0.7 ? (sp - 0.7) * 0.5 : sp < 0.25 ? -(0.25 - sp) * 0.4 : 0;
    const k = inGrout ? 0.62 : tones[slab] * (0.86 + g * 0.2 + (c - 0.5) * 0.12 + fleck) - pit * 0.2;
    return {
      h: inGrout ? 0 : 0.5 * Math.sqrt(lip) + g * 0.12 - pit * 0.2,
      c: tint(k, base),
      rough: inGrout ? 0.95 : 0.74 + g * 0.16,
      metal: 0,
    };
  };
}

// ── stone block (columns, pilasters, the dais): the same grain, no slabs.
function stoneBlock(base) {
  const grain = fbm(21, 8, 5), cloud = fbm(22, 2, 3), fleck = fbm(23, 128, 1);
  return (u, v) => {
    const g = grain(u, v), c = cloud(u, v), f = fleck(u, v);
    const k = 0.9 + g * 0.12 + (c - 0.5) * 0.1 + (f > 0.8 ? 0.05 : 0);
    return { h: g * 0.3 + c * 0.1, c: tint(k, base), rough: 0.72 + g * 0.15, metal: 0 };
  };
}

// ── plaster: soft trowel marks.
function plaster(base) {
  const big = fbm(31, 3, 4), fine = fbm(32, 32, 3);
  return (u, v) => {
    const b = big(u, v), f = fine(u, v);
    const trowel = Math.abs(Math.sin((u * 3 + b * 1.4) * Math.PI * 2)) * 0.5;
    return { h: b * 0.4 + f * 0.15 + trowel * 0.15, c: tint(0.9 + (b - 0.5) * 0.08 + f * 0.04, base), rough: 0.82 + f * 0.1, metal: 0 };
  };
}

// ── brushed metal: long fine streaks along u, soft smudges, a little wear.
function brushed(base, metal, roughBase) {
  const smudge = fbm(41, 2, 3);
  const streakN = fbm(42, 4, 1);
  const r = rng(43);
  const rows = 512;
  const streaks = new Float32Array(rows).map(() => r());
  return (u, v) => {
    const row = Math.floor(v * rows);
    const s = streaks[row] * 0.6 + streakN(u, v * 64 % 1) * 0.4;
    const m = smudge(u, v);
    return {
      h: s * 0.18,
      c: tint(0.9 + (s - 0.5) * 0.12 + (m - 0.5) * 0.06, base),
      rough: roughBase + (s - 0.5) * 0.1 + (m - 0.5) * 0.12,
      metal,
    };
  };
}

// ── marble: soft veins.
function marble(base) {
  const warp = fbm(51, 2, 6), warp2 = fbm(53, 4, 5), fine = fbm(52, 16, 3), strength = fbm(54, 3, 3);
  return (u, v) => {
    const w = warp(u, v);
    const main = Math.pow(1 - Math.abs(Math.sin((u + v + w * 2.6) * Math.PI * 2)), 40) * clamp((strength(u, v) - 0.3) * 2.5);
    const thin = Math.pow(1 - Math.abs(Math.sin((u - v * 2 + warp2(u, v) * 3) * Math.PI * 3)), 90) * 0.5;
    const vein = Math.min(1, main + thin);
    const f = fine(u, v);
    return { h: f * 0.05, c: tint(0.93 - vein * 0.32 + (w - 0.5) * 0.06 + (f - 0.5) * 0.04, base), rough: 0.18 + vein * 0.2, metal: 0 };
  };
}

// ── fabric: a plain weave.
function fabric(base) {
  const fuzz = fbm(61, 32, 3);
  const n = 96;
  return (u, v) => {
    const a = Math.sin(u * n * Math.PI * 2), b = Math.sin(v * n * Math.PI * 2);
    const over = (Math.floor(u * n * 2) + Math.floor(v * n * 2)) % 2 === 0;
    const h = (over ? Math.abs(a) : Math.abs(b)) * 0.6 + fuzz(u, v) * 0.4;
    return { h, c: tint(0.82 + h * 0.18, base), rough: 0.95, metal: 0 };
  };
}

// ── carpet: a 70s honeycomb, baked in real colours (not tinted). small
// hexagons packed edge to edge, each drawn as concentric hex rings (brown
// outline, orange, rust, peach, rust, a brown centre) like an old cinema
// carpet, with a soft pile and a little mottling. 7 x 8 hexagons per tile
// (the rows are 1% short of a true hex grid, so it tiles seamlessly).
function carpet() {
  const pile = fbm(71, 64, 3), mottle = fbm(72, 3, 3);
  const N = 7, M = 8;
  const brown = lin(104, 56, 34), orange = lin(214, 112, 48), rust = lin(168, 74, 38), peach = lin(232, 160, 102);
  const S3 = Math.sqrt(3);
  return (u, v) => {
    // nearest hexagon centre (rows offset by half a cell on odd rows)
    let best = 1e9, bx = 0, by = 0;
    const j0 = Math.floor(v * M);
    for (let dj = -1; dj <= 1; dj++) {
      const j = j0 + dj;
      const off = (((j % 2) + 2) % 2) * 0.5;
      const i0 = Math.floor(u * N - off);
      for (let di = -1; di <= 1; di++) {
        const cx = (i0 + di + off + 0.5) / N, cy = (j + 0.5) / M;
        const x = (u - cx) * N, y = (v - cy) * N;
        const d = x * x + y * y;
        if (d < best) { best = d; bx = x; by = y; }
      }
    }
    const ax = Math.abs(bx), ay = Math.abs(by);
    const t = Math.max(ax, (ax + S3 * ay) / 2) / 0.5; // 0 centre .. 1 edge
    let c;
    if (t > 0.86) c = brown;
    else if (t > 0.68) c = orange;
    else if (t > 0.5) c = rust;
    else if (t > 0.33) c = peach;
    else if (t > 0.18) c = rust;
    else c = brown;
    const f = pile(u, v), m = mottle(u, v);
    return { h: f * 0.7 + (t > 0.86 ? -0.15 : 0), c: tint(0.88 + f * 0.12 + (m - 0.5) * 0.06, c), rough: 0.96, metal: 0 };
  };
}

const NEUTRAL = [0.97, 0.96, 0.94];
const lin = (r, g, b) => [r / 255, g / 255, b / 255];

console.log('tiling sets:');
bake('Stone', 1024, stone(NEUTRAL), 2.2);
bake('Plaster', 1024, plaster(NEUTRAL), 1.2);
bake('Metal', 1024, brushed(NEUTRAL, 1, 0.34), 0.8);
bake('Grain', 1024, stoneBlock(NEUTRAL), 1.6);
bake('Marble', 1024, marble(NEUTRAL), 0.6);
bake('Fabric', 512, fabric(NEUTRAL), 1.6);
bake('Carpet', 1024, carpet(), 1.2);
console.log('baked sets:');
// (the names stay so lobbymeshdata keeps working; the colours are the retro
// palette now: "gold" is matte orange paint, "stoneblock" cream stone, "navy"
// peach plaster. see shared/lobbypalette.)
bake('Gold', 1024, plaster(lin(242, 147, 58)), 0.6);
bake('StoneBlock', 1024, stoneBlock(lin(239, 224, 202)), 1.6);
bake('Navy', 512, plaster(lin(248, 192, 138)), 1.0);
bake('Cream', 256, stoneBlock(lin(246, 236, 214)), 0.3);
