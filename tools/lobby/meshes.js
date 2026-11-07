// paw mayhem lobby — procedural 3d models (no blender needed).
//
//   node tools/lobby/textures.js   (once, or after changing textures)
//   node tools/lobby/meshes.js
//
// writes assets/lobbymeshes.glb (meshes + embedded pbr textures; studio's 3d
// importer turns the textures into surfaceappearances) and the lua layout
// table src/replicatedstorage/shared/lobbymeshdata.lua. lobbyservice swaps
// the block-built pieces for these once replicatedstorage.lobbymeshes holds
// the imported model; until then the lobby stays block-built.
//
// each group is modelled in its own space, roblox axes, studs; origin at the
// bottom centre unless noted. every piece is centred on x and z (mirror
// symmetric), so the importer's 180° turn can't put anything on the wrong side.

const fs = require('fs');
const path = require('path');
const { V, Mesh, grid, lathe, roundedBox, sweep, tube, circle, roundRect, uvBox } = require('./geo');

const ROOT = path.join(__dirname, '..', '..');
const TEX = path.join(__dirname, 'textures');
const OUT_GLB = path.join(ROOT, 'assets', 'LobbyMeshes.glb');
const OUT_LUA = path.join(ROOT, 'src', 'ReplicatedStorage', 'Shared', 'LobbyMeshData.lua');

const arc = (cx, cy, r, a0, a1, n) => Array.from({ length: n + 1 }, (_, i) => {
  const a = a0 + ((a1 - a0) * i) / n;
  return [cx + Math.cos(a) * r, cy + Math.sin(a) * r];
});
const D = Math.PI / 180;
const translate = (m, t) => m.transform((p) => V.add(p, t));
const rotY = (m, a) => m.transform((p) => [p[0] * Math.cos(a) - p[2] * Math.sin(a), p[1], p[0] * Math.sin(a) + p[2] * Math.cos(a)]);
const mirrorX = (m) => m.transform((p) => [-p[0], p[1], p[2]]);
const merge = (...ms) => ms.reduce((a, b) => a.merge(b), new Mesh());

// ── spawn dais (origin: floor centre) ─────────────────────────────────────────
// a stone step and platform with soft edges and a gold bead round the
// platform; the code still lays the grate, ribs and logo on top (top = 0.6).
function dais() {
  const stone = lathe([
    [[17.5, 0], [17.5, 0.1]],
    [[17.5, 0.1], [17.48, 0.19], [17.4, 0.26], [17.25, 0.3]],
    [[17.25, 0.3], [15.1, 0.3]],
    [[15.1, 0.3], [15.1, 0.5]],
    [[15.1, 0.5], [15.07, 0.56], [14.98, 0.6]],
    [[14.98, 0.6], [0, 0.6]],
  ], 128, { tile: 8, planarTop: true });
  const bead = lathe([[...arc(15.17, 0.42, 0.17, -100 * D, 260 * D, 20)]], 128, { tile: 2 });
  const inlay = lathe([[...arc(16.2, 0.3, 0.06, 0, 180 * D, 6)]], 128, { tile: 2 });
  return { DaisStone: ['StoneBlock', stone], DaisGold: ['Gold', merge(bead, inlay)] };
}

