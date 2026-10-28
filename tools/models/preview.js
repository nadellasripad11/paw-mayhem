// renders the blaster and prop models to tools/models/preview_*.png (flat
// colours, one key light) to check shapes without studio.
//   node tools/models/preview.js
const fs = require('fs');
const path = require('path');
const { encode } = require('../lobby/png');
const { V } = require('../lobby/geo');
const { PROPS, GUNS } = require('./game_meshes');

const DESIGNS = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'src', 'ReplicatedStorage', 'Shared', 'Character', 'BlasterDesigns.json'), 'utf8'));

function render(file, items, W, H, yaw, pitch) {
  const ya = (yaw * Math.PI) / 180, pa = (pitch * Math.PI) / 180;
  const rot = (p) => {
    const x = p[0] * Math.cos(ya) - p[2] * Math.sin(ya);
    const z = p[0] * Math.sin(ya) + p[2] * Math.cos(ya);
    return [x, p[1] * Math.cos(pa) - z * Math.sin(pa), p[1] * Math.sin(pa) + z * Math.cos(pa)];
  };
  let mn = [Infinity, Infinity], mx = [-Infinity, -Infinity];
  for (const [, m, off] of items) for (const p of m.p) {
    const q = rot(V.add(p, off));
    mn = [Math.min(mn[0], q[0]), Math.min(mn[1], q[1])];
    mx = [Math.max(mx[0], q[0]), Math.max(mx[1], q[1])];
  }
  const s = Math.min((W * 0.92) / (mx[0] - mn[0]), (H * 0.92) / (mx[1] - mn[1]));
  const cx = (mn[0] + mx[0]) / 2, cy = (mn[1] + mx[1]) / 2;
  const zb = new Float32Array(W * H).fill(Infinity);
  const img = new Uint8Array(W * H * 4);
  for (let i = 0; i < W * H; i++) img.set([30, 32, 40, 255], i * 4);
  const L = V.norm([0.5, 0.8, -0.5]);
  for (const [col, m, off] of items) {
    const P = m.p.map((p) => {
      const q = rot(V.add(p, off));
      return [W / 2 + (q[0] - cx) * s, H / 2 - (q[1] - cy) * s, q[2]];
    });
    const N = m.n.map(rot);
    for (let t = 0; t < m.idx.length; t += 3) {
      const [a, b, c] = [m.idx[t], m.idx[t + 1], m.idx[t + 2]];
      const A = P[a], B = P[b], C = P[c];
      const area = (B[0] - A[0]) * (C[1] - A[1]) - (B[1] - A[1]) * (C[0] - A[0]);
      if (area <= 0) continue;
      const x0 = Math.max(0, Math.floor(Math.min(A[0], B[0], C[0]))), x1 = Math.min(W - 1, Math.ceil(Math.max(A[0], B[0], C[0])));
      const y0 = Math.max(0, Math.floor(Math.min(A[1], B[1], C[1]))), y1 = Math.min(H - 1, Math.ceil(Math.max(A[1], B[1], C[1])));
      for (let y = y0; y <= y1; y++)
        for (let x = x0; x <= x1; x++) {
          const w0 = ((B[0] - x) * (C[1] - y) - (B[1] - y) * (C[0] - x)) / area;
          const w1 = ((C[0] - x) * (A[1] - y) - (C[1] - y) * (A[0] - x)) / area;
          const w2 = 1 - w0 - w1;
          if (w0 < 0 || w1 < 0 || w2 < 0) continue;
          const z = A[2] * w0 + B[2] * w1 + C[2] * w2;
          const i = y * W + x;
          if (z >= zb[i]) continue;
          zb[i] = z;
          const n = V.norm(V.add(V.add(V.mul(N[a], w0), V.mul(N[b], w1)), V.mul(N[c], w2)));
          const d = Math.max(0, V.dot(n, L));
          const spec = Math.pow(Math.max(0, V.dot(n, V.norm(V.add(L, [0, 0, -1])))), 30) * 0.35;
          const k = col.glow ? 1 : 0.3 + 0.7 * d;
          img.set([Math.min(255, col[0] * k + spec * 255), Math.min(255, col[1] * k + spec * 255), Math.min(255, col[2] * k + spec * 255), 255], i * 4);
        }
    }
  }
  fs.writeFileSync(path.join(__dirname, file), encode(W, H, img));
  console.log(file);
}

