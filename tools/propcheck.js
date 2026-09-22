#!/usr/bin/env node
// Scans every `X.Property = value` and `{ Property = value, ... }` table-prop
// pattern in the client UI code and flags any property name that is NOT a
// real Roblox GuiObject/Instance property. Catches typos my eyes keep
// sliding past (e.g. a misspelled property) that a Lua syntax checker can't.
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..", "src", "StarterPlayer", "StarterPlayerScripts", "Client", "UI");

// Known-valid properties across every ClassName used anywhere in this UI
// codebase (Frame, TextLabel, TextButton, ScrollingFrame, UICorner, UIStroke,
// UIGradient, UIPadding, UIListLayout, UIGridLayout, ImageLabel, ScreenGui).
const VALID_PROPS = new Set([
  // GuiObject base (shared by Frame/TextLabel/TextButton/ScrollingFrame)
  "Name", "Parent", "Size", "Position", "AnchorPoint", "Rotation", "Visible",
  "BackgroundColor3", "BackgroundTransparency", "BorderColor3", "BorderSizePixel",
  "BorderMode", "ZIndex", "LayoutOrder", "ClipsDescendants", "Active", "Selectable",
  "AutomaticSize", "SizeConstraint",
  // TextLabel/TextButton specific
  "Text", "TextColor3", "TextSize", "TextTransparency", "Font", "TextWrapped",
  "TextXAlignment", "TextYAlignment", "TextTruncate", "TextStrokeTransparency",
  "TextStrokeColor3", "RichText", "TextScaled",
  // TextButton specific
  "AutoButtonColor", "Modal",
  // ScrollingFrame specific
  "ScrollBarThickness", "CanvasSize", "AutomaticCanvasSize", "ScrollBarImageColor3",
  "ScrollingDirection", "ScrollBarImageTransparency", "ElasticBehavior",
  // ScreenGui
  "IgnoreGuiInset", "ResetOnSpawn", "DisplayOrder", "Enabled",
  // Shape-ish on Frame (not real, only Part has Shape) -- excluded intentionally
  // UICorner
  "CornerRadius",
  // UIStroke
  "Color", "Thickness", "ApplyStrokeMode", "Transparency", "LineJoinMode",
  // UIGradient
  "Rotation", "Offset", "Enabled",
  // UIPadding
  "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight",
  // UIListLayout / UIGridLayout
  "FillDirection", "Padding", "SortOrder", "HorizontalAlignment", "VerticalAlignment",
  "CellSize", "CellPadding", "StartCorner", "FillDirectionMaxCells",
  // ImageLabel (unused currently but harmless to allow)
  "Image", "ImageColor3", "ImageTransparency", "ScaleType",
]);

// These identifiers are never property assignments even though they match the
// `Word.Word = ` shape — skip them.
const SKIP_LHS_ROOTS = new Set([
  "opts", "state", "self", "cfg", "config", "data", "props", "item", "cat",
  "entry", "profile", "t", "s", "q", "p", "w", "layer", "spec", "board",
]);

function scanFile(file) {
  const src = fs.readFileSync(file, "utf8");
  const lines = src.split("\n");
  const findings = [];

  lines.forEach((line, i) => {
    // Pattern A: table constructor field `PropName = ` inside { ... }
    // Pattern B: direct assignment `var.PropName = `
    const assignRe = /\b([A-Za-z_][A-Za-z0-9_]*)\.([A-Z][A-Za-z0-9_]*)\s*=(?!=)/g;
    let m;
    while ((m = assignRe.exec(line))) {
      const [, lhsRoot, prop] = m;
      if (SKIP_LHS_ROOTS.has(lhsRoot)) continue;
      if (prop === "Root") continue; // custom module fields like Loadout.Root
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
