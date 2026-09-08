#!/usr/bin/env node
import { chromium } from 'playwright';
import { PNG } from 'pngjs';
import { mkdir, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { performance } from 'node:perf_hooks';

// This smoke test observes the exported canvas and sends normal browser input.
// Exact movement/owner/physics assertions belong to the native runtime suite.
function argumentsFrom(argv) {
  const args = { timeout: '180000' };
  const seen = new Set();
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i];
    if (!['--url', '--out', '--timeout'].includes(key) || !argv[i + 1] || argv[i + 1].startsWith('--')) {
      throw new Error('Usage: node smoke.mjs --url http://127.0.0.1:PORT --out DIR [--timeout 180000]');
    }
    if (seen.has(key)) throw new Error('Repeated argument: ' + key);
    seen.add(key);
    args[key.slice(2)] = argv[i + 1];
  }
  const url = new URL(args.url);
  if (!['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname) || url.protocol !== 'http:') {
    throw new Error('--url must be a loopback HTTP server');
  }
  if (!args.out || !/^\d+$/.test(args.timeout) || !Number.isSafeInteger(Number(args.timeout)) || Number(args.timeout) < 1000 || Number(args.timeout) > 600000) {
    throw new Error('--out and --timeout in [1000, 600000] milliseconds are required');
  }
  return { url: url.href, out: resolve(args.out), timeout: Number(args.timeout) };
}

const report = {
  schema_version: 1, completed: false, checks: [], errors: [], screenshots: [],
  limitations: [
    'Canvas observations establish release/browser integration; native checks establish exact physics, surface ownership and replay determinism.',
    'Touch input uses Chromium emulation; physical phones, gamepads and other browser engines are not covered.',
    'Pixel comparisons are within this run, with broad regions; they are not universal golden image hashes.',
  ],
};
const consoleLog = [];
const networkLog = [];
let browser;
let args;
const started = performance.now();
const sleep = ms => new Promise(resolvePromise => setTimeout(resolvePromise, ms));

function check(name, ok, details = {}) {
  const row = { name, ok: Boolean(ok), elapsed_ms: Math.round(performance.now() - started), ...details };
  report.checks.push(row);
  if (!ok) report.errors.push(name);
  process.stdout.write('BROWSER_CHECK ' + JSON.stringify(row) + '\n');
  return ok;
}

function pixelsIn(image, region, predicate) {
  let count = 0;
  let total = 0;
  const [left, top, right, bottom] = region;
  for (let y = Math.floor(top * image.height); y < Math.floor(bottom * image.height); y += 2) {
    for (let x = Math.floor(left * image.width); x < Math.floor(right * image.width); x += 2) {
      const at = (y * image.width + x) * 4;
      if (predicate(image.data[at], image.data[at + 1], image.data[at + 2])) count++;
      total++;
    }
  }
  return count / Math.max(total, 1);
}

function difference(a, b, region = [0, 0, 1, 1]) {
  if (a.width !== b.width || a.height !== b.height) throw new Error('Cannot compare frames of different dimensions');
  let changed = 0;
  let count = 0;
  const [left, top, right, bottom] = region;
  for (let y = Math.floor(top * a.height); y < Math.floor(bottom * a.height); y += 2) {
    for (let x = Math.floor(left * a.width); x < Math.floor(right * a.width); x += 2) {
      const at = (y * a.width + x) * 4;
      const distance = Math.abs(a.data[at] - b.data[at]) + Math.abs(a.data[at + 1] - b.data[at + 1]) + Math.abs(a.data[at + 2] - b.data[at + 2]);
      if (distance > 30) changed++;
      count++;
    }
  }
  return changed / Math.max(count, 1);
}

