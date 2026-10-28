// geometry helpers for the lobby meshes (roblox axes: y up, studs).
// a mesh is positions / normals / uvs / triangle indices. every triangle is
// wound to face along its vertex normals, so builders only need the normals
// right.

const V = {
  add: (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]],
  sub: (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]],
  mul: (a, s) => [a[0] * s, a[1] * s, a[2] * s],
  dot: (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2],
  cross: (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]],
  len: (a) => Math.hypot(a[0], a[1], a[2]),
  norm: (a) => {
    const l = Math.hypot(a[0], a[1], a[2]);
    return l > 1e-9 ? [a[0] / l, a[1] / l, a[2] / l] : [0, 1, 0];
  },
};

class Mesh {
  constructor() {
    this.p = [];
    this.n = [];
    this.uv = [];
    this.idx = [];
  }
  vert(p, n, uv) {
    this.p.push(p);
    this.n.push(n);
    this.uv.push(uv);
    return this.p.length - 1;
  }
  tri(a, b, c) {
    const pa = this.p[a], pb = this.p[b], pc = this.p[c];
    const fn = V.cross(V.sub(pb, pa), V.sub(pc, pa));
    if (V.len(fn) < 1e-12) return;
    const vn = V.add(V.add(this.n[a], this.n[b]), this.n[c]);
    if (V.dot(fn, vn) < 0) this.idx.push(a, c, b);
    else this.idx.push(a, b, c);
  }
  quad(a, b, c, d) {
    this.tri(a, b, c);
    this.tri(a, c, d);
  }
  merge(m) {
    const o = this.p.length;
    this.p.push(...m.p);
    this.n.push(...m.n);
    this.uv.push(...m.uv);
    for (const i of m.idx) this.idx.push(i + o);
    return this;
  }
  transform(fn) {
    // fn(p) -> p; normals re-derived by transforming p + n.
    const out = new Mesh();
    for (let i = 0; i < this.p.length; i++) {
      const p = fn(this.p[i]);
      const q = fn(V.add(this.p[i], V.mul(this.n[i], 1e-3)));
      out.vert(p, V.norm(V.sub(q, p)), this.uv[i]);
    }
    out.idx = this.idx.slice();
    return out;
  }
  bounds() {
    const mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity];
    for (const p of this.p) for (let k = 0; k < 3; k++) {
      mn[k] = Math.min(mn[k], p[k]);
      mx[k] = Math.max(mx[k], p[k]);
    }
    return { min: mn, max: mx };
  }
}

// box-projected uvs (world studs / tile) from the dominant normal axis.
function uvBox(p, n, tile) {
  const ax = Math.abs(n[0]), ay = Math.abs(n[1]), az = Math.abs(n[2]);
  if (ay >= ax && ay >= az) return [p[0] / tile, p[2] / tile];
  if (ax >= az) return [p[2] / tile, -p[1] / tile];
  return [p[0] / tile, -p[1] / tile];
}

// a parametric surface over u, v in [0, 1]; normals from finite differences,
// flipped to agree with hint(p, u, v) (a rough outward direction).
function grid(f, nu, nv, opts = {}) {
  const m = new Mesh();
  const e = 1e-4;
  const at = (u, v) => f(opts.closedU ? ((u % 1) + 1) % 1 : Math.min(1, Math.max(0, u)), Math.min(1, Math.max(0, v)));
  const ids = [];
  for (let j = 0; j <= nv; j++) {
    const row = [];
    for (let i = 0; i <= nu; i++) {
      const u = i / nu, v = j / nv;
      const p = f(u, v);
      const du = V.sub(at(u + e, v), at(u - e, v));
      const dv = V.sub(at(u, v + e), at(u, v - e));
      let n = V.cross(du, dv);
      const hint = opts.hint ? opts.hint(p, u, v) : null;
      if (V.len(n) < 1e-10) n = hint || [0, 1, 0];
      n = V.norm(n);
      if (hint && V.dot(n, hint) < 0) n = V.mul(n, -1);
      const uv = opts.uv ? opts.uv(u, v, p, n) : [u, v];
      row.push(m.vert(p, n, uv));
    }
    ids.push(row);
  }
  for (let j = 0; j < nv; j++)
    for (let i = 0; i < nu; i++) m.quad(ids[j][i], ids[j][i + 1], ids[j + 1][i + 1], ids[j + 1][i]);
  return m;
}

