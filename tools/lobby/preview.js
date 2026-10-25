// Renders each lobby mesh group to tools/lobby/preview_<Group>.png (flat
// material colours, one key light) so the shapes can be checked without
// Studio.   node tools/lobby/preview.js [Group]
const fs = require('fs');
const path = require('path');
const { encode } = require('./png');
const { V } = require('./geo');
const { GROUPS } = require('./meshes');

const COL = { Gold: [214, 164, 74], StoneBlock: [184, 174, 156], Navy: [40, 48, 84], Cream: [246, 236, 214] };
const W = 900, H = 900;

function render(group, pieces, yaw = -35, pitch = 20) {
  const ya = (yaw * Math.PI) / 180, pa = (pitch * Math.PI) / 180;
  const rot = (p) => {
    const x = p[0] * Math.cos(ya) - p[2] * Math.sin(ya);
    const z = p[0] * Math.sin(ya) + p[2] * Math.cos(ya);
    return [x, p[1] * Math.cos(pa) - z * Math.sin(pa), p[1] * Math.sin(pa) + z * Math.cos(pa)];
  };
  const all = [];
  for (const [, [mat, m]] of Object.entries(pieces)) all.push([mat, m]);
  let mn = [Infinity, Infinity], mx = [-Infinity, -Infinity];
  for (const [, m] of all) for (const p of m.p) {
    const q = rot(p);
    mn = [Math.min(mn[0], q[0]), Math.min(mn[1], q[1])];
    mx = [Math.max(mx[0], q[0]), Math.max(mx[1], q[1])];
  }
  const s = Math.min((W * 0.9) / (mx[0] - mn[0]), (H * 0.9) / (mx[1] - mn[1]));
  const cx = (mn[0] + mx[0]) / 2, cy = (mn[1] + mx[1]) / 2;
  const scr = (q) => [W / 2 + (q[0] - cx) * s, H / 2 - (q[1] - cy) * s, q[2]];
  const zb = new Float32Array(W * H).fill(Infinity);
  const img = new Uint8Array(W * H * 4);
  for (let i = 0; i < W * H; i++) img.set([28, 30, 38, 255], i * 4);
  const L = V.norm([0.5, 0.8, -0.4]);
  const view = [0, 0, -1];
  for (const [mat, m] of all) {
    const base = COL[mat] || [200, 200, 200];
    const P = m.p.map((p) => scr(rot(p)));
    const N = m.n.map((n) => rot(n));
    for (let t = 0; t < m.idx.length; t += 3) {
      const [a, b, c] = [m.idx[t], m.idx[t + 1], m.idx[t + 2]];
      const A = P[a], B = P[b], C = P[c];
      const area = (B[0] - A[0]) * (C[1] - A[1]) - (B[1] - A[1]) * (C[0] - A[0]);
      if (area <= 0) continue; // back face (screen y is flipped)
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
          const h = V.norm(V.add(L, V.mul(view, -1)));
          const spec = Math.pow(Math.max(0, V.dot(n, h)), 40) * (mat === 'Gold' ? 0.9 : 0.15);
          const k = 0.25 + 0.75 * d;
          img.set([Math.min(255, base[0] * k + spec * 255), Math.min(255, base[1] * k + spec * 255), Math.min(255, base[2] * k + spec * 220), 255], i * 4);
        }
    }
  }
  const out = path.join(__dirname, 'preview_' + group + '.png');
  fs.writeFileSync(out, encode(W, H, img));
  return out;
}

const only = process.argv[2];
for (const [g, pieces] of Object.entries(GROUPS)) {
  if (g === 'Swatches' || (only && g !== only)) continue;
  console.log(render(g, pieces, g === 'Arch' ? -20 : -35, g === 'Dais' ? -35 : -18));
}