// ── column (4 x 22 x 4): plinth, mouldings, fluted shaft, capital ────────────
function column() {
  const flutes = 20;
  const fl = (lo, hi) => (th, r, y) => {
    const fade = Math.min(1, Math.max(0, (y - lo) / 0.4), Math.max(0, (hi - y) / 0.4));
    const g = 0.5 + 0.5 * Math.cos(th * flutes);
    return r - 0.09 * Math.pow(g, 2.2) * fade;
  };
  const entasis = (y) => 1.45 - 0.15 * Math.pow((y - 2.1) / 17, 1.5);
  const shaftPts = (y0, y1, n) => Array.from({ length: n + 1 }, (_, i) => {
    const y = y0 + ((y1 - y0) * i) / n;
    return [entasis(y), y];
  });
  const shaft = lathe([shaftPts(2.1, 2.9, 8), shaftPts(2.9, 18.4, 6), shaftPts(18.4, 19.2, 8)], 200, { rmod: fl(2.25, 19.05), tile: 4 });
  const base = lathe([
    arc(1.6, 1.25, 0.25, -90 * D, 90 * D, 10),
    arc(1.62, 1.65, 0.12, 270 * D, 90 * D, 8).map(([r, y]) => [r, y]),
    arc(1.62, 1.88, 0.11, -90 * D, 90 * D, 8),
    [[1.62, 1.99], [1.45, 2.0]],
  ], 96, { tile: 4 });
  const echinus = lathe([
    Array.from({ length: 11 }, (_, i) => {
      const t = i / 10;
      return [1.3 + 0.55 * Math.sin((t * Math.PI) / 2), 19.2 + 1.4 * t];
    }),
    [[1.85, 20.6], [0, 20.6]],
  ], 96, { tile: 4 });
  const stone = merge(
    roundedBox([4, 1.0, 4], 0.12, [0, 0.5, 0], 3, 4),
    base, shaft, echinus,
    roundedBox([4, 0.9, 4], 0.12, [0, 21.05, 0], 3, 4),
  );
  const gold = merge(
    lathe([arc(1.5, 2.12, 0.13, -180 * D, 180 * D, 16)], 96, { tile: 1 }),
    lathe([arc(1.35, 19.17, 0.13, -180 * D, 180 * D, 16)], 96, { tile: 1 }),
    roundedBox([4.1, 0.5, 4.1], 0.1, [0, 21.75, 0], 3, 4),
    roundedBox([4.08, 0.12, 4.08], 0.05, [0, 1.0, 0], 2, 4),
  );
  return { ColumnStone: ['StoneBlock', stone], ColumnGold: ['Gold', gold] };
}

// ── pilaster (1.4 deep x 19.6 x 2.2 wide), fluted on both faces ─────────────
function pilaster() {
  const loop = roundRect(1.1, 1.8, 0.1, 5);
  const per = [0];
  for (let i = 1; i <= loop.length; i++) {
    const a = loop[i - 1], b = loop[i % loop.length];
    per.push(per[i - 1] + Math.hypot(b[0] - a[0], b[1] - a[1]));
  }
  const P = per[per.length - 1];
  const onLoop = (u) => {
    const d = u * P;
    let i = 1;
    while (i < per.length - 1 && per[i] < d) i++;
    const t = (d - per[i - 1]) / (per[i] - per[i - 1]);
    const a = loop[i - 1], b = loop[i % loop.length];
    return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
  };
  const y0 = 1.2, y1 = 17.8;
  // denser rows at the ends where the flutes round off
  const yOf = (v) => (v < 0.3 ? y0 + (v / 0.3) * 0.7 : v > 0.7 ? y1 - ((1 - v) / 0.3) * 0.7 : y0 + 0.7 + ((v - 0.3) / 0.4) * (y1 - y0 - 1.4));
  const f = (u, v) => {
    const [x, z] = onLoop(u);
    const y = yOf(v);
    let depth = 0;
    if (Math.abs(x) > 0.54) {
      const fade = Math.min(1, Math.max(0, (y - y0 - 0.25) / 0.4), Math.max(0, (y1 - 0.25 - y) / 0.4));
      for (const c of [-0.52, 0, 0.52]) {
        const t = Math.abs(z - c) / 0.17;
        if (t < 1) depth = Math.max(depth, Math.sqrt(1 - t * t) * 0.08 * fade);
      }
    }
    return [x - Math.sign(x) * depth, y, z];
  };
  const shaft = grid(f, 240, 30, { closedU: true, hint: (p) => [p[0], 0, p[2]], uv: (u, v, p, n) => uvBox(p, n, 4) });
  const stone = merge(
    roundedBox([1.4, 1.2, 2.2], 0.08, [0, 0.6, 0], 3, 4),
    shaft,
    roundedBox([1.4, 1.1, 2.2], 0.08, [0, 18.65, 0], 3, 4),
  );
  const gold = merge(
    roundedBox([1.22, 0.16, 1.92], 0.05, [0, 17.88, 0], 2, 4),
    roundedBox([1.5, 0.4, 2.4], 0.08, [0, 19.4, 0], 3, 4),
    roundedBox([1.46, 0.1, 2.3], 0.04, [0, 1.22, 0], 2, 4),
  );
  return { PilasterStone: ['StoneBlock', stone], PilasterGold: ['Gold', gold] };
}

