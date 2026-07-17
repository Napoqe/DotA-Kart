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

-- Heróis/karts possíveis para bots. A IA sorteia depois que humanos escolherem,
-- tentando evitar repetir heróis já usados por humanos.
DOTA_KART_AI_HERO_POOL = {
    "npc_dota_hero_pudge",
    "npc_dota_hero_tusk",
    "npc_dota_hero_brewmaster",
    "npc_dota_hero_kunkka",
    "npc_dota_hero_faceless_void",
    "npc_dota_hero_phantom_assassin",
    "npc_dota_hero_chaos_knight",
    "npc_dota_hero_spirit_breaker",
    "npc_dota_hero_mirana",
    "npc_dota_hero_vengefulspirit",
    "npc_dota_hero_venomancer",
    "npc_dota_hero_lich",
    "npc_dota_hero_invoker",
    "npc_dota_hero_bounty_hunter",
    "npc_dota_hero_rattletrap"
}

-- FIX69: tabela legada mantida apenas para precache defensivo.
-- A IA publica NAO usa mais SetModel/prop_dynamic; cada bot usa o modelo nativo do heroi real.
DOTA_KART_AI_HERO_MODELS = {
    npc_dota_hero_rattletrap = "models/heroes/rattletrap/rattletrap.vmdl",
    npc_dota_hero_pudge = "models/heroes/pudge/pudge.vmdl",
    npc_dota_hero_tusk = "models/heroes/tuskarr/tuskarr.vmdl",
    npc_dota_hero_brewmaster = "models/heroes/brewmaster/brewmaster.vmdl",
    npc_dota_hero_kunkka = "models/heroes/kunkka/kunkka.vmdl",
    npc_dota_hero_faceless_void = "models/heroes/faceless_void/faceless_void.vmdl",
    npc_dota_hero_phantom_assassin = "models/heroes/phantom_assassin/phantom_assassin.vmdl",
    npc_dota_hero_chaos_knight = "models/heroes/chaos_knight/chaos_knight.vmdl",
    npc_dota_hero_spirit_breaker = "models/heroes/spirit_breaker/spirit_breaker.vmdl",
    npc_dota_hero_mirana = "models/heroes/mirana/mirana.vmdl",
    npc_dota_hero_vengefulspirit = "models/heroes/vengeful/vengeful.vmdl",
    npc_dota_hero_venomancer = "models/heroes/venomancer/venomancer.vmdl",
    npc_dota_hero_lich = "models/heroes/lich/lich.vmdl",
    npc_dota_hero_invoker = "models/heroes/invoker/invoker.vmdl",
    npc_dota_hero_bounty_hunter = "models/heroes/bounty_hunter/bounty_hunter.vmdl"
}

if CAddonTemplateGameMode == nil then
    CAddonTemplateGameMode = class({})
end

function Precache(context)
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

    -- FIX44: custom announcer/lap soundevents.
    -- Coloque os MP3 em content/dota_addons/dota_kart/sounds e recompile o soundevent.
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
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_rubick.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_chaos_knight.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_bounty_hunter.vsndevts", context)
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
    GameRules:SetSameHeroSelectionEnabled(true)
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

function CAddonTemplateGameMode:OnNPCSpawned(keys)
    local spawnedUnit = EntIndexToHScript(keys.entindex)
    if spawnedUnit == nil or spawnedUnit:IsNull() then return end

    if spawnedUnit:IsRealHero() and not spawnedUnit:IsIllusion() then
        local playerID = spawnedUnit:GetPlayerOwnerID()
        if playerID ~= nil and playerID >= 0 then
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

function CAddonTemplateGameMode:OnNPCSpawned(keys)
    local spawnedUnit = EntIndexToHScript(keys.entindex)
    if spawnedUnit == nil or spawnedUnit:IsNull() then return end

    if spawnedUnit:IsRealHero() and not spawnedUnit:IsIllusion() then
        local playerID = spawnedUnit:GetPlayerOwnerID()
        if playerID ~= nil and playerID >= 0 then
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

