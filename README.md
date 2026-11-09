# DotA Kart

Custom Game de Dota 2 no estilo Mario Kart 64, criado por **Napoqe** (Rafael). Estado: **Beta**.
*A Dota 2 Custom Game in the style of Mario Kart 64, made by Napoqe. Status: Beta.*

## Mapas / Maps
- `radiant_track`
- `mines`
- `rome`
- `dust` (Egito Antigo / Ancient Egypt)

## Estrutura / Layout
| Pasta / Folder | Vai para / Goes to (inside `dota 2 beta`) |
|---|---|
| `content/` | `content/dota_addons/dota_kart/` |
| `game/` | `game/dota_addons/dota_kart/` |

- `game/scripts/vscripts/` — Lua (modo de jogo, karts, itens, bots, anti-skip, mapas).
- `content/panorama/` — interface (HUD, inputs, música, tela de Setup).
- `content/maps/` — mapas do Hammer (`.vmap`); `game/maps/` — mapas compilados (`.vpk`).
- `content/models`, `content/materials`, `content/sounds`, `content/soundevents` — fontes dos assets.
- `game/models`, `game/materials`, `game/sounds`, `game/soundevents`, `game/panorama` — assets compilados.

## Como instalar / How to install
1. Instale o **Dota 2 Workshop Tools** (Steam → Dota 2 → Propriedades → DLC).
   *Install Dota 2 Workshop Tools (Steam → Dota 2 → Properties → DLC).*
2. Clone o repositório com o **GitHub Desktop** (ou `git clone`). Instale o **Git LFS** e rode `git lfs pull`
   se algum arquivo grande vier como ponteiro.
   *Clone with GitHub Desktop or git, install Git LFS and run `git lfs pull` if large files are pointers.*
3. Copie `content/` para `...\dota 2 beta\content\dota_addons\dota_kart\`
   e `game/` para `...\dota 2 beta\game\dota_addons\dota_kart\`.
   *Copy `content/` and `game/` into the folders above.*
4. Abra o Dota 2 com Workshop Tools, escolha o addon `dota_kart` e rode um mapa
   (ex.: console `dota_launch_custom_game dota_kart dust`).
   *Launch Dota 2 Workshop Tools, pick the `dota_kart` addon and run a map.*

## Controles / Controls
- **W / S** — acelerar / ré (*accelerate / reverse*)
- **A / D** — virar; segurar em curva faz drift (*steer; hold in a turn to drift*)
- **T** — usar item para frente; **S + T** usa para trás (*use item forward; S + T uses it backward*)
- **Q** — Astral Imprisonment em si mesmo (*self-cast Astral Imprisonment*)
- **R** — segurar para câmera traseira (*hold for rear view*)

## Licença / License
Resumo (texto completo em [LICENSE](LICENSE)):

- Pode usar qualquer conteúdo deste repositório para outros trabalhos, incluindo novos custom games do tipo DotA Kart.
- Se você usar qualquer conteúdo deste repositório e monetizar, precisará de autorização do autor **Napoqe**.
  Se ele autorizar, você terá que compartilhar uma pequena parte da monetização com o autor original do DotA Kart.
- Isso se aplica também a torneios com prêmio em dinheiro real.
- Ativos da Valve pertencem à Valve. Os ativos do Napoqe podem ser usados livremente para fins não lucrativos; uso comercial exige royalties.

*Summary: free to reuse for non-profit work (including new DotA Kart-style custom games). Monetizing anything from this
repository — including real-money prize tournaments — requires Napoqe's permission and a small revenue share (royalties).
Valve assets belong to Valve.*

© 2026 Napoqe
