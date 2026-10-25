// Checks assets/LobbyMeshes.glb against the glTF 2.0 rules Studio's importer
// relies on, and against Roblox's mesh limits.   node tools/lobby/validate.js
const fs = require('fs');
const path = require('path');

const file = path.join(__dirname, '..', '..', 'assets', 'LobbyMeshes.glb');
const buf = fs.readFileSync(file);
const errors = [];
const err = (m) => errors.push(m);

if (buf.readUInt32LE(0) !== 0x46546c67) err('bad magic');
if (buf.readUInt32LE(4) !== 2) err('not glTF 2');
if (buf.readUInt32LE(8) !== buf.length) err('length header != file size');
const jlen = buf.readUInt32LE(12);
if (buf.readUInt32LE(16) !== 0x4e4f534a) err('first chunk is not JSON');
const json = JSON.parse(buf.slice(20, 20 + jlen).toString('utf8'));
const boff = 20 + jlen;
const blen = buf.readUInt32LE(boff);
if (buf.readUInt32LE(boff + 4) !== 0x004e4942) err('second chunk is not BIN');
const bin = buf.slice(boff + 8, boff + 8 + blen);
if (json.buffers[0].byteLength > bin.length) err('buffer longer than BIN chunk');

const SIZE = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4 };
const CT = { 5126: 4, 5125: 4, 5123: 2 };
json.bufferViews.forEach((bv, i) => {
  if (bv.byteOffset % 4) err(`bufferView ${i} not 4-byte aligned`);
  if (bv.byteOffset + bv.byteLength > bin.length) err(`bufferView ${i} out of range`);
});
const read = (ai) => {
  const a = json.accessors[ai];
  const bv = json.bufferViews[a.bufferView];
  const n = a.count * SIZE[a.type];
  if (n * CT[a.componentType] > bv.byteLength) err(`accessor ${ai} longer than its view`);
  const start = bin.byteOffset + bv.byteOffset + (a.byteOffset || 0);
  const ab = bin.buffer.slice(start, start + n * CT[a.componentType]);
  return a.componentType === 5126 ? new Float32Array(ab) : new Uint32Array(ab);
};
const names = new Set();
let total = 0;
for (const node of json.nodes) {
  if (names.has(node.name)) err('duplicate node name ' + node.name);
  names.add(node.name);
  const mesh = json.meshes[node.mesh];
  if (mesh.name !== node.name) err('mesh/node name mismatch ' + node.name);
  for (const prim of mesh.primitives) {
    const pos = read(prim.attributes.POSITION), nrm = read(prim.attributes.NORMAL), uv = read(prim.attributes.TEXCOORD_0), idx = read(prim.indices);
    const vc = pos.length / 3;
    if (nrm.length / 3 !== vc || uv.length / 2 !== vc) err(node.name + ': attribute counts differ');
    const a = json.accessors[prim.attributes.POSITION];
    const mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity];
    for (let i = 0; i < vc; i++) for (let k = 0; k < 3; k++) {
      const v = pos[i * 3 + k];
      if (!Number.isFinite(v)) err(node.name + ': NaN position');
      mn[k] = Math.min(mn[k], v);
      mx[k] = Math.max(mx[k], v);
    }
    for (let k = 0; k < 3; k++) if (Math.abs(mn[k] - a.min[k]) > 1e-4 || Math.abs(mx[k] - a.max[k]) > 1e-4) err(node.name + ': min/max wrong');
    for (let i = 0; i < vc; i++) {
      const l = Math.hypot(nrm[i * 3], nrm[i * 3 + 1], nrm[i * 3 + 2]);
      if (!(Math.abs(l - 1) < 1e-3)) { err(node.name + ': normal not unit length'); break; }
    }
    for (const v of uv) if (!Number.isFinite(v)) { err(node.name + ': NaN uv'); break; }
    if (idx.length % 3) err(node.name + ': index count not a multiple of 3');
    for (const i of idx) if (i >= vc) { err(node.name + ': index out of range'); break; }
    const tris = idx.length / 3;
    total += tris;
    if (tris > 20000) err(node.name + `: ${tris} triangles (Roblox max 20000)`);
    if (vc > 65535) err(node.name + `: ${vc} vertices`);
    const mat = json.materials[prim.material];
    if (!mat) err(node.name + ': no material');
    const size = mx.map((v, k) => v - mn[k]);
    if (Math.max(...size) > 2048) err(node.name + ': bigger than 2048 studs');
    console.log(`  ${node.name.padEnd(18)} ${String(tris).padStart(6)} tris  ${String(vc).padStart(6)} verts  ${mat.name}`);
  }
}
for (const img of json.images) {
  const bv = json.bufferViews[img.bufferView];
  const head = bin.slice(bv.byteOffset, bv.byteOffset + 24);
  if (head.readUInt32BE(0) !== 0x89504e47) err(img.name + ': not a PNG');
  const w = head.readUInt32BE(16), h = head.readUInt32BE(20);
  if (w > 1024 || h > 1024) err(img.name + `: ${w}x${h} (Roblox max 1024)`);
}
for (const m of json.materials) {
  const p = m.pbrMetallicRoughness;
  for (const t of [p.baseColorTexture, p.metallicRoughnessTexture, m.normalTexture]) if (!t || !json.textures[t.index]) err(m.name + ': missing texture');
}
console.log(`${json.nodes.length} meshes, ${total} triangles, ${json.images.length} images, ${(buf.length / 1e6).toFixed(1)} MB`);
if (errors.length) {
  console.log('FAIL\n' + errors.join('\n'));
  process.exit(1);
}
console.log('OK: LobbyMeshes.glb is valid');
