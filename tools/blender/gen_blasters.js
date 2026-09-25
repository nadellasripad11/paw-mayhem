// Generates BlasterDesigns.json: stylized sci-fi guns with real gun anatomy.
const fs = require('fs');
const OUT = require('path').join(__dirname, '..', '..', 'src', 'ReplicatedStorage', 'Shared', 'Character', 'BlasterDesigns.json');

const box = (size, pos, c, rot, extra) => Object.assign({ k: 'box', size, pos, c }, rot ? { rot } : {}, extra || {});
const cyl = (len, d, pos, c, rot, extra) => Object.assign({ k: 'cyl', len, d, pos, c }, rot ? { rot } : {}, extra || {});
const ball = (d, pos, c, extra) => Object.assign({ k: 'ball', d, pos, c }, extra || {});
const glow = (len, d, pos) => cyl(len, d, pos, 'Glow');
const V = [0, 90, 0]; // cylinder across the gun (along Z)
const UP = [0, 0, 90]; // cylinder standing up

// Shared lower: grip, trigger guard, trigger.
const grip = [
  box([0.36, 0.9, 0.32], [-0.72, -0.66, 0], 'Dark', [0, 0, -14]),
  box([0.62, 0.07, 0.26], [-0.3, -0.62, 0], 'Dark'),
  box([0.07, 0.3, 0.26], [-0.02, -0.5, 0], 'Dark'),
  box([0.07, 0.22, 0.08], [-0.3, -0.45, 0], 'Body', [0, 0, -12]),
];

const stock = (x, h, d, butt) => [
  box([0.95, h, d], [x, 0.02, 0], 'Dark'),
  box([0.16, butt, d + 0.04], [x - 0.55, -0.05, 0], 'Body'),
];
const skeletonStock = (x) => [
  box([1.25, 0.17, 0.27], [x, 0.12, 0], 'Dark'),
  box([1.05, 0.15, 0.27], [x - 0.05, -0.28, 0], 'Dark', [0, 0, 8]),
  box([0.15, 0.68, 0.33], [x - 0.68, -0.07, 0], 'Body'),
];
const scope = (x, y, len, d) => [
  cyl(len, d, [x, y, 0], 'Dark'),
  cyl(0.28, d * 1.35, [x + len / 2, y, 0], 'Dark'),
  cyl(0.22, d * 1.25, [x - len / 2, y, 0], 'Dark'),
  glow(0.03, d * 1.1, [x + len / 2 + 0.15, y, 0]),
  box([0.13, y - 0.3, 0.15], [x - len * 0.25, (y + 0.3) / 2 + 0.02, 0], 'Dark'),
  box([0.13, y - 0.3, 0.15], [x + len * 0.25, (y + 0.3) / 2 + 0.02, 0], 'Dark'),
];
const handle = (y) => [
  box([1.05, 0.1, 0.18], [0, y + 0.14, 0], 'Dark'),
  box([0.1, 0.22, 0.16], [-0.45, y + 0.02, 0], 'Dark'),
  box([0.1, 0.22, 0.16], [0.45, y + 0.02, 0], 'Dark'),
];
const vents = (xs, y, h, d) => xs.map((x) => box([0.08, h, d], [x, y, 0], 'Dark'));
const strip = (len, x, y, z) => box([len, 0.05, 0.02], [x, y, z], 'Glow');

const rifleCore = [
  box([2.1, 0.62, 0.46], [0, 0.05, 0], 'Body'),
  box([1.3, 0.28, 0.42], [-0.1, -0.35, 0], 'Dark'),
  box([2.0, 0.08, 0.26], [0, 0.4, 0], 'Dark'),
  box([1.2, 0.5, 0.44], [1.62, 0.02, 0], 'Accent'),
  ...vents([1.35, 1.62, 1.89], 0.02, 0.3, 0.46),
  cyl(0.7, 0.2, [2.55, 0.08, 0], 'Dark'),
  box([0.32, 0.26, 0.26], [2.95, 0.08, 0], 'Body'),
  glow(0.04, 0.14, [3.13, 0.08, 0]),
  box([0.36, 0.85, 0.3], [0.35, -0.7, 0], 'Dark', [0, 0, -10]),
  ...stock(-1.5, 0.46, 0.34, 0.66),
  strip(1.2, -0.1, 0.12, 0.24),
];