function menuRowCount(image) {
  // Sample inside the left edge of each level button, away from its text.
  const x = Math.floor(image.width * 0.35);
  let rows = 0;
  let height = 0;
  for (let y = Math.floor(image.height * 0.37); y < Math.floor(image.height * 0.82); y++) {
    const at = (y * image.width + x) * 4;
    const reference = y * image.width * 4;
    const distance = Math.abs(image.data[at] - image.data[reference]) + Math.abs(image.data[at + 1] - image.data[reference + 1]) + Math.abs(image.data[at + 2] - image.data[reference + 2]);
    if (distance > 30) {
      height++;
    } else {
      if (height > image.height * 0.03) rows++;
      height = 0;
    }
  }
  if (height > image.height * 0.03) rows++;
  return rows;
}

function menuTitle(image) {
  return pixelsIn(image, [0.30, 0.08, 0.70, 0.20], (r, g, b) => r > 180 && g > 180 && b > 170);
}

async function snapshot(page, name) {
  const captureStarted = performance.now();
  const box = await page.locator('#canvas').boundingBox();
  if (!box || box.width <= 0 || box.height <= 0) throw new Error('Missing game canvas bounds');
  // The canvas already fills the viewport. Capture its rendered pixels without
  // element scrolling/stability waits across extra costly SwiftShader frames.
  // Playwright preserves viewport/device emulation for desktop and touch.
  const buffer = await page.screenshot({ clip: box, timeout: 20000 });
  const image = PNG.sync.read(buffer);
  if (image.width !== Math.round(box.width) || image.height !== Math.round(box.height)) {
    throw new Error('Screenshot dimensions do not match the game canvas');
  }
  report.capture_count = (report.capture_count || 0) + 1;
  report.capture_elapsed_ms = (report.capture_elapsed_ms || 0) + Math.round(performance.now() - captureStarted);
  if (name) {
    const path = join(args.out, name + '.png');
    await writeFile(path, buffer);
    report.screenshots.push({ name, path, width: image.width, height: image.height });
  }
  return image;
}

async function menuReady(page, label) {
  const until = performance.now() + Math.min(args.timeout, 90000);
  while (performance.now() < until) {
    const frame = await snapshot(page);
    if (menuTitle(frame) > 0.025) {
      check(label, true, { title_light_fraction: menuTitle(frame) });
      return frame;
    }
    await sleep(250);
  }
  await snapshot(page, label.replaceAll(':', '-') + '-timeout');
  throw new Error(label + ': exported menu did not appear');
}

async function boot(context, label) {
  const page = await context.newPage();
  page.on('console', message => {
    consoleLog.push({ context: label, type: message.type(), text: message.text() });
    if (message.type() === 'error') report.errors.push(label + ' console: ' + message.text());
  });
  page.on('pageerror', error => report.errors.push(label + ' pageerror: ' + error.message));
  page.on('crash', () => report.errors.push(label + ': browser page crashed'));
  page.on('requestfailed', request => {
    networkLog.push({ context: label, url: request.url(), error: request.failure()?.errorText });
    report.errors.push(label + ' request failed: ' + request.url());
  });
  page.on('response', response => {
    networkLog.push({ context: label, url: response.url(), status: response.status() });
    if (response.status() >= 400) report.errors.push(label + ' HTTP ' + response.status() + ': ' + response.url());
  });
  await page.goto(args.url, { waitUntil: 'domcontentloaded', timeout: Math.min(args.timeout, 90000) });
  await page.locator('#canvas').waitFor({ state: 'visible', timeout: 30000 });
  await menuReady(page, label + ':release_menu');
  await snapshot(page, label + '-menu');
  return page;
}

async function press(page, key, delay = 250) {
  await page.keyboard.press(key);
  // Let Godot consume the event and render the resulting focus/menu state
  // before sending another command, even when a frame takes longer than delay.
  await page.evaluate(() => new Promise(resolveFrame => requestAnimationFrame(() => requestAnimationFrame(resolveFrame))));
  await sleep(delay);
}