// ── the duels arch (origin: floor at the arch's centre line) ─────────────────
// an elliptical arch under the header between the two columns (x = ±20):
// navy spandrels and soffit, two gold beads on each face, a stone keystone.
function archway() {
  const A = 20, Y0 = 8, B = 5.2, TOP = 14.2, Z = 0.95;
  const arcY = (x) => Y0 + B * Math.sqrt(Math.max(0, 1 - (x / A) ** 2));
  const xOf = (u) => -A * Math.cos(Math.PI * u);
  const face = (z) => grid((u, v) => {
    const x = xOf(u);
    const y0 = arcY(x);
    return [x, y0 + (TOP - y0) * v, z];
  }, 120, 6, { hint: () => [0, 0, Math.sign(z)], uv: (u, v, p, n) => uvBox(p, n, 8) });
  const soffit = grid((u, v) => {
    const x = xOf(u);
    return [x, arcY(x), -Z + 2 * Z * v];
  }, 120, 2, { hint: (p) => [-p[0] / A, -(1 - Math.abs(p[0]) / A) - 0.05, 0], uv: (u, v, p, n) => [p[0] / 8, p[2] / 8] });
  const ellipse = (off, z) => (t) => {
    const th = Math.PI * (1 - t);
    const e = [A * Math.cos(th), Y0 + B * Math.sin(th)];
    const n = V.norm([Math.cos(th) / A, Math.sin(th) / B, 0]);
    return [e[0] + n[0] * off, e[1] + n[1] * off, z];
  };
  const beads = [];
  for (const z of [Z + 0.06, -Z - 0.06]) {
    beads.push(tube(ellipse(0.32, z), 0.17, 120, 10, { up: [0, 0, 1] }));
    beads.push(tube(ellipse(1.25, z), 0.1, 120, 8, { up: [0, 0, 1] }));
  }
  const key = roundedBox([1.8, 2.4, 2.5], 0.12, [0, Y0 + B + 0.7, 0], 3, 4);
  const keyGold = roundedBox([1.9, 0.18, 2.6], 0.05, [0, Y0 + B + 1.78, 0], 2, 4);
  return { ArchNavy: ['Navy', merge(face(Z), face(-Z), soffit)], ArchGold: ['Gold', merge(...beads, keyGold)], ArchKeystone: ['StoneBlock', key] };
}

// ── chandelier (origin: the hub's centre) ────────────────────────────────────
function chandelierMesh() {
  const hub = lathe([[
    [0, -1.3], [0.12, -1.25], [0.2, -1.05], [0.15, -0.85], [0.45, -0.6], [0.6, -0.32], [0.55, -0.02],
    [0.3, 0.25], [0.2, 0.5], [0.26, 0.7], [0.13, 0.9], [0.1, 1.1], [0, 1.16],
  ]], 48, { tile: 2 });
  const parts = [hub];
  const candles = [];
  for (let k = 0; k < 8; k++) {
    const a = (k / 8) * Math.PI * 2;
    const arm = (t) => {
      const r = 0.5 + 2.9 * t;
      const y = -0.1 + 0.8 * Math.sin(0.9 * Math.PI * t) - 0.75 * t;
      return [Math.cos(a) * r, y, Math.sin(a) * r];
    };
    parts.push(tube(arm, 0.08, 40, 8, { up: [0, 1, 0] }));
    const tip = [Math.cos(a) * 3.4, 0, Math.sin(a) * 3.4];
    parts.push(translate(lathe([[[0, -0.66], [0.1, -0.66], [0.3, -0.58], [0.37, -0.52], [0.3, -0.49], [0.12, -0.51], [0, -0.51]]], 20, { tile: 1 }), tip));
    candles.push(translate(lathe([[[0, -0.51], [0.11, -0.51], [0.11, 0.0], [0.08, 0.05], [0, 0.06]]], 14, { tile: 1 }), tip));
  }
  parts.push(lathe([arc(3.4, -0.62, 0.06, -180 * D, 180 * D, 8)], 96, { tile: 1 }));
  return { ChandelierGold: ['Gold', merge(...parts)], ChandelierCandles: ['Cream', merge(...candles)] };
}