const designs = {
  PawBlaster: [
    ...rifleCore,
    box([0.26, 0.2, 0.18], [-0.6, 0.52, 0], 'Dark'),
    box([0.1, 0.26, 0.1], [1.1, 0.47, 0], 'Dark'),
  ],
  Starfall: [
    box([2.2, 0.56, 0.42], [0, 0.05, 0], 'Body'),
    box([1.1, 0.24, 0.38], [-0.15, -0.3, 0], 'Dark'),
    box([1.5, 0.4, 0.38], [1.8, 0.05, 0], 'Accent'),
    ...vents([1.3, 1.6, 1.9, 2.2], 0.05, 0.26, 0.4),
    cyl(1.2, 0.18, [3.1, 0.07, 0], 'Dark'),
    box([0.36, 0.22, 0.22], [3.78, 0.07, 0], 'Body'),
    glow(0.04, 0.12, [3.98, 0.07, 0]),
    ...scope(0.1, 0.66, 1.5, 0.3),
    box([0.32, 0.55, 0.28], [0.3, -0.55, 0], 'Dark'),
    ...skeletonStock(-1.7),
    box([0.6, 0.14, 0.3], [-1.55, 0.28, 0], 'Accent'),
    strip(1.1, -0.1, 0.1, 0.22),
  ],
  BoomPaw: [
    box([1.9, 0.85, 0.66], [0, 0.1, 0], 'Body'),
    cyl(1.5, 0.66, [1.7, 0.2, 0], 'Dark'),
    cyl(0.5, 0.76, [1.2, 0.2, 0], 'Accent'),
    cyl(0.26, 0.82, [2.5, 0.2, 0], 'Body'),
    glow(0.04, 0.5, [2.64, 0.2, 0]),
    cyl(0.7, 1.0, [0.25, -0.55, 0], 'Accent', V),
    cyl(0.74, 0.5, [0.25, -0.55, 0], 'Dark', V),
    box([1.6, 0.08, 0.3], [0, 0.56, 0], 'Dark'),
    ...handle(0.62),
    box([0.26, 0.55, 0.26], [1.5, -0.38, 0], 'Dark', [0, 0, 8]),
    ...stock(-1.4, 0.55, 0.44, 0.78),
    strip(1.0, -0.1, 0.3, 0.34),
  ],
  RapidPaw: [
    box([1.7, 0.55, 0.4], [0, 0.08, 0], 'Body'),
    box([0.8, 0.38, 0.36], [1.25, 0.08, 0], 'Accent'),
    ...vents([1.1, 1.4], 0.08, 0.24, 0.38),
    cyl(0.5, 0.16, [1.85, 0.1, 0], 'Dark'),
    cyl(0.45, 0.26, [2.2, 0.1, 0], 'Body'),
    glow(0.04, 0.14, [2.44, 0.1, 0]),
    box([0.28, 1.05, 0.24], [0.45, -0.72, 0], 'Dark', [0, 0, -6]),
    box([0.34, 0.24, 0.24], [-0.15, 0.48, 0], 'Dark'),
    box([0.02, 0.14, 0.16], [0.03, 0.5, 0], 'Glow'),
    box([0.9, 0.08, 0.2], [-1.25, 0.2, 0], 'Dark'),
    box([0.9, 0.08, 0.2], [-1.25, -0.15, 0], 'Dark'),
    box([0.1, 0.5, 0.28], [-1.72, 0.02, 0], 'Body'),
    strip(0.9, -0.1, 0.14, 0.21),
  ],
  FrostBlaster: [
    box([2.0, 0.64, 0.48], [0, 0.05, 0], 'Body'),
    box([1.2, 0.26, 0.44], [-0.1, -0.34, 0], 'Dark'),
    cyl(1.1, 0.42, [0.1, 0.62, 0], 'Accent', null, { m: 'glass', t: 0.4 }),
    cyl(1.0, 0.24, [0.1, 0.62, 0], 'Glow'),
    cyl(0.1, 0.46, [-0.45, 0.62, 0], 'Dark'),
    cyl(0.1, 0.46, [0.65, 0.62, 0], 'Dark'),
    box([1.1, 0.46, 0.42], [1.55, 0.05, 0], 'Accent'),
    box([0.7, 0.08, 0.1], [2.4, 0.22, 0], 'Dark'),
    box([0.7, 0.08, 0.1], [2.4, -0.12, 0], 'Dark'),
    box([0.24, 0.24, 0.24], [2.35, 0.05, 0], 'Glow', [45, 0, 45]),
    box([0.36, 0.5, 0.3], [0.35, -0.55, 0], 'Accent'),
    ...stock(-1.45, 0.44, 0.34, 0.62),
    strip(1.0, -0.1, 0.12, 0.25),
  ],
  VoidCannon: [
    box([2.2, 0.95, 0.76], [0, 0.12, 0], 'Body'),
    cyl(1.6, 0.62, [1.9, 0.18, 0], 'Dark'),
    cyl(0.12, 0.76, [1.4, 0.18, 0], 'Accent'),
    cyl(0.12, 0.76, [1.8, 0.18, 0], 'Accent'),
    cyl(0.12, 0.76, [2.2, 0.18, 0], 'Accent'),
    cyl(0.3, 0.9, [2.78, 0.18, 0], 'Body'),
    glow(0.04, 0.56, [2.95, 0.18, 0]),
    box([0.7, 0.2, 0.02], [-0.1, 0.18, 0.39], 'Glow'),
    ...handle(0.72),
    box([0.26, 0.5, 0.26], [1.3, -0.4, 0], 'Dark'),
    ...stock(-1.5, 0.6, 0.5, 0.85),
  ],
  BubbleBlaster: [
    box([1.8, 0.62, 0.46], [0, 0.05, 0], 'Body'),
    cyl(0.9, 0.56, [-0.25, 0.8, 0], 'Glow', UP, { m: 'glass', t: 0.45 }),
    cyl(0.7, 0.36, [-0.25, 0.8, 0], 'Accent', UP),
    cyl(0.1, 0.6, [-0.25, 1.28, 0], 'Dark', UP),
    cyl(1.0, 0.36, [1.4, 0.1, 0], 'Accent'),
    cyl(0.2, 0.56, [1.98, 0.1, 0], 'Body'),
    glow(0.04, 0.4, [2.1, 0.1, 0]),
    box([0.6, 0.3, 0.4], [1.25, -0.25, 0], 'Dark'),
    ...stock(-1.35, 0.42, 0.32, 0.6),
    strip(0.9, 0.1, 0.12, 0.24),
  ],
  GoldenPurr: [
    ...rifleCore,
    ...scope(-0.05, 0.62, 0.9, 0.24),
  ],
  CometClaw: [
    box([2.2, 0.52, 0.4], [0, 0.05, 0], 'Body'),
    box([1.2, 0.36, 0.36], [1.7, 0.05, 0], 'Accent'),
    ...vents([1.4, 1.7, 2.0], 0.05, 0.22, 0.38),
    box([0.5, 0.06, 0.3], [2.55, 0.3, 0], 'Body', [0, 0, -15]),
    box([0.5, 0.06, 0.3], [2.55, -0.2, 0], 'Body', [0, 0, 15]),
    cyl(1.0, 0.16, [2.7, 0.05, 0], 'Dark'),
    ball(0.3, [3.25, 0.05, 0], 'Glow'),
    ...scope(0, 0.58, 1.1, 0.26),
    box([0.3, 0.55, 0.26], [0.3, -0.52, 0], 'Dark'),
    ...skeletonStock(-1.6),
    strip(1.0, -0.1, 0.1, 0.21),
  ],
  PurrfectStorm: [
    box([2.0, 0.8, 0.6], [0, 0.08, 0], 'Body'),
    cyl(1.1, 0.22, [1.65, 0.1, 0], 'Dark'),
    cyl(1.5, 0.16, [1.75, 0.3, 0], 'Dark'),
    cyl(1.5, 0.16, [1.75, 0.0, 0.18], 'Dark'),
    cyl(1.5, 0.16, [1.75, 0.0, -0.18], 'Dark'),
    cyl(0.12, 0.72, [1.15, 0.1, 0], 'Accent'),
    cyl(0.12, 0.72, [2.2, 0.1, 0], 'Accent'),
    glow(0.04, 0.12, [2.52, 0.3, 0]),
    glow(0.04, 0.12, [2.52, 0.0, 0.18]),
    glow(0.04, 0.12, [2.52, 0.0, -0.18]),
    box([0.7, 0.55, 0.5], [0.2, -0.62, 0], 'Accent'),
    box([0.72, 0.06, 0.52], [0.2, -0.33, 0], 'Dark'),
    ...handle(0.62),
    ...stock(-1.45, 0.5, 0.42, 0.72),
  ],
};