async function pauseCycle(page, label) {
  await press(page, 'Escape', 300);
  const paused = await snapshot(page, label + '-paused');
  await sleep(500);
  const still = await snapshot(page);
  const stillDifference = difference(paused, still);
  check(label + ':pause_frame_stable', stillDifference < 0.001, { changed_fraction: stillDifference });
  // Resume is the initial focused button; Tab moves to Controls.
  await press(page, 'Tab', 100);
  await press(page, 'Enter', 300);
  const controls = await snapshot(page, label + '-controls');
  const controlsDifference = difference(paused, controls);
  check(label + ':controls_open', controlsDifference > 0.02, { changed_fraction: controlsDifference });
  await press(page, 'Escape', 250);
  const back = await snapshot(page, label + '-controls-back');
  const backDifference = difference(paused, back, [0.10, 0.02, 0.90, 0.30]);
  check(label + ':controls_back_to_pause', backDifference < 0.005, { changed_fraction: backDifference });
  await press(page, 'Escape', 200);
  const resumed = await snapshot(page, label + '-resumed');
  const resumedDifference = difference(paused, resumed);
  check(label + ':escape_resumes', resumedDifference > 0.02, { changed_fraction: resumedDifference });
  await press(page, 'Escape', 200);
  await press(page, 'Tab', 100);
  await press(page, 'Tab', 100);
  await press(page, 'Enter', 300);
  await menuReady(page, label + ':return_to_menu');
}

async function desktopSmoke() {
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
  const page = await boot(context, 'desktop');
  const originalMenu = await snapshot(page);
  check("desktop:release_lists_two_levels", menuRowCount(originalMenu) === 2, { visible_level_rows: menuRowCount(originalMenu) });
  const mapFrames = [];
  for (const [index, level] of ['layers', 'offset_demo'].entries()) {
    if (index === 1) {
      await press(page, 'ArrowDown');
      const focused = await snapshot(page, 'desktop-second-level-focus');
      const focusDifference = difference(originalMenu, focused, [0.31, 0.37, 0.69, 0.54]);
      check('desktop:keyboard_menu_navigation', focusDifference > 0.01, { changed_fraction: focusDifference });
    }
    await press(page, 'Enter', 1000);
    const spawn = await snapshot(page, level + '-spawn');
    mapFrames.push(spawn);
    const debugInk = pixelsIn(spawn, [12 / 1280, 684 / 720, 120 / 1280, 708 / 720], (r, g, b) => r > 190 && g > 190 && b > 190);
    check(level + ':release_fps_hud_absent', debugInk < 0.002, { bright_fraction_in_fps_label: debugInk });
    check(level + ':keyboard_starts_level', menuTitle(spawn) < 0.015 && difference(originalMenu, spawn) > 0.08, { title_light_fraction: menuTitle(spawn) });
    const region = [0.15, 0.20, 0.85, 0.85];
    await page.keyboard.down('d');
    await sleep(350);
    await page.keyboard.up('d');
    const moved = await snapshot(page, level + '-movement');
    const movedDifference = difference(spawn, moved, region);
    check(level + ':keyboard_movement_changes_world', movedDifference > 0.005, { changed_fraction: movedDifference });
    await page.keyboard.down('Space');
    await sleep(350);
    await page.keyboard.up('Space');
    await sleep(120);
    const ollie = await snapshot(page, level + '-ollie');
    check(level + ':ollie_input_rendered', difference(moved, ollie, region) > 0.003);
    await pauseCycle(page, level);
  }
  check('desktop:distinct_playable_maps', difference(mapFrames[0], mapFrames[1]) > 0.03);
  await page.setViewportSize({ width: 960, height: 640 });
  await sleep(400);
  const resized = await snapshot(page, 'desktop-resized-menu');
  check('desktop:canvas_resizes', resized.width === 960 && resized.height === 640, { width: resized.width, height: resized.height });
  await page.setViewportSize({ width: 1280, height: 720 });
  await sleep(300);
  await menuReady(page, 'desktop:menu_after_resize');
  await context.close();
}

async function touchPoint(page, x, y) {
  const box = await page.locator('#canvas').boundingBox();
  if (!box) throw new Error('Missing game canvas bounds');
  return { x: box.x + box.width * x / 1280, y: box.y + box.height * y / 720 };
}

