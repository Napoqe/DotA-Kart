-- DotA Kart - addon_game_mode.lua
-- FIX51: countdown soundevents + local start countdown fixes.

require("dotakart/hud_server")
require("dotakart/auto_drive")
require("dotakart/camera_server")
require("dotakart/kart_controller")
require("dotakart/item_system")
require("dotakart/ai/public_ai")

-- Ligue para testar automaticamente o sistema de minimap/laps.
-- Depois que confirmar que funciona, troque para false.
DOTA_KART_AUTO_DRIVE_TEST = false

-- FIX8: por padrão usa GameEvents, não CustomNetTables.
-- Deixe false para eliminar o erro/spam "Unknown custom nettable".
DOTA_KART_USE_NETTABLES = false

-- Liga camera chase estilo Mario Kart 64.
DOTA_KART_MK64_CAMERA = true

-- FIX72: aumenta a faixa vertical da camera/render para pista estilo kart.
-- SetCameraZRange é aplicado no GameModeEntity; r_farz/Hammer Far Z Clip continuam sendo alternativas do engine/mapa.
DOTA_KART_CAMERA_Z_MIN = 0
DOTA_KART_CAMERA_Z_MAX = 12000

-- Liga controle manual W/S/A/D/T.
DOTA_KART_MANUAL_CONTROLS = true

-- Liga caixas de item estilo Mario Kart.
DOTA_KART_ITEM_BOXES = true

-- Maximo de jogadores do DotA Kart.
DOTA_KART_MAX_PLAYERS = 8

-- Free-for-all: cada jogador em um time custom separado.
DOTA_KART_FREE_FOR_ALL = true

-- Remove fog of war para corrida.
DOTA_KART_NO_FOG = true

-- FIX58/FIX59: IA publica para preencher slots vazios em partidas com humanos.
-- Fica separada em scripts/vscripts/dotakart/ai/public_ai.lua
DOTA_KART_PUBLIC_AI = true

-- FIX59: configuracao pelo host na tela de selecao de time/GameSetup.
-- true = usa a tela tipo Warcraft 3: host escolhe voltas e computadores antes de confirmar.
DOTA_KART_PUBLIC_SETUP_SCREEN = true

-- Padrao: preencher todos os slots vazios com IA.
-- DOTA_KART_PUBLIC_AI_BOT_COUNT = -1 significa "preencher vazios".
-- 0..7 significa quantidade fixa de computadores.
DOTA_KART_PUBLIC_AI_FILL_EMPTY_SLOTS = true
DOTA_KART_PUBLIC_AI_BOT_COUNT = -1
DOTA_KART_PUBLIC_AI_DEFAULT_LAPS = 3
DOTA_KART_PUBLIC_AI_SETUP_HOLD_SECONDS = 0.0
DOTA_KART_PUBLIC_AI_DEBUG = false
-- FIX67/FIX69: bots publicos nascem como herois reais integrados, iguais aos humanos.
-- O proxy visual do FIX66 foi removido; nunca usar prop_dynamic/SetModel para os bots publicos.
DOTA_KART_PUBLIC_AI_USE_REAL_HERO_BOTS = true
DOTA_KART_PUBLIC_AI_VISUAL_PROXY = false

-- FIX84: oito pilotos oficiais do DotA Kart, estilo seleção fechada de Mario Kart 64.
-- Humanos e IA pública devem usar somente estes heróis base.
DOTA_KART_KART_HERO_POOL = {
    -- FIX88: somente Invoker usa herói custom agora, porque ele já tem VMDL custom pronto.
    -- Os outros pilotos voltam para os heróis padrão até você criar os modelos 3D custom deles.
    "npc_dota_hero_dotakart_invoker",
    "npc_dota_hero_brewmaster",
    "npc_dota_hero_tinker",
    "npc_dota_hero_lina",
    "npc_dota_hero_pudge",
    "npc_dota_hero_tiny",
    "npc_dota_hero_mirana",
    "npc_dota_hero_juggernaut"
}

-- Mapeamento só para heróis que realmente possuem uma versão custom DotA Kart.
DOTA_KART_KART_BASE_HERO = {
    npc_dota_hero_dotakart_invoker = "npc_dota_hero_invoker"
}

-- Se o jogador escolher Invoker base por cache/bug da seleção, substitui pelo Invoker Kart custom.
-- Os outros heróis não são convertidos para custom enquanto não houver VMDL custom pronto.
DOTA_KART_BASE_TO_CUSTOM_HERO = {
    npc_dota_hero_invoker = "npc_dota_hero_dotakart_invoker"
}

DOTA_KART_KART_HERO_NAMES = {
    npc_dota_hero_dotakart_invoker = "Invoker",
    npc_dota_hero_invoker = "Invoker",
    npc_dota_hero_brewmaster = "Brewmaster",
    npc_dota_hero_tinker = "Tinker",
    npc_dota_hero_lina = "Lina",
    npc_dota_hero_pudge = "Pudge",
    npc_dota_hero_tiny = "Tiny",
    npc_dota_hero_mirana = "Mirana",
    npc_dota_hero_juggernaut = "Juggernaut"
}

-- Modelos custom de kart prontos. Por enquanto, só o Invoker usa VMDL custom.
DOTA_KART_CUSTOM_KART_MODELS = {
    npc_dota_hero_dotakart_invoker = "models/invoker/invoker_kart.vmdl",
    -- FIX104: IA usa Invoker base integrado ao Dota para não quebrar spawn/controle,
    -- mas recebe o mesmo modelo custom visual.
    npc_dota_hero_invoker = "models/invoker/invoker_kart.vmdl"
}

DOTA_KART_CUSTOM_KART_MODEL_SCALE = {
    npc_dota_hero_dotakart_invoker = 2.0,
    npc_dota_hero_invoker = 2.0
}

-- Exceções visuais somente para o modelo custom do Invoker.
-- Não muda a orientação dos heróis padrão.
DOTA_KART_CUSTOM_KART_FACING_YAW_OFFSET = {
    npc_dota_hero_dotakart_invoker = -90,
    npc_dota_hero_invoker = -90
}

DOTA_KART_CUSTOM_KART_GROUND_Z_OFFSET = {
    npc_dota_hero_dotakart_invoker = 72,
    npc_dota_hero_invoker = 72
}

-- Fallback apenas para o Invoker custom; os heróis padrão mantêm os wearables/modelos normais.
DOTA_KART_HIDE_DEFAULT_HERO_WEARABLES_FOR_CUSTOM_KARTS = true
DOTA_KART_REMOVE_DEFAULT_HERO_WEARABLES_FOR_CUSTOM_KARTS = false

-- A IA pública usa exatamente a mesma lista permitida para jogadores humanos.
DOTA_KART_AI_HERO_POOL = DOTA_KART_KART_HERO_POOL

-- Tabela de precache defensivo; só Invoker tem modelo custom por enquanto.
DOTA_KART_AI_HERO_MODELS = {
    npc_dota_hero_dotakart_invoker = "models/invoker/invoker_kart.vmdl",
    npc_dota_hero_brewmaster = "models/heroes/brewmaster/brewmaster.vmdl",
    npc_dota_hero_tinker = "models/heroes/tinker/tinker.vmdl",
    npc_dota_hero_lina = "models/heroes/lina/lina.vmdl",
    npc_dota_hero_pudge = "models/heroes/pudge/pudge.vmdl",
    npc_dota_hero_tiny = "models/heroes/tiny/tiny_01/tiny_01.vmdl",
    npc_dota_hero_mirana = "models/heroes/mirana/mirana.vmdl",
    npc_dota_hero_juggernaut = "models/heroes/juggernaut/juggernaut.vmdl"
}

if CAddonTemplateGameMode == nil then
    CAddonTemplateGameMode = class({})
end

