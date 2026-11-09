# DotA Kart

A Dota 2 Custom Game in the style of Mario Kart 64, made by **Napoqe** (Rafael). Status: **Beta**.

## Maps
- `radiant_track`
- `mines`
- `rome`
- `dust` (Ancient Egypt)

## Layout
| Folder | Goes to (inside `dota 2 beta`) |
|---|---|
| `content/` | `content/dota_addons/dota_kart/` |
| `game/` | `game/dota_addons/dota_kart/` |

- `game/scripts/vscripts/` — Lua (game mode, karts, items, bots, anti-skip, maps).
- `content/panorama/` — UI (HUD, input, music, Setup screen).
- `content/maps/` — Hammer maps (`.vmap`); `game/maps/` — compiled maps (`.vpk`).
- `content/models`, `content/materials`, `content/sounds`, `content/soundevents` — asset sources.
- `game/models`, `game/materials`, `game/sounds`, `game/soundevents`, `game/panorama` — compiled assets.

## How to install
1. Install **Dota 2 Workshop Tools** (Steam → Dota 2 → Properties → DLC).
2. Clone this repository with **GitHub Desktop** (or `git clone`). Install **Git LFS** and run `git lfs pull` if large files come down as pointers.
3. Copy `content/` into `...\dota 2 beta\content\dota_addons\dota_kart\` and `game/` into `...\dota 2 beta\game\dota_addons\dota_kart\`.
4. Launch Dota 2 with Workshop Tools, pick the `dota_kart` addon and run a map (for example, console: `dota_launch_custom_game dota_kart dust`).

## Controls
- **W / S** — accelerate / reverse
- **A / D** — steer; hold in a turn to drift
- **T** — use item forward; **S + T** uses it backward
- **Q** — self-cast Astral Imprisonment
- **R** — hold for rear view

## Contributing
DotA Kart is open source. Pull requests with improvements and new features are welcome.

## License
Summary (full text in [LICENSE](LICENSE)):

- You may use any content of this repository in other works, including new DotA Kart-style custom games, for non-profit purposes.
- If you use any content of this repository and monetize it, you need permission from the author, **Napoqe**. If he grants it, you must share a small part of the revenue with the original author of DotA Kart.
- This also applies to tournaments with real-money prizes.
- Valve assets belong to Valve. Napoqe's assets are free for non-profit use; commercial use requires royalties.

© 2026 Napoqe