async function touchSmoke() {
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1, hasTouch: true, isMobile: true,
    userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel Tablet) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
  });
  const page = await boot(context, 'touch');
  const button = await touchPoint(page, 640, 302);
  await page.touchscreen.tap(button.x, button.y);
  await sleep(1200);
  const spawn = await snapshot(page, 'touch-spawn');
  check('touch:tap_starts_level', menuTitle(spawn) < 0.015);
  // Top-left Pause label is absent from the desktop game and visible on touch.
  const pauseInk = pixelsIn(spawn, [0.035, 0.08, 0.115, 0.18], (r, g, b) => r > 185 && g > 185 && b > 175);
  check('touch:controls_visible', pauseInk > 0.006, { label_light_fraction: pauseInk });
  const cdp = await context.newCDPSession(page);
  const stick = await touchPoint(page, 198, 494);
  const outward = await touchPoint(page, 308, 494);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ ...stick, id: 0 }] });
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ ...outward, id: 0 }] });
  await sleep(400);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await sleep(100);
  const moved = await snapshot(page, 'touch-movement');
  const changed = difference(spawn, moved, [0.30, 0.15, 0.78, 0.83]);
  check('touch:joystick_changes_world', changed > 0.005, { changed_fraction: changed });
  const ollie = await touchPoint(page, 1128, 540);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ ...ollie, id: 0 }] });
  await sleep(350);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await sleep(120);
  const jumped = await snapshot(page, 'touch-ollie');
  check('touch:ollie_input_rendered', difference(moved, jumped, [0.30, 0.15, 0.78, 0.83]) > 0.003);
  const pause = await touchPoint(page, 96, 96);
  await page.touchscreen.tap(pause.x, pause.y);
  await sleep(300);
  const paused = await snapshot(page, 'touch-paused');
  check('touch:pause_button_changes_ui', difference(jumped, paused) > 0.03);
  await sleep(500);
  check('touch:pause_frame_stable', difference(paused, await snapshot(page)) < 0.001);
  const quit = await touchPoint(page, 640, 430);
  await page.touchscreen.tap(quit.x, quit.y);
  await sleep(300);
  await menuReady(page, 'touch:return_to_menu');
  await snapshot(page, 'touch-returned-menu');
  await context.close();
}

try {
  args = argumentsFrom(process.argv.slice(2));
  await mkdir(args.out, { recursive: true });
  await writeFile(join(args.out, 'report.json'), JSON.stringify(report, null, 2));
  report.url = args.url;
  browser = await chromium.launch({ headless: true, timeout: Math.min(args.timeout, 30000), args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--disable-vulkan'] });
  report.browser = browser.version();
  let timer;
  try {
    await Promise.race([
      (async () => { await desktopSmoke(); await touchSmoke(); })(),
      new Promise((_, reject) => {
        // Include browser startup in the workload budget. The Python supervisor
        // separately permits bounded cleanup and final diagnostic report writes.
        timer = setTimeout(() => reject(new Error('Browser smoke timed out after ' + args.timeout + ' ms')),
          Math.max(1, args.timeout - (performance.now() - started)));
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
} catch (error) {
  report.errors.push(String(error.stack || error));
} finally {
  if (browser) await browser.close().catch(error => report.errors.push(String(error)));
  report.completed = true;
  report.check_count = report.checks.length;
  report.failed = report.checks.filter(row => !row.ok).length;
  report.elapsed_ms = Math.round(performance.now() - started);
  if (args) {
    await writeFile(join(args.out, 'console.json'), JSON.stringify(consoleLog, null, 2));
    await writeFile(join(args.out, 'network.json'), JSON.stringify(networkLog, null, 2));
    await writeFile(join(args.out, 'report.json'), JSON.stringify(report, null, 2));
  }
  process.stdout.write('BROWSER_COMPLETE ' + JSON.stringify({ completed: report.completed, check_count: report.check_count, failed: report.failed, errors: report.errors, report: args ? join(args.out, 'report.json') : '' }) + '\n');
  process.exitCode = report.errors.length === 0 && report.check_count > 0 ? 0 : 1;
}