function Precache(context)
    -- FIX100: Castle-Fight usa um arquivo canônico em soundevents/game_sounds_custom.vsndevts.
    -- Dota/Source2 carrega melhor soundevents custom quando o evento existe nesse arquivo
    -- e ele foi recompilado para game/.../soundevents/game_sounds_custom.vsndevts_c.
    PrecacheResource("soundfile", "soundevents/game_sounds_custom.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/soundevents_addon.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/dotakart_announcer.vsndevts", context)

    -- Caixa de item DotA Kart / Mario Kart style.
    PrecacheResource("model", "models/gameplay/breakingcrate_dest.vmdl", context)

    -- FIX24/FIX59: AutoBot/IA publica precisam estar precached para os modelos carregarem.
    PrecacheUnitByNameSync("npc_dota_hero_rattletrap", context)
    for _, heroName in ipairs(DOTA_KART_AI_HERO_POOL or {}) do
        PrecacheUnitByNameSync(heroName, context)
    end
    PrecacheResource("model", "models/heroes/rattletrap/rattletrap.vmdl", context)
    for _, modelPath in pairs(DOTA_KART_AI_HERO_MODELS or {}) do
        PrecacheResource("model", modelPath, context)
    end
    -- FIX54: Nitro icons are Panorama PNGs, not material resources.

    -- FIX22: itens reais + VFX.
    PrecacheResource("particle", "particles/items_fx/black_king_bar_overhead_sphere.vpcf", context)
    PrecacheResource("particle", "particles/items_fx/black_king_bar_avatar.vpcf", context)
    PrecacheResource("particle", "particles/items_fx/black_king_bar_overhead.vpcf", context)
    PrecacheResource("particle", "particles/items_fx/black_king_bar_overhead_shield.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_pudge/pudge_meathook_chain.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_pudge/pudge_meathook_chain_secondarychain.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_pudge/pudge_meathook_hook.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_rattletrap/rattletrap_hookshot.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_rattletrap/rattletrap_hookshot_c.vpcf", context)
    PrecacheResource("particle", "particles/econ/items/mirana/mirana_crescent_arrow/mirana_spell_crescent_arrow.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_vengeful/vengeful_magic_missle.vpcf", context)
    PrecacheResource("particle", "particles/econ/items/spirit_breaker/spirit_breaker_iron_surge/spirit_breaker_charge_target_mark_iron.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_spirit_breaker/spirit_breaker_greater_bash.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_venomancer/venomancer_venomous_gale.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_venomancer/venomancer_venomous_gale_impact.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_lich/lich_frost_armor.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_lich/lich_frost_armor_c.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_lich/lich_frost_armor_ice.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_lich/lich_frost_armor_ring.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_lich/lich_chain_frost.vpcf", context)
    PrecacheResource("particle", "particles/econ/items/lich/lich_ti8_immortal_arms/lich_ti8_chain_frost_explode.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_invoker/invoker_tornado.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_invoker/invoker_tornado_base.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_invoker/invoker_tornado_base_ring.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_invoker/invoker_tornado_base_swirl.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_invoker/invoker_tornado_funnel.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_invoker/invoker_tornado_funnel_detail.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_invoker/invoker_tornado_trail.vpcf", context)
    PrecacheResource("particle", "particles/econ/items/tuskarr/tusk_ti5_immortal/tusk_ice_shards_stout_crystal.vpcf", context)
    PrecacheResource("particle", "particles/econ/items/tuskarr/tusk_ti5_immortal/tusk_ice_shards_stout_base.vpcf", context)
    PrecacheResource("particle", "particles/econ/items/tuskarr/tusk_ti5_immortal/tusk_ice_shards_stout.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_tusk/tusk_ice_shards_projectile.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_tusk/tusk_ice_shards_projectile_flek.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_tusk/tusk_ice_shards_projectile_frost.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_tusk/tusk_ice_shards_projectile_model.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_rubick/rubick_spell_steal_flash.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_chaos_knight/chaos_knight_chaos_bolt.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_chaos_knight/chaos_knight_chaos_bolt_launch.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_chaos_knight/chaos_knight_chaos_bolt_explosion.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_bounty_hunter/bounty_hunter_windwalk_smoke.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_bounty_hunter/bounty_hunter_windwalk_smoke_top.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_invoker/invoker_ice_wall_shards.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_invoker/invoker_ice_wall_snow_ground.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_invoker/invoker_ice_wall_icicle.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_invoker/invoker_ice_wall_hero_shatter.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_sandking/sandking_burrowstrike_ground.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_sandking/sandking_burrowstrike_low.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_sandking/sandking_burrowstrike_mid.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_treant/treant_bramble_root_model.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_treant/treant_bramble_root.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_ogre_magi/ogre_magi_bloodlust_buff_symbol.vpcf", context)
    -- FIX92: Spectral Dagger particles from the real Spectre asset set.
    PrecacheResource("particle", "particles/units/heroes/hero_spectre/spectre_spectral_dagger.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_spectre/spectre_spectral_dagger_tracking.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_spectre/spectre_spectral_dagger_fallback_mid.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_spectre/spectre_spectral_dagger_glow.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_spectre/spectre_shadow_path.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_spectre/spectre_shadow_path_owner.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_spectre/spectre_shadow_path_owner_fallback_mid.vpcf", context)
    PrecacheResource("particle", "particles/econ/items/spectre/spectre_transversant/spectre_transversant_spectral_dagger_v2_path.vpcf", context)
    PrecacheResource("particle", "particles/econ/items/spectre/spectre_transversant/spectre_transversant_spectral_dagger_v2_path_front.vpcf", context)
    PrecacheResource("model", "models/heroes/rattletrap/rattletrap_cog.vmdl", context)

    -- Raw VSNDs pedidos + arquivos de eventos de som dos herois/itens.
    PrecacheResource("soundfile", "sounds/items/black_king_bar.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/ember_spirit/flame_guard_loop.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/rattletrap/jetpack_cast.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/pudge/hook_throw.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/rattletrap/hookshot_fire.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/rattletrap/hookshot_impact.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/rattletrap/hookshot_damage.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/rattletrap/hookshot_retract.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/mirana/leap1.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/mirana/leap2.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/mirana/leap3.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/mirana/leap4.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/mirana/arrow.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/vengeful_spirit/magic_missile1.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/vengeful_spirit/magic_missile_impact.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/vengeful_spirit/nether_swap.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/spirit_breaker/charge_cast.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/spirit_breaker/charge_impact.vsnd", context)
    PrecacheResource("soundfile", "sounds/ui/economy/rylais_wheel_spin_01_lp.vsnd", context)
    PrecacheResource("soundfile", "sounds/ui/economy/rylais_wheel_spin_02_lp.vsnd", context)
    PrecacheResource("soundfile", "sounds/ui/treasure_01.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/venomancer/venomancer_venomous_gale.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/venomancer/venomancer_venomous_gale_impact1.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/rattletrap/power_cogs.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/rattletrap/power_cogs_impact.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/lich/frost_armor.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/lich/frost_armor_damage.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/lich/chain_frost_cast.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/lich/chain_frost_loop.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/lich/chain_frost_impact.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/lich/chain_frost_impact_hero01.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/lich/chain_frost_impact_hero02.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/lich/chain_frost_impact_hero03.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/lich/chain_frost_impact_lf.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/lich/ice_age_target.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/invoker/tornado_cast.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/invoker/tornado.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/tusk/ice_shards_cast.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/tusk/ice_shards_projectile.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/tusk/ice_shards.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/rubick/spell_steal_cast.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/rubick/spell_steal_complete.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/rubick/spell_steal_target.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/chaos_knight/chaos_bolt_cast.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/chaos_knight/chaos_bolt_target.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/bounty_hunter/shadow_walk.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/invoker/ice_wall_slow02.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/crystal_maiden/freezing_field.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/sand_king/sand_king_burrow_attack.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/treant/overgrowth_target02.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/treant/natures_guise.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/ogre_magi/bloodlust_target.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/ogre_magi/multicast01.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/ogre_magi/multicast02.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/ogre_magi/multicast03.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/spectre/dagger_cast.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/spectre/dagger_impact.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/alchemist/unstable_concoction_fuse.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/alchemist/unstable_concoction_throw.vsnd", context)
    PrecacheResource("soundfile", "sounds/weapons/hero/alchemist/unstable_concoction_stun01.vsnd", context)
    PrecacheResource("particle", "particles/units/heroes/hero_alchemist/alchemist_unstable_concoction_projectile.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_alchemist/alchemist_unstable_concoction_projectile_explosion.vpcf", context)

    -- FIX44/FIX103: custom announcer/lap/engine soundevents.
    -- Não precachear raw .vsnd custom diretamente aqui; o raw fica referenciado dentro do KV3 .vsndevts.
    -- EmitSound/Game.EmitSound recebem o nome do soundevent, ex: dotakart_engine_idle.
    PrecacheResource("soundfile", "soundevents/dotakart_announcer.vsndevts", context)

    -- FIX50: countdown/start sounds.
    PrecacheResource("soundfile", "sounds/vo/announcer/ann_custom_countdown_01.vsnd", context)
    PrecacheResource("soundfile", "sounds/vo/announcer/ann_custom_countdown_02.vsnd", context)
    PrecacheResource("soundfile", "sounds/vo/announcer/ann_custom_countdown_03.vsnd", context)
    PrecacheResource("soundfile", "sounds/vo/announcer/ann_custom_countdown_04.vsnd", context)
    PrecacheResource("soundfile", "sounds/vo/announcer/ann_custom_countdown_05.vsnd", context)
    PrecacheResource("soundfile", "sounds/vo/announcer/ann_custom_countdown_06.vsnd", context)
    PrecacheResource("soundfile", "sounds/vo/announcer/ann_custom_countdown_07.vsnd", context)
    PrecacheResource("soundfile", "sounds/vo/announcer/ann_custom_countdown_08.vsnd", context)
    PrecacheResource("soundfile", "sounds/vo/announcer/ann_custom_countdown_09.vsnd", context)
    PrecacheResource("soundfile", "sounds/vo/announcer/ann_custom_countdown_10.vsnd", context)
    PrecacheResource("soundfile", "sounds/vo/announcer/announcer_battle_begin_01.vsnd", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_items.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_pudge.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ember_spirit.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_rattletrap.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_mirana.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_vengefulspirit.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_spirit_breaker.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_venomancer.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_lich.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_invoker.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_tusk.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_sandking.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_treant.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ogre_magi.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_rubick.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_chaos_knight.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_bounty_hunter.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_alchemist.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_spectre.vsndevts", context)
end

function Activate()
    GameRules.AddonTemplate = CAddonTemplateGameMode()
    GameRules.AddonTemplate:InitGameMode()
end

function CAddonTemplateGameMode:InitGameMode()
    print("[DotA Kart] Addon carregado.")

    self.raceStarted = false
    self.autoDriveStarted = false

    -- Acelera o fluxo para testes no Workshop Tools.
    GameRules:SetHeroSelectionTime(5)
    GameRules:SetStrategyTime(0)
    GameRules:SetShowcaseTime(0)
    GameRules:SetPreGameTime(3)
    GameRules:SetSameHeroSelectionEnabled(false)
    self:ConfigureDotaKartRules()
    -- FIX60: mantém a seleção padrão de equipes ativa. A UI DotA Kart é apenas um painel pequeno
    -- na tela GameSetup; o host configura e todos continuam escolhendo equipe/herói normalmente.
    if DOTA_KART_PUBLIC_SETUP_SCREEN == true then
        GameRules:EnableCustomGameSetupAutoLaunch(false)
        if GameRules.LockCustomGameSetupTeamAssignment ~= nil then
            pcall(function() GameRules:LockCustomGameSetupTeamAssignment(false) end)
        end
    else
        GameRules:EnableCustomGameSetupAutoLaunch(true)
        GameRules:SetCustomGameSetupAutoLaunchDelay(0)
    end

    GameRules.DotaKartHUD = DotaKartHUD
    DotaKartHUD:Init()

    GameRules.DotaKartAutoDrive = DotaKartAutoDrive
    DotaKartAutoDrive:Init(DotaKartHUD)

    GameRules.DotaKartCamera = DotaKartCamera
    DotaKartCamera:Init()
    DotaKartCamera:SetYawOffset(270)
    DotaKartCamera:SetDirectionMode("movement")

    GameRules.DotaKartController = DotaKartController
    DotaKartController:Init(DotaKartHUD)

    GameRules.DotaKartItemSystem = DotaKartItemSystem
    DotaKartItemSystem:Init(DotaKartHUD, DotaKartController)

    GameRules.DotaKartPublicAI = DotaKartPublicAI
    DotaKartPublicAI:Init(self, DotaKartHUD, DotaKartController, DotaKartItemSystem)
    CustomGameEventManager:RegisterListener("dotakart_host_settings", function(eventSourceIndex, keys)
        keys = keys or {}
        local providedPlayerID = tonumber(keys.PlayerID or keys.player_id or keys.playerID or -1) or -1
        local resolvedPlayerID = -1
        if DotaKartHUD ~= nil and DotaKartHUD.GetPlayerIDFromEvent ~= nil then
            local ok, pid = pcall(function() return DotaKartHUD:GetPlayerIDFromEvent(eventSourceIndex, {}) end)
            if ok and tonumber(pid) ~= nil then resolvedPlayerID = tonumber(pid) end
        end
        -- FIX60: prefere o PlayerID real do eventSourceIndex quando disponível. Se o GameSetup
        -- ainda não expôs esse dado, usa o PlayerID enviado pelo Panorama como fallback.
        if resolvedPlayerID >= 0 then
            keys.PlayerID = resolvedPlayerID
        elseif providedPlayerID >= 0 then
            keys.PlayerID = providedPlayerID
        else
            keys.PlayerID = -1
        end
        keys._resolvedPlayerID = resolvedPlayerID
        if GameRules.DotaKartPublicAI ~= nil then
            GameRules.DotaKartPublicAI:OnHostSettingsEvent(keys)
        end
    end)


    -- FIX61: GameSetup custom com seleção de equipes própria, porque o painel GameSetup do Dota
    -- pode esconder a seleção padrão quando existe CustomUIElement type="GameSetup".
    CustomGameEventManager:RegisterListener("dotakart_setup_join_team", function(eventSourceIndex, keys)
        self:OnDotaKartSetupJoinTeam(eventSourceIndex, keys or {})
    end)

    CustomGameEventManager:RegisterListener("dotakart_setup_confirm", function(eventSourceIndex, keys)
        self:OnDotaKartSetupConfirm(eventSourceIndex, keys or {})
    end)

    ListenToGameEvent("npc_spawned", Dynamic_Wrap(CAddonTemplateGameMode, "OnNPCSpawned"), self)
    ListenToGameEvent("player_connect_full", Dynamic_Wrap(CAddonTemplateGameMode, "OnPlayerConnectFull"), self)

    Convars:RegisterCommand("dk_race_start", function()
        self:StartDotaKartRace(true)
    end, "DotA Kart: inicia/reinicia corrida, HUD, minimap e laps", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_autodrive_start", function()
        self:StartAutoDriveTest(true)
    end, "DotA Kart: manda os heroes/karts andarem pelos dk_track", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_autodrive_stop", function()
        DotaKartAutoDrive:Stop()
        self.autoDriveStarted = false
    end, "DotA Kart: para o teste automatico", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_track_debug", function()
        DotaKartHUD:DebugPrintTrack()
    end, "DotA Kart: imprime informacoes dos pontos dk_track", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_items_start_from_gamemode", function()
        if GameRules.DotaKartItemSystem ~= nil then
            GameRules.DotaKartItemSystem:Start({ force_rebuild = true })
        end
    end, "DotA Kart: recria caixas de item pelo addon_game_mode", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_add_autobot", function()
        self:AddAutoBotKart()
    end, "DotA Kart: adiciona um bot/kart inimigo com AutoDrive para testar itens", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_remove_autobots", function()
        self:RemoveAutoBots()
    end, "DotA Kart: remove bots/karts de teste criados pelo DotA Kart", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_set_laps", function(_, a)
        if GameRules.DotaKartPublicAI ~= nil then
            GameRules.DotaKartPublicAI:SetConfiguredLaps(tonumber(a) or 3, "console")
        elseif DotaKartHUD ~= nil and DotaKartHUD.SetMaxLapsForRace ~= nil then
            DotaKartHUD:SetMaxLapsForRace(math.max(2, math.min(5, tonumber(a) or 3)))
        end
    end, "DotA Kart: define voltas publicas 2..5", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_set_bots", function(_, a)
        if GameRules.DotaKartPublicAI ~= nil then
            GameRules.DotaKartPublicAI:SetConfiguredBotCount(tonumber(a), "console")
        end
    end, "DotA Kart: define computadores. -1=preencher vazios, 0..7=fixo", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_public_ai_fill", function()
        if GameRules.DotaKartPublicAI ~= nil then
            GameRules.DotaKartPublicAI:PreparePublicBots()
            GameRules.DotaKartPublicAI:StartRaceBots()
        end
    end, "DotA Kart: cria bots publicos para slots vazios", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_public_ai_remove", function()
        if GameRules.DotaKartPublicAI ~= nil then
            GameRules.DotaKartPublicAI:RemoveBots()
        end
    end, "DotA Kart: remove bots publicos", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_ffa_assign", function()
        self:AssignExistingPlayersToFFA()
    end, "DotA Kart: força cada jogador para um time adversario separado", FCVAR_CHEAT)

    GameRules:GetGameModeEntity():SetThink("OnThink", self, "GlobalThink", 0.50)
end

function CAddonTemplateGameMode:GetRaceTeamForSlot(slot)
    slot = tonumber(slot) or 0
    if slot < 0 or slot > 7 then
        return nil
    end

    local customTeam = _G["DOTA_TEAM_CUSTOM_" .. tostring(slot + 1)]
    if customTeam ~= nil then
        return customTeam
    end

    -- Fallback seguro para builds onde os custom teams nao estao expostos.
    if slot == 0 then return DOTA_TEAM_GOODGUYS end
    if slot == 1 then return DOTA_TEAM_BADGUYS end
    return nil
end

function CAddonTemplateGameMode:ConfigureDotaKartRules()
    self.maxPlayers = DOTA_KART_MAX_PLAYERS or 8
    if self.maxPlayers > 8 then self.maxPlayers = 8 end
    if self.maxPlayers < 1 then self.maxPlayers = 1 end

    self.autoBots = self.autoBots or {}
    self.nextAutoBotID = 1

    -- DotA Kart FFA usa somente CUSTOM_1 até CUSTOM_8.
    -- FIX24: antes o loop de desligar times extras acabava desligando o CUSTOM_8 por causa do clamp.
    GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_GOODGUYS, 0)
    GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_BADGUYS, 0)

    for slot = 0, 7 do
        local team = self:GetRaceTeamForSlot(slot)
        if team ~= nil then
            local maxForTeam = (slot < self.maxPlayers) and 1 or 0
            GameRules:SetCustomGameTeamMaxPlayers(team, maxForTeam)
            print("[DotA Kart] Team slot " .. tostring(slot + 1) .. " team=" .. tostring(team) .. " max=" .. tostring(maxForTeam))
        end
    end

    if DOTA_KART_NO_FOG then
        local mode = GameRules:GetGameModeEntity()
        if mode ~= nil then
            mode:SetFogOfWarDisabled(true)
            mode:SetUnseenFogOfWarEnabled(false)
        end
    end

    -- FIX72: melhora alcance de visibilidade/render para a câmera alta MK64.
    -- SetCameraZRange é a opção VScript; r_farz e Far Z Clip do env_fog_controller continuam sendo alternativas do motor/mapa.
    local mode = GameRules:GetGameModeEntity()
    local minZ = tonumber(DOTA_KART_CAMERA_Z_MIN or 0) or 0
    local maxZ = tonumber(DOTA_KART_CAMERA_Z_MAX or 12000) or 12000
    if mode ~= nil and mode.SetCameraZRange ~= nil then
        local ok = pcall(function() mode:SetCameraZRange(minZ, maxZ) end)
        if ok then
            print("[DotA Kart] FIX72 CameraZRange aplicado min=" .. tostring(minZ) .. " max=" .. tostring(maxZ))
        else
            print("[DotA Kart] FIX72 CameraZRange falhou; ajuste r_farz/env_fog_controller no mapa se necessario.")
        end
    end

    -- FIX72: se existir env_fog_controller no mapa, tenta aumentar tambem o Far Z Clip dele.
    -- Isso ajuda quando o limite real vem do fog controller/Hammer, não apenas da camera.
    if Entities ~= nil and DoEntFireByInstanceHandle ~= nil then
        local fog = Entities:FindByClassname(nil, "env_fog_controller")
        local count = 0
        while fog ~= nil do
            count = count + 1
            pcall(function() DoEntFireByInstanceHandle(fog, "SetFarZ", tostring(math.floor(maxZ)), 0, nil, nil) end)
            fog = Entities:FindByClassname(fog, "env_fog_controller")
        end
        if count > 0 then print("[DotA Kart] FIX72 env_fog_controller SetFarZ=" .. tostring(math.floor(maxZ)) .. " count=" .. tostring(count)) end
    end

    print("[DotA Kart] Regras FIX26: max_players=" .. tostring(self.maxPlayers) .. ", FFA=" .. tostring(DOTA_KART_FREE_FOR_ALL) .. ", fog=off")
