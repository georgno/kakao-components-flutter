// Look-alike check: screenshots each web demo element in cases.json and the
// showcase fixture of the same id, at the same width, theme and contrast,
// and diffs them. Writes build/lookalike/report.html. See README.md.
//
//   node tool/lookalike/lookalike.mjs [--web ../kakao-components] [--themes light,dark]
//     [--contrast] [--only id,id] [--no-build]

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pixelmatch from 'pixelmatch';
import { chromium } from 'playwright';
import { PNG } from 'pngjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '../..');
const OUT = path.join(ROOT, 'build/lookalike');

const VIEWPORT = { width: 1280, height: 900 };
const SCALE = 2; // device pixels per CSS pixel
const SETTLE_MS = 1500; // glow fades, fills and pops finish well inside this
const FLUTTER_MARGIN = 48; // LookalikeApp.margin
const OPEN_MS = 600; // an opened panel's entry motion finishes well inside this

function parseArgs(argv) {
  const args = { web: path.resolve(ROOT, '../kakao-components'), themes: ['light', 'dark'], contrast: false, only: null, build: true };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--web') args.web = path.resolve(argv[++i]);
    else if (a === '--themes') args.themes = argv[++i].split(',');
    else if (a === '--contrast') args.contrast = true;
    else if (a === '--only') args.only = argv[++i].split(',');
    else if (a === '--no-build') args.build = false;
    else throw new Error(`Unknown argument ${a}`);
  }
  return args;
}

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css',
  '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml',
  '.woff2': 'font/woff2', '.woff': 'font/woff', '.ttf': 'font/ttf', '.otf': 'font/otf', '.jpg': 'image/jpeg',
  '.webp': 'image/webp', '.ico': 'image/x-icon' };

/** A static file server for [dir] on a free port; resolves to its base URL. */
function serve(dir) {
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, 'http://x');
    let file = path.join(dir, decodeURIComponent(url.pathname));
    if (!file.startsWith(dir)) return res.writeHead(403).end();
    if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
    if (!fs.existsSync(file)) return res.writeHead(404).end();
    res.writeHead(200, { 'content-type': TYPES[path.extname(file)] ?? 'application/octet-stream' });
    fs.createReadStream(file).pipe(res);
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve({ server, url: `http://127.0.0.1:${server.address().port}` })));
}

/** The most common colour on the outer ring of a screenshot, as RRGGBB. */
function borderColour(png) {
  const counts = new Map();
  const add = (x, y) => {
    const i = (y * png.width + x) * 4;
    const hex = [0, 1, 2].map((k) => png.data[i + k].toString(16).padStart(2, '0')).join('');
    counts.set(hex, (counts.get(hex) ?? 0) + 1);
  };
  for (let x = 0; x < png.width; x++) { add(x, 0); add(x, png.height - 1); }
  for (let y = 0; y < png.height; y++) { add(0, y); add(png.width - 1, y); }
  return [...counts].sort((a, b) => b[1] - a[1])[0][0];
}

/** [png] on a [w]×[h] canvas filled with [hex], top-left aligned. */
function pad(png, w, h, hex) {
  if (png.width === w && png.height === h) return png;
  const out = new PNG({ width: w, height: h });
  const [r, g, b] = [0, 2, 4].map((k) => parseInt(hex.slice(k, k + 2), 16));
  for (let i = 0; i < w * h; i++) out.data.set([r, g, b, 255], i * 4);
  PNG.bitblt(png, out, 0, 0, png.width, png.height, 0, 0);
  return out;
}

/**
 * [box] grown by [m] on every side, its origin moved back by [shift] (the
 * part of the web element's position below a whole CSS pixel, so both crops
 * start at the same distance from their element).
 */
function grow(box, m, shift = { x: 0, y: 0 }) {
  const x = box.x - m - shift.x;
  const y = box.y - m - shift.y;
  return { x: Math.max(0, x), y: Math.max(0, y), width: box.width + 2 * m, height: box.height + 2 * m };
}