const palettes = {
  PawBlaster: { Body: [70, 74, 84], Accent: [120, 200, 110], Dark: [30, 32, 38], Glow: [150, 255, 140] },
  Starfall: { Body: [200, 205, 215], Accent: [70, 110, 230], Dark: [34, 36, 44], Glow: [120, 190, 255] },
  BoomPaw: { Body: [72, 68, 70], Accent: [230, 120, 40], Dark: [32, 30, 32], Glow: [255, 190, 90] },
  RapidPaw: { Body: [60, 60, 72], Accent: [220, 80, 170], Dark: [28, 28, 36], Glow: [255, 130, 220] },
  FrostBlaster: { Body: [190, 210, 225], Accent: [80, 160, 220], Dark: [36, 46, 60], Glow: [140, 235, 255] },
  VoidCannon: { Body: [50, 44, 64], Accent: [130, 80, 210], Dark: [22, 20, 30], Glow: [200, 130, 255] },
  BubbleBlaster: { Body: [80, 86, 100], Accent: [250, 130, 190], Dark: [34, 36, 44], Glow: [140, 220, 255] },
  GoldenPurr: { Body: [212, 170, 70], Accent: [245, 240, 225], Dark: [50, 40, 26], Glow: [255, 230, 150] },
  CometClaw: { Body: [185, 195, 210], Accent: [60, 170, 230], Dark: [30, 34, 46], Glow: [150, 230, 255] },
  PurrfectStorm: { Body: [66, 58, 92], Accent: [150, 110, 230], Dark: [26, 24, 36], Glow: [180, 235, 255] },
};

const data = {
  _about: 'Stylized sci-fi blasters with real gun anatomy (receiver, rail, handguard, magazine, stock, sights, muzzle). Gun-local axes: +X forward, +Y up, +Z the side facing the camera. cyl = cylinder along X, ball, box, wedge; rot = degrees (x, y, z); c = palette slot. Default materials by slot: Body metal, Accent/Dark plastic, Glow neon (m overrides; t = transparency). Generated by tools/blender/gen_blasters.js and rendered by tools/blender/preview_blasters.py.',
  materials: { Body: 'metal', Accent: 'plastic', Dark: 'plastic', Glow: 'neon' },
  palettes,
  grip,
  designs,
};

let json = JSON.stringify(data, null, 2);
json = json.replace(/\[\n\s+(-?[\d.]+),\n\s+(-?[\d.]+),\n\s+(-?[\d.]+)\n\s+\]/g, '[$1, $2, $3]');
fs.writeFileSync(OUT, json + '\n');
let parts = {};
for (const [k, v] of Object.entries(designs)) parts[k] = v.length + grip.length;
console.log('ok', parts);
