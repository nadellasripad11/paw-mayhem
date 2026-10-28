// paw mayhem — procedural 3d models for the blasters and the maps.
//
//   node tools/models/game_meshes.js
//
// writes
//   assets/gamemeshes.glb                      every mesh (no textures: each
//                                              piece is tinted and given a
//                                              roblox material in the game, so
//                                              skins and map themes still work)
//   src/replicatedstorage/shared/gamemeshdata.lua  sizes / centres / gun layout
//   tools/models/setup_game.lua                the one-paste studio setup
//
// blasters: every design in blasterdesigns.json, rebuilt piece for piece with
// rounded edges (boxes bevelled, cylinders chamfered) and merged into one
// mesh per colour slot, so a gun is 4-6 smooth parts instead of 20-30 blocks.
// map props: trees, pines, bushes, rocks, crates, lamps, island cliffs and
// rock undersides (the duel maps), toy props (toybox), rooftop props
// (rooftops). sky islands and volcano are left as they are.
//
// roblox axes, studs. props: origin at the bottom centre unless noted.
// "unit" meshes (u_*) fill a 1 x 1 x 1 box centred on the origin and are
// stretched to the part they replace.

const fs = require('fs');
const path = require('path');
const { V, Mesh, grid, lathe, roundedBox, sweep, tube, circle, uvBox } = require('../lobby/geo');

const ROOT = path.join(__dirname, '..', '..');
const OUT_GLB = path.join(ROOT, 'assets', 'GameMeshes.glb');
const OUT_LUA = path.join(ROOT, 'src', 'ReplicatedStorage', 'Shared', 'GameMeshData.lua');
const OUT_SETUP = path.join(__dirname, 'setup_game.lua');
const DESIGNS = JSON.parse(fs.readFileSync(path.join(ROOT, 'src', 'ReplicatedStorage', 'Shared', 'Character', 'BlasterDesigns.json'), 'utf8'));

const D = Math.PI / 180;
const merge = (...ms) => ms.reduce((a, b) => a.merge(b), new Mesh());
const move = (m, t) => m.transform((p) => V.add(p, t));
const scaleM = (m, s) => m.transform((p) => [p[0] * s[0], p[1] * s[1], p[2] * s[2]]);
const rx = (a) => (p) => [p[0], p[1] * Math.cos(a) - p[2] * Math.sin(a), p[1] * Math.sin(a) + p[2] * Math.cos(a)];
const ry = (a) => (p) => [p[0] * Math.cos(a) + p[2] * Math.sin(a), p[1], -p[0] * Math.sin(a) + p[2] * Math.cos(a)];
const rz = (a) => (p) => [p[0] * Math.cos(a) - p[1] * Math.sin(a), p[0] * Math.sin(a) + p[1] * Math.cos(a), p[2]];
// roblox cframe.angles(x, y, z) = rx * ry * rz (z applied first)
const angles = (m, x, y, z) => m.transform((p) => rx(x)(ry(y)(rz(z)(p))));
const turnY = (m, a) => m.transform(ry(a));

// ── noise ────────────────────────────────────────────────────────────────────
function hash3(x, y, z, seed) {
  let h = (x * 374761393 + y * 668265263 + z * 2147483647 + seed * 144269504) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}
function noise3(p, seed) {
  const [x, y, z] = p;
  const xi = Math.floor(x), yi = Math.floor(y), zi = Math.floor(z);
  const s = (t) => t * t * (3 - 2 * t);
  const fx = s(x - xi), fy = s(y - yi), fz = s(z - zi);
  let out = 0;
  for (let dx = 0; dx <= 1; dx++) for (let dy = 0; dy <= 1; dy++) for (let dz = 0; dz <= 1; dz++)
    out += hash3(xi + dx, yi + dy, zi + dz, seed) * (dx ? fx : 1 - fx) * (dy ? fy : 1 - fy) * (dz ? fz : 1 - fz);
  return out;
}
const fbm3 = (p, seed, oct = 3) => {
  let s = 0, a = 0.5, f = 1, t = 0;
  for (let o = 0; o < oct; o++) {
    s += noise3([p[0] * f, p[1] * f, p[2] * f], seed + o * 17) * a;
    t += a;
    a *= 0.5;
    f *= 2;
  }
  return s / t;
};

