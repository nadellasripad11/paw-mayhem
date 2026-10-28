#!/usr/bin/env node
// scans every `x.property = value` and `{ property = value, ... }` table-prop
// pattern in the client ui code and flags any property name that is not a
// real roblox guiobject/instance property. catches typos my eyes keep
// sliding past (e.g. a misspelled property) that a lua syntax checker can't.
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..", "src", "StarterPlayer", "StarterPlayerScripts", "Client", "UI");

// known-valid properties across every classname used anywhere in this ui
// codebase (frame, textlabel, textbutton, scrollingframe, uicorner, uistroke,
// uigradient, uipadding, uilistlayout, uigridlayout, imagelabel, screengui).
const VALID_PROPS = new Set([
  // guiobject base (shared by frame/textlabel/textbutton/scrollingframe)
  "Name", "Parent", "Size", "Position", "AnchorPoint", "Rotation", "Visible",
  "BackgroundColor3", "BackgroundTransparency", "BorderColor3", "BorderSizePixel",
  "BorderMode", "ZIndex", "LayoutOrder", "ClipsDescendants", "Active", "Selectable",
  "AutomaticSize", "SizeConstraint",
  // textlabel/textbutton specific
  "Text", "TextColor3", "TextSize", "TextTransparency", "Font", "TextWrapped",
  "TextXAlignment", "TextYAlignment", "TextTruncate", "TextStrokeTransparency",
  "TextStrokeColor3", "RichText", "TextScaled",
  // textbutton specific
  "AutoButtonColor", "Modal",
  // scrollingframe specific
  "ScrollBarThickness", "CanvasSize", "AutomaticCanvasSize", "ScrollBarImageColor3",
  "ScrollingDirection", "ScrollBarImageTransparency", "ElasticBehavior",
  // screengui
  "IgnoreGuiInset", "ResetOnSpawn", "DisplayOrder", "Enabled",
  // shape-ish on frame (not real, only part has shape) -- excluded intentionally
  // uicorner
  "CornerRadius",
  // uistroke
  "Color", "Thickness", "ApplyStrokeMode", "Transparency", "LineJoinMode",
  // uigradient
  "Rotation", "Offset", "Enabled",
  // uipadding
  "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight",
  // uilistlayout / uigridlayout
  "FillDirection", "Padding", "SortOrder", "HorizontalAlignment", "VerticalAlignment",
  "CellSize", "CellPadding", "StartCorner", "FillDirectionMaxCells",
  // imagelabel (unused currently but harmless to allow)
  "Image", "ImageColor3", "ImageTransparency", "ScaleType",
]);

// these identifiers are never property assignments even though they match the
// `word.word = ` shape — skip them.
const SKIP_LHS_ROOTS = new Set([
  "opts", "state", "self", "cfg", "config", "data", "props", "item", "cat",
  "entry", "profile", "t", "s", "q", "p", "w", "layer", "spec", "board",
]);

function scanFile(file) {
  const src = fs.readFileSync(file, "utf8");
  const lines = src.split("\n");
  const findings = [];

  lines.forEach((line, i) => {
    // pattern a: table constructor field `propname = ` inside { ... }
    // pattern b: direct assignment `var.propname = `
    const assignRe = /\b([A-Za-z_][A-Za-z0-9_]*)\.([A-Z][A-Za-z0-9_]*)\s*=(?!=)/g;
    let m;
    while ((m = assignRe.exec(line))) {
      const [, lhsRoot, prop] = m;
      if (SKIP_LHS_ROOTS.has(lhsRoot)) continue;
      if (prop === "Root") continue; // custom module fields like loadout.root
      if (!VALID_PROPS.has(prop)) {
        findings.push({ line: i + 1, text: line.trim(), prop, lhsRoot });
      }
    }
  });
  return findings;
}

function walk(dir, out) {
  for (const name of fs.readdirSync(dir)) {
    const p = path.join(dir, name);
    const st = fs.statSync(p);
    if (st.isDirectory()) walk(p, out);
    else if (name.endsWith(".lua")) out.push(p);
  }
}

const files = [];
walk(ROOT, files);

let total = 0;
for (const f of files) {
  const findings = scanFile(f);
  for (const fnd of findings) {
    console.log(`${path.relative(process.cwd(), f)}:${fnd.line}  suspicious property '.${fnd.prop}' on '${fnd.lhsRoot}'`);
    console.log(`    ${fnd.text}`);
    total++;
  }
}
console.log(total === 0 ? `\nOK: no suspicious property names across ${files.length} UI files` : `\n${total} suspicious propert${total === 1 ? "y" : "ies"} found`);
process.exit(total === 0 ? 0 : 1);