// revolve runs of [r, y] points round the y axis. each run is smooth inside;
// runs meet at hard edges. seg = segments round. rmod(theta, r, y) can carve
// the radius (flutes). uvs: round the axis (seamless) x down the profile.
function lathe(runs, seg, opts = {}) {
  const out = new Mesh();
  const tile = opts.tile || 4;
  let vAcc = 0;
  for (const run of runs) {
    const lens = [0];
    for (let i = 1; i < run.length; i++) lens.push(lens[i - 1] + Math.hypot(run[i][0] - run[i - 1][0], run[i][1] - run[i - 1][1]));
    const total = lens[lens.length - 1] || 1;
    const sample = (v) => {
      const d = v * total;
      let i = 1;
      while (i < run.length - 1 && lens[i] < d) i++;
      const t = (d - lens[i - 1]) / ((lens[i] - lens[i - 1]) || 1);
      return [run[i - 1][0] + (run[i][0] - run[i - 1][0]) * t, run[i - 1][1] + (run[i][1] - run[i - 1][1]) * t];
    };
    const rAvg = run.reduce((s, q) => s + q[0], 0) / run.length;
    const uRep = Math.max(1, Math.round((2 * Math.PI * rAvg) / tile));
    const v0 = vAcc;
    // rows exactly on the run's points (plus subdivisions for long runs)
    const vs = [];
    for (let i = 0; i < run.length; i++) {
      if (i > 0) {
        const sub = opts.rows ? Math.max(1, Math.ceil((lens[i] - lens[i - 1]) / opts.rows)) : 1;
        for (let k = 1; k < sub; k++) vs.push((lens[i - 1] + ((lens[i] - lens[i - 1]) * k) / sub) / total);
      }
      vs.push(lens[i] / total);
    }
    const f = (u, v) => {
      const [r0, y] = sample(v);
      const th = u * Math.PI * 2;
      const r = opts.rmod ? opts.rmod(th, r0, y) : r0;
      return [Math.cos(th) * r, y, Math.sin(th) * r];
    };
    // grid over explicit v rows
    const m = new Mesh();
    const e = 1e-4;
    const ids = [];
    for (const v of vs) {
      const row = [];
      for (let i = 0; i <= seg; i++) {
        const u = i / seg;
        const p = f(u, v);
        const du = V.sub(f(u + e, v), f(u - e, v));
        const dv = V.sub(f(u, Math.min(1, v + e)), f(u, Math.max(0, v - e)));
        let n = V.cross(du, dv);
        // outward hint from the profile direction (2d normal of the run)
        const a = sample(Math.max(0, v - 0.01)), b = sample(Math.min(1, v + 0.01));
        const t2 = [b[0] - a[0], b[1] - a[1]];
        const th = u * Math.PI * 2;
        const hn = [t2[1] * Math.cos(th), -t2[0], t2[1] * Math.sin(th)];
        const hint = opts.inward ? V.mul(hn, -1) : hn;
        if (V.len(n) < 1e-10) n = hint;
        n = V.norm(n);
        if (V.dot(n, hint) < 0) n = V.mul(n, -1);
        const flat = Math.abs(n[1]) > 0.9 && opts.planarTop;
        const uv = flat ? [p[0] / tile, p[2] / tile] : [u * uRep, (v0 + v * total) / tile];
        row.push(m.vert(p, n, uv));
      }
      ids.push(row);
    }
    for (let j = 0; j < vs.length - 1; j++)
      for (let i = 0; i < seg; i++) m.quad(ids[j][i], ids[j][i + 1], ids[j + 1][i + 1], ids[j + 1][i]);
    out.merge(m);
    vAcc += total;
  }
  return out;
}

// a box with rounded edges (radius r, m steps per quarter round), centred on c.
function roundedBox(size, r, c = [0, 0, 0], m = 3, tile = 4) {
  const half = size.map((s) => s / 2);
  r = Math.min(r, ...half.map((h) => h * 0.999));
  const inner = half.map((h) => h - r);
  const axisSamples = (k) => {
    const s = [];
    for (let i = 0; i <= m; i++) s.push(-inner[k] - r * Math.cos(((i / m) * Math.PI) / 2));
    for (let i = m; i >= 0; i--) s.push(inner[k] + r * Math.cos(((i / m) * Math.PI) / 2));
    return s;
  };
  const out = new Mesh();
  for (let ax = 0; ax < 3; ax++)
    for (const sgn of [-1, 1]) {
      const a1 = (ax + 1) % 3, a2 = (ax + 2) % 3;
      const S1 = axisSamples(a1), S2 = axisSamples(a2);
      const ids = [];
      for (let j = 0; j < S2.length; j++) {
        const row = [];
        for (let i = 0; i < S1.length; i++) {
          const q = [0, 0, 0];
          q[ax] = sgn * half[ax];
          q[a1] = S1[i];
          q[a2] = S2[j];
          const cl = q.map((x, k) => Math.max(-inner[k], Math.min(inner[k], x)));
          const n = V.norm(V.sub(q, cl));
          const p = V.add(V.add(cl, V.mul(n, r)), c);
          row.push(out.vert(p, n, uvBox(p, n, tile)));
        }
        ids.push(row);
      }
      for (let j = 0; j < S2.length - 1; j++)
        for (let i = 0; i < S1.length - 1; i++) out.quad(ids[j][i], ids[j][i + 1], ids[j + 1][i + 1], ids[j + 1][i]);
    }
  return out;
}