// ── trophy (origin: the plinth trim's top) ────────────────────────────────────
function trophyMesh() {
  const cup = lathe([
    [[0, 0], [1.0, 0]],
    [[1.0, 0], [1.0, 0.12]],
    [[1.0, 0.12], [0.85, 0.2], [0.55, 0.32], [0.4, 0.45], [0.25, 0.6]],
    [[0.25, 0.6], [0.2, 0.9], [0.3, 0.98], [0.35, 1.05], [0.3, 1.12], [0.2, 1.2], [0.18, 1.5]],
    [[0.18, 1.5], [0.4, 1.65], [0.7, 1.75], [0.95, 1.95], [1.12, 2.35], [1.2, 2.9], [1.26, 3.4], [1.3, 3.6]],
    [[1.3, 3.6], [1.22, 3.6]],
    [[1.22, 3.6], [1.18, 3.4], [1.12, 2.9], [1.04, 2.4], [0.85, 2.1], [0.4, 1.95], [0, 1.92]],
  ], 64, { tile: 2 });
  const handle = (s) => tube((t) => [s * (1.15 + 0.6 * Math.sin(Math.PI * t)), 2.75 + 0.5 * Math.cos(Math.PI * t), 0], 0.09, 24, 10, { up: [0, 0, 1] });
  return { TrophyGold: ['Gold', merge(cup, handle(1), handle(-1))] };
}

// ── planter (3.4 x 1.6 x 3.4) ────────────────────────────────────────────────
function planterMesh() {
  const stone = merge(
    roundedBox([3.4, 0.3, 3.4], 0.08, [0, 0.15, 0], 3, 4),
    roundedBox([3.0, 1.1, 3.0], 0.1, [0, 0.85, 0], 3, 4),
    roundedBox([3.4, 0.22, 3.4], 0.08, [0, 1.49, 0], 3, 4),
  );
  const gold = merge(roundedBox([3.08, 0.14, 3.08], 0.05, [0, 0.55, 0], 2, 4), roundedBox([3.08, 0.08, 3.08], 0.03, [0, 1.32, 0], 2, 4));
  return { PlanterStone: ['StoneBlock', stone], PlanterGold: ['Gold', gold] };
}

// ── mouldings, 1 stud long (stretched along z to fit each wall) ─────────────
function mouldings() {
  const right = [[0.2, -0.5], [0.24, -0.44], [0.25, -0.38], [0.22, -0.32], [0.21, -0.25], [0.22, -0.15], [0.25, -0.06], [0.29, 0.02], [0.3, 0.08], [0.3, 0.3], [0.27, 0.34], [0.3, 0.38], [0.3, 0.5]];
  const crownProf = [...right, ...right.slice().reverse().map(([x, y]) => [-x, y])];
  const line = (t) => [0, 0, -0.5 + t];
  const crown = sweep(line, crownProf, 1, { up: [0, 1, 0], uvAlong: true, tile: 1 });
  const railProf = circle(18, 1).map(([x, y]) => [x * 0.2, y * 0.3]);
  const rail = sweep(line, railProf, 1, { up: [0, 1, 0], uvAlong: true, tile: 1 });
  return { CrownMould: ['Gold', crown], RailMould: ['Gold', rail] };
}