// guns: two rows of five, side-on with a slight 3/4 turn.
const items = [];
Object.entries(GUNS).forEach(([id, g], i) => {
  const pal = DESIGNS.palettes[id];
  const off = [(i % 5) * 7, -Math.floor(i / 5) * 3.5, 0];
  for (const p of g.parts) {
    const c = pal[p.slot] || [200, 200, 200];
    const col = [...c];
    if (p.mat === 'neon') col.glow = true;
    items.push([col, p.mesh, off]);
  }
});
render('preview_guns.png', items, 1800, 700, 18, -12);

// props on a grid.
const PROP_COL = {
  TreeTrunk: [122, 84, 54], TreeCanopyA: [82, 170, 64], TreeCanopyB: [58, 146, 58], PineFoliage: [44, 116, 62], PineSnow: [240, 244, 250], PineTrunk: [100, 66, 44],
  BushA: [82, 170, 64], RockA: [158, 136, 118], RockB: [140, 120, 104], RockC: [120, 104, 96], CrateBody: [164, 114, 68], CrateFrame: [104, 68, 42],
  LampStone: [196, 186, 168], LampIron: [58, 56, 60], Balloon: [255, 120, 150], LollipopDisc: [110, 200, 255], LollipopStripe: [250, 250, 250],
  CrayonBody: [255, 110, 140], CrayonBands: [160, 60, 80], CrayonTip: [255, 110, 140], CandyCaneWhite: [250, 250, 250], CandyCaneRed: [240, 60, 70], DuckBody: [255, 214, 50], DuckBeak: [255, 140, 40],
  ACBody: [180, 186, 196], ACFan: [60, 64, 74], TankWood: [150, 104, 76], TankMetal: [60, 60, 66], TankRoof: [110, 76, 58],
};
const groups = [
  ['TreeTrunk', ['TreeCanopyA', [0, 7.5, 0]]], ['TreeTrunk', ['TreeCanopyB', [0, 7.5, 0]]], ['PineTrunk', 'PineFoliage', 'PineSnow'], ['BushA'], ['RockA'], ['RockB'], ['RockC'],
  ['CrateBody', 'CrateFrame'], ['LampStone', 'LampIron'], ['Balloon'], ['LollipopDisc', 'LollipopStripe'], ['CrayonBody', 'CrayonBands', ['CrayonTip', [0, 1, 0]]], ['CandyCaneWhite', 'CandyCaneRed'],
  ['ACBody', 'ACFan'], ['TankWood', 'TankMetal', 'TankRoof'], ['U_Cliff1'], ['U_Cliff2'], ['U_Hang1'], ['U_RockDrum'], ['U_GrassLip'], ['U_SoftBlock'], ['U_Dice'],
];
const pitems = [];
groups.forEach((g, i) => {
  const base = [(i % 8) * 12, -Math.floor(i / 8) * 14, 0];
  for (const e of g) {
    const [name, extra] = Array.isArray(e) ? e : [e, [0, 0, 0]];
    let m = PROPS[name];
    if (name.startsWith('U_')) m = m.transform((p) => [p[0] * 5, p[1] * 8, p[2] * 5]);
    pitems.push([PROP_COL[name] || [170, 160, 150], m, V.add(base, extra)]);
  }
});
render('preview_props.png', pitems, 1800, 1100, -30, -15);
render('preview_duck.png', [[[255, 214, 50], PROPS.DuckBody, [0, 0, 0]], [[255, 140, 40], PROPS.DuckBeak, [0, 0, 0]]], 700, 700, -50, -10);