end

function CAddonTemplateGameMode:AssignPlayerToFFA(playerID)
    playerID = tonumber(playerID)
    if playerID == nil or playerID < 0 or playerID >= (self.maxPlayers or 8) then return end
    if not DOTA_KART_FREE_FOR_ALL then return end

    local team = self:GetRaceTeamForSlot(playerID)
    if PlayerResource ~= nil and PlayerResource.SetCustomTeamAssignment ~= nil then
        pcall(function() PlayerResource:SetCustomTeamAssignment(playerID, team) end)
    end

    local hero = nil
    if PlayerResource ~= nil and PlayerResource:IsValidPlayerID(playerID) then
        hero = PlayerResource:GetSelectedHeroEntity(playerID)
    end

    if hero ~= nil and not hero:IsNull() then
        pcall(function() hero:SetTeam(team) end)
    end

    print("[DotA Kart] Player " .. tostring(playerID) .. " atribuido ao time FFA " .. tostring(team))
end

function CAddonTemplateGameMode:AssignExistingPlayersToFFA()
    for playerID = 0, (self.maxPlayers or 8) - 1 do
        if PlayerResource:IsValidPlayerID(playerID) then
            self:AssignPlayerToFFA(playerID)
        end
    end
end


function CAddonTemplateGameMode:ResolveSetupPlayerID(eventSourceIndex, keys)
    keys = keys or {}
    local provided = tonumber(keys.PlayerID or keys.player_id or keys.playerID or -1) or -1
    local resolved = -1

    if DotaKartHUD ~= nil and DotaKartHUD.GetPlayerIDFromEvent ~= nil then
        local ok, pid = pcall(function() return DotaKartHUD:GetPlayerIDFromEvent(eventSourceIndex, {}) end)
        if ok and tonumber(pid) ~= nil then resolved = tonumber(pid) end
    end

    if resolved >= 0 then return resolved end
    if provided >= 0 then return provided end
    return -1
