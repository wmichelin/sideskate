# itch HTML5 Prod Deploy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One local command exports a clean Godot Web build and pushes it to `wmichelin/sideskater:html5` via butler.

**Architecture:** Tracked `export/html5_prod.cfg` is copied to gitignored `export_presets.cfg`; `tools/deploy_prod.sh` headless-exports then `butler push`es. README documents one-time host/itch setup.

**Tech Stack:** Godot 4.7 Web export, butler, bash.

## Global Constraints

- Target: `wmichelin/sideskater:html5`
- No `debug_tools` custom feature on prod export
- Godot binary must be 4.7.x
- `DRY_RUN=1` exports only (no butler)
- No CI / desktop channels

---

### Task 1: Export preset + gitignore + deploy script + README

**Files:**
- Create: `export/html5_prod.cfg`
- Create: `tools/deploy_prod.sh`
- Modify: `.gitignore`
- Modify: `README.md`
- Create: `docs/superpowers/plans/2026-08-01-itch-prod-deploy.md` (this file)

**Interfaces:**
- Consumes: Godot CLI `--export-release`, butler `push`
- Produces: `./tools/deploy_prod.sh` with env `GODOT`, `USERVERSION`, `DRY_RUN`

- [ ] **Step 1: Add `build/` to `.gitignore`**

Append:

```
build/
```

- [ ] **Step 2: Create `export/html5_prod.cfg`**

Single Web preset named `HTML5 Prod`, path `build/html5/index.html`, empty `custom_features`, `runnable=false`, thread support on (itch SharedArrayBuffer checkbox), COOP/COEP via PWA isolation headers option.

- [ ] **Step 3: Create `tools/deploy_prod.sh`**

Executable bash: resolve Godot 4.7, optionally require butler, copy preset, `--export-release "HTML5 Prod"`, push or DRY_RUN skip, print itch checklist.

- [ ] **Step 4: Document Deploy in `README.md`**

Prerequisites (Godot 4.7 web templates, butler login), command, itch HTML / playable-in-browser checklist, link to game page.

- [ ] **Step 5: Smoke-test export**

Run: `DRY_RUN=1 GODOT=/path/to/Godot ./tools/deploy_prod.sh`  
Expected: `build/html5/index.html` exists; script exits 0 without butler.

- [ ] **Step 6: Install/login butler if needed and push**

Run: `./tools/deploy_prod.sh`  
Expected: butler push succeeds to `wmichelin/sideskater:html5`.

- [ ] **Step 7: Commit**

```bash
git add export/html5_prod.cfg tools/deploy_prod.sh .gitignore README.md \
  docs/superpowers/specs/2026-08-01-itch-prod-deploy-design.md \
  docs/superpowers/plans/2026-08-01-itch-prod-deploy.md
git commit -m "$(cat <<'EOF'
Add local itch.io HTML5 prod deploy via butler.

EOF
)"
```