// a closed surface round the origin: radius(dir) along each direction.
function radial(rfun, nu = 48, nv = 28, tile = 4) {
  return grid((u, v) => {
    const th = u * Math.PI * 2, ph = (v - 0.5) * Math.PI;
    const dir = [Math.cos(ph) * Math.cos(th), Math.sin(ph), Math.cos(ph) * Math.sin(th)];
    return V.mul(dir, rfun(dir));
  }, nu, nv, { closedU: true, hint: (p) => p, uv: (u, v, p, n) => uvBox(p, n, tile) });
}
// union of spheres seen from the origin (cloud / canopy shapes).
function lobes(spheres, seed, wobble = 0.06) {
  return (dir) => {
    let best = 0;
    for (const [c, r] of spheres) {
      const b = V.dot(dir, c), cc = V.dot(c, c) - r * r;
      const disc = b * b - cc;
      if (disc >= 0) best = Math.max(best, b + Math.sqrt(disc));
    }
    return best * (1 + (fbm3(V.mul(dir, 2.2), seed) - 0.5) * wobble * 2);
  };
}

// ── shapes ───────────────────────────────────────────────────────────────────
const chamfer = (r, len, c) => [
  [[0, -len / 2], [r - c, -len / 2]],
  [[r - c, -len / 2], [r, -len / 2 + c]],
  [[r, -len / 2 + c], [r, len / 2 - c]],
  [[r, len / 2 - c], [r - c, len / 2]],
  [[r - c, len / 2], [0, len / 2]],
];
// cylinder along x (roblox's cylinder axis), chamfered ends
function cylX(len, d, seg = 24) {
  const r = d / 2, c = Math.min(0.04, r * 0.3, len * 0.2);
  return lathe(chamfer(r, len, c), seg, { tile: 1 }).transform(rz(-Math.PI / 2));
}
// cylinder along y
function cylY(len, d, seg = 24, c) {
  const r = d / 2;
  c = c ?? Math.min(0.08, r * 0.3, len * 0.2);
  return move(lathe(chamfer(r, len, c), seg, { tile: 2 }), [0, len / 2, 0]);
}
function sphere(d, seg = 20) {
  const r = d / 2;
  const pts = [];
  for (let i = 0; i <= 12; i++) {
    const a = -Math.PI / 2 + (i / 12) * Math.PI;
    pts.push([Math.max(0, Math.cos(a) * r), Math.sin(a) * r]);
  }
  pts[0][0] = 0;
  pts[12][0] = 0;
  return lathe([pts], seg, { tile: 1 });
}
const bevel = (size, r) => roundedBox(size, Math.min(r, ...size.map((s) => s * 0.22)), [0, 0, 0], 2, 1);

// ── blasters ────────────────────────────────────────────────────────────────
function gunPiece(pc) {
  let m;
  if (pc.k === 'cyl') m = cylX(pc.len, pc.d);
  else if (pc.k === 'ball') m = sphere(pc.d);
  else if (pc.k === 'pill') {
    const mid = Math.max(0.01, pc.len - pc.d);
    m = merge(cylX(mid, pc.d), move(sphere(pc.d), [-mid / 2, 0, 0]), move(sphere(pc.d), [mid / 2, 0, 0]));
  } else m = bevel(pc.size, 0.05);
  const r = pc.rot || [0, 0, 0];
  m = angles(m, r[0] * D, r[1] * D, r[2] * D);
  return move(m, pc.pos);
}
function guns() {
  const out = {};
  const mats = DESIGNS.materials || {};
  for (const [id, pieces] of Object.entries(DESIGNS.designs)) {
    const groups = {};
    let tip = [-Infinity, 0, 0];
    for (const pc of [...pieces, ...DESIGNS.grip]) {
      const mat = pc.m || mats[pc.c] || 'plastic';
      const key = `${pc.c}|${mat}|${pc.t || 0}`;
      (groups[key] = groups[key] || []).push(gunPiece(pc));
      const reach = pc.k === 'cyl' || pc.k === 'pill' ? pc.len / 2 : pc.k === 'ball' ? pc.d / 2 : pc.k === 'wedge' ? 0 : pc.size[0] / 2;
      if (pc.pos[0] + reach > tip[0]) tip = [pc.pos[0] + reach, pc.pos[1], 0];
    }
    const parts = Object.entries(groups).map(([key, ms], i) => {
      const [slot, mat, t] = key.split('|');
      return { name: `Gun_${id}_${i + 1}`, slot, mat, t: Number(t), mesh: merge(...ms) };
    });
    out[id] = { tip, parts };
  }
  return out;
}