end

function CAddonTemplateGameMode:GetSetupNoTeam()
    if DOTA_TEAM_NOTEAM ~= nil then return DOTA_TEAM_NOTEAM end
    return 5
end

function CAddonTemplateGameMode:IsValidSetupTeam(team)
    team = tonumber(team)
    if team == nil then return false end
    for slot = 0, (self.maxPlayers or 8) - 1 do
        if team == self:GetRaceTeamForSlot(slot) then return true end
    end
    return false
end

function CAddonTemplateGameMode:GetPlayerSetupTeam(playerID)
    playerID = tonumber(playerID) or -1
    if playerID < 0 or PlayerResource == nil then return self:GetSetupNoTeam() end

    local team = nil
    if PlayerResource.GetCustomTeamAssignment ~= nil then
        local ok, value = pcall(function() return PlayerResource:GetCustomTeamAssignment(playerID) end)
        if ok and tonumber(value) ~= nil then team = tonumber(value) end
    end
    if team == nil and PlayerResource.GetTeam ~= nil then
        local ok, value = pcall(function() return PlayerResource:GetTeam(playerID) end)
        if ok and tonumber(value) ~= nil then team = tonumber(value) end
    end
    return team or self:GetSetupNoTeam()
end

function CAddonTemplateGameMode:IsSetupPlayerConnected(playerID)
    playerID = tonumber(playerID) or -1
    if playerID < 0 or PlayerResource == nil or PlayerResource.IsValidPlayerID == nil then return false end
    if not PlayerResource:IsValidPlayerID(playerID) then return false end

    local player = nil
    pcall(function() player = PlayerResource:GetPlayer(playerID) end)
    local steam = 0
    pcall(function() steam = PlayerResource:GetSteamAccountID(playerID) or 0 end)
    local conn = nil
    pcall(function() conn = PlayerResource:GetConnectionState(playerID) end)

    if conn == DOTA_CONNECTION_STATE_DISCONNECTED or conn == DOTA_CONNECTION_STATE_ABANDONED then
        return false
    end

    return player ~= nil or (tonumber(steam) or 0) > 0 or conn == DOTA_CONNECTION_STATE_CONNECTED or conn == DOTA_CONNECTION_STATE_LOADING
end

function CAddonTemplateGameMode:IsSetupTeamOccupied(team, exceptPlayerID)
    team = tonumber(team)
    exceptPlayerID = tonumber(exceptPlayerID) or -999
    if team == nil then return false end

    for playerID = 0, (self.maxPlayers or 8) - 1 do
        if playerID ~= exceptPlayerID and self:IsSetupPlayerConnected(playerID) then
            if self:GetPlayerSetupTeam(playerID) == team then
                return true, playerID
            end
        end
    end
    return false, -1
end

function CAddonTemplateGameMode:AppendSetupState(payload)
    payload = payload or {}
    payload.max_players = self.maxPlayers or DOTA_KART_MAX_PLAYERS or 8
    payload.host_player_id = 0

    for slot = 0, (self.maxPlayers or 8) - 1 do
        payload["team" .. tostring(slot)] = self:GetRaceTeamForSlot(slot) or -1
    end

    for playerID = 0, (self.maxPlayers or 8) - 1 do
        local prefix = "p" .. tostring(playerID)
        if self:IsSetupPlayerConnected(playerID) then
            payload[prefix .. "_connected"] = 1
            payload[prefix .. "_team"] = self:GetPlayerSetupTeam(playerID)
            local name = nil
            if PlayerResource ~= nil and PlayerResource.GetPlayerName ~= nil then
                pcall(function() name = PlayerResource:GetPlayerName(playerID) end)
            end
            if name == nil or name == "" then name = "Player " .. tostring(playerID + 1) end
            payload[prefix .. "_name"] = name
        else
            payload[prefix .. "_connected"] = 0
            payload[prefix .. "_team"] = self:GetSetupNoTeam()
            payload[prefix .. "_name"] = ""
        end
    end

    return payload
end

function CAddonTemplateGameMode:BroadcastSetupState()
    if GameRules ~= nil and GameRules.DotaKartPublicAI ~= nil then
        GameRules.DotaKartPublicAI:BroadcastHostSettings()
    end
end

function CAddonTemplateGameMode:AssignSetupPlayerToSlot(playerID, slot, source)
    playerID = tonumber(playerID) or -1
    slot = tonumber(slot) or -1
    if playerID < 0 or slot < 0 or slot >= (self.maxPlayers or 8) then return false end
    if self.raceStarted == true then return false end

    local team = self:GetRaceTeamForSlot(slot)
    if team == nil then return false end

    local occupied, occupiedBy = self:IsSetupTeamOccupied(team, playerID)
    if occupied then
        print("[DotA Kart] GameSetup: slot " .. tostring(slot + 1) .. " ocupado por player " .. tostring(occupiedBy))
        self:BroadcastSetupState()
        return false
    end

    if PlayerResource ~= nil and PlayerResource.SetCustomTeamAssignment ~= nil then
        pcall(function() PlayerResource:SetCustomTeamAssignment(playerID, team) end)
    end

    local hero = nil
    if PlayerResource ~= nil and PlayerResource:IsValidPlayerID(playerID) then
        pcall(function() hero = PlayerResource:GetSelectedHeroEntity(playerID) end)
    end
    if hero ~= nil and not hero:IsNull() then
        pcall(function() hero:SetTeam(team) end)
    end

    print("[DotA Kart] GameSetup: player " .. tostring(playerID) .. " entrou no slot " .. tostring(slot + 1) .. " team=" .. tostring(team) .. " source=" .. tostring(source or ""))
    self:BroadcastSetupState()
    return true
end

function CAddonTemplateGameMode:AssignSetupPlayerToFirstFree(playerID)
    for slot = 0, (self.maxPlayers or 8) - 1 do
        local team = self:GetRaceTeamForSlot(slot)
        local occupied = self:IsSetupTeamOccupied(team, playerID)
        if not occupied then
            return self:AssignSetupPlayerToSlot(playerID, slot, "first_free")
        end
    end
    self:BroadcastSetupState()
    return false
end

function CAddonTemplateGameMode:OnDotaKartSetupJoinTeam(eventSourceIndex, keys)
    keys = keys or {}
    if self.raceStarted == true then return end

    local playerID = self:ResolveSetupPlayerID(eventSourceIndex, keys)
    if playerID < 0 then
        print("[DotA Kart] GameSetup: nao consegui resolver PlayerID para troca de equipe.")
        self:BroadcastSetupState()
        return
    end

    if tonumber(keys.leave or 0) == 1 then
        local noTeam = self:GetSetupNoTeam()
        if PlayerResource ~= nil and PlayerResource.SetCustomTeamAssignment ~= nil then
            pcall(function() PlayerResource:SetCustomTeamAssignment(playerID, noTeam) end)
        end
        print("[DotA Kart] GameSetup: player " .. tostring(playerID) .. " saiu da equipe.")
        self:BroadcastSetupState()
        return
    end

    if tonumber(keys.random or 0) == 1 then
        self:AssignSetupPlayerToFirstFree(playerID)
        return
    end

    self:AssignSetupPlayerToSlot(playerID, tonumber(keys.team_slot or keys.slot or 0) or 0, "panorama")
end

function CAddonTemplateGameMode:EnsureConnectedPlayersHaveSetupTeams()
    for playerID = 0, (self.maxPlayers or 8) - 1 do
        if self:IsSetupPlayerConnected(playerID) then
            local team = self:GetPlayerSetupTeam(playerID)
            local valid = self:IsValidSetupTeam(team)
            local occupied = false
            if valid then
                occupied = self:IsSetupTeamOccupied(team, playerID)
            end
            if (not valid) or occupied then
                self:AssignSetupPlayerToFirstFree(playerID)
            end
        end
    end
end

function CAddonTemplateGameMode:OnDotaKartSetupConfirm(eventSourceIndex, keys)
    keys = keys or {}
    local playerID = self:ResolveSetupPlayerID(eventSourceIndex, keys)
    if playerID < 0 then playerID = 0 end

    if playerID ~= 0 then
        print("[DotA Kart] GameSetup: confirm ignorado de player nao-host " .. tostring(playerID))
        self:BroadcastSetupState()
        return
    end

    if GameRules.DotaKartPublicAI ~= nil then
        if keys.laps ~= nil then GameRules.DotaKartPublicAI:SetConfiguredLaps(tonumber(keys.laps) or 3, "setup_confirm") end
        if keys.bot_count ~= nil then GameRules.DotaKartPublicAI:SetConfiguredBotCount(tonumber(keys.bot_count), "setup_confirm") end
        GameRules.DotaKartPublicAI:LockHostSetup()
    end

    self:EnsureConnectedPlayersHaveSetupTeams()
    self:BroadcastSetupState()

    print("[DotA Kart] GameSetup: host confirmou. Avancando para selecao de heroi.")
    if GameRules.FinishCustomGameSetup ~= nil then
        local ok, err = pcall(function() GameRules:FinishCustomGameSetup() end)
        if not ok then print("[DotA Kart] FinishCustomGameSetup falhou: " .. tostring(err)) end
    elseif GameRules.SetCustomGameSetupTimeout ~= nil then
        pcall(function() GameRules:SetCustomGameSetupTimeout(0) end)
    elseif GameRules.SetCustomGameSetupAutoLaunchDelay ~= nil then
        pcall(function() GameRules:SetCustomGameSetupAutoLaunchDelay(0) end)
        pcall(function() GameRules:EnableCustomGameSetupAutoLaunch(true) end)
    end
