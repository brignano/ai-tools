// Fleet UX gate: load each page at mobile and desktop widths, light and dark,
// run axe-core (WCAG 2.2 AA) and save screenshots. Exit 1 on any serious or
// critical violation, a page that fails to load, or a console error.
//
//   node check.mjs <base-url> [path ...]
// Needs `playwright` and `@axe-core/playwright` resolvable from this folder or
// NODE_PATH. Screenshots go to $UI_CHECK_OUT (default ./ui-check).
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { chromium } from "playwright";
import { AxeBuilder } from "@axe-core/playwright";

const [base, ...rawPaths] = process.argv.slice(2);
if (!base) {
  console.error("usage: node check.mjs <base-url> [path ...]");
  process.exit(2);
}
const paths = rawPaths.length ? rawPaths : ["/"];
const out = process.env.UI_CHECK_OUT || "ui-check";
mkdirSync(out, { recursive: true });

const viewports = { mobile: { width: 390, height: 844 }, desktop: { width: 1280, height: 800 } };
const schemes = ["light", "dark"];
const blocking = new Set(["serious", "critical"]);

const browser = await chromium.launch();
const report = [];
let failed = false;

for (const path of paths) {
  for (const [vpName, viewport] of Object.entries(viewports)) {
    for (const colorScheme of schemes) {
      const ctx = await browser.newContext({ viewport, colorScheme, reducedMotion: "reduce" });
      const page = await ctx.newPage();
      const errors = [];
      page.on("console", (m) => m.type() === "error" && errors.push(m.text()));
      page.on("pageerror", (e) => errors.push(String(e)));
      const label = `${path} ${vpName} ${colorScheme}`;
      const slug = `${path.replace(/[^a-z0-9]+/gi, "-").replace(/^-|-$/g, "") || "home"}-${vpName}-${colorScheme}`;
      try {
        const res = await page.goto(new URL(path, base).href, { waitUntil: "networkidle" });
        if (!res || res.status() >= 400) throw new Error(`HTTP ${res ? res.status() : "no response"}`);
        await page.screenshot({ path: join(out, `${slug}.png`), fullPage: true });
        const { violations } = await new AxeBuilder({ page })
          .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"])
          .analyze();
        const bad = violations.filter((v) => blocking.has(v.impact));
        for (const v of bad) {
          failed = true;
          console.log(`FAIL ${label}: [${v.impact}] ${v.id} — ${v.help} (${v.nodes.length} element${v.nodes.length === 1 ? "" : "s"}) ${v.helpUrl}`);
          for (const n of v.nodes.slice(0, 3)) console.log(`     ${n.target.join(" ")}`);
        }
        for (const v of violations.filter((v) => !blocking.has(v.impact))) {
          console.log(`warn ${label}: [${v.impact}] ${v.id} — ${v.help}`);
        }
        if (errors.length) {
          failed = true;
          for (const e of errors) console.log(`FAIL ${label}: console error: ${e}`);
        }
        report.push({ path, viewport: vpName, colorScheme, violations: violations.map((v) => ({ id: v.id, impact: v.impact, nodes: v.nodes.length })), consoleErrors: errors });
        if (!bad.length && !errors.length) console.log(`ok   ${label}`);
      } catch (e) {
        failed = true;
        console.log(`FAIL ${label}: ${e.message}`);
        report.push({ path, viewport: vpName, colorScheme, error: e.message });
      }
      await ctx.close();
    }
  }
}

await browser.close();
writeFileSync(join(out, "report.json"), JSON.stringify(report, null, 2));
process.exit(failed ? 1 : 0);
