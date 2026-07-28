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
| Esc | Back to menu |

## Levels

ASCII `.ssk` files in `levels/`. Format: [docs/level_format.md](docs/level_format.md).

## Tests

```bash
godot4 --headless --path . --script res://tests/test_runner.gd
```