end

function CAddonTemplateGameMode:OnPlayerConnectFull(keys)
    local playerID = tonumber(keys.PlayerID or keys.player_id or keys.userid or -1) or -1
    if playerID >= 0 then
        self:AssignPlayerToFFA(playerID)
    end
    if GameRules.DotaKartPublicAI ~= nil then
        GameRules.DotaKartPublicAI:BroadcastHostSettings()
    end
end

function CAddonTemplateGameMode:GetNextAutoBotID()
    self.autoBots = self.autoBots or {}
    for id = 1, (self.maxPlayers or 8) - 1 do
        local occupiedByReal = PlayerResource ~= nil and PlayerResource:IsValidPlayerID(id)
        local occupiedByBot = self.autoBots[id] ~= nil and not self.autoBots[id]:IsNull()
        if not occupiedByReal and not occupiedByBot then
            return id
        end
    end
    return nil
end

function CAddonTemplateGameMode:AddAutoBotKart(heroName)
    heroName = heroName or "npc_dota_hero_rattletrap"
    self.autoBots = self.autoBots or {}

    local botID = self:GetNextAutoBotID()
    if botID == nil then
        print("[DotA Kart] Nao ha slot livre para AutoBot. Maximo: " .. tostring(self.maxPlayers or 8))
        return nil
    end

    if DotaKartHUD.trackWorldPoints == nil or #DotaKartHUD.trackWorldPoints < 2 then
        DotaKartHUD:BuildTrackPathFromEntities("dk_track_", 1024, true, 512)
    end

    local spawn = Vector(0, 0, 0)
    local startEnt = Entities:FindByName(nil, "player" .. tostring(botID + 1) .. "_start_position")
    if startEnt == nil then startEnt = Entities:FindByName(nil, "player_" .. tostring(botID + 1) .. "_start_position") end

    if startEnt ~= nil then
        local p = startEnt:GetAbsOrigin()
        spawn = Vector(p.x, p.y, GetGroundHeight(p, nil))
    elseif DotaKartHUD.trackWorldPoints ~= nil and #DotaKartHUD.trackWorldPoints >= 1 then
        local p = DotaKartHUD.trackWorldPoints[1]
        spawn = Vector(p.x + botID * 120, p.y + botID * 72, GetGroundHeight(p, nil))
    end

    local team = self:GetRaceTeamForSlot(botID)
    if team == nil then
        print("[DotA Kart] ERRO: slot de time FFA invalido para AutoBot " .. tostring(botID))
        return nil
    end

    -- FIX24: garante que o modelo do bot esteja carregado antes de criar a unidade.
    pcall(function() PrecacheUnitByNameAsync(heroName, function() end) end)

    local bot = CreateUnitByName(heroName, spawn, true, nil, nil, team)
    if bot == nil or bot:IsNull() then
        print("[DotA Kart] ERRO: nao consegui criar AutoBot " .. tostring(heroName))
        return nil
    end

    -- Clockwerk/rattletrap criado por script às vezes nasce sem visual se não tiver player owner.
    -- Forçamos o modelo padrão para o AutoBot de teste.
    if heroName == "npc_dota_hero_rattletrap" then
        pcall(function() bot:SetModel("models/heroes/rattletrap/rattletrap.vmdl") end)
        pcall(function() bot:SetOriginalModel("models/heroes/rattletrap/rattletrap.vmdl") end)
    end

    bot:SetControllableByPlayer(-1, false)
    bot:SetBaseMoveSpeed(650)
    bot:SetHullRadius(55)

    -- FIX24: bot de teste não deve adquirir/atacar jogador. Ele é alvo inimigo, mas só pilota.
    pcall(function() bot:SetIdleAcquire(false) end)
    pcall(function() bot:SetAcquisitionRange(0) end)
    if DOTA_UNIT_CAP_NO_ATTACK ~= nil then
        pcall(function() bot:SetAttackCapability(DOTA_UNIT_CAP_NO_ATTACK) end)
    end
    if DOTA_UNIT_TARGET_FLAG_INVULNERABLE ~= nil then end

    FindClearSpaceForUnit(bot, spawn, true)

    self.autoBots[botID] = bot

    if GameRules.DotaKartHUD ~= nil then
        GameRules.DotaKartHUD:RegisterKart(botID, bot)
    end

    if GameRules.DotaKartController ~= nil then
        GameRules.DotaKartController:RegisterHero(botID, bot)
    end

    if GameRules.DotaKartItemSystem ~= nil then
        GameRules.DotaKartItemSystem:SetEnabled(true)
    end

    if GameRules.DotaKartAutoDrive ~= nil then
        GameRules.DotaKartAutoDrive:LoadTrackPoints({ prefix = "dk_track_", max_points = 1024 })
        GameRules.DotaKartAutoDrive:AddDriver(botID, bot, {
            teleport_to_start = true,
            move_speed = 650,
            direct_drive = true,
            no_attack = true
        })
        GameRules.DotaKartAutoDrive.running = true
        GameRules.DotaKartAutoDrive:StartThink()
    end

    print("[DotA Kart] AutoBot criado: player " .. tostring(botID) .. " = " .. tostring(heroName) .. " team=" .. tostring(team))
    return bot
end

function CAddonTemplateGameMode:RemoveAutoBots()
    for botID, bot in pairs(self.autoBots or {}) do
        if bot ~= nil and not bot:IsNull() then
            UTIL_Remove(bot)
        end
        if DotaKartHUD ~= nil and DotaKartHUD.racers ~= nil then
            DotaKartHUD.racers[botID] = nil
        end
        if DotaKartController ~= nil then
            if DotaKartController.heroes ~= nil then DotaKartController.heroes[botID] = nil end
            if DotaKartController.states ~= nil then DotaKartController.states[botID] = nil end
            if DotaKartController.heldItems ~= nil then DotaKartController.heldItems[botID] = nil end
        end
        if DotaKartAutoDrive ~= nil and DotaKartAutoDrive.drivers ~= nil then
            DotaKartAutoDrive.drivers[botID] = nil
        end
    end
    self.autoBots = {}
    print("[DotA Kart] AutoBots removidos.")
end




function CAddonTemplateGameMode:GetBaseHeroNameForKartHero(heroName)
    heroName = tostring(heroName or "")
    if DOTA_KART_KART_BASE_HERO ~= nil and DOTA_KART_KART_BASE_HERO[heroName] ~= nil then
        return DOTA_KART_KART_BASE_HERO[heroName]
    end
    return heroName
end

function CAddonTemplateGameMode:GetCustomKartHeroForBaseHero(heroName)
    heroName = tostring(heroName or "")
    if DOTA_KART_BASE_TO_CUSTOM_HERO ~= nil and DOTA_KART_BASE_TO_CUSTOM_HERO[heroName] ~= nil then
        return DOTA_KART_BASE_TO_CUSTOM_HERO[heroName]
    end
    return heroName
end

function CAddonTemplateGameMode:GetCustomKartModelScale(heroName)
    heroName = tostring(heroName or "")
    local baseHero = self:GetBaseHeroNameForKartHero(heroName)
    local scale = 1.0
    if DOTA_KART_CUSTOM_KART_MODEL_SCALE ~= nil then
        scale = tonumber(DOTA_KART_CUSTOM_KART_MODEL_SCALE[heroName] or DOTA_KART_CUSTOM_KART_MODEL_SCALE[baseHero] or 1.0) or 1.0
    end
    if scale <= 0 then scale = 1.0 end
    return scale
end

function CAddonTemplateGameMode:IsCustomKartWearableChild(child, heroName)
    if child == nil or child:IsNull() then return false end
    local className = ""
    pcall(function() className = tostring(child:GetClassname() or "") end)
    className = string.lower(className or "")

    if string.find(className, "wearable", 1, true) ~= nil then return true end
    if string.find(className, "dota_item", 1, true) ~= nil then return true end

    -- Fallback defensivo para os cosméticos do Invoker que podem vir como props/children.
    if heroName == "npc_dota_hero_invoker" or heroName == "npc_dota_hero_dotakart_invoker" then
        local modelName = ""
        pcall(function()
            if child.GetModelName ~= nil then modelName = tostring(child:GetModelName() or "") end
        end)
        modelName = string.lower(modelName or "")
        if string.find(modelName, "models/heroes/invoker", 1, true) ~= nil then return true end
        if string.find(modelName, "models/items/invoker", 1, true) ~= nil then return true end
    end

    return false
end

function CAddonTemplateGameMode:HideDefaultHeroWearablesForCustomKart(unit, heroName)
    if DOTA_KART_HIDE_DEFAULT_HERO_WEARABLES_FOR_CUSTOM_KARTS ~= true then return 0 end
    if unit == nil or unit:IsNull() then return 0 end
    heroName = tostring(heroName or unit:GetUnitName() or "")
    -- FIX88: só esconde wearables quando este herói possui modelo custom configurado.
    -- Heróis padrão (Brewmaster, Tinker, Lina, Pudge, Tiny, Mirana, Juggernaut) não devem ser tocados.
    local baseHeroForWearableCheck = self.GetBaseHeroNameForKartHero and self:GetBaseHeroNameForKartHero(heroName) or heroName
    local hasCustomModel = DOTA_KART_CUSTOM_KART_MODELS ~= nil and (DOTA_KART_CUSTOM_KART_MODELS[heroName] ~= nil or DOTA_KART_CUSTOM_KART_MODELS[baseHeroForWearableCheck] ~= nil)
    if hasCustomModel ~= true then return 0 end
    local removed = 0

    local function hideChild(child)
        if child == nil or child:IsNull() then return end
        if not self:IsCustomKartWearableChild(child, heroName) then return end
        pcall(function() child:AddNoDraw() end)
        pcall(function() if EF_NODRAW ~= nil then child:AddEffects(EF_NODRAW) end end)
        pcall(function() child:SetAbsOrigin(Vector(0, 0, -32000)) end)
        if DOTA_KART_REMOVE_DEFAULT_HERO_WEARABLES_FOR_CUSTOM_KARTS == true then
            pcall(function() UTIL_Remove(child) end)
        end
        removed = removed + 1
    end

    -- Método 1: filhos diretos, quando disponível.
    local okChildren, children = pcall(function()
        if unit.GetChildren ~= nil then return unit:GetChildren() end
        return nil
    end)
    if okChildren and type(children) == "table" then
        for _, child in pairs(children) do hideChild(child) end
    end

    -- Método 2: árvore de move children, mais compatível com wearables do Dota.
    local okFirst, child = pcall(function()
        if unit.FirstMoveChild ~= nil then return unit:FirstMoveChild() end
        return nil
    end)
    local guard = 0
    if okFirst then
        while child ~= nil and guard < 128 do
            local nextChild = nil
            pcall(function()
                if child.NextMovePeer ~= nil then nextChild = child:NextMovePeer() end
            end)
            hideChild(child)
            child = nextChild
            guard = guard + 1
        end
    end

    return removed