// ── trees, pines, bushes, rocks ─────────────────────────────────────────────
function trunk(h, r0, r1, seed) {
  const pts = [];
  for (let i = 0; i <= 10; i++) {
    const t = i / 10;
    pts.push([r1 + (r0 - r1) * Math.pow(1 - t, 3) * 0.6 + (r0 - r1) * 0.4 * (1 - t), t * h]);
  }
  return lathe([pts], 24, {
    tile: 2, rows: 0.4,
    rmod: (th, r, y) => {
      const roots = Math.pow(Math.max(0, Math.cos(th * 5 + seed)), 4) * Math.max(0, 1 - y / (h * 0.18)) * r0 * 0.55;
      const bark = (fbm3([Math.cos(th) * 2, y * 0.9, Math.sin(th) * 2], seed) - 0.5) * r * 0.18;
      return r + roots + bark;
    },
  });
}
function canopy(seed, lobeSet) {
  return radial(lobes(lobeSet, seed, 0.07), 56, 32, 3);
}
function pineFoliage(seed, snowCap) {
  const tiers = [];
  for (let k = 0; k < 4; k++) {
    const R = (7.2 - k * 1.6) / 2, y0 = 2.5 + k * 2.0, h = 3.2;
    // a drooping cone with a scalloped rim
    const pts = [[R * 0.92, y0], [R, y0 + 0.25], [R * 0.55, y0 + h * 0.55], [0.15, y0 + h]];
    const m = lathe([[[0, y0 + 0.1], [R * 0.8, y0 + 0.05], [R * 0.92, y0]], pts], 40, {
      tile: 2, rows: 0.35,
      rmod: (th, r, y) => r * (1 + 0.08 * Math.cos(th * 9 + k * 1.7 + seed) * Math.max(0, 1 - (y - y0) / h)),
    });
    tiers.push(m);
    if (snowCap) {
      const s = lathe([[[R * 0.62, y0 + h * 0.42], [R * 0.4, y0 + h * 0.66], [0.12, y0 + h + 0.12]], [[0.12, y0 + h + 0.12], [0, y0 + h + 0.13]]], 32, {
        tile: 2, rmod: (th, r) => r * (1.06 + 0.05 * Math.cos(th * 7 + k)),
      });
      snowCap.push(s);
    }
  }
  return merge(...tiers);
}
function rockMesh(seed, sx, sy, sz) {
  const m = radial((dir) => {
    const n = fbm3(V.mul(dir, 1.6), seed, 3);
    // faceted: quantise the noise a little
    const q = Math.round(n * 6) / 6;
    return 0.5 * (0.78 + 0.32 * (n * 0.6 + q * 0.4));
  }, 18, 10, 2);
  const out = m.transform((p) => [p[0] * sx, Math.max(p[1], -0.18) * sy, p[2] * sz]);
  return move(out, [0, 0.18 * sy, 0]);
}

