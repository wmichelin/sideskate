# SideSkate

Godot 4.7 pseudo-3D skate prototype. Logical X/Z + height, projected to screen.

Gameplay authority is the analytical sim ([`docs/movement_contract.md`](docs/movement_contract.md)). Overview: [`docs/gameplay.md`](docs/gameplay.md).

## Run

Open the project in Godot 4.7+ and play. Starts at the level select menu.

## Controls

| Input | Action |
|-------|--------|
| WASD / arrows | Move (W = farther) |
| Space | Hold ollie — forward accel in facing dir |
| P / T | Spine (rising) / acid drop (falling) |
| Esc | Pause (Return to Main Menu from pause) |
| Y | Fall |

## Levels

ASCII `.ssk` files in `levels/` (playable). Debug/prototype maps live in
`debug_levels/` and only appear in the menu when debug tools are available.
Format: [docs/level_format.md](docs/level_format.md).

## Tests

```bash
godot4 --headless --path . --script res://tests/test_runner.gd
```

## Deploy (itch.io HTML5)

Prod page: [wmichelin.itch.io/sideskater](https://wmichelin.itch.io/sideskater)

Prerequisites:

1. Godot **4.7** with **Web** export templates installed
2. [butler](https://itch.io/docs/butler/installing.html) on `PATH` and `butler login`

```bash
./tools/deploy_prod.sh
```

Exports a clean release Web build (no debug tools) to `build/html5/`, then pushes
channel `html5` on `wmichelin/sideskater` (overrides that channel’s previous build).

- `DRY_RUN=1 ./tools/deploy_prod.sh` — export only
- `GODOT=/path/to/Godot` — override binary
- `USERVERSION=1.2.3` — override butler version label (default: git short SHA)

After the **first** push, on the itch Edit game page: set kind to **HTML**, mark the
`html5` upload playable in browser, then delete/hide any old manual upload.
Prod currently uses a **no-threads** Web build (SharedArrayBuffer not required).