end

function CAddonTemplateGameMode:ReapplyCustomKartHeroModel(unit, heroName, modelPath, scale)
    if unit == nil or unit:IsNull() then return nil end
    pcall(function() unit:SetModel(modelPath) end)
    pcall(function() unit:SetOriginalModel(modelPath) end)
    pcall(function() unit:SetModelScale(scale) end)
    pcall(function() unit:RemoveNoDraw() end)
    self:HideDefaultHeroWearablesForCustomKart(unit, heroName)
    return nil
end

function CAddonTemplateGameMode:GetAllowedKartHeroSet()
    if self._dotakartAllowedHeroSet ~= nil then return self._dotakartAllowedHeroSet end
    local set = {}
    for _, heroName in ipairs(DOTA_KART_KART_HERO_POOL or {}) do
        if heroName ~= nil and heroName ~= "" then set[heroName] = true end
    end
    -- FIX104: permite aliases/base heroes usados internamente para manter fake clients/bots
    -- estáveis. Eles continuam contando como o mesmo piloto no GameSetup/AI.
    for customHero, baseHero in pairs(DOTA_KART_KART_BASE_HERO or {}) do
        if customHero ~= nil and customHero ~= "" then set[customHero] = true end
        if baseHero ~= nil and baseHero ~= "" then set[baseHero] = true end
    end
    for baseHero, customHero in pairs(DOTA_KART_BASE_TO_CUSTOM_HERO or {}) do
        if baseHero ~= nil and baseHero ~= "" then set[baseHero] = true end
        if customHero ~= nil and customHero ~= "" then set[customHero] = true end
    end
    self._dotakartAllowedHeroSet = set
    return set
end

function CAddonTemplateGameMode:IsAllowedKartHeroName(heroName)
    heroName = tostring(heroName or "")
    local set = self:GetAllowedKartHeroSet()
    return set[heroName] == true
end

