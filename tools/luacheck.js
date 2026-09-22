#!/usr/bin/env node
// Lightweight Lua block-balance + return sanity checker for PAW MAYHEM.
// Not a full parser: strips comments/strings, then balances block openers
// against `end`/`until`. Catches the most common "missing end" mistakes.
const fs = require("fs");
const path = require("path");

function walk(dir, out) {
  for (const name of fs.readdirSync(dir)) {
    const p = path.join(dir, name);
    const st = fs.statSync(p);
    if (st.isDirectory()) walk(p, out);
    else if (name.endsWith(".lua")) out.push(p);
  }
}

// Strip long brackets, line comments, and quoted strings (approx).
function strip(src) {
  let s = src;
  // long comments/strings [[ ]] and [=[ ]=]
  s = s.replace(/--\[(=*)\[[\s\S]*?\]\1\]/g, " ");
  s = s.replace(/\[(=*)\[[\s\S]*?\]\1\]/g, " ");
  // line comments
  s = s.replace(/--[^\n]*/g, " ");
  // strings
  s = s.replace(/"(?:\\.|[^"\\])*"/g, '""');
  s = s.replace(/'(?:\\.|[^'\\])*'/g, "''");
  return s;
}

function tokens(s) {
  return s.match(/[A-Za-z_][A-Za-z0-9_]*|[^\sA-Za-z0-9_]/g) || [];
}

let hadError = false;
const files = [];
walk(path.join(__dirname, "..", "src"), files);

for (const f of files) {
  const raw = fs.readFileSync(f, "utf8");
  const s = strip(raw);
  const toks = tokens(s);
  let depth = 0;
  let ret = false;
  // Track function/if/for/while/do/repeat vs end/until.
  // Note: `elseif`/`else`/`then` don't change depth. `do` after for/while
  // is part of the same block, so we only count the leading keyword and treat
  // standalone `do` (rare here) as +1; matching `end` closes it. To avoid the
  // for..do double count, we skip `do` when preceded by a `)` is hard — instead
  // we DON'T count `do` at all and DON'T count the trailing `end` for those...
  // Simpler + reliable here: count function/if/for/while/repeat as openers and
  // `do` NOT as opener; `end` closes function/if/for/while; `until` closes repeat.
  for (let i = 0; i < toks.length; i++) {
    const t = toks[i];
    if (t === "function" || t === "if" || t === "for" || t === "while") depth++;
    else if (t === "repeat") depth++;
    else if (t === "end") depth--;
    else if (t === "until") depth--;
    else if (t === "return") ret = true;
    if (depth < 0) {
      console.log(`? ${path.relative(process.cwd(), f)}: extra 'end'/'until' near token ${i}`);
      hadError = true;
      break;
    }
  }
  if (depth !== 0) {
    console.log(`? ${path.relative(process.cwd(), f)}: unbalanced blocks (depth ${depth})`);
    hadError = true;
  }
  if (!ret) {
    // scripts (.server/.client) don't need return; modules do.
    if (!f.endsWith(".server.lua") && !f.endsWith(".client.lua")) {
      console.log(`? ${path.relative(process.cwd(), f)}: no 'return' found (module?)`);
    }
  }
}

console.log(hadError ? "\nFAIL: block issues found" : `\nOK: ${files.length} files balanced`);
process.exit(hadError ? 1 : 0);
