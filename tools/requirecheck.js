#!/usr/bin/env node
// Simulates the Rojo instance tree from default.project.json + src, then checks
// that every require(...) path expression resolves to an existing module.
// Handles: script.Parent chains, game:GetService("X").a.b, and local aliases
// like `local Shared = ReplicatedStorage.Shared`.
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");
const proj = JSON.parse(fs.readFileSync(path.join(ROOT, "default.project.json"), "utf8"));

// ---- Build virtual tree from a src directory ----
// node = { name, className, children: {name:node}, parent }
function makeNode(name, className, parent) {
  return { name, className, children: {}, parent };
}

function classFromFile(fname) {
  if (fname.endsWith(".server.lua")) return { cls: "Script", base: fname.slice(0, -".server.lua".length) };
  if (fname.endsWith(".client.lua")) return { cls: "LocalScript", base: fname.slice(0, -".client.lua".length) };
  if (fname.endsWith(".lua")) return { cls: "ModuleScript", base: fname.slice(0, -".lua".length) };
  return null;
}

// Map disk path -> node, recording where each lua file lives for require resolution.
const fileToNode = new Map(); // absolute lua path -> node

function buildDir(dirAbs, name, parent) {
  const entries = fs.readdirSync(dirAbs);
  // detect init files
  let selfClass = "Folder";
  let initFile = null;
  for (const e of entries) {
    if (e === "init.server.lua") { selfClass = "Script"; initFile = e; }
    else if (e === "init.client.lua") { selfClass = "LocalScript"; initFile = e; }
    else if (e === "init.lua") { selfClass = "ModuleScript"; initFile = e; }
  }
  const node = makeNode(name, selfClass, parent);
  if (initFile) fileToNode.set(path.join(dirAbs, initFile), node);

  for (const e of entries) {
    const abs = path.join(dirAbs, e);
    const st = fs.statSync(abs);
    if (st.isDirectory()) {
      const child = buildDir(abs, e, node);
      node.children[child.name] = child;
    } else if (e.startsWith("init.")) {
      // handled as self
    } else {
      const info = classFromFile(e);
      if (info) {
        const child = makeNode(info.base, info.cls, node);
        node.children[child.name] = child;
        fileToNode.set(abs, child);
      }
    }
  }
  return node;
}

// Root DataModel
const game = makeNode("game", "DataModel", null);
function ensureService(name) {
  if (!game.children[name]) game.children[name] = makeNode(name, name, game);
  return game.children[name];
}

// Walk project tree mapping $path dirs to services/children.
function applyProjectNode(objName, obj, parentNode) {
  let node;
  if (parentNode === game) {
    node = ensureService(objName);
  } else {
    node = parentNode.children[objName] || makeNode(objName, obj["$className"] || "Folder", parentNode);
    parentNode.children[objName] = node;
  }
  if (obj["$path"]) {
    const dirAbs = path.join(ROOT, obj["$path"]);
    if (fs.existsSync(dirAbs)) {
      const built = buildDir(dirAbs, objName, parentNode);
      // merge built children into node, keep node identity/class
      node.className = built.className === "Folder" ? node.className : built.className;
      for (const k in built.children) { built.children[k].parent = node; node.children[k] = built.children[k]; }
      // if built is a script (init), remember mapping to node
      for (const [k, v] of fileToNode.entries()) { if (v === built) fileToNode.set(k, node); }
    } else {
      console.log(`! $path missing on disk: ${obj["$path"]}`);
    }
  }
  for (const key in obj) {
    if (key.startsWith("$")) continue;
    applyProjectNode(key, obj[key], node);
  }
}
for (const key in proj.tree) {
  if (key.startsWith("$")) continue;
  applyProjectNode(key, proj.tree[key], game);
}

// Aliases for service access.
const SERVICE_ALIASES = { workspace: "Workspace", Workspace: "Workspace" };

