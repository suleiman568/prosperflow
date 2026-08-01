/**
 * Rasterises the brand SVGs in assets/brand/ to the 1024px PNGs that
 * flutter_launcher_icons fans out from.
 *
 * The SVGs are the source of truth — they carry the spec's geometry directly
 * (0.64 x tile glyph, 0.25 x tile radius, the monogram's own path data) — but
 * flutter_launcher_icons only reads raster images, so they have to be baked.
 * There is no SVG rasteriser in this toolchain, so this drives the headless
 * Chromium that is already present for browser testing.
 *
 * Usage: node tool/render_brand_icons.js
 * Requires: playwright, and a Chromium at $CHROMIUM.
 */
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const CHROMIUM = process.env.CHROMIUM || '/opt/pw-browsers/chromium';
const ROOT = path.join(__dirname, '..');
const DIR = path.join(ROOT, 'assets', 'brand');

// [source, output, size, keep transparency]
// Only the iOS tile is flattened: it is square and must stay opaque, since
// the App Store rejects alpha. The others keep transparency so the 0.25 x tile
// corner radius is actually cut out rather than filled with the same ink.
const ICONS = [
  ['app_icon.svg', 'app_icon.png', 1024, true],
  ['app_icon_ios.svg', 'app_icon_ios.png', 1024, false],
  ['app_icon_foreground.svg', 'app_icon_foreground.png', 1024, true],
  ['splash_mark.svg', 'splash_mark.png', 512, true],
];

// The launch screens need the same mark at their own densities. Android is
// given the 4x bucket so every lower density scales down rather than up; iOS
// wants the three explicit scales its imageset declares.
const SPLASH_COPIES = [
  ['android/app/src/main/res/drawable-xxxhdpi/splash_mark.png', 512],
  ['ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png', 128],
  ['ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png', 256],
  ['ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png', 384],
];

(async () => {
  const browser = await chromium.launch({
    executablePath: CHROMIUM,
    args: ['--no-proxy-server', '--no-sandbox', '--disable-dev-shm-usage'],
  });

  async function render(src, dest, size, transparent) {
    const svg = fs.readFileSync(path.join(DIR, src), 'utf8');
    const page = await browser.newPage({
      viewport: { width: size, height: size },
      deviceScaleFactor: 1,
    });
    await page.setContent(
      `<!DOCTYPE html><html><head><style>
         html,body{margin:0;padding:0;width:${size}px;height:${size}px;
                   background:${transparent ? 'transparent' : '#17150F'}}
         svg{display:block;width:${size}px;height:${size}px}
       </style></head><body>${svg}</body></html>`,
      { waitUntil: 'load' },
    );
    await page.screenshot({
      path: dest,
      omitBackground: transparent,
      clip: { x: 0, y: 0, width: size, height: size },
    });
    await page.close();
  }

  for (const [src, out, size, transparent] of ICONS) {
    await render(src, path.join(DIR, out), size, transparent);
    console.log(`${src} -> assets/brand/${out}`);
  }

  for (const [rel, size] of SPLASH_COPIES) {
    const dest = path.join(ROOT, rel);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    await render('splash_mark.svg', dest, size, true);
    console.log(`splash_mark.svg -> ${rel} (${size}px)`);
  }

  await browser.close();
})();