// island bits: a cliff column (unit box), a hanging rock (unit box, point
// down), a lumpy rock drum (unit box) for the island's core and tapers, and
// the grass lip (unit box: a disc with a rolled, wavy edge).
function cliffColumn(seed) {
  const sides = 7;
  const loop = [];
  for (let i = 0; i < sides; i++) {
    const a = (i / sides) * Math.PI * 2 + hash3(i, seed, 1, 3) * 0.4;
    const r = 0.42 + hash3(i, seed, 2, 3) * 0.08;
    loop.push([Math.cos(a) * r, Math.sin(a) * r]);
  }
  const f = (u, v) => {
    const t = u * sides, i = Math.floor(t) % sides, w = t - Math.floor(t);
    const a = loop[i], b = loop[(i + 1) % sides];
    const x = a[0] + (b[0] - a[0]) * w, z = a[1] + (b[1] - a[1]) * w;
    const y = -0.5 + v;
    const n = (fbm3([x * 3, y * 4, z * 3], seed) - 0.5) * 0.1;
    const taper = 1 - 0.12 * Math.pow(Math.max(0, -y * 2), 2); // narrower at the bottom
    return [x * taper * (1 + n), y, z * taper * (1 + n)];
  };
  const side = grid(f, sides * 6, 14, { closedU: true, hint: (p) => [p[0], 0, p[2]], uv: (u, v, p, n) => uvBox(p, n, 0.5) });
  // bevelled top and a closed bottom
  const top = grid((u, v) => {
    const p = f(u, 1);
    const k = 1 - v * 0.9;
    return [p[0] * k, 0.5 + 0.06 * Math.sin(v * Math.PI / 2) - 0.03 * v, p[2] * k];
  }, sides * 6, 3, { closedU: true, hint: () => [0, 1, 0], uv: (u, v, p, n) => uvBox(p, n, 0.5) });
  return merge(side, top);
}
function hangRock(seed) {
  return radial((dir) => {
    const down = Math.max(0, -dir[1]);
    const n = fbm3(V.mul(dir, 2), seed);
    return (0.32 + 0.18 * Math.pow(down, 3)) * (0.85 + n * 0.3);
  }, 20, 14, 0.5).transform((p) => [p[0], p[1] < 0 ? p[1] : p[1] * 0.4, p[2]]);
}
function rockDrum(seed) {
  return lathe([[[0, -0.5], [0.42, -0.5]], [[0.42, -0.5], [0.48, -0.3], [0.5, 0.2], [0.47, 0.5]], [[0.47, 0.5], [0, 0.5]]], 48, {
    tile: 0.5, rows: 0.12,
    rmod: (th, r, y) => r * (0.88 + (fbm3([Math.cos(th) * 2.5, y * 3, Math.sin(th) * 2.5], seed) - 0.5) * 0.3),
  });
}
function grassLip(seed) {
  return lathe([[[0, -0.5], [0.46, -0.5]], [[0.46, -0.5], [0.49, -0.3], [0.5, 0.1], [0.485, 0.4], [0.46, 0.5]], [[0.46, 0.5], [0, 0.5]]], 72, {
    tile: 0.25, rows: 0.15,
    rmod: (th, r, y) => (y < 0.45 ? r * (1 + 0.025 * Math.sin(th * 13 + seed) + 0.02 * Math.sin(th * 5 + seed * 2)) : r),
  }).transform((p) => [p[0], p[1] - (p[1] < 0 ? (0.5 + p[1]) * 0 : 0), p[2]]);
}

// ── crates, lamps ───────────────────────────────────────────────────────────
function crate() {
  const s = 3, b = 0.32;
  const frame = [];
  for (const [x, y, z, sx, sy, sz] of [
    [0, b / 2, s / 2 - b / 2, s, b, b], [0, b / 2, -s / 2 + b / 2, s, b, b], [s / 2 - b / 2, b / 2, 0, b, b, s], [-s / 2 + b / 2, b / 2, 0, b, b, s],
    [0, s - b / 2, s / 2 - b / 2, s, b, b], [0, s - b / 2, -s / 2 + b / 2, s, b, b], [s / 2 - b / 2, s - b / 2, 0, b, b, s], [-s / 2 + b / 2, s - b / 2, 0, b, b, s],
    [s / 2 - b / 2, s / 2, s / 2 - b / 2, b, s, b], [-s / 2 + b / 2, s / 2, s / 2 - b / 2, b, s, b], [s / 2 - b / 2, s / 2, -s / 2 + b / 2, b, s, b], [-s / 2 + b / 2, s / 2, -s / 2 + b / 2, b, s, b],
  ]) frame.push(roundedBox([sx + 0.02, sy + 0.02, sz + 0.02], 0.06, [x, y, z], 2, 1));
  // a diagonal brace on each side
  const diag = Math.hypot(s - 2 * b, s - 2 * b);
  for (let k = 0; k < 4; k++) {
    let m = roundedBox([diag, 0.28, 0.12], 0.04, [0, 0, 0], 2, 1);
    m = m.transform(rz(Math.PI / 4 * (k % 2 ? 1 : -1)));
    m = move(m, [0, s / 2, s / 2 - 0.02]);
    frame.push(turnY(m, (k * Math.PI) / 2));
  }
  // planks: the box with grooves every 0.66
  const body = roundedBox([s - 0.16, s - 0.16, s - 0.16], 0.05, [0, s / 2, 0], 2, 1);
  const grooves = [];
  for (let k = 1; k < 4; k++) {
    const y = (k / 4) * s;
    for (let side = 0; side < 4; side++) grooves.push(turnY(roundedBox([s - 0.5, 0.05, 0.03], 0.01, [0, y, s / 2 - 0.07], 1, 1), (side * Math.PI) / 2));
  }
  return { body: merge(body, ...grooves), frame: merge(...frame) };
}
function lampMeshes() {
  const base = merge(roundedBox([1.4, 0.7, 1.4], 0.08, [0, 0.35, 0], 2, 1), roundedBox([1.1, 0.3, 1.1], 0.06, [0, 0.85, 0], 2, 1));
  const pole = lathe([[[0.3, 1.0], [0.3, 1.3]], [[0.3, 1.3], [0.2, 1.5], [0.17, 1.8], [0.15, 8.2]], [[0.15, 8.2], [0.26, 8.3], [0.3, 8.45]], [[0.3, 8.45], [0, 8.45]]], 20, { tile: 2 });
  const cage = [];
  for (const [x, z] of [[-0.6, -0.6], [0.6, -0.6], [-0.6, 0.6], [0.6, 0.6]]) cage.push(roundedBox([0.1, 1.45, 0.1], 0.03, [x, 9.15, z], 1, 1));
  cage.push(roundedBox([1.4, 0.12, 1.4], 0.04, [0, 8.45, 0], 2, 1));
  // a little pyramid roof and a finial
  cage.push(lathe([[[0.95, 9.85], [0.9, 9.95], [0.15, 10.4]], [[0.15, 10.4], [0, 10.42]]], 4, { tile: 1 }).transform(ry(Math.PI / 4)));
  cage.push(move(sphere(0.25, 10), [0, 10.5, 0]));
  return { LampStone: base, LampIron: merge(pole, ...cage) };
}