// ---- Resolve a path expression against the tree ----
function resolveSegments(startNode, segs) {
  let n = startNode;
  for (const s of segs) {
    if (!n) return null;
    if (s === "Parent") { n = n.parent; continue; }
    // WaitForChild("X") / FindFirstChild("X")
    n = n.children[s] || null;
  }
  return n;
}

// Parse a require argument expression into {root, segs}.
// Supports: script..., game:GetService("X")..., ReplicatedStorage...(alias), and var aliases.
function analyzeFile(absPath, node) {
  const src = fs.readFileSync(absPath, "utf8");
  // collect local aliases: local NAME = <expr>
  const aliasRe = /local\s+([A-Za-z_]\w*)\s*=\s*([^\n]+)/g;
  const aliases = {};
  let m;
  while ((m = aliasRe.exec(src))) {
    aliases[m[1]] = m[2].trim();
  }

  // Expand a textual expr to segments relative to a known root node, or null.
  function exprToTarget(expr) {
    expr = expr.replace(/\s+/g, "");
    // strip trailing require-close etc handled by caller
    // Replace :WaitForChild("X") / :FindFirstChild("X") / (":X") with .X
    expr = expr.replace(/:WaitForChild\("([^"]+)"\)/g, ".$1");
    expr = expr.replace(/:FindFirstChild\("([^"]+)"\)/g, ".$1");
    // game:GetService("X") -> game.X
    expr = expr.replace(/game:GetService\("([^"]+)"\)/g, "game.$1");
    // Resolve leading alias variable
    let parts = expr.split(".");
    let head = parts[0];
    // follow alias chains up to a few times
    let guard = 0;
    while (aliases[head] && guard < 6) {
      const rep = aliases[head].replace(/:WaitForChild\("([^"]+)"\)/g, ".$1").replace(/:FindFirstChild\("([^"]+)"\)/g, ".$1").replace(/game:GetService\("([^"]+)"\)/g, "game.$1").replace(/\s+/g, "");
      parts = (rep + "." + parts.slice(1).join(".")).split(".").filter(Boolean);
      head = parts[0];
      guard++;
    }
    // Determine start node
    let start, segs;
    if (head === "script") { start = node; segs = parts.slice(1); }
    else if (head === "game") { start = game; segs = parts.slice(1); }
    else if (SERVICE_ALIASES[head]) { start = ensureService(SERVICE_ALIASES[head]); segs = parts.slice(1); }
    else if (game.children[head]) { start = game.children[head]; segs = parts.slice(1); }
    else return { ok: false, reason: "unknown-root:" + head, expr };
    const target = resolveSegments(start, segs);
    if (target && (target.className === "ModuleScript")) return { ok: true };
    if (target) return { ok: false, reason: "not-a-module(" + target.className + ")", expr };
    return { ok: false, reason: "unresolved", expr };
  }

  // find require(...) with a single balanced-ish argument (no nested parens except GetService)
  const reqRe = /require\(([^\n]+?)\)\s*$/gm;
  const results = [];
  // simpler: match require( ... ) up to the matching close on same line
  const lineRe = /require\((.+)\)/g;
  let mm;
  while ((mm = lineRe.exec(src))) {
    let arg = mm[1];
    // trim to first top-level close paren balance
    let depth = 1, out = "";
    for (let i = 0; i < arg.length; i++) {
      const ch = arg[i];
      if (ch === "(") depth++;
      else if (ch === ")") { depth--; if (depth === 0) break; }
      out += ch;
    }
    arg = out.trim();
    if (!arg || arg.startsWith('"')) continue;
    const r = exprToTarget(arg);
    if (!r.ok) results.push(r);
  }
  return results;
}

let problems = 0;
let checked = 0;
for (const [abs, node] of fileToNode.entries()) {
  checked++;
  const res = analyzeFile(abs, node);
  for (const r of res) {
    console.log(`? ${path.relative(ROOT, abs)}: ${r.reason}  ->  require(${r.expr})`);
    problems++;
  }
}
console.log(problems === 0 ? `\nOK: all requires resolve (${checked} modules)` : `\n${problems} require issue(s)`);
process.exit(problems === 0 ? 0 : 1);
