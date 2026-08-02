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

- [x] **Step 1: Add `build/` to `.gitignore`**
- [x] **Step 2: Create `export/html5_prod.cfg`**
- [x] **Step 3: Create `tools/deploy_prod.sh`**
- [x] **Step 4: Document Deploy in `README.md`**
- [x] **Step 5: Smoke-test export**
- [x] **Step 6: Install/login butler if needed and push**
- [x] **Step 7: Commit**
