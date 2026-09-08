#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const env = { ...process.env };
if (process.platform === 'linux' && process.arch === 'x64' && !env.PLAYWRIGHT_HOST_PLATFORM_OVERRIDE) {
  const release = readFileSync('/etc/os-release', 'utf8');
  // This pinned Playwright predates Ubuntu 26.04. Its Ubuntu 24.04 Chromium
  // build is verified by this repository's desktop/touch checks on 26.04.
  if (/^ID=ubuntu$/m.test(release) && /^VERSION_ID="?26\.04"?$/m.test(release)) {
    env.PLAYWRIGHT_HOST_PLATFORM_OVERRIDE = 'ubuntu24.04-x64';
  }
}
const result = spawnSync(process.execPath, [fileURLToPath(new URL('./node_modules/playwright/cli.js', import.meta.url)), 'install', 'chromium', ...process.argv.slice(2)], { env, stdio: 'inherit' });
if (result.error) process.stderr.write(String(result.error) + '\n');
process.exitCode = result.status ?? 1;