// ── swatches: one cube per tiling material (setup_lobby.lua turns their
// surfaceappearances into materialvariants). never placed in the world.
function swatches() {
  const out = {};
  ['Stone', 'Grain', 'Plaster', 'Metal', 'Marble', 'Fabric', 'Carpet'].forEach((s, i) => {
    out['Swatch_Paw' + s] = ['Sw' + s, roundedBox([4, 4, 4], 0.3, [i * 6, 2, 0], 3, 4)];
  });
  return out;
}

const GROUPS = {
  Dais: dais(),
  Column: column(),
  Pilaster: pilaster(),
  Arch: archway(),
  Chandelier: chandelierMesh(),
  Trophy: trophyMesh(),
  Planter: planterMesh(),
  Moulding: mouldings(),
  Swatches: swatches(),
};
// nominal size each group was modelled at (the code scales to the part it
// replaces); nil = placed 1:1.
const BOX = { Column: [4, 22, 4], Pilaster: [1.4, 19.6, 2.2], Planter: [3.4, 1.6, 3.4] };

const MATERIALS = {
  Gold: 'Gold', StoneBlock: 'StoneBlock', Navy: 'Navy', Cream: 'Cream',
  SwStone: 'Stone', SwGrain: 'Grain', SwPlaster: 'Plaster', SwMetal: 'Metal', SwMarble: 'Marble', SwFabric: 'Fabric', SwCarpet: 'Carpet',
};

module.exports = { GROUPS, BOX, MATERIALS };

// ── glb writer ───────────────────────────────────────────────────────────────
// (comments lowercase, like the rest of the code)
const lowerComments = (t) => t.replace(/^(\s*--.*)$/gm, (m) => m.toLowerCase());