// ── toys ────────────────────────────────────────────────────────────────────
function balloon() {
  const pts = [];
  for (let i = 0; i <= 16; i++) {
    const t = i / 16, a = -Math.PI / 2 + t * Math.PI;
    const r = Math.cos(a) * (1.5 - 0.35 * Math.max(0, -Math.sin(a)));
    pts.push([Math.max(0, r), 1.8 + Math.sin(a) * 1.8 + (a < 0 ? Math.sin(a) * 0.25 : 0)]);
  }
  pts[0] = [0, pts[0][1]];
  const knot = [[0, -0.32], [0.18, -0.3], [0.22, -0.15], [0.12, -0.02], [0.2, 0.05], [0, 0.12]];
  return merge(lathe([pts], 32, { tile: 2 }), lathe([knot], 12, { tile: 1 }));
}
function lollipop() {
  const disc = lathe([[[0, -0.3], [2.4, -0.3]], [[2.4, -0.3], [2.6, -0.15], [2.65, 0], [2.6, 0.15], [2.4, 0.3]], [[2.4, 0.3], [0, 0.3]]], 48, { tile: 1 }).transform(rx(Math.PI / 2));
  const stripe = [];
  for (const z of [0.31, -0.31]) {
    stripe.push(tube((t) => {
      const a = t * Math.PI * 2 * 3.2, r = 0.25 + t * 2.15;
      return [Math.cos(a) * r, Math.sin(a) * r, z];
    }, 0.16, 160, 8, { up: [0, 0, 1] }));
  }
  return { disc, stripe: merge(...stripe) };
}
function crayonMeshes() {
  // a hexagonal crayon 1.6 across, height 1 (stretched to the crayon's
  // height); the cone tip is its own mesh so it isn't stretched with it
  const body = lathe([[[0, 0], [0.8, 0]], [[0.8, 0], [0.8, 1]], [[0.8, 1], [0, 1]]], 6, { tile: 1 });
  const tip = lathe([[[0.8, 0], [0.55, 0.12]], [[0.55, 0.12], [0.3, 0.6], [0.12, 0.9], [0, 0.93]]], 18, { tile: 1 });
  const bands = merge(lathe([[[0.82, 0.12], [0.82, 0.2]]], 6, { tile: 1 }), lathe([[[0.82, 0.8], [0.82, 0.88]]], 6, { tile: 1 }));
  return { body, tip, bands };
}
function candyCane() {
  const pole = cylY(7, 0.5, 20, 0.06);
  const hook = tube((t) => {
    const a = Math.PI * t;
    return [0.6 - Math.cos(a) * 0.6, 7 + Math.sin(a) * 0.6, 0];
  }, 0.25, 24, 14, { up: [0, 0, 1] });
  const stripes = [];
  stripes.push(tube((t) => {
    const a = t * Math.PI * 2 * 6;
    return [Math.cos(a) * 0.255, 0.2 + t * 6.6, Math.sin(a) * 0.255];
  }, 0.07, 220, 6, { up: [0, 1, 0] }));
  return { white: merge(pole, hook), red: merge(...stripes) };
}
function duck() {
  const body = radial(lobes([[[0, 0, 0], 7], [[0, 1.5, 4.5], 4.2], [[0, 1, -3], 5.6]], 5, 0.02), 48, 28, 4).transform((p) => [p[0], p[1] * 0.78, p[2]]);
  const head = move(sphere(9, 32), [0, 8, -4]);
  const tail = move(radial(lobes([[[0, 0, 0], 2.2]], 6, 0.03), 18, 10, 2), [0, 3.2, 6.6]);
  const beak = move(scaleM(sphere(1, 20), [4.4, 1.6, 4.4]), [0, 7.3, -8.7]);
  return { DuckBody: merge(body, head, tail), DuckBeak: beak };
}
const softBlock = () => roundedBox([1, 1, 1], 0.08, [0, 0, 0], 3, 1);
const dice = () => {
  const m = roundedBox([1, 1, 1], 0.14, [0, 0, 0], 4, 1);
  return m;
};

