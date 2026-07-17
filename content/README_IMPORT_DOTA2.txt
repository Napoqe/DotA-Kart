DOTA 2 / SOURCE 2 IMPORT - FINISH LINE GATE

Este ZIP foi limpo para usar caminhos curtos no addon.
Nao foi criada pasta dota_kart e nao foi criada pasta props.

Extraia o conteudo deste ZIP diretamente em:

C:\Steam\steamapps\common\dota 2 beta\content\dota_addons\dota_kart\

Depois de extrair, os caminhos devem ficar assim:

content\dota_addons\dota_kart\models\finish_line_gate\fbx\finish_line_gate.fbx
content\dota_addons\dota_kart\models\finish_line_gate\fbx\temp.fbm\texture_0.png
content\dota_addons\dota_kart\materials\finish_line_gate\finish_line_gate_color.png
content\dota_addons\dota_kart\materials\finish_line_gate\finish_line_gate_normal.png
content\dota_addons\dota_kart\materials\finish_line_gate\finish_line_gate_roughness.png
content\dota_addons\dota_kart\materials\finish_line_gate\finish_line_gate_metallic.png
content\dota_addons\dota_kart\materials\finish_line_gate\finish_line_gate_metallic_roughness.png
content\dota_addons\dota_kart\materials\finish_line_gate\finish_line_gate_emissive.png
content\dota_addons\dota_kart\tools\import_settings.txt

IMPORT WIZARD - campos recomendados:

Source Asset Path:
C:\Steam\steamapps\common\dota 2 beta\content\dota_addons\dota_kart\models\finish_line_gate\fbx

Parent Directory:
models

Asset Directory:
finish_line_gate

Target Resource Name:
finish_line_gate

FBX Subdirectory:
fbx

Material Subdirectory:
finish_line_gate

Marque:
Generate VMDL(s)
Import FBX Files
Generate VMAT(s)
Import Textures

O modelo final deve ser salvo/gerado como:
models/finish_line_gate/finish_line_gate.vmdl

Caminho para usar no Hammer:
models/finish_line_gate/finish_line_gate.vmdl

Recomendacao para o arco de chegada/largada:
Use prop_dynamic se quiser controlar por script/Lua.
Use prop_static se for apenas decoracao parada.

Se o material aparecer como <None> ou o modelo ficar branco:
1. Abra o Material Editor.
2. Crie/edite um material em: materials/finish_line_gate/finish_line_gate.vmat
3. Use as texturas da pasta materials/finish_line_gate.
4. No ModelDoc, atribua esse VMAT ao mesh/material group.

Observacao:
O FBX do Meshy referencia uma textura interna chamada temp.fbm/texture_0.png.
Por isso este ZIP tambem inclui models/finish_line_gate/fbx/temp.fbm/texture_0.png para ajudar o importer.