// sweep a closed 2d profile (points [a, b] in the curve's normal / binormal
// plane) along curve(t) for t in [0, 1]. up = the binormal reference.
function sweep(curve, profile, steps, opts = {}) {
  const e = 1e-4;
  const frame = (t) => {
    const T = V.norm(V.sub(curve(Math.min(1, t + e)), curve(Math.max(0, t - e))));
    const up = opts.up || [0, 0, 1];
    let N = V.cross(up, T);
    if (V.len(N) < 1e-6) N = V.cross([1, 0, 0], T);
    N = V.norm(N);
    const B = V.norm(V.cross(T, N));
    return { T, N, B };
  };
  const plen = [0];
  for (let i = 1; i <= profile.length; i++) {
    const a = profile[i - 1], b = profile[i % profile.length];
    plen.push(plen[i - 1] + Math.hypot(b[0] - a[0], b[1] - a[1]));
  }
  const tile = opts.tile || 4;
  const out = new Mesh();
  let along = 0;
  let prev = curve(0);
  const ids = [];
  for (let s = 0; s <= steps; s++) {
    const t = s / steps;
    const c = curve(t);
    along += V.len(V.sub(c, prev));
    prev = c;
    const { N, B } = frame(t);
    const row = [];
    for (let i = 0; i <= profile.length; i++) {
      const q = profile[i % profile.length];
      const p = V.add(c, V.add(V.mul(N, q[0]), V.mul(B, q[1])));
      // normal: perpendicular to the profile edge, in the n/b plane
      const a = profile[(i - 1 + profile.length) % profile.length], b = profile[(i + 1) % profile.length];
      const d = [b[0] - a[0], b[1] - a[1]];
      let n2 = [d[1], -d[0]];
      // outward from the profile's centroid
      const cx = profile.reduce((s2, z) => s2 + z[0], 0) / profile.length, cy = profile.reduce((s2, z) => s2 + z[1], 0) / profile.length;
      if (n2[0] * (q[0] - cx) + n2[1] * (q[1] - cy) < 0) n2 = [-n2[0], -n2[1]];
      const n = V.norm(V.add(V.mul(N, n2[0]), V.mul(B, n2[1])));
      row.push(out.vert(p, n, opts.uvAlong ? [along / tile, plen[i] / tile] : [plen[i] / tile, along / tile]));
    }
    ids.push(row);
  }
  for (let s = 0; s < steps; s++)
    for (let i = 0; i < profile.length; i++) out.quad(ids[s][i], ids[s][i + 1], ids[s + 1][i + 1], ids[s + 1][i]);
  return out;
}

// a tube (radius r, n sides) along a curve.
function tube(curve, r, steps, sides = 10, opts = {}) {
  const prof = [];
  for (let i = 0; i < sides; i++) {
    const a = (i / sides) * Math.PI * 2;
    prof.push([Math.cos(a) * r, Math.sin(a) * r]);
  }
  return sweep(curve, prof, steps, opts);
}

const circle = (n, r, a0 = 0) => Array.from({ length: n }, (_, i) => [Math.cos(a0 + (i / n) * Math.PI * 2) * r, Math.sin(a0 + (i / n) * Math.PI * 2) * r]);
// a rounded rectangle profile (w x h, corner radius cr)
function roundRect(w, h, cr, steps = 4) {
  const pts = [];
  const cs = [[w / 2 - cr, h / 2 - cr, 0], [-w / 2 + cr, h / 2 - cr, 1], [-w / 2 + cr, -h / 2 + cr, 2], [w / 2 - cr, -h / 2 + cr, 3]];
  for (const [cx, cy, q] of cs)
    for (let i = 0; i <= steps; i++) {
      const a = ((q + i / steps) * Math.PI) / 2;
      pts.push([cx + Math.cos(a) * cr, cy + Math.sin(a) * cr]);
    }
  return pts;
}

module.exports = { V, Mesh, grid, lathe, roundedBox, sweep, tube, circle, roundRect, uvBox };