// ── rooftops ────────────────────────────────────────────────────────────────
function acUnit() {
  const body = roundedBox([4.5, 2.6, 3.4], 0.1, [0, 1.3, 0], 2, 1);
  const fins = [];
  for (let k = -5; k <= 5; k++) fins.push(roundedBox([0.06, 1.8, 3.42], 0.02, [k * 0.38, 1.25, 0], 1, 1));
  const ring = lathe([[[1.15, 2.6], [1.2, 2.75], [1.15, 2.9]], [[1.15, 2.9], [1.0, 2.9]], [[1.0, 2.9], [1.0, 2.62]]], 32, { tile: 1 });
  const feet = [];
  for (const [x, z] of [[-1.9, -1.4], [1.9, -1.4], [-1.9, 1.4], [1.9, 1.4]]) feet.push(roundedBox([0.4, 0.2, 0.4], 0.04, [x, 0.1, z], 1, 1));
  const fan = [];
  for (let k = 0; k < 5; k++) {
    const a = (k / 5) * Math.PI * 2;
    fan.push(move(turnY(roundedBox([0.9, 0.05, 0.35], 0.02, [0.5, 0, 0], 1, 1).transform(rx(0.4)), a), [0, 2.75, 0]));
  }
  fan.push(move(sphere(0.3, 12), [0, 2.75, 0]));
  return { ACBody: merge(body, ...fins, ...feet, ring), ACFan: merge(...fan) };
}
function waterTank() {
  const staves = lathe([[[2.0, 3], [2.08, 3.2], [2.12, 5], [2.08, 6.8], [2.0, 7]], [[2.0, 7], [0, 7]], [[0, 3], [2.0, 3]]], 48, {
    tile: 1, rows: 0.5, rmod: (th, r, y) => r - 0.03 * Math.pow(Math.abs(Math.sin(th * 20)), 0.3),
  });
  const bands = [3.6, 5, 6.4].map((y) => lathe([[[2.14, y - 0.08], [2.16, y], [2.14, y + 0.08]]], 48, { tile: 1 }));
  const roof = lathe([[[2.35, 7], [2.3, 7.15], [0.2, 8.4]], [[0.2, 8.4], [0, 8.42]]], 32, { tile: 1 });
  const legs = [];
  for (const [x, z] of [[1.3, 1.3], [-1.3, 1.3], [1.3, -1.3], [-1.3, -1.3]]) legs.push(roundedBox([0.3, 3, 0.3], 0.05, [x, 1.5, z], 1, 1));
  legs.push(roundedBox([3, 0.18, 0.18], 0.03, [0, 1.2, 1.3], 1, 1), roundedBox([3, 0.18, 0.18], 0.03, [0, 1.2, -1.3], 1, 1));
  return { TankWood: merge(staves, ...legs), TankMetal: merge(...bands), TankRoof: roof };
}

// ── everything ──────────────────────────────────────────────────────────────
const PROPS = {};
const add = (name, mesh) => (PROPS[name] = mesh);

