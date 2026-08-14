/**
 * Deploy-freshness check for the web build.
 *
 * Regression guard for: a shipped change (thousands separators while typing a
 * price) was invisible on the web build. The Dart code was correct; Flutter's
 * generated service worker is cache-first for main.dart.js, and the worker
 * controlling a page is the one registered on the *previous* visit. So the
 * first load after a deploy served the previous bundle and the change looked
 * like it had never landed.
 *
 * This drives the real app in Chromium: it serves an OLD build, visits it,
 * deploys a NEW build over the same URL, reloads ONCE, and asserts the buy
 * price field now groups digits. Reloading once is the whole point — the bug
 * only ever showed on the first load after a deploy.
 *
 * Usage:
 *   node tool/web_deploy_freshness_check.js --old <dir> --new <dir> [--port N]
 *
 * Requires: playwright, and a Chromium at $CHROMIUM (default
 * /opt/pw-browsers/chromium).
 */
const { chromium } = require('playwright');
const { execSync, spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const arg = (name, fallback) => {
  const i = process.argv.indexOf(`--${name}`);
  return i !== -1 ? process.argv[i + 1] : fallback;
};

const OLD = arg('old');
const NEW = arg('new');
const PORT = Number(arg('port', '8099'));
const SHOTS = arg('shots', null);
const CHROMIUM = process.env.CHROMIUM || '/opt/pw-browsers/chromium';

if (!OLD || !NEW) {
  console.error('usage: --old <dir> --new <dir> [--port N] [--shots <dir>]');
  process.exit(2);
}

const TYPED = '1339000';
const GROUPED = '1,339,000';

/** Logs in, opens Add Product, types into BUY PRICE, returns what it renders. */
async function typeBuyPrice(page, url, shot) {
  await page.goto(url, { waitUntil: 'load' });
  await page.waitForTimeout(6000);

  // Turn on the semantics tree so the fields become inspectable DOM nodes.
  const placeholder = await page.$('flt-semantics-placeholder');
  if (placeholder) {
    await placeholder.evaluate((el) => el.click());
    await page.waitForTimeout(1500);
  }

  await page.mouse.click(210, 459);
  await page.waitForTimeout(500);
  await page.keyboard.type('prosper@market.ng', { delay: 25 });
  await page.mouse.click(210, 517);
  await page.waitForTimeout(500);
  await page.keyboard.type('password123', { delay: 25 });
  await page.mouse.click(210, 600);
  await page.waitForTimeout(3000);

  await page.click('#flt-semantic-node-44'); // Products tab
  await page.waitForTimeout(2500);
  await page.click('#flt-semantic-node-59'); // Add product
  await page.waitForTimeout(2500);

  await page.click('#flt-semantic-node-70 input'); // BUY PRICE
  await page.waitForTimeout(600);
  await page.keyboard.type(TYPED, { delay: 120 });
  await page.waitForTimeout(900);

  if (shot) await page.screenshot({ path: shot });

  return page.evaluate(() => {
    const node = document.querySelector('#flt-semantic-node-70 input');
    return node ? node.value : 'FIELD MISSING';
  });
}

(async () => {
  const serveDir = fs.mkdtempSync(path.join(os.tmpdir(), 'pf-deploy-'));
  execSync(`cp -r ${OLD}/. ${serveDir}/`);

  const server = spawn('python3', ['-m', 'http.server', String(PORT), '--bind', '127.0.0.1'], {
    cwd: serveDir,
    stdio: 'ignore',
  });
  await new Promise((r) => setTimeout(r, 1500));

  const browser = await chromium.launch({
    executablePath: CHROMIUM,
    args: ['--no-proxy-server', '--no-sandbox', '--disable-dev-shm-usage'],
  });
  // Service workers deliberately left enabled: they are what is under test.
  const ctx = await browser.newContext({ viewport: { width: 420, height: 900 } });
  const page = await ctx.newPage();
  const url = `http://127.0.0.1:${PORT}/`;

  let failed = false;
  try {
    const before = await typeBuyPrice(page, url, SHOTS && `${SHOTS}/deploy-1-old.png`);
    console.log(`visit 1 (old build deployed):   "${before}"`);

    execSync(`cp -r ${NEW}/. ${serveDir}/`);
    console.log('deployed new build to the same URL');

    const after = await typeBuyPrice(page, url, SHOTS && `${SHOTS}/deploy-2-first-reload.png`);
    console.log(`visit 2 (FIRST reload after):   "${after}"`);

    if (after !== GROUPED) {
      console.error(
        `\nFAIL: the first load after a deploy still served the old bundle.\n` +
        `  expected "${GROUPED}", got "${after}"`,
      );
      failed = true;
    } else {
      console.log(`\nPASS: first load after deploy shows "${GROUPED}".`);
    }
  } finally {
    await browser.close();
    server.kill();
    fs.rmSync(serveDir, { recursive: true, force: true });
  }
  process.exit(failed ? 1 : 0);
})();