function writeGlb() {
  const chunks = [];
  let offset = 0;
  const bufferViews = [], accessors = [], images = [], textures = [], materials = [], meshes = [], nodes = [];
  const push = (buf, target) => {
    const pad = (4 - (buf.length % 4)) % 4;
    const view = { buffer: 0, byteOffset: offset, byteLength: buf.length };
    if (target) view.target = target;
    chunks.push(buf, Buffer.alloc(pad));
    offset += buf.length + pad;
    bufferViews.push(view);
    return bufferViews.length - 1;
  };
  const texIndex = {};
  const tex = (file) => {
    if (texIndex[file] !== undefined) return texIndex[file];
    const bv = push(fs.readFileSync(path.join(TEX, file)));
    images.push({ bufferView: bv, mimeType: 'image/png', name: file.replace('.png', '') });
    textures.push({ source: images.length - 1, sampler: 0 });
    return (texIndex[file] = textures.length - 1);
  };
  const matIndex = {};
  for (const [name, set] of Object.entries(MATERIALS)) {
    materials.push({
      name,
      pbrMetallicRoughness: {
        baseColorTexture: { index: tex(set + '_color.png') },
        metallicRoughnessTexture: { index: tex(set + '_orm.png') },
        metallicFactor: 1,
        roughnessFactor: 1,
      },
      normalTexture: { index: tex(set + '_normal.png') },
    });
    matIndex[name] = materials.length - 1;
  }
  const lua = [];
  let tris = 0;
  for (const [group, pieces] of Object.entries(GROUPS)) {
    const rows = [];
    for (const [name, [mat, mesh]] of Object.entries(pieces)) {
      const n = mesh.p.length;
      const pos = new Float32Array(n * 3), nrm = new Float32Array(n * 3), uv = new Float32Array(n * 2);
      mesh.p.forEach((p, i) => pos.set(p, i * 3));
      mesh.n.forEach((p, i) => nrm.set(p, i * 3));
      mesh.uv.forEach((p, i) => uv.set(p, i * 2));
      const idx = new Uint32Array(mesh.idx);
      tris += idx.length / 3;
      const b = mesh.bounds();
      accessors.push({ bufferView: push(Buffer.from(pos.buffer), 34962), componentType: 5126, count: n, type: 'VEC3', min: b.min, max: b.max });
      const aPos = accessors.length - 1;
      accessors.push({ bufferView: push(Buffer.from(nrm.buffer), 34962), componentType: 5126, count: n, type: 'VEC3' });
      const aN = accessors.length - 1;
      accessors.push({ bufferView: push(Buffer.from(uv.buffer), 34962), componentType: 5126, count: n, type: 'VEC2' });
      const aUv = accessors.length - 1;
      accessors.push({ bufferView: push(Buffer.from(idx.buffer), 34963), componentType: 5125, count: idx.length, type: 'SCALAR' });
      const aIdx = accessors.length - 1;
      meshes.push({ name, primitives: [{ attributes: { POSITION: aPos, NORMAL: aN, TEXCOORD_0: aUv }, indices: aIdx, material: matIndex[mat] }] });
      nodes.push({ name, mesh: meshes.length - 1 });
      const c = b.min.map((v, k) => (v + b.max[k]) / 2);
      const s = b.min.map((v, k) => b.max[k] - v);
      const f = (v) => v.map((x) => x.toFixed(4)).join(', ');
      rows.push(`\t\t\t{ Name = "${name}", Mat = "${mat}", Center = Vector3.new(${f(c)}), Size = Vector3.new(${f(s)}) },`);
      if (idx.length / 3 > 20000) throw new Error(name + ' is over 20k triangles');
    }
    const box = BOX[group] ? `Vector3.new(${BOX[group].join(', ')})` : 'nil';
    lua.push(`\t${group} = {\n\t\tBox = ${box},\n\t\tPieces = {\n${rows.join('\n')}\n\t\t},\n\t},`);
  }
  const json = {
    asset: { version: '2.0', generator: 'paw-mayhem tools/lobby/meshes.js' },
    scene: 0,
    scenes: [{ name: 'LobbyMeshes', nodes: nodes.map((_, i) => i) }],
    nodes, meshes, materials, textures, images,
    samplers: [{ magFilter: 9729, minFilter: 9987, wrapS: 10497, wrapT: 10497 }],
    accessors, bufferViews,
    buffers: [{ byteLength: offset }],
  };
  let jbuf = Buffer.from(JSON.stringify(json));
  jbuf = Buffer.concat([jbuf, Buffer.alloc((4 - (jbuf.length % 4)) % 4, 0x20)]);
  const bin = Buffer.concat(chunks);
  const header = Buffer.alloc(12);
  header.writeUInt32LE(0x46546c67, 0);
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(12 + 8 + jbuf.length + 8 + bin.length, 8);
  const ch = (type, data) => {
    const h = Buffer.alloc(8);
    h.writeUInt32LE(data.length, 0);
    h.writeUInt32LE(type, 4);
    return Buffer.concat([h, data]);
  };
  fs.writeFileSync(OUT_GLB, Buffer.concat([header, ch(0x4e4f534a, jbuf), ch(0x004e4942, bin)]));
  fs.writeFileSync(OUT_LUA, lowerComments(`--!strict
-- GENERATED by tools/lobby/meshes.js — do not edit by hand.
-- The lobby's 3D models: for each group, the size it was modelled at (Box;
-- the code scales it to the part it replaces) and each piece's centre and
-- size in the group's space. The meshes live in ReplicatedStorage.LobbyMeshes
-- (imported from assets/LobbyMeshes.glb).

return {
${lua.join('\n')}
}
`));
  console.log(`wrote ${path.relative(ROOT, OUT_GLB)} (${(fs.statSync(OUT_GLB).size / 1e6).toFixed(1)} MB, ${tris} triangles, ${nodes.length} meshes)`);
}

if (require.main === module) writeGlb();