add('TreeTrunk', trunk(5.6, 0.95, 0.5, 1));
add('TreeCanopyA', canopy(3, [[[0, 0, 0], 3.7], [[2.6, -0.6, 0.6], 2.6], [[-2.3, -0.4, 1.4], 2.5], [[0.6, -0.5, -2.6], 2.6], [[-0.8, 1.4, -0.6], 2.6], [[-1.6, -0.8, -1.8], 2.2]]));
add('TreeCanopyB', canopy(9, [[[0, 0, 0], 3.6], [[-2.5, -0.5, -0.4], 2.7], [[2.2, -0.2, 1.6], 2.4], [[0.2, -0.6, 2.7], 2.4], [[1.2, 1.3, -1.1], 2.5], [[-1.0, -0.9, 2.0], 2.0]]));
{
  const snow = [];
  add('PineFoliage', pineFoliage(4, snow));
  add('PineSnow', merge(...snow));
  add('PineTrunk', trunk(3.4, 0.75, 0.45, 7));
}
add('BushA', canopy(11, [[[0, 0, 0], 1.3], [[1.0, -0.2, 0.3], 1.0], [[-0.9, -0.2, 0.5], 1.0], [[0.2, -0.3, -1.0], 1.0]]).transform((p) => [p[0], Math.max(p[1], -0.6) + 0.6, p[2]]));
add('RockA', rockMesh(21, 2.6, 1.8, 2.2));
add('RockB', rockMesh(33, 2.2, 1.5, 2.6));
add('RockC', rockMesh(47, 3.0, 2.0, 2.4));
for (let i = 1; i <= 3; i++) add('U_Cliff' + i, cliffColumn(100 + i * 7));
add('U_Hang1', hangRock(201));
add('U_Hang2', hangRock(207));
add('U_RockDrum', rockDrum(301));
add('U_GrassLip', grassLip(401));
{
  const c = crate();
  add('CrateBody', c.body);
  add('CrateFrame', c.frame);
  const l = lampMeshes();
  add('LampStone', l.LampStone);
  add('LampIron', l.LampIron);
  add('Balloon', balloon());
  const lp = lollipop();
  add('LollipopDisc', lp.disc);
  add('LollipopStripe', lp.stripe);
  const cr = crayonMeshes();
  add('CrayonBody', cr.body);
  add('CrayonTip', cr.tip);
  add('CrayonBands', cr.bands);
  const cc = candyCane();
  add('CandyCaneWhite', cc.white);
  add('CandyCaneRed', cc.red);
  const d = duck();
  add('DuckBody', d.DuckBody);
  add('DuckBeak', d.DuckBeak);
  add('U_SoftBlock', softBlock());
  add('U_Dice', dice());
  const ac = acUnit();
  add('ACBody', ac.ACBody);
  add('ACFan', ac.ACFan);
  const wt = waterTank();
  add('TankWood', wt.TankWood);
  add('TankMetal', wt.TankMetal);
  add('TankRoof', wt.TankRoof);
}
// import probes: tell the setup script how the importer turned the scene.
add('Probe_O', roundedBox([0.5, 0.5, 0.5], 0.05, [0, 0, 0], 1, 1));
add('Probe_X', roundedBox([0.5, 0.5, 0.5], 0.05, [20, 0, 0], 1, 1));
add('Probe_Y', roundedBox([0.5, 0.5, 0.5], 0.05, [0, 20, 0], 1, 1));

const GUNS = guns();
module.exports = { PROPS, GUNS };

