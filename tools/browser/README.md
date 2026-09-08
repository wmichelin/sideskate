The browser smoke checks the exported release through ordinary browser keyboard
and touch events. It saves screenshots, within-run pixel comparisons, console and
network logs, and a completion report. Exact simulation assertions and replay
checks run in the native gameplay driver.

Install the pinned dependencies and matching Chromium once:

    npm ci --prefix tools/browser
    npm run --prefix tools/browser install-browser

After exporting the release and starting the local preview server:

    node tools/browser/smoke.mjs --url http://127.0.0.1:8060 --out /tmp/sideskate-browser --timeout 180000

The server must provide index.html and its JS/WASM/PCK resources from the release
export. The script only accepts loopback HTTP URLs. Chromium uses software
rendering, so this command does not require a hardware GPU or physical display.
Touch coverage uses Chromium emulation; this does not establish physical mobile
device or other browser engine compatibility.

Playwright 1.55.1 recognizes Ubuntu through 24.04. `install-browser` selects that
Chromium build on Ubuntu 26.04 x64, where this project's smoke checks verify it.
Other supported hosts use Playwright's normal platform selection. An explicit
`PLAYWRIGHT_HOST_PLATFORM_OVERRIDE` remains respected. CI can add `-- --with-deps`
to install Chromium's system libraries too.
