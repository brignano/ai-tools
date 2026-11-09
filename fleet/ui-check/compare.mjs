// Fleet before/after screenshots (skills/ux-review §2). Loads each path from a
// "before" and an "after" base URL at phone and desktop widths, light and dark,
// and writes one labelled side-by-side PNG per view, phone first.
//
//   node compare.mjs <before-url> <after-url> [path ...]
//
// Use "-" as <before-url> for a brand-new screen (after only).
// Paths are joined onto each base URL, so a base with a sub-path
// (https://host/app/) keeps it.
// Env: UI_COMPARE_OUT (default $TMPDIR/ui-compare, outside the repo so the
// PNGs never land in a commit), UI_COMPARE_SCHEMES (default
// "light dark"; set "light" for a UI with no dark mode).
// Needs only `playwright`, resolved with require() so NODE_PATH works.
import { createRequire } from "node:module";
import { mkdirSync } from "node:fs";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";

const { chromium } = createRequire(import.meta.url)("playwright");

const [before, after, ...rawPaths] = process.argv.slice(2);
if (!before || !after) {
  console.error("usage: node compare.mjs <before-url|-> <after-url> [path ...]");
  process.exit(2);
}
const paths = rawPaths.length ? rawPaths : ["/"];
const out = resolve(process.env.UI_COMPARE_OUT || join(tmpdir(), "ui-compare"));
const schemes = (process.env.UI_COMPARE_SCHEMES || "light dark").split(/\s+/).filter(Boolean);
// Numbered so a plain `ls` or glob lists phone views first.
const viewports = { "1-phone": { width: 390, height: 844 }, "2-desktop": { width: 1280, height: 800 } };
mkdirSync(out, { recursive: true });

const browser = await chromium.launch();
let failed = false;

// Phone at 2x so it reads on a real phone; desktop at 1x keeps files small.
const scale = (vpName) => (vpName === "1-phone" ? 2 : 1);

async function shoot(base, path, viewport, colorScheme, deviceScaleFactor) {
  const ctx = await browser.newContext({ viewport, colorScheme, reducedMotion: "reduce", deviceScaleFactor });
  try {
    const page = await ctx.newPage();
    const url = new URL(path.replace(/^\/+/, ""), base.endsWith("/") ? base : `${base}/`).href;
    const res = await page.goto(url, { waitUntil: "networkidle" });
    if (!res || res.status() >= 400) throw new Error(`HTTP ${res ? res.status() : "no response"}`);
    return (await page.screenshot({ fullPage: true })).toString("base64");
  } finally {
    await ctx.close();
  }
}

const esc = (t) => t.replace(/[&<>"]/g, (c) => `&#${c.charCodeAt(0)};`);
const panel = (label, b64) =>
  `<figure><figcaption>${esc(label)}</figcaption>${
    b64 ? `<img src="data:image/png;base64,${b64}">` : `<div class="none">nothing here before</div>`
  }</figure>`;

// File-name part per path; a numeric suffix keeps /a-b and /a/b apart.
const seen = new Map();
const names = paths.map((path) => {
  const base = path.replace(/[^a-z0-9]+/gi, "-").replace(/^-|-$/g, "") || "home";
  const n = (seen.get(base) || 0) + 1;
  seen.set(base, n);
  return n === 1 ? base : `${base}-${n}`;
});

for (const [vpName, viewport] of Object.entries(viewports)) {
  for (const [i, path] of paths.entries()) {
    for (const scheme of schemes) {
      const slug = `${vpName}-${names[i]}-${scheme}`;
      let ctx;
      try {
        const [b, a] = await Promise.all([
          before === "-" ? null : shoot(before, path, viewport, scheme, scale(vpName)),
          shoot(after, path, viewport, scheme, scale(vpName)),
        ]);
        // Compose in a plain page so no extra image library is needed. The grey
        // matte is harness chrome, not product UI, so it uses no design tokens.
        ctx = await browser.newContext({ viewport: { width: viewport.width * 2 + 48, height: 400 }, deviceScaleFactor: scale(vpName) });
        const page = await ctx.newPage();
        await page.setContent(`<!doctype html><style>
          body{margin:0;padding:16px;display:flex;gap:16px;align-items:flex-start;background:gray;font:600 20px system-ui,sans-serif}
          figure{margin:0;width:${viewport.width}px} figcaption{padding:0 0 8px;color:white}
          img{display:block;width:100%;outline:1px solid black}
          .none{height:200px;display:grid;place-items:center;background:dimgray;color:white}
        </style>${panel(`Before · ${path} · ${vpName.slice(2)} · ${scheme}`, b)}${panel("After", a)}`);
        await page.waitForLoadState("load");
        const file = join(out, `${slug}.png`);
        await page.screenshot({ path: file, fullPage: true });
        console.log(`ok   ${file}`);
      } catch (e) {
        failed = true;
        console.log(`FAIL ${path} ${vpName} ${scheme}: ${e.message}`);
      } finally {
        await ctx?.close();
      }
    }
  }
}

await browser.close();
process.exit(failed ? 1 : 0);