/** How far [box] grown by [m] sits past a whole CSS pixel. */
function fraction(box, m) {
  return { x: box.x - m - Math.floor(box.x - m), y: box.y - m - Math.floor(box.y - m) };
}

async function shootWeb(browser, base, c, run) {
  const context = await browser.newContext({ viewport: VIEWPORT, deviceScaleFactor: SCALE, contrast: run.contrast });
  // theme-switch.js reads the saved choice before first paint.
  await context.addInitScript((theme) => localStorage.setItem('kakao-theme', theme), run.theme);
  const page = await context.newPage();
  await page.goto(`${base}/${c.page}`, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(SETTLE_MS);
  if (c.open) {
    // Open it, then move the pointer away so nothing shows hover.
    await page.locator(c.open).first().click();
    await page.mouse.move(0, 0);
    await page.waitForTimeout(OPEN_MS);
  }
  const el = page.locator(c.selector).nth(c.nth ?? 0);
  await el.scrollIntoViewIfNeeded();
  const box = await el.boundingBox();
  if (!box) throw new Error(`${c.id}: no element for ${c.selector}`);
  const m = c.margin ?? 8;
  const shift = fraction(box, m);
  const png = PNG.sync.read(await page.screenshot({ clip: grow(box, m, shift) }));
  await context.close();
  return { box, png, shift };
}

async function shootFlutter(browser, base, c, run, width, bg, shift) {
  const context = await browser.newContext({ viewport: VIEWPORT, deviceScaleFactor: SCALE, contrast: run.contrast });
  const page = await context.newPage();
  const q = new URLSearchParams({ lookalike: c.id, theme: run.theme, w: String(width), bg, settle: String(SETTLE_MS) });
  if (run.contrast === 'more') q.set('contrast', 'more');
  if (c.open) q.set('open', '1');
  await page.goto(`${base}/?${q}`);
  const box = await page.waitForFunction(() => window.lookalikeBox, null, { timeout: 60_000 }).then((h) => h.jsonValue());
  const png = PNG.sync.read(await page.screenshot({ clip: grow(box, Math.min(c.margin ?? 8, FLUTTER_MARGIN), shift) }));
  await context.close();
  return { box, png };
}

function esc(s) {
  return String(s).replace(/[&<>"]/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[ch]);
}

function report(results) {
  const rows = results.map((r) => `
    <section>
      <h2>${esc(r.name)} <span>${r.mismatch.toFixed(1)}% differs · web ${r.web.w}×${r.web.h} · flutter ${r.flutter.w}×${r.flutter.h}${
        r.dh ? ` · <b>height ${r.dh > 0 ? '+' : ''}${r.dh}</b>` : ''}${r.dw ? ` · <b>width ${r.dw > 0 ? '+' : ''}${r.dw}</b>` : ''}</span></h2>
      <div class="shots">
        <figure><img src="${r.file}.web.png"><figcaption>web</figcaption></figure>
        <figure><img src="${r.file}.flutter.png"><figcaption>flutter</figcaption></figure>
        <figure><img src="${r.file}.diff.png"><figcaption>diff</figcaption></figure>
      </div>
    </section>`).join('');
  return `<!doctype html><meta charset="utf-8"><title>Look-alike check</title>
<style>
  body { font: 14px/1.5 system-ui, sans-serif; margin: 24px; background: #f4f4f5; color: #18181b; }
  h1 { font-size: 20px; } h2 { font-size: 15px; margin: 32px 0 8px; } h2 span { font-weight: 400; color: #52525b; }
  .shots { display: flex; gap: 12px; flex-wrap: wrap; align-items: flex-start; }
  figure { margin: 0; } figcaption { color: #52525b; font-size: 12px; }
  img { display: block; max-width: 100%; width: calc(var(--w) * 1px); border: 1px solid #d4d4d8; }
</style>
<h1>Look-alike check · ${new Date().toISOString().slice(0, 16).replace('T', ' ')}</h1>
<p>Sorted by how much differs. Images are at ${SCALE}× and shown at CSS size; differing pixels are red in the diff.</p>
${rows}
<script>for (const i of document.images) i.onload = () => i.style.setProperty('--w', i.naturalWidth / ${SCALE});</script>`;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const { cases } = JSON.parse(fs.readFileSync(path.join(HERE, 'cases.json'), 'utf8'));
  const chosen = args.only ? cases.filter((c) => args.only.includes(c.id)) : cases;
  if (!fs.existsSync(path.join(args.web, 'shared/tokens.css'))) throw new Error(`No kakao-components checkout at ${args.web} (--web)`);

  const flutterWeb = path.join(ROOT, 'example/build/web');
  if (args.build) {
    console.log('Building the showcase for the web…');
    const r = spawnSync('flutter', ['build', 'web', '--release', '--no-web-resources-cdn'], { cwd: path.join(ROOT, 'example'), stdio: 'inherit' });
    if (r.status !== 0) process.exit(r.status ?? 1);
  }
  if (!fs.existsSync(path.join(flutterWeb, 'index.html'))) throw new Error('No showcase web build; run without --no-build');

  fs.rmSync(OUT, { recursive: true, force: true });
  fs.mkdirSync(OUT, { recursive: true });
  const web = await serve(args.web);
  const flutter = await serve(flutterWeb);
  // The full Chromium in new headless mode: only one browser to install.
  const browser = await chromium.launch({ channel: 'chromium' });
  const runs = args.themes.flatMap((theme) => [{ theme, contrast: 'no-preference' }, ...(args.contrast ? [{ theme, contrast: 'more' }] : [])]);
  const results = [];
  try {
    for (const c of chosen) {
      for (const run of runs) {
        const name = `${c.id} · ${run.theme}${run.contrast === 'more' ? ' · more contrast' : ''}`;
        const file = `${c.id}-${run.theme}${run.contrast === 'more' ? '-more' : ''}`;
        const w = await shootWeb(browser, web.url, c, run);
        const bg = borderColour(w.png);
        const f = await shootFlutter(browser, flutter.url, c, run, w.box.width, bg, w.shift);
        const width = Math.max(w.png.width, f.png.width);
        const height = Math.max(w.png.height, f.png.height);
        const a = pad(w.png, width, height, bg);
        const b = pad(f.png, width, height, bg);
        const diff = new PNG({ width, height });
        const n = pixelmatch(a.data, b.data, diff.data, width, height, { threshold: 0.1 });
        fs.writeFileSync(path.join(OUT, `${file}.web.png`), PNG.sync.write(w.png));
        fs.writeFileSync(path.join(OUT, `${file}.flutter.png`), PNG.sync.write(f.png));
        fs.writeFileSync(path.join(OUT, `${file}.diff.png`), PNG.sync.write(diff));
        const size = (box) => ({ w: Math.round(box.width), h: Math.round(box.height) });
        const r = { name, file, mismatch: (100 * n) / (width * height), web: size(w.box), flutter: size(f.box) };
        r.dw = r.flutter.w - r.web.w;
        r.dh = r.flutter.h - r.web.h;
        results.push(r);
        console.log(`${name.padEnd(44)} ${r.mismatch.toFixed(1).padStart(5)}%  web ${r.web.w}×${r.web.h}  flutter ${r.flutter.w}×${r.flutter.h}`);
      }
    }
  } finally {
    await browser.close();
    web.server.close();
    flutter.server.close();
  }
  results.sort((x, y) => y.mismatch - x.mismatch);
  fs.writeFileSync(path.join(OUT, 'report.html'), report(results));
  console.log(`\nReport: ${path.join(OUT, 'report.html')}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