function CAddonTemplateGameMode:GetDefaultKartHeroForPlayer(playerID)
    local pool = DOTA_KART_KART_HERO_POOL or {}
    if #pool <= 0 then return "npc_dota_hero_invoker" end
    local index = ((tonumber(playerID) or 0) % #pool) + 1
    return pool[index] or "npc_dota_hero_invoker"
end

function CAddonTemplateGameMode:ApplyCustomKartHeroModel(unit)
    if unit == nil or unit:IsNull() then return false end
    local heroName = unit:GetUnitName()
    local baseHero = self:GetBaseHeroNameForKartHero(heroName)
    pcall(function() unit.dk_kart_hero_name = baseHero end)
    pcall(function() unit.dotakart_display_hero = baseHero end)
    pcall(function() unit.dotakart_public_ai_hero = baseHero end)

    local modelPath = nil
    if DOTA_KART_CUSTOM_KART_MODELS ~= nil then modelPath = DOTA_KART_CUSTOM_KART_MODELS[heroName] or DOTA_KART_CUSTOM_KART_MODELS[baseHero] end
    if modelPath == nil or modelPath == "" then return false end

    -- FIX85: aplica o modelo custom no próprio herói real, escala visual e esconde
    -- wearables/modelos padrão que o Dota adiciona por cima do custom VMDL.
    local scale = self:GetCustomKartModelScale(heroName)
    local ok1 = pcall(function() unit:SetModel(modelPath) end)
    local ok2 = pcall(function() unit:SetOriginalModel(modelPath) end)
    local ok3 = pcall(function() unit:SetModelScale(scale) end)
    pcall(function() unit:RemoveNoDraw() end)
    pcall(function() unit.dk_kart_custom_model = modelPath end)
    pcall(function() unit.dk_kart_custom_model_scale = scale end)
    if DOTA_KART_CUSTOM_KART_GROUND_Z_OFFSET ~= nil then
        local zoff = tonumber(DOTA_KART_CUSTOM_KART_GROUND_Z_OFFSET[heroName] or DOTA_KART_CUSTOM_KART_GROUND_Z_OFFSET[baseHero] or 0) or 0
        pcall(function() unit.dk_kart_custom_z_offset = zoff end)
    end

    local hidden = self:HideDefaultHeroWearablesForCustomKart(unit, heroName)

    -- Os cosméticos/wearables podem aparecer alguns frames depois do spawn/hero selection.
    -- Reaplica a limpeza em pequenas janelas sem tocar em HUD, itens, IA ou controle.
    local ent = -1
    pcall(function() ent = unit:entindex() end)
    local mode = GameRules:GetGameModeEntity()
    if mode ~= nil and ent ~= nil and ent >= 0 then
        local delays = { 0.03, 0.20, 0.60, 1.20, 2.00 }
        for i, delay in ipairs(delays) do
            mode:SetContextThink("DotaKartCustomKartModel_FIX85_" .. tostring(ent) .. "_" .. tostring(i), function()
                return self:ReapplyCustomKartHeroModel(unit, heroName, modelPath, scale)
            end, delay)
        end
    end

    print("[DotA Kart] FIX85 custom kart model aplicado: " .. tostring(heroName) .. " -> " .. tostring(modelPath) .. " scale=" .. tostring(scale) .. " hidden_children=" .. tostring(hidden))
    return ok1 or ok2 or ok3
end

function CAddonTemplateGameMode:ReplaceInvalidKartHero(playerID, oldHero)
    playerID = tonumber(playerID) or -1
    if playerID < 0 then return false end
    local oldHeroName = oldHero and oldHero:GetUnitName() or ""
    local replacement = self:GetCustomKartHeroForBaseHero(oldHeroName)
    if replacement == nil or replacement == oldHeroName or not self:IsAllowedKartHeroName(replacement) then
        replacement = self:GetDefaultKartHeroForPlayer(playerID)
    end
    print("[DotA Kart] Hero invalido/base detectado. player=" .. tostring(playerID) .. " hero=" .. tostring(oldHeroName) .. " -> " .. tostring(replacement))

    if PlayerResource ~= nil and PlayerResource.ReplaceHeroWith ~= nil then
        local ok, newHero = pcall(function() return PlayerResource:ReplaceHeroWith(playerID, replacement, 0, 0) end)
        if ok and newHero ~= nil and not newHero:IsNull() then
            pcall(function() self:ApplyCustomKartHeroModel(newHero) end)
            return true
        end
    end

    return false
end

function CAddonTemplateGameMode:OnNPCSpawned(keys)
    local spawnedUnit = EntIndexToHScript(keys.entindex)
    if spawnedUnit == nil or spawnedUnit:IsNull() then return end

    if spawnedUnit:IsRealHero() and not spawnedUnit:IsIllusion() then
        local playerID = spawnedUnit:GetPlayerOwnerID()
        if playerID ~= nil and playerID >= 0 then
            local heroName = spawnedUnit:GetUnitName()
            if not self:IsAllowedKartHeroName(heroName) then
                if self:ReplaceInvalidKartHero(playerID, spawnedUnit) then
                    return
                end
                print("[DotA Kart] AVISO: heroi fora da lista oficial registrado porque ReplaceHeroWith falhou: " .. tostring(heroName))
            end

            self:ApplyCustomKartHeroModel(spawnedUnit)
            self:AssignPlayerToFFA(playerID)
            DotaKartHUD:RegisterKart(playerID, spawnedUnit)

            if DOTA_KART_MK64_CAMERA then
                DotaKartCamera:RegisterHero(playerID, spawnedUnit)
            end

            if DOTA_KART_MANUAL_CONTROLS then
                DotaKartController:RegisterHero(playerID, spawnedUnit)
            end
            print("[DotA Kart] Hero/Kart registrado: player " .. tostring(playerID) .. " = " .. tostring(spawnedUnit:GetUnitName()))

            -- Para teste: assim que o Hero/Kart existe, agenda a corrida.
            if not self.raceStarted and GameRules:State_Get() >= DOTA_GAMERULES_STATE_PRE_GAME then
                GameRules:GetGameModeEntity():SetContextThink("DotaKartStartAfterHeroSpawn", function()
                    self:StartDotaKartRace(false)
                    return nil
                end, 0.75)
            end
        end
    end
end

function CAddonTemplateGameMode:HasAtLeastOneHero()
    for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(playerID) then
            local hero = PlayerResource:GetSelectedHeroEntity(playerID)
            if hero ~= nil and not hero:IsNull() and hero:IsRealHero() then
                return true
            end
        end
    end
    return false
end

function CAddonTemplateGameMode:StartDotaKartRace(forceRestart)
    if self.raceStarted and not forceRestart then
        return
    end

    self.raceStarted = true
    self.autoDriveStarted = false

    print("[DotA Kart] Iniciando corrida, minimap e sistema de voltas.")

    local configuredLaps = 3
    if GameRules.DotaKartPublicAI ~= nil and GameRules.DotaKartPublicAI.GetConfiguredLaps ~= nil then
        configuredLaps = GameRules.DotaKartPublicAI:GetConfiguredLaps()
    end

    local ok = DotaKartHUD:StartRace({
        max_laps = configuredLaps,
        prefix = "dk_track_",
        max_points = 1024,
        padding = 512,
        tick_rate = 0.10,
        lap_pass_percent = 0.72,
        min_lap_seconds = 2.0,
        finish_gate_radius = 430,
        finish_gate_exit_radius = 650,
        first_finish_gate_pass_is_free = true,
        required_checkpoints = 3,
        debug = true,
        auto_register_heroes = true,
        closed = true
    })

    if not ok then
        print("[DotA Kart] ERRO: corrida nao iniciou. Use dk_track_debug no console.")
        return
    end

    if DOTA_KART_MK64_CAMERA then
        DotaKartCamera:SetYawOffset(270)
        DotaKartCamera:SetDirectionMode("movement")
        DotaKartCamera:ThinkApplyToExistingHeroes()
        DotaKartCamera:ApplyToAllPlayers(true)
    end

    if DOTA_KART_MANUAL_CONTROLS then
        DotaKartController:ApplyToExistingHeroes()
        DotaKartController:TeleportAllToTrackStart()
        DotaKartController:SetEnabled(true)
    end

    -- FIX18: inicia automaticamente as caixas de item junto com a corrida.
    -- Antes o sistema era inicializado, mas não chamava Start(), então a colisão nunca rodava.
    if DOTA_KART_ITEM_BOXES and GameRules.DotaKartItemSystem ~= nil then
        GameRules.DotaKartItemSystem:Start({
            force_rebuild = true,
            prefix = "dk_itembox_",
            max_points = 1024,
            allow_same_targetname = true,
            debug = true
        })
    end

    -- FIX58: Bots publicos usam IA propria, separada do AutoDrive de teste.
    if GameRules.DotaKartPublicAI ~= nil then
        GameRules.DotaKartPublicAI:StartRaceBots()
    end

    if DOTA_KART_AUTO_DRIVE_TEST then
        GameRules:GetGameModeEntity():SetContextThink("DotaKartAutoDriveDelayedStart", function()
            self:StartAutoDriveTest(false)
            return nil
        end, 1.0)
    end
end

function CAddonTemplateGameMode:StartAutoDriveTest(forceRestart)
    if self.autoDriveStarted and not forceRestart then
        return
    end

    self.autoDriveStarted = true

    print("[DotA Kart] Iniciando AutoDrive pelos pontos dk_track.")

    DotaKartAutoDrive:Start({
        prefix = "dk_track_",
        max_points = 1024,
        arrive_distance = 170,
        order_interval = 0.20,
        tick_rate = 0.05,
        move_speed = 650,
        teleport_to_start = true,
        debug = true
    })
end

function CAddonTemplateGameMode:OnThink()
    local state = GameRules:State_Get()

    -- Comeca no PRE_GAME ou GAME_IN_PROGRESS, assim nao fica esperando ate tarde demais.
    if state >= DOTA_GAMERULES_STATE_PRE_GAME and state < DOTA_GAMERULES_STATE_POST_GAME then
        if not self.raceStarted and self:HasAtLeastOneHero() then
            GameRules:GetGameModeEntity():SetContextThink("DotaKartDelayedRaceStart", function()
                self:StartDotaKartRace(false)
                return nil
            end, 1.0)
        end
    elseif state >= DOTA_GAMERULES_STATE_POST_GAME then
        return nil
    end

    return 0.50
end

-- ============================================================
-- FIX50: Pre-race grid countdown.
-- Espera todos os jogadores humanos terem um kart/herói válido, teleporta todos para
-- player1_start_position..player8_start_position, trava movimento e libera a corrida
-- depois de 10 segundos. Os últimos 3 segundos aparecem no centro da HUD.
-- ============================================================

CAddonTemplateGameMode._DKFix50_OriginalStartDotaKartRace = CAddonTemplateGameMode._DKFix50_OriginalStartDotaKartRace or CAddonTemplateGameMode.StartDotaKartRace

function CAddonTemplateGameMode:GetExpectedHumanRacePlayers()
    local ids = {}
    local maxPlayers = tonumber(DOTA_KART_MAX_PLAYERS or self.maxPlayers or 8) or 8

    for playerID = 0, maxPlayers - 1 do
        if PlayerResource:IsValidPlayerID(playerID) then
            local player = PlayerResource:GetPlayer(playerID)
            local steam = 0
            pcall(function() steam = PlayerResource:GetSteamAccountID(playerID) or 0 end)
            local conn = nil
            pcall(function() conn = PlayerResource:GetConnectionState(playerID) end)

            -- PlayerResource pode ter slots vazios em alguns estados. Considera apenas slots
            -- com Player HScript, SteamID ou conexão ativa.
            local isConnected = (conn == DOTA_CONNECTION_STATE_CONNECTED)
            local isLoading = (conn == DOTA_CONNECTION_STATE_LOADING)
            local isDisconnected = (conn == DOTA_CONNECTION_STATE_DISCONNECTED) or (conn == DOTA_CONNECTION_STATE_ABANDONED)
            if not isDisconnected and (player ~= nil or (tonumber(steam) or 0) > 0 or isConnected or isLoading) then
                table.insert(ids, playerID)
            end
        end
    end

    return ids
end

function CAddonTemplateGameMode:GetReadyHumanKarts()
    local expected = self:GetExpectedHumanRacePlayers()
    local ready = {}

    for _, playerID in ipairs(expected) do
        local hero = PlayerResource:GetSelectedHeroEntity(playerID)
        if hero ~= nil and not hero:IsNull() and hero:IsRealHero() then
            table.insert(ready, playerID)
        end
    end

    return expected, ready
end

function CAddonTemplateGameMode:AreAllHumanKartsReady()
    local expected, ready = self:GetReadyHumanKarts()
    if #expected <= 0 then
        return false, 0, 0
    end
    return #ready >= #expected, #ready, #expected
end

function CAddonTemplateGameMode:GetCountdownSound(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 1 then seconds = 1 end
    if seconds > 10 then seconds = 10 end
    -- FIX51: usa soundevent customizado registrado em dotakart_announcer.vsndevts.
    -- O payload também leva raw_sound como fallback.
    return "dotakart_countdown_" .. string.format("%02d", seconds)
end

function CAddonTemplateGameMode:GetCountdownRawSound(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 1 then seconds = 1 end
    if seconds > 10 then seconds = 10 end
    return "sounds/vo/announcer/ann_custom_countdown_" .. string.format("%02d", seconds) .. ".vsnd"
end

function CAddonTemplateGameMode:BroadcastCountdown(seconds, text, soundName, center, rawSoundName)
    local payload = {
        seconds = tonumber(seconds) or 0,
        text = tostring(text or ""),
        center = center == true and 1 or 0,
        show = 1,
        sound = soundName or "",
        raw_sound = rawSoundName or ""
    }

    -- FIX51: tenta tocar no servidor também. Para o cliente, a HUD recebe o mesmo evento
    -- e tenta via Panorama. O soundevent dotakart_countdown_* é o caminho mais confiável.
    if soundName ~= nil and soundName ~= "" then
        pcall(function() EmitGlobalSound(soundName) end)
    end
    if rawSoundName ~= nil and rawSoundName ~= "" then
        pcall(function() EmitGlobalSound(rawSoundName) end)
    end

    CustomGameEventManager:Send_ServerToAllClients("dotakart_countdown_update", payload)
end

function CAddonTemplateGameMode:PrepareKartsForCountdown()
    if DotaKartHUD ~= nil then
        if DotaKartHUD.trackWorldPoints == nil or #DotaKartHUD.trackWorldPoints < 2 then
            DotaKartHUD:BuildTrackPathFromEntities("dk_track_", 1024, true, 512)
        end
        DotaKartHUD:AutoRegisterHeroKarts()
    end

    if DOTA_KART_MK64_CAMERA and DotaKartCamera ~= nil then
        DotaKartCamera:SetYawOffset(270)
        DotaKartCamera:SetDirectionMode("movement")
        DotaKartCamera:ThinkApplyToExistingHeroes()
        DotaKartCamera:ApplyToAllPlayers(true)
    end

    if DOTA_KART_MANUAL_CONTROLS and DotaKartController ~= nil then
        DotaKartController:ApplyToExistingHeroes()
        DotaKartController:TeleportAllToTrackStart()
        DotaKartController:HardStopAll()
        DotaKartController:SetEnabled(false)
    end

    if DotaKartAutoDrive ~= nil then
        DotaKartAutoDrive:Stop()
        self.autoDriveStarted = false
    end
end

function CAddonTemplateGameMode:StartPreRaceCountdown(forceRestart)
    if self.raceStarted and not forceRestart then return end
    if self.preRaceCountdownStarted and not forceRestart then return end

    local allReady, ready, expected = self:AreAllHumanKartsReady()
    if not allReady then
        print("[DotA Kart] Aguardando karts para countdown: " .. tostring(ready) .. "/" .. tostring(expected))
        return false
    end

    if GameRules.DotaKartPublicAI ~= nil then
        local delaySetup, left = GameRules.DotaKartPublicAI:ShouldDelayCountdownForHostSetup()
        if delaySetup then
            print("[DotA Kart] Aguardando host configurar corrida: " .. tostring(math.ceil(left or 0)) .. "s")
            return false
        end
        GameRules.DotaKartPublicAI:LockHostSetup()
        GameRules.DotaKartPublicAI:PreparePublicBots()
    end

    self.preRaceCountdownStarted = true
    self.preRaceCountdownFinished = false

    self:PrepareKartsForCountdown()

    print("[DotA Kart] Todos os karts humanos apareceram na pista. Countdown de 10 segundos iniciado.")

    for remaining = 10, 1, -1 do
        local r = remaining
        local delay = 10 - r
        GameRules:GetGameModeEntity():SetContextThink("DotaKartPreRaceCountdown" .. tostring(r), function()
            -- Reforça trava durante a contagem para evitar input/cache do Panorama mover o kart.
            if DotaKartController ~= nil then
                DotaKartController:HardStopAll()
                DotaKartController:SetEnabled(false)
            end
            local soundName = self:GetCountdownSound(r)
            local rawSound = self:GetCountdownRawSound(r)
            local showCenter = r <= 3
            self:BroadcastCountdown(r, tostring(r), soundName, showCenter, rawSound)
            return nil
        end, delay)
    end

    GameRules:GetGameModeEntity():SetContextThink("DotaKartPreRaceGo", function()
        local beginSound = "dotakart_race_start"
        local beginRawSound = "sounds/vo/announcer/announcer_battle_begin_01.vsnd"
        self:BroadcastCountdown(0, "GO!", beginSound, true, beginRawSound)
        self.preRaceCountdownFinished = true
        self.preRaceCountdownStarted = false
        -- Chama o StartRace original, pulando o gate do countdown.
        self:StartDotaKartRace(true, true)
        return nil
    end, 10.0)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartPreRaceHideGo", function()
        CustomGameEventManager:Send_ServerToAllClients("dotakart_countdown_update", { show = 0, seconds = -1, text = "" })
        return nil
    end, 11.15)

    return true
end

function CAddonTemplateGameMode:SchedulePreRaceCountdownCheck(forceRestart)
    if self.raceStarted and not forceRestart then return end
    if self.preRaceCountdownStarted and not forceRestart then return end

    GameRules:GetGameModeEntity():SetContextThink("DotaKartWaitAllKartsCountdown", function()
        if self.raceStarted and not forceRestart then return nil end
        if self.preRaceCountdownStarted and not forceRestart then return nil end
        local allReady, ready, expected = self:AreAllHumanKartsReady()
        if allReady then
            self:StartPreRaceCountdown(forceRestart)
            return nil
        end
        print("[DotA Kart] Esperando todos os karts aparecerem: " .. tostring(ready) .. "/" .. tostring(expected))
        return 0.50
    end, 0.10)
end

function CAddonTemplateGameMode:StartDotaKartRace(forceRestart, skipCountdown)
    if skipCountdown == true or self.preRaceCountdownFinished == true then
        self.preRaceCountdownFinished = false
        return self:_DKFix50_OriginalStartDotaKartRace(forceRestart)
    end

    -- Por padrão, iniciar corrida agora significa preparar grid + countdown.
    self:SchedulePreRaceCountdownCheck(forceRestart)
end


function CAddonTemplateGameMode:GetAllowedKartHeroSet()
    if self._dotakartAllowedHeroSet ~= nil then return self._dotakartAllowedHeroSet end
    local set = {}
    for _, heroName in ipairs(DOTA_KART_KART_HERO_POOL or {}) do
        if heroName ~= nil and heroName ~= "" then set[heroName] = true end
    end
    -- FIX104: permite aliases/base heroes usados internamente para manter fake clients/bots
    -- estáveis. Eles continuam contando como o mesmo piloto no GameSetup/AI.
    for customHero, baseHero in pairs(DOTA_KART_KART_BASE_HERO or {}) do
        if customHero ~= nil and customHero ~= "" then set[customHero] = true end
        if baseHero ~= nil and baseHero ~= "" then set[baseHero] = true end
    end
    for baseHero, customHero in pairs(DOTA_KART_BASE_TO_CUSTOM_HERO or {}) do
        if baseHero ~= nil and baseHero ~= "" then set[baseHero] = true end
        if customHero ~= nil and customHero ~= "" then set[customHero] = true end
    end
    self._dotakartAllowedHeroSet = set
    return set
end

function CAddonTemplateGameMode:IsAllowedKartHeroName(heroName)
    heroName = tostring(heroName or "")
    local set = self:GetAllowedKartHeroSet()
    return set[heroName] == true
end

function CAddonTemplateGameMode:GetDefaultKartHeroForPlayer(playerID)
    local pool = DOTA_KART_KART_HERO_POOL or {}
    if #pool <= 0 then return "npc_dota_hero_invoker" end
    local index = ((tonumber(playerID) or 0) % #pool) + 1
    return pool[index] or "npc_dota_hero_invoker"
end

function CAddonTemplateGameMode:ApplyCustomKartHeroModel(unit)
    if unit == nil or unit:IsNull() then return false end
    local heroName = unit:GetUnitName()
    local baseHero = self:GetBaseHeroNameForKartHero(heroName)
    pcall(function() unit.dk_kart_hero_name = baseHero end)
    pcall(function() unit.dotakart_display_hero = baseHero end)
    pcall(function() unit.dotakart_public_ai_hero = baseHero end)

    local modelPath = nil
    if DOTA_KART_CUSTOM_KART_MODELS ~= nil then modelPath = DOTA_KART_CUSTOM_KART_MODELS[heroName] or DOTA_KART_CUSTOM_KART_MODELS[baseHero] end
    if modelPath == nil or modelPath == "" then return false end

    -- FIX85: aplica o modelo custom no próprio herói real, escala visual e esconde
    -- wearables/modelos padrão que o Dota adiciona por cima do custom VMDL.
    local scale = self:GetCustomKartModelScale(heroName)
    local ok1 = pcall(function() unit:SetModel(modelPath) end)
    local ok2 = pcall(function() unit:SetOriginalModel(modelPath) end)
    local ok3 = pcall(function() unit:SetModelScale(scale) end)
    pcall(function() unit:RemoveNoDraw() end)
    pcall(function() unit.dk_kart_custom_model = modelPath end)
    pcall(function() unit.dk_kart_custom_model_scale = scale end)
    if DOTA_KART_CUSTOM_KART_GROUND_Z_OFFSET ~= nil then
        local zoff = tonumber(DOTA_KART_CUSTOM_KART_GROUND_Z_OFFSET[heroName] or DOTA_KART_CUSTOM_KART_GROUND_Z_OFFSET[baseHero] or 0) or 0
        pcall(function() unit.dk_kart_custom_z_offset = zoff end)
    end

    local hidden = self:HideDefaultHeroWearablesForCustomKart(unit, heroName)

    -- Os cosméticos/wearables podem aparecer alguns frames depois do spawn/hero selection.
    -- Reaplica a limpeza em pequenas janelas sem tocar em HUD, itens, IA ou controle.
    local ent = -1
    pcall(function() ent = unit:entindex() end)
    local mode = GameRules:GetGameModeEntity()
    if mode ~= nil and ent ~= nil and ent >= 0 then
        local delays = { 0.03, 0.20, 0.60, 1.20, 2.00 }
        for i, delay in ipairs(delays) do
            mode:SetContextThink("DotaKartCustomKartModel_FIX85_" .. tostring(ent) .. "_" .. tostring(i), function()
                return self:ReapplyCustomKartHeroModel(unit, heroName, modelPath, scale)
            end, delay)
        end
    end

    print("[DotA Kart] FIX85 custom kart model aplicado: " .. tostring(heroName) .. " -> " .. tostring(modelPath) .. " scale=" .. tostring(scale) .. " hidden_children=" .. tostring(hidden))
    return ok1 or ok2 or ok3
end

function CAddonTemplateGameMode:ReplaceInvalidKartHero(playerID, oldHero)
    playerID = tonumber(playerID) or -1
    if playerID < 0 then return false end
    local oldHeroName = oldHero and oldHero:GetUnitName() or ""
    local replacement = self:GetCustomKartHeroForBaseHero(oldHeroName)
    if replacement == nil or replacement == oldHeroName or not self:IsAllowedKartHeroName(replacement) then
        replacement = self:GetDefaultKartHeroForPlayer(playerID)
    end
    print("[DotA Kart] Hero invalido/base detectado. player=" .. tostring(playerID) .. " hero=" .. tostring(oldHeroName) .. " -> " .. tostring(replacement))

    if PlayerResource ~= nil and PlayerResource.ReplaceHeroWith ~= nil then
        local ok, newHero = pcall(function() return PlayerResource:ReplaceHeroWith(playerID, replacement, 0, 0) end)
        if ok and newHero ~= nil and not newHero:IsNull() then
            pcall(function() self:ApplyCustomKartHeroModel(newHero) end)
            return true
        end
    end

    return false
end

function CAddonTemplateGameMode:OnNPCSpawned(keys)
    local spawnedUnit = EntIndexToHScript(keys.entindex)
    if spawnedUnit == nil or spawnedUnit:IsNull() then return end

    if spawnedUnit:IsRealHero() and not spawnedUnit:IsIllusion() then
        local playerID = spawnedUnit:GetPlayerOwnerID()
        if playerID ~= nil and playerID >= 0 then
            local heroName = spawnedUnit:GetUnitName()
            if not self:IsAllowedKartHeroName(heroName) then
                if self:ReplaceInvalidKartHero(playerID, spawnedUnit) then
                    return
                end
                print("[DotA Kart] AVISO: heroi fora da lista oficial registrado porque ReplaceHeroWith falhou: " .. tostring(heroName))
            end

            self:ApplyCustomKartHeroModel(spawnedUnit)
            self:AssignPlayerToFFA(playerID)
            DotaKartHUD:RegisterKart(playerID, spawnedUnit)

            if DOTA_KART_MK64_CAMERA then
                DotaKartCamera:RegisterHero(playerID, spawnedUnit)
            end

            if DOTA_KART_MANUAL_CONTROLS then
                DotaKartController:RegisterHero(playerID, spawnedUnit)
                if not self.raceStarted then
                    DotaKartController:SetEnabled(false)
                    DotaKartController:HardStopAll()
                end
            end
            print("[DotA Kart] Hero/Kart registrado FIX50: player " .. tostring(playerID) .. " = " .. tostring(spawnedUnit:GetUnitName()))

            if not self.raceStarted and GameRules:State_Get() >= DOTA_GAMERULES_STATE_PRE_GAME then
                self:SchedulePreRaceCountdownCheck(false)
            end
        end
    end
end

function CAddonTemplateGameMode:OnThink()
    local state = GameRules:State_Get()
    if state >= DOTA_GAMERULES_STATE_PRE_GAME and state < DOTA_GAMERULES_STATE_POST_GAME then
        if not self.raceStarted and not self.preRaceCountdownStarted then
            self:SchedulePreRaceCountdownCheck(false)
        end
    elseif state >= DOTA_GAMERULES_STATE_POST_GAME then
        return nil
    end
    return 0.50
end