// ── writers ─────────────────────────────────────────────────────────────────
function writeAll() {
  const chunks = [];
  let offset = 0;
  const bufferViews = [], accessors = [], meshes = [], nodes = [];
  const push = (buf, target) => {
    const pad = (4 - (buf.length % 4)) % 4;
    bufferViews.push({ buffer: 0, byteOffset: offset, byteLength: buf.length, target });
    chunks.push(buf, Buffer.alloc(pad));
    offset += buf.length + pad;
    return bufferViews.length - 1;
  };
  const all = [];
  for (const [name, mesh] of Object.entries(PROPS)) all.push([name, mesh]);
  for (const g of Object.values(GUNS)) for (const p of g.parts) all.push([p.name, p.mesh]);
  const info = {};
  let tris = 0;
  for (const [name, mesh] of all) {
    const n = mesh.p.length;
    const pos = new Float32Array(n * 3), nrm = new Float32Array(n * 3), uv = new Float32Array(n * 2);
    mesh.p.forEach((p, i) => pos.set(p, i * 3));
    mesh.n.forEach((p, i) => nrm.set(p, i * 3));
    mesh.uv.forEach((p, i) => uv.set(p, i * 2));
    const idx = new Uint32Array(mesh.idx);
    if (idx.length / 3 > 20000) throw new Error(`${name}: ${idx.length / 3} triangles`);
    tris += idx.length / 3;
    const b = mesh.bounds();
    accessors.push({ bufferView: push(Buffer.from(pos.buffer), 34962), componentType: 5126, count: n, type: 'VEC3', min: b.min, max: b.max });
    accessors.push({ bufferView: push(Buffer.from(nrm.buffer), 34962), componentType: 5126, count: n, type: 'VEC3' });
    accessors.push({ bufferView: push(Buffer.from(uv.buffer), 34962), componentType: 5126, count: n, type: 'VEC2' });
    accessors.push({ bufferView: push(Buffer.from(idx.buffer), 34963), componentType: 5125, count: idx.length, type: 'SCALAR' });
    const a = accessors.length - 4;
    meshes.push({ name, primitives: [{ attributes: { POSITION: a, NORMAL: a + 1, TEXCOORD_0: a + 2 }, indices: a + 3, material: 0 }] });
    nodes.push({ name, mesh: meshes.length - 1 });
    info[name] = { c: b.min.map((v, k) => (v + b.max[k]) / 2), s: b.min.map((v, k) => b.max[k] - v) };
  }
  const json = {
    asset: { version: '2.0', generator: 'paw-mayhem tools/models/game_meshes.js' },
    scene: 0,
    scenes: [{ name: 'GameMeshes', nodes: nodes.map((_, i) => i) }],
    nodes, meshes,
    materials: [{ name: 'Plain', pbrMetallicRoughness: { baseColorFactor: [0.8, 0.8, 0.8, 1], metallicFactor: 0, roughnessFactor: 0.8 } }],
    accessors, bufferViews, buffers: [{ byteLength: offset }],
  };
  let jbuf = Buffer.from(JSON.stringify(json));
  jbuf = Buffer.concat([jbuf, Buffer.alloc((4 - (jbuf.length % 4)) % 4, 0x20)]);
  const bin = Buffer.concat(chunks);
  const ch = (type, data) => {
    const h = Buffer.alloc(8);
    h.writeUInt32LE(data.length, 0);
    h.writeUInt32LE(type, 4);
    return Buffer.concat([h, data]);
  };
  const header = Buffer.alloc(12);
  header.writeUInt32LE(0x46546c67, 0);
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(12 + 8 + jbuf.length + 8 + bin.length, 8);
  fs.writeFileSync(OUT_GLB, Buffer.concat([header, ch(0x4e4f534a, jbuf), ch(0x004e4942, bin)]));

  const f = (v) => v.map((x) => (Math.abs(x) < 5e-5 ? 0 : x).toFixed(4)).join(', ');
  const vec = (v) => `Vector3.new(${f(v)})`;
  const lua = [];
  lua.push('--!strict');
  lua.push('-- GENERATED by tools/models/game_meshes.js - do not edit by hand.');
  lua.push('-- Every model in assets/GameMeshes.glb (imported into');
  lua.push('-- ReplicatedStorage.GameMeshes by tools/models/setup_game.lua): its centre');
  lua.push('-- and size in the space it was modelled in, and how each blaster is put');
  lua.push('-- together (one mesh per colour slot; Tip = where the muzzle is).');
  lua.push('');
  lua.push('return {');
  lua.push('\tMeshes = {');
  for (const [name, i] of Object.entries(info)) lua.push(`\t\t${name} = { Center = ${vec(i.c)}, Size = ${vec(i.s)} },`);
  lua.push('\t},');
  lua.push('\tGuns = {');
  for (const [id, g] of Object.entries(GUNS)) {
    lua.push(`\t\t${id} = {`);
    lua.push(`\t\t\tTip = ${vec(g.tip)},`);
    lua.push('\t\t\tParts = {');
    for (const p of g.parts) lua.push(`\t\t\t\t{ Name = "${p.name}", Slot = "${p.slot}", Material = "${p.mat}", Transparency = ${p.t} },`);
    lua.push('\t\t\t},');
    lua.push('\t\t},');
  }
  lua.push('\t},');
  lua.push('}');
  fs.writeFileSync(OUT_LUA, (lua.join('\n') + '\n').replace(/^(\s*--.*)$/gm, (m) => m.toLowerCase())); // (comments lowercase, like the rest of the code)

  const template = fs.readFileSync(path.join(__dirname, 'setup_game.template.lua'), 'utf8');
  const names = all.map(([n]) => `"${n}"`).join(', ');
  fs.writeFileSync(OUT_SETUP, template.replace('__NAMES__', names));
  console.log(`wrote ${path.relative(ROOT, OUT_GLB)} (${(fs.statSync(OUT_GLB).size / 1e6).toFixed(1)} MB, ${all.length} meshes, ${tris} triangles), GameMeshData.lua, setup_game.lua`);
}

if (require.main === module) writeAll();
