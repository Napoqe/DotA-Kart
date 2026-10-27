-- DotA Kart - item_system.lua
-- FIX51: local roulette sound, rear camera support hooks, Meat Hook pass-through, Green Shell Cogs tuning.
-- Caixa 3D: models/gameplay/breakingcrate_dest.vmdl
-- Animacoes: breakingcrate_idle, breakingcrate_dest_break_c, breakingcrate_dest_break_b, breakingcrate_dest_break

if DotaKartItemSystem == nil then
    DotaKartItemSystem = class({})
end

-- FIX19: modifiers dos itens reais do DotA Kart.
LinkLuaModifier("modifier_dotakart_star", "dotakart/item_system.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_dotakart_root", "dotakart/item_system.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_dotakart_burrow_airborne", "dotakart/item_system.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_dotakart_frost_pulse_visual", "dotakart/item_system.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_dotakart_astral_enemy", "dotakart/item_system.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_dotakart_astral_self", "dotakart/item_system.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_dotakart_ball_lightning", "dotakart/item_system.lua", LUA_MODIFIER_MOTION_NONE)


local DK_EF_NODRAW = EF_NODRAW or 32

local function DKValidUnit(unit)
    return unit ~= nil and not unit:IsNull()
end

local function DKNow()
    return GameRules:GetGameTime()
end

local function DKClamp(v, a, b)
    v = tonumber(v) or 0
    if v < a then return a end
    if v > b then return b end
    return v
end

local function DKAtan2(y, x)
    if math.atan2 ~= nil then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi / 2 end
    if x == 0 and y < 0 then return -math.pi / 2 end
    return 0
end

local function DKNormalizeYaw(yaw)
    yaw = tonumber(yaw) or 0
    yaw = yaw % 360
    if yaw > 180 then yaw = yaw - 360 end
    if yaw < -180 then yaw = yaw + 360 end
    return yaw
end

local function DKLength2D(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y
    return math.sqrt(dx * dx + dy * dy)
end

local function DKRandomInt(a, b)
    if RandomInt ~= nil then return RandomInt(a, b) end
    return math.random(a, b)
end

local function DKRandomFloat(a, b)
    if RandomFloat ~= nil then return RandomFloat(a, b) end
    return (tonumber(a) or 0) + ((tonumber(b) or 1) - (tonumber(a) or 0)) * math.random()
end

local function DKTableCount(t)
    local c = 0
    if t ~= nil then
        for _, _ in pairs(t) do c = c + 1 end
    end
    return c
end

local function DKSafeCall(obj, methodName, ...)
    if obj == nil then return false end
    local f = obj[methodName]
    if f == nil then return false end
    local ok = pcall(f, obj, ...)
    return ok
end

if modifier_dotakart_root == nil then modifier_dotakart_root = class({}) end
function modifier_dotakart_root:IsHidden() return false end
function modifier_dotakart_root:IsPurgable() return false end
function modifier_dotakart_root:CheckState()
    local state = {}
    if MODIFIER_STATE_ROOTED ~= nil then state[MODIFIER_STATE_ROOTED] = true end
    return state
end

if modifier_dotakart_burrow_airborne == nil then modifier_dotakart_burrow_airborne = class({}) end
function modifier_dotakart_burrow_airborne:IsHidden() return false end
function modifier_dotakart_burrow_airborne:IsPurgable() return false end
function modifier_dotakart_burrow_airborne:CheckState()
    local state = {}
    if MODIFIER_STATE_STUNNED ~= nil then state[MODIFIER_STATE_STUNNED] = true end
    if MODIFIER_STATE_NO_UNIT_COLLISION ~= nil then state[MODIFIER_STATE_NO_UNIT_COLLISION] = true end
    return state
end

-- FIX110: visual padrao de slow/gelo do Dota 2 usado nas vitimas do pulso do Frost Shield.
-- Nao altera movimento: o slow real continua sendo controlado pelo kart_controller.
if modifier_dotakart_frost_pulse_visual == nil then modifier_dotakart_frost_pulse_visual = class({}) end
function modifier_dotakart_frost_pulse_visual:IsHidden() return true end
function modifier_dotakart_frost_pulse_visual:IsPurgable() return false end
function modifier_dotakart_frost_pulse_visual:IsDebuff() return true end
function modifier_dotakart_frost_pulse_visual:GetEffectName()
    return "particles/generic_gameplay/generic_slowed_cold.vpcf"
end
function modifier_dotakart_frost_pulse_visual:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end
function modifier_dotakart_frost_pulse_visual:GetStatusEffectName()
    return "particles/status_fx/status_effect_frost_lich.vpcf"
end
function modifier_dotakart_frost_pulse_visual:StatusEffectPriority() return 10 end


-- FIX120: Astral Imprisonment / Ball Lightning protection states.
if modifier_dotakart_astral_enemy == nil then modifier_dotakart_astral_enemy = class({}) end
function modifier_dotakart_astral_enemy:IsHidden() return true end
function modifier_dotakart_astral_enemy:IsPurgable() return false end
function modifier_dotakart_astral_enemy:OnCreated()
    if IsServer() then pcall(function() self:GetParent():AddNoDraw() end) end
end
function modifier_dotakart_astral_enemy:OnDestroy()
    if IsServer() then pcall(function() self:GetParent():RemoveNoDraw() end) end
end
function modifier_dotakart_astral_enemy:CheckState()
    local s = {}
    if MODIFIER_STATE_OUT_OF_GAME ~= nil then s[MODIFIER_STATE_OUT_OF_GAME] = true end
    if MODIFIER_STATE_INVULNERABLE ~= nil then s[MODIFIER_STATE_INVULNERABLE] = true end
    if MODIFIER_STATE_STUNNED ~= nil then s[MODIFIER_STATE_STUNNED] = true end
    if MODIFIER_STATE_COMMAND_RESTRICTED ~= nil then s[MODIFIER_STATE_COMMAND_RESTRICTED] = true end
    if MODIFIER_STATE_DISARMED ~= nil then s[MODIFIER_STATE_DISARMED] = true end
    if MODIFIER_STATE_NO_UNIT_COLLISION ~= nil then s[MODIFIER_STATE_NO_UNIT_COLLISION] = true end
    return s
end

if modifier_dotakart_astral_self == nil then modifier_dotakart_astral_self = class({}) end
function modifier_dotakart_astral_self:IsHidden() return true end
function modifier_dotakart_astral_self:IsPurgable() return false end
function modifier_dotakart_astral_self:CheckState()
    local s = {}
    -- FIX122: Q self-cast must keep the custom kart controller fully operational.
    -- Blocking item use is handled by DotaKartItemSystem state, so native MUTE/SILENCE
    -- are intentionally avoided here because they can interfere with custom inputs/orders.
    if MODIFIER_STATE_INVULNERABLE ~= nil then s[MODIFIER_STATE_INVULNERABLE] = true end
    if MODIFIER_STATE_UNTARGETABLE ~= nil then s[MODIFIER_STATE_UNTARGETABLE] = true end
    if MODIFIER_STATE_NO_UNIT_COLLISION ~= nil then s[MODIFIER_STATE_NO_UNIT_COLLISION] = true end
    return s
end

if modifier_dotakart_ball_lightning == nil then modifier_dotakart_ball_lightning = class({}) end
function modifier_dotakart_ball_lightning:IsHidden() return true end
function modifier_dotakart_ball_lightning:IsPurgable() return false end
function modifier_dotakart_ball_lightning:CheckState()
    local s = {}
    if MODIFIER_STATE_INVULNERABLE ~= nil then s[MODIFIER_STATE_INVULNERABLE] = true end
    if MODIFIER_STATE_NO_UNIT_COLLISION ~= nil then s[MODIFIER_STATE_NO_UNIT_COLLISION] = true end
    return s
end

function DotaKartItemSystem:Init(hud, controller)
    if self.initialized then return end
    self.initialized = true

    self.hud = hud or GameRules.DotaKartHUD
    self.controller = controller or GameRules.DotaKartController
    self.enabled = false
    self.boxes = {}
    self.boxByName = {}
    self.rolling = {}
    self.itemCharges = {}
    self.activeCharges = {}
    self.activeCogs = {}
    self.activeCogProjectiles = {}
    self.activeFrostShields = {}
    self.activeIceShards = {}
    self.activeItemSteals = {}
    self.itemStealLocks = {}
    self.activeInvisibility = {}
    self.activeIceWalls = {}
    self.activeNatureGrasps = {}
    self.activeSpectralDaggerPaths = {}
    self.activeBattleHungers = {}
    self.activeXMarks = {}
    self.spectralDaggerPathBuffUntil = {}
    self.spectralDaggerPathCreatorUntil = {}
    self.activeConcoctions = {}
    -- FIX117: decoys/clones and Shukuchi runtime state.
    self.activeDoppelwalkDecoys = {}
    self.activeCrystalClones = {}
    self.activeShukuchi = {}
    -- FIX120/FIX131: Astral Imprisonment and toggle-T Ball Lightning runtime state.
    self.activeAstrals = {}
    self.activeBallLightning = {}
    -- Legacy FIX122 pending-hold table kept for save/runtime compatibility; FIX131 uses T-toggle.
    self.pendingBallLightning = {}
    -- FIX121: Static Remnants left behind when Ball Lightning depletes all charges.
    self.activeStaticRemnants = {}
    -- FIX122: Gyrocopter-style waypoint-following Homing Missiles.
    self.activeHomingMissiles = {}
    -- FIX126: Plague Ward / The Swarm / Storm Hammer / Illusory Orb runtime.
    self.activePlagueWards = {}
    self.activeSwarmBeetles = {}
    self.activeIllusoryOrbs = {}
    self.activeDreamCoils = {}
    self.nextSwarmBeetleID = 1
    self.nextDoppelTargetID = -1000
    self.naturesGraspRootImmunity = {}
    self.naturesGraspRootActiveUntil = {}
    self.projectileSerial = 0
    self._thinkStarted = false
    self._lastThinkTime = DKNow()

    self.config = {
        debug = true,
        tick_rate = 0.06,
        prefix = "dk_itembox_",
        max_points = 512,
        model = "models/gameplay/breakingcrate_dest.vmdl",
        idle_anim = "breakingcrate_idle",
        break_anims = {
            "breakingcrate_dest_break_c",
            "breakingcrate_dest_break_b",
            "breakingcrate_dest_break"
        },
        pickup_radius = 230,
        respawn_time = 5.0,
        allow_same_targetname = true,
        hide_delay = 0.35,
        spawn_z_offset = 32,
        auto_create_from_track = true,
        auto_every_track_points = 4,
        auto_start_index = 3,
        roulette_enabled = true,
        roulette_duration = 2.50,
        roulette_step = 0.075,
        roulette_sound_loop = { "dotakart_itembox_spin_loop" },
        roulette_sound_done = { "sounds/ui/treasure_01.vsnd" },
        -- FIX112: som custom 3D quando o kart quebra/colide com uma Item Box.
        item_box_break_sound = { "dotakart_itembox_crate_break" },
        allow_pickup_when_holding_item = false
    }

    -- FIX22: Itens reais do DotA Kart.
    -- Os nomes continuam sendo itens reais do Dota para o DOTAItemImage mostrar ícone na HUD.
    self.itemDefs = {
        item_phase_boots = {
            label = "1 Nitro",
            description = "Um Nitro: impulso forte e curto. Some depois de usar.",
            icon_type = "custom",
            icon = "nitro_1",
            kind = "nitro",
            quality = 1,
            charges = 1,
            boost_duration = 1.35,
            boost_add_speed = 850,
            boost_max_speed = 1650,
            sound = { "sounds/weapons/hero/rattletrap/jetpack_cast.vsnd", "Hero_Rattletrap.Rocket_Flare.Fire" }
        },
        item_yasha = {
            label = "2 Nitros",
            forbidden_first_place = true,
            description = "Dois Nitros independentes. Cada uso consome uma carga e muda o icone.",
            icon_type = "custom",
            icon = "nitro_2",
            kind = "nitro",
            quality = 2,
            charges = 2,
            boost_duration = 1.25,
            boost_add_speed = 780,
            boost_max_speed = 1625,
            charge_items = { [2] = "item_yasha", [1] = "item_phase_boots" },
            sound = { "sounds/weapons/hero/rattletrap/jetpack_cast.vsnd", "Hero_Rattletrap.Rocket_Flare.Fire" }
        },
        item_mask_of_madness = {
            label = "3 Nitros",
            forbidden_first_place = true,
            description = "Tres Nitros independentes. Cada uso consome uma carga e muda o icone: 3, 2, 1.",
            icon_type = "custom",
            icon = "nitro_3",
            kind = "nitro",
            quality = 3,
            charges = 3,
            boost_duration = 1.25,
            boost_add_speed = 760,
            boost_max_speed = 1600,
            charge_items = { [3] = "item_mask_of_madness", [2] = "item_yasha", [1] = "item_phase_boots" },
            sound = { "sounds/weapons/hero/rattletrap/jetpack_cast.vsnd", "Hero_Rattletrap.Rocket_Flare.Fire" }
        },
        item_black_king_bar = {
            label = "Estrelinha",
            forbidden_first_place = true,
            description = "10s invulneravel, imune a status, velocidade maxima, atravessa karts e atordoa quem colidir.",
            icon_type = "item",
            icon = "item_black_king_bar",
            kind = "star",
            quality = 6,
            duration = 10.0,
            boost_add_speed = 900,
            boost_max_speed = 1750,
            star_collision_stun = 0.65,
            star_collision_push = 230,
            particles = {
                "particles/items_fx/black_king_bar_overhead_sphere.vpcf",
                "particles/items_fx/black_king_bar_avatar.vpcf",
                "particles/items_fx/black_king_bar_overhead.vpcf",
                "particles/items_fx/black_king_bar_overhead_shield.vpcf"
            },
            sound = { "DOTA_Item.BlackKingBar.Activate", "sounds/items/black_king_bar.vsnd" },
            sound_loop = { "sounds/weapons/hero/ember_spirit/flame_guard_loop.vsnd", "Hero_EmberSpirit.FlameGuard.Loop" }
        },
        item_force_staff = {
            label = "Meat Hook",
            description = "Hook do Pudge: alcance 4000; projétil mais rápido; puxa inimigos/caixas e libera passagem pelo alvo puxado.",
            icon_type = "ability",
            icon = "pudge_meat_hook",
            kind = "meat_hook",
            quality = 4,
            cast_range = 4000,
            speed = 2100,
            hit_radius = 150,
            pull_speed = 2100,
            final_stun = 0.50,
            -- FIX22: nomes exatos encontrados no Model/Particle Browser.
            -- Criamos corrente + corrente secundaria + ponta do hook ao mesmo tempo.
            particles = {
                "particles/units/heroes/hero_pudge/pudge_meathook_chain.vpcf",
                "particles/units/heroes/hero_pudge/pudge_meathook_chain_secondarychain.vpcf",
                "particles/units/heroes/hero_pudge/pudge_meathook_hook.vpcf"
            },
            sound_throw = { "Hero_Pudge.AttackHookExtend", "sounds/weapons/hero/pudge/hook_throw.vsnd" },
            sound_impact = { "Hero_Pudge.AttackHookImpact" },
            sound_retract = { "Hero_Pudge.AttackHookRetract" }
        },
        item_blink = {
            label = "Hookshot",
            description = "Gancho do Clockwerk: viaja ate 5000; ao acertar um kart, puxa voce ate o alvo e causa stun.",
            icon_type = "ability",
            icon = "rattletrap_hookshot",
            kind = "hookshot",
            quality = 5,
            cast_range = 5000,
            speed = 5000,
            hit_radius = 150,
            pull_speed = 5000,
            stun_duration = 0.85,
            pass_through_duration = 1.10,
            pre_pass_distance = 300,
            final_stop_distance = 80,
            pass_through_distance = 185,
            wood_wall_destroy_distance = 155,
            -- FIX22: projectile principal do gancho.
            particle = "particles/units/heroes/hero_rattletrap/rattletrap_hookshot.vpcf",
            particle_impact = "particles/units/heroes/hero_rattletrap/rattletrap_hookshot_c.vpcf",
            sound_fire = { "Hero_Rattletrap.Hookshot.Fire", "sounds/weapons/hero/rattletrap/hookshot_fire.vsnd" },
            sound_impact = { "Hero_Rattletrap.Hookshot.Impact", "sounds/weapons/hero/rattletrap/hookshot_impact.vsnd" },
            sound_damage = { "Hero_Rattletrap.Hookshot.Damage", "sounds/weapons/hero/rattletrap/hookshot_damage.vsnd" },
            sound_retract = { "Hero_Rattletrap.Hookshot.Retract", "sounds/weapons/hero/rattletrap/hookshot_retract.vsnd" }
        },
        item_hurricane_pike = {
            label = "Leap",
            description = "Salto em arco mais longo e alto. Percorre 1250 unidades, preserva a velocidade de entrada ao aterrissar e ganha +8% de velocidade maxima por 2s.",
            icon_type = "ability",
            icon = "mirana_leap",
            kind = "leap",
            quality = 3,
            distance = 1250,
            speed = 1600,
            max_time = 0.78,
            arc_height = 430,
            move_speed_bonus_pct = 8,
            bonus_duration = 2.0,
            sound = { "dotakart_leap" }
        },
        item_gungir = {
            label = "Sacred Arrow",
            description = "Flecha de alcance 5000. Quanto maior a distancia ate acertar, maior o stun.",
            icon_type = "ability",
            icon = "mirana_arrow",
            kind = "sacred_arrow",
            quality = 5,
            cast_range = 5000,
            speed = 1800,
            hit_radius = 130,
            min_stun = 0.01,
            max_stun = 5.0,
            particle = "particles/econ/items/mirana/mirana_crescent_arrow/mirana_spell_crescent_arrow.vpcf",
            visual_mode = "velocity",
            sound_fire = { "Hero_Mirana.ArrowCast", "sounds/weapons/hero/mirana/arrow.vsnd" },
            sound_impact = { "Hero_Mirana.ArrowImpact" }
        },
        item_cyclone = {
            label = "Swap Missile",
            description = "Missil teleguiado leve. Ao acertar, troca posicao com o alvo e causa 0.5s de stun.",
            icon_type = "ability",
            icon = "vengefulspirit_magic_missile",
            kind = "swap_missile",
            quality = 5,
            cast_range = 3000,
            speed = 1800,
            hit_radius = 155,
            homing_radius = 4200,
            homing_strength = 0.88,
            -- FIX48: projeteis teleguiados só podem perseguir dentro do arco da direção usada.
            -- 0.05 evita virar 180 graus para perseguir alvo no sentido contrário.
            homing_front_dot = 0.05,
            acquire_range = 4800,
            visual_lookahead = 520,
            stun_duration = 0.50,
            obstacle_check_radius = 90,
            particle = "particles/units/heroes/hero_vengeful/vengeful_magic_missle.vpcf",
            -- FIX31: Magic Missile fica melhor usando CP1 como ponto-alvo. O modo velocity fazia o VFX parecer sair de lado.
            visual_mode = "point",
            sound_fire = { "sounds/weapons/hero/vengeful_spirit/magic_missile1.vsnd", "Hero_VengefulSpirit.MagicMissile" },
            sound_impact = { "sounds/weapons/hero/vengeful_spirit/magic_missile_impact.vsnd", "Hero_VengefulSpirit.MagicMissileImpact" },
            sound_swap = { "sounds/weapons/hero/vengeful_spirit/nether_swap.vsnd", "Hero_VengefulSpirit.NetherSwap" }
        },
        item_dotakart_homing_missile = {
            label = "Homing Missile",
            description = "Launches a waypoint-following missile at the racer one place ahead (S+T targets one place behind). It arms for 2.5s, accelerates over time and stuns longer based on distance traveled.",
            icon_type = "ability",
            icon = "gyrocopter_homing_missile",
            kind = "homing_missile",
            quality = 6,
            base_speed = 850,
            acceleration = 260,
            max_speed = 2450,
            direct_radius = 900,
            path_arrive_radius = 220,
            hit_radius = 185,
            timeout = 18.0,
            launch_delay = 2.5, -- FIX128: missile arms in place before starting pursuit
            min_stun = 2.5,
            max_stun = 6.0,
            -- FIX125: fly just above the road so the missile stays readable without floating too high.
            flight_height = 50,
            model_scale = 1.0, -- FIX128: standard Homing Missile size
            visual_unit = "npc_dota_gyrocopter_homing_missile",
            model = "models/items/gyrocopter/dwarven_gyrocopter_off_hand/dwarven_gyrocopter_off_hand.vmdl",
            particle = "particles/econ/items/gyrocopter/hero_gyrocopter_gyrotechnics/gyro_homing_missile_fuse.vpcf",
            sound_launch = { "dotakart_homing_missile_launch" },
            sound_destroy = { "dotakart_homing_missile_destroy" },
            sound_enemy = { "dotakart_homing_missile_enemy" },
            sound_target = { "dotakart_homing_missile_target" }
        },
        item_dotakart_plague_ward = {
            label = "Plague Ward",
            description = "A Plague Ward orbits the kart for 45s, blocks enemy projectiles and fires harmless poison shots that slow racers by 15% for 2s.",
            icon_type = "ability",
            icon = "venomancer_plague_ward",
            kind = "plague_ward",
            quality = 5,
            duration = 45.0,
            orbit_radius = 190,
            orbit_speed = 115,
            block_radius = 120,
            attack_range = 1500, -- FIX128
            attack_interval = 1.0,
            projectile_speed = 1250,
            projectile_hit_radius = 115,
            slow_pct = 0.15,
            slow_duration = 2.0,
            model = "models/heroes/venomancer/venomancer_ward.vmdl",
            particle_projectile = "particles/units/heroes/hero_venomancer/venomancer_plague_ward_projectile.vpcf",
            particle_explosion = "particles/units/heroes/hero_venomancer/venomancer_plague_ward_projectile_explosion.vpcf",
            particle_explosion_flash = "particles/units/heroes/hero_venomancer/venomancer_plague_ward_projectile_explosion_flash.vpcf",
            particle_launch = "particles/units/heroes/hero_venomancer/venomancer_plague_ward_projectile_launch.vpcf",
            particle_trail = "particles/units/heroes/hero_venomancer/venomancer_plague_ward_projectile_trail.vpcf",
            sound_cast = { "dotakart_plague_ward_cast" },
            sound_shoot = { "dotakart_plague_ward_shoot" },
            sound_impact = { "dotakart_plague_ward_impact" }
        },
        item_dotakart_the_swarm = {
            label = "The Swarm",
            description = "Launches 12 untargetable Beetles forward. A Beetle that latches onto a rival lasts 16s and increases its movement slow by 3% every second, dealing no damage.",
            icon_type = "ability",
            icon = "weaver_the_swarm",
            kind = "the_swarm",
            quality = 5,
            count = 12,
            tick_interval = 1.0,
            slow_per_tick = 0.03,
            beetle_duration = 16.0,
            max_distance = 4000,
            speed = 2000, -- FIX127: doubled from 1000
            spawn_radius = 300,
            latch_radius = 100,
            beetle_model = "models/heroes/weaver/weaver_bug.vmdl",
            particle = "particles/units/heroes/hero_weaver/weaver_swarm_projectile.vpcf",
            sound_cast = { "dotakart_swarm_cast" },
            sound_projectile = { "dotakart_swarm_projectile" },
            sound_attach = { "dotakart_swarm_attach" }
        },
        item_dotakart_storm_hammer = {
            label = "Storm Hammer",
            description = "Launches a tracking Storm Hammer up to 1700 units and stuns racers in a 300 radius for 2.5s. Forward casts carry the user's kart only when a valid racer or Item Box target is acquired; S+T throws it backward without moving the user.",
            icon_type = "ability",
            icon = "sven_storm_bolt",
            kind = "storm_hammer",
            quality = 6,
            cast_range = 1700,
            speed = 1750,
            hit_radius = 150,
            effect_radius = 300,
            stun_duration = 2.5,
            particle = "particles/units/heroes/hero_sven/sven_spell_storm_bolt.vpcf",
            sound_cast = { "dotakart_storm_hammer_cast" },
            sound_impact = { "dotakart_storm_hammer_impact" }
        },
        item_dotakart_illusory_orb = {
            label = "Illusory Orb",
            description = "Launches a 3000-range orb that slows nearby rivals by 30% for 1s. Press T again while the orb is active to teleport to it and create a 2s Dream Coil around nearby enemy karts.",
            icon_type = "ability",
            icon = "puck_illusory_orb",
            kind = "illusory_orb",
            quality = 6,
            cast_range = 3000,
            travel_distance = 3000,
            speed = 1350, -- FIX127: small projectile speed increase
            slow_radius = 225,
            slow_pct = 0.30,
            slow_duration = 1.0,
            coil_latch_radius = 375,
            coil_break_radius = 600,
            coil_break_stun = 3.0,
            coil_duration = 2.0,
            particle_orb = "particles/units/heroes/hero_puck/puck_illusory_orb.vpcf",
            -- FIX129: native child components are also rendered as a world-follow fallback.
            -- The parent particle can be invisible when created outside Puck's real ability projectile context.
            particle_orb_main = "particles/units/heroes/hero_puck/puck_illusory_orb_main.vpcf",
            particle_orb_glow = "particles/units/heroes/hero_puck/puck_illusory_orb_glow.vpcf",
            particle_orb_sparks = "particles/units/heroes/hero_puck/puck_illusory_orb_sphere_sparks.vpcf",
            particle_orb_mist = "particles/units/heroes/hero_puck/puck_illusory_orb_mist.vpcf",
            particle_coil_break = "particles/units/heroes/hero_puck/puck_dreamcoil_tether_break.vpcf",
            particle_coil_tether = "particles/units/heroes/hero_puck/puck_dreamcoil_tether.vpcf",
            particle_coil_start = "particles/units/heroes/hero_puck/puck_dreamcoil_start.vpcf",
            sound_orb = { "dotakart_illusory_orb_cast" },
            sound_orb_end = { "dotakart_illusory_orb_end" },
            sound_coil = { "dotakart_dream_coil_cast" },
            sound_coil_snap = { "dotakart_dream_coil_snap" }
        },
        item_shadow_blade = {
            label = "Charge of Darkness",
            description = "Persegue o kart uma colocacao a sua frente. S cancela. Bash leve em quem encostar e stun final de 1s.",
            icon_type = "ability",
            icon = "spirit_breaker_charge_of_darkness",
            kind = "charge_darkness",
            quality = 6,
            forbidden_first_place = true,
            charge_speed = 1750,
            direct_radius = 600,
            hit_radius = 300,
            direct_hit_radius = 360,
            direct_speed_factor = 1.25,
            bash_radius = 300,
            bash_push = 200,
            -- FIX42: limite absoluto do arremesso/forca do Charge para nao mandar o alvo longe demais.
            max_push_distance = 300,
            bash_stun = 0.25,
            stun_duration = 1.00,
            timeout = 10.0,
            path_arrive_radius = 260,
            path_lookahead = 1,
            particle_mark = "particles/econ/items/spirit_breaker/spirit_breaker_iron_surge/spirit_breaker_charge_target_mark_iron.vpcf",
            particle_bash = "particles/units/heroes/hero_spirit_breaker/spirit_breaker_greater_bash.vpcf",
            sound_cast = { "sounds/weapons/hero/spirit_breaker/charge_cast.vsnd", "Hero_Spirit_Breaker.ChargeOfDarkness" },
            sound_impact = { "sounds/weapons/hero/spirit_breaker/charge_impact.vsnd", "Hero_Spirit_Breaker.Charge.Impact" }
        },
        item_orb_of_venom = {
            label = "Venomous Gale",
            description = "Bola de veneno em linha: range 1500, slow inicial de 50% por ate 15s, recuperando aos poucos.",
            icon_type = "ability",
            icon = "venomancer_venomous_gale",
            kind = "venomous_gale",
            quality = 4,
            cast_range = 1500,
            speed = 1500,
            hit_radius = 280,
            duration = 15.0,
            slow_pct = 0.50,
            recover_pct_per_tick = 0.001,
            recover_tick = 0.03,
            particle = "particles/units/heroes/hero_venomancer/venomancer_venomous_gale.vpcf",
            particle_impact = "particles/units/heroes/hero_venomancer/venomancer_venomous_gale_impact.vpcf",
            visual_mode = "velocity",
            sound_fire = { "sounds/weapons/hero/venomancer/venomancer_venomous_gale.vsnd", "Hero_Venomancer.VenomousGale" },
            sound_impact = { "sounds/weapons/hero/venomancer/venomancer_venomous_gale_impact1.vsnd", "Hero_Venomancer.VenomousGaleImpact" }
        },
        item_blade_mail = {
            label = "Power Cogs",
            description = "3 Cogs estilo Green Shell: orbitam; T/S+T arremessa; ricocheteiam e só quebram em jogadores/projéteis.",
            icon_type = "ability",
            icon = "rattletrap_power_cogs",
            kind = "power_cogs",
            quality = 4,
            charges = 3,
            cog_count = 3,
            orbit_radius = 175,
            orbit_speed = 145,
            -- FIX35: enquanto orbitam o usuario, as engrenagens nao expiram sozinhas.
            -- Elas somem apenas se forem arremessadas, colidirem ou acabarem as cargas.
            duration = 0.0,
            shock_radius = 185,
            shock_push = 520,
            shock_stun = 1.35, -- FIX116: +1s de stun
            projectile_speed = 2300,
            projectile_range = 999999,
            max_active_projectiles = 15,
            bounce_radius = 105,
            bounce_cooldown = 0.10,
            -- FIX127: Cogs may climb smooth ramps, but abrupt terrain-height steps/cliffs
            -- are treated as walls and make the Cog ricochet instead of climbing.
            max_terrain_step_up = 56,
            -- FIX104/FIX106: evita que o Cog recém-arremessado destrua imediatamente
            -- os outros Cogs que ainda estão orbitando o próprio usuário, mantendo
            -- a tolerância curta original.
            orbit_collision_grace = 0.65,
            self_hit_grace = 0.65,
            cog_model = "models/heroes/rattletrap/rattletrap_cog.vmdl",
            sound_cast = { "sounds/weapons/hero/rattletrap/power_cogs.vsnd", "Hero_Rattletrap.Power_Cogs" },
            sound_impact = { "sounds/weapons/hero/rattletrap/power_cogs_impact.vsnd", "Hero_Rattletrap.Power_Cogs_Impact" }
        },
        item_wind_waker = {
            label = "Tornado",
            description = "Tornado em linha por 4500 unidades. Levanta karts atingidos por 3.5s e bloqueia itens/movimento.",
            icon_type = "ability",
            icon = "invoker_tornado",
            kind = "tornado",
            quality = 5,
            travel_distance = 4500,
            speed = 1800,
            effect_radius = 300,
            cyclone_duration = 3.5,
            particles = {
                "particles/units/heroes/hero_invoker/invoker_tornado.vpcf",
                "particles/units/heroes/hero_invoker/invoker_tornado_base.vpcf",
                "particles/units/heroes/hero_invoker/invoker_tornado_base_ring.vpcf",
                "particles/units/heroes/hero_invoker/invoker_tornado_base_swirl.vpcf",
                "particles/units/heroes/hero_invoker/invoker_tornado_funnel.vpcf",
                "particles/units/heroes/hero_invoker/invoker_tornado_funnel_detail.vpcf",
                "particles/units/heroes/hero_invoker/invoker_tornado_trail.vpcf"
            },
            sound_cast = { "sounds/weapons/hero/invoker/tornado_cast.vsnd", "Hero_Invoker.Tornado.Cast" },
            sound_target = { "sounds/weapons/hero/invoker/tornado.vsnd", "Hero_Invoker.Tornado.Target" }
        },
        item_mage_slayer = {
            label = "Ice Shards",
            description = "Projétil de gelo. No destino cria 7 shards por 5s; bloqueia karts e cancela projéteis.",
            icon_type = "ability",
            icon = "tusk_ice_shards",
            kind = "ice_shards",
            quality = 4,
            travel_distance = 1700,
            speed = 1500,
            spawn_radius = 260,
            spawn_angle = 220,
            shard_count = 7,
            duration = 5.0,
            collision_radius = 190,
            hit_radius = 210,
            barrier_ahead_distance = 430,
            kart_hits_to_break = 3,
            shard_push = 460,
            shard_stun = 0.18,
            projectile = "particles/units/heroes/hero_tusk/tusk_ice_shards_projectile.vpcf",
            projectile_extra = {
                "particles/units/heroes/hero_tusk/tusk_ice_shards_projectile_flek.vpcf",
                "particles/units/heroes/hero_tusk/tusk_ice_shards_projectile_frost.vpcf",
                "particles/units/heroes/hero_tusk/tusk_ice_shards_projectile_model.vpcf"
            },
            shard_particles = {
                "particles/econ/items/tuskarr/tusk_ti5_immortal/tusk_ice_shards_stout_crystal.vpcf",
                "particles/econ/items/tuskarr/tusk_ti5_immortal/tusk_ice_shards_stout_base.vpcf",
                "particles/econ/items/tuskarr/tusk_ti5_immortal/tusk_ice_shards_stout.vpcf"
            },
            sound_cast = { "sounds/weapons/hero/tusk/ice_shards_cast.vsnd", "Hero_Tusk.IceShards.Cast" },
            sound_projectile = { "sounds/weapons/hero/tusk/ice_shards_projectile.vsnd", "Hero_Tusk.IceShards.Projectile" },
            sound_spawn = { "sounds/weapons/hero/tusk/ice_shards.vsnd", "Hero_Tusk.IceShards" }
        },
        item_spell_steal = {
            label = "Item Steal",
            description = "Procura por 5s um adversario com item. Ao encontrar, ambos mostram Spell Steal por 2s, entao o item e roubado.",
            icon_type = "ability",
            icon = "rubick_spell_steal",
            kind = "item_steal",
            quality = 5,
            search_duration = 5.0,
            steal_delay = 2.0,
            search_tick = 0.25,
            visual_tick = 0.35,
            particle = "particles/units/heroes/hero_rubick/rubick_spell_steal_flash.vpcf",
            sound_cast = { "sounds/weapons/hero/rubick/spell_steal_cast.vsnd", "Hero_Rubick.SpellSteal.Cast" },
            sound_complete = { "sounds/weapons/hero/rubick/spell_steal_complete.vsnd", "Hero_Rubick.SpellSteal.Complete" },
            sound_target = { "sounds/weapons/hero/rubick/spell_steal_target.vsnd", "Hero_Rubick.SpellSteal.Target" }
        },
        item_basher = {
            label = "Chaos Bolt",
            description = "Se houver alvo adversário no alcance, dispara um projétil que persegue esse alvo até acertar ou bater em árvores; stun aleatório de 1.5s a 6s.",
            icon_type = "ability",
            icon = "chaos_knight_chaos_bolt",
            kind = "chaos_bolt",
            quality = 5,
            cast_range = 1200,
            speed = 1350,
            hit_radius = 155,
            homing_radius = 1400,
            homing_strength = 0.92,
            homing_front_dot = -1.0,
            locked_lifetime = 30.0,
            obstacle_check_radius = 96,
            arc_height = 210,
            min_stun = 1.5,
            max_stun = 6.0,
            particle = "particles/units/heroes/hero_chaos_knight/chaos_knight_chaos_bolt.vpcf",
            particle_launch = "particles/units/heroes/hero_chaos_knight/chaos_knight_chaos_bolt_launch.vpcf",
            particle_explosion = "particles/units/heroes/hero_chaos_knight/chaos_knight_chaos_bolt_explosion.vpcf",
            sound_cast = { "sounds/weapons/hero/chaos_knight/chaos_bolt_cast.vsnd", "Hero_ChaosKnight.ChaosBolt.Cast" },
            sound_target = { "sounds/weapons/hero/chaos_knight/chaos_bolt_target.vsnd", "Hero_ChaosKnight.ChaosBolt.Target" }
        },
        item_glimmer_cape = {
            label = "Invisibility",
            description = "Fica invisível por 15s. Projéteis teleguiados ignoram o kart invisível.",
            icon_type = "ability",
            icon = "bounty_hunter_wind_walk",
            kind = "invisibility",
            quality = 4,
            duration = 15.0,
            particle = "particles/units/heroes/hero_bounty_hunter/bounty_hunter_windwalk_smoke.vpcf",
            particle_top = "particles/units/heroes/hero_bounty_hunter/bounty_hunter_windwalk_smoke_top.vpcf",
            sound_cast = { "sounds/weapons/hero/bounty_hunter/shadow_walk.vsnd", "Hero_BountyHunter.WindWalk" }
        },
        item_kaya = {
            label = "Ice Wall",
            description = "Solta rastro de gelo por 5s. Rivais em contato recebem 60% slow; gelo some em até 8s.",
            icon_type = "ability",
            icon = "invoker_ice_wall",
            kind = "ice_wall",
            quality = 4,
            emit_duration = 5.0,
            total_duration = 8.0,
            spawn_interval = 0.16,
            segment_radius = 175,
            visual_radius = 72, -- FIX57: visual menor e central; área de slow preservada
            segment_back_offset = 190, -- FIX57: rastro nasce claramente atrás do kart do usuário
            segment_side_offset = 0, -- FIX57: nunca desloca para lateral; evita dois rastros paralelos
            slow_pct = 0.60,
            slow_refresh = 0.20,
            particle_shards = "particles/units/heroes/hero_invoker/invoker_ice_wall_shards.vpcf",
            particle_ground = "particles/units/heroes/hero_invoker/invoker_ice_wall_snow_ground.vpcf",
            -- FIX58: testando particle pedido pelo Rafael.
            -- Mantem apenas UM segmento central atras do kart; nao volta para shards como rastro principal.
            visual_particle = "particles/units/heroes/hero_invoker/invoker_ice_wall_icicle.vpcf",
            visual_particle_is_icicle = true,
            visual_particle_fallback = "particles/units/heroes/hero_tusk/tusk_ice_shards_projectile_frost.vpcf",
            single_visual_trail = true,
            particle_shatter = "particles/units/heroes/hero_invoker/invoker_ice_wall_hero_shatter.vpcf",
            sound_slow = { "sounds/weapons/hero/invoker/ice_wall_slow02.vsnd", "Hero_Invoker.IceWall.Slow" },
            -- FIX60: som curto onde o rastro de gelo nasce. Sem loop persistente.
            sound_trail = { "sounds/weapons/hero/crystal_maiden/freezing_field.vsnd" },
            sound_trail_interval = 0.70
        },
        item_dotakart_burrowstrike = {
            label = "Burrowstrike",
            description = "Túneis em linha até 2000. Spikes viajam a 2000, atordoam e arremessam rivais para cima; usuário teleporta no fim mantendo velocidade.",
            icon_type = "ability",
            icon = "sandking_burrowstrike",
            kind = "burrowstrike",
            quality = 5,
            cast_range = 2000,
            speed = 2000,
            hit_radius = 150,
            stun_duration = 1.0,
            knockup_height = 350,
            knockup_duration = 0.52,
            safe_step = 80,
            safe_radius = 130,
            particle_ground = "particles/units/heroes/hero_sandking/sandking_burrowstrike_ground.vpcf",
            particle_low = "particles/units/heroes/hero_sandking/sandking_burrowstrike_low.vpcf",
            particle_mid = "particles/units/heroes/hero_sandking/sandking_burrowstrike_mid.vpcf",
            sound_cast = { "dotakart_burrowstrike_cast", "Hero_SandKing.BurrowStrike", "Hero_Sandking.BurrowStrike", "sounds/weapons/hero/sand_king/sand_king_burrow_attack.vsnd" },
            visual_step = 90,
            visual_duration = 0.65
        },
        item_dotakart_natures_grasp = {
            label = "Nature's Grasp",
            description = "Cria uma linha de vinhas até 2400 unidades. Karts rivais que tocam as vinhas recebem root.",
            icon_type = "ability",
            icon = "treant_natures_grasp",
            kind = "natures_grasp",
            quality = 4,
            cast_range = 2400,
            vine_count = 24,
            vine_spacing = 100,
            vine_radius = 150,
            spawn_interval = 0.04,
            duration = 5.0,
            root_duration = 1.85,
            root_immunity_after = 5.0,
            particle_vine = "particles/units/heroes/hero_treant/treant_bramble_root_model.vpcf",
            particle_root = "particles/units/heroes/hero_treant/treant_bramble_root.vpcf",
            sound_cast = { "sounds/weapons/hero/treant/natures_guise.vsnd", "Hero_Treant.NaturesGuise.On" },
            sound_root = { "sounds/weapons/hero/treant/overgrowth_target02.vsnd", "Hero_Treant.Overgrowth.Target" },
            sound_root_hit = { "sounds/weapons/hero/treant/overgrowth_cast.vsnd", "Hero_Treant.Overgrowth.Cast" }
        },
        item_dotakart_bloodlust = {
            label = "Bloodlust",
            description = "Aumenta velocidade e tamanho do kart por 15s. Pode sair 2x/3x/4x Multicast para amplificar o bônus.",
            icon_type = "ability",
            icon = "ogre_magi_bloodlust",
            kind = "bloodlust",
            quality = 5,
            duration = 15.0,
            move_speed_bonus = { [1] = 8, [2] = 12, [3] = 16, [4] = 20 },
            multicast_chance = { [2] = 50, [3] = 30, [4] = 15 },
            -- FIX116: chance de Multicast escala com a posição; líder tem chance
            -- bem menor e o último colocado mantém forte potencial de comeback.
            multicast_chance_by_tier = {
                [1] = { [2] = 22, [3] = 6,  [4] = 2  },
                [2] = { [2] = 26, [3] = 8,  [4] = 3  },
                [3] = { [2] = 30, [3] = 10, [4] = 4  },
                [4] = { [2] = 34, [3] = 13, [4] = 5  },
                [5] = { [2] = 38, [3] = 16, [4] = 7  },
                [6] = { [2] = 42, [3] = 20, [4] = 9  },
                [7] = { [2] = 46, [3] = 24, [4] = 12 },
                [8] = { [2] = 50, [3] = 28, [4] = 16 },
            },
            model_scale_bonus = 0.25,
            particle = "particles/units/heroes/hero_ogre_magi/ogre_magi_bloodlust_buff_symbol.vpcf",
            sound_target = { "sounds/weapons/hero/ogre_magi/bloodlust_target.vsnd", "Hero_OgreMagi.Bloodlust.Target" },
            sound_multicast = {
                [2] = { "sounds/weapons/hero/ogre_magi/multicast01.vsnd", "Hero_OgreMagi.Multicast.x2" },
                [3] = { "sounds/weapons/hero/ogre_magi/multicast02.vsnd", "Hero_OgreMagi.Multicast.x3" },
                [4] = { "sounds/weapons/hero/ogre_magi/multicast03.vsnd", "Hero_OgreMagi.Multicast.x4" }
            }
        },
        item_dotakart_unstable_concoction = {
            label = "Unstable Concoction",
            description = "Prepara uma mistura instável; use novamente para arremessar antes de explodir.",
            icon_type = "ability",
            icon = "alchemist_unstable_concoction",
            kind = "unstable_concoction",
            quality = 5,
            max_brew_time = 5.0,
            explode_time = 5.5,
            max_stun = 3.2,
            move_speed_bonus_pct = 10,
            radius = 350,
            cast_range = 1200,
            projectile_speed = 1400,
            hit_radius = 170,
            homing_strength = 0.92,
            particle = "particles/units/heroes/hero_alchemist/alchemist_unstable_concoction_projectile.vpcf",
            particle_explosion = "particles/units/heroes/hero_alchemist/alchemist_unstable_concoction_projectile_explosion.vpcf",
            sound_fuse = { "dotakart_unstable_concoction_fuse", "sounds/weapons/hero/alchemist/unstable_concoction_fuse.vsnd", "Hero_Alchemist.UnstableConcoction.Fuse" },
            sound_throw = { "dotakart_unstable_concoction_throw", "sounds/weapons/hero/alchemist/unstable_concoction_throw.vsnd", "Hero_Alchemist.UnstableConcoction.Throw" },
            sound_stun = { "dotakart_unstable_concoction_stun", "sounds/weapons/hero/alchemist/unstable_concoction_stun01.vsnd", "Hero_Alchemist.UnstableConcoction.Stun" },
            throw_item = "item_dotakart_unstable_concoction_throw"
        },
        item_dotakart_unstable_concoction_throw = {
            label = "Unstable Concoction Throw",
            description = "Arremessa a mistura em um kart adversário ou para frente/trás antes de explodir.",
            icon_type = "ability",
            icon = "alchemist_unstable_concoction_throw",
            kind = "unstable_concoction_throw",
            quality = 5,
            cast_range = 1200,
            radius = 350,
            projectile_speed = 1400,
            hit_radius = 170,
            homing_strength = 0.92,
            particle = "particles/units/heroes/hero_alchemist/alchemist_unstable_concoction_projectile.vpcf",
            particle_explosion = "particles/units/heroes/hero_alchemist/alchemist_unstable_concoction_projectile_explosion.vpcf",
            sound_throw = { "dotakart_unstable_concoction_throw", "sounds/weapons/hero/alchemist/unstable_concoction_throw.vsnd", "Hero_Alchemist.UnstableConcoction.Throw" },
            sound_stun = { "dotakart_unstable_concoction_stun", "sounds/weapons/hero/alchemist/unstable_concoction_stun01.vsnd", "Hero_Alchemist.UnstableConcoction.Stun" }
        },
        item_dotakart_spectral_dagger = {
            label = "Spectral Dagger",
            description = "Lança uma adaga que persegue diretamente o rival uma posição à frente até 2000. S+T mira atrás; R+T força disparo para frente/atalho.",
            icon_type = "ability",
            icon = "spectre_spectral_dagger",
            kind = "spectral_dagger",
            quality = 4,
            forbidden_first_place = true,
            cast_range = 2000,
            speed = 1200,
            hit_radius = 175,
            effect_radius = 175,
            slow_pct = 0.10,
            slow_refresh = 0.30,
            path_duration = 12.0,
            path_creator_duration = 7.0,
            path_radius = 200,
            path_buff_bonus_pct = 0.10,
            path_buff_linger = 1.0,
            -- FIX94: Spectral Dagger do DotA Kart agora usa projétil lógico + thinker Lua.
            -- O rastro é gerado por segmentos persistentes no chão, e não depende de um VPCF longo único.
            path_segment_spacing = 60,
            path_visual_stride = 1,
            homing_strength = 0.90,
            locked_lifetime = 8.0,
            direct_target_distance = 500,
            particle = "particles/units/heroes/hero_spectre/spectre_spectral_dagger_tracking.vpcf",
            particle_fallback = "particles/units/heroes/hero_spectre/spectre_spectral_dagger_fallback_mid.vpcf",
            particle_glow = "particles/units/heroes/hero_spectre/spectre_spectral_dagger_glow.vpcf",
            particle_path = "particles/units/heroes/hero_spectre/spectre_shadow_path.vpcf",
            particle_path_alt = "particles/units/heroes/hero_spectre/spectre_spectral_dagger_tracking.vpcf",
            particle_path_owner = "particles/units/heroes/hero_spectre/spectre_shadow_path_owner.vpcf",
            particle_path_owner_fallback = "particles/units/heroes/hero_spectre/spectre_shadow_path_owner_fallback_mid.vpcf",
            particle_hit = "particles/units/heroes/hero_spectre/spectre_spectral_dagger_fallback_mid.vpcf",
            particle_tracking = "particles/units/heroes/hero_spectre/spectre_spectral_dagger_tracking.vpcf",
            unobstructed_owner = true,
            stuck_recover_delay = 5.0,
            sound_cast = { "dotakart_spectral_dagger_cast_2d", "dotakart_spectral_dagger_cast", "sounds/weapons/hero/spectre/dagger_cast.vsnd", "Hero_Spectre.SpectralDagger", "Hero_Spectre.SpectralDagger.Cast" },
            sound_hit = { "dotakart_spectral_dagger_impact_2d", "dotakart_spectral_dagger_impact", "sounds/weapons/hero/spectre/dagger_impact.vsnd", "Hero_Spectre.SpectralDagger.Impact" }
        },
        item_dotakart_battle_hunger = {
            label = "Battle Hunger",
            description = "15s: usuário +15% velocidade e o rival exatamente 1 posição à frente recebe -15%. S+T mira 1 posição atrás. Se a vítima acertar outro kart com um item, os dois efeitos acabam.",
            icon_type = "ability",
            icon = "axe_battle_hunger",
            kind = "battle_hunger",
            quality = 4,
            duration = 15.0,
            caster_speed_bonus_pct = 0.15,
            victim_slow_pct = 0.15,
            particle_caster = "particles/econ/items/axe/axe_cinder/axe_cinder_battle_hunger_start_fire.vpcf",
            particle_debuff = "particles/units/heroes/hero_axe/axe_battle_hunger.vpcf",
            particle_start = "particles/units/heroes/hero_axe/axe_battle_hunger_start.vpcf",
            sound = { "sounds/weapons/hero/axe/battle_hunger.vsnd", "Hero_Axe.Battle_Hunger" }
        },
        item_dotakart_x_marks = {
            label = "X Marks the Spot",
            description = "Projétil em linha range 2000. Marca o kart atingido por 5s e o retorna ao X; S+T lança para trás. Invulnerável/hidden no retorno desperdiça o efeito.",
            icon_type = "ability",
            icon = "kunkka_x_marks_the_spot",
            kind = "x_marks",
            quality = 4,
            duration = 5.0,
            cast_range = 2000,
            speed = 1800,
            hit_radius = 165,
            particle_projectile = "particles/units/heroes/hero_kunkka/kunkka_spell_x_spot.vpcf",
            particle_mark = "particles/units/heroes/hero_kunkka/kunkka_spell_x_spot.vpcf",
            particle_line = "particles/units/heroes/hero_kunkka/kunkka_spell_x_spot_line.vpcf",
            particle_return = "particles/units/heroes/hero_kunkka/kunkka_spell_x_spot_return.vpcf",
            -- FIX114: usa soundevents próprios do addon apontando para os .vsnd solicitados.
            -- Evita tratar caminho raw como nome de soundevent e elimina aliases incorretos.
            sound_target = { "dotakart_xmarks_target" },
            sound_movement = { "dotakart_xmarks_movement" },
            sound_return = { "dotakart_xmarks_return" }
        },
        item_dotakart_doppelwalk = {
            label = "Doppelwalk",
            description = "Fica invisível por 8s, ganha +10% de velocidade máxima e cria uma ilusão que segue a pista e pode enganar projéteis teleguiados.",
            icon_type = "ability", icon = "phantom_lancer_doppelwalk", kind = "doppelwalk", quality = 4,
            fade_time = 0.0, duration = 8.0, move_speed_bonus_pct = 0.10, decoy_hit_radius = 155,
            particle = "particles/units/heroes/hero_phantom_lancer/phantomlancer_doppelwalk.vpcf",
            sound = { "dotakart_doppelwalk" }
        },
        item_dotakart_shukuchi = {
            label = "Shukuchi",
            description = "Disjoints homing projectiles, fades invisible after 0.25s, gains 1.5x max speed/phased movement for 4s and stuns racers passed through for 0.5s.",
            icon_type = "ability", icon = "weaver_shukuchi", kind = "shukuchi", quality = 6,
            fade_time = 0.25, radius = 175, duration = 4.0, max_speed_multiplier = 1.5, haste_speed = 550, stun_duration = 0.5,
            particle = "particles/units/heroes/hero_weaver/weaver_shukuchi.vpcf",
            particle_damage = "particles/units/heroes/hero_weaver/weaver_shukuchi_damage.vpcf",
            particle_damage_arc = "particles/units/heroes/hero_weaver/weaver_shukuchi_damage_arc.vpcf",
            sound = { "dotakart_shukuchi" }
        },
        item_dotakart_astral_imprisonment = {
            label = "Astral Imprisonment",
            description = "T imprisons the racer one place ahead for 4s (S+T targets one place behind); Q uses Astral on yourself, remaining visible and moving at normal speed while untargetable.",
            icon_type = "ability", icon = "obsidian_destroyer_astral_imprisonment", kind = "astral_imprisonment", quality = 5,
            cast_range = 1500, duration = 4.0,
            particle_start = "particles/units/heroes/hero_obsidian_destroyer/obsidian_destroyer_prison_start.vpcf",
            particle_prison = "particles/units/heroes/hero_obsidian_destroyer/obsidian_destroyer_prison.vpcf",
            particle_ring = "particles/units/heroes/hero_obsidian_destroyer/obsidian_destroyer_prison_ring.vpcf",
            -- FIX122: persistent mobile Shard-style visuals for Q self-cast.
            particle_shard_self = "particles/units/heroes/hero_obsidian_destroyer/obsidian_destroyer_prison_light.vpcf",
            particle_shard_orb = "particles/units/heroes/hero_obsidian_destroyer/obsidian_destroyer_prison_top_orb.vpcf",
            particle_end = "particles/units/heroes/hero_obsidian_destroyer/obsidian_destroyer_prison_end.vpcf",
            sound_cast = { "dotakart_astral_cast" },
            sound_loop = { "dotakart_astral_loop" },
            sound_stop = { "dotakart_astral_stop" }
        },
        item_dotakart_ball_lightning = {
            label = "Ball Lightning",
            description = "Press T to toggle Ball Lightning on. Press T again to stop and preserve remaining charges. Starts with 6000 distance charges; costs 1 charge per unit traveled and disappears only at 0 charges, leaving a Static Remnant.",
            icon_type = "ability", icon = "storm_spirit_ball_lightning", kind = "ball_lightning", quality = 6,
            charges = 6000, charges_distance = 6000, travel_speed = 1900, travel_acceleration = 5200,
            remnant_duration = 12.0, remnant_activation_delay = 0.75, remnant_trigger_radius = 235,
            remnant_slow_pct = 0.80, remnant_slow_duration = 0.8,
            remnant_particles = {
                "particles/units/heroes/hero_stormspirit/stormspirit_static_remnant_image.vpcf",
                "particles/units/heroes/hero_stormspirit/stormspirit_static_remnant_glow.vpcf",
                "particles/units/heroes/hero_stormspirit/stormspirit_static_remnant_points.vpcf",
                "particles/units/heroes/hero_stormspirit/stormspirit_static_remnant_shadow.vpcf",
                "particles/units/heroes/hero_stormspirit/storm_spirit_static_remnant_beam_ambient_arcs.vpcf"
            },
            remnant_sound_plant = { "dotakart_static_remnant_plant" },
            remnant_sound_explode = { "dotakart_static_remnant_explode" },
            particle_main = "particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning.vpcf",
            particles_active = {
                "particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning_arc.vpcf",
                "particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning_arc2.vpcf",
                "particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning_beams.vpcf",
                "particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning_glow.vpcf",
                "particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning_light.vpcf",
                "particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning_sphere.vpcf",
                "particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning_sphere_arcs.vpcf",
                "particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning_sphere_sparks.vpcf",
                "particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning_trail.vpcf",
                "particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning_trail_base.vpcf",
                "particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning_trail_base_elec.vpcf",
                "particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning_trail_base_lgt.vpcf",
                "particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning_trail_cloud.vpcf",
                "particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning_trail_lrg.vpcf",
                "particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning_trail_swirl.vpcf"
            },
            particle_end = "particles/units/heroes/hero_stormspirit/stormspirit_ball_lightning_end.vpcf",
            sound_start = { "dotakart_ball_lightning_start" },
            sound_loop = { "dotakart_ball_lightning_loop" },
            sound_end = { "dotakart_ball_lightning_end" }
        },
        item_dotakart_crystal_clone = {
            label = "Crystal Clone",
            description = "Cria um clone estacionário da Crystal Maiden por 90s. Kart ou projétil que o atingir o explode, aplicando Frostbite/root por 2.5s em raio 600.",
            icon_type = "ability", icon = "crystal_maiden_crystal_clone", kind = "crystal_clone", quality = 4,
            duration = 90.0, collision_radius = 155, frostbite_radius = 600, root_duration = 2.5,
            model = "models/heroes/crystal_maiden/crystal_maiden_deathsim.vmdl",
            frostbite_particles = {
                "particles/units/heroes/hero_crystalmaiden/maiden_shard_frostbite_base.vpcf",
                "particles/units/heroes/hero_crystalmaiden/maiden_shard_frostbite_vapor.vpcf",
                "particles/units/heroes/hero_crystalmaiden/maiden_shard_frostbite_mist.vpcf",
                "particles/units/heroes/hero_crystalmaiden/maiden_frostbite_buff.vpcf"
            },
            sound_frostbite = { "dotakart_crystal_clone_frostbite" },
            particle_status = "particles/status_fx/crystal_maiden_crystal_clone.vpcf",
            particle_end = "particles/units/heroes/hero_crystalmaiden/maiden_crystal_clone_end.vpcf",
            particle_snow = "particles/units/heroes/hero_crystalmaiden/maiden_crystal_clone_end_snow_burst.vpcf",
            particle_ring = "particles/units/heroes/hero_crystalmaiden/maiden_crystal_clone_end_aoe_shockwave_ring.vpcf",
            particle_blast = "particles/units/heroes/hero_crystalmaiden/maiden_crystal_clone_end_blast.vpcf",
            particle_shock = "particles/units/heroes/hero_crystalmaiden/maiden_crystal_clone_end_shock.vpcf",
            sound_cast = { "dotakart_crystal_clone_cast" },
            sound_destroy = { "dotakart_crystal_clone_destroy" }
        },
        item_dotakart_torrent_storm = {
            label = "Torrent Storm",
            description = "Por 5s cria um Torrent visível a cada 0.25s em 115-1500 de distância ao redor do usuário. Cada Torrent avisa por 1.6s, então arremessa e atordoa inimigos no raio 225 e aplica 40% slow por 4s.",
            icon_type = "ability",
            icon = "kunkka_torrent",
            kind = "torrent_storm",
            quality = 5,
            storm_duration = 5.0,
            spawn_interval = 0.25,
            effect_radius = 225,
            effect_delay = 1.6,
            move_slow_pct = 0.40,
            slow_duration = 4.0,
            stun_duration = 1.6,
            knockup_duration = 1.53,
            knockup_height = 420,
            min_spawn_radius = 115,
            max_spawn_radius = 1500,
            particle_wave = "particles/units/heroes/hero_kunkka/kunkka_spell_torrent_wave.vpcf",
            particle_splash = "particles/units/heroes/hero_kunkka/kunkka_spell_torrent_splash_scepter.vpcf",
            -- FIX111: eventos e arquivos do Torrent verificados no game_sounds_kunkka.vsndevts.
            sound_pre = { "Ability.pre.Torrent", "sounds/weapons/hero/kunkka/ability_pre_geyser.vsnd" },
            sound_hit = { "Ability.Torrent", "sounds/weapons/hero/kunkka/ability_geyser.vsnd" }
        },
        item_shivas_guard = {
            label = "Frost Shield",
            description = "Escudo gelado por 8s. Pulsa a cada 1s em raio 800, causando slow de 35% por 0.5s.",
            icon_type = "ability",
            icon = "lich_frost_shield",
            kind = "frost_shield",
            quality = 4,
            duration = 8.0,
            pulse_radius = 800,
            pulse_interval = 1.0,
            pulse_slow_pct = 0.35,
            pulse_slow_duration = 0.5,
            -- FIX108: partículas substituídas exatamente pelas solicitadas.
            particle_shield = "particles/units/heroes/hero_lich/lich_chain_frost_.vpcf",
            particle_pulse = "particles/units/heroes/hero_lich/lich_chain_frost_explode.vpcf",
            particle_pulse_ring = "particles/units/heroes/hero_lich/lich_ice_age_dmg_aoe_ring.vpcf",
            -- FIX39: raw .vsnd + aliases. O site de sons do Lich confirma Frost Shield cast + target impact.
            -- FIX111: eventos verificados no game_sounds_lich.vsndevts.
            -- Hero_Lich.IceAge -> ice_age_target.vsnd; Hero_Lich.IceAge.Damage -> impact01/02.vsnd.
            sound_cast = {
                "Hero_Lich.IceAge",
                "sounds/weapons/hero/lich/ice_age_target.vsnd"
            },
            sound_pulse = {
                "Hero_Lich.IceAge.Damage",
                "sounds/weapons/hero/lich/impact01.vsnd",
                "sounds/weapons/hero/lich/impact02.vsnd"
            }
        },
        item_sheepstick = {
            label = "Chain Frost",
            description = "Orbe de gelo teleguiado. Salta ate 10 vezes entre karts em raio 1200 e causa slow de 65% por 2.5s.",
            icon_type = "ability",
            icon = "lich_chain_frost",
            kind = "chain_frost",
            quality = 6,
            cast_range = 1200,
            bounce_distance = 1200,
            bounce_delay = 0.2,
            max_bounces = 10,
            projectile_speed = 1100,
            hit_radius = 180,
            homing_front_dot = 0.05,
            visual_lookahead = 520,
            slow_pct = 0.65,
            slow_duration = 2.5,
            particle = "particles/units/heroes/hero_lich/lich_chain_frost.vpcf",
            particle_impact = "particles/econ/items/lich/lich_ti8_immortal_arms/lich_ti8_chain_frost_explode.vpcf",
            particle_victim = "particles/units/heroes/hero_lich/lich_frost_armor_ice.vpcf",
            sound_cast = {
                "sounds/weapons/hero/lich/chain_frost_cast.vsnd",
                "sounds/weapons/hero/lich/chain_frost_cast",
                "weapons/hero/lich/chain_frost_cast",
                "Hero_Lich.ChainFrost",
                "Hero_Lich.ChainFrost.Cast"
            },
            -- FIX39: som de voo do projétil. O Dota 2 Wiki/Fandom lista chain_frost_loop como loop do projectile.
            sound_loop = {
                "sounds/weapons/hero/lich/chain_frost_loop.vsnd",
                "sounds/weapons/hero/lich/chain_frost_loop",
                "weapons/hero/lich/chain_frost_loop",
                "Hero_Lich.ChainFrostLoop",
                "Hero_Lich.ChainFrost.Loop",
                "Hero_Lich.ChainFrost.Projectile"
            },
            -- FIX39: tenta os impactos específicos em herói além do impacto genérico.
            sound_impact = {
                "sounds/weapons/hero/lich/chain_frost_impact_hero01.vsnd",
                "sounds/weapons/hero/lich/chain_frost_impact_hero02.vsnd",
                "sounds/weapons/hero/lich/chain_frost_impact_hero03.vsnd",
                "sounds/weapons/hero/lich/chain_frost_impact_lf.vsnd",
                "sounds/weapons/hero/lich/chain_frost_impact.vsnd",
                "sounds/weapons/hero/lich/chain_frost_impact",
                "weapons/hero/lich/chain_frost_impact",
                "Hero_Lich.ChainFrostImpact",
                "Hero_Lich.ChainFrost.Impact",
                "Hero_Lich.ChainFrost.Target"
            }
        }
    }

    -- Tabela por classificacao: pior posicao recebe chance maior de itens fortes.
    -- FIX72: pools por colocação exata, inspirado na filosofia do Mario Kart 64:
    -- líder recebe mais defesa/fracos; meio recebe ataque moderado; últimos recebem catch-up.
    self.itemPoolsByPlace = {
        [1] = {
            { item = "item_phase_boots", weight = 7 },
            { item = "item_force_staff", weight = 12 },
            { item = "item_blade_mail", weight = 18 },
            { item = "item_kaya", weight = 16 },
            { item = "item_dotakart_natures_grasp", weight = 14 },
            { item = "item_dotakart_bloodlust", weight = 2 },
            { item = "item_shivas_guard", weight = 12 },
            { item = "item_glimmer_cape", weight = 8 },
            { item = "item_basher", weight = 4 },
            { item = "item_cyclone", weight = 3 },
            { item = "item_mage_slayer", weight = 7 },
            { item = "item_dotakart_battle_hunger", weight = 5 },
            { item = "item_dotakart_x_marks", weight = 8 },
            { item = "item_dotakart_doppelwalk", weight = 16 },
            { item = "item_dotakart_crystal_clone", weight = 16 },
            { item = "item_dotakart_shukuchi", weight = 1 },
            { item = "item_dotakart_astral_imprisonment", weight = 8 },
            { item = "item_dotakart_ball_lightning", weight = 1 },
            { item = "item_dotakart_homing_missile", weight = 4 },
            { item = "item_dotakart_plague_ward", weight = 14 },
            { item = "item_dotakart_the_swarm", weight = 3 },
            { item = "item_dotakart_storm_hammer", weight = 2 },
            { item = "item_dotakart_illusory_orb", weight = 3 },
            { item = "item_dotakart_torrent_storm", weight = 8 }
        },
        [2] = {
            { item = "item_phase_boots", weight = 10 },
            { item = "item_yasha", weight = 4 },
            { item = "item_force_staff", weight = 12 },
            { item = "item_blink", weight = 7 },
            { item = "item_blade_mail", weight = 15 },
            { item = "item_kaya", weight = 14 },
            { item = "item_dotakart_natures_grasp", weight = 13 },
            { item = "item_dotakart_bloodlust", weight = 4 },
            { item = "item_dotakart_unstable_concoction", weight = 8 },
            { item = "item_dotakart_spectral_dagger", weight = 11 },
            { item = "item_dotakart_battle_hunger", weight = 6 },
            { item = "item_dotakart_x_marks", weight = 8 },
            { item = "item_dotakart_doppelwalk", weight = 14 },
            { item = "item_dotakart_crystal_clone", weight = 14 },
            { item = "item_dotakart_shukuchi", weight = 2 },
            { item = "item_dotakart_astral_imprisonment", weight = 8 },
            { item = "item_dotakart_ball_lightning", weight = 2 },
            { item = "item_dotakart_homing_missile", weight = 6 },
            { item = "item_dotakart_plague_ward", weight = 13 },
            { item = "item_dotakart_the_swarm", weight = 5 },
            { item = "item_dotakart_storm_hammer", weight = 4 },
            { item = "item_dotakart_illusory_orb", weight = 5 },
            { item = "item_dotakart_torrent_storm", weight = 8 },
            { item = "item_orb_of_venom", weight = 9 },
            { item = "item_shivas_guard", weight = 11 },
            { item = "item_basher", weight = 6 },
            { item = "item_cyclone", weight = 6 },
            { item = "item_mage_slayer", weight = 9 },
            { item = "item_spell_steal", weight = 5 },
            { item = "item_black_king_bar", weight = 3 }
        },
        [3] = {
            { item = "item_phase_boots", weight = 12 },
            { item = "item_yasha", weight = 9 },
            { item = "item_mask_of_madness", weight = 4 },
            { item = "item_force_staff", weight = 12 },
            { item = "item_blink", weight = 10 },
            { item = "item_hurricane_pike", weight = 8 },
            { item = "item_gungir", weight = 8 },
            { item = "item_cyclone", weight = 9 },
            { item = "item_orb_of_venom", weight = 10 },
            { item = "item_blade_mail", weight = 11 },
            { item = "item_dotakart_burrowstrike", weight = 8 },
            { item = "item_dotakart_natures_grasp", weight = 10 },
            { item = "item_dotakart_bloodlust", weight = 6 },
            { item = "item_dotakart_unstable_concoction", weight = 9 },
            { item = "item_dotakart_spectral_dagger", weight = 12 },
            { item = "item_dotakart_battle_hunger", weight = 7 },
            { item = "item_dotakart_x_marks", weight = 8 },
            { item = "item_dotakart_doppelwalk", weight = 12 },
            { item = "item_dotakart_crystal_clone", weight = 12 },
            { item = "item_dotakart_shukuchi", weight = 4 },
            { item = "item_dotakart_astral_imprisonment", weight = 8 },
            { item = "item_dotakart_ball_lightning", weight = 4 },
            { item = "item_dotakart_homing_missile", weight = 9 },
            { item = "item_dotakart_plague_ward", weight = 11 },
            { item = "item_dotakart_the_swarm", weight = 7 },
            { item = "item_dotakart_storm_hammer", weight = 6 },
            { item = "item_dotakart_illusory_orb", weight = 7 },
            { item = "item_dotakart_torrent_storm", weight = 8 },
            { item = "item_wind_waker", weight = 7 },
            { item = "item_mage_slayer", weight = 9 },
            { item = "item_spell_steal", weight = 8 },
            { item = "item_basher", weight = 8 },
            { item = "item_black_king_bar", weight = 6 }
        },
        [4] = {
            { item = "item_phase_boots", weight = 12 },
            { item = "item_yasha", weight = 14 },
            { item = "item_mask_of_madness", weight = 9 },
            { item = "item_force_staff", weight = 13 },
            { item = "item_blink", weight = 11 },
            { item = "item_hurricane_pike", weight = 10 },
            { item = "item_gungir", weight = 10 },
            { item = "item_cyclone", weight = 11 },
            { item = "item_orb_of_venom", weight = 11 },
            { item = "item_blade_mail", weight = 11 },
            { item = "item_dotakart_burrowstrike", weight = 10 },
            { item = "item_dotakart_natures_grasp", weight = 10 },
            { item = "item_dotakart_bloodlust", weight = 9 },
            { item = "item_dotakart_unstable_concoction", weight = 10 },
            { item = "item_dotakart_spectral_dagger", weight = 13 },
            { item = "item_dotakart_battle_hunger", weight = 8 },
            { item = "item_dotakart_x_marks", weight = 8 },
            { item = "item_dotakart_doppelwalk", weight = 9 },
            { item = "item_dotakart_crystal_clone", weight = 9 },
            { item = "item_dotakart_shukuchi", weight = 7 },
            { item = "item_dotakart_astral_imprisonment", weight = 8 },
            { item = "item_dotakart_ball_lightning", weight = 7 },
            { item = "item_dotakart_homing_missile", weight = 12 },
            { item = "item_dotakart_plague_ward", weight = 9 },
            { item = "item_dotakart_the_swarm", weight = 10 },
            { item = "item_dotakart_storm_hammer", weight = 9 },
            { item = "item_dotakart_illusory_orb", weight = 9 },
            { item = "item_dotakart_torrent_storm", weight = 8 },
            { item = "item_wind_waker", weight = 9 },
            { item = "item_mage_slayer", weight = 10 },
            { item = "item_spell_steal", weight = 10 },
            { item = "item_basher", weight = 10 },
            { item = "item_shadow_blade", weight = 7 },
            { item = "item_black_king_bar", weight = 8 }
        },
        [5] = {
            { item = "item_phase_boots", weight = 11 },
            { item = "item_yasha", weight = 18 },
            { item = "item_mask_of_madness", weight = 17 },
            { item = "item_force_staff", weight = 13 },
            { item = "item_blink", weight = 12 },
            { item = "item_hurricane_pike", weight = 12 },
            { item = "item_gungir", weight = 12 },
            { item = "item_cyclone", weight = 13 },
            { item = "item_orb_of_venom", weight = 12 },
            { item = "item_blade_mail", weight = 11 },
            { item = "item_dotakart_burrowstrike", weight = 12 },
            { item = "item_dotakart_natures_grasp", weight = 11 },
            { item = "item_dotakart_bloodlust", weight = 12 },
            { item = "item_dotakart_unstable_concoction", weight = 11 },
            { item = "item_dotakart_spectral_dagger", weight = 14 },
            { item = "item_dotakart_battle_hunger", weight = 8 },
            { item = "item_dotakart_x_marks", weight = 8 },
            { item = "item_dotakart_doppelwalk", weight = 7 },
            { item = "item_dotakart_crystal_clone", weight = 7 },
            { item = "item_dotakart_shukuchi", weight = 10 },
            { item = "item_dotakart_astral_imprisonment", weight = 8 },
            { item = "item_dotakart_ball_lightning", weight = 11 },
            { item = "item_dotakart_homing_missile", weight = 12 },
            { item = "item_dotakart_plague_ward", weight = 7 },
            { item = "item_dotakart_the_swarm", weight = 12 },
            { item = "item_dotakart_storm_hammer", weight = 12 },
            { item = "item_dotakart_illusory_orb", weight = 11 },
            { item = "item_dotakart_torrent_storm", weight = 8 },
            { item = "item_wind_waker", weight = 12 },
            { item = "item_mage_slayer", weight = 11 },
            { item = "item_spell_steal", weight = 12 },
            { item = "item_basher", weight = 12 },
            { item = "item_sheepstick", weight = 11 },
            { item = "item_shadow_blade", weight = 10 },
            { item = "item_black_king_bar", weight = 10 }
        },
        [6] = {
            { item = "item_phase_boots", weight = 8 },
            { item = "item_yasha", weight = 19 },
            { item = "item_mask_of_madness", weight = 22 },
            { item = "item_force_staff", weight = 12 },
            { item = "item_blink", weight = 13 },
            { item = "item_hurricane_pike", weight = 13 },
            { item = "item_gungir", weight = 13 },
            { item = "item_cyclone", weight = 15 },
            { item = "item_orb_of_venom", weight = 12 },
            { item = "item_blade_mail", weight = 10 },
            { item = "item_dotakart_burrowstrike", weight = 14 },
            { item = "item_dotakart_natures_grasp", weight = 10 },
            { item = "item_dotakart_bloodlust", weight = 16 },
            { item = "item_dotakart_unstable_concoction", weight = 12 },
            { item = "item_dotakart_spectral_dagger", weight = 15 },
            { item = "item_dotakart_battle_hunger", weight = 8 },
            { item = "item_dotakart_x_marks", weight = 8 },
            { item = "item_dotakart_doppelwalk", weight = 5 },
            { item = "item_dotakart_crystal_clone", weight = 5 },
            { item = "item_dotakart_shukuchi", weight = 13 },
            { item = "item_dotakart_astral_imprisonment", weight = 8 },
            { item = "item_dotakart_ball_lightning", weight = 15 },
            { item = "item_dotakart_homing_missile", weight = 10 },
            { item = "item_dotakart_plague_ward", weight = 5 },
            { item = "item_dotakart_the_swarm", weight = 14 },
            { item = "item_dotakart_storm_hammer", weight = 15 },
            { item = "item_dotakart_illusory_orb", weight = 13 },
            { item = "item_dotakart_torrent_storm", weight = 8 },
            { item = "item_wind_waker", weight = 14 },
            { item = "item_mage_slayer", weight = 10 },
            { item = "item_spell_steal", weight = 14 },
            { item = "item_basher", weight = 13 },
            { item = "item_sheepstick", weight = 14 },
            { item = "item_shadow_blade", weight = 14 },
            { item = "item_black_king_bar", weight = 14 }
        },
        [7] = {
            { item = "item_phase_boots", weight = 6 },
            { item = "item_yasha", weight = 18 },
            { item = "item_mask_of_madness", weight = 26 },
            { item = "item_force_staff", weight = 11 },
            { item = "item_blink", weight = 13 },
            { item = "item_hurricane_pike", weight = 14 },
            { item = "item_gungir", weight = 14 },
            { item = "item_cyclone", weight = 17 },
            { item = "item_orb_of_venom", weight = 11 },
            { item = "item_dotakart_burrowstrike", weight = 15 },
            { item = "item_dotakart_natures_grasp", weight = 9 },
            { item = "item_dotakart_bloodlust", weight = 18 },
            { item = "item_dotakart_unstable_concoction", weight = 13 },
            { item = "item_dotakart_spectral_dagger", weight = 16 },
            { item = "item_dotakart_battle_hunger", weight = 8 },
            { item = "item_dotakart_x_marks", weight = 8 },
            { item = "item_dotakart_doppelwalk", weight = 3 },
            { item = "item_dotakart_crystal_clone", weight = 3 },
            { item = "item_dotakart_shukuchi", weight = 16 },
            { item = "item_dotakart_astral_imprisonment", weight = 8 },
            { item = "item_dotakart_ball_lightning", weight = 19 },
            { item = "item_dotakart_homing_missile", weight = 7 },
            { item = "item_dotakart_plague_ward", weight = 4 },
            { item = "item_dotakart_the_swarm", weight = 15 },
            { item = "item_dotakart_storm_hammer", weight = 17 },
            { item = "item_dotakart_illusory_orb", weight = 14 },
            { item = "item_dotakart_torrent_storm", weight = 8 },
            { item = "item_wind_waker", weight = 16 },
            { item = "item_spell_steal", weight = 15 },
            { item = "item_basher", weight = 14 },
            { item = "item_sheepstick", weight = 17 },
            { item = "item_shadow_blade", weight = 18 },
            { item = "item_black_king_bar", weight = 17 }
        },
        [8] = {
            { item = "item_phase_boots", weight = 4 },
            { item = "item_yasha", weight = 16 },
            { item = "item_mask_of_madness", weight = 30 },
            { item = "item_force_staff", weight = 9 },
            { item = "item_blink", weight = 13 },
            { item = "item_hurricane_pike", weight = 14 },
            { item = "item_gungir", weight = 15 },
            { item = "item_cyclone", weight = 19 },
            { item = "item_dotakart_burrowstrike", weight = 16 },
            { item = "item_dotakart_bloodlust", weight = 20 },
            { item = "item_dotakart_unstable_concoction", weight = 14 },
            { item = "item_dotakart_spectral_dagger", weight = 17 },
            { item = "item_dotakart_battle_hunger", weight = 8 },
            { item = "item_dotakart_x_marks", weight = 8 },
            { item = "item_dotakart_doppelwalk", weight = 2 },
            { item = "item_dotakart_crystal_clone", weight = 2 },
            { item = "item_dotakart_shukuchi", weight = 18 },
            { item = "item_dotakart_astral_imprisonment", weight = 8 },
            { item = "item_dotakart_ball_lightning", weight = 23 },
            { item = "item_dotakart_homing_missile", weight = 5 },
            { item = "item_dotakart_plague_ward", weight = 3 },
            { item = "item_dotakart_the_swarm", weight = 16 },
            { item = "item_dotakart_storm_hammer", weight = 18 },
            { item = "item_dotakart_illusory_orb", weight = 15 },
            { item = "item_dotakart_torrent_storm", weight = 8 },
            { item = "item_wind_waker", weight = 18 },
            { item = "item_spell_steal", weight = 16 },
            { item = "item_basher", weight = 15 },
            { item = "item_sheepstick", weight = 20 },
            { item = "item_shadow_blade", weight = 22 },
            { item = "item_black_king_bar", weight = 22 }
        }
    }

    -- Compatibilidade com comandos/debug antigos.
    self.itemPools = {
        solo = self.itemPoolsByPlace[4],
        front = self.itemPoolsByPlace[1],
        middle = self.itemPoolsByPlace[4],
        back = self.itemPoolsByPlace[8]
    }

    Convars:RegisterCommand("dk_items_start", function()
        self:Start({ force_rebuild = true })
    end, "DotA Kart: inicia/recria caixas de item", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_items_stop", function()
        self:SetEnabled(false)
    end, "DotA Kart: desliga caixas de item", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_items_debug", function()
        self.config.debug = not self.config.debug
        print("[DotaKartItems] debug = " .. tostring(self.config.debug))
    end, "DotA Kart: alterna debug das caixas de item", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_items_respawn", function()
        self:RespawnAllBoxes()
    end, "DotA Kart: respawna todas caixas de item", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_items_scan", function()
        self:Start({ force_rebuild = true, allow_same_targetname = true })
        self:PrintBoxes()
    end, "DotA Kart: reescaneia e lista caixas de item", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_items_nearest", function()
        self:PrintNearestBox(0)
    end, "DotA Kart: mostra distancia da caixa mais perto do player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_items_pickup_nearest", function()
        self:ForcePickupNearest(0)
    end, "DotA Kart: força pegar a caixa mais perto do player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_random_item", function()
        self:GiveRandomItemToPlayer(0, true)
    end, "DotA Kart: da item aleatorio para player 0 baseado na posicao", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_best_item", function()
        self:GiveItemToPlayer(0, "item_black_king_bar", true)
    end, "DotA Kart: da item forte para player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_item_table", function()
        self:PrintItemTable()
    end, "DotA Kart: imprime tabela de itens por colocacao", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_single_nitro", function()
        self:GiveItemToPlayer(0, "item_phase_boots", true)
    end, "DotA Kart: da Single Nitro ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_double_nitro", function()
        self:GiveItemToPlayer(0, "item_yasha", true)
    end, "DotA Kart: da Double/2 Nitros ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_triple_nitro", function()
        self:GiveItemToPlayer(0, "item_mask_of_madness", true)
    end, "DotA Kart: da Triple/3 Nitros ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_star", function()
        self:GiveItemToPlayer(0, "item_black_king_bar", true)
    end, "DotA Kart: da Star/BKB ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_meathook", function()
        self:GiveItemToPlayer(0, "item_force_staff", true)
    end, "DotA Kart: da Meat Hook ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_hookshot", function()
        self:GiveItemToPlayer(0, "item_blink", true)
    end, "DotA Kart: da Hookshot ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_leap", function()
        self:GiveItemToPlayer(0, "item_hurricane_pike", true)
    end, "DotA Kart: da Leap ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_sacred_arrow", function()
        self:GiveItemToPlayer(0, "item_gungir", true)
    end, "DotA Kart: da Sacred Arrow ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_swap_missile", function()
        self:GiveItemToPlayer(0, "item_cyclone", true)
    end, "DotA Kart: da Swap Missile ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_charge_darkness", function()
        self:GiveItemToPlayer(0, "item_shadow_blade", true)
    end, "DotA Kart: da Charge of Darkness ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_cancel_charge", function()
        self:CancelChargeOfDarkness(0, "console")
    end, "DotA Kart: cancela Charge of Darkness do player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_venomous_gale", function()
        self:GiveItemToPlayer(0, "item_orb_of_venom", true)
    end, "DotA Kart: da Venomous Gale ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_power_cogs", function()
        self:GiveItemToPlayer(0, "item_blade_mail", true)
    end, "DotA Kart: da Power Cogs ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_frost_shield", function()
        self:GiveItemToPlayer(0, "item_shivas_guard", true)
    end, "DotA Kart: da Frost Shield ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_chain_frost", function()
        self:GiveItemToPlayer(0, "item_sheepstick", true)
    end, "DotA Kart: da Chain Frost ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_tornado", function()
        self:GiveItemToPlayer(0, "item_wind_waker", true)
    end, "DotA Kart: da Tornado ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_ice_shards", function()
        self:GiveItemToPlayer(0, "item_mage_slayer", true)
    end, "DotA Kart: da Ice Shards ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_item_steal", function()
        self:GiveItemToPlayer(0, "item_spell_steal", true)
    end, "DotA Kart: da Item Steal ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_chaos_bolt", function()
        self:GiveItemToPlayer(0, "item_basher", true)
    end, "DotA Kart: da Chaos Bolt ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_invisibility", function()
        self:GiveItemToPlayer(0, "item_glimmer_cape", true)
    end, "DotA Kart: da Invisibility ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_ice_wall", function()
        self:GiveItemToPlayer(0, "item_kaya", true)
    end, "DotA Kart: da Ice Wall ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_burrowstrike", function()
        self:GiveItemToPlayer(0, "item_dotakart_burrowstrike", true)
    end, "DotA Kart: da Burrowstrike ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_natures_grasp", function()
        self:GiveItemToPlayer(0, "item_dotakart_natures_grasp", true)
    end, "DotA Kart: da Nature's Grasp ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_bloodlust", function()
        self:GiveItemToPlayer(0, "item_dotakart_bloodlust", true)
    end, "DotA Kart: da Bloodlust ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_spectral_dagger", function()
        self:GiveItemToPlayer(0, "item_dotakart_spectral_dagger", true)
    end, "DotA Kart: da Spectral Dagger ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_battle_hunger", function()
        self:GiveItemToPlayer(0, "item_dotakart_battle_hunger", true)
    end, "DotA Kart: da Battle Hunger ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_x_marks", function()
        self:GiveItemToPlayer(0, "item_dotakart_x_marks", true)
    end, "DotA Kart: da X Marks the Spot ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_doppelwalk", function()
        self:GiveItemToPlayer(0, "item_dotakart_doppelwalk", true)
    end, "DotA Kart: da Doppelwalk ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_shukuchi", function()
        self:GiveItemToPlayer(0, "item_dotakart_shukuchi", true)
    end, "DotA Kart: da Shukuchi ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_crystal_clone", function()
        self:GiveItemToPlayer(0, "item_dotakart_crystal_clone", true)
    end, "DotA Kart: da Crystal Clone ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_astral_imprisonment", function()
        self:GiveItemToPlayer(0, "item_dotakart_astral_imprisonment", true)
    end, "DotA Kart: da Astral Imprisonment ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_ball_lightning", function()
        self:GiveItemToPlayer(0, "item_dotakart_ball_lightning", true)
    end, "DotA Kart: da Ball Lightning ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_homing_missile", function()
        self:GiveItemToPlayer(0, "item_dotakart_homing_missile", true)
    end, "DotA Kart: gives Homing Missile to player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_plague_ward", function()
        self:GiveItemToPlayer(0, "item_dotakart_plague_ward", true)
    end, "DotA Kart: da Plague Ward ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_the_swarm", function()
        self:GiveItemToPlayer(0, "item_dotakart_the_swarm", true)
    end, "DotA Kart: da The Swarm ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_storm_hammer", function()
        self:GiveItemToPlayer(0, "item_dotakart_storm_hammer", true)
    end, "DotA Kart: da Storm Hammer ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_illusory_orb", function()
        self:GiveItemToPlayer(0, "item_dotakart_illusory_orb", true)
    end, "DotA Kart: da Illusory Orb ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_torrent_storm", function()
        self:GiveItemToPlayer(0, "item_dotakart_torrent_storm", true)
    end, "DotA Kart: da Torrent Storm ao player 0", FCVAR_CHEAT)


    Convars:RegisterCommand("dk_give_unstable_concoction", function()
        self:GiveItemToPlayer(0, "item_dotakart_unstable_concoction", true)
    end, "DotA Kart: da Unstable Concoction ao player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_test_stun_self", function()
        local hero = self:GetHeroForPlayer(0)
        if DKValidUnit(hero) then
            self:ApplyKartStun(hero, hero, 2.0)
            print("[DotaKartItems] FIX26 teste de stun no player 0 por 2s")
        end
    end, "DotA Kart: testa stun Mario Kart no player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_test_item_sounds", function()
        local hero = self:GetHeroForPlayer(0)
        if DKValidUnit(hero) then
            self:EmitKartSound(hero, { "DOTA_Item.BlackKingBar.Activate", "Hero_Pudge.AttackHookExtend", "Hero_Rattletrap.Hookshot.Fire", "sounds/weapons/hero/rattletrap/jetpack_cast.vsnd" })
            print("[DotaKartItems] Teste de sons executado no player 0")
        else
            print("[DotaKartItems] Sem hero para testar sons")
        end
    end, "DotA Kart: testa sons dos itens no player 0", FCVAR_CHEAT)


    Convars:RegisterCommand("dk_test_custom_assets", function()
        local hero = self:GetHeroForPlayer(0)
        if DKValidUnit(hero) then
            -- FIX103: teste os SOUND EVENTS que referenciam os raw .vsnd sem _c.
            -- EmitSound/Game.EmitSound devem receber o nome do soundevent; o raw .vsnd fica dentro do .vsndevts.
            local tests = {
                "dotakart_announcer_place_01",
                "vo_announcer_ann_custom_place_01",
                "dotakart_announcer_place_02",
                "vo_announcer_ann_custom_place_02",
                "dotakart_engine_idle",
                "engine_idle",
                "dotakart_spectral_dagger_cast",
                "dotakart_spectral_dagger_impact",
            }
            for _, snd in ipairs(tests) do
                self:TryEmitUISoundServer(hero, snd)
                self:SendUISoundToPlayer(0, snd, "play", 0)
            end
            print("[DotaKartItems] FIX103 dk_test_custom_assets: testando soundevents KV3 que apontam para raw .vsnd sem _c.")
        else
            print("[DotaKartItems] dk_test_custom_assets: sem hero player 0")
        end
    end, "DotA Kart: testa raw .vsnd custom e soundevents", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_test_roulette_sounds", function()
        local hero = self:GetHeroForPlayer(0)
        self:TryEmitUISoundServer(hero, "sounds/ui/economy/rylais_wheel_spin_02_lp.vsnd")
        self:SendUISoundToPlayer(0, "sounds/ui/economy/rylais_wheel_spin_02_lp.vsnd", "start_loop", 2.5)
        GameRules:GetGameModeEntity():SetContextThink("DKTestRouletteDoneSound", function()
            self:TryStopUISoundServer(hero, "sounds/ui/economy/rylais_wheel_spin_02_lp.vsnd")
            self:TryEmitUISoundServer(hero, "sounds/ui/treasure_01.vsnd")
            self:SendUISoundToPlayer(0, "sounds/ui/treasure_01.vsnd", "play", 0)
            return nil
        end, 2.5)
        print("[DotaKartItems] FIX27 testando sons da roleta/caixa no player 0")
    end, "DotA Kart: testa sons da roleta da caixa", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_test_item_vfx", function()
        local hero = self:GetHeroForPlayer(0)
        if DKValidUnit(hero) then
            local pos = hero:GetAbsOrigin() + Vector(0,0,96)
            self:CreateWorldParticle("particles/items_fx/black_king_bar_overhead_sphere.vpcf", pos, 1.5)
            self:CreateProjectileParticles({
                "particles/units/heroes/hero_pudge/pudge_meathook_chain.vpcf",
                "particles/units/heroes/hero_pudge/pudge_meathook_chain_secondarychain.vpcf",
                "particles/units/heroes/hero_pudge/pudge_meathook_hook.vpcf"
            }, pos, pos + Vector(700,0,0))
            self:CreateLinearParticle("particles/units/heroes/hero_rattletrap/rattletrap_hookshot.vpcf", pos, pos + Vector(0,700,0))
            self:CreateLinearParticle("particles/econ/items/mirana/mirana_crescent_arrow/mirana_spell_crescent_arrow.vpcf", pos, pos + Vector(-700,0,0))
            self:CreateDirectionalParticle("particles/units/heroes/hero_vengeful/vengeful_magic_missle.vpcf", pos, Vector(1,1,0), 1700)
            self:CreateDirectionalParticle("particles/units/heroes/hero_venomancer/venomancer_venomous_gale.vpcf", pos, Vector(1,0,0), 1500)
            self:CreateMissileParticle("particles/units/heroes/hero_invoker/invoker_tornado.vpcf", pos, Vector(1,0,0), 1800, 520)
            self:CreateMissileParticle("particles/units/heroes/hero_tusk/tusk_ice_shards_projectile.vpcf", pos, Vector(1,0,0), 1500, 420)
            print("[DotaKartItems] Teste de VFX executado no player 0")
        else
            print("[DotaKartItems] Sem hero para testar VFX")
        end
    end, "DotA Kart: testa particles dos itens no player 0", FCVAR_CHEAT)

    self:StartThink()
    print("[DotaKartItems] Sistema de itens iniciado FIX54")
end

function DotaKartItemSystem:SetEnabled(enabled)
    self.enabled = enabled == true
    print("[DotaKartItems] enabled = " .. tostring(self.enabled))
end

function DotaKartItemSystem:StartThink()
    if self._thinkStarted then return end
    self._thinkStarted = true
    self._lastThinkTime = DKNow()
    GameRules:GetGameModeEntity():SetContextThink("DotaKartItemSystemThink", function()
        return self:OnThink()
    end, self.config.tick_rate)
end

function DotaKartItemSystem:Start(options)
    options = options or {}
    for k, v in pairs(options) do
        if self.config[k] ~= nil then self.config[k] = v end
    end

    if options.force_rebuild == true or #self.boxes <= 0 then
        self:BuildBoxesFromEntities(self.config.prefix, self.config.max_points)
        if #self.boxes <= 0 and self.config.auto_create_from_track then
            self:BuildBoxesFromTrack()
        end
    end

    self:RespawnAllBoxes()
    self:SetEnabled(true)

    print("[DotaKartItems] Caixas ativas: " .. tostring(#self.boxes))
    if self.config.debug then self:PrintBoxes() end
    if #self.boxes <= 0 then
        print("[DotaKartItems] AVISO: nenhuma caixa encontrada. Crie info_target/prop_dynamic no Hammer: dk_itembox_001, dk_itembox_002...")
    end
end

function DotaKartItemSystem:MakeNameCandidates(prefix, i)
    prefix = prefix or "dk_itembox_"
    local prefixes = { prefix }
    if string.sub(prefix, -1) == "_" then
        table.insert(prefixes, string.sub(prefix, 1, -2))
    else
        table.insert(prefixes, prefix .. "_")
    end

    local nums = {
        string.format("%04d", i),
        string.format("%03d", i),
        string.format("%02d", i),
        tostring(i)
    }

    local names = {}
    for _, pfx in ipairs(prefixes) do
        for _, num in ipairs(nums) do
            table.insert(names, pfx .. num)
        end
    end
    return names
end

function DotaKartItemSystem:FindPointEntity(prefix, i)
    local names = self:MakeNameCandidates(prefix, i)
    for _, name in ipairs(names) do
        local ent = Entities:FindByName(nil, name)
        if ent ~= nil then return ent, name end
    end
    return nil, nil
end

function DotaKartItemSystem:GetEntityIndexSafe(ent)
    if ent == nil then return nil end
    if ent.GetEntityIndex ~= nil then
        local ok, idx = pcall(function() return ent:GetEntityIndex() end)
        if ok then return tonumber(idx) end
    end
    if ent.entindex ~= nil then
        local ok, idx = pcall(function() return ent:entindex() end)
        if ok then return tonumber(idx) end
    end
    return nil
end

function DotaKartItemSystem:FindAllByName(name)
    local result = {}
    local cursor = nil
    local guard = 0

    while true do
        cursor = Entities:FindByName(cursor, name)
        if cursor == nil then break end
        table.insert(result, cursor)
        guard = guard + 1
        if guard > 2048 then break end
    end

    return result
end

function DotaKartItemSystem:LooksLikeRenderableCrate(ent)
    if ent == nil then return false end

    -- Prop_dynamic colocado no Hammer deve ser tratado como a própria caixa.
    local okClass, cls = pcall(function() return ent:GetClassname() end)
    if okClass and cls ~= nil then
        cls = tostring(cls)
        if cls == "prop_dynamic" or cls == "prop_physics" or cls == "prop_dynamic_override" then
            return true
        end
    end

    local ok, model = pcall(function() return ent:GetModelName() end)
    if not ok or model == nil or model == "" then return false end
    return true
end

function DotaKartItemSystem:SpawnCrateProp(name, pos, yaw)
    if SpawnEntityFromTableSynchronous == nil then return nil end

    local ent = SpawnEntityFromTableSynchronous("prop_dynamic", {
        targetname = name,
        model = self.config.model,
        DefaultAnim = self.config.idle_anim,
        solid = "0"
    })

    if ent ~= nil then
        ent:SetAbsOrigin(pos)
        if ent.SetAngles ~= nil then ent:SetAngles(0, yaw or 0, 0) end
        self:PlayAnimation(ent, self.config.idle_anim)
    end

    return ent
end

function DotaKartItemSystem:AddBox(name, sourceEnt, pos, yaw)
    if name == nil or pos == nil then return nil end

    local entIndex = self:GetEntityIndexSafe(sourceEnt)
    local uniqueName = tostring(name)
    if entIndex ~= nil then
        uniqueName = uniqueName .. "_ent" .. tostring(entIndex)
    end

    -- Hammer permite várias entidades com o mesmo Name/targetname.
    -- Internamente precisamos de chave única para não descartar as duplicadas.
    if self.boxByName[uniqueName] ~= nil then
        local suffix = 2
        while self.boxByName[uniqueName .. "_" .. tostring(suffix)] ~= nil do
            suffix = suffix + 1
        end
        uniqueName = uniqueName .. "_" .. tostring(suffix)
    end

    local sourceRenderable = self:LooksLikeRenderableCrate(sourceEnt)
    local visualEnt = sourceEnt
    local visualPos = Vector(pos.x, pos.y, pos.z)

    if sourceRenderable then
        -- Se a caixa já é prop_dynamic no Hammer, respeita exatamente a posição dela.
        visualPos = Vector(pos.x, pos.y, pos.z)
    else
        -- Se for info_target, cria o modelo um pouco acima do chão.
        visualPos = Vector(pos.x, pos.y, pos.z + self.config.spawn_z_offset)
        visualEnt = self:SpawnCrateProp(uniqueName .. "_prop", visualPos, yaw or 0)
    end

    local box = {
        name = uniqueName,
        targetname = tostring(name),
        source = sourceEnt,
        ent = visualEnt,
        -- FIX107: salva a posição original colocada no Hammer/gerada no start.
        -- Mesmo que Hook/Burrow/itens movam a caixa no gameplay, o respawn volta exatamente
        -- para esse ponto inicial.
        pos = Vector(visualPos.x, visualPos.y, visualPos.z),
        initial_pos = Vector(visualPos.x, visualPos.y, visualPos.z),
        ground_pos = Vector(pos.x, pos.y, pos.z),
        initial_ground_pos = Vector(pos.x, pos.y, pos.z),
        yaw = yaw or 0,
        initial_yaw = yaw or 0,
        active = true,
        respawn_time = 0,
        last_pickup_time = -9999
    }

    if DKValidUnit(visualEnt) then
        visualEnt:SetAbsOrigin(box.pos)
        if visualEnt.SetAngles ~= nil then visualEnt:SetAngles(0, yaw or 0, 0) end
        self:PlayAnimation(visualEnt, self.config.idle_anim)
    end

    table.insert(self.boxes, box)
    self.boxByName[uniqueName] = box

    if self.config.debug then
        print("[DotaKartItems] caixa registrada: " .. tostring(uniqueName) .. " targetname=" .. tostring(name) .. " pos=" .. tostring(math.floor(pos.x)) .. "," .. tostring(math.floor(pos.y)))
    end

    return box
end

function DotaKartItemSystem:BuildBoxesFromEntities(prefix, maxPoints)
    self.boxes = {}
    self.boxByName = {}

    prefix = prefix or "dk_itembox_"
    maxPoints = maxPoints or 512

    local foundAny = false
    local missingAfterLastFound = 0
    local seen = {}

    for i = 1, maxPoints do
        local names = self:MakeNameCandidates(prefix, i)
        local foundThisIndex = false

        for _, name in ipairs(names) do
            local ents = self:FindAllByName(name)
            if ents ~= nil and #ents > 0 then
                for _, ent in ipairs(ents) do
                    local idx = self:GetEntityIndexSafe(ent)
                    local key = tostring(idx or tostring(ent))
                    if not seen[key] then
                        seen[key] = true
                        foundAny = true
                        foundThisIndex = true

                        local pos = ent:GetAbsOrigin()
                        local yaw = 0
                        local ok, angles = pcall(function() return ent:GetAnglesAsVector() end)
                        if ok and angles ~= nil then yaw = angles.y or 0 end

                        self:AddBox(name, ent, pos, yaw)
                    end
                end
            end
        end

        if foundThisIndex then
            missingAfterLastFound = 0
        elseif foundAny then
            missingAfterLastFound = missingAfterLastFound + 1
            if missingAfterLastFound >= 16 then break end
        end
    end

    if self.config.debug then
        print("[DotaKartItems] Caixas encontradas no Hammer: " .. tostring(#self.boxes) .. " | prefix=" .. tostring(prefix) .. " | suporta targetname duplicado")
    end
end

function DotaKartItemSystem:BuildBoxesFromTrack()
    if self.hud == nil or self.hud.trackWorldPoints == nil or #self.hud.trackWorldPoints < 4 then
        return
    end

    local points = self.hud.trackWorldPoints
    local every = math.max(1, tonumber(self.config.auto_every_track_points) or 4)
    local startIndex = math.max(1, tonumber(self.config.auto_start_index) or 3)
    local created = 0

    for i = startIndex, #points - 1, every do
        local p = points[i]
        local nextP = points[i + 1] or points[i]
        local yaw = DKNormalizeYaw(math.deg(DKAtan2(nextP.y - p.y, nextP.x - p.x)))
        local pos = Vector(p.x, p.y, GetGroundHeight(p, nil))
        created = created + 1
        self:AddBox("dk_itembox_auto_" .. string.format("%03d", created), nil, pos, yaw)
    end

    print("[DotaKartItems] Auto caixas criadas nos dk_track: " .. tostring(created))
end

function DotaKartItemSystem:PlayAnimation(ent, anim)
    if ent == nil or anim == nil or anim == "" then return end

    pcall(function()
        DoEntFireByInstanceHandle(ent, "SetAnimation", anim, 0, nil, nil)
    end)
    pcall(function()
        DoEntFireByInstanceHandle(ent, "SetDefaultAnimation", anim, 0, nil, nil)
    end)
    DKSafeCall(ent, "ResetSequence", anim)
    DKSafeCall(ent, "SetSequence", anim)
    DKSafeCall(ent, "SetPlaybackRate", 1.0)
end

function DotaKartItemSystem:SetBoxVisible(box, visible)
    if box == nil or box.ent == nil then return end

    if visible then
        pcall(function() box.ent:RemoveNoDraw() end)
        pcall(function() box.ent:RemoveEffects(DK_EF_NODRAW) end)
        local respawnPos = box.initial_pos or box.pos
        if respawnPos ~= nil then
            box.pos = Vector(respawnPos.x, respawnPos.y, respawnPos.z)
            box.ent:SetAbsOrigin(box.pos)
        end
        if box.ent.SetAngles ~= nil then pcall(function() box.ent:SetAngles(0, box.initial_yaw or box.yaw or 0, 0) end) end
        self:PlayAnimation(box.ent, self.config.idle_anim)
    else
        pcall(function() box.ent:AddNoDraw() end)
        pcall(function() box.ent:AddEffects(DK_EF_NODRAW) end)
        -- Fallback visual caso AddNoDraw não exista para esse tipo de entidade.
        pcall(function() box.ent:SetAbsOrigin(box.pos + Vector(0, 0, -10000)) end)
    end
end

function DotaKartItemSystem:BreakBox(box)
    if box == nil or not box.active then return end

    box.active = false
    box.being_pulled = false
    box.respawn_time = DKNow() + self.config.respawn_time

    local anims = self.config.break_anims or {}
    if box.ent ~= nil and #anims > 0 then
        local anim = anims[DKRandomInt(1, #anims)]
        self:PlayAnimation(box.ent, anim)
    end

    local hideDelay = self.config.hide_delay or 0.35
    GameRules:GetGameModeEntity():SetContextThink("DotaKartHideBox_" .. box.name .. "_" .. tostring(math.floor(DKNow() * 1000)), function()
        self:SetBoxVisible(box, false)
        return nil
    end, hideDelay)
end

function DotaKartItemSystem:RespawnBox(box)
    if box == nil then return end
    box.active = true
    box.being_pulled = false
    box.respawn_time = 0
    -- FIX107: respawn sempre na posição inicial salva ao registrar a caixa.
    if box.initial_pos ~= nil then
        box.pos = Vector(box.initial_pos.x, box.initial_pos.y, box.initial_pos.z)
    end
    if box.initial_ground_pos ~= nil then
        box.ground_pos = Vector(box.initial_ground_pos.x, box.initial_ground_pos.y, box.initial_ground_pos.z)
    end
    box.yaw = box.initial_yaw or box.yaw or 0
    self:SetBoxVisible(box, true)
end

function DotaKartItemSystem:RespawnAllBoxes()
    for _, box in ipairs(self.boxes) do
        self:RespawnBox(box)
    end
    print("[DotaKartItems] Todas caixas respawnadas.")
end

function DotaKartItemSystem:GetRegisteredPlayerIDs()
    local set = {}

    if self.hud ~= nil and self.hud.racers ~= nil then
        for playerID, _ in pairs(self.hud.racers) do
            if tonumber(playerID) ~= nil then set[tonumber(playerID)] = true end
        end
    end

    if self.controller ~= nil and self.controller.heroes ~= nil then
        for playerID, hero in pairs(self.controller.heroes) do
            if tonumber(playerID) ~= nil and DKValidUnit(hero) then set[tonumber(playerID)] = true end
        end
    end

    for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(playerID) then set[playerID] = true end
    end

    local ids = {}
    for playerID, _ in pairs(set) do
        table.insert(ids, playerID)
    end
    table.sort(ids)
    return ids
end

function DotaKartItemSystem:GetRacerInfo(playerID)
    if self.hud ~= nil and self.hud.racers ~= nil then
        return self.hud.racers[playerID]
    end
    return nil
end

function DotaKartItemSystem:GetRacerCount()
    local ids = self:GetRegisteredPlayerIDs()
    if #ids > 0 then return #ids end
    return 1
end

function DotaKartItemSystem:GetPlaceForPlayer(playerID)
    local racer = self:GetRacerInfo(playerID)
    if racer ~= nil and racer.place ~= nil then return tonumber(racer.place) or 1 end
    return 1
end

function DotaKartItemSystem:GetPoolNameForPlayer(playerID)
    local count = self:GetRacerCount()
    if count <= 1 then return "solo" end

    local place = self:GetPlaceForPlayer(playerID)
    local ratio = place / math.max(1, count)

    if place <= 1 then return "front" end
    if ratio >= 0.67 then return "back" end
    return "middle"
end

function DotaKartItemSystem:WeightedChoice(pool)
    if pool == nil or #pool <= 0 then return "item_phase_boots" end

    local total = 0
    for _, entry in ipairs(pool) do
        total = total + math.max(0, tonumber(entry.weight) or 0)
    end

    if total <= 0 then return pool[1].item end

    local roll = DKRandomInt(1, total)
    local acc = 0
    for _, entry in ipairs(pool) do
        acc = acc + math.max(0, tonumber(entry.weight) or 0)
        if roll <= acc then return entry.item end
    end

    return pool[#pool].item
end

function DotaKartItemSystem:GetItemPoolForPlayer(playerID)
    local place = math.floor(tonumber(self:GetPlaceForPlayer(playerID)) or 1)
    if place < 1 then place = 1 end
    if place > 8 then place = 8 end
    local pool = self.itemPoolsByPlace and self.itemPoolsByPlace[place]
    if pool ~= nil and #pool > 0 then return pool, ("place_" .. tostring(place)) end
    local poolName = self:GetPoolNameForPlayer(playerID)
    pool = self.itemPools and self.itemPools[poolName] or nil
    if pool ~= nil and #pool > 0 then return pool, poolName end
    return self.itemPools.solo, "solo"
end

function DotaKartItemSystem:RollItemForPlayer(playerID)
    local pool, poolName = self:GetItemPoolForPlayer(playerID)
    local place = self:GetPlaceForPlayer(playerID)

    -- FIX72: regra forte de líder. Primeiro colocado nunca recebe BKB/Star, 2/3 Nitros ou Charge.
    for _ = 1, 24 do
        local itemName = self:WeightedChoice(pool)
        local def = self.itemDefs[itemName or ""]
        if not (place <= 1 and def ~= nil and def.forbidden_first_place == true) then
            return itemName, poolName
        end
    end

    return "item_phase_boots", poolName
end

function DotaKartItemSystem:GetHeldItem(playerID)
    if self.controller ~= nil and self.controller.heldItems ~= nil then
        return self.controller.heldItems[playerID] or ""
    end
    return ""
end

function DotaKartItemSystem:PlayerCanReceiveItem(playerID)
    if self.rolling[playerID] ~= nil then return false end
    if self.config.allow_pickup_when_holding_item then return true end
    local held = self:GetHeldItem(playerID)
    return held == nil or held == ""
end

function DotaKartItemSystem:GetItemChargeCount(playerID, itemName)
    local def = self.itemDefs[itemName or ""]
    local defaultCharges = tonumber(def and def.charges or 0) or 0
    local charges = tonumber(self.itemCharges[playerID] or defaultCharges) or 0
    if itemName == nil or itemName == "" then return 0 end
    if charges <= 1 then return 0 end
    return charges
end

function DotaKartItemSystem:SetHeldItemHUD(playerID, itemName, charges)
    itemName = itemName or ""
    charges = tonumber(charges or 0) or 0

    if self.controller ~= nil and self.controller.SetHeldItem ~= nil then
        self.controller:SetHeldItem(playerID, itemName, charges)
    elseif self.hud ~= nil and self.hud.SetRacerItem ~= nil then
        self.hud:SetRacerItem(playerID, itemName, charges)
    end
end

function DotaKartItemSystem:GiveItemToPlayer(playerID, itemName, force)
    if playerID == nil or playerID < 0 then return false end
    if itemName == nil or itemName == "" then return false end
    if not force and not self:PlayerCanReceiveItem(playerID) then return false end

    local def = self.itemDefs[itemName]
    self.itemCharges[playerID] = nil
    if def ~= nil and def.charges ~= nil and tonumber(def.charges) ~= nil and tonumber(def.charges) > 1 then
        self.itemCharges[playerID] = tonumber(def.charges)
    end

    self:SetHeldItemHUD(playerID, itemName, self:GetItemChargeCount(playerID, itemName))

    local label = def and def.label or itemName
    local charges = self:GetItemChargeCount(playerID, itemName)
    local chargeText = charges > 1 and (" x" .. tostring(charges)) or ""
    print("[DotaKartItems] Player " .. tostring(playerID) .. " recebeu item: " .. tostring(label) .. chargeText .. " (" .. tostring(itemName) .. ")")
    return true
end

function DotaKartItemSystem:GiveRandomItemToPlayer(playerID, force)
    local itemName, poolName = self:RollItemForPlayer(playerID)
    local ok = self:GiveItemToPlayer(playerID, itemName, force)
    if ok and self.config.debug then
        print("[DotaKartItems] Pool " .. tostring(poolName) .. " usado para player " .. tostring(playerID) .. " place=" .. tostring(self:GetPlaceForPlayer(playerID)) .. "/" .. tostring(self:GetRacerCount()))
    end
    return ok, itemName
end

function DotaKartItemSystem:IsRealPlayerWithClient(playerID)
    playerID = tonumber(playerID)
    if playerID == nil or playerID < 0 then return false end
    if PlayerResource == nil or PlayerResource.GetPlayer == nil then return false end
    local player = PlayerResource:GetPlayer(playerID)
    return player ~= nil
end

function DotaKartItemSystem:PulseRouletteSpinSoundServer(hero)
    if not DKValidUnit(hero) then return end
    -- FIX114: o WAV custom não está se repetindo sozinho. Enquanto a roleta está
    -- ativa fazemos tentativas frequentes de reemitir o MESMO soundevent. O evento
    -- possui instance_limit=1 + block_matching_entity, então não empilha enquanto
    -- uma instância ainda está tocando; assim que termina, a próxima tentativa reinicia.
    pcall(function() EmitSoundOn("dotakart_itembox_spin_loop", hero) end)
end

function DotaKartItemSystem:StartRouletteSpinSoundServer(playerID, hero)
    if not DKValidUnit(hero) then return end
    pcall(function() StopSoundOn("dotakart_itembox_spin_loop", hero) end)
    if StopSoundEvent ~= nil then
        pcall(function() StopSoundEvent("dotakart_itembox_spin_loop", hero) end)
    end
    self:PulseRouletteSpinSoundServer(hero)
end

function DotaKartItemSystem:StopRouletteSpinSoundServer(hero)
    if not DKValidUnit(hero) then return end
    pcall(function() StopSoundOn("dotakart_itembox_spin_loop", hero) end)
    if StopSoundEvent ~= nil then
        pcall(function() StopSoundEvent("dotakart_itembox_spin_loop", hero) end)
    end
end

function DotaKartItemSystem:StartRoulette(playerID)
    if not self:PlayerCanReceiveItem(playerID) then return end

    -- FIX27: AutoBots criados por script não têm cliente Panorama.
    -- Eles recebem item silenciosamente para não disparar a roleta/caixa no HUD do jogador humano.
    if not self:IsRealPlayerWithClient(playerID) then
        self:GiveRandomItemToPlayer(playerID, true)
        if self.config.debug then
            print("[DotaKartItems] Bot/player sem cliente pegou caixa; item entregue sem roleta UI. player=" .. tostring(playerID))
        end
        return
    end

    if not self.config.roulette_enabled then
        self:GiveRandomItemToPlayer(playerID, false)
        return
    end

    local now = DKNow()
    local finalItem, poolName = self:RollItemForPlayer(playerID)
    local hero = self:GetHeroForPlayer(playerID)
    self.rolling[playerID] = {
        final_item = finalItem,
        pool_name = poolName,
        end_time = now + (self.config.roulette_duration or 2.5),
        next_tick = 0,
        next_spin_sound = now + 0.20,
        sound_hero = hero,
        ui_started = true
    }

    -- FIX26/FIX113: a roleta gira por ~2.5s. O custom loop é iniciado
    -- também no servidor porque o evento Panorama do FIX112 não tocava o asset.
    self:StartRouletteSpinSoundServer(playerID, hero)
    self:SendRouletteEventToPlayer(playerID, "start", finalItem, self.config.roulette_duration or 2.5)

    if self.config.debug then
        print("[DotaKartItems] FIX27 Roulette player " .. tostring(playerID) .. " pool=" .. tostring(poolName) .. " final=" .. tostring(finalItem) .. " duration=" .. tostring(self.config.roulette_duration))
    end
end

function DotaKartItemSystem:UpdateRoulette(playerID, roll, now)
    if roll == nil then return end

    if now >= roll.end_time then
        self.rolling[playerID] = nil
        local hero = roll.sound_hero or self:GetHeroForPlayer(playerID)
        -- FIX113: o novo loop custom é um soundevent real e deve ser encerrado
        -- exatamente quando a escolha final é revelada.
        self:StopRouletteSpinSoundServer(hero)
        self:GiveItemToPlayer(playerID, roll.final_item, true)
        self:SendRouletteEventToPlayer(playerID, "done", roll.final_item, 0)
        -- FIX51: som de item escolhido toca apenas no cliente desse jogador via dotakart_roulette_fx.
        -- Não toca EmitGlobalSound/EmitKartSound aqui para evitar todos ouvirem na partida.
        return
    end

    if now >= (roll.next_spin_sound or 0) then
        self:PulseRouletteSpinSoundServer(roll.sound_hero or self:GetHeroForPlayer(playerID))
        roll.next_spin_sound = now + 0.20
    end

    if now >= (roll.next_tick or 0) then
        roll.next_tick = now + self.config.roulette_step
        local pool = nil
        pool, _ = self:GetItemPoolForPlayer(playerID)
        local fakeItem = self:WeightedChoice(pool)
        if self.controller ~= nil and self.controller.SetHeldItem ~= nil then
            self.controller:SetHeldItem(playerID, fakeItem, 0)
        elseif self.hud ~= nil and self.hud.SetRacerItem ~= nil then
            self.hud:SetRacerItem(playerID, fakeItem, 0)
        end
    end
end

function DotaKartItemSystem:OnPickupBox(playerID, hero, box)
    if box == nil or not box.active then return end
    if not self:PlayerCanReceiveItem(playerID) then return end

    box.last_pickup_time = DKNow()
    -- FIX112: som custom 3D exatamente no ponto da caixa no instante da colisão.
    self:EmitKartWorldSound(hero, self.config.item_box_break_sound, box.pos or hero:GetAbsOrigin())
    self:BreakBox(box)
    self:StartRoulette(playerID)

    if self.config.debug then
        print("[DotaKartItems] Player " .. tostring(playerID) .. " pegou caixa " .. tostring(box.name))
    end
end

function DotaKartItemSystem:GetHeroForPlayer(playerID)
    if self.controller ~= nil and self.controller.GetHeroForPlayer ~= nil then
        local hero = self.controller:GetHeroForPlayer(playerID)
        if DKValidUnit(hero) then return hero end
    end
    if PlayerResource:IsValidPlayerID(playerID) then
        local hero = PlayerResource:GetSelectedHeroEntity(playerID)
        if DKValidUnit(hero) then return hero end
    end
    return nil
end

function DotaKartItemSystem:CheckPickupCollisions(now)
    local radius = tonumber(self.config.pickup_radius) or 185

    for _, playerID in ipairs(self:GetRegisteredPlayerIDs()) do
        local hero = self:GetHeroForPlayer(playerID)
        if DKValidUnit(hero) and self:PlayerCanReceiveItem(playerID) then
            local pos = hero:GetAbsOrigin()
            for _, box in ipairs(self.boxes) do
                if box.active and not box.being_pulled and box.pos ~= nil then
                    if DKLength2D(pos, box.pos) <= radius then
                        self:OnPickupBox(playerID, hero, box)
                        break
                    end
                end
            end
        end
    end
end

function DotaKartItemSystem:NormalizeSoundList(soundDef)
    local out = {}
    if soundDef == nil then return out end
    if type(soundDef) == "table" then
        for _, s in ipairs(soundDef) do
            if s ~= nil and s ~= "" then table.insert(out, tostring(s)) end
        end
    elseif soundDef ~= "" then
        table.insert(out, tostring(soundDef))
    end
    return out
end

function DotaKartItemSystem:EmitKartSound(hero, soundDef, pos)
    local sounds = self:NormalizeSoundList(soundDef)
    if #sounds <= 0 then return end

    local origin = pos
    if origin == nil and DKValidUnit(hero) then origin = hero:GetAbsOrigin() end

    for _, soundName in ipairs(sounds) do
        -- EmitSoundOn toca para jogadores próximos quando o som está preso ao herói/kart.
        if DKValidUnit(hero) then
            pcall(function() EmitSoundOn(soundName, hero) end)
            pcall(function() StartSoundEvent(soundName, hero) end)
        end

        -- Fallback para sons raw .vsnd ou quando o som precisa sair de uma posição.
        if origin ~= nil then
            pcall(function() EmitSoundOnLocationWithCaster(origin, soundName, hero) end)
            if StartSoundEventFromPosition ~= nil then
                pcall(function() StartSoundEventFromPosition(soundName, origin) end)
            end
        end
    end
end

function DotaKartItemSystem:EmitKartWorldSound(caster, soundDef, pos)
    local sounds = self:NormalizeSoundList(soundDef)
    if #sounds <= 0 or pos == nil then return end

    for _, soundName in ipairs(sounds) do
        local played = false
        if EmitSoundOnLocationWithCaster ~= nil then
            local ok = pcall(function() EmitSoundOnLocationWithCaster(pos, soundName, caster) end)
            played = ok == true
        end
        if not played and StartSoundEventFromPosition ~= nil then
            pcall(function() StartSoundEventFromPosition(soundName, pos) end)
        end
    end
end

function DotaKartItemSystem:StopKartSound(hero, soundDef)
    if hero == nil or hero:IsNull() then return end
    local sounds = self:NormalizeSoundList(soundDef)
    for _, soundName in ipairs(sounds) do
        if soundName ~= nil and soundName ~= "" then
            pcall(function() StopSoundOn(soundName, hero) end)
            if StopSoundEvent ~= nil then
                pcall(function() StopSoundEvent(soundName, hero) end)
            end
        end
    end
end

function DotaKartItemSystem:CreateWorldParticle(particleName, pos, duration)
    if particleName == nil or particleName == "" or ParticleManager == nil or pos == nil then return nil end
    local fx = nil
    local ok = pcall(function()
        fx = ParticleManager:CreateParticle(particleName, PATTACH_WORLDORIGIN, nil)
        ParticleManager:SetParticleControl(fx, 0, pos)
        ParticleManager:SetParticleControl(fx, 1, pos)
    end)
    if ok and fx ~= nil and duration ~= nil then
        GameRules:GetGameModeEntity():SetContextThink("DotaKartWorldParticleRelease_" .. tostring(fx), function()
            pcall(function()
                ParticleManager:DestroyParticle(fx, false)
                ParticleManager:ReleaseParticleIndex(fx)
            end)
            return nil
        end, duration)
    end
    return fx
end


function DotaKartItemSystem:CreateAttachedParticle(particleName, unit, duration, cp1)
    if particleName == nil or particleName == "" or ParticleManager == nil or not DKValidUnit(unit) then return nil end
    local fx = nil
    local ok = pcall(function()
        fx = ParticleManager:CreateParticle(particleName, PATTACH_ABSORIGIN_FOLLOW, unit)
        ParticleManager:SetParticleControlEnt(fx, 0, unit, PATTACH_ABSORIGIN_FOLLOW, "", unit:GetAbsOrigin(), true)
        ParticleManager:SetParticleControl(fx, 1, cp1 or unit:GetAbsOrigin())
        ParticleManager:SetParticleControl(fx, 2, unit:GetAbsOrigin())
    end)
    if not ok then return nil end
    if fx ~= nil and duration ~= nil and duration > 0 then
        GameRules:GetGameModeEntity():SetContextThink("DotaKartAttachedParticleRelease_" .. tostring(fx), function()
            pcall(function()
                ParticleManager:DestroyParticle(fx, false)
                ParticleManager:ReleaseParticleIndex(fx)
            end)
            return nil
        end, duration)
    end
    return fx
end

-- FIX38: helper extra para VFX do Lich que não apareciam em alguns heróis/karts.
-- Cria o particle de mais de um jeito e configura CPs comuns de shield/radius.
function DotaKartItemSystem:CreateAttachedParticleRobust(particleName, unit, duration, radius)
    local fxs = {}
    if particleName == nil or particleName == "" or ParticleManager == nil or not DKValidUnit(unit) then return fxs end
    local pos = unit:GetAbsOrigin()
    local r = tonumber(radius) or 160

    local function addFx(attachType, attachName)
        local fx = nil
        local ok = pcall(function()
            fx = ParticleManager:CreateParticle(particleName, attachType, unit)
            ParticleManager:SetParticleControlEnt(fx, 0, unit, attachType, attachName or "", pos, true)
            ParticleManager:SetParticleControl(fx, 1, Vector(r, 0, 0))
            ParticleManager:SetParticleControl(fx, 2, pos)
            ParticleManager:SetParticleControl(fx, 3, Vector(r, r, r))
            ParticleManager:SetParticleControlForward(fx, 0, unit:GetForwardVector())
        end)
        if ok and fx ~= nil then
            table.insert(fxs, fx)
        end
    end

    addFx(PATTACH_ABSORIGIN_FOLLOW, "")
    -- Tenta hitloc, mas se o modelo não tiver esse attachment o pcall evita quebrar.
    addFx(PATTACH_POINT_FOLLOW, "attach_hitloc")

    if duration ~= nil and tonumber(duration) ~= nil and tonumber(duration) > 0 then
        for _, fx in ipairs(fxs) do
            GameRules:GetGameModeEntity():SetContextThink("DotaKartRobustParticleRelease_" .. tostring(fx), function()
                pcall(function()
                    ParticleManager:DestroyParticle(fx, false)
                    ParticleManager:ReleaseParticleIndex(fx)
                end)
                return nil
            end, tonumber(duration))
        end
    end
    return fxs
end


-- FIX39: Particle do Frost Shield em modo world-follow.
-- Alguns particles do Lich não aparecem quando presos por attachment em heróis/karts diferentes.
-- Este modo cria em world origin e atualiza os CPs manualmente no tick.
function DotaKartItemSystem:UpdateFrostFollowParticleCP(fx, unit, radius, zOffset)
    if fx == nil or ParticleManager == nil or not DKValidUnit(unit) then return end
    local r = tonumber(radius) or 600
    local z = tonumber(zOffset) or 72
    local pos = unit:GetAbsOrigin()
    local center = pos + Vector(0, 0, z)
    pcall(function()
        ParticleManager:SetParticleControl(fx, 0, center)
        ParticleManager:SetParticleControl(fx, 1, Vector(r, 0, 0))
        ParticleManager:SetParticleControl(fx, 2, center)
        ParticleManager:SetParticleControl(fx, 3, Vector(r, r, r))
        ParticleManager:SetParticleControl(fx, 4, pos)
        ParticleManager:SetParticleControlForward(fx, 0, unit:GetForwardVector())
    end)
end

function DotaKartItemSystem:CreateFrostWorldFollowParticle(particleName, unit, data, radius, zOffset)
    if particleName == nil or particleName == "" or ParticleManager == nil or not DKValidUnit(unit) or data == nil then return nil end
    data.fxs = data.fxs or {}
    data.world_fxs = data.world_fxs or {}
    local fx = nil
    local ok = pcall(function()
        fx = ParticleManager:CreateParticle(particleName, PATTACH_WORLDORIGIN, nil)
    end)
    if ok and fx ~= nil then
        table.insert(data.fxs, fx)
        table.insert(data.world_fxs, { fx = fx, radius = tonumber(radius) or 600, z = tonumber(zOffset) or 72 })
        self:UpdateFrostFollowParticleCP(fx, unit, radius, zOffset)
    end
    return fx
end

function DotaKartItemSystem:UpdateFrostWorldFollowParticles(unit, data)
    if not DKValidUnit(unit) or data == nil or data.world_fxs == nil then return end
    for _, entry in ipairs(data.world_fxs) do
        if entry ~= nil and entry.fx ~= nil then
            self:UpdateFrostFollowParticleCP(entry.fx, unit, entry.radius or 600, entry.z or 72)
        end
    end
end

function DotaKartItemSystem:EmitFrostShieldSound(playerID, hero, soundDef, pos)
    -- FIX111: os eventos do Lich são soundevents reais do game_sounds_lich.vsndevts.
    -- EmitKartSound também tenta os raw .vsnd fornecidos como fallback.
    self:EmitKartSound(hero, soundDef, pos)
    local sounds = self:NormalizeSoundList(soundDef)
    if DKValidUnit(hero) and #sounds > 0 then
        self:TryEmitUISoundServer(hero, sounds[1])
    end
    if tonumber(playerID) ~= nil and #sounds > 0 then
        self:SendUISoundToPlayer(tonumber(playerID), sounds[1], "play", 0)
    end
end

function DotaKartItemSystem:EmitChainFrostLoopSound(caster, def, pos)
    if def == nil then return end
    -- Não tenta parar esse loop: é um .vsnd curto/loopado pelo próprio arquivo e StopSoundEvent gerava spam em alguns sons.
    self:EmitKartSound(caster, def.sound_loop, pos)
    local sounds = self:NormalizeSoundList(def.sound_loop)
    if #sounds > 0 then
        self:TryEmitUISoundServer(caster, sounds[1])
    end
end

function DotaKartItemSystem:CreateDebuffVictimVisual(target, def, kind, duration)
    if not DKValidUnit(target) then return end
    def = def or {}
    local pos = target:GetAbsOrigin() + Vector(0, 0, 72)
    local dur = tonumber(duration) or 1.0

    if kind == "venom" then
        if def.particle_impact ~= nil then
            self:CreateWorldParticle(def.particle_impact, pos, math.min(1.3, dur))
            self:CreateAttachedParticleRobust(def.particle_impact, target, math.min(1.2, dur), 180)
        end
    elseif kind == "frost" then
        if def.particle_ice ~= nil then
            self:CreateAttachedParticleRobust(def.particle_ice, target, math.min(1.0, dur), 180)
            self:CreateWorldParticle(def.particle_ice, pos, math.min(0.8, dur))
        end
        if def.particle_shield_c ~= nil then
            self:CreateAttachedParticleRobust(def.particle_shield_c, target, math.min(0.9, dur), 220)
            self:CreateWorldParticle(def.particle_shield_c, pos, math.min(0.8, dur))
        end
        if def.particle_ring ~= nil then
            self:CreateRadiusWorldParticle(def.particle_ring, target:GetAbsOrigin() + Vector(0,0,18), 220, 0.65)
        end
    elseif kind == "chain" then
        if def.particle_impact ~= nil then
            self:CreateWorldParticle(def.particle_impact, pos, 1.1)
        end
        local victimParticle = def.particle_victim or "particles/units/heroes/hero_lich/lich_frost_armor_ice.vpcf"
        self:CreateAttachedParticleRobust(victimParticle, target, math.min(1.8, dur), 220)
        if def.particle_shield_c ~= nil then
            self:CreateAttachedParticleRobust(def.particle_shield_c, target, math.min(1.2, dur), 240)
        end
        if def.particle_ring ~= nil then
            self:CreateRadiusWorldParticle(def.particle_ring, target:GetAbsOrigin() + Vector(0,0,18), 240, 0.7)
        end
    end
end

function DotaKartItemSystem:CreateRadiusWorldParticle(particleName, pos, radius, duration)
    if particleName == nil or particleName == "" or ParticleManager == nil or pos == nil then return nil end
    local fx = nil
    local r = tonumber(radius) or 600
    local ok = pcall(function()
        fx = ParticleManager:CreateParticle(particleName, PATTACH_WORLDORIGIN, nil)
        ParticleManager:SetParticleControl(fx, 0, pos)
        ParticleManager:SetParticleControl(fx, 1, Vector(r, 0, 0))
        ParticleManager:SetParticleControl(fx, 2, pos)
        ParticleManager:SetParticleControl(fx, 3, Vector(r, r, r))
    end)
    if not ok then return nil end
    if fx ~= nil and duration ~= nil and duration > 0 then
        GameRules:GetGameModeEntity():SetContextThink("DotaKartRadiusParticleRelease_" .. tostring(fx), function()
            pcall(function()
                ParticleManager:DestroyParticle(fx, false)
                ParticleManager:ReleaseParticleIndex(fx)
            end)
            return nil
        end, duration)
    end
    return fx
end

function DotaKartItemSystem:CreateLinearParticle(particleName, startPos, endPos)
    if particleName == nil or particleName == "" or ParticleManager == nil then return nil end
    local fx = nil
    local ok = pcall(function()
        fx = ParticleManager:CreateParticle(particleName, PATTACH_WORLDORIGIN, nil)
        ParticleManager:SetParticleControl(fx, 0, startPos)
        ParticleManager:SetParticleControl(fx, 1, endPos or startPos)
        ParticleManager:SetParticleControl(fx, 2, endPos or startPos)
        ParticleManager:SetParticleControl(fx, 3, startPos)
        ParticleManager:SetParticleControl(fx, 4, endPos or startPos)
    end)
    if not ok then return nil end
    return fx
end

function DotaKartItemSystem:UpdateLinearParticle(fx, startPos, endPos)
    if fx == nil or ParticleManager == nil then return end
    pcall(function()
        ParticleManager:SetParticleControl(fx, 0, startPos)
        ParticleManager:SetParticleControl(fx, 1, endPos)
        ParticleManager:SetParticleControl(fx, 2, endPos)
        ParticleManager:SetParticleControl(fx, 3, startPos)
        ParticleManager:SetParticleControl(fx, 4, endPos)
    end)
end

function DotaKartItemSystem:DestroyLinearParticle(fx, immediate)
    if fx == nil or ParticleManager == nil then return end
    pcall(function()
        ParticleManager:DestroyParticle(fx, immediate == true)
        ParticleManager:ReleaseParticleIndex(fx)
    end)
end


function DotaKartItemSystem:NormalizeParticleList(particleDef)
    local out = {}
    if particleDef == nil then return out end
    if type(particleDef) == "table" then
        for _, p in ipairs(particleDef) do
            if p ~= nil and p ~= "" then table.insert(out, tostring(p)) end
        end
    elseif particleDef ~= "" then
        table.insert(out, tostring(particleDef))
    end
    return out
end

function DotaKartItemSystem:CreateProjectileParticles(particleDef, startPos, endPos)
    local list = self:NormalizeParticleList(particleDef)
    local fxs = {}
    for _, particleName in ipairs(list) do
        local fx = self:CreateLinearParticle(particleName, startPos, endPos)
        if fx ~= nil then table.insert(fxs, fx) end
    end
    return fxs
end

function DotaKartItemSystem:UpdateProjectileParticles(fxs, startPos, endPos)
    if fxs == nil then return end
    for _, fx in ipairs(fxs) do
        self:UpdateLinearParticle(fx, startPos, endPos)
    end
end

function DotaKartItemSystem:DestroyProjectileParticles(fxs, immediate)
    if fxs == nil then return end
    for _, fx in ipairs(fxs) do
        self:DestroyLinearParticle(fx, immediate)
    end
end

-- FIX22: alguns particles de projétil do Dota, como Sacred Arrow, usam CP1 como vetor de velocidade/direção.
-- Se usar CP1 como ponto final, a flecha pode parecer sair de lado. Este modo segue a posição do projétil
-- e mantém CP1 como velocidade para orientar o modelo corretamente.
function DotaKartItemSystem:CreateDirectionalParticle(particleName, startPos, dir, speed)
    if particleName == nil or particleName == "" or ParticleManager == nil then return nil end
    local fx = nil
    local velocity = (dir or Vector(1,0,0)) * (speed or 1000)
    local ok = pcall(function()
        fx = ParticleManager:CreateParticle(particleName, PATTACH_WORLDORIGIN, nil)
        ParticleManager:SetParticleControl(fx, 0, startPos)
        ParticleManager:SetParticleControl(fx, 1, velocity)
        ParticleManager:SetParticleControl(fx, 2, startPos)
        ParticleManager:SetParticleControlForward(fx, 0, dir or Vector(1,0,0))
    end)
    if not ok then return nil end
    return fx
end

function DotaKartItemSystem:UpdateDirectionalParticle(fx, pos, dir, speed)
    if fx == nil or ParticleManager == nil then return end
    local velocity = (dir or Vector(1,0,0)) * (speed or 1000)
    pcall(function()
        ParticleManager:SetParticleControl(fx, 0, pos)
        ParticleManager:SetParticleControl(fx, 1, velocity)
        ParticleManager:SetParticleControl(fx, 2, pos)
        ParticleManager:SetParticleControlForward(fx, 0, dir or Vector(1,0,0))
    end)
end

function DotaKartItemSystem:CreateMissileParticle(particleName, startPos, dir, speed, lookAhead)
    if particleName == nil or particleName == "" or ParticleManager == nil then return nil end
    local fx = nil
    dir = self:NormalizeDir2D(dir or Vector(1,0,0))
    lookAhead = tonumber(lookAhead) or 420
    speed = tonumber(speed) or 1200
    local target = startPos + dir * lookAhead
    local ok = pcall(function()
        fx = ParticleManager:CreateParticle(particleName, PATTACH_WORLDORIGIN, nil)
        ParticleManager:SetParticleControl(fx, 0, startPos)
        ParticleManager:SetParticleControl(fx, 1, target)
        ParticleManager:SetParticleControl(fx, 2, Vector(speed, 0, 0))
        ParticleManager:SetParticleControl(fx, 3, startPos)
        ParticleManager:SetParticleControl(fx, 4, target)
        ParticleManager:SetParticleControlForward(fx, 0, dir)
        if ParticleManager.SetParticleControlOrientation ~= nil then
            ParticleManager:SetParticleControlOrientation(fx, 0, dir, Vector(-dir.y, dir.x, 0), Vector(0,0,1))
        end
    end)
    if not ok then return nil end
    return fx
end

function DotaKartItemSystem:UpdateMissileParticle(fx, pos, dir, speed, lookAhead)
    if fx == nil or ParticleManager == nil then return end
    dir = self:NormalizeDir2D(dir or Vector(1,0,0))
    lookAhead = tonumber(lookAhead) or 420
    speed = tonumber(speed) or 1200
    local target = pos + dir * lookAhead
    pcall(function()
        ParticleManager:SetParticleControl(fx, 0, pos)
        ParticleManager:SetParticleControl(fx, 1, target)
        ParticleManager:SetParticleControl(fx, 2, Vector(speed, 0, 0))
        ParticleManager:SetParticleControl(fx, 3, pos)
        ParticleManager:SetParticleControl(fx, 4, target)
        ParticleManager:SetParticleControlForward(fx, 0, dir)
        if ParticleManager.SetParticleControlOrientation ~= nil then
            ParticleManager:SetParticleControlOrientation(fx, 0, dir, Vector(-dir.y, dir.x, 0), Vector(0,0,1))
        end
    end)
end

function DotaKartItemSystem:EmitRandomKartSound(hero, soundDef, pos)
    local sounds = self:NormalizeSoundList(soundDef)
    if #sounds <= 0 then return end
    local soundName = sounds[DKRandomInt(1, #sounds)]
    self:EmitKartSound(hero, { soundName }, pos)
end

function DotaKartItemSystem:EmitLeapSound(playerID, hero, soundDef, pos)
    local sounds = self:NormalizeSoundList(soundDef)
    if #sounds <= 0 then return end
    local soundName = sounds[DKRandomInt(1, #sounds)]

    -- FIX119: Leap usa um soundevent proprio do addon. O evento escolhe aleatoriamente
    -- leap1..leap4.vsnd e evita depender de aliases/raw .vsnd que falhavam em algumas builds.
    if soundName == "dotakart_leap" then
        self:EmitKartSound(hero, { soundName }, pos)
        if self.config and self.config.debug then
            print("[DotaKartItems] FIX119 Leap soundevent: " .. tostring(soundName))
        end
        return
    end
    local noExt = string.gsub(soundName, "%.vsnd$", "")
    local noSounds = string.gsub(noExt, "^sounds/", "")
    local aliases = {
        soundName,
        noExt,
        noSounds,
        string.gsub(noSounds, "/", "."),
        string.gsub(noSounds, "/", "_"),
        "Hero_Mirana.Leap",
        "Hero_Mirana.Leap.Cast",
        "Hero_Mirana.Leap.Begin",
        "Hero_Mirana.Leap1",
        "Hero_Mirana.Leap2",
        "Hero_Mirana.Leap3",
        "Hero_Mirana.Leap4",
        "Hero_Mirana.Leap.Start",
        "Hero_Mirana.Leap.End",
        "Ability.MiranaLeap",
        "Mirana.Leap",
        "mirana_leap",
        "mirana.leap1",
        "mirana.leap2",
        "mirana.leap3",
        "mirana.leap4"
    }

    -- FIX28: toca no servidor e também no Panorama; repete em 0.04s/0.10s porque algumas builds
    -- ignoram o raw .vsnd no mesmo frame do SetAbsOrigin do Leap.
    self:EmitKartSound(hero, aliases, pos)
    self:TryEmitUISoundServer(hero, soundName)
    for _, a in ipairs(aliases) do
        self:SendUISoundToPlayer(playerID, a, "play", 0)
    end

    local serial = self:NextProjectileSerial()
    for i, delay in ipairs({0.04, 0.10}) do
        GameRules:GetGameModeEntity():SetContextThink("DotaKartLeapSoundRetry_" .. tostring(serial) .. "_" .. tostring(i), function()
            if DKValidUnit(hero) then
                self:EmitKartSound(hero, aliases, hero:GetAbsOrigin())
            end
            return nil
        end, delay)
    end

    if self.config and self.config.debug then
        print("[DotaKartItems] FIX28 Leap sound escolhido: " .. tostring(soundName))
    end
end

function DotaKartItemSystem:GetState(playerID)
    if self.controller ~= nil and self.controller.GetState ~= nil then
        return self.controller:GetState(playerID)
    end
    return nil
end

function DotaKartItemSystem:GetHeroYaw(playerID, hero)
    local st = self:GetState(playerID)
    if st ~= nil and st.yaw ~= nil then return tonumber(st.yaw) or 0 end
    if DKValidUnit(hero) and hero.GetForwardVector ~= nil then
        local fwd = hero:GetForwardVector()
        if fwd ~= nil then return DKNormalizeYaw(math.deg(DKAtan2(fwd.y, fwd.x))) end
    end
    return 0
end

function DotaKartItemSystem:GetForwardForPlayer(playerID, hero)
    local yaw = self:GetHeroYaw(playerID, hero)
    local rad = math.rad(yaw)
    return Vector(math.cos(rad), math.sin(rad), 0), yaw
end

function DotaKartItemSystem:GetFireDirectionForPlayer(playerID, hero)
    local dir, yaw = self:GetForwardForPlayer(playerID, hero)
    local st = self:GetState(playerID)

    -- Mario Kart: sem cursor/reticulo. Item sai para frente por padrão.
    -- Se o jogador estiver segurando S ao usar T, lança para trás.
    local backward = false
    if st ~= nil and st.input ~= nil then
        backward = st.input.reverse == true and st.input.forward ~= true
    end

    if backward then
        dir = dir * -1
        yaw = DKNormalizeYaw(yaw + 180)
    end

    return dir, yaw, backward
end

function DotaKartItemSystem:GetPlayerIDForHero(hero)
    if not DKValidUnit(hero) then return -1 end

    -- FIX27: AutoBots criados por script ficam registrados no controller/hud,
    -- mas não necessariamente aparecem como PlayerResource:IsValidPlayerID.
    if self.controller ~= nil and self.controller.heroes ~= nil then
        for playerID, h in pairs(self.controller.heroes) do
            if DKValidUnit(h) and h == hero then return tonumber(playerID) or -1 end
        end
    end

    if self.hud ~= nil and self.hud.racers ~= nil then
        for playerID, racer in pairs(self.hud.racers) do
            if racer ~= nil and DKValidUnit(racer.unit) and racer.unit == hero then return tonumber(playerID) or -1 end
        end
    end

    for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(playerID) then
            local h = self:GetHeroForPlayer(playerID)
            if DKValidUnit(h) and h == hero then return playerID end
        end
    end
    return -1
end

function DotaKartItemSystem:IsPlayerStarActive(playerID)
    local st = self:GetState(playerID)
    if st ~= nil and (st.star_until or 0) > DKNow() then return true end
    local hero = self:GetHeroForPlayer(playerID)
    if DKValidUnit(hero) and hero.HasModifier ~= nil and hero:HasModifier("modifier_dotakart_star") then return true end
    return false
end

function DotaKartItemSystem:IsHeroStarActive(hero)
    local pid = self:GetPlayerIDForHero(hero)
    if pid >= 0 then return self:IsPlayerStarActive(pid) end
    return DKValidUnit(hero) and hero.HasModifier ~= nil and hero:HasModifier("modifier_dotakart_star")
end

function DotaKartItemSystem:ConsumeHeldItem(playerID, itemName, def)
    if def ~= nil and def.charges ~= nil and tonumber(def.charges) ~= nil and tonumber(def.charges) > 1 then
        local left = tonumber(self.itemCharges[playerID] or def.charges) or def.charges
        left = left - 1
        if left > 0 then
            self.itemCharges[playerID] = left

            -- FIX48: Nitros mudam de icone/item conforme a carga restante:
            -- 3 Nitros -> 2 Nitros -> 1 Nitro.
            local hudItemName = itemName
            if def.kind == "nitro" then
                if def.charge_items ~= nil and def.charge_items[left] ~= nil then
                    hudItemName = def.charge_items[left]
                elseif left == 2 then
                    hudItemName = "item_yasha"
                elseif left == 1 then
                    hudItemName = "item_phase_boots"
                end
            end

            self:SetHeldItemHUD(playerID, hudItemName, left)
            print("[DotaKartItems] " .. tostring(def.label) .. " restante player " .. tostring(playerID) .. ": " .. tostring(left) .. " hudItem=" .. tostring(hudItemName))
            return
        end
    end

    self.itemCharges[playerID] = nil
    self:SetHeldItemHUD(playerID, "", 0)
end

function DotaKartItemSystem:ApplyNitro(playerID, itemName, def)
    local hero = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(hero) then return false end
    local st = self:GetState(playerID)
    if st == nil then return false end

    local now = DKNow()
    st.boost_until = math.max(st.boost_until or 0, now + (def.boost_duration or 1.0))
    st.item_max_speed_until = math.max(st.item_max_speed_until or 0, now + (def.boost_duration or 1.0))
    st.item_max_speed = math.max(st.item_max_speed or 0, def.boost_max_speed or 1320)
    st.speed = math.min((st.speed or 0) + (def.boost_add_speed or 500), def.boost_max_speed or 1320)

    self:EmitKartSound(hero, def.sound)
    self:ConsumeHeldItem(playerID, itemName, def)
    print("[DotaKartItems] Player " .. tostring(playerID) .. " usou " .. tostring(def.label))
    return true
end

function DotaKartItemSystem:GetComebackTierForPlayer(playerID)
    local count = math.max(1, math.min(8, tonumber(self:GetRacerCount()) or 1))
    local place = math.max(1, math.min(count, tonumber(self:GetPlaceForPlayer(playerID)) or 1))
    if count <= 1 then return 4 end
    return math.max(1, math.min(8, math.floor(1 + ((place - 1) / (count - 1)) * 7 + 0.5)))
end

function DotaKartItemSystem:RollBloodlustMulticast(def, playerID)
    def = def or {}
    local tier = self:GetComebackTierForPlayer(playerID)
    local chances = def.multicast_chance_by_tier and def.multicast_chance_by_tier[tier] or def.multicast_chance or {}
    local roll = DKRandomFloat(0, 100)
    local chance4 = tonumber(chances[4] or 15) or 15
    local chance3 = tonumber(chances[3] or 30) or 30
    local chance2 = tonumber(chances[2] or 50) or 50

    if roll < chance4 then return 4 end
    if roll < chance4 + chance3 then return 3 end
    if roll < chance4 + chance3 + chance2 then return 2 end
    return 1
end

function DotaKartItemSystem:ShowBloodlustMulticastText(target, multicast, bonusPct, duration)
    if not DKValidUnit(target) then return end
    multicast = tonumber(multicast) or 1
    if multicast <= 1 then return end

    local text = tostring(multicast) .. "x MULTICAST!"
    local pos = target:GetAbsOrigin() + Vector(0, 0, 260)
    pcall(function()
        CustomGameEventManager:Send_ServerToAllClients("dotakart_multicast_text", {
            text = text,
            subtext = "+" .. tostring(math.floor((tonumber(bonusPct) or 0) + 0.5)) .. "% SPEED",
            duration = math.min(2.25, math.max(1.25, tonumber(duration) or 1.75)),
            entindex = target:entindex(),
            x = pos.x,
            y = pos.y,
            z = pos.z
        })
    end)
end

function DotaKartItemSystem:ApplyBloodlust(playerID, itemName, def)
    local hero = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(hero) then return false end
    local st = self:GetState(playerID)
    if st == nil then return false end

    local now = DKNow()
    local duration = tonumber(def.duration) or 15.0
    local multicast = self:RollBloodlustMulticast(def, playerID)
    local bonusPct = tonumber(def.move_speed_bonus and def.move_speed_bonus[multicast] or 8) or 8
    local maxBase = 880
    if self.controller ~= nil and self.controller.config ~= nil and self.controller.config.max_speed ~= nil then
        maxBase = tonumber(self.controller.config.max_speed) or maxBase
    end
    local boostedMax = maxBase * (1.0 + bonusPct / 100.0)

    st.bloodlust_until = now + duration
    st.bloodlust_multicast = multicast
    st.bloodlust_speed_bonus_pct = bonusPct
    st.item_max_speed_until = math.max(st.item_max_speed_until or 0, now + duration)
    st.item_max_speed = math.max(st.item_max_speed or 0, boostedMax)
    if (st.speed or 0) > 0 then
        st.speed = math.min(boostedMax, (st.speed or 0) + maxBase * (bonusPct / 100.0) * 0.50)
    end

    local baseScale = tonumber(st.bloodlust_base_model_scale)
    if baseScale == nil or baseScale <= 0 then
        baseScale = 1.0
        pcall(function() baseScale = tonumber(hero:GetModelScale()) or baseScale end)
        if baseScale <= 0 then baseScale = 1.0 end
        st.bloodlust_base_model_scale = baseScale
    end
    local scaleBonus = tonumber(def.model_scale_bonus) or 0.25
    pcall(function() hero:SetModelScale(baseScale * (1.0 + scaleBonus)) end)

    st.bloodlust_token = (tonumber(st.bloodlust_token) or 0) + 1
    local token = st.bloodlust_token

    self:EmitKartSound(hero, def.sound_target, hero:GetAbsOrigin())
    if multicast > 1 then
        local ms = def.sound_multicast and def.sound_multicast[multicast] or nil
        self:EmitKartSound(hero, ms, hero:GetAbsOrigin())
        self:ShowBloodlustMulticastText(hero, multicast, bonusPct, 1.8)
    end
    if def.particle ~= nil then
        self:CreateAttachedParticleRobust(def.particle, hero, duration, 220)
    end

    GameRules:GetGameModeEntity():SetContextThink("DotaKartBloodlustEnd_" .. tostring(playerID) .. "_" .. tostring(token), function()
        local st2 = self:GetState(playerID)
        local h = self:GetHeroForPlayer(playerID)
        if st2 ~= nil and st2.bloodlust_token == token and (st2.bloodlust_until or 0) <= DKNow() + 0.05 then
            if DKValidUnit(h) then
                local restore = tonumber(st2.bloodlust_base_model_scale) or 1.0
                pcall(function() h:SetModelScale(restore) end)
            end
            st2.bloodlust_base_model_scale = nil
            st2.bloodlust_multicast = nil
            st2.bloodlust_speed_bonus_pct = nil
        end
        return nil
    end, duration)

    self:ConsumeHeldItem(playerID, itemName, def)
    print("[DotaKartItems] Player " .. tostring(playerID) .. " usou BLOODLUST " .. tostring(multicast) .. "x bonus=" .. tostring(bonusPct) .. "% duration=" .. tostring(duration))
    return true
end

function DotaKartItemSystem:ApplyStar(playerID, itemName, def)
    local hero = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(hero) then return false end
    local st = self:GetState(playerID)
    if st == nil then return false end

    local now = DKNow()
    local duration = def.duration or 15.0
    st.star_until = now + duration
    st.boost_until = math.max(st.boost_until or 0, now + duration)
    st.item_max_speed_until = math.max(st.item_max_speed_until or 0, now + duration)
    st.item_max_speed = math.max(st.item_max_speed or 0, def.boost_max_speed or 1750)
    st.speed = math.min(math.max(st.speed or 0, def.boost_max_speed or 1750), def.boost_max_speed or 1750)
    st.slow_until = math.min(st.slow_until or 0, now)
    st.slow_initial_pct = 0

    pcall(function()
        hero:Purge(false, true, false, true, true)
    end)
    pcall(function()
        hero:AddNewModifier(hero, nil, "modifier_dotakart_star", { duration = duration })
    end)

    if ParticleManager ~= nil then
        local particleList = {}
        if def.particle ~= nil then table.insert(particleList, def.particle) end
        if def.particles ~= nil then
            for _, particleName in ipairs(def.particles) do
                table.insert(particleList, particleName)
            end
        end

        for _, particleName in ipairs(particleList) do
            pcall(function()
                local p = ParticleManager:CreateParticle(particleName, PATTACH_ABSORIGIN_FOLLOW, hero)
                ParticleManager:SetParticleControlEnt(p, 0, hero, PATTACH_ABSORIGIN_FOLLOW, "attach_origin", hero:GetAbsOrigin(), true)
                ParticleManager:SetParticleControlEnt(p, 1, hero, PATTACH_OVERHEAD_FOLLOW, "attach_origin", hero:GetAbsOrigin(), true)
                ParticleManager:SetParticleControlEnt(p, 2, hero, PATTACH_ABSORIGIN_FOLLOW, "attach_origin", hero:GetAbsOrigin(), true)
                GameRules:GetGameModeEntity():SetContextThink("DotaKartStarParticleRelease_" .. tostring(playerID) .. "_" .. tostring(p), function()
                    ParticleManager:DestroyParticle(p, false)
                    ParticleManager:ReleaseParticleIndex(p)
                    return nil
                end, duration)
            end)
        end
    end

    self:EmitKartSound(hero, def.sound)
    self:EmitKartSound(hero, def.sound_loop)
    if def.sound_loop ~= nil then
        GameRules:GetGameModeEntity():SetContextThink("DotaKartStarLoopStop_" .. tostring(playerID), function()
            if DKValidUnit(hero) then self:StopKartSound(hero, def.sound_loop) end
            return nil
        end, duration)
    end
    self:ConsumeHeldItem(playerID, itemName, def)
    print("[DotaKartItems] Player " .. tostring(playerID) .. " ativou ESTRELINHA/BKB por " .. tostring(duration) .. "s")
    return true
end

function DotaKartItemSystem:LinePointHit(projectilePos, targetPos, radius)
    if projectilePos == nil or targetPos == nil then return false end
    return DKLength2D(projectilePos, targetPos) <= (radius or 140)
end

-- FIX120: central protection used by Astral self/enemy and Ball Lightning.
function DotaKartItemSystem:IsKartUntargetable(playerID)
    playerID = tonumber(playerID)
    if playerID == nil or playerID < 0 then return false end
    local now = DKNow()
    local st = self:GetState(playerID)
    if st ~= nil then
        if (tonumber(st.astral_enemy_until) or 0) > now then return true end
        if (tonumber(st.astral_self_until) or 0) > now then return true end
        if st.ball_lightning_active == true then return true end
    end
    if self.activeBallLightning ~= nil and self.activeBallLightning[playerID] ~= nil then return true end
    return false
end

function DotaKartItemSystem:FindHeroHit(casterPlayerID, projectilePos, radius)
    for _, playerID in ipairs(self:GetRegisteredPlayerIDs()) do
        if playerID ~= casterPlayerID then
            local hero = self:GetHeroForPlayer(playerID)
            if DKValidUnit(hero) and not self:IsPlayerStarActive(playerID) and not self:IsPlayerInvisible(playerID) and not (self.activeShukuchi and self.activeShukuchi[playerID]) and not self:IsKartUntargetable(playerID) then
                if self:LinePointHit(projectilePos, hero:GetAbsOrigin(), radius) then
                    self:NotifyBattleHungerItemHit(casterPlayerID, playerID)
                    return hero, playerID
                end
            end
        end
    end
    return nil, -1
end

function DotaKartItemSystem:FindBoxHit(projectilePos, radius)
    for _, box in ipairs(self.boxes or {}) do
        if box.active and not box.being_pulled and box.pos ~= nil then
            if self:LinePointHit(projectilePos, box.pos, radius) then
                return box
            end
        end
    end
    return nil
end

function DotaKartItemSystem:LockKart(playerID, duration)
    if self.controller ~= nil and self.controller.SetKartLocked ~= nil then
        self.controller:SetKartLocked(playerID, duration or 0.1)
    else
        local st = self:GetState(playerID)
        if st ~= nil then
            st.locked_until = math.max(st.locked_until or 0, DKNow() + (duration or 0.1))
            st.speed = 0
        end
    end
end

function DotaKartItemSystem:ApplyKartStun(caster, target, duration)
    if not DKValidUnit(target) then return end
    if self:IsHeroStarActive(target) then return end
    local protectedPID = self:GetPlayerIDForHero(target)
    if protectedPID ~= nil and protectedPID >= 0 and self:IsKartUntargetable(protectedPID) then return end

    local dur = math.max(0.05, tonumber(duration) or 0.5)
    local targetPlayerID = self:GetPlayerIDForHero(target)
    local casterPlayerID = self:GetPlayerIDForHero(caster)
    if casterPlayerID ~= nil and casterPlayerID >= 0 and targetPlayerID ~= nil and targetPlayerID >= 0 then
        self:NotifyBattleHungerItemHit(casterPlayerID, targetPlayerID)
    end

    if targetPlayerID ~= nil and targetPlayerID >= 0 and self.controller ~= nil and self.controller.SetKartStunned ~= nil then
        self.controller:SetKartStunned(targetPlayerID, dur)
    end

    -- Mantém também o modifier_stunned do Dota para feedback padrão e segurança,
    -- mas o movimento real do kart é travado pelo controller/auto-drive.
    pcall(function()
        target:AddNewModifier(caster or target, nil, "modifier_stunned", { duration = dur })
    end)
end

function DotaKartItemSystem:ApplyMiniStun(caster, target, duration)
    return self:ApplyKartStun(caster, target, duration)
end

function DotaKartItemSystem:ApplyKartSlow(caster, target, duration, slowPct, recoverPctPerTick, tickInterval)
    if not DKValidUnit(target) then return end
    if self:IsHeroStarActive(target) then return end

    local targetPlayerID = self:GetPlayerIDForHero(target)
    if targetPlayerID ~= nil and targetPlayerID >= 0 and self:IsKartUntargetable(targetPlayerID) then return end
    local casterPlayerID = self:GetPlayerIDForHero(caster)
    if casterPlayerID ~= nil and casterPlayerID >= 0 and targetPlayerID ~= nil and targetPlayerID >= 0 then
        self:NotifyBattleHungerItemHit(casterPlayerID, targetPlayerID)
    end
    if targetPlayerID ~= nil and targetPlayerID >= 0 and self.controller ~= nil and self.controller.SetKartSlow ~= nil then
        self.controller:SetKartSlow(targetPlayerID, duration or 15.0, slowPct or 0.5, recoverPctPerTick or 0.001, tickInterval or 0.03)
    else
        local st = targetPlayerID and self:GetState(targetPlayerID) or nil
        if st ~= nil then
            local now = DKNow()
            st.slow_until = math.max(st.slow_until or 0, now + (duration or 15.0))
            st.slow_start_time = now
            st.slow_initial_pct = slowPct or 0.5
            st.slow_recover_per_tick = recoverPctPerTick or 0.001
            st.slow_tick = tickInterval or 0.03
        end
    end
end

-- FIX129: source-specific exact slow channels. Plague Ward refreshes 15% without
-- stacking; The Swarm starts at zero on latch and increases only on 1-second ticks.
function DotaKartItemSystem:ApplyPlagueWardSlow(caster, target, duration, slowPct)
    if not DKValidUnit(target) or self:IsHeroStarActive(target) then return end
    local targetPlayerID = self:GetPlayerIDForHero(target)
    if targetPlayerID == nil or targetPlayerID < 0 or self:IsKartUntargetable(targetPlayerID) then return end
    local casterPlayerID = self:GetPlayerIDForHero(caster)
    if casterPlayerID ~= nil and casterPlayerID >= 0 then self:NotifyBattleHungerItemHit(casterPlayerID, targetPlayerID) end
    if self.controller ~= nil and self.controller.SetPlagueWardSlow ~= nil then
        self.controller:SetPlagueWardSlow(targetPlayerID, duration or 2.0, slowPct or 0.15)
    else
        local st = self:GetState(targetPlayerID)
        local now = DKNow()
        st.plague_ward_slow_until = now + math.max(0.05, tonumber(duration) or 2.0)
        st.plague_ward_slow_pct = math.max(0, math.min(0.95, tonumber(slowPct) or 0.15))
    end
end

function DotaKartItemSystem:ApplySwarmTickSlow(caster, target, duration, slowPct)
    if not DKValidUnit(target) or self:IsHeroStarActive(target) then return end
    local targetPlayerID = self:GetPlayerIDForHero(target)
    if targetPlayerID == nil or targetPlayerID < 0 or self:IsKartUntargetable(targetPlayerID) then return end
    local casterPlayerID = self:GetPlayerIDForHero(caster)
    if casterPlayerID ~= nil and casterPlayerID >= 0 then self:NotifyBattleHungerItemHit(casterPlayerID, targetPlayerID) end
    if self.controller ~= nil and self.controller.SetSwarmSlow ~= nil then
        self.controller:SetSwarmSlow(targetPlayerID, duration or 1.1, slowPct or 0)
    else
        local st = self:GetState(targetPlayerID)
        local now = DKNow()
        st.swarm_slow_until = now + math.max(0.05, tonumber(duration) or 1.1)
        st.swarm_slow_pct = math.max(0, math.min(0.95, tonumber(slowPct) or 0))
    end
end

function DotaKartItemSystem:ClearSwarmTickSlow(targetPlayerID)
    targetPlayerID = tonumber(targetPlayerID)
    if targetPlayerID == nil or targetPlayerID < 0 then return end
    if self.controller ~= nil and self.controller.ClearSwarmSlow ~= nil then
        self.controller:ClearSwarmSlow(targetPlayerID)
    else
        local st = self:GetState(targetPlayerID)
        st.swarm_slow_until = 0
        st.swarm_slow_pct = 0
    end
end

-- FIX116: interação pontual com props do mapa mines e miners.
function DotaKartItemSystem:FindMinesBlockingPropHit(pos, radius, onlyKind)
    if self.controller ~= nil and self.controller.FindMinesBlockingPropAtPosition ~= nil then
        return self.controller:FindMinesBlockingPropAtPosition(pos, radius, onlyKind)
    end
    return nil, nil
end

function DotaKartItemSystem:FindMinerHit(pos, radius)
    local miners = GameRules ~= nil and GameRules.DotaKartMinerSystem or nil
    if miners ~= nil and miners.FindMinerAtPosition ~= nil then
        return miners:FindMinerAtPosition(pos, radius)
    end
    return nil
end

function DotaKartItemSystem:PullMinerToCaster(casterPlayerID, caster, entry, speed)
    if not DKValidUnit(caster) or entry == nil or not DKValidUnit(entry.unit) or not entry.unit:IsAlive() then return end
    local miners = GameRules ~= nil and GameRules.DotaKartMinerSystem or nil
    if miners ~= nil and miners.BeginExternalPull ~= nil then miners:BeginExternalPull(entry, 3.5) end
    local target = entry.unit
    local serial = self:NextProjectileSerial()
    local speedValue = tonumber(speed) or 1600

    GameRules:GetGameModeEntity():SetContextThink("DotaKartMeatHookPullMiner_" .. tostring(serial), function()
        if not DKValidUnit(caster) or not DKValidUnit(target) or not target:IsAlive() then
            if miners ~= nil and miners.EndExternalPull ~= nil then miners:EndExternalPull(entry) end
            return nil
        end
        local targetPos = target:GetAbsOrigin()
        local casterPos = caster:GetAbsOrigin()
        local toCaster = casterPos - targetPos
        toCaster.z = 0
        local dist = math.sqrt(toCaster.x * toCaster.x + toCaster.y * toCaster.y)
        if dist <= 120 then
            if miners ~= nil and miners.EndExternalPull ~= nil then miners:EndExternalPull(entry) end
            return nil
        end
        local dir = toCaster / math.max(1, dist)
        local step = math.min(dist, speedValue * 0.03)
        local nextPos = targetPos + dir * step
        nextPos.z = GetGroundHeight(nextPos, target)
        target:SetAbsOrigin(nextPos)
        if miners ~= nil and miners.BeginExternalPull ~= nil then miners:BeginExternalPull(entry, 0.15) end
        return 0.03
    end, 0.03)
end

function DotaKartItemSystem:PullHeroToCaster(casterPlayerID, caster, targetPlayerID, target, speed, finalStun)
    if not DKValidUnit(caster) or not DKValidUnit(target) then return end
    local serial = self:NextProjectileSerial()
    local speedValue = speed or 1600

    -- FIX51: quando o Hook puxa o alvo para frente do usuário, o próprio usuário pode
    -- atravessar esse alvo por curto tempo para não ter o caminho bloqueado pelo pull.
    local now0 = DKNow()
    local casterSt = self:GetState(casterPlayerID)
    if casterSt ~= nil then
        casterSt.hook_passthrough_until = now0 + 2.25
        casterSt.hook_passthrough_target = targetPlayerID
    end
    local targetSt = self:GetState(targetPlayerID)
    if targetSt ~= nil then
        targetSt.hook_passthrough_until = now0 + 2.25
        targetSt.hook_passthrough_target = casterPlayerID
    end

    self:LockKart(targetPlayerID, 1.5)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartMeatHookPullHero_" .. tostring(serial), function()
        if not DKValidUnit(caster) or not DKValidUnit(target) then return nil end
        if self:IsPlayerStarActive(targetPlayerID) or self:IsKartUntargetable(targetPlayerID) then return nil end

        local now = DKNow()
        local targetPos = target:GetAbsOrigin()
        local casterPos = caster:GetAbsOrigin()
        local toCaster = casterPos - targetPos
        toCaster.z = 0
        local dist = math.sqrt(toCaster.x * toCaster.x + toCaster.y * toCaster.y)

        if dist <= 120 then
            self:LockKart(targetPlayerID, finalStun or 0.5)
            self:ApplyMiniStun(caster, target, finalStun or 0.5)
            local nowEnd = DKNow()
            local casterSt2 = self:GetState(casterPlayerID)
            if casterSt2 ~= nil then casterSt2.hook_passthrough_until = nowEnd + 1.00; casterSt2.hook_passthrough_target = targetPlayerID end
            local targetSt2 = self:GetState(targetPlayerID)
            if targetSt2 ~= nil then targetSt2.hook_passthrough_until = nowEnd + 1.00; targetSt2.hook_passthrough_target = casterPlayerID end
            return nil
        end

        local dir = toCaster / math.max(1, dist)
        local step = math.min(dist, speedValue * 0.03)
        local nextPos = targetPos + dir * step
        nextPos.z = GetGroundHeight(nextPos, target)
        target:SetAbsOrigin(nextPos)
        self:LockKart(targetPlayerID, 0.12)
        return 0.03
    end, 0.03)
end

function DotaKartItemSystem:PullBoxToCaster(playerID, caster, box, speed)
    if not DKValidUnit(caster) or box == nil or box.ent == nil then return end
    box.being_pulled = true
    local serial = self:NextProjectileSerial()
    local speedValue = speed or 1600

    GameRules:GetGameModeEntity():SetContextThink("DotaKartMeatHookPullBox_" .. tostring(serial), function()
        if not DKValidUnit(caster) or box == nil or box.ent == nil or box.ent:IsNull() then return nil end
        if not box.active then return nil end

        local boxPos = box.ent:GetAbsOrigin()
        local casterPos = caster:GetAbsOrigin()
        local toCaster = casterPos - boxPos
        toCaster.z = 0
        local dist = math.sqrt(toCaster.x * toCaster.x + toCaster.y * toCaster.y)

        if dist <= 130 then
            box.pos = box.ent:GetAbsOrigin()
            box.being_pulled = false
            self:OnPickupBox(playerID, caster, box)
            return nil
        end

        local dir = toCaster / math.max(1, dist)
        local step = math.min(dist, speedValue * 0.03)
        local nextPos = boxPos + dir * step
        nextPos.z = GetGroundHeight(nextPos, nil) + (self.config.spawn_z_offset or 0)
        box.ent:SetAbsOrigin(nextPos)
        box.pos = nextPos
        return 0.03
    end, 0.03)
end

function DotaKartItemSystem:NextProjectileSerial()
    self.projectileSerial = (self.projectileSerial or 0) + 1
    return self.projectileSerial
end

function DotaKartItemSystem:PullCogToMeatHookCaster(casterPlayerID, caster, cogOwnerID, cog, speed, hookDef)
    if not DKValidUnit(caster) or cog == nil or cog.active ~= true then return end
    local cogDef = self.itemDefs and self.itemDefs.item_blade_mail or {}
    local serial = self:NextProjectileSerial()
    local speedValue = tonumber(speed) or 1600

    -- O Cog deixa de orbitar/ricochetear e passa a pertencer ao pull do Meat Hook.
    cog.hooked_by_meat_hook = true
    cog.launched = true
    self:UnregisterCogProjectile(cog)
    self:UpdatePowerCogsHUD(cogOwnerID)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartMeatHookPullCog_" .. tostring(serial), function()
        if not DKValidUnit(caster) or cog == nil or cog.active ~= true then return nil end
        local cogPos = cog.pos
        if cog.ent ~= nil and not cog.ent:IsNull() then
            cogPos = cog.ent:GetAbsOrigin()
        end
        if cogPos == nil then
            self:DestroyCogInstance(cogOwnerID, cog, "meat_hook_cog_missing")
            return nil
        end

        local casterPos = caster:GetAbsOrigin()
        local toCaster = casterPos - cogPos
        toCaster.z = 0
        local dist = math.sqrt(toCaster.x * toCaster.x + toCaster.y * toCaster.y)
        if dist <= 125 then
            local cogOwnerHero = self:GetHeroForPlayer(cogOwnerID)
            local stun = tonumber(cogDef.shock_stun) or 1.35
            self:EmitKartSound(caster, cogDef.sound_impact, casterPos)
            -- Meat Hook trouxe a "casca" até si: o próprio caster recebe o stun do Cog.
            self:ApplyKartStun(DKValidUnit(cogOwnerHero) and cogOwnerHero or caster, caster, stun)
            self:DestroyCogInstance(cogOwnerID, cog, "meat_hook_pulled_cog_to_caster")
            return nil
        end

        local dir = toCaster / math.max(1, dist)
        local step = math.min(dist, speedValue * 0.03)
        local nextPos = cogPos + dir * step
        nextPos.z = GetGroundHeight(nextPos, caster)
        cog.pos = nextPos
        if cog.ent ~= nil and not cog.ent:IsNull() then
            cog.ent:SetAbsOrigin(nextPos)
        end
        return 0.03
    end, 0.03)
end

function DotaKartItemSystem:UseMeatHook(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end
    local dir, yaw, backward = self:GetFireDirectionForPlayer(playerID, caster)
    local start = caster:GetAbsOrigin() + dir * 120 + Vector(0, 0, 96)
    local range = def.cast_range or 2500
    local speed = def.speed or 1600
    local radius = def.hit_radius or 150
    local serial = self:NextProjectileSerial()
    local startTime = DKNow()
    local maxTime = range / math.max(1, speed)
    local fxs = self:CreateProjectileParticles(def.particles or def.particle, start, start)

    self:EmitKartSound(caster, def.sound_throw, start)
    self:ConsumeHeldItem(playerID, itemName, def)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartMeatHook_" .. tostring(serial), function()
        local now = DKNow()
        local traveled = math.min(range, (now - startTime) * speed)
        local p = start + dir * traveled
        self:UpdateProjectileParticles(fxs, start, p)

        -- FIX112: Power Cog intercepta Meat Hook. Diferente dos outros projéteis,
        -- o Hook captura o Cog e o traz até o caster, que então recebe o stun do Cog.
        local cogOwnerID, hitCog = self:FindPowerCogHit(playerID, p, radius)
        if hitCog ~= nil then
            self:EmitKartSound(caster, def.sound_impact, p)
            self:DestroyProjectileParticles(fxs, false)
            self:PullCogToMeatHookCaster(playerID, caster, cogOwnerID, hitCog, def.pull_speed or speed, def)
            return nil
        end

        local minerEntry = self:FindMinerHit(p, radius)
        if minerEntry ~= nil and DKValidUnit(minerEntry.unit) then
            self:EmitKartSound(caster, def.sound_impact, p)
            self:DestroyProjectileParticles(fxs, false)
            self:PullMinerToCaster(playerID, caster, minerEntry, def.pull_speed or speed)
            return nil
        end

        if self:HandleSpecialProjectileTargetHit(playerID,p,radius,"meat_hook") then self:EmitKartSound(caster,def.sound_impact,p); self:DestroyProjectileParticles(fxs,false); return nil end
        local target, targetPlayerID = self:FindHeroHit(playerID, p, radius)
        if DKValidUnit(target) then
            self:EmitKartSound(caster, def.sound_impact, p)
            self:DestroyProjectileParticles(fxs, false)
            self:PullHeroToCaster(playerID, caster, targetPlayerID, target, def.pull_speed or speed, def.final_stun or 0.5)
            return nil
        end

        local box = self:FindBoxHit(p, radius)
        if box ~= nil then
            self:EmitKartSound(caster, def.sound_impact, p)
            self:DestroyProjectileParticles(fxs, false)
            self:PullBoxToCaster(playerID, caster, box, def.pull_speed or speed)
            return nil
        end

        if now - startTime >= maxTime then
            self:EmitKartSound(caster, def.sound_retract, p)
            self:DestroyProjectileParticles(fxs, false)
            return nil
        end
        return 0.03
    end, 0.03)

    print("[DotaKartItems] Player " .. tostring(playerID) .. " lançou MEAT HOOK " .. (backward and "para tras" or "para frente"))
    return true
end

function DotaKartItemSystem:PullCasterToTarget(playerID, caster, targetPlayerID, target, speed, stunDuration, def)
    if not DKValidUnit(caster) or not DKValidUnit(target) then return end
    local serial = self:NextProjectileSerial()
    local speedValue = speed or 5000
    local startNow = DKNow()
    local casterSt0 = self:GetState(playerID)
    local preservedSpeed = casterSt0 and tonumber(casterSt0.speed or 0) or 0
    local preservedYaw = casterSt0 and casterSt0.yaw or nil
    local passDuration = tonumber(def and def.pass_through_duration) or 1.10
    local prePassDist = tonumber(def and def.pre_pass_distance) or 300
    local finishDist = tonumber(def and def.final_stop_distance) or 70
    local passThroughDistance = tonumber(def and def.pass_through_distance) or 185
    local startedPass = false
    local appliedHit = false
    local beyondUntil = 0
    local beyondPoint = nil
    local pullStart = startNow

    -- FIX82: Hookshot ativa pass-through pouco antes de encostar na vítima.
    -- Assim a colisão do kart alvo não bloqueia o pull, permitindo atravessar/ultrapassar
    -- a vítima de forma parecida com a exceção usada pelo Meat Hook.
    local function EnablePairPassThrough(untilTime)
        local casterSt = self:GetState(playerID)
        if casterSt ~= nil then
            casterSt.hook_passthrough_until = math.max(casterSt.hook_passthrough_until or 0, untilTime)
            casterSt.hook_passthrough_target = targetPlayerID
        end
        local targetSt = self:GetState(targetPlayerID)
        if targetSt ~= nil then
            targetSt.hook_passthrough_until = math.max(targetSt.hook_passthrough_until or 0, untilTime)
            targetSt.hook_passthrough_target = playerID
        end
    end

    -- Não começa com pass-through longo global; só mantém o caster travado pelo pull.
    self:LockKart(playerID, 0.35)
    if casterSt0 ~= nil then casterSt0.speed = preservedSpeed end

    self:EmitKartSound(caster, def.sound_impact)
    if def ~= nil and def.particle_impact ~= nil then
        self:CreateWorldParticle(def.particle_impact, target:GetAbsOrigin() + Vector(0,0,96), 0.75)
    end

    GameRules:GetGameModeEntity():SetContextThink("DotaKartHookshotPull_" .. tostring(serial), function()
        if not DKValidUnit(caster) or not DKValidUnit(target) then return nil end
        local now = DKNow()
        local casterPos = caster:GetAbsOrigin()
        local targetPos = target:GetAbsOrigin()
        local toTarget = targetPos - casterPos
        toTarget.z = 0
        local dist = math.sqrt(toTarget.x * toTarget.x + toTarget.y * toTarget.y)

        local dir = nil
        if dist > 1 then
            dir = toTarget / dist
        else
            dir = self:NormalizeDir2D(caster:GetForwardVector())
        end

        if dist <= prePassDist then
            startedPass = true
            EnablePairPassThrough(now + passDuration)
        end

        if dist <= finishDist and not appliedHit then
            appliedHit = true
            startedPass = true
            EnablePairPassThrough(now + passDuration)
            self:ApplyMiniStun(caster, target, stunDuration or 0.85)
            self:EmitKartSound(target, def.sound_damage)
            self:EmitKartSound(caster, def.sound_retract)
            beyondPoint = targetPos + dir * passThroughDistance
            beyondPoint.z = GetGroundHeight(beyondPoint, caster)
            beyondUntil = now + 0.22
        end

        local moveTarget = nil
        if appliedHit and beyondPoint ~= nil then
            moveTarget = beyondPoint
        else
            moveTarget = targetPos
        end

        local toMove = moveTarget - casterPos
        toMove.z = 0
        local moveDist = math.sqrt(toMove.x * toMove.x + toMove.y * toMove.y)
        local moveDir = dir
        if moveDist > 1 then moveDir = toMove / moveDist end

        local step = math.min(moveDist, speedValue * 0.03)
        local nextPos = casterPos + moveDir * step
        nextPos.z = GetGroundHeight(nextPos, caster)
        caster:SetAbsOrigin(nextPos)

        local stTick = self:GetState(playerID)
        if stTick ~= nil then
            stTick.locked_until = math.max(stTick.locked_until or 0, now + 0.10)
            stTick.speed = preservedSpeed or stTick.speed or 0
            if preservedYaw ~= nil then stTick.yaw = preservedYaw end
        end
        if startedPass then EnablePairPassThrough(now + passDuration) end

        if appliedHit and (moveDist <= 45 or now >= beyondUntil) then
            local stEnd = self:GetState(playerID)
            if stEnd ~= nil then
                stEnd.locked_until = math.max(stEnd.locked_until or 0, now + 0.04)
                stEnd.speed = preservedSpeed or stEnd.speed or 0
                if preservedYaw ~= nil then stEnd.yaw = preservedYaw end
            end
            EnablePairPassThrough(now + passDuration)
            return nil
        end

        if now - pullStart > 2.20 then
            local stEnd = self:GetState(playerID)
            if stEnd ~= nil then
                stEnd.speed = preservedSpeed or stEnd.speed or 0
                if preservedYaw ~= nil then stEnd.yaw = preservedYaw end
            end
            return nil
        end
        return 0.03
    end, 0.03)
end

function DotaKartItemSystem:PullCasterToWoodWall(playerID, caster, wall, impactPos, speed, def)
    if not DKValidUnit(caster) or wall == nil or wall:IsNull() or impactPos == nil then return end
    local serial = self:NextProjectileSerial()
    local st0 = self:GetState(playerID)
    local preservedSpeed = st0 and tonumber(st0.speed or 0) or 0
    local preservedYaw = st0 and st0.yaw or nil
    local speedValue = tonumber(speed) or 5000
    local destroyDistance = tonumber(def and def.wood_wall_destroy_distance) or 155
    local targetPoint = Vector(impactPos.x, impactPos.y, GetGroundHeight(impactPos, caster))
    local started = DKNow()
    self:LockKart(playerID, 0.30)
    self:EmitKartSound(caster, def and def.sound_impact or nil, impactPos)

    local function finish(removeWall)
        if removeWall and wall ~= nil and not wall:IsNull() then
            pcall(function() wall:AddNoDraw() end)
            if UTIL_Remove ~= nil then pcall(function() UTIL_Remove(wall) end) end
            if wall ~= nil and not wall:IsNull() and wall.RemoveSelf ~= nil then pcall(function() wall:RemoveSelf() end) end
            if self.controller ~= nil and self.controller.RefreshMinesBlockingProps ~= nil then
                pcall(function() self.controller:RefreshMinesBlockingProps(true) end)
            end
        end
        local st = self:GetState(playerID)
        if st ~= nil then
            st.speed = preservedSpeed or st.speed or 0
            if preservedYaw ~= nil then st.yaw = preservedYaw end
        end
        self:EmitKartSound(caster, def and def.sound_retract or nil, caster:GetAbsOrigin())
    end

    GameRules:GetGameModeEntity():SetContextThink("DotaKartHookshotWoodWallPull_" .. tostring(serial), function()
        if not DKValidUnit(caster) then return nil end
        if wall == nil or wall:IsNull() then finish(false); return nil end
        local casterPos = caster:GetAbsOrigin()
        local toTarget = targetPoint - casterPos
        toTarget.z = 0
        local dist = math.sqrt(toTarget.x * toTarget.x + toTarget.y * toTarget.y)
        if dist <= destroyDistance then
            finish(true)
            return nil
        end
        if DKNow() - started > 2.20 then
            finish(false)
            return nil
        end
        local dir = self:NormalizeDir2D(toTarget)
        local step = math.min(dist, speedValue * 0.03)
        local nextPos = casterPos + dir * step
        nextPos.z = GetGroundHeight(nextPos, caster)
        caster:SetAbsOrigin(nextPos)
        local st = self:GetState(playerID)
        if st ~= nil then
            st.locked_until = math.max(st.locked_until or 0, DKNow() + 0.10)
            st.speed = preservedSpeed or st.speed or 0
            if preservedYaw ~= nil then st.yaw = preservedYaw end
        end
        return 0.03
    end, 0.03)
end

function DotaKartItemSystem:UseHookshot(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end
    local dir, yaw, backward = self:GetFireDirectionForPlayer(playerID, caster)
    local start = caster:GetAbsOrigin() + dir * 120 + Vector(0, 0, 96)
    local range = def.cast_range or 2500
    local speed = def.speed or 5000
    local radius = def.hit_radius or 150
    local serial = self:NextProjectileSerial()
    local startTime = DKNow()
    local maxTime = range / math.max(1, speed)
    local fxs = self:CreateProjectileParticles(def.particles or def.particle, start, start)

    self:EmitKartSound(caster, def.sound_fire, start)
    self:ConsumeHeldItem(playerID, itemName, def)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartHookshot_" .. tostring(serial), function()
        local now = DKNow()
        local traveled = math.min(range, (now - startTime) * speed)
        local p = start + dir * traveled
        self:UpdateProjectileParticles(fxs, start, p)

        local woodWall = self:FindMinesBlockingPropHit(p, radius, "wood_wall")
        if woodWall ~= nil then
            self:DestroyProjectileParticles(fxs, false)
            if def.particle_impact ~= nil then self:CreateWorldParticle(def.particle_impact, p, 0.75) end
            self:PullCasterToWoodWall(playerID, caster, woodWall, p, def.pull_speed or speed, def)
            return nil
        end

        if self:HandleSpecialProjectileTargetHit(playerID,p,radius,"hookshot") then self:DestroyProjectileParticles(fxs,false); return nil end
        local target, targetPlayerID = self:FindHeroHit(playerID, p, radius)

        if DKValidUnit(target) then
            self:DestroyProjectileParticles(fxs, false)
            if def.particle_impact ~= nil then
                self:CreateWorldParticle(def.particle_impact, target:GetAbsOrigin() + Vector(0,0,96), 0.75)
            end
            self:PullCasterToTarget(playerID, caster, targetPlayerID, target, def.pull_speed or speed, def.stun_duration or 0.85, def)
            return nil
        end

        if now - startTime >= maxTime then
            self:EmitKartSound(caster, def.sound_retract, p)
            self:DestroyProjectileParticles(fxs, false)
            return nil
        end
        return 0.02
    end, 0.02)

    print("[DotaKartItems] Player " .. tostring(playerID) .. " lançou HOOKSHOT " .. (backward and "para tras" or "para frente"))
    return true
end


function DotaKartItemSystem:UseLeap(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end
    local dir, yaw, backward = self:GetFireDirectionForPlayer(playerID, caster)
    local st = self:GetState(playerID)
    local start = caster:GetAbsOrigin()
    local distance = tonumber(def.distance) or 1250
    local speed = tonumber(def.speed) or 1600
    local maxTime = tonumber(def.max_time) or (distance / math.max(1, speed))
    local startTime = DKNow()
    local endPos = start + dir * distance
    local serial = self:NextProjectileSerial()
    local preLeapSpeed = st ~= nil and (tonumber(st.speed) or 0) or 0
    local leapLockUntil = startTime + maxTime

    self:EmitLeapSound(playerID, caster, def.sound, start)
    self:ConsumeHeldItem(playerID, itemName, def)

    if st ~= nil then
        local now = DKNow()
        local bonusDuration = tonumber(def.bonus_duration) or 2.0
        st.item_max_speed_until = math.max(st.item_max_speed_until or 0, now + bonusDuration)
        st.item_max_speed = math.max(st.item_max_speed or 0, (self.controller and self.controller.config and self.controller.config.max_speed or 720) * (1 + ((def.move_speed_bonus_pct or 8) / 100)))
        -- FIX119: nao injeta velocidade artificial e guarda exatamente a velocidade de entrada.
        -- O controller zera speed durante locked_until; ela e restaurada apos o pouso.
        st.leap_pre_use_speed = preLeapSpeed
        st.leap_motion_until = leapLockUntil
        st.leap_lock_until = leapLockUntil
        st.locked_until = math.max(st.locked_until or 0, leapLockUntil)
    end

    GameRules:GetGameModeEntity():SetContextThink("DotaKartLeap_" .. tostring(serial), function()
        if not DKValidUnit(caster) then return nil end
        local now = DKNow()
        local t = math.min(1.0, (now - startTime) / math.max(0.01, maxTime))
        local p = start + (endPos - start) * t
        local groundZ = GetGroundHeight(p, caster)
        local arcHeight = tonumber(def.arc_height) or 430
        p.z = groundZ + math.sin(math.pi * t) * arcHeight
        caster:SetAbsOrigin(p)
        if t >= 1.0 then
            local finalPos = endPos
            finalPos.z = GetGroundHeight(finalPos, caster)
            caster:SetAbsOrigin(finalPos)
            pcall(function() FindClearSpaceForUnit(caster, finalPos, true) end)

            if st ~= nil then
                st.leap_motion_until = 0
                -- Limpa somente o lock que o proprio Leap criou. Se outro efeito colocou
                -- um lock maior durante o salto, ele permanece intacto.
                if st.leap_lock_until ~= nil and st.locked_until == st.leap_lock_until then
                    st.locked_until = DKNow()
                end
            end

            -- FIX119: restaura a velocidade anterior assim que o lock proprio do Leap termina.
            -- Nao sobrepoe um stun/root/lock externo recebido durante o salto.
            GameRules:GetGameModeEntity():SetContextThink("DotaKartLeapRestoreSpeed_" .. tostring(serial), function()
                if st == nil or not DKValidUnit(caster) then return nil end
                local restoreNow = DKNow()
                if (st.stunned_until or 0) > restoreNow or (st.rooted_until or 0) > restoreNow then
                    st.leap_pre_use_speed = nil
                    st.leap_lock_until = nil
                    return nil
                end
                if (st.locked_until or 0) > restoreNow + 0.01 then
                    st.leap_pre_use_speed = nil
                    st.leap_lock_until = nil
                    return nil
                end
                st.speed = tonumber(st.leap_pre_use_speed) or preLeapSpeed
                st.leap_pre_use_speed = nil
                st.leap_lock_until = nil
                return nil
            end, 0.01)
            return nil
        end
        return 0.03
    end, 0.03)

    print("[DotaKartItems] Player " .. tostring(playerID) .. " usou LEAP FIX119 " .. (backward and "para tras" or "para frente") .. " distance=" .. tostring(distance) .. " preserve_speed=" .. tostring(math.floor(preLeapSpeed)))
    return true
end

function DotaKartItemSystem:UseSacredArrow(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end
    local dir, yaw, backward = self:GetFireDirectionForPlayer(playerID, caster)
    local start = caster:GetAbsOrigin() + dir * 120 + Vector(0, 0, 96)
    local range = tonumber(def.cast_range) or 3000
    local speed = tonumber(def.speed) or 1800
    local radius = tonumber(def.hit_radius) or 130
    local serial = self:NextProjectileSerial()
    local startTime = DKNow()
    local maxTime = range / math.max(1, speed)

    -- FIX22: Sacred Arrow precisa de CP1 como vetor velocidade para não sair lateralmente.
    local arrowFx = nil
    local fxs = nil
    if def.visual_mode == "velocity" then
        arrowFx = self:CreateDirectionalParticle(def.particle, start, dir, speed)
    else
        fxs = self:CreateProjectileParticles(def.particles or def.particle, start, start)
    end

    self:EmitKartSound(caster, def.sound_fire, start)
    self:ConsumeHeldItem(playerID, itemName, def)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartSacredArrow_" .. tostring(serial), function()
        local now = DKNow()
        local traveled = math.min(range, (now - startTime) * speed)
        local p = start + dir * traveled

        if arrowFx ~= nil then
            self:UpdateDirectionalParticle(arrowFx, p, dir, speed)
        else
            self:UpdateProjectileParticles(fxs, start, p)
        end

        -- FIX112: Cogs sacrificam-se para bloquear Sacred Arrow antes de atingir o kart.
        if self:BlockProjectileWithPowerCog(playerID, p, radius, "sacred_arrow_blocked") then
            if arrowFx ~= nil then
                self:DestroyLinearParticle(arrowFx, false)
            else
                self:DestroyProjectileParticles(fxs, false)
            end
            self:EmitKartSound(caster, def.sound_impact, p)
            return nil
        end

        if self:HandleSpecialProjectileTargetHit(playerID,p,radius,"sacred_arrow") then if arrowFx~=nil then self:DestroyLinearParticle(arrowFx,false) else self:DestroyProjectileParticles(fxs,false) end; return nil end
        local target, targetPlayerID = self:FindHeroHit(playerID, p, radius)
        if DKValidUnit(target) then
            if arrowFx ~= nil then
                self:DestroyLinearParticle(arrowFx, false)
            else
                self:DestroyProjectileParticles(fxs, false)
            end
            local ratio = DKClamp(traveled / math.max(1, range), 0, 1)
            local stun = (def.min_stun or 0.01) + ratio * ((def.max_stun or 5.0) - (def.min_stun or 0.01))
            self:ApplyMiniStun(caster, target, stun)
            self:LockKart(targetPlayerID, stun)
            self:EmitKartSound(target, def.sound_impact, p)
            print("[DotaKartItems] Sacred Arrow acertou player " .. tostring(targetPlayerID) .. " stun=" .. tostring(string.format("%.2f", stun)) .. " dist=" .. tostring(math.floor(traveled)))
            return nil
        end

        if now - startTime >= maxTime then
            if arrowFx ~= nil then
                self:DestroyLinearParticle(arrowFx, false)
            else
                self:DestroyProjectileParticles(fxs, false)
            end
            return nil
        end
        return 0.02
    end, 0.02)

    print("[DotaKartItems] Player " .. tostring(playerID) .. " lançou SACRED ARROW " .. (backward and "para tras" or "para frente"))
    return true
end


function DotaKartItemSystem:UseVenomousGale(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end

    local dir, yaw, backward = self:GetFireDirectionForPlayer(playerID, caster)
    dir = self:NormalizeDir2D(dir)
    local start = caster:GetAbsOrigin() + dir * 120 + Vector(0, 0, 96)
    local range = tonumber(def.cast_range) or 1000
    local speed = tonumber(def.speed) or 1500
    local radius = tonumber(def.hit_radius) or 280
    local serial = self:NextProjectileSerial()
    local startTime = DKNow()
    local maxTime = range / math.max(1, speed)
    local hitPlayers = {}

    local fx = nil
    if def.visual_mode == "velocity" then
        fx = self:CreateDirectionalParticle(def.particle, start, dir, speed)
    else
        fx = self:CreateLinearParticle(def.particle, start, start)
    end

    self:EmitKartSound(caster, def.sound_fire, start)
    self:ConsumeHeldItem(playerID, itemName, def)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartVenomousGale_" .. tostring(serial), function()
        local now = DKNow()
        local traveled = math.min(range, (now - startTime) * speed)
        local p = start + dir * traveled
        p.z = GetGroundHeight(p, nil) + 96

        if def.visual_mode == "velocity" then
            self:UpdateDirectionalParticle(fx, p, dir, speed)
        else
            self:UpdateLinearParticle(fx, start, p)
        end

        if self:HandleSpecialProjectileTargetHit(playerID, p, radius, "venomous_gale") then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            return nil
        end

        for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
            if tonumber(otherID) ~= tonumber(playerID) and hitPlayers[otherID] ~= true then
                local other = self:GetHeroForPlayer(otherID)
                if DKValidUnit(other) and not self:IsPlayerStarActive(otherID) and not self:IsKartUntargetable(otherID) and DKLength2D(p, other:GetAbsOrigin()) <= radius then
                    hitPlayers[otherID] = true
                    self:ApplyKartSlow(caster, other, def.duration or 15.0, def.slow_pct or 0.50, def.recover_pct_per_tick or 0.001, def.recover_tick or 0.03)
                    self:EmitKartSound(other, def.sound_impact, p)
                    if def.particle_impact ~= nil then
                        self:CreateWorldParticle(def.particle_impact, other:GetAbsOrigin() + Vector(0,0,72), 1.0)
                    end
                    self:CreateDebuffVictimVisual(other, def, "venom", def.duration or 15.0)
                    print("[DotaKartItems] Venomous Gale acertou player " .. tostring(otherID) .. " slow=50%")
                end
            end
        end

        if now - startTime >= maxTime then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            return nil
        end
        return 0.02
    end, 0.02)

    print("[DotaKartItems] Player " .. tostring(playerID) .. " lançou VENOMOUS GALE " .. (backward and "para tras" or "para frente"))
    return true
end


function DotaKartItemSystem:GetTrackWorldBounds(padding)
    local hud = self.hud or GameRules.DotaKartHUD
    if hud == nil or hud.trackWorldPoints == nil or #hud.trackWorldPoints <= 0 then return nil end
    padding = tonumber(padding) or 1000
    local minX, maxX, minY, maxY = nil, nil, nil, nil
    for _, p in ipairs(hud.trackWorldPoints) do
        if p ~= nil then
            minX = minX == nil and p.x or math.min(minX, p.x)
            maxX = maxX == nil and p.x or math.max(maxX, p.x)
            minY = minY == nil and p.y or math.min(minY, p.y)
            maxY = maxY == nil and p.y or math.max(maxY, p.y)
        end
    end
    if minX == nil then return nil end
    return { min_x = minX - padding, max_x = maxX + padding, min_y = minY - padding, max_y = maxY + padding }
end

function DotaKartItemSystem:GetCogMapBoundaryBounce(pos, dir, padding)
    if pos == nil then return nil end
    local b = self:GetTrackWorldBounds(padding or 1000)
    if b == nil then return nil end
    dir = self:NormalizeDir2D(dir or Vector(1,0,0))
    local newDir = Vector(dir.x, dir.y, 0)
    local hit = false
    if pos.x <= b.min_x and newDir.x < 0 then newDir.x = math.abs(newDir.x); hit = true end
    if pos.x >= b.max_x and newDir.x > 0 then newDir.x = -math.abs(newDir.x); hit = true end
    if pos.y <= b.min_y and newDir.y < 0 then newDir.y = math.abs(newDir.y); hit = true end
    if pos.y >= b.max_y and newDir.y > 0 then newDir.y = -math.abs(newDir.y); hit = true end
    if not hit then return nil end
    return self:NormalizeDir2D(newDir)
end

function DotaKartItemSystem:RegisterCogProjectile(ownerPlayerID, cog)
    self.activeCogProjectiles = self.activeCogProjectiles or {}
    if cog == nil then return end
    cog.projectile_birth = DKNow()
    table.insert(self.activeCogProjectiles, { owner = ownerPlayerID, cog = cog, birth = cog.projectile_birth })
    self:EnforceCogProjectileLimit(self.itemDefs and self.itemDefs.item_blade_mail or nil)
end

function DotaKartItemSystem:UnregisterCogProjectile(cog)
    if self.activeCogProjectiles == nil or cog == nil then return end
    local out = {}
    for _, e in ipairs(self.activeCogProjectiles) do
        if e.cog ~= cog and e.cog ~= nil and e.cog.active == true then
            table.insert(out, e)
        end
    end
    self.activeCogProjectiles = out
end

function DotaKartItemSystem:EnforceCogProjectileLimit(def)
    local maxCount = tonumber(def and def.max_active_projectiles or 15) or 15
    self.activeCogProjectiles = self.activeCogProjectiles or {}
    table.sort(self.activeCogProjectiles, function(a,b) return (a.birth or 0) < (b.birth or 0) end)
    while #self.activeCogProjectiles > maxCount do
        local e = table.remove(self.activeCogProjectiles, 1)
        if e ~= nil and e.cog ~= nil and e.cog.active == true then
            e.cog.active = false
            self:RemoveCogVisual(e.cog)
            if e.owner ~= nil then self:UpdatePowerCogsHUD(e.owner) end
            if self.config and self.config.debug then
                print("[DotaKartItems] Power Cog antigo removido pelo limite global de " .. tostring(maxCount))
            end
        end
    end
end

function DotaKartItemSystem:GetCogBounceDirection(pos, dir, radius)
    dir = self:NormalizeDir2D(dir)
    radius = tonumber(radius) or 105
    local right = Vector(dir.y, -dir.x, 0)
    local function blockedAt(p)
        if self:IsProjectileBlockedByWorld(p, radius) then return true end
        local prop = self:FindMinesBlockingPropHit(p, radius, nil)
        return prop ~= nil
    end
    local forwardBlocked = blockedAt(pos + dir * radius)
    local rightBlocked = blockedAt(pos + right * radius)
    local leftBlocked = blockedAt(pos - right * radius)

    local newDir = nil
    if forwardBlocked and not rightBlocked and leftBlocked then
        newDir = right
    elseif forwardBlocked and rightBlocked and not leftBlocked then
        newDir = -right
    elseif rightBlocked ~= leftBlocked then
        -- Reflete contra uma parede aproximada lateral.
        newDir = self:NormalizeDir2D(dir - right * (rightBlocked and 2 or -2))
    else
        -- Fallback de ricochete simples: inverte e inclina, evitando ficar preso no mesmo ponto.
        newDir = self:NormalizeDir2D((dir * -1) + right * (DKRandomInt(0, 1) == 0 and 0.55 or -0.55))
    end
    return self:NormalizeDir2D(newDir)
end

-- FIX127: detect an abrupt terrain-height wall independently from GridNav.
-- Smooth ramps produce a small Z delta per projectile step and remain climbable;
-- cliffs/ledges produce a large jump and should ricochet like a wall.
function DotaKartItemSystem:GetCogTerrainBounceDirection(pos, dir, step, maxStepUp)
    dir = self:NormalizeDir2D(dir or Vector(1,0,0))
    step = math.max(48, tonumber(step) or 72)
    maxStepUp = tonumber(maxStepUp) or 56
    local right = Vector(dir.y, -dir.x, 0)
    local baseZ = GetGroundHeight(pos, nil)
    local candidates = {
        self:NormalizeDir2D((dir * -1) + right * 0.70),
        self:NormalizeDir2D((dir * -1) - right * 0.70),
        self:NormalizeDir2D(dir * -1)
    }
    local best = candidates[3]
    local bestScore = 999999
    for _, cand in ipairs(candidates) do
        local probe = pos + cand * step
        local rise = GetGroundHeight(probe, nil) - baseZ
        local blocked = self:IsProjectileBlockedByWorld(probe, 72) or self:FindMinesBlockingPropHit(probe, 72, nil) ~= nil
        local score = math.max(0, rise) + (blocked and 10000 or 0) + (rise > maxStepUp and 5000 or 0)
        if score < bestScore then bestScore = score; best = cand end
    end
    return self:NormalizeDir2D(best)
end

function DotaKartItemSystem:DestroyCogInstance(ownerPlayerID, cog, reason)
    if cog == nil or cog.active ~= true then return end
    cog.active = false
    self:UnregisterCogProjectile(cog)
    self:RemoveCogVisual(cog)
    if ownerPlayerID ~= nil then self:UpdatePowerCogsHUD(ownerPlayerID) end
    if self.config and self.config.debug then
        print("[DotaKartItems] FIX97 Cog destruido owner=" .. tostring(ownerPlayerID) .. " reason=" .. tostring(reason or "cog_collision"))
    end
end

function DotaKartItemSystem:CheckCogProjectileCollision(ownerPlayerID, cog, pos, radius)
    -- FIX97/FIX104: cogs arremessados se anulam contra outros cogs/proteções orbitais,
    -- mas existe uma janela curta após arremessar para não quebrar imediatamente as
    -- próprias cascas/Cogs que ainda estão orbitando o usuário.
    if cog == nil or pos == nil then return false end
    radius = tonumber(radius) or 115
    local now = DKNow()

    -- Projétil Cog x Projétil Cog.
    if self.activeCogProjectiles ~= nil then
        for _, e in ipairs(self.activeCogProjectiles) do
            local other = e.cog
            if other ~= nil and other ~= cog and other.active == true and other.launched == true and other.pos ~= nil then
                if DKLength2D(pos, other.pos) <= radius then
                    self:DestroyCogInstance(ownerPlayerID, cog, "projectile_vs_projectile")
                    self:DestroyCogInstance(e.owner, other, "projectile_vs_projectile")
                    return true
                end
            end
        end
    end

    local orbitCollisionTime = tonumber(cog.orbit_collision_time or 0) or 0
    if now < orbitCollisionTime then
        return false
    end

    -- Projétil Cog x Cog orbitando jogador. Após a tolerância, vale para qualquer dono,
    -- inclusive o próprio usuário, igual às 3 cascas verdes orbitais do Mario Kart 64.
    -- Importante: Cogs que ainda estão orbitando nunca fazem essa checagem entre si;
    -- só um Cog realmente arremessado pode anular um Cog orbital.
    for otherOwnerID, data in pairs(self.activeCogs or {}) do
        for _, other in ipairs(data.cogs or {}) do
            if other ~= nil and other ~= cog and other.active == true and other.launched ~= true and other.pos ~= nil then
                if DKLength2D(pos, other.pos) <= radius then
                    self:DestroyCogInstance(ownerPlayerID, cog, "projectile_vs_orbit")
                    self:DestroyCogInstance(otherOwnerID, other, "projectile_vs_orbit")
                    return true
                end
            end
        end
    end

    return false
end


function DotaKartItemSystem:FindPowerCogHit(casterPlayerID, projectilePos, radius)
    if projectilePos == nil then return nil, nil end
    radius = tonumber(radius) or 145
    for ownerID, data in pairs(self.activeCogs or {}) do
        -- Projéteis não são bloqueados pelos Cogs do próprio caster.
        if tonumber(ownerID) ~= tonumber(casterPlayerID) then
            for _, cog in ipairs(data.cogs or {}) do
                if cog ~= nil and cog.active == true and cog.hooked_by_meat_hook ~= true and cog.pos ~= nil then
                    if DKLength2D(projectilePos, cog.pos) <= radius then
                        return tonumber(ownerID) or ownerID, cog
                    end
                end
            end
        end
    end
    return nil, nil
end

function DotaKartItemSystem:BlockProjectileWithPowerCog(casterPlayerID, projectilePos, radius, reason)
    -- FIX112: helper comum usado por Chaos Bolt, Swap Missile, Spectral Dagger e Sacred Arrow.
    -- Meat Hook usa uma reação especial: captura o Cog e o puxa para o próprio caster.
    local ownerID, cog = self:FindPowerCogHit(casterPlayerID, projectilePos, radius)
    if cog == nil then return false end
    self:DestroyCogInstance(ownerID, cog, reason or "projectile_blocked_by_cog")
    if self.config and self.config.debug then
        print("[DotaKartItems] Power Cog bloqueou projetil reason=" .. tostring(reason) .. " owner=" .. tostring(ownerID) .. " caster=" .. tostring(casterPlayerID))
    end
    return true
end

function DotaKartItemSystem:SpawnCogVisual(def, pos, yaw)
    local model = def.cog_model or "models/heroes/rattletrap/rattletrap_cog.vmdl"
    local ent = nil
    pcall(function()
        ent = SpawnEntityFromTableSynchronous("prop_dynamic", {
            model = model,
            DefaultAnim = "idle",
            solid = "0"
        })
    end)
    if ent ~= nil then
        ent:SetAbsOrigin(pos)
        if ent.SetAngles ~= nil then ent:SetAngles(0, yaw or 0, 0) end
    end
    return ent
end

function DotaKartItemSystem:RemoveCogVisual(cog)
    if cog == nil or cog.ent == nil then return end
    pcall(function() cog.ent:AddNoDraw() end)
    pcall(function() UTIL_Remove(cog.ent) end)
    pcall(function() cog.ent:RemoveSelf() end)
    cog.ent = nil
end

function DotaKartItemSystem:GetActiveCogCount(playerID)
    -- Conta só engrenagens ainda orbitando/guardadas. Engrenagem arremessada já foi gasta,
    -- mesmo continuando viva como projétil até acertar ou bater em obstáculo.
    local data = self.activeCogs and self.activeCogs[playerID]
    if data == nil then return 0 end
    local count = 0
    for _, cog in ipairs(data.cogs or {}) do
        if cog.active == true and cog.launched ~= true then count = count + 1 end
    end
    return count
end

function DotaKartItemSystem:UpdatePowerCogsHUD(playerID)
    local count = self:GetActiveCogCount(playerID)
    if count > 0 then
        self.itemCharges[playerID] = count
        self:SetHeldItemHUD(playerID, "item_blade_mail", count)
    else
        if self:GetHeldItem(playerID) == "item_blade_mail" then
            self.itemCharges[playerID] = nil
            self:SetHeldItemHUD(playerID, "", 0)
        end
    end
end

function DotaKartItemSystem:ClearPowerCogs(playerID, reason)
    local data = self.activeCogs and self.activeCogs[playerID]
    if data ~= nil then
        for _, cog in ipairs(data.cogs or {}) do
            self:RemoveCogVisual(cog)
        end
    end
    self.activeCogs[playerID] = nil
    if self:GetHeldItem(playerID) == "item_blade_mail" then
        self.itemCharges[playerID] = nil
        self:SetHeldItemHUD(playerID, "", 0)
    end
    if self.config and self.config.debug then
        print("[DotaKartItems] Power Cogs removido player " .. tostring(playerID) .. " reason=" .. tostring(reason))
    end
end

function DotaKartItemSystem:PushKartAwayFromPoint(sourcePos, targetPlayerID, target, pushDistance, stunDuration)
    if sourcePos == nil or not DKValidUnit(target) then return end
    local targetPos = target:GetAbsOrigin()
    local dir = targetPos - sourcePos
    dir.z = 0
    dir = self:NormalizeDir2D(dir)
    local dist = tonumber(pushDistance) or 420
    local finalPos = targetPos + dir * dist
    finalPos.z = GetGroundHeight(finalPos, target)
    target:SetAbsOrigin(finalPos)
    pcall(function() FindClearSpaceForUnit(target, finalPos, true) end)
    if targetPlayerID ~= nil and targetPlayerID >= 0 then
        self:ApplyKartStun(nil, target, stunDuration or 0.30)
        local st = self:GetState(targetPlayerID)
        if st ~= nil then st.speed = math.min(st.speed or 0, -120) end
    end
end

function DotaKartItemSystem:ShockCogTarget(ownerPlayerID, cog, targetPlayerID, target, def)
    if cog == nil or cog.active ~= true or not DKValidUnit(target) then return end
    if self:IsPlayerStarActive(targetPlayerID) then
        -- FIX91: Cogs que batem em kart com Black King Bar/Star são destruídos.
        cog.active = false
        self:UnregisterCogProjectile(cog)
        self:RemoveCogVisual(cog)
        self:UpdatePowerCogsHUD(ownerPlayerID)
        return
    end
    self:NotifyBattleHungerItemHit(ownerPlayerID, targetPlayerID)
    cog.active = false
    self:UnregisterCogProjectile(cog)
    -- FIX39: impacto em herói usa arquivos específicos hero01/02/03/lf + fallback genérico.
    self:EmitKartSound(target, def.sound_impact, target:GetAbsOrigin())
    local impactSounds = self:NormalizeSoundList(def.sound_impact)
    if #impactSounds > 0 then
        self:TryEmitUISoundServer(target, impactSounds[DKRandomInt(1, #impactSounds)])
    end
    self:PushKartAwayFromPoint(cog.pos or target:GetAbsOrigin(), targetPlayerID, target, def.shock_push or 520, def.shock_stun or 1.35)
    self:RemoveCogVisual(cog)
    self:UpdatePowerCogsHUD(ownerPlayerID)
end

function DotaKartItemSystem:DeployPowerCogs(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end

    local nowDeploy = DKNow()
    local duration = tonumber(def.duration or 0) or 0
    local expireTime = duration > 0 and (nowDeploy + duration) or 0
    self.activeCogs[playerID] = self.activeCogs[playerID] or { cogs = {}, startTime = nowDeploy, expireTime = expireTime, def = def }
    local data = self.activeCogs[playerID]
    data.cogs = {}
    data.startTime = nowDeploy
    data.expireTime = expireTime
    data.def = def

    local count = tonumber(def.cog_count) or 3
    local basePos = caster:GetAbsOrigin()
    for i = 1, count do
        local angle = ((i - 1) / count) * 360
        local rad = math.rad(angle)
        local pos = basePos + Vector(math.cos(rad), math.sin(rad), 0) * (def.orbit_radius or 175)
        pos.z = GetGroundHeight(pos, caster)
        local ent = self:SpawnCogVisual(def, pos, angle)
        table.insert(data.cogs, { active = true, ent = ent, angle = angle, pos = pos, launched = false })
    end

    self.itemCharges[playerID] = count
    self:SetHeldItemHUD(playerID, itemName, count)
    self:EmitKartSound(caster, def.sound_cast, caster:GetAbsOrigin())
    print("[DotaKartItems] Player " .. tostring(playerID) .. " ativou POWER COGS x" .. tostring(count))
    return true
end

function DotaKartItemSystem:LaunchOneCog(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end
    local data = self.activeCogs and self.activeCogs[playerID]
    if data == nil then return self:DeployPowerCogs(playerID, itemName, def) end

    local cog = nil
    for _, c in ipairs(data.cogs or {}) do
        if c.active == true and c.launched ~= true then cog = c; break end
    end
    if cog == nil then
        self:ClearPowerCogs(playerID, "no_cogs")
        return true
    end

    local dir, yaw, backward = self:GetFireDirectionForPlayer(playerID, caster)
    dir = self:NormalizeDir2D(dir)
    local launchNow = DKNow()
    cog.launched = true
    cog.owner = playerID
    cog.launch_time = launchNow
    cog.orbit_collision_time = launchNow + (tonumber(def.orbit_collision_grace or 0.65) or 0.65)
    cog.self_hit_time = launchNow + (tonumber(def.self_hit_grace or def.orbit_collision_grace or 0.65) or 0.65)
    local start = cog.pos or (caster:GetAbsOrigin() + dir * 120)
    local pos = Vector(start.x, start.y, GetGroundHeight(start, caster))
    local speed = tonumber(def.projectile_speed) or 2300
    local radius = tonumber(def.shock_radius) or 185
    local bounceRadius = tonumber(def.bounce_radius) or 105
    local bounceCooldown = tonumber(def.bounce_cooldown) or 0.10
    local lastBounce = -9999
    local serial = self:NextProjectileSerial()
    self:RegisterCogProjectile(playerID, cog)
    self:EmitKartSound(caster, def.sound_cast, pos)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartCogProjectile_" .. tostring(serial), function()
        if cog.active ~= true then
            self:UnregisterCogProjectile(cog)
            return nil
        end
        -- FIX112: se um Meat Hook capturou este Cog, o thinker do Hook assume o movimento.
        if cog.hooked_by_meat_hook == true then
            self:UnregisterCogProjectile(cog)
            return nil
        end
        local dt = 0.03
        local step = speed * dt
        local oldPos = Vector(pos.x, pos.y, pos.z)
        local oldGroundZ = GetGroundHeight(oldPos, nil)
        local nextPos = pos + dir * step
        local nextGroundZ = GetGroundHeight(nextPos, nil)
        nextPos.z = nextGroundZ
        local terrainRise = nextGroundZ - oldGroundZ
        local maxTerrainStepUp = tonumber(def.max_terrain_step_up) or 56
        local terrainBounced = false

        -- FIX127: an abrupt upward level/cliff is a wall for Cogs. Smooth ramps are
        -- still allowed because their height gain per 0.03s step stays below the threshold.
        if terrainRise > maxTerrainStepUp then
            local now = DKNow()
            if now - lastBounce >= bounceCooldown then
                dir = self:GetCogTerrainBounceDirection(oldPos, dir, step, maxTerrainStepUp)
                yaw = DKNormalizeYaw(math.deg(DKAtan2(dir.y, dir.x)))
                nextPos = oldPos + dir * step
                nextPos.z = GetGroundHeight(nextPos, nil)
                lastBounce = now
                terrainBounced = true
            else
                nextPos = oldPos
                terrainBounced = true
            end
        end

        -- FIX72: limite amplo do mapa/pista também conta como parede de Green Shell.
        -- Isso evita o Cog sumir/ficar perdido ao sair do retângulo do circuito.
        local boundaryDir = (not terrainBounced) and self:GetCogMapBoundaryBounce(nextPos, dir, 1000) or nil
        if boundaryDir ~= nil then
            local now = DKNow()
            if now - lastBounce >= bounceCooldown then
                dir = boundaryDir
                yaw = DKNormalizeYaw(math.deg(DKAtan2(dir.y, dir.x)))
                nextPos = oldPos + dir * step
                nextPos.z = GetGroundHeight(nextPos, nil)
                lastBounce = now
            else
                nextPos = oldPos
            end
        elseif (not terrainBounced) and (self:IsProjectileBlockedByWorld(nextPos, bounceRadius, playerID) or self:FindMinesBlockingPropHit(nextPos, bounceRadius, nil) ~= nil) then
            local now = DKNow()
            if now - lastBounce >= bounceCooldown then
                dir = self:GetCogBounceDirection(oldPos, dir, bounceRadius)
                yaw = DKNormalizeYaw(math.deg(DKAtan2(dir.y, dir.x)))
                nextPos = oldPos + dir * step
                nextPos.z = GetGroundHeight(nextPos, nil)
                lastBounce = now
            else
                nextPos = oldPos
            end
        end

        pos = nextPos
        cog.pos = pos
        if cog.ent ~= nil and not cog.ent:IsNull() then
            cog.ent:SetAbsOrigin(pos)
            if cog.ent.SetAngles ~= nil then cog.ent:SetAngles(0, yaw or 0, 0) end
        end

        if self:CheckCogProjectileCollision(playerID, cog, pos, radius * 0.85) then return nil end
        if self:HandleSpecialProjectileTargetHit(playerID,pos,radius,"power_cogs") then cog.active=false; self:UnregisterCogProjectile(cog); self:RemoveCogVisual(cog); self:UpdatePowerCogsHUD(playerID); return nil end

        local allowSelfHit = DKNow() >= (tonumber(cog.self_hit_time or 0) or 0)
        for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
            if tonumber(otherID) ~= tonumber(playerID) or allowSelfHit then
                local other = self:GetHeroForPlayer(otherID)
                if DKValidUnit(other) and not self:IsKartUntargetable(otherID) and DKLength2D(pos, other:GetAbsOrigin()) <= radius then
                    self:ShockCogTarget(playerID, cog, otherID, other, def)
                    return nil
                end
            end
        end

        return dt
    end, 0.03)

    self:UpdatePowerCogsHUD(playerID)
    print("[DotaKartItems] Player " .. tostring(playerID) .. " arremessou POWER COG Green-Shell " .. (backward and "para tras" or "para frente"))
    return true
end

function DotaKartItemSystem:UsePowerCogs(playerID, itemName, def)
    local data = self.activeCogs and self.activeCogs[playerID]
    if data == nil or self:GetActiveCogCount(playerID) <= 0 then
        return self:DeployPowerCogs(playerID, itemName, def)
    end
    return self:LaunchOneCog(playerID, itemName, def)
end

function DotaKartItemSystem:UpdatePowerCogs(now)
    for playerID, data in pairs(self.activeCogs or {}) do
        local caster = self:GetHeroForPlayer(playerID)
        local def = data.def or self.itemDefs.item_blade_mail or {}
        local expireTime = tonumber(data.expireTime or 0) or 0
        if not DKValidUnit(caster) or (expireTime > 0 and now >= expireTime) then
            self:ClearPowerCogs(playerID, "expired")
        else
            local basePos = caster:GetAbsOrigin()
            local activeCount = 0
            for i, cog in ipairs(data.cogs or {}) do
                if cog.active == true then
                    activeCount = activeCount + 1
                    if cog.launched ~= true then
                        cog.angle = (tonumber(cog.angle) or 0) + (tonumber(def.orbit_speed) or 145) * (self.config.tick_rate or 0.06)
                        local rad = math.rad(cog.angle)
                        local pos = basePos + Vector(math.cos(rad), math.sin(rad), 0) * (def.orbit_radius or 175)
                        pos.z = GetGroundHeight(pos, caster)
                        cog.pos = pos
                        if cog.ent ~= nil and not cog.ent:IsNull() then
                            cog.ent:SetAbsOrigin(pos)
                            if cog.ent.SetAngles ~= nil then cog.ent:SetAngles(0, cog.angle or 0, 0) end
                        end

                        if self:HandleSpecialProjectileTargetHit(playerID,pos,def.shock_radius or 185,"power_cogs_orbit") then cog.active=false; self:RemoveCogVisual(cog) end

                        for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
                            if tonumber(otherID) ~= tonumber(playerID) then
                                local other = self:GetHeroForPlayer(otherID)
                                if DKValidUnit(other) and DKLength2D(pos, other:GetAbsOrigin()) <= (def.shock_radius or 185) then
                                    self:ShockCogTarget(playerID, cog, otherID, other, def)
                                    break
                                end
                            end
                        end
                    end
                end
            end
            if activeCount <= 0 then
                self:ClearPowerCogs(playerID, "empty")
            end
        end
    end
end


-- ============================================================
-- FIX37: Frost Shield
-- Escudo do Lich robusto: VFX persistente no caster + pulso visível em área.
-- ============================================================
function DotaKartItemSystem:DestroyFrostShield(playerID, data)
    if data ~= nil then
        if data.fxs ~= nil and ParticleManager ~= nil then
            for _, fx in ipairs(data.fxs) do
                pcall(function()
                    ParticleManager:DestroyParticle(fx, false)
                    ParticleManager:ReleaseParticleIndex(fx)
                end)
            end
        elseif data.fx ~= nil and ParticleManager ~= nil then
            pcall(function()
                ParticleManager:DestroyParticle(data.fx, false)
                ParticleManager:ReleaseParticleIndex(data.fx)
            end)
        end
    end
    self.activeFrostShields[playerID] = nil
end

function DotaKartItemSystem:UpdateFrostChainParticleCP(fx, caster)
    if fx == nil or ParticleManager == nil or not DKValidUnit(caster) then return end
    local center = caster:GetAbsOrigin() + Vector(0,0,72)
    pcall(function()
        -- FIX113: CP0 fica realmente preso à entidade. Apenas SetParticleControl
        -- atualizava números do WORLDORIGIN, mas o lich_chain_frost_ continuava
        -- renderizando a esfera no ponto em que nasceu.
        ParticleManager:SetParticleControlEnt(fx, 0, caster, PATTACH_ABSORIGIN_FOLLOW, "", center, true)
        ParticleManager:SetParticleControl(fx, 1, center)
        ParticleManager:SetParticleControl(fx, 2, center)
        ParticleManager:SetParticleControl(fx, 3, center)
        ParticleManager:SetParticleControlForward(fx, 0, caster:GetForwardVector())
    end)
end

function DotaKartItemSystem:CreateFrostChainWorldFollow(particleName, caster, data)
    if particleName == nil or particleName == "" or ParticleManager == nil or not DKValidUnit(caster) or data == nil then return nil end
    local fx = nil
    local ok = pcall(function()
        -- FIX112: mantém WORLDORIGIN, que foi a variante confirmada visualmente no FIX110,
        -- mas passa o caster como owner e move CP0..CP4 manualmente a cada tick.
        fx = ParticleManager:CreateParticle(particleName, PATTACH_WORLDORIGIN, caster)
    end)
    if ok and fx ~= nil then
        data.fxs = data.fxs or {}
        data.frost_chain_world_fxs = data.frost_chain_world_fxs or {}
        table.insert(data.fxs, fx)
        table.insert(data.frost_chain_world_fxs, fx)
        self:UpdateFrostChainParticleCP(fx, caster)
    end
    return fx
end

function DotaKartItemSystem:CreateFrostChainAttached(particleName, caster, data)
    if particleName == nil or particleName == "" or ParticleManager == nil or not DKValidUnit(caster) or data == nil then return nil end
    local fx = nil
    local ok = pcall(function()
        fx = ParticleManager:CreateParticle(particleName, PATTACH_ABSORIGIN_FOLLOW, caster)
    end)
    if ok and fx ~= nil then
        data.fxs = data.fxs or {}
        table.insert(data.fxs, fx)
    end
    return fx
end

function DotaKartItemSystem:RefreshFrostChainWorldFollow(caster, data)
    if not DKValidUnit(caster) or data == nil then return end
    for _, fx in ipairs(data.frost_chain_world_fxs or {}) do
        self:UpdateFrostChainParticleCP(fx, caster)
    end
end

function DotaKartItemSystem:CreateFrostPulseVFX(particleName, caster, duration)
    if particleName == nil or particleName == "" or ParticleManager == nil or not DKValidUnit(caster) then return end
    local center = caster:GetAbsOrigin() + Vector(0,0,72)

    -- World-origin com CPs no kart.
    local worldFx = nil
    pcall(function()
        worldFx = ParticleManager:CreateParticle(particleName, PATTACH_WORLDORIGIN, nil)
        ParticleManager:SetParticleControl(worldFx, 0, center)
        ParticleManager:SetParticleControl(worldFx, 1, center)
        ParticleManager:SetParticleControl(worldFx, 2, center)
        ParticleManager:SetParticleControl(worldFx, 3, center)
    end)
    if worldFx ~= nil then
        GameRules:GetGameModeEntity():SetContextThink("DotaKartFrostPulseWorld_" .. tostring(worldFx), function()
            pcall(function()
                ParticleManager:DestroyParticle(worldFx, false)
                ParticleManager:ReleaseParticleIndex(worldFx)
            end)
            return nil
        end, tonumber(duration) or 0.85)
    end

    -- Segunda variante usando owner/attachment, sem os CPs de radius do antigo Frost Armor.
    local attachedFx = nil
    pcall(function()
        attachedFx = ParticleManager:CreateParticle(particleName, PATTACH_ABSORIGIN_FOLLOW, caster)
        ParticleManager:SetParticleControlEnt(attachedFx, 0, caster, PATTACH_ABSORIGIN_FOLLOW, "", caster:GetAbsOrigin(), true)
    end)
    if attachedFx ~= nil then
        GameRules:GetGameModeEntity():SetContextThink("DotaKartFrostPulseAttached_" .. tostring(attachedFx), function()
            pcall(function()
                ParticleManager:DestroyParticle(attachedFx, false)
                ParticleManager:ReleaseParticleIndex(attachedFx)
            end)
            return nil
        end, tonumber(duration) or 0.85)
    end
end

function DotaKartItemSystem:CreateFrostPulseRingVFX(particleName, caster, radius, duration)
    if particleName == nil or particleName == "" or ParticleManager == nil or not DKValidUnit(caster) then return end
    local raw = caster:GetAbsOrigin()
    local ground = Vector(raw.x, raw.y, GetGroundHeight(raw, caster) + 8)
    local life = tonumber(duration) or 1.0

    -- FIX114: esse particle do Ice Age não deve receber CP1/CP2 de raio do nosso
    -- helper genérico. Esses CPs estavam sobrescrevendo a configuração interna do
    -- VPCF e o anel não aparecia. Cria primeiro no chão usando SOMENTE CP0.
    local worldFx = nil
    pcall(function()
        worldFx = ParticleManager:CreateParticle(particleName, PATTACH_WORLDORIGIN, caster)
        ParticleManager:SetParticleControl(worldFx, 0, ground)
    end)
    if worldFx ~= nil then
        GameRules:GetGameModeEntity():SetContextThink("DotaKartFrostPulseRingWorld_" .. tostring(worldFx), function()
            pcall(function()
                ParticleManager:DestroyParticle(worldFx, false)
                ParticleManager:ReleaseParticleIndex(worldFx)
            end)
            return nil
        end, life)
    end

    -- Fallback preso ao caster, novamente sem alterar CPs internos além do CP0.
    local attachedFx = nil
    pcall(function()
        attachedFx = ParticleManager:CreateParticle(particleName, PATTACH_ABSORIGIN_FOLLOW, caster)
        ParticleManager:SetParticleControlEnt(attachedFx, 0, caster, PATTACH_ABSORIGIN_FOLLOW, "", raw, true)
    end)
    if attachedFx ~= nil then
        GameRules:GetGameModeEntity():SetContextThink("DotaKartFrostPulseRingAttached_" .. tostring(attachedFx), function()
            pcall(function()
                ParticleManager:DestroyParticle(attachedFx, false)
                ParticleManager:ReleaseParticleIndex(attachedFx)
            end)
            return nil
        end, life)
    end
end

function DotaKartItemSystem:AddFrostShieldPersistentVFX(caster, def, data)
    if not DKValidUnit(caster) then return end
    data.fxs = data.fxs or {}
    data.frost_chain_world_fxs = data.frost_chain_world_fxs or {}

    -- FIX112: restaura as duas estratégias do FIX110, versão em que a esfera apareceu.
    -- A world-origin agora tem o próprio caster como owner e seus CPs são movidos a cada 0.03s.
    self:CreateFrostChainAttached(def.particle_shield, caster, data)
    self:CreateFrostChainWorldFollow(def.particle_shield, caster, data)
end

function DotaKartItemSystem:UseFrostShield(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end

    local now = DKNow()
    local duration = tonumber(def.duration) or 8.0
    local old = self.activeFrostShields[playerID]
    if old ~= nil then self:DestroyFrostShield(playerID, old) end

    local data = {
        caster = caster,
        def = def,
        end_time = now + duration,
        next_pulse = now + 0.05,
        -- FIX109: reforço visual leve e periódico do MESMO particle solicitado.
        next_visual = now + 0.05,
        fxs = {},
        frost_chain_world_fxs = {}
    }

    self.activeFrostShields[playerID] = data
    self:AddFrostShieldPersistentVFX(caster, def, data)
    self:EmitFrostShieldSound(playerID, caster, def.sound_cast, caster:GetAbsOrigin())
    self:ConsumeHeldItem(playerID, itemName, def)
    print("[DotaKartItems] FIX109 Player " .. tostring(playerID) .. " ativou FROST SHIELD por " .. tostring(duration) .. "s")
    return true
end

function DotaKartItemSystem:FrostShieldVisualTick(playerID, data, now)
    local caster = data.caster or self:GetHeroForPlayer(playerID)
    local def = data.def or self.itemDefs.item_shivas_guard or {}
    if not DKValidUnit(caster) then return end

    -- FIX112: a esfera confirmada no FIX110 permanece WORLDORIGIN, mas seus CPs
    -- são reposicionados continuamente para acompanhar o kart.
    self:RefreshFrostChainWorldFollow(caster, data)
end

function DotaKartItemSystem:FrostShieldPulse(playerID, data, now)
    local caster = data.caster or self:GetHeroForPlayer(playerID)
    local def = data.def or self.itemDefs.item_shivas_guard or {}
    if not DKValidUnit(caster) then return end

    local casterPos = caster:GetAbsOrigin()
    local radius = tonumber(def.pulse_radius) or 800
    local hitCount = 0

    -- FIX109: cada pulso usa somente o explode solicitado, com variantes world + attached.
    for _, fx in ipairs(data.frost_chain_world_fxs or {}) do
        self:UpdateFrostChainParticleCP(fx, caster)
    end
    if def.particle_pulse ~= nil then
        self:CreateFrostPulseVFX(def.particle_pulse, caster, 0.85)
    end
    -- FIX113: Ice Age AoE ring também aparece visualmente em cada pulso.
    self:CreateFrostPulseRingVFX(
        def.particle_pulse_ring or "particles/units/heroes/hero_lich/lich_ice_age_dmg_aoe_ring.vpcf",
        caster,
        radius,
        0.9
    )
    self:EmitFrostShieldSound(playerID, caster, def.sound_pulse, casterPos)
    self:DestroyDoppelDecoysInRadius(playerID, casterPos, radius, "frost_shield_pulse")

    for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
        if tonumber(otherID) ~= tonumber(playerID) then
            local other = self:GetHeroForPlayer(otherID)
            if DKValidUnit(other) and not self:IsPlayerStarActive(otherID) and not self:IsKartUntargetable(otherID) and DKLength2D(casterPos, other:GetAbsOrigin()) <= radius then
                hitCount = hitCount + 1
                local slowDuration = tonumber(def.pulse_slow_duration) or 0.5
                self:ApplyKartSlow(caster, other, slowDuration, def.pulse_slow_pct or 0.35, 0, 0.03)
                -- FIX110: visual padrao de unidades congeladas/slow do Dota 2.
                pcall(function()
                    other:AddNewModifier(caster, nil, "modifier_dotakart_frost_pulse_visual", { duration = slowDuration })
                end)
                self:EmitFrostShieldSound(otherID, other, def.sound_pulse, other:GetAbsOrigin())
            end
        end
    end

    if self.config and self.config.debug then
        print("[DotaKartItems] FIX39 Frost Shield pulse player=" .. tostring(playerID) .. " hits=" .. tostring(hitCount))
    end
end

function DotaKartItemSystem:UpdateFrostShields(now)
    for playerID, data in pairs(self.activeFrostShields or {}) do
        local caster = data.caster or self:GetHeroForPlayer(playerID)
        local def = data.def or self.itemDefs.item_shivas_guard or {}
        if not DKValidUnit(caster) or now >= (data.end_time or 0) then
            self:DestroyFrostShield(playerID, data)
        else
            if now >= (data.next_visual or 0) then
                data.next_visual = now + 0.03
                self:FrostShieldVisualTick(playerID, data, now)
            end
            if now >= (data.next_pulse or 0) then
                data.next_pulse = now + (tonumber(def.pulse_interval) or 1.0)
                self:FrostShieldPulse(playerID, data, now)
            end
        end
    end
end

-- ============================================================
-- FIX54: Invisibilidade protege contra aquisição de projéteis teleguiados.
function DotaKartItemSystem:IsPlayerInvisible(playerID)
    playerID = tonumber(playerID)
    if playerID == nil then return false end
    local now = DKNow()
    local data = self.activeInvisibility and self.activeInvisibility[playerID]
    if data ~= nil and (data.end_time or 0) > now then return true end
    local doppel = self.activeDoppelwalkDecoys and self.activeDoppelwalkDecoys["owner_" .. tostring(playerID)]
    if doppel ~= nil and (doppel.end_time or 0) > now then return true end
    local shukuchi = self.activeShukuchi and self.activeShukuchi[playerID]
    if shukuchi ~= nil and now >= (shukuchi.invis_time or 0) and now < (shukuchi.end_time or 0) then return true end
    local hero = self:GetHeroForPlayer(playerID)
    if DKValidUnit(hero) then
        local invis = false
        pcall(function() if hero:IsInvisible() then invis = true end end)
        if invis then return true end
    end
    return false
end

function DotaKartItemSystem:IsHomingValidTarget(casterPlayerID, targetPlayerID)
    targetPlayerID = tonumber(targetPlayerID) or -1
    if targetPlayerID < 0 then return false end
    if targetPlayerID == tonumber(casterPlayerID) then return false end
    if self:IsPlayerStarActive(targetPlayerID) then return false end
    if self:IsKartUntargetable(targetPlayerID) then return false end
    if self:IsPlayerInvisible(targetPlayerID) then return false end
    local hero = self:GetHeroForPlayer(targetPlayerID)
    if not DKValidUnit(hero) then return false end
    local bad = false
    pcall(function() if hero:IsOutOfGame() then bad = true end end)
    pcall(function() if hero:IsInvulnerable() then bad = true end end)
    return not bad
end

-- FIX37: Chain Frost
-- Agora sempre cria projétil. Se não houver alvo inicial, o orbe segue em linha
-- para frente/trás e pode acertar o primeiro kart no caminho.
-- ============================================================
function DotaKartItemSystem:IsChainFrostValidTarget(casterPlayerID, candidateID, excludeImmediateID)
    candidateID = tonumber(candidateID) or -1
    if candidateID <= -1000 then
        if excludeImmediateID ~= nil and candidateID == tonumber(excludeImmediateID) then return false end
        local decoy = self:GetDoppelDecoyByTargetID(candidateID)
        return decoy ~= nil and tonumber(decoy.owner_player_id) ~= tonumber(casterPlayerID)
    end
    if candidateID < 0 then return false end
    if candidateID == tonumber(casterPlayerID) then return false end
    if excludeImmediateID ~= nil and candidateID == tonumber(excludeImmediateID) then return false end
    if self:IsPlayerStarActive(candidateID) then return false end
    if self:IsKartUntargetable(candidateID) then return false end
    if self:IsPlayerInvisible(candidateID) then return false end

    local hero = self:GetHeroForPlayer(candidateID)
    if not DKValidUnit(hero) then return false end

    local bad = false
    pcall(function() if hero:IsInvisible() then bad = true end end)
    pcall(function() if hero:IsOutOfGame() then bad = true end end)
    pcall(function() if hero:IsInvulnerable() then bad = true end end)
    if bad then return false end
    return true
end

function DotaKartItemSystem:FindChainFrostInitialTarget(casterPlayerID, startPos, dir, range)
    -- FIX48: Chain Frost inicial também respeita o arco da direção usada.
    -- Assim, ao lançar para frente, não vira 180 graus para perseguir um kart atrás.
    return self:FindNearestEnemyKartInArc(casterPlayerID, startPos, dir, range or 1200, 0.05)
end

function DotaKartItemSystem:FindChainFrostBounceTarget(casterPlayerID, fromPos, radius, lastHitID)
    local bestHero = nil
    local bestPlayerID = -1
    local bestDist = 999999
    radius = tonumber(radius) or 1200

    for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
        if self:IsChainFrostValidTarget(casterPlayerID, otherID, lastHitID) then
            local other = self:GetHeroForPlayer(otherID)
            local dist = DKLength2D(fromPos, other:GetAbsOrigin())
            if dist <= radius and dist < bestDist then
                bestHero = other
                bestPlayerID = tonumber(otherID) or -1
                bestDist = dist
            end
        end
    end

    for key, data in pairs(self.activeDoppelwalkDecoys or {}) do
        if type(key) == "number" and self:IsChainFrostValidTarget(casterPlayerID, key, lastHitID) then
            local unit = data and data.unit or nil
            if DKValidUnit(unit) then
                local dist = DKLength2D(fromPos, unit:GetAbsOrigin())
                if dist <= radius and dist < bestDist then
                    bestHero = unit
                    bestPlayerID = key
                    bestDist = dist
                end
            end
        end
    end

    return bestHero, bestPlayerID
end

function DotaKartItemSystem:ChainFrostImpact(casterPlayerID, caster, targetPlayerID, target, remainingBounces, def)
    if not DKValidUnit(caster) or not DKValidUnit(target) then return end
    if self:IsPlayerStarActive(targetPlayerID) or self:IsKartUntargetable(targetPlayerID) then return end

    -- FIX39: impacto em herói usa arquivos específicos hero01/02/03/lf + fallback genérico.
    self:EmitKartSound(target, def.sound_impact, target:GetAbsOrigin())
    local impactSounds = self:NormalizeSoundList(def.sound_impact)
    if #impactSounds > 0 then
        self:TryEmitUISoundServer(target, impactSounds[DKRandomInt(1, #impactSounds)])
    end
    if def.particle_impact ~= nil then
        self:CreateWorldParticle(def.particle_impact, target:GetAbsOrigin() + Vector(0, 0, 96), 1.0)
    end
    self:CreateDebuffVictimVisual(target, def, "chain", def.slow_duration or 2.5)
    self:ApplyKartSlow(caster, target, def.slow_duration or 2.5, def.slow_pct or 0.65, 0, 0.03)

    if remainingBounces > 1 then
        local impactPos = target:GetAbsOrigin() + Vector(0, 0, 96)
        local nextHero, nextID = self:FindChainFrostBounceTarget(casterPlayerID, impactPos, def.bounce_distance or 1200, targetPlayerID)
        if DKValidUnit(nextHero) then
            local serial = self:NextProjectileSerial()
            GameRules:GetGameModeEntity():SetContextThink("DotaKartChainFrostDelay_" .. tostring(serial), function()
                self:StartChainFrostProjectile(casterPlayerID, caster, impactPos, nextID, remainingBounces - 1, targetPlayerID, def)
                return nil
            end, def.bounce_delay or 0.2)
        end
    end
end

function DotaKartItemSystem:StartChainFrostProjectile(casterPlayerID, caster, fromPos, targetPlayerID, remainingBounces, lastHitID, def)
    local target = self:GetHomingTargetUnit(targetPlayerID)
    if not DKValidUnit(caster) or not DKValidUnit(target) then return end
    if remainingBounces <= 0 then return end

    local speed = tonumber(def.projectile_speed) or 1100
    local serial = self:NextProjectileSerial()
    local pos = Vector(fromPos.x, fromPos.y, fromPos.z or (GetGroundHeight(fromPos, nil) + 96))
    local targetPos = target:GetAbsOrigin() + Vector(0, 0, 96)
    local dir = self:NormalizeDir2D(targetPos - pos)
    local fx = self:CreateMissileParticle(def.particle, pos, dir, speed, def.visual_lookahead or 520)
    local lastTime = DKNow()
    local nextLoopSound = lastTime
    self:EmitChainFrostLoopSound(caster, def, pos)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartChainFrost_" .. tostring(serial), function()
        target = self:GetHomingTargetUnit(targetPlayerID)
        if not DKValidUnit(caster) then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            return nil
        end

        if not DKValidUnit(target) or not self:IsHomingValidTarget(casterPlayerID, targetPlayerID) then
            local newHero, newID = self:FindChainFrostBounceTarget(casterPlayerID, pos, def.bounce_distance or 1200, lastHitID)
            if DKValidUnit(newHero) then
                target = newHero
                targetPlayerID = newID
            else
                if fx ~= nil then self:DestroyLinearParticle(fx, false) end
                return nil
            end
        end

        local now = DKNow()
        local dt = math.max(0.001, math.min(0.05, now - lastTime))
        lastTime = now
        targetPos = target:GetAbsOrigin() + Vector(0, 0, 96)
        local desired = self:NormalizeDir2D(targetPos - pos)
        -- Homing forte: visual e colisão seguem sempre o alvo atual.
        dir = self:NormalizeDir2D(dir * 0.18 + desired * 0.82)
        local dist = DKLength2D(pos, targetPos)
        local step = speed * dt

        if dist <= math.max(step, tonumber(def.hit_radius) or 180) then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            if tonumber(targetPlayerID) and tonumber(targetPlayerID)<=-1000 then local decoy=self:GetDoppelDecoyByTargetID(targetPlayerID); if decoy then self:DestroyDoppelDecoy(decoy,"chain_frost") end else self:ChainFrostImpact(casterPlayerID,caster,targetPlayerID,target,remainingBounces,def) end
            return nil
        end

        pos = pos + dir * step
        pos.z = GetGroundHeight(pos, nil) + 96
        self:UpdateMissileParticle(fx, pos, dir, speed, def.visual_lookahead or 520)
        if now >= (nextLoopSound or 0) then
            nextLoopSound = now + 0.65
            self:EmitChainFrostLoopSound(caster, def, pos)
        end
        return 0.02
    end, 0.02)
end

function DotaKartItemSystem:StartChainFrostLinearProjectile(casterPlayerID, caster, startPos, dir, remainingBounces, def)
    if not DKValidUnit(caster) then return end
    local range = tonumber(def.cast_range) or 1200
    local speed = tonumber(def.projectile_speed) or 1100
    local radius = tonumber(def.hit_radius) or 180
    local serial = self:NextProjectileSerial()
    local pos = Vector(startPos.x, startPos.y, startPos.z)
    local startTime = DKNow()
    local lastTime = startTime
    local traveled = 0
    dir = self:NormalizeDir2D(dir)
    local fx = self:CreateMissileParticle(def.particle, pos, dir, speed, def.visual_lookahead or 520)
    local nextLoopSound = DKNow()
    self:EmitChainFrostLoopSound(caster, def, pos)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartChainFrostLine_" .. tostring(serial), function()
        if not DKValidUnit(caster) then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            return nil
        end

        -- Se algum adversário entrar no range de busca, o projétil deixa de ser linear e passa a perseguir.
        local nearHero, nearID, nearDist = self:FindNearestEnemyKartInArc(casterPlayerID, pos, dir, range, def.homing_front_dot or 0.05)
        if DKValidUnit(nearHero) and self:IsChainFrostValidTarget(casterPlayerID, nearID, nil) then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            self:StartChainFrostProjectile(casterPlayerID, caster, pos, nearID, remainingBounces, nil, def)
            return nil
        end

        local now = DKNow()
        local dt = math.max(0.001, math.min(0.05, now - lastTime))
        lastTime = now
        local step = speed * dt
        traveled = traveled + step
        pos = pos + dir * step
        pos.z = GetGroundHeight(pos, nil) + 96
        self:UpdateMissileParticle(fx, pos, dir, speed, def.visual_lookahead or 520)
        if now >= (nextLoopSound or 0) then
            nextLoopSound = now + 0.65
            self:EmitChainFrostLoopSound(caster, def, pos)
        end

        if self:HandleSpecialProjectileTargetHit(casterPlayerID, pos, radius, "chain_frost") then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            return nil
        end

        for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
            if self:IsChainFrostValidTarget(casterPlayerID, otherID, nil) then
                local other = self:GetHeroForPlayer(otherID)
                if DKValidUnit(other) and DKLength2D(pos, other:GetAbsOrigin()) <= radius then
                    if fx ~= nil then self:DestroyLinearParticle(fx, false) end
                    self:ChainFrostImpact(casterPlayerID, caster, otherID, other, remainingBounces, def)
                    return nil
                end
            end
        end

        if traveled >= range or (now - startTime) >= (range / math.max(1, speed) + 0.2) then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            return nil
        end
        return 0.02
    end, 0.02)
end

function DotaKartItemSystem:UseChainFrost(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end

    local dir, yaw, backward = self:GetFireDirectionForPlayer(playerID, caster)
    dir = self:NormalizeDir2D(dir)
    local start = caster:GetAbsOrigin() + dir * 120 + Vector(0, 0, 96)
    local target, targetPlayerID = self:FindChainFrostInitialTarget(playerID, start, dir, def.cast_range or 1200)

    self:EmitKartSound(caster, def.sound_cast, start)
    self:ConsumeHeldItem(playerID, itemName, def)

    if DKValidUnit(target) then
        self:StartChainFrostProjectile(playerID, caster, start, targetPlayerID, def.max_bounces or 10, nil, def)
        print("[DotaKartItems] FIX39 Player " .. tostring(playerID) .. " lançou CHAIN FROST " .. (backward and "para tras" or "para frente") .. " target=" .. tostring(targetPlayerID))
    else
        self:StartChainFrostLinearProjectile(playerID, caster, start, dir, def.max_bounces or 10, def)
        print("[DotaKartItems] FIX39 CHAIN FROST sem alvo inicial: projétil linear criado range=" .. tostring(def.cast_range or 1200))
    end
    return true
end


function DotaKartItemSystem:IsProjectileBlockedByWorld(pos, radius, ownerPlayerID)
    if pos == nil then return false end
    radius = tonumber(radius) or 90

    if self:CheckIceShardProjectileCollision(pos, radius, ownerPlayerID) then
        return true
    end

    if GridNav == nil then return false end

    local blocked = false
    pcall(function()
        if GridNav:IsBlocked(pos) then blocked = true end
    end)
    -- Não usamos IsTraversable por padrão porque pistas de corrida custom podem ficar fora da navmesh,
    -- e isso faria o míssil cancelar mesmo no asfalto. IsBlocked + árvore cobre melhor obstáculos reais.
    pcall(function()
        if GridNav:IsNearbyTree(pos, radius, true) then blocked = true end
    end)

    return blocked
end

function DotaKartItemSystem:FindNearestEnemyKart(casterPlayerID, pos, radius)
    radius = tonumber(radius) or 4200
    local bestHero = nil
    local bestPlayerID = -1
    local bestDist = 999999

    for _, playerID in ipairs(self:GetRegisteredPlayerIDs()) do
        if tonumber(playerID) ~= tonumber(casterPlayerID) then
            local hero = self:GetHeroForPlayer(playerID)
            if DKValidUnit(hero) and not self:IsPlayerStarActive(playerID) and not self:IsPlayerInvisible(playerID) and not self:IsKartUntargetable(playerID) then
                local hp = hero:GetAbsOrigin()
                local dx = hp.x - pos.x
                local dy = hp.y - pos.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist > 1 and dist <= radius and dist < bestDist then
                    bestHero = hero
                    bestPlayerID = tonumber(playerID) or -1
                    bestDist = dist
                end
            end
        end
    end

    for key,data in pairs(self.activeDoppelwalkDecoys or {}) do
        if type(key)=="number" and data and tonumber(data.owner_player_id)~=tonumber(casterPlayerID) and DKValidUnit(data.unit) then
            local dist=DKLength2D(pos,data.unit:GetAbsOrigin())
            if dist>1 and dist<=radius and dist<bestDist then bestHero=data.unit; bestPlayerID=data.target_id; bestDist=dist end
        end
    end
    return bestHero, bestPlayerID, bestDist
end

function DotaKartItemSystem:FindNearestEnemyKartInArc(casterPlayerID, pos, dir, radius, minDot)
    -- FIX48: projeteis teleguiados nao devem dar meia-volta para perseguir alvo no sentido contrario.
    -- O alvo precisa estar dentro do arco da direcao usada no disparo.
    if pos == nil then return nil, -1, 999999 end
    dir = self:NormalizeDir2D(dir or Vector(1, 0, 0))
    radius = tonumber(radius) or 4200
    minDot = tonumber(minDot)
    if minDot == nil then minDot = 0.05 end

    local bestHero = nil
    local bestPlayerID = -1
    local bestDist = 999999
    for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
        if tonumber(otherID) ~= tonumber(casterPlayerID) then
            local other = self:GetHeroForPlayer(otherID)
            if DKValidUnit(other) and not self:IsPlayerStarActive(otherID) and not self:IsPlayerInvisible(otherID) and not self:IsKartUntargetable(otherID) then
                local toTarget = other:GetAbsOrigin() - pos
                local dist = DKLength2D(pos, other:GetAbsOrigin())
                if dist <= radius then
                    local toDir = self:NormalizeDir2D(toTarget)
                    local dot = (toDir.x * dir.x) + (toDir.y * dir.y)
                    if dot >= minDot and dist < bestDist then
                        bestHero = other
                        bestPlayerID = tonumber(otherID) or -1
                        bestDist = dist
                    end
                end
            end
        end
    end
    for key,data in pairs(self.activeDoppelwalkDecoys or {}) do
        if type(key)=="number" and data and tonumber(data.owner_player_id)~=tonumber(casterPlayerID) and DKValidUnit(data.unit) then
            local toTarget=data.unit:GetAbsOrigin()-pos; local dist=DKLength2D(pos,data.unit:GetAbsOrigin())
            if dist<=radius then local toDir=self:NormalizeDir2D(toTarget); local dot=(toDir.x*dir.x)+(toDir.y*dir.y); if dot>=minDot and dist<bestDist then bestHero=data.unit; bestPlayerID=data.target_id; bestDist=dist end end
        end
    end
    return bestHero, bestPlayerID, bestDist
end

function DotaKartItemSystem:FindHomingTarget(casterPlayerID, pos, dir, radius, frontDot)
    return self:FindNearestEnemyKartInArc(casterPlayerID, pos, dir, radius or 4200, frontDot or 0.05)
end

function DotaKartItemSystem:NormalizeDir2D(v)
    if v == nil then return Vector(1,0,0) end
    local len = math.sqrt((v.x or 0) * (v.x or 0) + (v.y or 0) * (v.y or 0))
    if len <= 0.001 then return Vector(1,0,0) end
    return Vector(v.x / len, v.y / len, 0)
end

function DotaKartItemSystem:AcquireSwapMissileTarget(casterPlayerID, caster, startPos, dir, range, frontDot)
    if not DKValidUnit(caster) then return nil, -1 end
    return self:FindNearestEnemyKartInArc(casterPlayerID, startPos or caster:GetAbsOrigin(), dir, range or 4800, frontDot or 0.05)
end

function DotaKartItemSystem:SwapKartPositions(casterPlayerID, caster, targetPlayerID, target, stunDuration)
    if not DKValidUnit(caster) or not DKValidUnit(target) then return end
    if self:IsPlayerStarActive(targetPlayerID) or self:IsKartUntargetable(targetPlayerID) then return end

    local casterSt = self:GetState(casterPlayerID)
    local savedSpeed = casterSt and casterSt.speed or nil
    local savedYaw = casterSt and casterSt.yaw or nil
    local savedBoostUntil = casterSt and casterSt.boost_until or nil
    local savedItemMaxUntil = casterSt and casterSt.item_max_speed_until or nil
    local savedItemMaxSpeed = casterSt and casterSt.item_max_speed or nil

    -- FIX121: Swap Missile is a legitimate instantaneous relocation and must not
    -- be mistaken for an illegal dk_track_* skip by the anti-skip system.
    local antiSkip = GameRules and GameRules.DotaKartAntiSkip or nil
    if antiSkip ~= nil and antiSkip.AuthorizeTeleport ~= nil then
        pcall(function() antiSkip:AuthorizeTeleport(casterPlayerID, 1.5) end)
        pcall(function() antiSkip:AuthorizeTeleport(targetPlayerID, 1.5) end)
    end

    local casterPos = caster:GetAbsOrigin()
    local targetPos = target:GetAbsOrigin()
    local newCaster = Vector(targetPos.x, targetPos.y, GetGroundHeight(targetPos, caster))
    local newTarget = Vector(casterPos.x, casterPos.y, GetGroundHeight(casterPos, target))

    caster:SetAbsOrigin(newCaster)
    target:SetAbsOrigin(newTarget)
    pcall(function() FindClearSpaceForUnit(caster, newCaster, true) end)
    pcall(function() FindClearSpaceForUnit(target, newTarget, true) end)

    -- FIX72: o usuário do Swap Missile não deve perder velocidade/boost após trocar posição.
    if casterSt ~= nil then
        casterSt.speed = savedSpeed or casterSt.speed or 0
        casterSt.yaw = savedYaw or casterSt.yaw
        casterSt.boost_until = savedBoostUntil or casterSt.boost_until
        casterSt.item_max_speed_until = savedItemMaxUntil or casterSt.item_max_speed_until
        casterSt.item_max_speed = savedItemMaxSpeed or casterSt.item_max_speed
        casterSt.locked_until = 0
    end

    self:ApplyMiniStun(caster, target, stunDuration or 0.5)
end

function DotaKartItemSystem:UseSwapMissile(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end

    local dir, yaw, backward = self:GetFireDirectionForPlayer(playerID, caster)
    dir = self:NormalizeDir2D(dir)

    local start = caster:GetAbsOrigin() + dir * 120 + Vector(0, 0, 96)
    local pos = Vector(start.x, start.y, start.z)
    local range = tonumber(def.cast_range) or 3000
    local speed = tonumber(def.speed) or 1800

    -- FIX31: trava no kart adversário mais próximo no momento do disparo.
    -- Se outro ficar mais perto durante o voo, reaquisição também é permitida.
    local arcDot = tonumber(def.homing_front_dot) or 0.05
    local lockedTarget, lockedPlayerID = self:AcquireSwapMissileTarget(playerID, caster, start, dir, def.acquire_range or 4800, arcDot)
    if DKValidUnit(lockedTarget) then
        dir = self:NormalizeDir2D((lockedTarget:GetAbsOrigin() + Vector(0, 0, 72)) - start)
    end

    local radius = tonumber(def.hit_radius) or 155
    local serial = self:NextProjectileSerial()
    local startTime = DKNow()
    local lastTime = startTime
    local maxTime = range / math.max(1, speed)
    local traveled = 0

    -- FIX31: vengeful_magic_missle.vpcf fica alinhado melhor com CP1 como alvo/ponto final.
    local missileFx = self:CreateMissileParticle(def.particle, pos, dir, speed, def.visual_lookahead or 520)

    self:EmitKartSound(caster, def.sound_fire, pos)
    self:ConsumeHeldItem(playerID, itemName, def)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartSwapMissile_" .. tostring(serial), function()
        if not DKValidUnit(caster) then
            if missileFx ~= nil then self:DestroyLinearParticle(missileFx, false) end
            return nil
        end

        local now = DKNow()
        local dt = math.max(0.001, math.min(0.05, now - lastTime))
        lastTime = now

        if not DKValidUnit(lockedTarget) or not self:IsHomingValidTarget(playerID, lockedPlayerID) then
            lockedTarget, lockedPlayerID = self:FindNearestEnemyKartInArc(playerID, pos, dir, def.homing_radius or 4200, arcDot)
        else
            local dLocked = DKLength2D(pos, lockedTarget:GetAbsOrigin())
            if dLocked > (def.homing_radius or 4200) then
                lockedTarget, lockedPlayerID = self:FindNearestEnemyKartInArc(playerID, pos, dir, def.homing_radius or 4200, arcDot)
            else
                -- Reaquisição para o adversário realmente mais próximo, se ele estiver bem mais perto.
                local nearHero, nearID, nearDist = self:FindNearestEnemyKartInArc(playerID, pos, dir, def.homing_radius or 4200, arcDot)
                if DKValidUnit(nearHero) and nearID ~= lockedPlayerID and nearDist < dLocked * 0.72 then
                    lockedTarget = nearHero
                    lockedPlayerID = nearID
                end
            end
        end

        if DKValidUnit(lockedTarget) then
            local targetPos = lockedTarget:GetAbsOrigin() + Vector(0, 0, 72)
            local desired = self:NormalizeDir2D(targetPos - pos)
            local strength = DKClamp(def.homing_strength or 0.88, 0, 0.95)
            dir = self:NormalizeDir2D(dir * (1 - strength) + desired * strength)
        end

        local step = speed * dt
        traveled = traveled + step
        pos = pos + dir * step
        pos.z = GetGroundHeight(pos, nil) + 96
        self:UpdateMissileParticle(missileFx, pos, dir, speed, def.visual_lookahead or 520)

        if self:BlockProjectileWithPowerCog(playerID, pos, radius * 0.90, "swap_missile_blocked") then
            if missileFx ~= nil then self:DestroyLinearParticle(missileFx, false) end
            return nil
        end

        -- Obstáculos/árvores anulam o efeito. Ignora os primeiros metros para não bater no próprio caster.
        if traveled > 220 and self:IsProjectileBlockedByWorld(pos, def.obstacle_check_radius or 90) then
            if missileFx ~= nil then self:DestroyLinearParticle(missileFx, false) end
            if self.config and self.config.debug then
                print("[DotaKartItems] Swap Missile bateu em obstaculo/arvore e foi anulado.")
            end
            return nil
        end

        if self:HandleSpecialProjectileTargetHit(playerID,pos,radius,"swap_missile") then if missileFx~=nil then self:DestroyLinearParticle(missileFx,false) end; return nil end
        local target, targetPlayerID = self:FindHeroHit(playerID, pos, radius)
        if DKValidUnit(target) then
            if missileFx ~= nil then self:DestroyLinearParticle(missileFx, false) end
            self:EmitKartSound(target, def.sound_impact, pos)
            if backward then
                -- FIX48: Swap Missile usado para tras nao troca posicao; funciona como missil/stun defensivo.
                self:ApplyMiniStun(caster, target, def.stun_duration or 0.5)
                print("[DotaKartItems] Swap Missile para tras acertou player " .. tostring(targetPlayerID) .. "; sem troca de posicao.")
            else
                self:EmitKartSound(caster, def.sound_swap, pos)
                self:SwapKartPositions(playerID, caster, targetPlayerID, target, def.stun_duration or 0.5)
                print("[DotaKartItems] Swap Missile acertou player " .. tostring(targetPlayerID) .. " e trocou posicoes.")
            end
            return nil
        end

        if now - startTime >= maxTime or traveled >= range then
            if missileFx ~= nil then self:DestroyLinearParticle(missileFx, false) end
            return nil
        end

        return 0.02
    end, 0.02)

    print("[DotaKartItems] Player " .. tostring(playerID) .. " lançou SWAP MISSILE " .. (backward and "para tras" or "para frente") .. " target=" .. tostring(lockedPlayerID or -1))
    return true
end



-- ============================================================
-- FIX72: Burrowstrike + Nature's Grasp / Root
-- ============================================================
function DotaKartItemSystem:CreateBurrowstrikeTrailFx(def, pos, dir, duration)
    if def == nil or pos == nil then return end
    duration = tonumber(duration) or tonumber(def.visual_duration) or 0.65
    dir = self:NormalizeDir2D(dir or Vector(1,0,0))
    local right = Vector(-dir.y, dir.x, 0)
    local base = Vector(pos.x, pos.y, GetGroundHeight(pos, nil) + 12)

    -- FIX73: Sand King Burrowstrike particles nem sempre desenham linha quando tratados
    -- como projétil linear genérico. Criamos marcas curtas ao longo da trajetória, com CPs
    -- mais completos, para formar uma linha visível na pista.
    local particles = {
        { name = def.particle_ground, z = 4, radius = 135 },
        { name = def.particle_low,    z = 28, radius = 110 },
        { name = def.particle_mid,    z = 56, radius = 95  }
    }

    for _, data in ipairs(particles) do
        if data.name ~= nil and data.name ~= "" and ParticleManager ~= nil then
            local fx = nil
            local p = base + Vector(0,0,data.z or 0)
            local ok = pcall(function()
                fx = ParticleManager:CreateParticle(data.name, PATTACH_WORLDORIGIN, nil)
                ParticleManager:SetParticleControl(fx, 0, p)
                ParticleManager:SetParticleControl(fx, 1, p + dir * 120)
                ParticleManager:SetParticleControl(fx, 2, Vector(data.radius or 120, 0, 0))
                ParticleManager:SetParticleControl(fx, 3, p - dir * 60)
                ParticleManager:SetParticleControl(fx, 4, p + dir * 60)
                ParticleManager:SetParticleControl(fx, 5, p + right * 40)
                ParticleManager:SetParticleControlForward(fx, 0, dir)
            end)
            if ok and fx ~= nil then
                GameRules:GetGameModeEntity():SetContextThink("DKBurrowTrailRelease_" .. tostring(fx), function()
                    pcall(function()
                        ParticleManager:DestroyParticle(fx, false)
                        ParticleManager:ReleaseParticleIndex(fx)
                    end)
                    return nil
                end, duration)
            end
        end
    end
end

function DotaKartItemSystem:PlayBurrowstrikeCastSound(playerID, caster, def, pos)
    -- FIX74: som do Burrowstrike agora usa um soundevent customizado do addon
    -- como primeira opcao. Raw .vsnd direto falhava em algumas builds.
    local origin = pos or (DKValidUnit(caster) and caster:GetAbsOrigin() or nil)
    self:EmitKartWorldSound(caster, def and def.sound_cast, origin)

    if DKValidUnit(caster) and self.TryEmitUISoundServer ~= nil then
        self:TryEmitUISoundServer(caster, "dotakart_burrowstrike_cast")
        self:TryEmitUISoundServer(caster, "Hero_SandKing.BurrowStrike")
        self:TryEmitUISoundServer(caster, "sounds/weapons/hero/sand_king/sand_king_burrow_attack.vsnd")
    end

    -- Fallback 2D para o usuario do item: se o 3D/raw falhar, pelo menos o caster ouve.
    if tonumber(playerID) ~= nil and self.SendUISoundToPlayer ~= nil then
        self:SendUISoundToPlayer(tonumber(playerID), "dotakart_burrowstrike_cast", "play", 0)
    end
end

function DotaKartItemSystem:IsOfficialPathPosition(pos)
    if pos == nil then return false end
    if self.controller ~= nil then
        if self.controller.IsPositionInsideTrackSkip ~= nil then
            local okSkip, skip = pcall(function() return self.controller:IsPositionInsideTrackSkip(pos) end)
            if okSkip and skip == true then return true end
        end
        if self.controller.IsGridNavWardBlockPenaltyTile ~= nil then
            local okWard, wardPenalty = pcall(function() return self.controller:IsGridNavWardBlockPenaltyTile(pos) end)
            if okWard and wardPenalty == true then return false end
        end
        if self.controller.IsPositionOnOfficialPath ~= nil then
            local ok, result = pcall(function() return self.controller:IsPositionOnOfficialPath(pos) end)
            if ok and result == true then return true end
        end
    end
    if GridNav == nil or GridNav.IsTraversable == nil then return false end
    local traversable = false
    local blocked = false
    local ok = pcall(function() traversable = GridNav:IsTraversable(pos) == true end)
    if not ok or traversable ~= true then return false end
    if GridNav.IsBlocked ~= nil then pcall(function() blocked = GridNav:IsBlocked(pos) == true end) end
    return blocked ~= true
end

function DotaKartItemSystem:CheckBurrowstrikeBoxPickup(playerID, caster, pos, radius)
    if pos == nil or not DKValidUnit(caster) then return false end
    if not self:PlayerCanReceiveItem(playerID) then return false end
    local box = self:FindBoxHit(pos, radius or (self.config.pickup_radius or 185))
    if box ~= nil then
        self:OnPickupBox(playerID, caster, box)
        print("[DotaKartItems] FIX97 Burrowstrike coletou caixa no caminho player " .. tostring(playerID))
        return true
    end
    return false
end

function DotaKartItemSystem:IsSafeBurrowDestination(caster, origin, pos, dir, radius)
    if pos == nil then return false end
    radius = tonumber(radius) or 130
    dir = self:NormalizeDir2D(dir or Vector(1,0,0))

    -- FIX99: revert do FIX97/98 para Burrowstrike.
    -- Off-road/Block Wards continuam funcionando no kart_controller, mas Burrowstrike volta a
    -- respeitar árvore/highground/bloqueio real ao escolher o ponto final seguro. Portanto o
    -- destino final pode ser reduzido novamente se a linha terminar em área insegura.
    -- A coleta de caixa no caminho permanece ativa e não altera o destino.

    if self.controller ~= nil and self.controller.IsWorldCollisionBlocked ~= nil then
        local blocked = false
        local ok, result = pcall(function() return self.controller:IsWorldCollisionBlocked(pos, caster, origin, dir) end)
        if ok then blocked = result == true end
        if blocked then return false end
    end

    if GridNav ~= nil then
        local blocked = false
        pcall(function() if GridNav:IsBlocked(pos) then blocked = true end end)
        pcall(function() if GridNav:IsNearbyTree(pos, radius, true) then blocked = true end end)
        if blocked then return false end
    end

    local right = Vector(-dir.y, dir.x, 0)
    for _, probe in ipairs({ pos + right * radius, pos - right * radius, pos + dir * radius }) do
        if self.controller ~= nil and self.controller.IsWorldCollisionBlocked ~= nil then
            local blocked = false
            local ok, result = pcall(function() return self.controller:IsWorldCollisionBlocked(probe, caster, origin, dir) end)
            if ok then blocked = result == true end
            if blocked then return false end
        end
        if GridNav ~= nil then
            local blocked = false
            pcall(function() if GridNav:IsBlocked(probe) then blocked = true end end)
            pcall(function() if GridNav:IsNearbyTree(probe, radius * 0.75, true) then blocked = true end end)
            if blocked then return false end
        end
    end

    return true
end

function DotaKartItemSystem:FindSafeBurrowEnd(caster, startPos, dir, maxRange, def)
    dir = self:NormalizeDir2D(dir or Vector(1,0,0))
    local step = tonumber(def and def.safe_step) or 80
    local radius = tonumber(def and def.safe_radius) or 130
    local minRange = 180
    local r = tonumber(maxRange) or 1000
    while r >= minRange do
        local p = startPos + dir * r
        p.z = GetGroundHeight(p, caster)
        if self:IsSafeBurrowDestination(caster, startPos, p, dir, radius) then
            return p, r
        end
        r = r - step
    end
    local p = startPos + dir * minRange
    p.z = GetGroundHeight(p, caster)
    return p, minRange
end

function DotaKartItemSystem:ApplyBurrowKnockup(caster, targetPlayerID, target, def)
    if not DKValidUnit(target) then return end
    if self:IsPlayerStarActive(targetPlayerID) or self:IsKartUntargetable(targetPlayerID) then return end
    local casterPlayerID = self:GetPlayerIDForHero(caster)
    if casterPlayerID ~= nil and casterPlayerID >= 0 then
        self:NotifyBattleHungerItemHit(casterPlayerID, targetPlayerID)
    end
    local stun = tonumber(def.stun_duration) or 1.0
    local airDur = tonumber(def.knockup_duration) or 0.52
    local height = tonumber(def.knockup_height) or 350
    local now = DKNow()

    if self.controller ~= nil and self.controller.SetKartStunned ~= nil then
        self.controller:SetKartStunned(targetPlayerID, stun)
        local st = self.controller.GetState ~= nil and self.controller:GetState(targetPlayerID) or nil
        if st ~= nil then st.burrow_airborne_until = math.max(st.burrow_airborne_until or 0, now + airDur) end
    else
        pcall(function() target:AddNewModifier(caster or target, nil, "modifier_stunned", { duration = stun }) end)
    end
    pcall(function() target:AddNewModifier(caster or target, nil, "modifier_dotakart_burrow_airborne", { duration = airDur }) end)

    local base = target:GetAbsOrigin()
    local serial = self:NextProjectileSerial()
    local startTime = now
    GameRules:GetGameModeEntity():SetContextThink("DotaKartBurrowKnockup_" .. tostring(serial), function()
        if not DKValidUnit(target) then return nil end
        local tnow = DKNow()
        local t = DKClamp((tnow - startTime) / math.max(0.01, airDur), 0, 1)
        local ground = GetGroundHeight(base, target)
        local z = ground + math.sin(math.pi * t) * height
        target:SetAbsOrigin(Vector(base.x, base.y, z))
        if tnow >= startTime + airDur then
            local final = Vector(base.x, base.y, GetGroundHeight(base, target))
            target:SetAbsOrigin(final)
            return nil
        end
        return 0.03
    end, 0.03)
end

function DotaKartItemSystem:UseBurrowstrike(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end
    local dir, yaw, backward = self:GetFireDirectionForPlayer(playerID, caster)
    dir = self:NormalizeDir2D(dir)
    local startGround = caster:GetAbsOrigin()
    startGround.z = GetGroundHeight(startGround, caster)
    local start = startGround + Vector(0,0,24)
    local endPos, safeRange = self:FindSafeBurrowEnd(caster, startGround, dir, def.cast_range or 1000, def)
    local speed = tonumber(def.speed) or 2000
    local radius = tonumber(def.hit_radius) or 150
    local serial = self:NextProjectileSerial()
    local startTime = DKNow()
    local maxTime = safeRange / math.max(1, speed)
    local hit = {}
    local oldSpeed = nil
    local st = self:GetState(playerID)
    if st ~= nil then oldSpeed = st.speed end

    -- Mantém a tentativa de linha original, mas o visual confiável agora é criado
    -- por marcas curtas ao longo da trajetória em CreateBurrowstrikeTrailFx().
    local fxs = {}
    for _, particleName in ipairs({ def.particle_ground, def.particle_low, def.particle_mid }) do
        local fx = self:CreateLinearParticle(particleName, start, start)
        if fx ~= nil then table.insert(fxs, fx) end
    end

    self:PlayBurrowstrikeCastSound(playerID, caster, def, startGround)
    self:CreateBurrowstrikeTrailFx(def, startGround, dir, def.visual_duration or 0.65)
    self:ConsumeHeldItem(playerID, itemName, def)

    local lastVisualDist = 0
    local visualStep = tonumber(def.visual_step) or 90

    GameRules:GetGameModeEntity():SetContextThink("DotaKartBurrowstrike_" .. tostring(serial), function()
        if not DKValidUnit(caster) then
            for _, fx in ipairs(fxs) do self:DestroyLinearParticle(fx, false) end
            return nil
        end
        local now = DKNow()
        local traveled = math.min(safeRange, (now - startTime) * speed)
        local p = startGround + dir * traveled
        p.z = GetGroundHeight(p, caster) + 24
        for _, fx in ipairs(fxs) do self:UpdateLinearParticle(fx, start, p) end

        if traveled <= 1 or traveled - lastVisualDist >= visualStep then
            lastVisualDist = traveled
            self:CreateBurrowstrikeTrailFx(def, p, dir, def.visual_duration or 0.65)
        end
        self:CheckBurrowstrikeBoxPickup(playerID, caster, p, def.box_pickup_radius or 210)
        self:DestroyDoppelDecoysInRadius(playerID, p, radius, "burrowstrike")

        for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
            otherID = tonumber(otherID)
            if otherID ~= nil and otherID ~= playerID and hit[otherID] ~= true then
                local other = self:GetHeroForPlayer(otherID)
                if DKValidUnit(other) and DKLength2D(p, other:GetAbsOrigin()) <= radius then
                    hit[otherID] = true
                    self:ApplyBurrowKnockup(caster, otherID, other, def)
                end
            end
        end

        if now - startTime >= maxTime or traveled >= safeRange then
            for _, fx in ipairs(fxs) do self:DestroyLinearParticle(fx, false) end
            self:CreateBurrowstrikeTrailFx(def, endPos, dir, 0.85)
            self:CheckBurrowstrikeBoxPickup(playerID, caster, endPos, def.box_pickup_radius or 210)
            local final = Vector(endPos.x, endPos.y, GetGroundHeight(endPos, caster))
            caster:SetAbsOrigin(final)
            pcall(function() FindClearSpaceForUnit(caster, final, true) end)
            local st2 = self:GetState(playerID)
            if st2 ~= nil then
                st2.yaw = yaw or st2.yaw
                st2.speed = oldSpeed or st2.speed or 0
            end
            return nil
        end
        return 0.02
    end, 0.02)

    print("[DotaKartItems] FIX73 Player " .. tostring(playerID) .. " usou BURROWSTRIKE range=" .. tostring(math.floor(safeRange)) .. " " .. (backward and "para tras" or "para frente"))
    return true
end

function DotaKartItemSystem:SpawnNatureVineSegment(playerID, caster, def, pos, spawnTime)
    local seg = {
        pos = pos,
        expire_time = spawnTime + (tonumber(def.duration) or 5.0),
        hit_cd = {}
    }
    if def.particle_vine ~= nil then
        seg.fx = self:CreateRadiusWorldParticle(def.particle_vine, pos + Vector(0,0,8), tonumber(def.vine_radius) or 150, tonumber(def.duration) or 5.0)
    end
    return seg
end

function DotaKartItemSystem:ApplyKartRoot(caster, targetPlayerID, target, duration, def)
    if not DKValidUnit(target) then return false end
    if self:IsPlayerStarActive(targetPlayerID) then return false end
    if self:IsKartUntargetable(targetPlayerID) then return false end
    self.naturesGraspRootImmunity = self.naturesGraspRootImmunity or {}
    self.naturesGraspRootActiveUntil = self.naturesGraspRootActiveUntil or {}
    local now = DKNow()
    if (self.naturesGraspRootImmunity[targetPlayerID] or 0) > now then return false end
    if (self.naturesGraspRootActiveUntil[targetPlayerID] or 0) > now then return false end

    local casterPlayerID = self:GetPlayerIDForHero(caster)
    if casterPlayerID ~= nil and casterPlayerID >= 0 then
        self:NotifyBattleHungerItemHit(casterPlayerID, targetPlayerID)
    end

    local dur = math.max(0.1, tonumber(duration) or 1.35)
    self.naturesGraspRootActiveUntil[targetPlayerID] = now + dur
    if self.controller ~= nil and self.controller.SetKartRoot ~= nil then
        self.controller:SetKartRoot(targetPlayerID, dur)
    else
        local st = self:GetState(targetPlayerID)
        if st ~= nil then st.rooted_until = math.max(st.rooted_until or 0, now + dur) end
    end
    pcall(function() target:AddNewModifier(caster or target, nil, "modifier_dotakart_root", { duration = dur }) end)
    if def ~= nil and def.particle_root ~= nil then self:CreateAttachedParticleRobust(def.particle_root, target, dur, 180) end
    if def ~= nil then
        self:EmitKartSound(target, def.sound_root_hit or { "sounds/weapons/hero/treant/overgrowth_cast.vsnd", "Hero_Treant.Overgrowth.Cast" }, target:GetAbsOrigin())
        self:EmitKartSound(target, def.sound_root, target:GetAbsOrigin())
    end

    local serial = self:NextProjectileSerial()
    GameRules:GetGameModeEntity():SetContextThink("DotaKartNatureRootImmunity_" .. tostring(serial), function()
        self.naturesGraspRootActiveUntil[targetPlayerID] = nil
        self.naturesGraspRootImmunity[targetPlayerID] = DKNow() + (tonumber(def and def.root_immunity_after) or 5.0)
        return nil
    end, dur)
    return true
end

function DotaKartItemSystem:UseNaturesGrasp(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end
    local dir, yaw, backward = self:GetFireDirectionForPlayer(playerID, caster)
    dir = self:NormalizeDir2D(dir)
    local now = DKNow()
    local count = tonumber(def.vine_count) or 20
    local spacing = tonumber(def.vine_spacing) or 100
    local interval = tonumber(def.spawn_interval) or 0.04
    local serial = self:NextProjectileSerial()
    local data = { player_id = playerID, caster = caster, def = def, dir = dir, spawned = 0, next_spawn = now, segments = {}, serial = serial }
    self.activeNatureGrasps = self.activeNatureGrasps or {}
    self.activeNatureGrasps[serial] = data
    self:EmitKartSound(caster, def.sound_cast, caster:GetAbsOrigin())
    self:ConsumeHeldItem(playerID, itemName, def)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartNatureSpawn_" .. tostring(serial), function()
        if self.activeNatureGrasps[serial] == nil then return nil end
        if not DKValidUnit(caster) then self.activeNatureGrasps[serial] = nil; return nil end
        data.spawned = data.spawned + 1
        local base = caster:GetAbsOrigin()
        local p = base + dir * (spacing * data.spawned)
        p.z = GetGroundHeight(p, caster)
        table.insert(data.segments, self:SpawnNatureVineSegment(playerID, caster, def, p, DKNow()))
        if data.spawned >= count then return nil end
        return interval
    end, 0.0)

    print("[DotaKartItems] Player " .. tostring(playerID) .. " usou NATURES GRASP " .. (backward and "para tras" or "para frente"))
    return true
end

function DotaKartItemSystem:DestroyNatureSegment(seg)
    if seg ~= nil and seg.fx ~= nil then self:DestroyLinearParticle(seg.fx, false) end
end

function DotaKartItemSystem:UpdateNatureGrasps(now)
    self.activeNatureGrasps = self.activeNatureGrasps or {}
    for serial, data in pairs(self.activeNatureGrasps) do
        local caster = data.caster or self:GetHeroForPlayer(data.player_id)
        local def = data.def or self.itemDefs.item_dotakart_natures_grasp or {}
        local alive = {}
        for _, seg in ipairs(data.segments or {}) do
            if seg ~= nil and now < (seg.expire_time or 0) then
                table.insert(alive, seg)
                self:DestroyDoppelDecoysInRadius(data.player_id, seg.pos, tonumber(def.vine_radius) or 150, "natures_grasp")
                for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
                    otherID = tonumber(otherID)
                    if otherID ~= nil and otherID ~= data.player_id then
                        local other = self:GetHeroForPlayer(otherID)
                        if DKValidUnit(other) and DKLength2D(seg.pos, other:GetAbsOrigin()) <= (tonumber(def.vine_radius) or 150) then
                            if (seg.hit_cd[otherID] or 0) <= now then
                                if self:ApplyKartRoot(caster, otherID, other, def.root_duration or 1.35, def) then
                                    seg.hit_cd[otherID] = now + (tonumber(def.root_duration) or 1.35) + (tonumber(def.root_immunity_after) or 5.0)
                                end
                            end
                        end
                    end
                end
            else
                self:DestroyNatureSegment(seg)
            end
        end
        data.segments = alive
        if #alive <= 0 and (tonumber(data.spawned) or 0) >= (tonumber(def.vine_count) or 20) then
            self.activeNatureGrasps[serial] = nil
        end
    end
end

-- ============================================================
-- FIX29: Charge of Darkness
-- Persegue o kart exatamente uma colocacao melhor usando a pista/waypoints,
-- depois entra em modo direto para bater e atordoar.
-- ============================================================
function DotaKartItemSystem:GetPlayerIDOnePlaceAhead(playerID)
    local place = self:GetPlaceForPlayer(playerID)
    if place <= 1 then return -1 end
    local wantedPlace = place - 1

    if self.hud ~= nil and self.hud.racers ~= nil then
        for otherID, racer in pairs(self.hud.racers) do
            if tonumber(otherID) ~= tonumber(playerID) and racer ~= nil and tonumber(racer.place or 0) == wantedPlace then
                return tonumber(otherID) or -1
            end
        end
    end

    if self.hud ~= nil and self.hud.lastRacers ~= nil then
        for _, racer in pairs(self.hud.lastRacers) do
            if racer ~= nil and tonumber(racer.player_id) ~= tonumber(playerID) and tonumber(racer.place or 0) == wantedPlace then
                return tonumber(racer.player_id) or -1
            end
        end
    end

    return -1
end

function DotaKartItemSystem:GetTrackPointCount()
    local hud = self.hud
    if hud ~= nil and hud.trackWorldPoints ~= nil then return #hud.trackWorldPoints end
    return 0
end

function DotaKartItemSystem:GetTrackPointWorld(index, unit)
    local hud = self.hud
    if hud == nil or hud.trackWorldPoints == nil or #hud.trackWorldPoints <= 0 then return nil end
    local count = #hud.trackWorldPoints
    index = tonumber(index) or 1
    while index > count do index = index - count end
    while index < 1 do index = index + count end
    local p = hud.trackWorldPoints[index]
    if p == nil then return nil end
    return Vector(p.x, p.y, GetGroundHeight(p, unit))
end

function DotaKartItemSystem:GetNearestTrackIndex(pos)
    local hud = self.hud
    if pos == nil or hud == nil or hud.trackWorldPoints == nil or #hud.trackWorldPoints <= 0 then return 1 end
    local bestIndex = 1
    local bestDist = 999999999
    for i, p in ipairs(hud.trackWorldPoints) do
        local dx = (p.x or 0) - pos.x
        local dy = (p.y or 0) - pos.y
        local d = dx * dx + dy * dy
        if d < bestDist then
            bestDist = d
            bestIndex = i
        end
    end
    return bestIndex
end

function DotaKartItemSystem:GetInitialChargeTrackIndex(caster)
    if not DKValidUnit(caster) then return 1 end
    local hud = self.hud
    if hud ~= nil and hud.ProjectPositionOnTrack ~= nil then
        local ok, project = pcall(function() return hud:ProjectPositionOnTrack(caster:GetAbsOrigin()) end)
        if ok and project ~= nil then
            local count = self:GetTrackPointCount()
            local idx = (tonumber(project.nearest_segment or 1) or 1) + 1
            if count > 0 and idx > count then idx = 1 end
            return idx
        end
    end
    local count = self:GetTrackPointCount()
    local idx = self:GetNearestTrackIndex(caster:GetAbsOrigin()) + 1
    if count > 0 and idx > count then idx = 1 end
    return idx
end

function DotaKartItemSystem:AdvanceChargeTrackIndex(charge)
    local count = self:GetTrackPointCount()
    if count <= 0 or charge == nil then return end
    charge.next_index = (tonumber(charge.next_index or 1) or 1) + 1
    if charge.next_index > count then charge.next_index = 1 end
end

function DotaKartItemSystem:GetChargeWaypoint(playerID, targetPlayerID, caster, target, def, charge)
    if not DKValidUnit(caster) then return nil, false end

    if DKValidUnit(target) then
        local distToTarget = DKLength2D(caster:GetAbsOrigin(), target:GetAbsOrigin())
        if charge ~= nil and (charge.direct_chase == true or distToTarget <= (def.direct_radius or 1850)) then
            charge.direct_chase = true
            return target:GetAbsOrigin(), true
        end
    end

    if self:GetTrackPointCount() < 2 then
        if DKValidUnit(target) then return target:GetAbsOrigin(), true end
        return nil, false
    end

    charge = charge or {}
    if charge.next_index == nil then
        charge.next_index = self:GetInitialChargeTrackIndex(caster)
    end

    local pos = caster:GetAbsOrigin()
    local arrive = tonumber(def.path_arrive_radius) or 260
    local safety = 0
    local point = self:GetTrackPointWorld(charge.next_index, caster)
    while point ~= nil and DKLength2D(pos, point) <= arrive and safety < 4 do
        self:AdvanceChargeTrackIndex(charge)
        point = self:GetTrackPointWorld(charge.next_index, caster)
        safety = safety + 1
    end

    if point == nil then
        if DKValidUnit(target) then return target:GetAbsOrigin(), true end
        return nil, false
    end

    return point, false
end

function DotaKartItemSystem:CreateChargeParticleMark(target, particleName, timeout)
    if not DKValidUnit(target) or particleName == nil or particleName == "" or ParticleManager == nil then return nil end

    -- FIX32: alguns particles de Spirit Breaker não aparecem bem só com OVERHEAD_FOLLOW.
    -- Criamos duas ancoragens no alvo: uma overhead e outra na origem do modelo.
    local fxs = {}
    local ok = pcall(function()
        local pos = target:GetAbsOrigin()

        local fx1 = ParticleManager:CreateParticle(particleName, PATTACH_OVERHEAD_FOLLOW, target)
        ParticleManager:SetParticleControlEnt(fx1, 0, target, PATTACH_OVERHEAD_FOLLOW, "attach_hitloc", pos, true)
        ParticleManager:SetParticleControlEnt(fx1, 1, target, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", pos, true)
        ParticleManager:SetParticleControlEnt(fx1, 2, target, PATTACH_ABSORIGIN_FOLLOW, "attach_origin", pos, true)
        table.insert(fxs, fx1)

        local fx2 = ParticleManager:CreateParticle(particleName, PATTACH_ABSORIGIN_FOLLOW, target)
        ParticleManager:SetParticleControlEnt(fx2, 0, target, PATTACH_ABSORIGIN_FOLLOW, "attach_origin", pos, true)
        ParticleManager:SetParticleControlEnt(fx2, 1, target, PATTACH_OVERHEAD_FOLLOW, "attach_hitloc", pos, true)
        ParticleManager:SetParticleControl(fx2, 2, pos)
        table.insert(fxs, fx2)
    end)

    if not ok or #fxs <= 0 then return nil end
    return fxs
end

function DotaKartItemSystem:ReleaseParticleSafe(fx, immediate)
    if fx == nil or ParticleManager == nil then return end
    if type(fx) == "table" then
        for _, one in ipairs(fx) do
            self:ReleaseParticleSafe(one, immediate)
        end
        return
    end
    pcall(function()
        ParticleManager:DestroyParticle(fx, immediate == true)
        ParticleManager:ReleaseParticleIndex(fx)
    end)
end

function DotaKartItemSystem:PlayGreaterBashFx(target, def)
    if not DKValidUnit(target) then return end
    if def ~= nil and def.particle_bash ~= nil and ParticleManager ~= nil then
        pcall(function()
            local fx = ParticleManager:CreateParticle(def.particle_bash, PATTACH_ABSORIGIN_FOLLOW, target)
            ParticleManager:SetParticleControlEnt(fx, 0, target, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)
            ParticleManager:SetParticleControlEnt(fx, 1, target, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)
            GameRules:GetGameModeEntity():SetContextThink("DKChargeBashRelease_" .. tostring(fx), function()
                self:ReleaseParticleSafe(fx, false)
                return nil
            end, 1.0)
        end)
    end
end

function DotaKartItemSystem:PushKartFromCharge(casterPlayerID, caster, targetPlayerID, target, def, dir, dt)
    if not DKValidUnit(target) then return end

    -- FIX42: Charge of Darkness nao pode arremessar karts a distancias absurdas.
    -- O valor visual/fisico da pancada fica sempre limitado, independente da velocidade do caster.
    local maxPush = tonumber(def and def.max_push_distance) or 300
    local push = tonumber(def and def.bash_push) or 200
    push = math.max(0, math.min(push, maxPush))

    local pos = target:GetAbsOrigin()
    local normal = dir
    if DKValidUnit(caster) then
        normal = self:NormalizeDir2D(pos - caster:GetAbsOrigin())
        if normal == nil then normal = dir end
    end
    if normal == nil then normal = Vector(1, 0, 0) end

    local newPos = pos + normal * push
    newPos.z = GetGroundHeight(newPos, target)

    -- Nao passa velocidade gigante para MoveUnitWithKartPhysics, porque isso pode transferir bounce
    -- de colisao e fazer o alvo voar muito alem do push definido.
    if self.controller ~= nil and self.controller.MoveUnitWithKartPhysics ~= nil and targetPlayerID ~= nil and targetPlayerID >= 0 then
        local oldSpeed = nil
        local st = nil
        if self.controller.GetState ~= nil then
            st = self.controller:GetState(targetPlayerID)
            if st ~= nil then oldSpeed = st.speed end
        end
        self.controller:MoveUnitWithKartPhysics(targetPlayerID, target, newPos, normal, math.min(260, push / math.max(0.03, dt or 0.05)), dt or 0.05)
        if st ~= nil then
            st.speed = math.max(-220, math.min(220, tonumber(st.speed or 0) or 0))
        end
    else
        target:SetAbsOrigin(newPos)
    end
end

function DotaKartItemSystem:CancelChargeOfDarkness(playerID, reason)
    local charge = self.activeCharges and self.activeCharges[playerID]
    if charge ~= nil then
        self:ReleaseParticleSafe(charge.markFx, false)
    end
    if self.activeCharges ~= nil then self.activeCharges[playerID] = nil end
    local st = self:GetState(playerID)
    if st ~= nil then
        st.charge_active = false
        st.charge_target_player_id = nil
        st.charging_until = 0
        st.locked_until = 0
        st.speed = 0
    end
    if self.config and self.config.debug then
        print("[DotaKartItems] Charge of Darkness cancelado p" .. tostring(playerID) .. " reason=" .. tostring(reason or ""))
    end
end

function DotaKartItemSystem:GetDistance2DPointToSegment(point, a, b)
    if point == nil or a == nil or b == nil then return 999999 end
    local abx = b.x - a.x
    local aby = b.y - a.y
    local apx = point.x - a.x
    local apy = point.y - a.y
    local lenSq = abx * abx + aby * aby
    if lenSq <= 0.001 then
        return DKLength2D(point, a)
    end
    local t = (apx * abx + apy * aby) / lenSq
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local cx = a.x + abx * t
    local cy = a.y + aby * t
    local dx = point.x - cx
    local dy = point.y - cy
    return math.sqrt(dx * dx + dy * dy)
end

function DotaKartItemSystem:FinishChargeHit(playerID, caster, targetID, target, def, dt)
    if not DKValidUnit(caster) or not DKValidUnit(target) then return false end
    local casterPos = caster:GetAbsOrigin()
    local targetPos = target:GetAbsOrigin()
    self:PlayGreaterBashFx(target, def)
    self:EmitKartSound(target, def.sound_impact, targetPos)
    self:ApplyKartStun(caster, target, def.stun_duration or 1.0)
    self:PushKartFromCharge(playerID, caster, targetID, target, def, self:NormalizeDir2D(targetPos - casterPos), dt or 0.03)
    self:CancelChargeOfDarkness(playerID, "hit_target")
    print("[DotaKartItems] Charge of Darkness acertou player " .. tostring(targetID))
    return true
end

function DotaKartItemSystem:PlayChargeCasterFx(caster, def, charge, now)
    if not DKValidUnit(caster) or def == nil or def.particle_bash == nil or ParticleManager == nil then return end
    charge = charge or {}
    if now < (charge.nextCasterFxTime or 0) then return end
    charge.nextCasterFxTime = now + 0.32
    pcall(function()
        local fx = ParticleManager:CreateParticle(def.particle_bash, PATTACH_ABSORIGIN_FOLLOW, caster)
        ParticleManager:SetParticleControlEnt(fx, 0, caster, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
        ParticleManager:SetParticleControlEnt(fx, 1, caster, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
        GameRules:GetGameModeEntity():SetContextThink("DKChargeCasterFxRelease_" .. tostring(fx), function()
            self:ReleaseParticleSafe(fx, false)
            return nil
        end, 0.45)
    end)
end

function DotaKartItemSystem:UpdateChargeOfDarkness(playerID, charge)
    if charge == nil then return false end
    local def = charge.def or {}
    local caster = charge.caster or self:GetHeroForPlayer(playerID)
    local targetID = charge.targetPlayerID
    local target = charge.target or self:GetHeroForPlayer(targetID)
    local now = DKNow()

    if not DKValidUnit(caster) or not DKValidUnit(target) or now >= (charge.endTime or 0) then
        self:CancelChargeOfDarkness(playerID, "finished_or_invalid")
        return false
    end
    if self:IsKartUntargetable(targetID) or self:IsPlayerStarActive(targetID) or self:IsPlayerInvisible(targetID) then
        self:CancelChargeOfDarkness(playerID, "target_protected")
        return false
    end

    local st = self:GetState(playerID)
    if st == nil then
        self:CancelChargeOfDarkness(playerID, "no_state")
        return false
    end

    if self.controller ~= nil and self.controller.IsKartStunned ~= nil and self.controller:IsKartStunned(playerID, now) then
        self:CancelChargeOfDarkness(playerID, "caster_stunned")
        return false
    end

    if st.input ~= nil and st.input.reverse == true then
        self:CancelChargeOfDarkness(playerID, "reverse_cancel")
        return false
    end

    local lastTime = charge.lastTime or now
    local dt = math.max(0.01, math.min(0.05, now - lastTime))
    charge.lastTime = now

    local pos = caster:GetAbsOrigin()
    local targetPos = target:GetAbsOrigin()
    local distToTarget = DKLength2D(pos, targetPos)

    if distToTarget <= (def.hit_radius or 300) then
        self:FinishChargeHit(playerID, caster, targetID, target, def, dt)
        return false
    end

    -- Mantem o controller travado só por um pequeno intervalo renovado a cada tick.
    st.charge_active = true
    st.charge_target_player_id = targetID
    st.charging_until = math.max(st.charging_until or 0, now + 0.20)
    st.locked_until = math.max(st.locked_until or 0, now + 0.12)

    local waypoint, direct = self:GetChargeWaypoint(playerID, targetID, caster, target, def, charge)
    if waypoint == nil then
        self:CancelChargeOfDarkness(playerID, "no_waypoint")
        return false
    end

    if direct == true and charge.direct_logged ~= true then
        charge.direct_logged = true
        print("[DotaKartItems] Charge of Darkness entrou em modo direto contra player " .. tostring(targetID))
    end
    self:PlayChargeCasterFx(caster, def, charge, now)

    local dx = waypoint.x - pos.x
    local dy = waypoint.y - pos.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then dist = 1 end
    local dir = Vector(dx / dist, dy / dist, 0)

    local baseSpeed = tonumber(def.charge_speed) or 1750
    local currentSpeed = math.abs(tonumber(st.speed or 0) or 0)
    local speed = math.max(currentSpeed, baseSpeed)
    if direct == true then
        speed = math.max(speed, baseSpeed * (tonumber(def.direct_speed_factor) or 1.25))
    end
    st.speed = speed
    st.yaw = DKNormalizeYaw(math.deg(DKAtan2(dir.y, dir.x)))

    local step = math.min(dist, speed * dt)
    local newPos = pos + dir * step
    newPos.z = GetGroundHeight(newPos, caster)

    -- FIX32: se o segmento do movimento cruza o alvo, considera impacto mesmo que o tick passe direto.
    local segHit = false
    if direct == true then
        local segDist = self:GetDistance2DPointToSegment(targetPos, pos, newPos)
        if segDist <= (def.direct_hit_radius or def.hit_radius or 360) then
            segHit = true
            newPos = targetPos - dir * 92
            newPos.z = GetGroundHeight(newPos, caster)
        end
    end

    if self.controller ~= nil and self.controller.MoveUnitWithKartPhysics ~= nil then
        newPos = self.controller:MoveUnitWithKartPhysics(playerID, caster, newPos, dir, speed, dt)
    else
        caster:SetAbsOrigin(newPos)
    end
    pcall(function() caster:FaceTowards(newPos + dir * 256) end)
    pcall(function() caster:SetForwardVector(dir) end)

    if segHit or DKLength2D(caster:GetAbsOrigin(), target:GetAbsOrigin()) <= (def.hit_radius or 300) then
        self:FinishChargeHit(playerID, caster, targetID, target, def, dt)
        return false
    end

    -- Greater Bash: qualquer unidade dentro de 300 de raio durante a investida é atingida e empurrada.
    for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
        if otherID ~= playerID then
            local other = self:GetHeroForPlayer(otherID)
            if DKValidUnit(other) and not self:IsPlayerStarActive(otherID) and not self:IsKartUntargetable(otherID) then
                local d = DKLength2D(caster:GetAbsOrigin(), other:GetAbsOrigin())
                if d <= (def.bash_radius or 300) then
                    charge.bashCooldowns = charge.bashCooldowns or {}
                    if now >= (charge.bashCooldowns[otherID] or 0) then
                        charge.bashCooldowns[otherID] = now + 0.70
                        self:PlayGreaterBashFx(other, def)
                        self:EmitKartSound(other, def.sound_impact, other:GetAbsOrigin())
                        self:ApplyKartStun(caster, other, def.bash_stun or 0.25)
                        self:PushKartFromCharge(playerID, caster, otherID, other, def, dir, dt)
                    end
                end
            end
        end
    end

    return true
end

function DotaKartItemSystem:UseChargeOfDarkness(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end

    local place = self:GetPlaceForPlayer(playerID)
    if place <= 1 then
        print("[DotaKartItems] Charge of Darkness sem efeito: player " .. tostring(playerID) .. " esta em 1o lugar.")
        return false
    end

    local targetID = self:GetPlayerIDOnePlaceAhead(playerID)
    local target = self:GetHeroForPlayer(targetID)
    if targetID < 0 or not DKValidUnit(target) or self:IsKartUntargetable(targetID) or self:IsPlayerStarActive(targetID) or self:IsPlayerInvisible(targetID) then
        print("[DotaKartItems] Charge of Darkness sem alvo valido para player " .. tostring(playerID))
        return false
    end

    self:CancelChargeOfDarkness(playerID, "restart")
    self:EmitKartSound(caster, def.sound_cast, caster:GetAbsOrigin())
    self:ConsumeHeldItem(playerID, itemName, def)

    local now = DKNow()
    local markFx = self:CreateChargeParticleMark(target, def.particle_mark, def.timeout or 9.0)
    self.activeCharges[playerID] = {
        caster = caster,
        target = target,
        targetPlayerID = targetID,
        startTime = now,
        lastTime = now,
        endTime = now + (def.timeout or 9.0),
        def = def,
        markFx = markFx,
        bashCooldowns = {},
        next_index = self:GetInitialChargeTrackIndex(caster),
        direct_chase = false
    }

    print("[DotaKartItems] Player " .. tostring(playerID) .. " usou Charge of Darkness contra player " .. tostring(targetID) .. " place " .. tostring(place) .. " -> " .. tostring(place - 1))
    return true
end




-- ============================================================
-- FIX41: Item Steal (Rubick Spell Steal)
-- Procura por 5s um adversario com item. Quando encontra, mostra Spell Steal
-- por 2s nos dois karts e depois transfere o item para o usuario.
-- ============================================================
function DotaKartItemSystem:GetItemStealCharges(playerID, itemName)
    if itemName == "item_blade_mail" and self.GetActiveCogCount ~= nil then
        return self:GetActiveCogCount(playerID)
    end
    local charges = tonumber(self.itemCharges and self.itemCharges[playerID] or 0) or 0
    if charges > 0 then return charges end
    return self:GetItemChargeCount(playerID, itemName)
end

function DotaKartItemSystem:IsStealableHeldItem(itemName)
    if itemName == nil or itemName == "" then return false end
    if itemName == "item_spell_steal" then return false end
    return self.itemDefs[itemName] ~= nil
end

function DotaKartItemSystem:ClearHeldItemForSteal(playerID, reason)
    local held = self:GetHeldItem(playerID)
    if held == "item_dotakart_unstable_concoction_throw" and self.activeConcoctions ~= nil then
        self.activeConcoctions[playerID] = nil
    end
    if held == "item_blade_mail" and self.CapturePowerCogsForSteal ~= nil then
        -- FIX106: Item Steal remove só Cogs orbitando; Cogs já arremessados continuam no mapa.
        self:CapturePowerCogsForSteal(playerID, held)
    else
        self.itemCharges[playerID] = nil
        self:SetHeldItemHUD(playerID, "", 0)
    end
end

function DotaKartItemSystem:SetSpellStealTemporaryIcon(playerID, untilTime)
    self.itemStealLocks[playerID] = untilTime or (DKNow() + 2.0)
    self.itemCharges[playerID] = nil
    self:SetHeldItemHUD(playerID, "item_spell_steal", 0)
end

function DotaKartItemSystem:CaptureUnstableConcoctionForSteal(victimID, heldItem)
    if heldItem ~= "item_dotakart_unstable_concoction_throw" then return nil end
    local data = self.activeConcoctions and self.activeConcoctions[victimID]
    if data == nil or data.thrown == true then return nil end
    local now = DKNow()
    local explodeTime = tonumber(data.explode_time or 0) or 0
    if explodeTime <= now then return nil end

    local payload = {
        def = data.def or self.itemDefs.item_dotakart_unstable_concoction or {},
        start_time = data.start_time or now,
        explode_time = data.explode_time,
        max_brew_time = data.max_brew_time,
        remaining = explodeTime - now
    }

    self.activeConcoctions[victimID] = nil
    local stVictim = self:GetState(victimID)
    if stVictim ~= nil then
        stVictim.concoction_until = 0
        if (stVictim.item_max_speed_until or 0) <= explodeTime + 0.05 then
            stVictim.item_max_speed_until = 0
            stVictim.item_max_speed = 0
        end
    end
    return payload
end

function DotaKartItemSystem:CapturePowerCogsForSteal(victimID, heldItem)
    if heldItem ~= "item_blade_mail" then return nil end
    local def = self.itemDefs and self.itemDefs.item_blade_mail or {}
    local count = 0
    local data = self.activeCogs and self.activeCogs[victimID]

    if data ~= nil then
        def = data.def or def
        local kept = {}
        for _, cog in ipairs(data.cogs or {}) do
            if cog ~= nil and cog.active == true and cog.launched ~= true then
                -- Rouba somente Cogs orbitando. Projéteis já lançados continuam vivos no mapa.
                count = count + 1
                cog.active = false
                self:RemoveCogVisual(cog)
            else
                table.insert(kept, cog)
            end
        end

        data.cogs = kept
        if #kept <= 0 then
            self.activeCogs[victimID] = nil
        end
    end

    self.itemCharges[victimID] = nil
    self:SetHeldItemHUD(victimID, "", 0)

    return { count = count, def = def }
end

function DotaKartItemSystem:GrantStolenPowerCogs(playerID, payload)
    if payload == nil then return false end
    local count = tonumber(payload.count or 0) or 0
    if count <= 0 then
        self.itemCharges[playerID] = nil
        self:SetHeldItemHUD(playerID, "", 0)
        return true
    end

    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end

    local def = payload.def or (self.itemDefs and self.itemDefs.item_blade_mail) or {}
    self.activeCogs = self.activeCogs or {}

    -- Mantém Cogs já lançados pelo novo dono, mas remove orbitais antigos/stale antes de receber os roubados.
    local oldData = self.activeCogs[playerID]
    local kept = {}
    if oldData ~= nil then
        for _, oldCog in ipairs(oldData.cogs or {}) do
            if oldCog ~= nil and oldCog.active == true and oldCog.launched == true then
                table.insert(kept, oldCog)
            elseif oldCog ~= nil then
                oldCog.active = false
                self:RemoveCogVisual(oldCog)
            end
        end
    end

    local nowDeploy = DKNow()
    local duration = tonumber(def.duration or 0) or 0
    local expireTime = duration > 0 and (nowDeploy + duration) or 0
    local data = { cogs = kept, startTime = nowDeploy, expireTime = expireTime, def = def }
    self.activeCogs[playerID] = data

    local basePos = caster:GetAbsOrigin()
    for i = 1, count do
        local angle = ((i - 1) / math.max(1, count)) * 360
        local rad = math.rad(angle)
        local pos = basePos + Vector(math.cos(rad), math.sin(rad), 0) * (def.orbit_radius or 175)
        pos.z = GetGroundHeight(pos, caster)
        local ent = self:SpawnCogVisual(def, pos, angle)
        table.insert(data.cogs, { active = true, ent = ent, angle = angle, pos = pos, launched = false, stolen = true })
    end

    self.itemCharges[playerID] = count
    self:SetHeldItemHUD(playerID, "item_blade_mail", count)
    self:EmitKartSound(caster, def.sound_cast, caster:GetAbsOrigin())
    print("[DotaKartItems] FIX106 ITEM STEAL transferiu Power Cogs orbitais para player " .. tostring(playerID) .. " count=" .. tostring(count))
    return true
end

function DotaKartItemSystem:ApplyStolenUnstableConcoction(playerID, payload)
    if payload == nil then return false end
    local hero = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(hero) then return false end
    local now = DKNow()
    local explodeTime = tonumber(payload.explode_time or 0) or 0
    if explodeTime <= now then explodeTime = now + math.max(0.1, tonumber(payload.remaining or 0) or 0.1) end

    local def = payload.def or self.itemDefs.item_dotakart_unstable_concoction or {}
    self.activeConcoctions = self.activeConcoctions or {}
    self.activeConcoctions[playerID] = {
        caster = hero,
        def = def,
        start_time = payload.start_time or now,
        explode_time = explodeTime,
        max_brew_time = payload.max_brew_time or (now + (tonumber(def.max_brew_time) or 5.0)),
        next_timer = 0,
        thrown = false,
        stolen = true
    }

    local st = self:GetState(playerID)
    if st ~= nil then
        local maxBase = 880
        if self.controller ~= nil and self.controller.config ~= nil and self.controller.config.max_speed ~= nil then
            maxBase = tonumber(self.controller.config.max_speed) or maxBase
        end
        local pct = tonumber(def.move_speed_bonus_pct) or 10
        st.concoction_until = explodeTime
        st.item_max_speed_until = math.max(st.item_max_speed_until or 0, explodeTime)
        st.item_max_speed = math.max(st.item_max_speed or 0, maxBase * (1.0 + pct / 100.0))
    end

    self:SetHeldItemHUD(playerID, "item_dotakart_unstable_concoction_throw", 0)
    self:EmitKartSound(hero, def.sound_fuse, hero:GetAbsOrigin())
    print("[DotaKartItems] FIX97 ITEM STEAL transferiu Unstable Concoction Throw para player " .. tostring(playerID) .. " remaining=" .. tostring(string.format("%.2f", explodeTime - now)))
    return true
end

function DotaKartItemSystem:FindRandomItemStealVictim(casterPlayerID)
    local candidates = {}
    for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
        if tonumber(otherID) ~= tonumber(casterPlayerID) then
            local hero = self:GetHeroForPlayer(otherID)
            local held = self:GetHeldItem(otherID)
            if DKValidUnit(hero) and not self:IsKartUntargetable(otherID) and self:IsStealableHeldItem(held) and self.rolling[otherID] == nil then
                table.insert(candidates, { playerID = tonumber(otherID), hero = hero, item = held, charges = self:GetItemStealCharges(otherID, held) })
            end
        end
    end
    if #candidates <= 0 then return nil end
    return candidates[DKRandomInt(1, #candidates)]
end

function DotaKartItemSystem:StartItemStealTransfer(playerID, data, victim)
    if data == nil or victim == nil or victim.playerID == nil then return end
    local now = DKNow()
    local def = data.def or self.itemDefs.item_spell_steal or {}
    local caster = data.caster or self:GetHeroForPlayer(playerID)
    local victimHero = victim.hero or self:GetHeroForPlayer(victim.playerID)
    if not DKValidUnit(caster) or not DKValidUnit(victimHero) then return end

    data.phase = "transfer"
    data.victimPlayerID = victim.playerID
    data.victimHero = victimHero
    data.stolenItem = victim.item
    data.stolenCharges = tonumber(victim.charges or 0) or 0
    data.stolenConcoction = self:CaptureUnstableConcoctionForSteal(victim.playerID, victim.item)
    data.stolenPowerCogs = self:CapturePowerCogsForSteal(victim.playerID, victim.item)
    if data.stolenPowerCogs ~= nil then
        data.stolenCharges = tonumber(data.stolenPowerCogs.count or data.stolenCharges or 0) or 0
    end
    data.complete_time = now + (tonumber(def.steal_delay) or 2.0)

    self:SetSpellStealTemporaryIcon(playerID, data.complete_time)
    -- FIX107: Power Cogs/Unstable já foram capturados acima. Não chamar ClearHeldItemForSteal de novo,
    -- pois isso podia limpar estado extra ou remover Cogs lançados indevidamente.
    if victim.item ~= "item_blade_mail" and victim.item ~= "item_dotakart_unstable_concoction_throw" then
        self:ClearHeldItemForSteal(victim.playerID, "stolen_pending")
    else
        self.itemCharges[victim.playerID] = nil
        self:SetHeldItemHUD(victim.playerID, "", 0)
    end
    self:SetSpellStealTemporaryIcon(victim.playerID, data.complete_time)

    self:EmitKartSound(caster, def.sound_target, caster:GetAbsOrigin())
    self:EmitKartSound(victimHero, def.sound_target, victimHero:GetAbsOrigin())
    self:CreateAttachedParticleRobust(def.particle, caster, 1.8, 220)
    self:CreateAttachedParticleRobust(def.particle, victimHero, 1.8, 220)
    self:CreateWorldParticle(def.particle, caster:GetAbsOrigin() + Vector(0,0,86), 1.2)
    self:CreateWorldParticle(def.particle, victimHero:GetAbsOrigin() + Vector(0,0,86), 1.2)

    print("[DotaKartItems] ITEM STEAL encontrou alvo: player " .. tostring(playerID) .. " roubando " .. tostring(victim.item) .. " de player " .. tostring(victim.playerID))
end

function DotaKartItemSystem:CompleteItemSteal(playerID, data)
    if data == nil then return end
    local def = data.def or self.itemDefs.item_spell_steal or {}
    local caster = data.caster or self:GetHeroForPlayer(playerID)
    local victimID = tonumber(data.victimPlayerID or -1) or -1
    local victimHero = data.victimHero or self:GetHeroForPlayer(victimID)
    local stolenItem = data.stolenItem or ""
    local stolenCharges = tonumber(data.stolenCharges or 0) or 0

    self.activeItemSteals[playerID] = nil
    self.itemStealLocks[playerID] = nil
    if victimID >= 0 then self.itemStealLocks[victimID] = nil end

    if victimID >= 0 then
        self.itemCharges[victimID] = nil
        self:SetHeldItemHUD(victimID, "", 0)
    end

    if data.stolenConcoction ~= nil and stolenItem == "item_dotakart_unstable_concoction_throw" then
        self.itemCharges[playerID] = nil
        self:ApplyStolenUnstableConcoction(playerID, data.stolenConcoction)
    elseif data.stolenPowerCogs ~= nil and stolenItem == "item_blade_mail" then
        self:GrantStolenPowerCogs(playerID, data.stolenPowerCogs)
    elseif self:IsStealableHeldItem(stolenItem) then
        self:GiveItemToPlayer(playerID, stolenItem, true)
        if stolenCharges > 1 then
            self.itemCharges[playerID] = stolenCharges
            self:SetHeldItemHUD(playerID, stolenItem, stolenCharges)
        end
    else
        self.itemCharges[playerID] = nil
        self:SetHeldItemHUD(playerID, "", 0)
    end

    if DKValidUnit(caster) then
        self:EmitKartSound(caster, def.sound_complete, caster:GetAbsOrigin())
        self:CreateAttachedParticleRobust(def.particle, caster, 1.0, 240)
    end
    if DKValidUnit(victimHero) then
        self:EmitKartSound(victimHero, def.sound_complete, victimHero:GetAbsOrigin())
        self:CreateAttachedParticleRobust(def.particle, victimHero, 1.0, 240)
    end

    print("[DotaKartItems] ITEM STEAL concluido player " .. tostring(playerID) .. " recebeu " .. tostring(stolenItem) .. " de player " .. tostring(victimID))
end

function DotaKartItemSystem:FailItemSteal(playerID, data, reason)
    data = data or {}
    local caster = data.caster or self:GetHeroForPlayer(playerID)
    self.activeItemSteals[playerID] = nil
    self.itemStealLocks[playerID] = nil
    self.itemCharges[playerID] = nil
    self:SetHeldItemHUD(playerID, "", 0)
    if DKValidUnit(caster) and data.def ~= nil then
        self:CreateWorldParticle(data.def.particle, caster:GetAbsOrigin() + Vector(0,0,86), 0.8)
    end
    print("[DotaKartItems] ITEM STEAL falhou player " .. tostring(playerID) .. " reason=" .. tostring(reason or "timeout"))
end

function DotaKartItemSystem:UpdateItemSteals(now)
    for playerID, data in pairs(self.activeItemSteals or {}) do
        local caster = data.caster or self:GetHeroForPlayer(playerID)
        local def = data.def or self.itemDefs.item_spell_steal or {}
        if not DKValidUnit(caster) then
            self.activeItemSteals[playerID] = nil
            self.itemStealLocks[playerID] = nil
        elseif data.phase == "transfer" then
            if now >= (data.complete_time or 0) then
                self:CompleteItemSteal(playerID, data)
            elseif now >= (data.next_visual or 0) then
                data.next_visual = now + (tonumber(def.visual_tick) or 0.35)
                self:CreateWorldParticle(def.particle, caster:GetAbsOrigin() + Vector(0,0,86), 0.45)
                if DKValidUnit(data.victimHero) then
                    self:CreateWorldParticle(def.particle, data.victimHero:GetAbsOrigin() + Vector(0,0,86), 0.45)
                end
            end
        else
            if now >= (data.end_time or 0) then
                self:FailItemSteal(playerID, data, "timeout")
            else
                if now >= (data.next_visual or 0) then
                    data.next_visual = now + (tonumber(def.visual_tick) or 0.35)
                    self:CreateWorldParticle(def.particle, caster:GetAbsOrigin() + Vector(0,0,86), 0.45)
                end
                if now >= (data.next_check or 0) then
                    data.next_check = now + (tonumber(def.search_tick) or 0.25)
                    local victim = self:FindRandomItemStealVictim(playerID)
                    if victim ~= nil then
                        self:StartItemStealTransfer(playerID, data, victim)
                    end
                end
            end
        end
    end
end

function DotaKartItemSystem:UseItemSteal(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end
    local now = DKNow()
    def = def or self.itemDefs.item_spell_steal or {}

    self.itemCharges[playerID] = nil
    self:SetHeldItemHUD(playerID, "item_spell_steal", 0)
    self.itemStealLocks[playerID] = now + (tonumber(def.search_duration) or 5.0)
    self.activeItemSteals[playerID] = {
        phase = "search",
        caster = caster,
        def = def,
        end_time = now + (tonumber(def.search_duration) or 5.0),
        next_check = now + 0.05,
        next_visual = now + 0.05
    }

    self:EmitKartSound(caster, def.sound_cast, caster:GetAbsOrigin())
    self:CreateAttachedParticleRobust(def.particle, caster, 1.0, 220)
    self:CreateWorldParticle(def.particle, caster:GetAbsOrigin() + Vector(0,0,86), 1.0)
    print("[DotaKartItems] Player " .. tostring(playerID) .. " usou ITEM STEAL; procurando item por " .. tostring(def.search_duration or 5.0) .. "s")
    return true
end

-- ============================================================
-- FIX40: Tornado + Ice Shards
-- ============================================================
function DotaKartItemSystem:CreateMultiMissileParticles(particleList, pos, dir, speed, lookAhead)
    local fxs = {}
    for _, particleName in ipairs(self:NormalizeParticleList(particleList)) do
        local fx = self:CreateMissileParticle(particleName, pos, dir, speed, lookAhead or 520)
        if fx ~= nil then table.insert(fxs, fx) end
    end
    return fxs
end

function DotaKartItemSystem:UpdateMultiMissileParticles(fxs, pos, dir, speed, lookAhead)
    for _, fx in ipairs(fxs or {}) do
        self:UpdateMissileParticle(fx, pos, dir, speed, lookAhead or 520)
    end
end

function DotaKartItemSystem:DestroyMultiMissileParticles(fxs, immediate)
    for _, fx in ipairs(fxs or {}) do
        self:DestroyLinearParticle(fx, immediate)
    end
end

function DotaKartItemSystem:ApplyKartCyclone(caster, target, duration, soundDef)
    if not DKValidUnit(target) then return end
    if self:IsHeroStarActive(target) then return end

    local dur = math.max(0.1, tonumber(duration) or 3.5)
    local targetPlayerID = self:GetPlayerIDForHero(target)
    if targetPlayerID ~= nil and targetPlayerID >= 0 then
        self:LockKart(targetPlayerID, dur)
        -- FIX107: enquanto está no ar pelo Tornado, outros karts podem atravessar/passsar por baixo.
        local stTornado = self:GetState(targetPlayerID)
        if stTornado ~= nil then
            stTornado.tornado_airborne_until = DKNow() + dur
        end
    end

    self:EmitKartSound(target, soundDef, target:GetAbsOrigin())
    pcall(function()
        target:AddNewModifier(caster or target, nil, "modifier_stunned", { duration = dur })
    end)

    local base = target:GetAbsOrigin()
    local startTime = DKNow()
    local endTime = startTime + dur
    local serial = self:NextProjectileSerial()
    local spin = 0
    GameRules:GetGameModeEntity():SetContextThink("DotaKartCycloneLift_" .. tostring(serial), function()
        if not DKValidUnit(target) then return nil end
        local now = DKNow()
        local t = DKClamp((now - startTime) / dur, 0, 1)
        local ground = GetGroundHeight(base, target)
        local height = 120 + math.sin(math.pi * t) * 420
        local pos = Vector(base.x, base.y, ground + height)
        target:SetAbsOrigin(pos)
        spin = DKNormalizeYaw(spin + 55)
        if target.SetAngles ~= nil then pcall(function() target:SetAngles(0, spin, 0) end) end
        if now >= endTime then
            local finalPos = Vector(base.x, base.y, GetGroundHeight(base, target))
            target:SetAbsOrigin(finalPos)
            pcall(function() FindClearSpaceForUnit(target, finalPos, true) end)
            if targetPlayerID ~= nil and targetPlayerID >= 0 then
                local st = self:GetState(targetPlayerID)
                if st ~= nil then
                    st.speed = 0
                    st.tornado_airborne_until = 0
                end
            end
            return nil
        end
        return 0.03
    end, 0.03)
end

function DotaKartItemSystem:UseTornado(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end

    local dir, yaw, backward = self:GetFireDirectionForPlayer(playerID, caster)
    dir = self:NormalizeDir2D(dir)
    local start = caster:GetAbsOrigin() + dir * 130 + Vector(0, 0, 96)
    local pos = Vector(start.x, start.y, start.z)
    local speed = tonumber(def.speed) or 1800
    local range = tonumber(def.travel_distance) or 4000
    local radius = tonumber(def.effect_radius) or 300
    local hitPlayers = {}
    local traveled = 0
    local lastTime = DKNow()
    local serial = self:NextProjectileSerial()
    local fxs = self:CreateMultiMissileParticles(def.particles or def.particle, pos, dir, speed, 620)

    self:EmitKartSound(caster, def.sound_cast, start)
    self:ConsumeHeldItem(playerID, itemName, def)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartTornadoProjectile_" .. tostring(serial), function()
        if not DKValidUnit(caster) then
            self:DestroyMultiMissileParticles(fxs, false)
            return nil
        end
        local now = DKNow()
        local dt = math.max(0.001, math.min(0.05, now - lastTime))
        lastTime = now
        local step = speed * dt
        traveled = traveled + step
        pos = pos + dir * step
        pos.z = GetGroundHeight(pos, nil) + 110
        self:UpdateMultiMissileParticles(fxs, pos, dir, speed, 620)

        if traveled > 120 and self:IsProjectileBlockedByWorld(pos, 110, playerID) then
            self:DestroyMultiMissileParticles(fxs, false)
            return nil
        end

        if self:HandleSpecialProjectileTargetHit(playerID, pos, radius, "tornado") then
            self:DestroyMultiMissileParticles(fxs, false)
            return nil
        end

        for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
            if tonumber(otherID) ~= tonumber(playerID) and hitPlayers[otherID] ~= true then
                local other = self:GetHeroForPlayer(otherID)
                if DKValidUnit(other) and not self:IsPlayerStarActive(otherID) and not self:IsKartUntargetable(otherID) and DKLength2D(pos, other:GetAbsOrigin()) <= radius then
                    hitPlayers[otherID] = true
                    self:NotifyBattleHungerItemHit(playerID, otherID)
                    self:ApplyKartCyclone(caster, other, def.cyclone_duration or 3.5, def.sound_target)
                    print("[DotaKartItems] Tornado pegou player " .. tostring(otherID))
                end
            end
        end

        if traveled >= range then
            self:DestroyMultiMissileParticles(fxs, false)
            return nil
        end
        return 0.02
    end, 0.02)

    print("[DotaKartItems] Player " .. tostring(playerID) .. " lançou TORNADO " .. (backward and "para tras" or "para frente"))
    return true
end

function DotaKartItemSystem:DestroyIceShardSet(set, reason)
    if set == nil or set.destroyed == true then return end
    set.destroyed = true
    for _, fx in ipairs(set.fxs or {}) do
        self:DestroyLinearParticle(fx, false)
    end
    self.activeIceShards[set.id] = nil
    if self.config and self.config.debug then
        print("[DotaKartItems] Ice Shards destruido reason=" .. tostring(reason) .. " id=" .. tostring(set.id))
    end
end

function DotaKartItemSystem:CheckIceShardProjectileCollision(pos, radius, ownerPlayerID)
    if pos == nil then return false end
    local r = tonumber(radius) or 90
    for _, set in pairs(self.activeIceShards or {}) do
        if set ~= nil and set.destroyed ~= true and (ownerPlayerID == nil or tonumber(set.ownerPlayerID) ~= tonumber(ownerPlayerID)) then
            for _, shard in ipairs(set.shards or {}) do
                if DKLength2D(pos, shard.pos) <= ((set.collision_radius or 145) + r) then
                    self:DestroyIceShardSet(set, "projectile")
                    return true
                end
            end
        end
    end
    return false
end

function DotaKartItemSystem:SpawnIceShardsBarrier(ownerPlayerID, caster, center, dir, def, customPoints)
    if center == nil then return end
    dir = self:NormalizeDir2D(dir or Vector(1,0,0))
    local yaw = math.deg(DKAtan2(dir.y, dir.x))
    local count = tonumber(def.shard_count) or 7
    local spawnRadius = tonumber(def.spawn_radius) or 260
    local angleTotal = tonumber(def.spawn_angle) or 220
    local duration = tonumber(def.duration) or 5.0
    local serial = self:NextProjectileSerial()
    local set = {
        id = serial,
        ownerPlayerID = ownerPlayerID,
        caster = caster,
        def = def,
        endTime = DKNow() + duration,
        shards = {},
        fxs = {},
        collision_radius = tonumber(def.collision_radius) or 190,
        kartHitCount = 0,
        hitCooldowns = {}
    }

    local particles = self:NormalizeParticleList(def.shard_particles)
    local points = customPoints

    -- FIX49: barreira padrao agora e um arco largo em U, nao uma linha estreita.
    -- Isso deixa as shards realmente obstruindo a pista como no Ice Shards do Tusk/Mario Kart.
    if points == nil then
        points = {}
        for i = 1, count do
            local frac = 0
            if count > 1 then frac = (i - 1) / (count - 1) end
            local a = yaw - angleTotal * 0.5 + frac * angleTotal
            local rad = math.rad(a)
            local p = center + Vector(math.cos(rad), math.sin(rad), 0) * spawnRadius
            table.insert(points, p)
        end
    end

    for _, rawP in ipairs(points or {}) do
        local p = Vector(rawP.x, rawP.y, GetGroundHeight(rawP, nil) + 18)
        table.insert(set.shards, { pos = p })
        for _, particleName in ipairs(particles) do
            local fx = self:CreateWorldParticle(particleName, p, nil)
            if fx ~= nil then table.insert(set.fxs, fx) end
        end
    end

    self.activeIceShards[serial] = set
    self:EmitKartSound(caster, def.sound_spawn, center)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartIceShardsBarrier_" .. tostring(serial), function()
        if set.destroyed == true then return nil end
        local now = DKNow()
        if now >= (set.endTime or 0) then
            self:DestroyIceShardSet(set, "expired")
            return nil
        end

        for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
            local other = self:GetHeroForPlayer(otherID)
            if DKValidUnit(other) then
                local otherPos = other:GetAbsOrigin()
                for _, shard in ipairs(set.shards or {}) do
                    if DKLength2D(otherPos, shard.pos) <= (set.collision_radius or 190) then
                        local key = tostring(otherID)
                        if now >= (set.hitCooldowns[key] or 0) then
                            set.hitCooldowns[key] = now + 0.45
                            set.kartHitCount = (set.kartHitCount or 0) + 1
                            self:NotifyBattleHungerItemHit(set.ownerPlayerID, otherID)
                            self:PushKartAwayFromPoint(shard.pos, otherID, other, def.shard_push or 460, def.shard_stun or 0.18)
                            if set.kartHitCount >= (tonumber(def.kart_hits_to_break) or 3) then
                                self:DestroyIceShardSet(set, "kart_hits")
                                return nil
                            end
                        end
                    end
                end
            end
        end
        return 0.05
    end, 0.05)

    print("[DotaKartItems] ICE SHARDS barreira criada id=" .. tostring(serial) .. " shards=" .. tostring(#(set.shards or {})) .. " FIX49")
end

-- FIX49: cria uma ferradura de shards NA FRENTE do kart atingido.
-- A barreira usa o facing do alvo, independente do caster ter usado T ou S+T.
function DotaKartItemSystem:BuildIceShardsFrontUPoints(targetPos, dir, def)
    dir = self:NormalizeDir2D(dir or Vector(1,0,0))
    local right = Vector(-dir.y, dir.x, 0)
    local scale = tonumber(def.formation_scale) or 1.0
    local pts = {}
    -- x = lateral, y = para frente do alvo. Forma inspirada nas referencias enviadas.
    local offsets = {
        Vector(-360,  60, 0),
        Vector(-330, 250, 0),
        Vector(-250, 430, 0),
        Vector(   0, 540, 0),
        Vector( 250, 430, 0),
        Vector( 330, 250, 0),
        Vector( 360,  60, 0),
    }
    for _, o in ipairs(offsets) do
        local p = targetPos + right * (o.x * scale) + dir * (o.y * scale)
        p.z = GetGroundHeight(p, nil) + 18
        table.insert(pts, p)
    end
    return pts
end

function DotaKartItemSystem:GetBarrierDirectionForTarget(targetPlayerID, target)
    local dir = nil
    if targetPlayerID ~= nil and tonumber(targetPlayerID) ~= nil then
        dir = self:GetForwardForPlayer(tonumber(targetPlayerID), target)
    end
    if dir == nil and DKValidUnit(target) and target.GetForwardVector ~= nil then
        dir = target:GetForwardVector()
    end
    return self:NormalizeDir2D(dir or Vector(1,0,0))
end

function DotaKartItemSystem:SpawnIceShardsInFrontOfTarget(ownerPlayerID, caster, targetPlayerID, target, def)
    if not DKValidUnit(target) then return false end
    local dir = self:GetBarrierDirectionForTarget(targetPlayerID, target)
    local targetPos = target:GetAbsOrigin()
    targetPos.z = GetGroundHeight(targetPos, target) + 20

    -- FIX49: ao atingir um kart, as shards aparecem sempre na frente DELE.
    -- Isso independe se o usuario lançou para frente ou para tras.
    local points = self:BuildIceShardsFrontUPoints(targetPos, dir, def)
    local center = targetPos + dir * (tonumber(def.barrier_ahead_distance) or 430)
    center.z = GetGroundHeight(center, target) + 20
    self:SpawnIceShardsBarrier(ownerPlayerID, caster, center, dir, def, points)
    return true
end

function DotaKartItemSystem:UseIceShards(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end

    local dir, yaw, backward = self:GetFireDirectionForPlayer(playerID, caster)
    dir = self:NormalizeDir2D(dir)
    local start = caster:GetAbsOrigin() + dir * 120 + Vector(0, 0, 92)
    local pos = Vector(start.x, start.y, start.z)
    local speed = tonumber(def.speed) or 1500
    local range = tonumber(def.travel_distance) or 1500
    local hitRadius = tonumber(def.hit_radius) or 180
    local traveled = 0
    local lastTime = DKNow()
    local serial = self:NextProjectileSerial()
    local particles = { def.projectile }
    for _, p in ipairs(def.projectile_extra or {}) do table.insert(particles, p) end
    local fxs = self:CreateMultiMissileParticles(particles, pos, dir, speed, 420)

    self:EmitKartSound(caster, def.sound_cast, start)
    self:EmitKartSound(caster, def.sound_projectile, start)
    self:ConsumeHeldItem(playerID, itemName, def)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartIceShardsProjectile_" .. tostring(serial), function()
        if not DKValidUnit(caster) then
            self:DestroyMultiMissileParticles(fxs, false)
            return nil
        end
        local now = DKNow()
        local dt = math.max(0.001, math.min(0.05, now - lastTime))
        lastTime = now
        local step = speed * dt
        traveled = traveled + step
        pos = pos + dir * step
        pos.z = GetGroundHeight(pos, nil) + 92
        self:UpdateMultiMissileParticles(fxs, pos, dir, speed, 420)

        if self:HandleSpecialProjectileTargetHit(playerID,pos,hitRadius,"ice_shards") then self:DestroyMultiMissileParticles(fxs,false); return nil end
        local target, targetPlayerID = self:FindHeroHit(playerID, pos, hitRadius)
        if DKValidUnit(target) then
            self:DestroyMultiMissileParticles(fxs, false)
            self:SpawnIceShardsInFrontOfTarget(playerID, caster, targetPlayerID, target, def)
            print("[DotaKartItems] ICE SHARDS acertou player " .. tostring(targetPlayerID) .. "; barreira criada na frente do alvo.")
            return nil
        end

        if traveled > 100 and self:IsProjectileBlockedByWorld(pos, 90, playerID) then
            self:DestroyMultiMissileParticles(fxs, false)
            return nil
        end

        if traveled >= range then
            self:DestroyMultiMissileParticles(fxs, false)
            local center = Vector(pos.x, pos.y, GetGroundHeight(pos, nil) + 20)
            self:SpawnIceShardsBarrier(playerID, caster, center, dir, def)
            return nil
        end
        return 0.02
    end, 0.02)

    print("[DotaKartItems] Player " .. tostring(playerID) .. " lançou ICE SHARDS " .. (backward and "para tras" or "para frente"))
    return true
end


-- ============================================================
-- FIX54: Chaos Bolt / Invisibility / Ice Wall
-- ============================================================
function DotaKartItemSystem:ShowChaosBoltStunText(target, duration, targetPlayerID)
    if not DKValidUnit(target) then return end
    local dur = tonumber(duration) or 0
    local shown = math.floor(dur * 100 + 0.5) / 100
    local label = string.format("%.2fs STUN", shown)
    local pos = target:GetAbsOrigin() + Vector(0, 0, 230)

    -- FIX57: o servidor envia o evento para os clientes, mas o Panorama só desenha
    -- quando a vítima está visível/na tela daquele jogador. Isso permite que espectadores
    -- próximos ou jogadores com câmera renderizando a vítima vejam o texto, sem prender
    -- o aviso apenas ao cliente atingido e sem fallback no centro da tela.
    pcall(function()
        CustomGameEventManager:Send_ServerToAllClients("dotakart_chaos_stun_text", {
            text = label,
            duration = math.min(2.20, math.max(1.10, shown)),
            entindex = target:entindex(),
            target_player_id = tonumber(targetPlayerID or self:GetPlayerIDForHero(target) or -1) or -1,
            x = pos.x,
            y = pos.y,
            z = pos.z
        })
    end)

    if self.config and self.config.debug then
        print("[DotaKartItems] Chaos Bolt stun = " .. string.format("%.2f", shown) .. "s targetPlayer=" .. tostring(targetPlayerID) .. " FIX57 visible-clients")
    end
end

function DotaKartItemSystem:UseChaosBolt(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end

    local dir, yaw, backward = self:GetFireDirectionForPlayer(playerID, caster)
    dir = self:NormalizeDir2D(dir)
    local start = caster:GetAbsOrigin() + dir * 120 + Vector(0, 0, 105)
    local pos = Vector(start.x, start.y, start.z)
    local speed = tonumber(def.speed) or 1350
    local range = tonumber(def.cast_range) or 1200
    local radius = tonumber(def.hit_radius) or 155
    local minStun = tonumber(def.min_stun) or 1.5
    local maxStun = tonumber(def.max_stun) or 6.0
    local arcHeight = tonumber(def.arc_height) or 210

    -- FIX82: Chaos Bolt agora tenta adquirir um alvo adversário dentro do alcance do item.
    -- Se encontrou alvo, o projétil fica travado nele e persegue até acertar ou bater em árvore/obstáculo.
    -- Se não encontrou alvo, mantém fallback linear curto para não quebrar o uso do item.
    local lockedTarget, lockedPlayerID, lockedDist = self:FindNearestEnemyKart(playerID, start, range)
    local hasLockedTarget = DKValidUnit(lockedTarget)

    if def.particle_launch ~= nil then self:CreateWorldParticle(def.particle_launch, start, 0.8) end
    local fx = self:CreateMissileParticle(def.particle, pos, dir, speed, 420)
    self:EmitKartSound(caster, def.sound_cast, start)
    self:ConsumeHeldItem(playerID, itemName, def)

    local serial = self:NextProjectileSerial()
    local startTime = DKNow()
    local lastTime = startTime
    local traveled = 0
    local maxTime = hasLockedTarget and (tonumber(def.locked_lifetime) or 30.0) or (range / math.max(1, speed) + 0.35)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartChaosBolt_" .. tostring(serial), function()
        if not DKValidUnit(caster) then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            return nil
        end
        local now = DKNow()
        local dt = math.max(0.001, math.min(0.05, now - lastTime))
        lastTime = now

        if hasLockedTarget then
            if not DKValidUnit(lockedTarget) or not self:IsHomingValidTarget(playerID, lockedPlayerID) then
                local decoy = tonumber(lockedPlayerID) and tonumber(lockedPlayerID) >= 0 and self:GetDoppelDecoyForOwner(lockedPlayerID) or nil
                if decoy ~= nil and DKValidUnit(decoy.unit) then
                    lockedTarget = decoy.unit
                    lockedPlayerID = decoy.target_id
                else
                    if fx ~= nil then self:DestroyLinearParticle(fx, false) end
                    return nil
                end
            end
            local targetPos = lockedTarget:GetAbsOrigin() + Vector(0,0,88)
            local desired = self:NormalizeDir2D(targetPos - pos)
            local strength = DKClamp(def.homing_strength or 0.92, 0, 0.98)
            dir = self:NormalizeDir2D(dir * (1 - strength) + desired * strength)
        end

        local step = speed * dt
        traveled = traveled + step
        local t = DKClamp((hasLockedTarget and 0.50 or (traveled / math.max(1, range))), 0, 1)
        pos = pos + dir * step
        pos.z = GetGroundHeight(pos, nil) + 96 + math.sin(t * math.pi) * arcHeight
        self:UpdateMissileParticle(fx, pos, dir, speed, 420)

        if self:BlockProjectileWithPowerCog(playerID, pos, radius * 0.90, "chaos_bolt_blocked") then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            return nil
        end

        -- Árvores/obstáculos anulam o Chaos Bolt travado. Ignora os primeiros metros para não
        -- cancelar no próprio caster ou em colisões muito próximas do ponto de disparo.
        if traveled > 220 and self:IsProjectileBlockedByWorld(pos, tonumber(def.obstacle_check_radius) or 96, playerID) then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            if self.config and self.config.debug then
                print("[DotaKartItems] Chaos Bolt bateu em árvore/obstáculo e foi anulado.")
            end
            return nil
        end

        if self:HandleSpecialProjectileTargetHit(playerID,pos,radius,"chaos_bolt") then if fx~=nil then self:DestroyLinearParticle(fx,false) end; return nil end
        local target, targetPlayerID = self:FindHeroHit(playerID, pos, radius)
        if DKValidUnit(target) then
            local stun = minStun + math.random() * math.max(0, maxStun - minStun)
            self:EmitKartSound(target, def.sound_target, target:GetAbsOrigin())
            if def.particle_explosion ~= nil then self:CreateWorldParticle(def.particle_explosion, target:GetAbsOrigin() + Vector(0,0,96), 1.2) end
            self:ApplyKartStun(caster, target, stun)
            self:ShowChaosBoltStunText(target, stun, targetPlayerID)
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            return nil
        end

        if (not hasLockedTarget and traveled >= range) or (now - startTime) >= maxTime then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            return nil
        end
        return 0.03
    end, 0.03)

    print("[DotaKartItems] FIX82 Player " .. tostring(playerID) .. " lançou CHAOS BOLT " .. (backward and "para tras" or "para frente") .. " locked=" .. tostring(hasLockedTarget) .. " target=" .. tostring(lockedPlayerID))
    return true
end

function DotaKartItemSystem:UseInvisibility(playerID, itemName, def)
    local hero = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(hero) then return false end
    local duration = tonumber(def.duration) or 15.0
    local now = DKNow()
    self.activeInvisibility = self.activeInvisibility or {}
    local data = { end_time = now + duration, fxs = {} }
    self.activeInvisibility[playerID] = data

    self:EmitKartSound(hero, def.sound_cast, hero:GetAbsOrigin())
    if def.particle ~= nil then
        local f = self:CreateAttachedParticleRobust(def.particle, hero, duration, 180)
        for _, fx in ipairs(f or {}) do table.insert(data.fxs, fx) end
    end
    if def.particle_top ~= nil then
        local f = self:CreateAttachedParticleRobust(def.particle_top, hero, duration, 180)
        for _, fx in ipairs(f or {}) do table.insert(data.fxs, fx) end
    end
    pcall(function() hero:AddNewModifier(hero, nil, "modifier_invisible", { duration = duration }) end)
    self:ConsumeHeldItem(playerID, itemName, def)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartInvisibilityEnd_" .. tostring(playerID), function()
        local cur = self.activeInvisibility and self.activeInvisibility[playerID]
        if cur ~= nil and (cur.end_time or 0) <= DKNow() + 0.05 then
            self.activeInvisibility[playerID] = nil
        end
        return nil
    end, duration)

    print("[DotaKartItems] Player " .. tostring(playerID) .. " ativou INVISIBILITY por " .. tostring(duration) .. "s")
    return true
end

function DotaKartItemSystem:DestroyIceWallSegment(seg)
    if seg == nil then return end
    if seg.fxs ~= nil then
        for _, fx in ipairs(seg.fxs) do
            pcall(function() ParticleManager:DestroyParticle(fx, false); ParticleManager:ReleaseParticleIndex(fx) end)
        end
    end
    seg.fxs = nil
end

function DotaKartItemSystem:CreateIceWallIcicleParticle(particleName, pos, fwd, visualRadius, duration)
    if particleName == nil or particleName == "" or ParticleManager == nil or pos == nil then return nil end
    local dir = self:NormalizeDir2D(fwd or Vector(1, 0, 0))
    local halfLen = math.max(36, tonumber(visualRadius or 72) or 72)
    local startPos = pos - dir * halfLen + Vector(0, 0, 20)
    local endPos = pos + dir * halfLen + Vector(0, 0, 20)
    local fx = nil
    local ok = pcall(function()
        fx = ParticleManager:CreateParticle(particleName, PATTACH_WORLDORIGIN, nil)
        -- CP0/CP1 recebem uma linha curta central. Isso evita duas linhas paralelas e
        -- deixa o icicle formar um unico rastro atras do kart.
        ParticleManager:SetParticleControl(fx, 0, startPos)
        ParticleManager:SetParticleControl(fx, 1, endPos)
        ParticleManager:SetParticleControl(fx, 2, pos + Vector(0, 0, 12))
        ParticleManager:SetParticleControl(fx, 3, Vector(halfLen, halfLen, halfLen))
    end)
    if not ok then return nil end
    if fx ~= nil and duration ~= nil and duration > 0 then
        GameRules:GetGameModeEntity():SetContextThink("DotaKartIceWallIcicleRelease_" .. tostring(fx), function()
            pcall(function()
                ParticleManager:DestroyParticle(fx, false)
                ParticleManager:ReleaseParticleIndex(fx)
            end)
            return nil
        end, duration)
    end
    return fx
end

function DotaKartItemSystem:SpawnIceWallSegment(ownerPlayerID, caster, def, pos, now, fwd)
    local lifetime = tonumber(def.segment_lifetime or def.total_duration) or 8.0
    local visualRadius = tonumber(def.visual_radius or def.segment_radius) or 72
    local seg = {
        owner = ownerPlayerID,
        pos = Vector(pos.x,pos.y,pos.z),
        expire_time = now + lifetime,
        fxs = {},
        hit_cd = {}
    }

    -- FIX57: rastro único. Evita totalmente invoker_ice_wall_shards como visual principal,
    -- porque essa partícula desenha rastros/arestas paralelas por design.
    local chosen = def.visual_particle
    if chosen == nil or chosen == "" then
        chosen = "particles/units/heroes/hero_crystalmaiden/maiden_freezing_field_snow.vpcf"
    end

    local fx = nil
    if def.visual_particle_is_icicle == true then
        fx = self:CreateIceWallIcicleParticle(chosen, seg.pos + Vector(0,0,6), fwd or Vector(1,0,0), visualRadius, lifetime)
    else
        fx = self:CreateRadiusWorldParticle(chosen, seg.pos + Vector(0,0,10), visualRadius, lifetime)
    end

    if fx ~= nil then
        table.insert(seg.fxs, fx)
    elseif def.visual_particle_fallback ~= nil and def.visual_particle_fallback ~= "" then
        local fallbackFx = self:CreateWorldParticle(def.visual_particle_fallback, seg.pos + Vector(0,0,24), lifetime)
        if fallbackFx ~= nil then table.insert(seg.fxs, fallbackFx) end
    end

    return seg
end

function DotaKartItemSystem:UseIceWall(playerID, itemName, def)
    local hero = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(hero) then return false end
    local now = DKNow()
    self.activeIceWalls = self.activeIceWalls or {}

    -- FIX57: se o jogador reusar Ice Wall antes do rastro anterior expirar,
    -- limpa o rastro antigo dele para não criar duas trilhas simultâneas.
    if self.activeIceWalls[playerID] ~= nil then
        for _, seg in ipairs(self.activeIceWalls[playerID].segments or {}) do
            self:DestroyIceWallSegment(seg)
        end
        self.activeIceWalls[playerID] = nil
    end

    local emitDuration = tonumber(def.emit_duration) or 5.0
    local segmentLifetime = tonumber(def.segment_lifetime or def.total_duration) or 8.0
    self.activeIceWalls[playerID] = {
        caster = hero,
        def = def,
        start_time = now,
        emit_until = now + emitDuration,
        -- FIX55/FIX57: não apaga tudo de uma vez; cada segmento expira no seu próprio tempo.
        cleanup_time = now + emitDuration + segmentLifetime + 0.20,
        next_spawn = now,
        next_trail_sound = now,
        segments = {}
    }
    -- FIX60: não inicia loop no caster. O som do rastro toca como one-shot posicional e com throttle no spawn do gelo.
    self:ConsumeHeldItem(playerID, itemName, def)
    print("[DotaKartItems] Player " .. tostring(playerID) .. " ativou ICE WALL FIX60 icicle single rear trail + CM trail sound")
    return true
end

function DotaKartItemSystem:UpdateIceWalls(now)
    self.activeIceWalls = self.activeIceWalls or {}
    for playerID, data in pairs(self.activeIceWalls) do
        local caster = data.caster or self:GetHeroForPlayer(playerID)
        local def = data.def or self.itemDefs.item_kaya or {}
        if data.cleanup_time ~= nil and now >= data.cleanup_time then
            for _, seg in ipairs(data.segments or {}) do self:DestroyIceWallSegment(seg) end
            self.activeIceWalls[playerID] = nil
        else
            if DKValidUnit(caster) and now <= (data.emit_until or 0) and now >= (data.next_spawn or 0) then
                data.next_spawn = now + (tonumber(def.spawn_interval) or 0.14)
                -- FIX57: usa yaw do kart/controller, não apenas ForwardVector do herói,
                -- para garantir que o gelo nasce atrás do kart no sistema de câmera/controle MK64.
                local fwd = self:GetForwardForPlayer(playerID, caster)
                fwd = self:NormalizeDir2D(fwd or Vector(1,0,0))
                local right = Vector(-fwd.y, fwd.x, 0)
                local base = caster:GetAbsOrigin()
                local p = base - fwd * (tonumber(def.segment_back_offset) or 190) + right * (tonumber(def.segment_side_offset) or 0)
                p.z = GetGroundHeight(p, caster)
                table.insert(data.segments, self:SpawnIceWallSegment(playerID, caster, def, p, now, fwd))

                -- FIX60: som curto no ponto onde o rastro aparece. Throttle evita spam/loop.
                if def.sound_trail ~= nil and now >= (data.next_trail_sound or 0) then
                    data.next_trail_sound = now + (tonumber(def.sound_trail_interval) or 0.70)
                    self:EmitKartWorldSound(caster, def.sound_trail, p)
                end
            end
            local alive = {}
            for _, seg in ipairs(data.segments or {}) do
                if seg ~= nil and now < (seg.expire_time or 0) then
                    table.insert(alive, seg)
                    self:DestroyDoppelDecoysInRadius(playerID, seg.pos, tonumber(def.segment_radius) or 175, "ice_wall")
                    for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
                        if tonumber(otherID) ~= tonumber(playerID) and not self:IsPlayerStarActive(otherID) and not self:IsKartUntargetable(otherID) then
                            local other = self:GetHeroForPlayer(otherID)
                            if DKValidUnit(other) and DKLength2D(seg.pos, other:GetAbsOrigin()) <= (tonumber(def.segment_radius) or 175) then
                                self:ApplyKartSlow(caster, other, tonumber(def.slow_refresh) or 0.20, tonumber(def.slow_pct) or 0.60, 0, 0.03)
                                seg.hit_cd = seg.hit_cd or {}
                                if (seg.hit_cd[otherID] or 0) <= now then
                                    seg.hit_cd[otherID] = now + 0.45
                                    if def.particle_shatter ~= nil then self:CreateAttachedParticleRobust(def.particle_shatter, other, 0.45, 180) end
                                    self:EmitKartSound(other, def.sound_slow, other:GetAbsOrigin())
                                end
                            end
                        end
                    end
                else
                    self:DestroyIceWallSegment(seg)
                end
            end
            data.segments = alive
        end
    end
end

-- ============================================================
-- FIX108: Battle Hunger
-- ============================================================
function DotaKartItemSystem:DestroyParticleListNow(list)
    if list == nil or ParticleManager == nil then return end
    for _, fx in ipairs(list) do
        if fx ~= nil then
            pcall(function()
                ParticleManager:DestroyParticle(fx, false)
                ParticleManager:ReleaseParticleIndex(fx)
            end)
        end
    end
end

function DotaKartItemSystem:ClearBattleHungerByVictim(victimPlayerID, reason)
    self.activeBattleHungers = self.activeBattleHungers or {}
    victimPlayerID = tonumber(victimPlayerID) or -1
    local data = self.activeBattleHungers[victimPlayerID]
    if data == nil then return false end

    local casterID = tonumber(data.casterPlayerID) or -1
    local victimSt = self:GetState(victimPlayerID)
    local casterSt = self:GetState(casterID)
    if victimSt ~= nil then
        victimSt.battle_hunger_slow_until = 0
        victimSt.battle_hunger_slow_pct = 0
    end
    if casterSt ~= nil then
        casterSt.battle_hunger_bonus_until = 0
        casterSt.battle_hunger_bonus_pct = 0
    end

    self:DestroyParticleListNow(data.caster_fxs)
    self:DestroyParticleListNow(data.victim_fxs)
    if data.victim_start_fx ~= nil and ParticleManager ~= nil then
        pcall(function()
            ParticleManager:DestroyParticle(data.victim_start_fx, false)
            ParticleManager:ReleaseParticleIndex(data.victim_start_fx)
        end)
    end
    self.activeBattleHungers[victimPlayerID] = nil

    if self.config and self.config.debug then
        print("[DotaKartItems] FIX108 Battle Hunger removido victim=" .. tostring(victimPlayerID) .. " caster=" .. tostring(casterID) .. " reason=" .. tostring(reason or "end"))
    end
    return true
end

function DotaKartItemSystem:NotifyBattleHungerItemHit(ownerPlayerID, targetPlayerID)
    ownerPlayerID = tonumber(ownerPlayerID) or -1
    targetPlayerID = tonumber(targetPlayerID) or -1
    if ownerPlayerID < 0 or targetPlayerID < 0 or ownerPlayerID == targetPlayerID then return false end
    local data = self.activeBattleHungers and self.activeBattleHungers[ownerPlayerID]
    if data == nil or (data.end_time or 0) <= DKNow() then return false end
    return self:ClearBattleHungerByVictim(ownerPlayerID, "victim_hit_kart_with_item")
end

function DotaKartItemSystem:UpdateBattleHungers(now)
    local expired = {}
    for victimID, data in pairs(self.activeBattleHungers or {}) do
        local victim = self:GetHeroForPlayer(victimID)
        local caster = self:GetHeroForPlayer(tonumber(data.casterPlayerID) or -1)
        if not DKValidUnit(victim) or not DKValidUnit(caster) or now >= (data.end_time or 0) then
            table.insert(expired, { id = victimID, reason = "duration" })
        elseif self:IsPlayerStarActive(victimID) then
            -- Star/BKB já é o estado global de imunidade a debuffs do DotA Kart.
            table.insert(expired, { id = victimID, reason = "victim_invulnerable" })
        else
            if ParticleManager ~= nil then
                local body = victim:GetAbsOrigin() + Vector(0,0,90)
                for _, fx in ipairs(data.victim_world_fxs or {}) do
                    pcall(function()
                        ParticleManager:SetParticleControl(fx, 0, body)
                        ParticleManager:SetParticleControl(fx, 1, body)
                        ParticleManager:SetParticleControl(fx, 2, body)
                    end)
                end
                if data.victim_start_fx ~= nil then
                    local overhead = victim:GetAbsOrigin() + Vector(0,0,1000)
                    pcall(function()
                        ParticleManager:SetParticleControl(data.victim_start_fx, 0, overhead)
                        ParticleManager:SetParticleControl(data.victim_start_fx, 1, overhead)
                        ParticleManager:SetParticleControl(data.victim_start_fx, 2, overhead)
                    end)
                end
            end
        end
    end
    for _, e in ipairs(expired) do self:ClearBattleHungerByVictim(e.id, e.reason) end
end

function DotaKartItemSystem:UseBattleHunger(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end
    local _, _, backward = self:GetFireDirectionForPlayer(playerID, caster)
    local place = tonumber(self:GetPlaceForPlayer(playerID)) or 1
    local targetID = nil
    if place <= 1 then
        -- FIX116: líder sempre aplica Battle Hunger no 2º colocado, independentemente de T/S+T.
        targetID = self:GetPlayerIDOnePlaceBehind(playerID)
    else
        targetID = backward and self:GetPlayerIDOnePlaceBehind(playerID) or self:GetPlayerIDOnePlaceAhead(playerID)
    end
    if targetID == nil or targetID < 0 then
        if self.config and self.config.debug then print("[DotaKartItems] FIX108 Battle Hunger sem alvo de colocação; item mantido.") end
        return true
    end
    local target = self:GetHeroForPlayer(targetID)
    if not DKValidUnit(target) or self:IsPlayerStarActive(targetID) or self:IsKartUntargetable(targetID) then return true end

    -- Se o caster estiver atualmente como vítima de outro Battle Hunger, este cast é
    -- um item que atingiu outro kart e portanto quebra o efeito anterior primeiro.
    self:NotifyBattleHungerItemHit(playerID, targetID)

    -- Um caster mantém apenas um Battle Hunger ofensivo por vez; isso evita que
    -- o fim de um cast antigo apague o bônus de um cast mais novo.
    local outgoingVictims = {}
    for victimID, active in pairs(self.activeBattleHungers or {}) do
        if tonumber(active.casterPlayerID) == tonumber(playerID) then table.insert(outgoingVictims, victimID) end
    end
    for _, victimID in ipairs(outgoingVictims) do self:ClearBattleHungerByVictim(victimID, "caster_recast") end

    -- Um alvo só mantém um Battle Hunger ativo; renovar substitui o par anterior.
    if self.activeBattleHungers[targetID] ~= nil then
        self:ClearBattleHungerByVictim(targetID, "replaced")
    end

    local now = DKNow()
    local duration = tonumber(def.duration) or 15.0
    local casterSt = self:GetState(playerID)
    local victimSt = self:GetState(targetID)
    if casterSt == nil or victimSt == nil then return false end

    casterSt.battle_hunger_bonus_until = now + duration
    casterSt.battle_hunger_bonus_pct = tonumber(def.caster_speed_bonus_pct) or 0.15
    victimSt.battle_hunger_slow_until = now + duration
    victimSt.battle_hunger_slow_pct = tonumber(def.victim_slow_pct) or 0.15

    local data = {
        casterPlayerID = playerID,
        victimPlayerID = targetID,
        caster = caster,
        victim = target,
        def = def,
        end_time = now + duration,
        caster_fxs = {},
        victim_fxs = {},
        victim_world_fxs = {},
        victim_start_fx = nil
    }
    self.activeBattleHungers[targetID] = data

    data.caster_fxs = self:CreateAttachedParticleRobust(def.particle_caster, caster, nil, 210)

    -- FIX113: axe_battle_hunger.vpcf não é mais anexado ao esqueleto/attach_hitloc
    -- da vítima. Isso impede o particle de usar attachments da cabeça (o efeito
    -- temporário de chifres). Ele vive em WORLDORIGIN e acompanha apenas a origem
    -- do kart por control points numéricos.
    if def.particle_debuff ~= nil and ParticleManager ~= nil then
        local ok, fx = pcall(function()
            local pfx = ParticleManager:CreateParticle(def.particle_debuff, PATTACH_WORLDORIGIN, nil)
            local body = target:GetAbsOrigin() + Vector(0,0,90)
            ParticleManager:SetParticleControl(pfx, 0, body)
            ParticleManager:SetParticleControl(pfx, 1, body)
            ParticleManager:SetParticleControl(pfx, 2, body)
            return pfx
        end)
        if ok and fx ~= nil then
            table.insert(data.victim_fxs, fx)
            table.insert(data.victim_world_fxs, fx)
        end
    end

    -- FIX111: axe_battle_hunger_start fica 1000 units acima da origem da vítima, bem separado da cabeça/modelo.
    -- World-follow evita depender de attach_hitloc/attach_overhead existentes no modelo do kart.
    if def.particle_start ~= nil and ParticleManager ~= nil then
        local ok, fx = pcall(function()
            local pfx = ParticleManager:CreateParticle(def.particle_start, PATTACH_WORLDORIGIN, nil)
            local overhead = target:GetAbsOrigin() + Vector(0,0,1000)
            ParticleManager:SetParticleControl(pfx, 0, overhead)
            ParticleManager:SetParticleControl(pfx, 1, overhead)
            ParticleManager:SetParticleControl(pfx, 2, overhead)
            return pfx
        end)
        if ok then data.victim_start_fx = fx end
    end
    self:EmitKartSound(target, def.sound, target:GetAbsOrigin())
    self:ConsumeHeldItem(playerID, itemName, def)

    print("[DotaKartItems] FIX108 Player " .. tostring(playerID) .. " usou BATTLE HUNGER em player " .. tostring(targetID) .. " " .. (backward and "para tras" or "para frente") .. " duration=" .. tostring(duration))
    return true
end

-- ============================================================
-- FIX108: X Marks the Spot
-- ============================================================
function DotaKartItemSystem:DestroyXMark(targetPlayerID, data, reason)
    if data == nil or data.destroyed == true then return end
    data.destroyed = true

    -- FIX114: xmark_target_movement é longo; encerra junto com a marca para não
    -- continuar tocando depois do retorno/substituição/invalidação.
    local markedForSound = data.target or self:GetHeroForPlayer(targetPlayerID)
    if DKValidUnit(markedForSound) and data.def ~= nil then
        self:StopKartSound(markedForSound, data.def.sound_movement)
    end

    if data.line_fx ~= nil then self:DestroyLinearParticle(data.line_fx, false) end
    if data.victim_line_fx ~= nil and ParticleManager ~= nil then
        pcall(function()
            ParticleManager:DestroyParticle(data.victim_line_fx, false)
            ParticleManager:ReleaseParticleIndex(data.victim_line_fx)
        end)
    end
    for _, fx in ipairs(data.trail_fxs or {}) do
        if fx ~= nil then self:DestroyLinearParticle(fx, false) end
    end
    if data.mark_fx ~= nil and ParticleManager ~= nil then
        pcall(function()
            ParticleManager:DestroyParticle(data.mark_fx, false)
            ParticleManager:ReleaseParticleIndex(data.mark_fx)
        end)
    end
    local target = data.target or self:GetHeroForPlayer(targetPlayerID)
    if DKValidUnit(target) then self:StopKartSound(target, data.def and data.def.sound_movement or nil) end
    if self.activeXMarks ~= nil and self.activeXMarks[targetPlayerID] == data then self.activeXMarks[targetPlayerID] = nil end
end

function DotaKartItemSystem:IsXMarkReturnBlocked(targetPlayerID, target)
    if not DKValidUnit(target) then return true end
    if self:IsPlayerStarActive(targetPlayerID) or self:IsPlayerInvisible(targetPlayerID) then return true end
    local blocked = false
    pcall(function() if target:IsInvulnerable() then blocked = true end end)
    pcall(function() if target:IsOutOfGame() then blocked = true end end)
    pcall(function() if target:IsAlive() == false then blocked = true end end)
    return blocked
end

function DotaKartItemSystem:CreateXMarkGroundParticle(particleName, markPos)
    if particleName == nil or particleName == "" or ParticleManager == nil or markPos == nil then return nil end
    local fx = nil
    local p = markPos + Vector(0,0,12)
    local ok = pcall(function()
        fx = ParticleManager:CreateParticle(particleName, PATTACH_WORLDORIGIN, nil)
        -- Kunkka particles variam no uso de CPs entre versões; alimentar vários CPs
        -- com o mesmo ponto deixa o X estável sem prender ao kart atingido.
        ParticleManager:SetParticleControl(fx, 0, p)
        ParticleManager:SetParticleControl(fx, 1, p)
        ParticleManager:SetParticleControl(fx, 2, p)
        ParticleManager:SetParticleControl(fx, 3, p)
    end)
    if not ok then return nil end
    return fx
end

function DotaKartItemSystem:CreateXMarkTrailSegment(data, fromPos, toPos)
    if data == nil or data.def == nil or data.def.particle_line == nil then return end
    local a = Vector(fromPos.x, fromPos.y, GetGroundHeight(fromPos, nil) + 18)
    local b = Vector(toPos.x, toPos.y, GetGroundHeight(toPos, nil) + 18)
    if DKLength2D(a, b) < 18 then return end
    local fx = self:CreateLinearParticle(data.def.particle_line, a, b)
    if fx ~= nil then
        data.trail_fxs = data.trail_fxs or {}
        table.insert(data.trail_fxs, fx)
    end
end

function DotaKartItemSystem:ReturnXMarkedKart(targetPlayerID, data)
    if data == nil or data.returned == true then return end
    data.returned = true
    local target = data.target or self:GetHeroForPlayer(targetPlayerID)

    if DKValidUnit(target) and not self:IsXMarkReturnBlocked(targetPlayerID, target) then
        local st = self:GetState(targetPlayerID)
        local savedSpeed = st and st.speed or nil
        local savedYaw = st and st.yaw or nil
        local dest = Vector(data.mark_pos.x, data.mark_pos.y, GetGroundHeight(data.mark_pos, target))
        if self.controller ~= nil and self.controller.config ~= nil then
            dest.z = dest.z + (tonumber(self.controller.config.ground_z_offset) or 0)
        end

        -- FIX109: retorno direto e determinístico. FindClearSpaceForUnit podia deslocar o kart
        -- para fora do X; o controller já resolve colisões no tick seguinte.
        pcall(function()
            target:SetAbsOrigin(dest)
            if ResolveNPCPositions ~= nil then ResolveNPCPositions(dest, 96) end
        end)
        if st ~= nil then
            if savedSpeed ~= nil then st.speed = savedSpeed end
            if savedYaw ~= nil then st.yaw = savedYaw end
        end
        if self.controller ~= nil and self.controller.SetHeroFacing ~= nil and savedYaw ~= nil then
            pcall(function() self.controller:SetHeroFacing(target, savedYaw) end)
        end

        -- Return VFX com CPs redundantes no ponto do X para maximizar compatibilidade.
        local returnFx = self:CreateXMarkGroundParticle(data.def.particle_return, dest + Vector(0,0,55))
        if returnFx ~= nil then
            GameRules:GetGameModeEntity():SetContextThink("DotaKartXMarkReturnFX_" .. tostring(returnFx), function()
                pcall(function()
                    ParticleManager:DestroyParticle(returnFx, false)
                    ParticleManager:ReleaseParticleIndex(returnFx)
                end)
                return nil
            end, 1.1)
        end
        self:EmitKartSound(target, data.def.sound_return, dest)
        print("[DotaKartItems] FIX109 X MARK retornou player " .. tostring(targetPlayerID) .. " ao ponto marcado.")
    elseif DKValidUnit(target) then
        print("[DotaKartItems] FIX109 X MARK desperdiçado: target invulnerable/hidden player=" .. tostring(targetPlayerID))
    end

    self:DestroyXMark(targetPlayerID, data, "finished")
end

function DotaKartItemSystem:ApplyXMark(ownerPlayerID, targetPlayerID, target, def)
    targetPlayerID = tonumber(targetPlayerID) or -1
    if targetPlayerID < 0 or not DKValidUnit(target) then return false end
    self.activeXMarks = self.activeXMarks or {}
    local old = self.activeXMarks[targetPlayerID]
    if old ~= nil then self:DestroyXMark(targetPlayerID, old, "replaced") end

    local now = DKNow()
    local duration = tonumber(def.duration) or 5.0
    local raw = target:GetAbsOrigin()
    local markPos = Vector(raw.x, raw.y, GetGroundHeight(raw, target))
    local data = {
        ownerPlayerID = ownerPlayerID,
        targetPlayerID = targetPlayerID,
        target = target,
        def = def,
        mark_pos = markPos,
        end_time = now + duration,
        mark_fx = nil,
        line_fx = nil,
        victim_line_fx = nil,
        trail_fxs = {},
        last_trail_pos = Vector(raw.x, raw.y, raw.z),
        next_trail_time = now + 0.08,
        returned = false,
        destroyed = false,
        uses_context_think = true
    }

    -- X fica no chão durante a duração configurada (FIX111: 5 segundos).
    data.mark_fx = self:CreateXMarkGroundParticle(def.particle_mark, markPos)
    -- Linha dinâmica inicial do X até a vítima, além dos segmentos que ficam para trás.
    data.line_fx = self:CreateLinearParticle(def.particle_line, markPos + Vector(0,0,18), raw + Vector(0,0,18))
    -- FIX110: o particle original de Kunkka também é emitido diretamente PELA vítima.
    -- Ele fica attached durante toda a duração do X e pode executar o comportamento de trilha interno do VPCF,
    -- em vez de depender somente dos CPs lineares world-origin usados como fallback.
    if def.particle_line ~= nil and ParticleManager ~= nil then
        local ok, fx = pcall(function()
            return ParticleManager:CreateParticle(def.particle_line, PATTACH_ABSORIGIN_FOLLOW, target)
        end)
        if ok then data.victim_line_fx = fx end
    end
    self.activeXMarks[targetPlayerID] = data
    self:EmitKartSound(target, def.sound_target, raw)
    self:EmitKartSound(target, def.sound_movement, raw)

    -- FIX109: thinker próprio do X Marks. O retorno não depende mais do OnThink geral
    -- do sistema de itens e portanto não pode ser perdido por outro update do item system.
    local serial = self:NextProjectileSerial()
    GameRules:GetGameModeEntity():SetContextThink("DotaKartXMarkActive_" .. tostring(serial), function()
        if data.destroyed == true then return nil end
        local marked = data.target or self:GetHeroForPlayer(targetPlayerID)
        if not DKValidUnit(marked) then
            self:DestroyXMark(targetPlayerID, data, "invalid")
            return nil
        end

        local t = DKNow()
        local cur = marked:GetAbsOrigin()
        if data.line_fx ~= nil then
            self:UpdateLinearParticle(data.line_fx, data.mark_pos + Vector(0,0,18), cur + Vector(0,0,18))
        end

        if t >= (data.next_trail_time or 0) then
            if DKLength2D(data.last_trail_pos, cur) >= 35 then
                self:CreateXMarkTrailSegment(data, data.last_trail_pos, cur)
                data.last_trail_pos = Vector(cur.x, cur.y, cur.z)
            end
            data.next_trail_time = t + 0.08
        end

        if t >= (data.end_time or 0) then
            self:ReturnXMarkedKart(targetPlayerID, data)
            return nil
        end
        return 0.03
    end, 0.03)

    print("[DotaKartItems] FIX109 X MARK aplicado player=" .. tostring(targetPlayerID) .. " duration=" .. tostring(duration))
    return true
end

function DotaKartItemSystem:UpdateXMarks(now)
    -- FIX109: marcas novas possuem thinker próprio. Mantém apenas limpeza de entradas
    -- legadas/sem thinker para não executar o retorno duas vezes.
    local stale = {}
    for targetID, data in pairs(self.activeXMarks or {}) do
        if data.uses_context_think ~= true and now >= (data.end_time or 0) then
            table.insert(stale, { id = targetID, data = data })
        end
    end
    for _, e in ipairs(stale) do self:ReturnXMarkedKart(e.id, e.data) end
end

function DotaKartItemSystem:UseXMarks(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end
    local dir, yaw, backward = self:GetFireDirectionForPlayer(playerID, caster)
    dir = self:NormalizeDir2D(dir)
    local start = caster:GetAbsOrigin() + dir * 130 + Vector(0,0,92)
    local pos = Vector(start.x, start.y, start.z)
    local speed = tonumber(def.speed) or 1800
    local range = tonumber(def.cast_range) or 2000
    local radius = tonumber(def.hit_radius) or 165
    local fx = self:CreateMissileParticle(def.particle_projectile, pos, dir, speed, 360)

    self:ConsumeHeldItem(playerID, itemName, def)
    local serial = self:NextProjectileSerial()
    local lastTime = DKNow()
    local traveled = 0

    GameRules:GetGameModeEntity():SetContextThink("DotaKartXMarksProjectile_" .. tostring(serial), function()
        if not DKValidUnit(caster) then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            return nil
        end
        local now = DKNow()
        local dt = math.max(0.001, math.min(0.05, now - lastTime))
        lastTime = now
        local step = speed * dt
        traveled = traveled + step
        pos = pos + dir * step
        pos.z = GetGroundHeight(pos, nil) + 92
        self:UpdateMissileParticle(fx, pos, dir, speed, 360)

        if self:HandleSpecialProjectileTargetHit(playerID,pos,radius,"x_marks") then if fx~=nil then self:DestroyLinearParticle(fx,false) end; return nil end
        local target, targetPlayerID = self:FindHeroHit(playerID, pos, radius)
        if DKValidUnit(target) and targetPlayerID ~= nil and targetPlayerID >= 0 then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            self:NotifyBattleHungerItemHit(playerID, targetPlayerID)
            self:ApplyXMark(playerID, targetPlayerID, target, def)
            return nil
        end
        if traveled >= range then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            return nil
        end
        return 0.02
    end, 0.02)

    print("[DotaKartItems] FIX109 Player " .. tostring(playerID) .. " lançou X MARKS " .. (backward and "para tras" or "para frente") .. " range=" .. tostring(range))
    return true
end

-- ============================================================
-- FIX117: Doppelwalk / Shukuchi / Crystal Clone
-- ============================================================
function DotaKartItemSystem:GetDoppelDecoyByTargetID(targetID)
    local id = tonumber(targetID)
    if id == nil or id > -1000 then return nil end
    local data = self.activeDoppelwalkDecoys and self.activeDoppelwalkDecoys[id]
    if data ~= nil and DKValidUnit(data.unit) and DKNow() < (data.end_time or 0) then return data end
    return nil
end

function DotaKartItemSystem:GetDoppelDecoyForOwner(ownerPlayerID)
    local data = self.activeDoppelwalkDecoys and self.activeDoppelwalkDecoys["owner_" .. tostring(tonumber(ownerPlayerID) or -1)]
    if data ~= nil and DKValidUnit(data.unit) and DKNow() < (data.end_time or 0) then return data end
    return nil
end

function DotaKartItemSystem:GetHomingTargetUnit(targetID)
    targetID = tonumber(targetID) or -1
    if targetID <= -1000 then
        local data = self:GetDoppelDecoyByTargetID(targetID)
        return data and data.unit or nil
    end
    return self:GetHeroForPlayer(targetID)
end

function DotaKartItemSystem:DestroyDoppelDecoy(data, reason)
    if data == nil or data.destroyed == true then return end
    data.destroyed = true
    local unit = data.unit
    local tid = tonumber(data.target_id)
    local owner = tonumber(data.owner_player_id) or -1
    if self.activeDoppelwalkDecoys ~= nil then
        if tid ~= nil then self.activeDoppelwalkDecoys[tid] = nil end
        local k = "owner_" .. tostring(owner)
        if self.activeDoppelwalkDecoys[k] == data then self.activeDoppelwalkDecoys[k] = nil end
    end
    if DKValidUnit(unit) then pcall(function() unit:ForceKill(false) end); pcall(function() UTIL_Remove(unit) end) end
end

function DotaKartItemSystem:GetTrackForDoppelwalk()
    local hud = self.hud or GameRules.DotaKartHUD
    if hud ~= nil and (hud.trackWorldPoints == nil or #hud.trackWorldPoints < 2) and hud.BuildTrackPathFromEntities ~= nil then
        pcall(function() hud:BuildTrackPathFromEntities("dk_track_", 1024, true, 512) end)
    end
    return (hud and hud.trackWorldPoints) or {}
end

function DotaKartItemSystem:FindNearestTrackIndexForDoppel(pos, track)
    local best, bestDist = 1, 99999999
    for i, p in ipairs(track or {}) do
        local d = DKLength2D(pos, p)
        if d < bestDist then best, bestDist = i, d end
    end
    return best
end

function DotaKartItemSystem:UseDoppelwalk(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end
    local duration = tonumber(def.duration) or 8.0
    local now = DKNow()
    local old = self:GetDoppelDecoyForOwner(playerID)
    if old ~= nil then self:DestroyDoppelDecoy(old, "replaced") end
    self:EmitKartSound(caster, def.sound, caster:GetAbsOrigin())
    if def.particle ~= nil then self:CreateAttachedParticleRobust(def.particle, caster, 1.2, 180) end
    pcall(function() caster:AddNewModifier(caster, nil, "modifier_invisible", { duration = duration }) end)

    local clone = nil
    if CreateIllusions ~= nil then
        local ok, list = pcall(function()
            return CreateIllusions(caster, caster, { duration = duration, outgoing_damage = 0, incoming_damage = 100, bounty_base = 0, bounty_growth = 0 }, 1, 0, false, false)
        end)
        if ok and list ~= nil then clone = list[1] end
    end
    if not DKValidUnit(clone) and SpawnEntityFromTableSynchronous ~= nil then
        local modelName = nil
        pcall(function() modelName = tostring(caster:GetModelName() or "") end)
        if modelName ~= nil and modelName ~= "" then
            pcall(function()
                clone = SpawnEntityFromTableSynchronous("prop_dynamic", { model = modelName, solid = "0", DefaultAnim = "idle" })
                clone:SetAbsOrigin(caster:GetAbsOrigin())
                clone:SetAngles(0, caster:GetAngles().y, 0)
                if clone.SetModelScale ~= nil and caster.GetModelScale ~= nil then clone:SetModelScale(caster:GetModelScale()) end
            end)
        end
    end
    if DKValidUnit(clone) then
        pcall(function() if clone.SetControllableByPlayer ~= nil then clone:SetControllableByPlayer(playerID, false) end end)
        pcall(function() if clone.SetIdleAcquire ~= nil then clone:SetIdleAcquire(false) end; if clone.SetAcquisitionRange ~= nil then clone:SetAcquisitionRange(0) end; if clone.SetAttackCapability ~= nil then clone:SetAttackCapability(DOTA_UNIT_CAP_NO_ATTACK) end end)
        pcall(function() if clone.AddNewModifier ~= nil then clone:AddNewModifier(clone, nil, "modifier_disarmed", { duration = duration }) end end)
        pcall(function() if clone.RemoveModifierByName ~= nil then clone:RemoveModifierByName("modifier_invisible") end end)
        local track = self:GetTrackForDoppelwalk()
        self.nextDoppelTargetID = (tonumber(self.nextDoppelTargetID) or -1000) - 1
        local targetID = self.nextDoppelTargetID
        local st = self:GetState(playerID)
        local data = { target_id=targetID, owner_player_id=playerID, unit=clone, end_time=now+duration, track=track,
            track_index=self:FindNearestTrackIndexForDoppel(clone:GetAbsOrigin(), track),
            speed=math.max(tonumber(st and st.speed or 0) or 0, tonumber(self.controller and self.controller.config and self.controller.config.max_speed or 880) or 880) }
        self.activeDoppelwalkDecoys[targetID] = data
        self.activeDoppelwalkDecoys["owner_" .. tostring(playerID)] = data
    end
    local st = self:GetState(playerID)
    if st ~= nil then st.doppelwalk_bonus_until=now+duration; st.doppelwalk_bonus_pct=tonumber(def.move_speed_bonus_pct) or 0.10 end
    self:ConsumeHeldItem(playerID, itemName, def)
    return true
end

function DotaKartItemSystem:UpdateDoppelwalkDecoys(now)
    for key, data in pairs(self.activeDoppelwalkDecoys or {}) do
        if type(key) == "number" and data ~= nil then
            local unit = data.unit
            if not DKValidUnit(unit) or now >= (data.end_time or 0) then
                self:DestroyDoppelDecoy(data, "expired")
            else
                local track = data.track or {}
                if #track >= 2 then
                    local idx = tonumber(data.track_index) or 1
                    local nextIdx = idx + 1; if nextIdx > #track then nextIdx = 1 end
                    local pos = unit:GetAbsOrigin(); local target = track[nextIdx]
                    local to = target - pos; to.z = 0
                    local dist = math.sqrt(to.x*to.x + to.y*to.y)
                    if dist < 170 then data.track_index = nextIdx else
                        local dir = self:NormalizeDir2D(to)
                        local step = math.min(dist, (tonumber(data.speed) or 880) * (tonumber(self.config.tick_rate) or 0.06))
                        local dest = pos + dir * step; dest.z = GetGroundHeight(dest, unit)
                        unit:SetAbsOrigin(dest); pcall(function() unit:SetForwardVector(dir) end)
                    end
                end
            end
        end
    end
end

function DotaKartItemSystem:UseShukuchi(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end
    local now = DKNow(); local duration = tonumber(def.duration) or 4.0; local fade = tonumber(def.fade_time) or 0.25
    local data = { caster=caster, invis_time=now+fade, end_time=now+duration, hit_ids={}, def=def }
    self.activeShukuchi[playerID] = data
    local st = self:GetState(playerID)
    if st ~= nil then
        st.shukuchi_until=data.end_time; st.shukuchi_phased_until=data.end_time
        local base=tonumber(self.controller and self.controller.config and self.controller.config.max_speed or 880) or 880
        st.shukuchi_haste_speed=math.max(tonumber(def.haste_speed) or 550, base*(tonumber(def.max_speed_multiplier) or 1.5))
    end
    self:EmitKartSound(caster, def.sound, caster:GetAbsOrigin())
    if def.particle ~= nil then self:CreateAttachedParticleRobust(def.particle, caster, duration, 180) end
    GameRules:GetGameModeEntity():SetContextThink("DotaKartShukuchiFade_"..tostring(self:NextProjectileSerial()), function()
        if self.activeShukuchi[playerID] == data and DKValidUnit(caster) then
            pcall(function() caster:AddNewModifier(caster,nil,"modifier_invisible",{duration=math.max(0.05,data.end_time-DKNow())}) end)
        end
        return nil
    end, fade)
    self:ConsumeHeldItem(playerID,itemName,def)
    return true
end

function DotaKartItemSystem:UpdateShukuchi(now)
    for playerID,data in pairs(self.activeShukuchi or {}) do
        local caster=data.caster or self:GetHeroForPlayer(playerID)
        if not DKValidUnit(caster) or now >= (data.end_time or 0) then self.activeShukuchi[playerID]=nil else
            local def=data.def or self.itemDefs.item_dotakart_shukuchi or {}; local radius=tonumber(def.radius) or 175
            self:DestroyDoppelDecoysInRadius(playerID, caster:GetAbsOrigin(), radius, "shukuchi")
            for _,otherID in ipairs(self:GetRegisteredPlayerIDs()) do
                if tonumber(otherID) ~= tonumber(playerID) and data.hit_ids[otherID] ~= true then
                    local other=self:GetHeroForPlayer(otherID)
                    if DKValidUnit(other) and DKLength2D(caster:GetAbsOrigin(),other:GetAbsOrigin()) <= radius then
                        data.hit_ids[otherID]=true; self:ApplyKartStun(caster,other,tonumber(def.stun_duration) or 0.5)
                        if def.particle_damage then self:CreateAttachedParticleRobust(def.particle_damage,other,0.75,180) end
                        if def.particle_damage_arc then self:CreateAttachedParticleRobust(def.particle_damage_arc,other,0.75,180) end
                    end
                end
            end
        end
    end
end

-- ============================================================
-- FIX120: Astral Imprisonment / Ball Lightning
-- ============================================================
function DotaKartItemSystem:GetAstralDesiredTarget(playerID, caster, def)
    local range = tonumber(def.cast_range) or 1500
    local st = self:GetState(playerID)
    local backward = st ~= nil and st.input ~= nil and st.input.reverse == true and st.input.forward ~= true
    local targetID = backward and self:GetPlayerIDOnePlaceBehind(playerID) or self:GetPlayerIDOnePlaceAhead(playerID)
    if targetID ~= nil and targetID >= 0 and not self:IsKartUntargetable(targetID) and not self:IsPlayerStarActive(targetID) then
        local target = self:GetHeroForPlayer(targetID)
        if self:IsPlayerInvisible(targetID) then
            local decoy = self:GetDoppelDecoyForOwner(targetID)
            if decoy ~= nil and DKValidUnit(decoy.unit) then
                target = decoy.unit
                targetID = decoy.target_id
            else
                target = nil
            end
        end
        if DKValidUnit(target) and DKLength2D(caster:GetAbsOrigin(), target:GetAbsOrigin()) <= range then
            return target, targetID
        end
    end
    return self:FindNearestEnemyKart(playerID, caster:GetAbsOrigin(), range)
end

function DotaKartItemSystem:CreateAstralStaticFX(target, def, duration)
    local fxs = {}
    if not DKValidUnit(target) or ParticleManager == nil then return fxs end
    local pos = target:GetAbsOrigin()
    if def.particle_start then self:CreateWorldParticle(def.particle_start, pos, 1.0) end
    for _, name in ipairs({def.particle_prison, def.particle_ring}) do
        if name and name ~= "" then
            local fx = nil
            pcall(function()
                fx = ParticleManager:CreateParticle(name, PATTACH_WORLDORIGIN, nil)
                ParticleManager:SetParticleControl(fx, 0, pos)
            end)
            if fx ~= nil then table.insert(fxs, fx) end
        end
    end
    return fxs
end

function DotaKartItemSystem:CreateAstralFollowFX(target, def)
    local fxs = {}
    if not DKValidUnit(target) or ParticleManager == nil then return fxs end
    local pos = target:GetAbsOrigin()
    if def.particle_start then self:CreateWorldParticle(def.particle_start, pos, 1.0) end

    -- FIX122: self Astral is the mobile Aghanim's Shard behavior. Attach the
    -- visual directly to the kart so it follows reliably while the kart drives.
    -- The unit itself remains visible.
    for _, name in ipairs({def.particle_prison, def.particle_ring, def.particle_shard_self, def.particle_shard_orb}) do
        if name and name ~= "" then
            local fx = nil
            pcall(function()
                fx = ParticleManager:CreateParticle(name, PATTACH_ABSORIGIN_FOLLOW, target)
                ParticleManager:SetParticleControlEnt(fx, 0, target, PATTACH_ABSORIGIN_FOLLOW, "attach_origin", pos, true)
                ParticleManager:SetParticleControlEnt(fx, 1, target, PATTACH_ABSORIGIN_FOLLOW, "attach_origin", pos, true)
            end)
            if fx ~= nil then table.insert(fxs, fx) end
        end
    end
    return fxs
end

function DotaKartItemSystem:FinishAstral(data, reason)
    if data == nil or data.finished == true then return end
    data.finished = true
    local target = data.target
    local playerID = tonumber(data.target_player_id) or -1
    self.activeAstrals[playerID] = nil
    if data.fxs and ParticleManager then
        for _,fx in ipairs(data.fxs) do pcall(function() ParticleManager:DestroyParticle(fx,false); ParticleManager:ReleaseParticleIndex(fx) end) end
    end
    if DKValidUnit(target) then
        pcall(function() target:RemoveModifierByName(data.self_cast and "modifier_dotakart_astral_self" or "modifier_dotakart_astral_enemy") end)
        pcall(function() target:RemoveNoDraw() end)
        if data.def and data.def.particle_end then self:CreateWorldParticle(data.def.particle_end, target:GetAbsOrigin(), 1.2) end
        self:StopKartSound(target, data.def and data.def.sound_loop)
        self:EmitKartSound(target, data.def and data.def.sound_stop, target:GetAbsOrigin())
    end
    local st = self:GetState(playerID)
    if st ~= nil then
        st.astral_enemy_until = 0
        st.astral_self_until = 0
    end
end

function DotaKartItemSystem:StartAstral(playerID, itemName, def, target, targetPlayerID, selfCast)
    if not DKValidUnit(target) then return false end
    targetPlayerID = tonumber(targetPlayerID) or -1
    if targetPlayerID < 0 then return false end
    local now = DKNow()
    local existing = self.activeAstrals[targetPlayerID]
    if existing ~= nil then
        if existing.finished == true or not DKValidUnit(existing.target) or now >= (tonumber(existing.end_time) or 0) then
            self:FinishAstral(existing, "stale_replace")
        else
            return false
        end
    end
    local dur = tonumber(def.duration) or 4.0
    local data = {caster_player_id=playerID,target_player_id=targetPlayerID,target=target,self_cast=selfCast==true,end_time=now+dur,def=def}
    data.fxs = selfCast and self:CreateAstralFollowFX(target,def) or self:CreateAstralStaticFX(target,def,dur)
    self.activeAstrals[targetPlayerID] = data
    local st = self:GetState(targetPlayerID)
    if st ~= nil then
        if selfCast then
            st.astral_self_until = data.end_time
        else
            st.astral_enemy_until = data.end_time; st.speed = 0
        end
    end
    if selfCast then pcall(function() target:RemoveNoDraw() end) end
    pcall(function() target:AddNewModifier(target,nil,selfCast and "modifier_dotakart_astral_self" or "modifier_dotakart_astral_enemy",{duration=dur}) end)
    self:EmitKartSound(target,def.sound_cast,target:GetAbsOrigin())
    self:EmitKartSound(target,def.sound_loop,target:GetAbsOrigin())
    self:ConsumeHeldItem(playerID,itemName,def)
    return true
end

function DotaKartItemSystem:UseAstralImprisonment(playerID,itemName,def)
    local caster=self:GetHeroForPlayer(playerID); if not DKValidUnit(caster) then return false end
    local target,targetID=self:GetAstralDesiredTarget(playerID,caster,def)
    if not DKValidUnit(target) then return false end
    if tonumber(targetID) and tonumber(targetID) <= -1000 then
        local decoy=self:GetDoppelDecoyByTargetID(targetID)
        if decoy then self:DestroyDoppelDecoy(decoy,"astral_imprisonment"); self:ConsumeHeldItem(playerID,itemName,def); return true end
        return false
    end
    return self:StartAstral(playerID,itemName,def,target,targetID,false)
end

function DotaKartItemSystem:UseAstralSelf(playerID,itemName,def)
    local caster=self:GetHeroForPlayer(playerID); if not DKValidUnit(caster) then return false end
    return self:StartAstral(playerID,itemName,def,caster,playerID,true)
end

function DotaKartItemSystem:UseSelfItem(playerID)
    local itemName=self:GetHeldItem(playerID); local def=self.itemDefs[itemName or ""]
    if def == nil or def.kind ~= "astral_imprisonment" then return false end
    local ok = self:UseAstralSelf(playerID,itemName,def)
    if not ok then
        self:SendItemHint(playerID, "ASTRAL SELF-CAST UNAVAILABLE", 1.4)
    end
    return ok
end

function DotaKartItemSystem:UpdateAstrals(now)
    local finish={}
    for _,data in pairs(self.activeAstrals or {}) do
        if data and (not DKValidUnit(data.target) or now >= (data.end_time or 0)) then
            table.insert(finish,data)
        elseif data and data.self_cast == true and DKValidUnit(data.target) then
            -- Attached Shard visuals follow the moving kart automatically in FIX122.
            pcall(function() data.target:RemoveNoDraw() end)
        end
    end
    for _,data in ipairs(finish) do self:FinishAstral(data,"expired") end
end

function DotaKartItemSystem:CreateBallLightningFX(caster,def)
    local fxs={}; if not DKValidUnit(caster) or ParticleManager==nil then return fxs end
    local names={def.particle_main}
    for _,n in ipairs(def.particles_active or {}) do table.insert(names,n) end
    for _,name in ipairs(names) do
        if name and name~="" then
            local fx=nil
            pcall(function()
                fx=ParticleManager:CreateParticle(name,PATTACH_ABSORIGIN_FOLLOW,caster)
                ParticleManager:SetParticleControlEnt(fx,0,caster,PATTACH_ABSORIGIN_FOLLOW,"",caster:GetAbsOrigin(),true)
            end)
            if fx~=nil then table.insert(fxs,fx) end
        end
    end
    return fxs
end

function DotaKartItemSystem:SendItemHint(playerID, text, duration)
    if CustomGameEventManager == nil or PlayerResource == nil then return end
    local player = PlayerResource:GetPlayer(tonumber(playerID) or -1)
    if player ~= nil then
        CustomGameEventManager:Send_ServerToPlayer(player, "dotakart_item_hint", {
            text = tostring(text or ""),
            duration = tonumber(duration) or 1.8
        })
    end
end

function DotaKartItemSystem:IsFakeClientPlayer(playerID)
    if PlayerResource == nil or PlayerResource.IsFakeClient == nil then return false end
    local ok, value = pcall(function() return PlayerResource:IsFakeClient(tonumber(playerID) or -1) end)
    return ok and value == true
end

function DotaKartItemSystem:BeginBallLightningHold(playerID, itemName, def)
    self.pendingBallLightning = self.pendingBallLightning or {}
    if self.activeBallLightning and self.activeBallLightning[playerID] ~= nil then return true end
    if self.pendingBallLightning[playerID] ~= nil then return true end

    -- Public AI does not generate a physical key-up/key-down hold sequence.
    if self:IsFakeClientPlayer(playerID) then
        return self:UseBallLightning(playerID, itemName, def)
    end

    local holdTime = math.max(0.10, tonumber(def.hold_time) or 0.22)
    local token = self:NextProjectileSerial()
    self.pendingBallLightning[playerID] = { token = token, item_name = itemName, def = def, started = DKNow() }
    GameRules:GetGameModeEntity():SetContextThink("DotaKartBallLightningArm_" .. tostring(playerID) .. "_" .. tostring(token), function()
        local pending = self.pendingBallLightning and self.pendingBallLightning[playerID] or nil
        if pending == nil or pending.token ~= token then return nil end
        local st = self:GetState(playerID)
        if st == nil or st.item_button_down ~= true or self:GetHeldItem(playerID) ~= itemName then
            self.pendingBallLightning[playerID] = nil
            return nil
        end
        local now = DKNow()
        if self.controller ~= nil then
            if (self.controller.IsKartStunned and self.controller:IsKartStunned(playerID, now)) or
               (self.controller.IsKartLocked and self.controller:IsKartLocked(playerID, now)) then
                self.pendingBallLightning[playerID] = nil
                return nil
            end
        end
        self.pendingBallLightning[playerID] = nil
        self:UseBallLightning(playerID, itemName, def)
        return nil
    end, holdTime)
    return true
end

function DotaKartItemSystem:EndBallLightning(playerID,reason)
    local data=self.activeBallLightning and self.activeBallLightning[playerID]; if data==nil then return end
    self.activeBallLightning[playerID]=nil
    local caster=data.caster
    local remnantPos = DKValidUnit(caster) and caster:GetAbsOrigin() or data.last_pos
    if data.fxs and ParticleManager then for _,fx in ipairs(data.fxs) do pcall(function() ParticleManager:DestroyParticle(fx,false); ParticleManager:ReleaseParticleIndex(fx) end) end end
    if DKValidUnit(caster) then
        pcall(function() caster:RemoveModifierByName("modifier_dotakart_ball_lightning") end)
        self:StopKartSound(caster,data.def and data.def.sound_loop)
        if data.def and data.def.particle_end then self:CreateWorldParticle(data.def.particle_end,caster:GetAbsOrigin()+Vector(0,0,72),1.0) end
        self:EmitKartSound(caster,data.def and data.def.sound_end,caster:GetAbsOrigin())
    end
    local st=self:GetState(playerID); if st then st.ball_lightning_active=false; st.ball_lightning_speed=0; st.ball_lightning_acceleration=0 end

    -- FIX123: releasing T only PAUSES Ball Lightning. The item and remaining distance
    -- charges stay in the slot and can be resumed by holding T again. It is consumed
    -- only when the counter really reaches zero.
    local remaining = math.max(0, math.ceil(tonumber(data.remaining) or 0))
    if reason == "charges_empty" or remaining <= 0 then
        self.itemCharges[playerID]=nil
        if self:GetHeldItem(playerID)==data.item_name then self:SetHeldItemHUD(playerID,"",0) end
        if remnantPos ~= nil then self:SpawnStaticRemnant(playerID, remnantPos, data.def) end
    else
        self.itemCharges[playerID]=remaining
        if self:GetHeldItem(playerID)==data.item_name then
            self:SetHeldItemHUD(playerID,data.item_name,remaining)
        end
    end
end

function DotaKartItemSystem:UseBallLightning(playerID,itemName,def)
    -- FIX131: Ball Lightning is a T-toggle. A second press stops the effect but
    -- preserves the remaining charges/item. Releasing T does nothing.
    if self.activeBallLightning[playerID]~=nil then
        -- Public AI previously behaved like a continuously held T and should keep
        -- spending charges until empty; only human T presses toggle the effect off.
        if self:IsFakeClientPlayer(playerID) then return true end
        self:EndBallLightning(playerID,"toggle_off")
        return true
    end
    local caster=self:GetHeroForPlayer(playerID); if not DKValidUnit(caster) then return false end
    -- FIX123: resume from the charge count left by the previous T release.
    local charges=tonumber(self.itemCharges[playerID]) or tonumber(def.charges_distance) or 6000
    if charges <= 0 then return false end
    local data={caster=caster,item_name=itemName,def=def,remaining=charges,last_pos=Vector(caster:GetAbsOrigin().x,caster:GetAbsOrigin().y,caster:GetAbsOrigin().z),last_hud=charges}
    data.fxs=self:CreateBallLightningFX(caster,def)
    self.activeBallLightning[playerID]=data
    local st=self:GetState(playerID)
    if st then st.ball_lightning_active=true; st.ball_lightning_speed=tonumber(def.travel_speed) or 1900; st.ball_lightning_acceleration=tonumber(def.travel_acceleration) or 5200 end
    pcall(function() caster:AddNewModifier(caster,nil,"modifier_dotakart_ball_lightning",{duration=-1}) end)
    self:EmitKartSound(caster,def.sound_start,caster:GetAbsOrigin())
    self:EmitKartSound(caster,def.sound_loop,caster:GetAbsOrigin())
    self.itemCharges[playerID]=charges
    self:SetHeldItemHUD(playerID,itemName,math.floor(charges))
    return true
end

function DotaKartItemSystem:OnItemButtonReleased(playerID)
    -- FIX131: Ball Lightning no longer uses hold/release semantics. Only T press
    -- toggles it, so key-up must never stop the effect or alter its charges.
    if self.pendingBallLightning and self.pendingBallLightning[playerID] ~= nil then
        self.pendingBallLightning[playerID] = nil
    end
    return false
end

function DotaKartItemSystem:UpdateBallLightning(now)
    local ending={}
    for playerID,data in pairs(self.activeBallLightning or {}) do
        local caster=data.caster
        if not DKValidUnit(caster) then table.insert(ending,{playerID,"invalid"}) else
            local pos=caster:GetAbsOrigin(); local dist=DKLength2D(data.last_pos,pos); data.last_pos=Vector(pos.x,pos.y,pos.z)
            if dist<500 then data.remaining=math.max(0,(tonumber(data.remaining) or 0)-dist) end
            local shown=math.max(0,math.ceil(data.remaining or 0)); self.itemCharges[playerID]=shown
            if math.abs(shown-(tonumber(data.last_hud) or shown))>=25 then data.last_hud=shown; self:SetHeldItemHUD(playerID,data.item_name,shown) end
            if (data.remaining or 0)<=0 then table.insert(ending,{playerID,"charges_empty"}) end
        end
    end
    for _,e in ipairs(ending) do self:EndBallLightning(e[1],e[2]) end
end


-- ============================================================
-- FIX121: Static Remnant created when Ball Lightning fully depletes.
-- ============================================================
function DotaKartItemSystem:CreateStaticRemnantFX(pos, def)
    local fxs = {}
    if pos == nil or ParticleManager == nil then return fxs end
    for _,name in ipairs((def and def.remnant_particles) or {}) do
        if name and name ~= "" then
            local fx = nil
            pcall(function()
                fx = ParticleManager:CreateParticle(name, PATTACH_WORLDORIGIN, nil)
                ParticleManager:SetParticleControl(fx, 0, pos)
                ParticleManager:SetParticleControl(fx, 1, pos)
            end)
            if fx ~= nil then table.insert(fxs, fx) end
        end
    end
    return fxs
end

function DotaKartItemSystem:DestroyStaticRemnantFX(data)
    if data == nil or data.fxs == nil or ParticleManager == nil then return end
    for _,fx in ipairs(data.fxs) do
        pcall(function()
            ParticleManager:DestroyParticle(fx, false)
            ParticleManager:ReleaseParticleIndex(fx)
        end)
    end
    data.fxs = nil
end

function DotaKartItemSystem:SpawnStaticRemnant(ownerPlayerID, pos, def)
    if pos == nil then return nil end
    def = def or self.itemDefs.item_dotakart_ball_lightning or {}
    local now = DKNow()
    local id = self:NextProjectileSerial()
    local ground = Vector(pos.x, pos.y, pos.z)
    local owner = self:GetHeroForPlayer(ownerPlayerID)
    if DKValidUnit(owner) then ground.z = GetGroundHeight(ground, owner) end
    local data = {
        id = id,
        owner_player_id = tonumber(ownerPlayerID) or -1,
        pos = ground,
        activation_time = now + (tonumber(def.remnant_activation_delay) or 0.75),
        end_time = now + (tonumber(def.remnant_duration) or 12.0),
        def = def,
        exploded = false
    }
    data.fxs = self:CreateStaticRemnantFX(ground, def)
    self.activeStaticRemnants[id] = data
    self:EmitKartWorldSound(owner, def.remnant_sound_plant, ground)
    return data
end

function DotaKartItemSystem:ExplodeStaticRemnant(data, reason)
    if data == nil or data.exploded == true then return end
    data.exploded = true
    if self.activeStaticRemnants then self.activeStaticRemnants[data.id] = nil end
    self:DestroyStaticRemnantFX(data)

    local def = data.def or self.itemDefs.item_dotakart_ball_lightning or {}
    local pos = data.pos
    local owner = self:GetHeroForPlayer(data.owner_player_id)
    if pos == nil then return end

    self:EmitKartWorldSound(owner, def.remnant_sound_explode, pos)
    -- Short explosion flash using the supplied Storm Spirit remnant assets.
    for _,name in ipairs({
        "particles/units/heroes/hero_stormspirit/stormspirit_static_remnant_points.vpcf",
        "particles/units/heroes/hero_stormspirit/stormspirit_static_remnant_glow.vpcf",
        "particles/units/heroes/hero_stormspirit/storm_spirit_static_remnant_beam_ambient_arcs.vpcf"
    }) do
        self:CreateWorldParticle(name, pos, 0.9)
    end

    local radius = tonumber(def.remnant_trigger_radius) or 235
    local slowDuration = tonumber(def.remnant_slow_duration) or 0.8
    local slowPct = tonumber(def.remnant_slow_pct) or 0.80

    self:DestroyDoppelDecoysInRadius(data.owner_player_id, pos, radius, "static_remnant")
    for _,otherID in ipairs(self:GetRegisteredPlayerIDs()) do
        if tonumber(otherID) ~= tonumber(data.owner_player_id) then
            local other = self:GetHeroForPlayer(otherID)
            if DKValidUnit(other) and DKLength2D(pos, other:GetAbsOrigin()) <= radius then
                self:ApplyKartSlow(owner or other, other, slowDuration, slowPct, 0, 0.03)
            end
        end
    end
end

function DotaKartItemSystem:UpdateStaticRemnants(now)
    local expired = {}
    for id,data in pairs(self.activeStaticRemnants or {}) do
        if data == nil or data.exploded == true then
            table.insert(expired, id)
        elseif now >= (tonumber(data.end_time) or 0) then
            self:DestroyStaticRemnantFX(data)
            table.insert(expired, id)
        elseif now >= (tonumber(data.activation_time) or 0) then
            local radius = tonumber(data.def and data.def.remnant_trigger_radius) or 235
            local shouldExplode = false

            -- Doppelwalk copies behave as enemy hero-like units for trap triggering.
            for _,decoy in pairs(self.activeDoppelwalkDecoys or {}) do
                if decoy and tonumber(decoy.owner_player_id) ~= tonumber(data.owner_player_id) and DKValidUnit(decoy.unit) then
                    if DKLength2D(data.pos, decoy.unit:GetAbsOrigin()) <= radius then
                        shouldExplode = true
                        break
                    end
                end
            end

            if not shouldExplode then
                for _,otherID in ipairs(self:GetRegisteredPlayerIDs()) do
                    if tonumber(otherID) ~= tonumber(data.owner_player_id) and not self:IsKartUntargetable(otherID) then
                        local other = self:GetHeroForPlayer(otherID)
                        if DKValidUnit(other) and DKLength2D(data.pos, other:GetAbsOrigin()) <= radius then
                            shouldExplode = true
                            break
                        end
                    end
                end
            end

            if shouldExplode then self:ExplodeStaticRemnant(data, "enemy_proximity") end
        end
    end
    for _,id in ipairs(expired) do if self.activeStaticRemnants then self.activeStaticRemnants[id] = nil end end
end

function DotaKartItemSystem:UseCrystalClone(playerID,itemName,def)
    local caster=self:GetHeroForPlayer(playerID); if not DKValidUnit(caster) then return false end
    local pos=caster:GetAbsOrigin(); local clone=nil
    if SpawnEntityFromTableSynchronous ~= nil then
        pcall(function()
            clone=SpawnEntityFromTableSynchronous("prop_dynamic", {
                model=(def.model or "models/heroes/crystal_maiden/crystal_maiden_deathsim.vmdl"),
                solid="0",
                DefaultAnim="idle"
            })
            clone:SetAbsOrigin(pos)
            clone:SetAngles(0,caster:GetAngles().y,0)
        end)
    end
    if not DKValidUnit(clone) then return false end
    local duration=tonumber(def.duration) or 90.0
    self:EmitKartSound(clone,def.sound_cast,pos)
    local fx=nil
    if def.particle_status and ParticleManager then pcall(function() fx=ParticleManager:CreateParticle(def.particle_status,PATTACH_ABSORIGIN_FOLLOW,clone); ParticleManager:SetParticleControlEnt(fx,0,clone,PATTACH_ABSORIGIN_FOLLOW,"",clone:GetAbsOrigin(),true) end) end
    local id=self:NextProjectileSerial()
    local data={id=id,owner_player_id=playerID,unit=clone,pos=Vector(pos.x,pos.y,pos.z),end_time=DKNow()+duration,def=def,fx=fx,owner_clear=false}
    self.activeCrystalClones[id]=data
    self:ConsumeHeldItem(playerID,itemName,def)
    return true
end

-- FIX118: Frostbite visual exclusivo do Crystal Clone.
-- Nao sobrescreve CPs internos dos particles da Valve; apenas prende o CP0 ao kart.
function DotaKartItemSystem:ApplyCrystalCloneFrostbiteVisuals(target, duration, def)
    if not DKValidUnit(target) or ParticleManager == nil then return end
    local dur = math.max(0.1, tonumber(duration) or 2.5)
    local particles = (def and def.frostbite_particles) or {}
    for _, particleName in ipairs(particles) do
        if particleName ~= nil and particleName ~= "" then
            local fx = nil
            local ok = pcall(function()
                fx = ParticleManager:CreateParticle(particleName, PATTACH_ABSORIGIN_FOLLOW, target)
                ParticleManager:SetParticleControlEnt(fx, 0, target, PATTACH_ABSORIGIN_FOLLOW, "", target:GetAbsOrigin(), true)
            end)
            if ok and fx ~= nil then
                GameRules:GetGameModeEntity():SetContextThink("DotaKartCrystalFrostbiteFX_" .. tostring(fx), function()
                    pcall(function()
                        ParticleManager:DestroyParticle(fx, false)
                        ParticleManager:ReleaseParticleIndex(fx)
                    end)
                    return nil
                end, dur)
            end
        end
    end
end

function DotaKartItemSystem:ExplodeCrystalClone(data,reason)
    if data==nil or data.exploded==true then return end; data.exploded=true; self.activeCrystalClones[data.id]=nil
    local def=data.def or self.itemDefs.item_dotakart_crystal_clone or {}; local unit=data.unit; local pos=DKValidUnit(unit) and unit:GetAbsOrigin() or data.pos
    if data.fx and ParticleManager then pcall(function() ParticleManager:DestroyParticle(data.fx,false); ParticleManager:ReleaseParticleIndex(data.fx) end) end
    if pos then
        for _,name in ipairs({def.particle_end,def.particle_snow,def.particle_ring,def.particle_blast,def.particle_shock}) do if name and name~="" then self:CreateWorldParticle(name,pos+Vector(0,0,40),1.5) end end
        self:EmitKartWorldSound(unit,def.sound_destroy,pos)
        self:DestroyDoppelDecoysInRadius(data.owner_player_id, pos, tonumber(def.frostbite_radius) or 600, "crystal_clone_frostbite")
        for _,otherID in ipairs(self:GetRegisteredPlayerIDs()) do
            local other=self:GetHeroForPlayer(otherID)
            local ownerProtected = tonumber(otherID) == tonumber(data.owner_player_id) and data.owner_clear ~= true
            if (not ownerProtected) and DKValidUnit(other) and DKLength2D(pos,other:GetAbsOrigin()) <= (tonumber(def.frostbite_radius) or 600) then
                local frostDef = { root_immunity_after = 0, sound_root_hit = def.sound_frostbite }
                if self:ApplyKartRoot(unit or other, otherID, other, tonumber(def.root_duration) or 2.5, frostDef) then
                    self:ApplyCrystalCloneFrostbiteVisuals(other, tonumber(def.root_duration) or 2.5, def)
                end
            end
        end
    end
    if DKValidUnit(unit) then
        pcall(function() if unit.ForceKill ~= nil then unit:ForceKill(false) end end)
        pcall(function() UTIL_Remove(unit) end)
    end
end

function DotaKartItemSystem:UpdateCrystalClones(now)
    for _,data in pairs(self.activeCrystalClones or {}) do
        local unit=data.unit
        if not DKValidUnit(unit) or now >= (data.end_time or 0) then
            if data.fx and ParticleManager then pcall(function() ParticleManager:DestroyParticle(data.fx,false); ParticleManager:ReleaseParticleIndex(data.fx) end) end
            self.activeCrystalClones[data.id]=nil; if DKValidUnit(unit) then pcall(function() UTIL_Remove(unit) end) end
        else
            local pos=unit:GetAbsOrigin(); local hitRadius=tonumber(data.def and data.def.collision_radius) or 155
            local ownerHero=self:GetHeroForPlayer(data.owner_player_id)
            if data.owner_clear ~= true and DKValidUnit(ownerHero) and DKLength2D(pos,ownerHero:GetAbsOrigin()) > (hitRadius + 60) then data.owner_clear=true end
            for _,playerID in ipairs(self:GetRegisteredPlayerIDs()) do
                local hero=self:GetHeroForPlayer(playerID)
                local canHit=(tonumber(playerID)~=tonumber(data.owner_player_id)) or data.owner_clear==true
                if canHit and DKValidUnit(hero) and DKLength2D(pos,hero:GetAbsOrigin()) <= hitRadius then
                    self:ExplodeCrystalClone(data,"kart_collision")
                    break
                end
            end
        end
    end
end

function DotaKartItemSystem:DestroyDoppelDecoysInRadius(ownerPlayerID, pos, radius, sourceKind)
    if pos == nil then return 0 end
    radius = tonumber(radius) or 155
    local victims = {}
    for key, data in pairs(self.activeDoppelwalkDecoys or {}) do
        if type(key) == "number" and data ~= nil and tonumber(data.owner_player_id) ~= tonumber(ownerPlayerID) and DKValidUnit(data.unit) then
            if DKLength2D(pos, data.unit:GetAbsOrigin()) <= radius then table.insert(victims, data) end
        end
    end
    for _, data in ipairs(victims) do self:DestroyDoppelDecoy(data, sourceKind or "area_item") end
    return #victims
end

function DotaKartItemSystem:HandleSpecialProjectileTargetHit(ownerPlayerID,pos,radius,sourceKind)
    if pos==nil then return false end; radius=tonumber(radius) or 155
    -- FIX126: an orbiting Plague Ward is a persistent projectile shield. Traveling
    -- Swarm beetles are intentionally not attackable; only latched Beetles can be hit.
    if self:BlockProjectileWithPlagueWard(ownerPlayerID,pos,radius,sourceKind) then return true end
    local latchedBeetle = self:FindLatchedSwarmBeetleHit(ownerPlayerID,pos,radius)
    if latchedBeetle ~= nil then
        -- FIX127: a latched Beetle can be killed by an incoming projectile, but it is
        -- not a projectile shield. The same projectile continues and may still hit
        -- the racer underneath it.
        self:DestroySwarmBeetle(latchedBeetle,sourceKind or "projectile")
    end
    for key,data in pairs(self.activeDoppelwalkDecoys or {}) do
        if type(key)=="number" and data and tonumber(data.owner_player_id)~=tonumber(ownerPlayerID) and DKValidUnit(data.unit) and DKLength2D(pos,data.unit:GetAbsOrigin())<=radius then self:DestroyDoppelDecoy(data,sourceKind or "item_hit"); return true end
    end
    for _,data in pairs(self.activeCrystalClones or {}) do
        if data and DKValidUnit(data.unit) then
            local ownerCanTrigger = tonumber(data.owner_player_id) ~= tonumber(ownerPlayerID) or data.owner_clear == true
            if ownerCanTrigger and DKLength2D(pos,data.unit:GetAbsOrigin())<=radius then
                self:ExplodeCrystalClone(data,sourceKind or "projectile")
                return true
            end
        end
    end
    return false
end

-- ============================================================
-- FIX111: Torrent Storm
-- Um Torrent a cada 0.25s por 5s, distribuído ciclicamente pelos quatro quadrantes.
-- Cada Torrent possui warning próprio, delay 1.6s, raio 225, slow 40%/4s,
-- stun/lock 1.6s e knock-up 1.53s. O airborne reutiliza o pass-through do Burrowstrike.
-- ============================================================
function DotaKartItemSystem:CreateTorrentStormParticle(particleName, pos, duration)
    if particleName == nil or particleName == "" or ParticleManager == nil or pos == nil then return nil end
    local fx = nil
    local ok = pcall(function()
        fx = ParticleManager:CreateParticle(particleName, PATTACH_WORLDORIGIN, nil)
        ParticleManager:SetParticleControl(fx, 0, pos)
        ParticleManager:SetParticleControl(fx, 1, pos)
        ParticleManager:SetParticleControl(fx, 2, pos)
    end)
    if not ok then return nil end
    if fx ~= nil and duration ~= nil and tonumber(duration) ~= nil and tonumber(duration) > 0 then
        GameRules:GetGameModeEntity():SetContextThink("DotaKartTorrentParticle_" .. tostring(fx), function()
            pcall(function()
                ParticleManager:DestroyParticle(fx, false)
                ParticleManager:ReleaseParticleIndex(fx)
            end)
            return nil
        end, tonumber(duration))
    end
    return fx
end

function DotaKartItemSystem:ApplyTorrentKnockup(casterPlayerID, caster, targetPlayerID, target, def)
    if not DKValidUnit(target) or self:IsPlayerStarActive(targetPlayerID) or self:IsKartUntargetable(targetPlayerID) then return end
    local stunDur = tonumber(def.stun_duration) or 1.6
    local airDur = tonumber(def.knockup_duration) or 1.53
    local slowDur = tonumber(def.slow_duration) or 4.0
    local slowPct = tonumber(def.move_slow_pct) or 0.40
    local height = tonumber(def.knockup_height) or 420
    local now = DKNow()

    -- Slow e stun começam juntos. Para o custom kart controller usamos lock em vez do
    -- stun giratório estilo Mario Kart; assim o thinker vertical não é forçado de volta ao chão.
    self:ApplyKartSlow(caster, target, slowDur, slowPct, 0, 0.03)
    self:LockKart(targetPlayerID, stunDur)
    pcall(function() target:AddNewModifier(caster or target, nil, "modifier_stunned", { duration = stunDur }) end)

    local st = self:GetState(targetPlayerID)
    local alreadyAirborne = st ~= nil and (tonumber(st.burrow_airborne_until or 0) or 0) > now
    if st ~= nil then
        st.burrow_airborne_until = math.max(tonumber(st.burrow_airborne_until or 0) or 0, now + airDur)
    end
    pcall(function() target:AddNewModifier(caster or target, nil, "modifier_dotakart_burrow_airborne", { duration = airDur }) end)

    -- Se outro Torrent/Burrow já está controlando a altura, apenas renova stun/slow/pass-through.
    if alreadyAirborne then return end

    local base = target:GetAbsOrigin()
    local baseX, baseY = base.x, base.y
    local startTime = now
    local serial = self:NextProjectileSerial()
    GameRules:GetGameModeEntity():SetContextThink("DotaKartTorrentKnockup_" .. tostring(serial), function()
        if not DKValidUnit(target) then return nil end
        local tnow = DKNow()
        local t = DKClamp((tnow - startTime) / math.max(0.01, airDur), 0, 1)
        local ground = GetGroundHeight(Vector(baseX, baseY, base.z), target)
        local z = ground + math.sin(math.pi * t) * height
        target:SetAbsOrigin(Vector(baseX, baseY, z))
        if tnow >= startTime + airDur then
            local final = Vector(baseX, baseY, GetGroundHeight(Vector(baseX, baseY, base.z), target))
            target:SetAbsOrigin(final)
            return nil
        end
        return 0.03
    end, 0.03)
end

function DotaKartItemSystem:EruptTorrentStormTorrent(casterPlayerID, caster, def, pos, warningFx)
    if warningFx ~= nil and ParticleManager ~= nil then
        pcall(function()
            ParticleManager:DestroyParticle(warningFx, false)
            ParticleManager:ReleaseParticleIndex(warningFx)
        end)
    end

    self:CreateTorrentStormParticle(def.particle_splash, pos, 1.10)
    self:EmitKartWorldSound(caster, def.sound_hit, pos)

    local radius = tonumber(def.effect_radius) or 225
    self:DestroyDoppelDecoysInRadius(casterPlayerID, pos, radius, "torrent_storm")
    for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
        if tonumber(otherID) ~= tonumber(casterPlayerID) then
            local other = self:GetHeroForPlayer(otherID)
            if DKValidUnit(other) and not self:IsPlayerStarActive(otherID) and not self:IsKartUntargetable(otherID) and DKLength2D(pos, other:GetAbsOrigin()) <= radius then
                self:NotifyBattleHungerItemHit(casterPlayerID, otherID)
                self:ApplyTorrentKnockup(casterPlayerID, caster, otherID, other, def)
            end
        end
    end
end

function DotaKartItemSystem:SpawnTorrentStormTorrent(casterPlayerID, caster, def, spawnIndex, startQuadrant)
    if not DKValidUnit(caster) then return end
    local minR = tonumber(def.min_spawn_radius) or 115
    local maxR = tonumber(def.max_spawn_radius) or 1500
    local quadrant = ((tonumber(startQuadrant) or 0) + (tonumber(spawnIndex) or 0)) % 4
    local angleDeg = quadrant * 90 + DKRandomFloat(0.0, 90.0)
    local radius = DKRandomFloat(minR, maxR)
    local rad = math.rad(angleDeg)
    local center = caster:GetAbsOrigin()
    local pos = center + Vector(math.cos(rad) * radius, math.sin(rad) * radius, 0)
    pos.z = GetGroundHeight(pos, caster) + 8

    -- O wave é o aviso visível durante os 1.6s anteriores à erupção.
    local delay = tonumber(def.effect_delay) or 1.6
    local warningFx = self:CreateTorrentStormParticle(def.particle_wave, pos, delay + 0.15)
    self:EmitKartWorldSound(caster, def.sound_pre, pos)

    local serial = self:NextProjectileSerial()
    GameRules:GetGameModeEntity():SetContextThink("DotaKartTorrentStormErupt_" .. tostring(serial), function()
        if DKValidUnit(caster) then
            self:EruptTorrentStormTorrent(casterPlayerID, caster, def, pos, warningFx)
        elseif warningFx ~= nil and ParticleManager ~= nil then
            pcall(function()
                ParticleManager:DestroyParticle(warningFx, false)
                ParticleManager:ReleaseParticleIndex(warningFx)
            end)
        end
        return nil
    end, delay)
end

function DotaKartItemSystem:UseTorrentStorm(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end

    local duration = tonumber(def.storm_duration) or 5.0
    local interval = math.max(0.05, tonumber(def.spawn_interval) or 0.25)
    local total = math.max(1, math.floor(duration / interval + 0.0001))
    local startQuadrant = DKRandomInt(0, 3)
    local spawned = 0
    local serial = self:NextProjectileSerial()

    self:ConsumeHeldItem(playerID, itemName, def)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartTorrentStorm_" .. tostring(serial), function()
        if not DKValidUnit(caster) or spawned >= total then return nil end
        self:SpawnTorrentStormTorrent(playerID, caster, def, spawned, startQuadrant)
        spawned = spawned + 1
        if spawned >= total then return nil end
        return interval
    end, 0.0)

    print("[DotaKartItems] FIX111 Player " .. tostring(playerID) .. " ativou TORRENT STORM torrents=" .. tostring(total))
    return true
end

-- ============================================================
-- FIX122: Homing Missile
-- Follows dk_track_* waypoints until close to its locked adjacent-position target,
-- then chases directly. Speed increases over time; stun scales with traveled distance.
-- ============================================================
function DotaKartItemSystem:GetHomingMissileStun(distance, def)
    distance = math.max(0, tonumber(distance) or 0)
    local points = {
        {1200, 2.5}, {2000, 3.0}, {4000, 4.0}, {6000, 5.0}, {8000, 6.0}
    }
    if distance <= points[1][1] then return tonumber(def.min_stun) or 2.5 end
    for i = 1, #points - 1 do
        local a, b = points[i], points[i + 1]
        if distance <= b[1] then
            local t = (distance - a[1]) / math.max(1, b[1] - a[1])
            return a[2] + (b[2] - a[2]) * t
        end
    end
    return tonumber(def.max_stun) or 6.0
end

function DotaKartItemSystem:SpawnHomingMissileVisual(def, pos, yaw, caster)
    def = def or {}
    local ent = nil
    local model = def.model or "models/items/gyrocopter/dwarven_gyrocopter_off_hand/dwarven_gyrocopter_off_hand.vmdl"
    local visualUnit = def.visual_unit or "npc_dota_gyrocopter_homing_missile"
    local team = DOTA_TEAM_NEUTRALS or 4
    if DKValidUnit(caster) and caster.GetTeamNumber ~= nil then
        pcall(function() team = caster:GetTeamNumber() end)
    end

    -- FIX124: a prop_dynamic could remain invisible with some wearable-only Gyrocopter
    -- models. Spawn the native networked Homing Missile unit first, then force the
    -- requested model on it. This produces a real rendered flying entity on clients.
    if CreateUnitByName ~= nil then
        pcall(function()
            ent = CreateUnitByName(visualUnit, pos, false, caster, caster, team)
        end)
    end

    -- Fallback only if the native missile unit cannot be created on a particular build.
    if ent == nil then
        pcall(function()
            ent = SpawnEntityFromTableSynchronous("prop_dynamic", {
                model = model,
                origin = tostring(pos.x) .. " " .. tostring(pos.y) .. " " .. tostring(pos.z),
                angles = "0 " .. tostring(yaw or 0) .. " 0",
                solid = "0"
            })
        end)
    end

    if ent ~= nil and (ent.IsNull == nil or not ent:IsNull()) then
        pcall(function()
            if ent.SetOriginalModel ~= nil then ent:SetOriginalModel(model) end
            if ent.SetModel ~= nil then ent:SetModel(model) end
            if ent.SetAbsOrigin ~= nil then ent:SetAbsOrigin(pos) end
            if ent.SetAngles ~= nil then ent:SetAngles(0, yaw or 0, 0) end
            if ent.SetForwardVector ~= nil then
                local r = math.rad(yaw or 0)
                ent:SetForwardVector(Vector(math.cos(r), math.sin(r), 0))
            end
            if ent.RemoveNoDraw ~= nil then ent:RemoveNoDraw() end
            if ent.SetRenderAlpha ~= nil then ent:SetRenderAlpha(255) end
            if ent.SetModelScale ~= nil then ent:SetModelScale(tonumber(def.model_scale) or 1.0) end
            if ent.SetHullRadius ~= nil then ent:SetHullRadius(0) end
            if ent.SetBaseMoveSpeed ~= nil then ent:SetBaseMoveSpeed(0) end
            if ent.SetIdleAcquire ~= nil then ent:SetIdleAcquire(false) end
            if ent.SetAcquisitionRange ~= nil then ent:SetAcquisitionRange(0) end
            if ent.SetForceAttackTarget ~= nil then ent:SetForceAttackTarget(nil) end
            if ent.SetAggroTarget ~= nil then ent:SetAggroTarget(nil) end
            if ent.SetHealthBarOffset ~= nil then ent:SetHealthBarOffset(-1000) end
            if DOTA_UNIT_CAP_NO_ATTACK ~= nil and ent.SetAttackCapability ~= nil then ent:SetAttackCapability(DOTA_UNIT_CAP_NO_ATTACK) end
        end)
    end

    local fx = nil
    if ent ~= nil and def.particle and ParticleManager ~= nil then
        pcall(function()
            fx = ParticleManager:CreateParticle(def.particle, PATTACH_ABSORIGIN_FOLLOW, ent)
            ParticleManager:SetParticleControlEnt(fx, 0, ent, PATTACH_ABSORIGIN_FOLLOW, "", pos, true)
            ParticleManager:SetParticleControlEnt(fx, 1, ent, PATTACH_ABSORIGIN_FOLLOW, "", pos, true)
        end)
    end
    return ent, fx
end

function DotaKartItemSystem:DestroyHomingMissile(data, reason, playDestroySound)
    if data == nil or data.destroyed == true then return end
    data.destroyed = true
    if self.activeHomingMissiles then self.activeHomingMissiles[data.serial] = nil end
    local pos = data.pos
    if data.fx ~= nil and ParticleManager ~= nil then
        pcall(function() ParticleManager:DestroyParticle(data.fx, false); ParticleManager:ReleaseParticleIndex(data.fx) end)
    end
    if data.ent ~= nil and (data.ent.IsNull == nil or not data.ent:IsNull()) then
        if pos == nil and data.ent.GetAbsOrigin ~= nil then pos = data.ent:GetAbsOrigin() end
        pcall(function() UTIL_Remove(data.ent) end)
    end
    if playDestroySound ~= false and pos ~= nil then
        self:EmitKartWorldSound(data.caster, data.def and data.def.sound_destroy, pos)
    end
end

function DotaKartItemSystem:GetHomingLockedUnit(data)
    if data == nil then return nil end
    local targetID = tonumber(data.target_player_id) or -1
    if targetID <= -1000 then
        local decoy = self:GetDoppelDecoyByTargetID(targetID)
        return decoy and decoy.unit or nil
    end
    if targetID < 0 then return nil end

    -- Doppelwalk can fool an already-flying Homing Missile.
    if self:IsPlayerInvisible(targetID) then
        local decoy = self:GetDoppelDecoyForOwner(targetID)
        if decoy ~= nil and DKValidUnit(decoy.unit) then
            data.target_player_id = decoy.target_id
            return decoy.unit
        end
    end

    -- Shukuchi / Ball Lightning / Astral disjoint or invalidate the lock.
    if (self.activeShukuchi and self.activeShukuchi[targetID]) or self:IsKartUntargetable(targetID) then
        return nil
    end
    return self:GetHeroForPlayer(targetID)
end

function DotaKartItemSystem:UseHomingMissile(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end
    local st = self:GetState(playerID)
    local backward = st ~= nil and st.input ~= nil and st.input.reverse == true and st.input.forward ~= true
    local targetID = backward and self:GetPlayerIDOnePlaceBehind(playerID) or self:GetPlayerIDOnePlaceAhead(playerID)
    if targetID == nil or targetID < 0 then
        self:SendItemHint(playerID, backward and "NO RACER ONE PLACE BEHIND" or "NO RACER ONE PLACE AHEAD", 1.5)
        return true
    end
    if self:IsPlayerStarActive(targetID) or self:IsKartUntargetable(targetID) then return true end
    local target = self:GetHeroForPlayer(targetID)
    if self:IsPlayerInvisible(targetID) then
        local decoy = self:GetDoppelDecoyForOwner(targetID)
        if decoy ~= nil and DKValidUnit(decoy.unit) then target = decoy.unit; targetID = decoy.target_id else return true end
    end
    if not DKValidUnit(target) then return true end

    local fwd = self:NormalizeDir2D(caster:GetForwardVector(), Vector(1,0,0))
    if backward then fwd = fwd * -1 end
    local raw = caster:GetAbsOrigin() + fwd * 145
    local flightHeight = tonumber(def.flight_height) or 50
    raw.z = GetGroundHeight(raw, caster) + flightHeight
    local pos = Vector(raw.x, raw.y, raw.z)
    local yaw = math.deg(DKAtan2(fwd.y, fwd.x))
    local ent, fx = self:SpawnHomingMissileVisual(def, pos, yaw, caster)
    -- FIX128: gameplay must not fail just because a renderer could not be created.
    local serial = self:NextProjectileSerial()
    local spawnTime = DKNow()
    local data = {
        serial = serial, caster_player_id = playerID, caster = caster, target_player_id = targetID,
        def = def, ent = ent, fx = fx, pos = pos, last_pos = Vector(pos.x,pos.y,pos.z),
        traveled = 0, start_time = spawnTime,
        move_start_time = spawnTime + (tonumber(def.launch_delay) or 2.5),
        backward = backward, route = {}, destroyed = false
    }
    self.activeHomingMissiles[serial] = data
    self:ConsumeHeldItem(playerID, itemName, def)
    self:EmitKartWorldSound(caster, def.sound_launch, pos)
    self:EmitKartSound(target, def.sound_target, target:GetAbsOrigin())
    self:EmitKartSound(target, def.sound_enemy, target:GetAbsOrigin())

    GameRules:GetGameModeEntity():SetContextThink("DotaKartHomingMissile_" .. tostring(serial), function()
        if data.destroyed == true then return nil end
        if data.ent == nil or (data.ent.IsNull ~= nil and data.ent:IsNull()) then
            -- FIX128: the native Gyrocopter missile unit may be removed by engine-side
            -- unit logic (especially for fake-client/public-AI owners). Losing the
            -- renderer must never cancel the gameplay projectile. Recreate the visual
            -- when possible and continue the logical missile regardless.
            if data.fx ~= nil and ParticleManager ~= nil then
                pcall(function() ParticleManager:DestroyParticle(data.fx,false); ParticleManager:ReleaseParticleIndex(data.fx) end)
                data.fx=nil
            end
            local respawnYaw=0
            if data.last_dir~=nil then respawnYaw=math.deg(DKAtan2(data.last_dir.y,data.last_dir.x)) end
            local newEnt,newFx=self:SpawnHomingMissileVisual(def,data.pos,respawnYaw,caster)
            data.ent=newEnt
            data.fx=newFx
        end

        local targetUnit = self:GetHomingLockedUnit(data)
        if not DKValidUnit(targetUnit) then self:DestroyHomingMissile(data,"disjoint_or_invalid",true); return nil end
        local now = DKNow()

        -- FIX128: Homing Missile remains visible and stationary for 2.5 seconds,
        -- matching Gyrocopter's arming behavior. This also gives bot-fired missiles
        -- a clear warning before they begin pursuing the target.
        if now < (tonumber(data.move_start_time) or now) then
            pcall(function()
                if data.ent.SetOriginalModel ~= nil and def.model ~= nil then data.ent:SetOriginalModel(def.model) end
                if data.ent.SetModel ~= nil and def.model ~= nil then data.ent:SetModel(def.model) end
                if data.ent.SetAbsOrigin ~= nil then data.ent:SetAbsOrigin(data.pos) end
                if data.ent.RemoveNoDraw ~= nil then data.ent:RemoveNoDraw() end
                if data.ent.SetRenderAlpha ~= nil then data.ent:SetRenderAlpha(255) end
                if data.ent.SetModelScale ~= nil then data.ent:SetModelScale(tonumber(def.model_scale) or 1.0) end
            end)
            return 0.03
        end

        if now - (tonumber(data.move_start_time) or data.start_time) >= (tonumber(def.timeout) or 18.0) then self:DestroyHomingMissile(data,"timeout",true); return nil end

        local targetPos = targetUnit:GetAbsOrigin()
        local toTarget = targetPos - data.pos; toTarget.z = 0
        local distToTarget = DKLength2D(data.pos, targetPos)
        local dir = nil
        if distToTarget <= (tonumber(def.direct_radius) or 900) then
            dir = self:NormalizeDir2D(toTarget, fwd)
        else
            dir = self:GetSpectralRouteDirection(data.pos, targetPos, data.route, data.backward)
            if dir == nil then dir = self:NormalizeDir2D(toTarget, fwd) end
        end

        local elapsed = math.max(0, now - (tonumber(data.move_start_time) or data.start_time))
        local speed = math.min(tonumber(def.max_speed) or 2450, (tonumber(def.base_speed) or 850) + (tonumber(def.acceleration) or 260) * elapsed)
        local dt = 0.03
        local step = math.min(speed * dt, math.max(1, distToTarget))
        local nextPos = data.pos + dir * step
        -- FIX124: Homing Missile is a flying projectile, not a ground prop.
        nextPos.z = GetGroundHeight(nextPos, targetUnit) + (tonumber(def.flight_height) or 50)
        data.traveled = (tonumber(data.traveled) or 0) + DKLength2D(data.pos, nextPos)
        data.last_pos = data.pos
        data.pos = nextPos
        local nextYaw = math.deg(DKAtan2(dir.y, dir.x))
        data.last_dir=dir
        pcall(function()
            if data.ent.SetOriginalModel ~= nil and def.model ~= nil then data.ent:SetOriginalModel(def.model) end
            if data.ent.SetModel ~= nil and def.model ~= nil then data.ent:SetModel(def.model) end
            data.ent:SetAbsOrigin(nextPos)
            data.ent:SetAngles(0,nextYaw,0)
            if data.ent.RemoveNoDraw ~= nil then data.ent:RemoveNoDraw() end
            if data.ent.SetRenderAlpha ~= nil then data.ent:SetRenderAlpha(255) end
            if data.ent.SetModelScale ~= nil then data.ent:SetModelScale(tonumber(def.model_scale) or 1.0) end
        end)

        local hitRadius = tonumber(def.hit_radius) or 185
        if self:BlockProjectileWithPowerCog(playerID, nextPos, hitRadius * 0.90, "homing_missile_blocked") then
            self:DestroyHomingMissile(data,"power_cog",true)
            return nil
        end
        if self:HandleSpecialProjectileTargetHit(playerID, nextPos, hitRadius, "homing_missile") then
            self:DestroyHomingMissile(data,"special_target",true)
            return nil
        end

        local currentTarget = self:GetHomingLockedUnit(data)
        if DKValidUnit(currentTarget) and DKLength2D(nextPos, currentTarget:GetAbsOrigin()) <= hitRadius then
            local tid = tonumber(data.target_player_id) or -1
            if tid <= -1000 then
                local decoy = self:GetDoppelDecoyByTargetID(tid)
                if decoy then self:DestroyDoppelDecoy(decoy,"homing_missile") end
            elseif tid >= 0 and not self:IsPlayerStarActive(tid) and not self:IsKartUntargetable(tid) then
                local stun = self:GetHomingMissileStun(data.traveled, def)
                self:ApplyKartStun(caster, currentTarget, stun)
                self:NotifyBattleHungerItemHit(playerID, tid)
            end
            self:DestroyHomingMissile(data,"impact",true)
            return nil
        end
        return dt
    end, 0.03)

    print("[DotaKartItems] Player " .. tostring(playerID) .. " launched HOMING MISSILE target=" .. tostring(targetID) .. " " .. (backward and "backward" or "forward"))
    return true
end


-- ============================================================
-- FIX126: Plague Ward / The Swarm / Storm Hammer / Illusory Orb
-- ============================================================
function DotaKartItemSystem:SpawnSimpleProp(model, pos, scale)
    if model == nil or model == "" or pos == nil or SpawnEntityFromTableSynchronous == nil then return nil end
    local ent = nil
    pcall(function()
        ent = SpawnEntityFromTableSynchronous("prop_dynamic", {
            model = model,
            solid = "0",
            DefaultAnim = "idle"
        })
    end)
    if DKValidUnit(ent) then
        ent:SetAbsOrigin(pos)
        if scale ~= nil and ent.SetModelScale ~= nil then pcall(function() ent:SetModelScale(tonumber(scale) or 1.0) end) end
    end
    return ent
end

function DotaKartItemSystem:DestroyPlagueWard(playerID, reason)
    self.activePlagueWards = self.activePlagueWards or {}
    local data = self.activePlagueWards[playerID]
    if data == nil then return end
    self.activePlagueWards[playerID] = nil
    if DKValidUnit(data.unit) then pcall(function() UTIL_Remove(data.unit) end) end
    if self.config and self.config.debug then print("[DotaKartItems] Plague Ward removed owner=" .. tostring(playerID) .. " reason=" .. tostring(reason)) end
end

function DotaKartItemSystem:FindPlagueWardHit(ownerPlayerID, pos, radius)
    if pos == nil then return nil, nil end
    radius = tonumber(radius) or 120
    for wardOwner, data in pairs(self.activePlagueWards or {}) do
        if tonumber(wardOwner) ~= tonumber(ownerPlayerID) and data ~= nil and DKValidUnit(data.unit) and DKNow() < (data.end_time or 0) then
            local wardPos = data.pos or data.unit:GetAbsOrigin()
            local hitRadius = radius + (tonumber(data.def and data.def.block_radius) or 120)
            if DKLength2D(pos, wardPos) <= hitRadius then return wardOwner, data end
        end
    end
    return nil, nil
end

function DotaKartItemSystem:BlockProjectileWithPlagueWard(ownerPlayerID, pos, radius, sourceKind)
    if sourceKind == "power_cogs_orbit" then return false end
    local wardOwner, data = self:FindPlagueWardHit(ownerPlayerID, pos, radius)
    if data == nil then return false end
    local def = data.def or self.itemDefs.item_dotakart_plague_ward or {}
    local wardPos = data.pos or (DKValidUnit(data.unit) and data.unit:GetAbsOrigin()) or pos
    self:CreateWorldParticle(def.particle_explosion, wardPos, 0.65)
    self:CreateWorldParticle(def.particle_explosion_flash, wardPos, 0.40)
    self:EmitKartWorldSound(self:GetHeroForPlayer(wardOwner), def.sound_impact, wardPos)
    return true
end

function DotaKartItemSystem:FirePlagueWardProjectile(ownerPlayerID, data, target, targetPlayerID)
    if data == nil or not DKValidUnit(data.unit) or not DKValidUnit(target) then return end
    local def = data.def or self.itemDefs.item_dotakart_plague_ward or {}
    local start = data.pos or data.unit:GetAbsOrigin()
    start = Vector(start.x, start.y, start.z + 65)
    local targetPos = target:GetAbsOrigin() + Vector(0,0,70)
    local dir = self:NormalizeDir2D(targetPos - start)
    local speed = tonumber(def.projectile_speed) or 1250
    local hitRadius = tonumber(def.projectile_hit_radius) or 115

    -- FIX127: keep the Ward facing the kart it just attacked rather than immediately
    -- overwriting its yaw with the orbital tangent on the next update.
    data.face_target = target
    data.face_target_player_id = targetPlayerID
    data.face_target_until = DKNow() + math.max(0.55, math.min(1.25, DKLength2D(start, targetPos) / math.max(1, speed)))

    -- The stock Venomancer Ward projectile is authored as an engine ProjectileModel.
    -- Prefer a real tracking projectile for the visual so it follows a moving racer.
    -- Collision/slow still remain server-authoritative in the custom thinker below.
    local trackingID = nil
    if ProjectileManager ~= nil and ProjectileManager.CreateTrackingProjectile ~= nil then
        local source = self:GetHeroForPlayer(ownerPlayerID)
        if DKValidUnit(source) then
            pcall(function()
                trackingID = ProjectileManager:CreateTrackingProjectile({
                    Target = target,
                    Source = source,
                    EffectName = def.particle_projectile,
                    iMoveSpeed = speed,
                    vSourceLoc = start,
                    bDodgeable = false,
                    bProvidesVision = false,
                    bVisibleToEnemies = true,
                    bReplaceExisting = false,
                    bIsAttack = false
                })
            end)
        end
    end

    -- Fallback for builds that reject a visual-only tracking projectile.
    local fx = nil
    local trail = self:CreateDirectionalParticle(def.particle_trail, start, dir, speed)
    if trackingID == nil then
        fx = self:CreateDirectionalParticle(def.particle_projectile, start, dir, speed)
    end
    self:CreateWorldParticle(def.particle_launch, start, 0.45)
    self:EmitKartWorldSound(self:GetHeroForPlayer(ownerPlayerID), def.sound_shoot, start)
    local serial = self:NextProjectileSerial()
    local pos = Vector(start.x,start.y,start.z)
    local startTime = DKNow()

    local function cleanup()
        if trackingID ~= nil and ProjectileManager ~= nil and ProjectileManager.DestroyTrackingProjectile ~= nil then
            pcall(function() ProjectileManager:DestroyTrackingProjectile(trackingID) end)
            trackingID = nil
        end
        if fx then self:DestroyLinearParticle(fx, false); fx = nil end
        if trail then self:DestroyLinearParticle(trail, false); trail = nil end
    end

    GameRules:GetGameModeEntity():SetContextThink("DotaKartPlagueWardShot_" .. tostring(serial), function()
        if not DKValidUnit(data.unit) then cleanup(); return nil end
        local liveTarget = self:GetHomingTargetUnit(targetPlayerID)
        if not DKValidUnit(liveTarget) then liveTarget = target end
        if not DKValidUnit(liveTarget) then cleanup(); return nil end
        if tonumber(targetPlayerID) >= 0 and (self:IsKartUntargetable(targetPlayerID) or self:IsPlayerStarActive(targetPlayerID) or self:IsPlayerInvisible(targetPlayerID)) then
            cleanup(); return nil
        end

        local tp = liveTarget:GetAbsOrigin() + Vector(0,0,70)
        dir = self:NormalizeDir2D(tp - pos)
        local enginePos = nil
        if trackingID ~= nil and ProjectileManager ~= nil and ProjectileManager.GetTrackingProjectileLocation ~= nil then
            pcall(function() enginePos = ProjectileManager:GetTrackingProjectileLocation(trackingID) end)
        end
        if enginePos ~= nil then
            pos = Vector(enginePos.x, enginePos.y, enginePos.z)
            dir = self:NormalizeDir2D(tp - pos)
        else
            pos = pos + dir * speed * 0.03
            pos.z = GetGroundHeight(pos,nil) + 90
        end
        if fx then self:UpdateDirectionalParticle(fx,pos,dir,speed) end
        if trail then self:UpdateDirectionalParticle(trail,pos,dir,speed) end

        if self:BlockProjectileWithPowerCog(ownerPlayerID,pos,hitRadius,"plague_ward_shot") then
            self:CreateWorldParticle(def.particle_explosion, pos, 0.55)
            cleanup()
            return nil
        end
        if self:HandleSpecialProjectileTargetHit(ownerPlayerID,pos,hitRadius,"plague_ward") then
            self:CreateWorldParticle(def.particle_explosion, pos, 0.55)
            cleanup()
            return nil
        end
        if DKLength2D(pos,tp) <= hitRadius then
            self:CreateWorldParticle(def.particle_explosion, tp, 0.65)
            self:CreateWorldParticle(def.particle_explosion_flash, tp, 0.40)
            self:EmitKartWorldSound(self:GetHeroForPlayer(ownerPlayerID), def.sound_impact, tp)
            if tonumber(targetPlayerID) >= 0 then
                local ownerHero = self:GetHeroForPlayer(ownerPlayerID)
                -- FIX129: repeated Ward attacks only refresh the same 15% slow; they never stack.
                self:ApplyPlagueWardSlow(ownerHero, liveTarget, tonumber(def.slow_duration) or 2.0, tonumber(def.slow_pct) or 0.15)
            end
            cleanup()
            return nil
        end
        if DKNow() - startTime > 2.5 then cleanup(); return nil end
        return 0.03
    end, 0.03)
end

function DotaKartItemSystem:UsePlagueWard(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end
    self:DestroyPlagueWard(playerID, "replace")
    local base = caster:GetAbsOrigin()
    local pos = base + Vector(tonumber(def.orbit_radius) or 190,0,80)
    local unit = self:SpawnSimpleProp(def.model,pos,1.0)
    if not DKValidUnit(unit) then return false end
    local now = DKNow()
    self.activePlagueWards[playerID] = {
        owner_player_id = playerID, unit = unit, def = def, pos = pos,
        angle = 0, end_time = now + (tonumber(def.duration) or 45.0), next_attack = now + 0.35
    }
    self:EmitKartSound(caster, def.sound_cast, base)
    self:ConsumeHeldItem(playerID,itemName,def)
    return true
end

function DotaKartItemSystem:UpdatePlagueWards(now)
    for playerID,data in pairs(self.activePlagueWards or {}) do
        local caster = self:GetHeroForPlayer(playerID)
        local def = data.def or self.itemDefs.item_dotakart_plague_ward or {}
        if not DKValidUnit(caster) or not DKValidUnit(data.unit) or now >= (data.end_time or 0) then
            self:DestroyPlagueWard(playerID,"expired")
        else
            data.angle = (tonumber(data.angle) or 0) + (tonumber(def.orbit_speed) or 115) * (self.config.tick_rate or 0.06)
            local rad = math.rad(data.angle)
            local base = caster:GetAbsOrigin()
            local p = base + Vector(math.cos(rad),math.sin(rad),0) * (tonumber(def.orbit_radius) or 190)
            p.z = GetGroundHeight(p,caster) + 70
            data.pos = p
            data.unit:SetAbsOrigin(p)
            local faceTarget = data.face_target
            if DKValidUnit(faceTarget) and now < (tonumber(data.face_target_until) or 0) then
                local faceDir = self:NormalizeDir2D(faceTarget:GetAbsOrigin() - p)
                local faceYaw = DKNormalizeYaw(math.deg(DKAtan2(faceDir.y, faceDir.x)))
                if data.unit.SetForwardVector ~= nil then pcall(function() data.unit:SetForwardVector(faceDir) end) end
                if data.unit.FaceTowards ~= nil then pcall(function() data.unit:FaceTowards(faceTarget:GetAbsOrigin()) end) end
                if data.unit.SetAngles ~= nil then pcall(function() data.unit:SetAngles(0,faceYaw,0) end) end
            elseif data.unit.SetAngles ~= nil then
                pcall(function() data.unit:SetAngles(0,data.angle+90,0) end)
            end
            if now >= (data.next_attack or 0) then
                data.next_attack = now + (tonumber(def.attack_interval) or 1.0)
                local target,targetID = self:FindNearestEnemyKart(playerID,p,tonumber(def.attack_range) or 1500)
                if DKValidUnit(target) then self:FirePlagueWardProjectile(playerID,data,target,targetID) end
            end
        end
    end
end

function DotaKartItemSystem:IsSwarmTargetLatched(targetPlayerID)
    targetPlayerID = tonumber(targetPlayerID) or -1
    for _,data in pairs(self.activeSwarmBeetles or {}) do
        if data ~= nil and data.destroyed ~= true and tonumber(data.target_player_id) == targetPlayerID and DKNow() < (data.end_time or 0) then return true end
    end
    return false
end

function DotaKartItemSystem:DestroySwarmBeetle(data, reason)
    if data == nil or data.destroyed == true then return end
    data.destroyed = true
    if self.activeSwarmBeetles ~= nil and data.id ~= nil then self.activeSwarmBeetles[data.id] = nil end
    -- FIX129: the Swarm slow belongs to the live latched Beetle and ends with it.
    self:ClearSwarmTickSlow(data.target_player_id)
    if DKValidUnit(data.unit) then pcall(function() UTIL_Remove(data.unit) end) end
    if self.config and self.config.debug then print("[DotaKartItems] Swarm Beetle removed id=" .. tostring(data.id) .. " reason=" .. tostring(reason)) end
end

function DotaKartItemSystem:FindLatchedSwarmBeetleHit(ownerPlayerID,pos,radius)
    if pos == nil then return nil end
    radius = tonumber(radius) or 110
    for _,data in pairs(self.activeSwarmBeetles or {}) do
        if data ~= nil and data.destroyed ~= true and tonumber(data.owner_player_id) ~= tonumber(ownerPlayerID) and DKValidUnit(data.unit) then
            local p = data.unit:GetAbsOrigin()
            if DKLength2D(pos,p) <= radius + 70 then return data end
        end
    end
    return nil
end

function DotaKartItemSystem:LatchSwarmBeetle(ownerPlayerID,targetPlayerID,target,def,pos)
    if self:IsSwarmTargetLatched(targetPlayerID) then return false end
    local id = tonumber(self.nextSwarmBeetleID) or 1
    self.nextSwarmBeetleID = id + 1
    local p = target:GetAbsOrigin() + Vector(0,0,115)
    local unit = self:SpawnSimpleProp(def.beetle_model,p,0.9)
    local now = DKNow()
    local data = {
        id=id, owner_player_id=ownerPlayerID, target_player_id=targetPlayerID,
        target=target, unit=unit, def=def, end_time=now+(tonumber(def.beetle_duration) or 16.0),
        next_tick=now+(tonumber(def.tick_interval) or 1.0), ticks=0, destroyed=false
    }
    self.activeSwarmBeetles[id]=data
    self:EmitKartWorldSound(self:GetHeroForPlayer(ownerPlayerID),def.sound_attach,p)
    return true
end

function DotaKartItemSystem:UpdateSwarmBeetles(now)
    local destroy={}
    for _,data in pairs(self.activeSwarmBeetles or {}) do
        local target=data.target
        if data.destroyed==true or not DKValidUnit(target) or now >= (data.end_time or 0) then
            table.insert(destroy,data)
        else
            local p=target:GetAbsOrigin()+Vector(0,0,115)
            if DKValidUnit(data.unit) then data.unit:SetAbsOrigin(p) end
            if now >= (data.next_tick or 0) then
                local tick=tonumber(data.def and data.def.tick_interval) or 1.0
                data.next_tick=now+tick
                data.ticks=(tonumber(data.ticks) or 0)+1
                -- FIX129: latch itself applies 0%. The first real slow is exactly 3% at t=1s,
                -- then 6%, 9%, ...; each tick REPLACES the prior Swarm value instead of
                -- feeding the shared slow accumulator.
                local slow=math.min(0.90,data.ticks*(tonumber(data.def and data.def.slow_per_tick) or 0.03))
                local remaining=math.max(0.10,(tonumber(data.end_time) or now)-now+0.05)
                self:ApplySwarmTickSlow(self:GetHeroForPlayer(data.owner_player_id),target,remaining,slow)
            end
        end
    end
    for _,data in ipairs(destroy) do self:DestroySwarmBeetle(data,"expired") end
end

function DotaKartItemSystem:UseTheSwarm(playerID,itemName,def)
    local caster=self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end
    local dir,_,backward=self:GetFireDirectionForPlayer(playerID,caster)
    dir=self:NormalizeDir2D(dir)
    local origin=caster:GetAbsOrigin()
    local count=tonumber(def.count) or 12
    local speed=tonumber(def.speed) or 2000
    local maxDistance=tonumber(def.max_distance) or 4000
    local spawnRadius=tonumber(def.spawn_radius) or 300
    local latchRadius=tonumber(def.latch_radius) or 100
    self:EmitKartSound(caster,def.sound_cast,origin)
    self:EmitKartSound(caster,def.sound_projectile,origin)
    self:ConsumeHeldItem(playerID,itemName,def)
    for i=1,count do
        local a=DKRandomFloat(0,math.pi*2)
        local r=math.sqrt(DKRandomFloat(0,1))*spawnRadius
        local start=origin+Vector(math.cos(a)*r,math.sin(a)*r,90)
        start.z=GetGroundHeight(start,caster)+90
        local pos=Vector(start.x,start.y,start.z)
        local fx=self:CreateDirectionalParticle(def.particle,start,dir,speed)
        local serial=self:NextProjectileSerial()
        local traveled=0
        GameRules:GetGameModeEntity():SetContextThink("DotaKartSwarmBug_"..tostring(serial),function()
            local step=speed*0.03
            traveled=traveled+step
            pos=pos+dir*step
            pos.z=GetGroundHeight(pos,nil)+90
            self:UpdateDirectionalParticle(fx,pos,dir,speed)
            for _,otherID in ipairs(self:GetRegisteredPlayerIDs()) do
                if tonumber(otherID)~=tonumber(playerID) and not self:IsSwarmTargetLatched(otherID) then
                    local other=self:GetHeroForPlayer(otherID)
                    if DKValidUnit(other) and not self:IsPlayerStarActive(otherID) and not self:IsKartUntargetable(otherID) and DKLength2D(pos,other:GetAbsOrigin())<=latchRadius then
                        if self:LatchSwarmBeetle(playerID,otherID,other,def,pos) then
                            if fx then self:DestroyLinearParticle(fx,false) end
                            return nil
                        end
                    end
                end
            end
            -- Doppelwalk decoys behave like one-hit hero proxies for item interactions.
            for key,decoy in pairs(self.activeDoppelwalkDecoys or {}) do
                if type(key)=="number" and decoy~=nil and tonumber(decoy.owner_player_id)~=tonumber(playerID) and DKValidUnit(decoy.unit) then
                    if DKLength2D(pos,decoy.unit:GetAbsOrigin())<=latchRadius then
                        self:DestroyDoppelDecoy(decoy,"the_swarm")
                        if fx then self:DestroyLinearParticle(fx,false) end
                        return nil
                    end
                end
            end
            if traveled>=maxDistance then if fx then self:DestroyLinearParticle(fx,false) end; return nil end
            return 0.03
        end,0.03)
    end
    print("[DotaKartItems] Player "..tostring(playerID).." used THE SWARM "..(backward and "backward" or "forward"))
    return true
end

function DotaKartItemSystem:StormHammerImpact(playerID,caster,pos,def)
    self:CreateWorldParticle(def.particle,pos,0.65)
    self:EmitKartWorldSound(caster,def.sound_impact,pos)
    local radius=tonumber(def.effect_radius) or 300
    for _,otherID in ipairs(self:GetRegisteredPlayerIDs()) do
        if tonumber(otherID)~=tonumber(playerID) then
            local other=self:GetHeroForPlayer(otherID)
            if DKValidUnit(other) and not self:IsKartUntargetable(otherID) and DKLength2D(pos,other:GetAbsOrigin())<=radius then
                self:ApplyKartStun(caster,other,tonumber(def.stun_duration) or 2.5)
            end
        end
    end
    self:DestroyDoppelDecoysInRadius(playerID,pos,radius,"storm_hammer")
end

function DotaKartItemSystem:FindStormHammerItemBoxTarget(pos,dir,range,minDot)
    if pos==nil then return nil,nil,999999 end
    dir=self:NormalizeDir2D(dir or Vector(1,0,0))
    range=tonumber(range) or 1700
    minDot=tonumber(minDot) or 0.15
    local bestBox=nil
    local bestPos=nil
    local bestDist=999999
    for _,box in ipairs(self.boxes or {}) do
        if box~=nil and box.active==true and box.being_pulled~=true then
            local bp=nil
            if DKValidUnit(box.ent) then
                bp=box.ent:GetAbsOrigin()
            elseif box.pos~=nil then
                bp=box.pos
            end
            if bp~=nil then
                local dist=DKLength2D(pos,bp)
                if dist<=range and dist<bestDist then
                    local toDir=self:NormalizeDir2D(bp-pos)
                    local dot=(toDir.x*dir.x)+(toDir.y*dir.y)
                    if dot>=minDot then
                        bestBox=box
                        bestPos=Vector(bp.x,bp.y,bp.z)
                        bestDist=dist
                    end
                end
            end
        end
    end
    return bestBox,bestPos,bestDist
end

function DotaKartItemSystem:UseStormHammer(playerID,itemName,def)
    local caster=self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end

    local st=self:GetState(playerID)
    local dir,_,backward=self:GetFireDirectionForPlayer(playerID,caster)
    dir=self:NormalizeDir2D(dir)

    local start=caster:GetAbsOrigin()+dir*115+Vector(0,0,105)
    local range=tonumber(def.cast_range) or 1700
    local speed=tonumber(def.speed) or 1750
    local hitRadius=tonumber(def.hit_radius) or 150
    local target,targetID,targetDist=self:FindNearestEnemyKartInArc(playerID,start,dir,range,0.15)

    -- FIX131: active Item Boxes (including Hammer boxes named dk_itembox_001) are
    -- valid forward Storm Hammer targets. Racer targets keep priority. Backward casts
    -- remain attack-only and never use boxes for kart displacement.
    local targetBox=nil
    local targetBoxPos=nil
    local targetBoxDist=999999
    if backward~=true and not DKValidUnit(target) then
        targetBox,targetBoxPos,targetBoxDist=self:FindStormHammerItemBoxTarget(start,dir,range,0.15)
    end

    local hasTarget=DKValidUnit(target) or targetBox~=nil
    local initialTargetDistance=tonumber(targetDist) or 999999
    if targetBox~=nil then initialTargetDistance=targetBoxDist end

    -- Visual only. Gameplay movement below is authoritative.
    local visualTrackingID=nil
    local visualLinearID=nil
    if ProjectileManager~=nil and DKValidUnit(target) and ProjectileManager.CreateTrackingProjectile~=nil then
        pcall(function()
            visualTrackingID=ProjectileManager:CreateTrackingProjectile({
                Target=target,
                Source=caster,
                EffectName=def.particle,
                iMoveSpeed=speed,
                vSourceLoc=start,
                bDodgeable=false,
                bProvidesVision=false,
                bVisibleToEnemies=true,
                bReplaceExisting=false,
                bIsAttack=false
            })
        end)
    elseif ProjectileManager~=nil and ProjectileManager.CreateLinearProjectile~=nil then
        local visualDistance=range
        if targetBox~=nil and initialTargetDistance<999999 then
            visualDistance=math.min(range,math.max(1,initialTargetDistance))
        end
        pcall(function()
            visualLinearID=ProjectileManager:CreateLinearProjectile({
                Source=caster,
                EffectName=def.particle,
                vSpawnOrigin=start,
                vVelocity=dir*speed,
                fDistance=visualDistance,
                fStartRadius=1,
                fEndRadius=1,
                iUnitTargetTeam=0,
                iUnitTargetType=0,
                iUnitTargetFlags=0,
                bDeleteOnHit=false,
                bProvidesVision=false,
                bHasFrontalCone=false
            })
        end)
    end
    local fx=nil
    if visualTrackingID==nil and visualLinearID==nil then
        fx=self:CreateDirectionalParticle(def.particle,start,dir,speed)
    end

    self:EmitKartSound(caster,def.sound_cast,start)
    self:ConsumeHeldItem(playerID,itemName,def)

    -- Forward Storm Hammer transports the kart only when a target existed at cast time.
    -- With no valid target it still flies the full 1700 range but leaves the caster alone.
    local travelWithCaster=(backward~=true and hasTarget==true)
    local preSpeed=st and (tonumber(st.speed) or 0) or 0
    local pos=Vector(start.x,start.y,start.z)
    local traveled=0
    local serial=self:NextProjectileSerial()
    local finished=false
    local lastThink=DKNow()
    local lastKartPos=caster:GetAbsOrigin()

    local function renewTransportLock(now)
        if not travelWithCaster or st==nil then return end
        local ownUntil=now+0.14
        local previousOwn=tonumber(st.storm_hammer_lock_until) or 0
        st.storm_hammer_transport_active=true
        st.storm_hammer_transport_until=now+0.18
        if (tonumber(st.locked_until) or 0)<=previousOwn+0.02 or (tonumber(st.locked_until) or 0)<=now then
            st.locked_until=ownUntil
        end
        st.storm_hammer_lock_until=ownUntil
        st.speed=0
    end

    local function cleanupTransport()
        if not travelWithCaster or st==nil then return end
        local now=DKNow()
        local ownUntil=tonumber(st.storm_hammer_lock_until) or 0
        st.storm_hammer_transport_active=false
        st.storm_hammer_transport_until=0
        if (tonumber(st.locked_until) or 0)<=ownUntil+0.02 then st.locked_until=now end
        if not ((st.stunned_until or 0)>now or (st.rooted_until or 0)>now or (st.locked_until or 0)>now+0.01) then
            st.speed=preSpeed
        end
        st.storm_hammer_lock_until=nil
    end

    local function destroyVisual()
        if visualTrackingID~=nil and ProjectileManager~=nil and ProjectileManager.DestroyTrackingProjectile~=nil then
            pcall(function() ProjectileManager:DestroyTrackingProjectile(visualTrackingID) end)
            visualTrackingID=nil
        end
        if visualLinearID~=nil and ProjectileManager~=nil and ProjectileManager.DestroyLinearProjectile~=nil then
            pcall(function() ProjectileManager:DestroyLinearProjectile(visualLinearID) end)
            visualLinearID=nil
        end
        if fx~=nil then self:DestroyLinearParticle(fx,false); fx=nil end
    end

    local function currentBoxPos()
        if targetBox==nil then return nil end
        if DKValidUnit(targetBox.ent) then
            local bp=targetBox.ent:GetAbsOrigin()
            return Vector(bp.x,bp.y,bp.z)
        end
        if targetBox.pos~=nil then
            return Vector(targetBox.pos.x,targetBox.pos.y,targetBox.pos.z)
        end
        return targetBoxPos
    end

    local function finish(atPos,explode,impactTarget,impactBox)
        if finished then return end
        finished=true
        destroyVisual()

        local impactPos=atPos or pos
        if DKValidUnit(impactTarget) then
            impactPos=impactTarget:GetAbsOrigin()
        elseif impactBox~=nil then
            impactPos=currentBoxPos() or impactPos
        end

        if explode then
            if DKValidUnit(impactTarget) then
                self:ApplyKartStun(caster,impactTarget,tonumber(def.stun_duration) or 2.5)
            end
            self:StormHammerImpact(playerID,caster,impactPos,def)
        end

        if travelWithCaster and DKValidUnit(caster) then
            local finalKart=nil
            if DKValidUnit(impactTarget) then
                local tp=impactTarget:GetAbsOrigin()
                finalKart=Vector(tp.x,tp.y,GetGroundHeight(tp,caster))
            elseif impactBox~=nil then
                local bp=currentBoxPos() or impactPos
                finalKart=Vector(bp.x,bp.y,GetGroundHeight(bp,caster))
            else
                local lp=lastKartPos or caster:GetAbsOrigin()
                finalKart=Vector(lp.x,lp.y,GetGroundHeight(lp,caster))
            end
            caster:SetAbsOrigin(finalKart)
            lastKartPos=finalKart
        end

        cleanupTransport()

        -- Consuming Storm Hammer emptied the item slot, so arriving at an active box
        -- immediately performs the normal box pickup/roulette flow.
        if impactBox~=nil and impactBox.active==true and DKValidUnit(caster) then
            self:OnPickupBox(playerID,caster,impactBox)
        end
    end

    renewTransportLock(lastThink)

    GameRules:GetGameModeEntity():SetContextThink('DotaKartStormHammer_'..tostring(serial),function()
        if finished then return nil end
        if not DKValidUnit(caster) then finish(pos,false,nil,nil); return nil end

        local now=DKNow()
        local dt=math.max(0.01,math.min(0.05,now-lastThink))
        lastThink=now
        renewTransportLock(now)

        local live=nil
        if DKValidUnit(target) then
            live=self:GetHomingTargetUnit(targetID)
            if DKValidUnit(live) and self:IsKartUntargetable(targetID) then live=nil end
        end

        local previousPos=Vector(pos.x,pos.y,pos.z)
        local targetPos=nil
        if DKValidUnit(live) then
            targetPos=live:GetAbsOrigin()+Vector(0,0,90)
            dir=self:NormalizeDir2D(targetPos-pos)
        elseif targetBox~=nil then
            local bp=currentBoxPos()
            if bp~=nil then
                targetPos=bp+Vector(0,0,90)
                dir=self:NormalizeDir2D(targetPos-pos)
            end
        end

        local step=speed*dt
        local nextPos=pos+dir*step
        if targetPos~=nil then
            local dist=DKLength2D(pos,targetPos)
            local segmentHit=self:GetDistance2DPointToSegment(targetPos,pos,nextPos)<=hitRadius
            if dist<=step+hitRadius or segmentHit then
                nextPos=Vector(targetPos.x,targetPos.y,targetPos.z)
            end
        end

        local moved=DKLength2D(previousPos,nextPos)
        traveled=traveled+moved
        pos=nextPos
        pos.z=GetGroundHeight(pos,nil)+100
        if fx~=nil then self:UpdateDirectionalParticle(fx,pos,dir,speed) end

        if travelWithCaster then
            local hp=pos-dir*70
            hp.z=GetGroundHeight(hp,caster)
            lastKartPos=Vector(hp.x,hp.y,hp.z)
            caster:SetAbsOrigin(lastKartPos)
            if st~=nil then
                st.speed=0
                st.yaw=DKNormalizeYaw(math.deg(DKAtan2(dir.y,dir.x)))
            end
            if self.controller~=nil and self.controller.SetHeroFacing~=nil then
                pcall(function() self.controller:SetHeroFacing(caster,st and st.yaw or DKNormalizeYaw(math.deg(DKAtan2(dir.y,dir.x)))) end)
            elseif caster.FaceTowards~=nil then
                pcall(function() caster:FaceTowards(lastKartPos+dir*256) end)
            end
        end

        if self:BlockProjectileWithPowerCog(playerID,pos,hitRadius,'storm_hammer') then
            finish(pos,false,nil,nil)
            return nil
        end
        if self:HandleSpecialProjectileTargetHit(playerID,pos,hitRadius,'storm_hammer') then
            finish(pos,false,nil,nil)
            return nil
        end

        if DKValidUnit(live) then
            local livePos=live:GetAbsOrigin()
            if DKLength2D(pos,livePos)<=hitRadius or self:GetDistance2DPointToSegment(livePos,previousPos,pos)<=hitRadius then
                finish(livePos,true,live,nil)
                return nil
            end
        elseif targetBox~=nil then
            local bp=currentBoxPos()
            if bp~=nil and (DKLength2D(pos,bp)<=hitRadius or self:GetDistance2DPointToSegment(bp,previousPos,pos)<=hitRadius) then
                finish(bp,true,nil,targetBox)
                return nil
            end
        end

        if traveled>=range then
            if DKValidUnit(live) and DKLength2D(start,live:GetAbsOrigin())<=range+hitRadius then
                finish(live:GetAbsOrigin(),true,live,nil)
            elseif targetBox~=nil then
                local bp=currentBoxPos()
                if bp~=nil and DKLength2D(start,bp)<=range+hitRadius then
                    finish(bp,true,nil,targetBox)
                else
                    finish(pos,true,nil,nil)
                end
            else
                finish(pos,true,nil,nil)
            end
            return nil
        end
        return 0.02
    end,0.02)

    return true
end

-- FIX129: the parent Illusory Orb particle is normally driven by Puck's actual
-- ability projectile. In a custom item context some clients render no sphere at all.
-- Keep the real parent projectile when possible, but also render native child orb
-- components at the authoritative custom-item position so the Orb is always visible.
function DotaKartItemSystem:CreateIllusoryOrbFallbackVisuals(data, pos, dir)
    if data == nil or ParticleManager == nil or pos == nil then return end
    data.visual_fxs = data.visual_fxs or {}
    local def = data.def or {}
    local names = { def.particle_orb_main, def.particle_orb_glow, def.particle_orb_sparks, def.particle_orb_mist }
    for _,name in ipairs(names) do
        if name ~= nil and name ~= "" then
            local fx=nil
            local ok=pcall(function()
                fx=ParticleManager:CreateParticle(name,PATTACH_WORLDORIGIN,nil)
                ParticleManager:SetParticleControl(fx,0,pos)
                ParticleManager:SetParticleControl(fx,1,pos)
                ParticleManager:SetParticleControl(fx,2,pos)
                ParticleManager:SetParticleControl(fx,3,pos)
                ParticleManager:SetParticleControlForward(fx,0,dir or Vector(1,0,0))
            end)
            if ok and fx~=nil then table.insert(data.visual_fxs,fx) end
        end
    end
end

function DotaKartItemSystem:UpdateIllusoryOrbFallbackVisuals(data, pos, dir)
    if data==nil or data.visual_fxs==nil or ParticleManager==nil then return end
    for _,fx in ipairs(data.visual_fxs) do
        pcall(function()
            ParticleManager:SetParticleControl(fx,0,pos)
            ParticleManager:SetParticleControl(fx,1,pos)
            ParticleManager:SetParticleControl(fx,2,pos)
            ParticleManager:SetParticleControl(fx,3,pos)
            ParticleManager:SetParticleControlForward(fx,0,dir or Vector(1,0,0))
        end)
    end
end

function DotaKartItemSystem:DestroyIllusoryOrbFallbackVisuals(data)
    if data==nil or data.visual_fxs==nil or ParticleManager==nil then return end
    for _,fx in ipairs(data.visual_fxs) do
        pcall(function() ParticleManager:DestroyParticle(fx,false); ParticleManager:ReleaseParticleIndex(fx) end)
    end
    data.visual_fxs=nil
end

function DotaKartItemSystem:DestroyIllusoryOrb(playerID,data,consume,reason)
    data=data or (self.activeIllusoryOrbs and self.activeIllusoryOrbs[playerID])
    if data==nil or data.destroyed==true then return end
    data.destroyed=true
    if self.activeIllusoryOrbs then self.activeIllusoryOrbs[playerID]=nil end
    if data.projectile_id ~= nil and ProjectileManager ~= nil and ProjectileManager.DestroyLinearProjectile ~= nil then
        pcall(function() ProjectileManager:DestroyLinearProjectile(data.projectile_id) end)
        data.projectile_id = nil
    end
    if data.fx then self:DestroyLinearParticle(data.fx,false) end
    self:DestroyIllusoryOrbFallbackVisuals(data)
    local caster=self:GetHeroForPlayer(playerID)
    self:EmitKartSound(caster,data.def and data.def.sound_orb_end,data.pos)
    if consume==true then self:ConsumeHeldItem(playerID,data.item_name,data.def) end
    if self.config and self.config.debug then print("[DotaKartItems] Illusory Orb ended player="..tostring(playerID).." reason="..tostring(reason)) end
end

function DotaKartItemSystem:CreateDreamCoil(playerID,caster,pos,def)
    local now=DKNow()
    local coil={owner_player_id=playerID,caster=caster,center=Vector(pos.x,pos.y,pos.z),def=def,end_time=now+(tonumber(def.coil_duration) or 2.0),targets={}}
    coil.start_fx=self:CreateWorldParticle(def.particle_coil_start,coil.center,tonumber(def.coil_duration) or 2.0)
    self:EmitKartWorldSound(caster,def.sound_coil,coil.center)
    self:DestroyDoppelDecoysInRadius(playerID,coil.center,tonumber(def.coil_latch_radius) or 375,"dream_coil")
    for _,otherID in ipairs(self:GetRegisteredPlayerIDs()) do
        if tonumber(otherID)~=tonumber(playerID) then
            local other=self:GetHeroForPlayer(otherID)
            if DKValidUnit(other) and not self:IsKartUntargetable(otherID) and DKLength2D(coil.center,other:GetAbsOrigin()) <= (tonumber(def.coil_latch_radius) or 375) then
                local fx=nil
                if ParticleManager~=nil then
                    pcall(function()
                        fx=ParticleManager:CreateParticle(def.particle_coil_tether,PATTACH_WORLDORIGIN,nil)
                        ParticleManager:SetParticleControl(fx,0,coil.center)
                        ParticleManager:SetParticleControl(fx,1,other:GetAbsOrigin()+Vector(0,0,80))
                    end)
                end
                coil.targets[tonumber(otherID) or otherID]={hero=other,fx=fx,snapped=false}
            end
        end
    end
    table.insert(self.activeDreamCoils,coil)
end

function DotaKartItemSystem:UpdateDreamCoils(now)
    local alive={}
    for _,coil in ipairs(self.activeDreamCoils or {}) do
        if coil~=nil and now < (coil.end_time or 0) then
            for otherID,t in pairs(coil.targets or {}) do
                if t.snapped~=true and DKValidUnit(t.hero) then
                    local hp=t.hero:GetAbsOrigin()+Vector(0,0,80)
                    if t.fx~=nil and ParticleManager~=nil then pcall(function() ParticleManager:SetParticleControl(t.fx,0,coil.center); ParticleManager:SetParticleControl(t.fx,1,hp) end) end
                    if DKLength2D(coil.center,t.hero:GetAbsOrigin()) > (tonumber(coil.def.coil_break_radius) or 600) then
                        t.snapped=true
                        if t.fx~=nil and ParticleManager~=nil then pcall(function() ParticleManager:DestroyParticle(t.fx,false); ParticleManager:ReleaseParticleIndex(t.fx) end); t.fx=nil end
                        self:CreateWorldParticle(coil.def.particle_coil_break,hp,0.8)
                        self:EmitKartWorldSound(coil.caster,coil.def.sound_coil_snap,hp)
                        self:ApplyKartStun(coil.caster,t.hero,tonumber(coil.def.coil_break_stun) or 3.0)
                    end
                end
            end
            table.insert(alive,coil)
        else
            for _,t in pairs(coil and coil.targets or {}) do if t.fx~=nil and ParticleManager~=nil then pcall(function() ParticleManager:DestroyParticle(t.fx,false); ParticleManager:ReleaseParticleIndex(t.fx) end) end end
        end
    end
    self.activeDreamCoils=alive
end

function DotaKartItemSystem:TeleportToIllusoryOrb(playerID,data)
    local caster=self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) or data==nil or data.destroyed==true then return false end
    local p=Vector(data.pos.x,data.pos.y,data.pos.z)
    p.z=GetGroundHeight(p,caster)
    local antiSkip=GameRules and GameRules.DotaKartAntiSkip or nil
    if antiSkip~=nil and antiSkip.AuthorizeTeleport~=nil then pcall(function() antiSkip:AuthorizeTeleport(playerID,1.5) end) end
    caster:SetAbsOrigin(p)
    pcall(function() FindClearSpaceForUnit(caster,p,true) end)
    self:CreateDreamCoil(playerID,caster,p,data.def)
    self:DestroyIllusoryOrb(playerID,data,true,"jaunt")
    return true
end

function DotaKartItemSystem:UseIllusoryOrb(playerID,itemName,def)
    self.activeIllusoryOrbs=self.activeIllusoryOrbs or {}
    local active=self.activeIllusoryOrbs[playerID]
    if active~=nil and active.destroyed~=true then return self:TeleportToIllusoryOrb(playerID,active) end
    local caster=self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end
    local dir=self:NormalizeDir2D(caster:GetForwardVector())
    local start=caster:GetAbsOrigin()+dir*110+Vector(0,0,90)
    local speed=tonumber(def.speed) or 1350
    local range=tonumber(def.travel_distance or def.cast_range) or 3000

    -- FIX128: Puck's Illusory Orb VFX is authored as a Source 2 linear projectile.
    -- Driving it manually through CP1 could leave the orb invisible, so create an
    -- engine linear projectile for the visual and use its live position for gameplay.
    local projectileID=nil
    if ProjectileManager ~= nil and ProjectileManager.CreateLinearProjectile ~= nil then
        pcall(function()
            projectileID=ProjectileManager:CreateLinearProjectile({
                Source=caster,
                EffectName=def.particle_orb,
                vSpawnOrigin=start,
                vVelocity=dir*speed,
                fDistance=range,
                fStartRadius=1,
                fEndRadius=1,
                iUnitTargetTeam=0,
                iUnitTargetType=0,
                iUnitTargetFlags=0,
                bDeleteOnHit=false,
                bProvidesVision=false,
                bHasFrontalCone=false
            })
        end)
    end
    local fx=nil
    if projectileID==nil then fx=self:CreateDirectionalParticle(def.particle_orb,start,dir,speed) end
    local data={owner_player_id=playerID,caster=caster,def=def,item_name=itemName,pos=Vector(start.x,start.y,start.z),fx=fx,projectile_id=projectileID,destroyed=false,hit_cd={}}
    self:CreateIllusoryOrbFallbackVisuals(data,start,dir)
    self.activeIllusoryOrbs[playerID]=data
    self:EmitKartSound(caster,def.sound_orb,start)
    local traveled=0
    local serial=self:NextProjectileSerial()
    GameRules:GetGameModeEntity():SetContextThink("DotaKartIllusoryOrb_"..tostring(serial),function()
        if data.destroyed==true then return nil end
        -- FIX129: gameplay position is deterministic and no longer depends on the engine
        -- returning a valid visual-projectile location. The engine projectile remains a
        -- bonus visual layer, while native child particles follow this exact position.
        local step=speed*0.03
        traveled=math.min(range,traveled+step)
        data.pos=start+dir*traveled
        data.pos.z=GetGroundHeight(data.pos,nil)+90
        self:UpdateDirectionalParticle(data.fx,data.pos,dir,speed)
        self:UpdateIllusoryOrbFallbackVisuals(data,data.pos,dir)
        if self:BlockProjectileWithPowerCog(playerID,data.pos,100,"illusory_orb") or self:HandleSpecialProjectileTargetHit(playerID,data.pos,100,"illusory_orb") then self:DestroyIllusoryOrb(playerID,data,true,"blocked"); return nil end
        local now=DKNow()
        for _,otherID in ipairs(self:GetRegisteredPlayerIDs()) do
            if tonumber(otherID)~=tonumber(playerID) and now >= (data.hit_cd[otherID] or 0) then
                local other=self:GetHeroForPlayer(otherID)
                if DKValidUnit(other) and not self:IsKartUntargetable(otherID) and DKLength2D(data.pos,other:GetAbsOrigin()) <= (tonumber(def.slow_radius) or 225) then
                    data.hit_cd[otherID]=now+0.25
                    self:ApplyKartSlow(caster,other,tonumber(def.slow_duration) or 1.0,tonumber(def.slow_pct) or 0.30,0,0.03)
                end
            end
        end
        if traveled>=range then self:DestroyIllusoryOrb(playerID,data,true,"max_range"); return nil end
        return 0.03
    end,0.03)
    return true
end

function DotaKartItemSystem:UseItem(playerID, itemName)
    local nowCheck = DKNow()
    if self.controller ~= nil then
        local stunned = self.controller.IsKartStunned ~= nil and self.controller:IsKartStunned(playerID, nowCheck)
        local locked = self.controller.IsKartLocked ~= nil and self.controller:IsKartLocked(playerID, nowCheck)
        if stunned or locked then
            if self.config.debug then
                print("[DotaKartItems] Player " .. tostring(playerID) .. " tentou usar item durante stun/lock; bloqueado.")
            end
            return true
        end
    end

    local currentState = self:GetState(playerID)
    if currentState ~= nil and ((tonumber(currentState.astral_enemy_until) or 0) > nowCheck or (tonumber(currentState.astral_self_until) or 0) > nowCheck) then
        if self.config.debug then print("[DotaKartItems] Player " .. tostring(playerID) .. " tentou usar item durante Astral; bloqueado.") end
        return true
    end

    -- Durante Item Steal pendente, nem usuario nem vitima podem gastar o icone temporario.
    if self.itemStealLocks ~= nil and (self.itemStealLocks[playerID] or 0) > nowCheck then
        if self.config.debug then
            print("[DotaKartItems] Player " .. tostring(playerID) .. " tentou usar item durante Item Steal; bloqueado.")
        end
        return true
    end

    -- Enquanto a roleta esta girando, T nao deve gastar o icone temporario.
    if self.rolling[playerID] ~= nil then
        if self.config.debug then
            print("[DotaKartItems] Player " .. tostring(playerID) .. " tentou usar item durante roulette; aguardando final.")
        end
        return true
    end

    itemName = itemName or self:GetHeldItem(playerID)
    if itemName == nil or itemName == "" then return false end

    local def = self.itemDefs[itemName]
    if def == nil then return false end

    -- FIX72: Root bloqueia somente itens de mobilidade especificados.
    if self.controller ~= nil and self.controller.IsKartRooted ~= nil and self.controller:IsKartRooted(playerID, nowCheck) then
        local blockedByRoot = { nitro = true, leap = true, burrowstrike = true, charge_darkness = true }
        if blockedByRoot[def.kind or ""] == true then
            if self.config.debug then
                print("[DotaKartItems] Player " .. tostring(playerID) .. " tentou usar " .. tostring(def.kind) .. " durante root; bloqueado.")
            end
            return true
        end
    end

    if def.kind == "nitro" then
        return self:ApplyNitro(playerID, itemName, def)
    elseif def.kind == "star" then
        return self:ApplyStar(playerID, itemName, def)
    elseif def.kind == "meat_hook" then
        return self:UseMeatHook(playerID, itemName, def)
    elseif def.kind == "hookshot" then
        return self:UseHookshot(playerID, itemName, def)
    elseif def.kind == "leap" then
        return self:UseLeap(playerID, itemName, def)
    elseif def.kind == "sacred_arrow" then
        return self:UseSacredArrow(playerID, itemName, def)
    elseif def.kind == "swap_missile" then
        return self:UseSwapMissile(playerID, itemName, def)
    elseif def.kind == "charge_darkness" then
        return self:UseChargeOfDarkness(playerID, itemName, def)
    elseif def.kind == "venomous_gale" then
        return self:UseVenomousGale(playerID, itemName, def)
    elseif def.kind == "power_cogs" then
        return self:UsePowerCogs(playerID, itemName, def)
    elseif def.kind == "frost_shield" then
        return self:UseFrostShield(playerID, itemName, def)
    elseif def.kind == "chain_frost" then
        return self:UseChainFrost(playerID, itemName, def)
    elseif def.kind == "tornado" then
        return self:UseTornado(playerID, itemName, def)
    elseif def.kind == "ice_shards" then
        return self:UseIceShards(playerID, itemName, def)
    elseif def.kind == "item_steal" then
        return self:UseItemSteal(playerID, itemName, def)
    elseif def.kind == "chaos_bolt" then
        return self:UseChaosBolt(playerID, itemName, def)
    elseif def.kind == "invisibility" then
        return self:UseInvisibility(playerID, itemName, def)
    elseif def.kind == "ice_wall" then
        return self:UseIceWall(playerID, itemName, def)
    elseif def.kind == "burrowstrike" then
        return self:UseBurrowstrike(playerID, itemName, def)
    elseif def.kind == "natures_grasp" then
        return self:UseNaturesGrasp(playerID, itemName, def)
    elseif def.kind == "bloodlust" then
        return self:ApplyBloodlust(playerID, itemName, def)
    elseif def.kind == "spectral_dagger" then
        return self:UseSpectralDagger(playerID, itemName, def)
    elseif def.kind == "battle_hunger" then
        return self:UseBattleHunger(playerID, itemName, def)
    elseif def.kind == "x_marks" then
        return self:UseXMarks(playerID, itemName, def)
    elseif def.kind == "doppelwalk" then
        return self:UseDoppelwalk(playerID, itemName, def)
    elseif def.kind == "shukuchi" then
        return self:UseShukuchi(playerID, itemName, def)
    elseif def.kind == "crystal_clone" then
        return self:UseCrystalClone(playerID, itemName, def)
    elseif def.kind == "astral_imprisonment" then
        return self:UseAstralImprisonment(playerID, itemName, def)
    elseif def.kind == "ball_lightning" then
        return self:UseBallLightning(playerID, itemName, def)
    elseif def.kind == "homing_missile" then
        return self:UseHomingMissile(playerID, itemName, def)
    elseif def.kind == "plague_ward" then
        return self:UsePlagueWard(playerID, itemName, def)
    elseif def.kind == "the_swarm" then
        return self:UseTheSwarm(playerID, itemName, def)
    elseif def.kind == "storm_hammer" then
        return self:UseStormHammer(playerID, itemName, def)
    elseif def.kind == "illusory_orb" then
        return self:UseIllusoryOrb(playerID, itemName, def)
    elseif def.kind == "torrent_storm" then
        return self:UseTorrentStorm(playerID, itemName, def)
    elseif def.kind == "unstable_concoction" then
        return self:StartUnstableConcoction(playerID, itemName, def)
    elseif def.kind == "unstable_concoction_throw" then
        return self:ThrowUnstableConcoction(playerID, itemName, def)
    end

    return false
end


-- ============================================================
-- FIX90: Spectral Dagger
-- Cria Shadow Path no trajeto da adaga e nos alvos atingidos. O usuário ganha
-- bônus de velocidade no próprio caminho e inimigos sofrem slow enquanto passam nele.
-- Se o jogador não estiver em 1º e o rival exatamente uma posição à frente estiver
-- dentro de 2000 unidades, a adaga segue waypoints da pista até chegar perto do alvo,
-- depois entra em perseguição direta. R+T força disparo para frente.
-- ============================================================
function DotaKartItemSystem:GetSpectralPathBuffUntil(playerID)
    local st = self:GetState(playerID)
    if st ~= nil then return tonumber(st.spectral_path_buff_until or 0) or 0 end
    self.spectralDaggerPathBuffUntil = self.spectralDaggerPathBuffUntil or {}
    return tonumber(self.spectralDaggerPathBuffUntil[playerID] or 0) or 0
end

function DotaKartItemSystem:SetSpectralPathBuff(playerID, duration, bonusPct, def)
    playerID = tonumber(playerID)
    if playerID == nil or playerID < 0 then return end
    local now = DKNow()
    local dur = math.max(0.05, tonumber(duration) or 4.0)
    local untilTime = now + dur
    self.spectralDaggerPathBuffUntil = self.spectralDaggerPathBuffUntil or {}
    self.spectralDaggerPathBuffUntil[playerID] = math.max(self.spectralDaggerPathBuffUntil[playerID] or 0, untilTime)

    local st = self:GetState(playerID)
    if st ~= nil then
        st.spectral_path_buff_until = math.max(st.spectral_path_buff_until or 0, untilTime)
        st.spectral_path_bonus_pct = math.max(tonumber(st.spectral_path_bonus_pct or 0) or 0, tonumber(bonusPct) or 0.10)
        st.spectral_unobstructed_until = math.max(st.spectral_unobstructed_until or 0, untilTime)
        st.spectral_recovery_delay = tonumber(def and def.stuck_recover_delay or 5.0) or 5.0
        st.spectral_last_active_time = DKNow()
        local baseMax = (self.controller ~= nil and self.controller.config ~= nil and self.controller.config.max_speed) or 880
        local targetMax = baseMax * (1.0 + (tonumber(bonusPct) or 0.10))
        st.item_max_speed_until = math.max(st.item_max_speed_until or 0, untilTime)
        st.item_max_speed = math.max(st.item_max_speed or 0, targetMax)
    end
end

function DotaKartItemSystem:IsSpectralPathBuffed(playerID, now)
    return (self:GetSpectralPathBuffUntil(playerID) or 0) > (now or DKNow())
end


function DotaKartItemSystem:CreateSpectralPathWorldParticle(particleName, pos, radius, duration, dir)
    if particleName == nil or particleName == "" or ParticleManager == nil or pos == nil then return nil end
    local fx = nil
    local r = tonumber(radius) or 200
    local p = Vector(pos.x, pos.y, GetGroundHeight(pos, nil) + 10)
    local fwd = self:NormalizeDir2D(dir or Vector(1, 0, 0))
    local right = Vector(-fwd.y, fwd.x, 0)

    local ok = pcall(function()
        fx = ParticleManager:CreateParticle(particleName, PATTACH_WORLDORIGIN, nil)
        -- FIX94: CPs conservadores. A Spectral Dagger do DotA Kart usa Lua para lógica,
        -- então a partícula é só marcador visual do segmento no chão.
        ParticleManager:SetParticleControl(fx, 0, p)
        ParticleManager:SetParticleControl(fx, 1, p + fwd * 48)
        ParticleManager:SetParticleControl(fx, 2, p + right * 48)
        ParticleManager:SetParticleControl(fx, 3, Vector(r, 0, 0))
        ParticleManager:SetParticleControl(fx, 4, p)
        ParticleManager:SetParticleControlForward(fx, 0, fwd)
        ParticleManager:SetParticleControlForward(fx, 1, fwd)
    end)
    if not ok then return nil end
    if fx ~= nil and duration ~= nil and duration > 0 then
        GameRules:GetGameModeEntity():SetContextThink("DotaKartSpectralPathParticleRelease_" .. tostring(fx), function()
            pcall(function()
                ParticleManager:DestroyParticle(fx, false)
                ParticleManager:ReleaseParticleIndex(fx)
            end)
            return nil
        end, duration)
    end
    return fx
end

function DotaKartItemSystem:SpawnSpectralPathSegment(ownerPlayerID, pos, def, duration, dir, commonExpireTime)
    if pos == nil then return nil end
    local now = DKNow()
    local expireTime = tonumber(commonExpireTime) or (now + (tonumber(duration) or tonumber(def.path_duration) or 12.0))
    local dur = math.max(0.05, expireTime - now)
    local radius = tonumber(def.path_radius) or 200
    local p = Vector(pos.x, pos.y, GetGroundHeight(pos, nil) + 8)
    local seg = {
        owner = ownerPlayerID,
        pos = p,
        radius = radius,
        expire_time = expireTime,
        hit_cd = {},
        fxs = {},
        dir = self:NormalizeDir2D(dir or Vector(1, 0, 0))
    }

    -- FIX94: o rastro de gameplay é a tabela Lua acima; as partículas são apenas decoração.
    -- Mantém poucos VFX por ponto para ficar consistente e barato em performance.
    local particles = {
        def.particle_path_owner,
        def.particle_path,
        def.particle_path_owner_fallback
    }
    local used = {}
    for _, particleName in ipairs(particles) do
        if particleName ~= nil and particleName ~= "" and used[particleName] ~= true then
            used[particleName] = true
            local fx = self:CreateSpectralPathWorldParticle(particleName, p, radius, dur, seg.dir)
            if fx ~= nil then table.insert(seg.fxs, fx) end
            if #seg.fxs >= 1 then break end
        end
    end

    self.activeSpectralDaggerPaths = self.activeSpectralDaggerPaths or {}
    table.insert(self.activeSpectralDaggerPaths, seg)
    return seg
end

function DotaKartItemSystem:DestroySpectralPathSegment(seg)
    if seg == nil then return end
    for _, fx in ipairs(seg.fxs or {}) do self:DestroyLinearParticle(fx, false) end
    if seg.fx ~= nil then self:DestroyLinearParticle(seg.fx, false) end
end

function DotaKartItemSystem:StartSpectralPathCreator(ownerPlayerID, targetPlayerID, target, def, pathExpireTime)
    if targetPlayerID == nil or targetPlayerID < 0 or not DKValidUnit(target) then return end
    local now = DKNow()
    local expireTime = tonumber(pathExpireTime) or (now + (tonumber(def.path_duration) or 12.0))
    if expireTime <= now + 0.05 then return end

    local token = (tonumber(target.dotakart_spectral_token) or 0) + 1
    target.dotakart_spectral_token = token
    self.spectralDaggerPathCreatorUntil = self.spectralDaggerPathCreatorUntil or {}
    self.spectralDaggerPathCreatorUntil[targetPlayerID] = expireTime

    local serial = self:NextProjectileSerial()
    local lastPos = target:GetAbsOrigin()
    local spacing = tonumber(def.path_segment_spacing) or 60
    self:SpawnSpectralPathSegment(ownerPlayerID, lastPos, def, expireTime - now, target:GetForwardVector(), expireTime)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartSpectralCreator_" .. tostring(serial), function()
        if not DKValidUnit(target) then return nil end
        if target.dotakart_spectral_token ~= token then return nil end
        local tnow = DKNow()
        if tnow >= (self.spectralDaggerPathCreatorUntil[targetPlayerID] or 0) then return nil end
        local pos = target:GetAbsOrigin()
        if DKLength2D(lastPos, pos) >= spacing then
            local d = self:NormalizeDir2D(pos - lastPos, target:GetForwardVector())
            lastPos = Vector(pos.x, pos.y, pos.z)
            self:SpawnSpectralPathSegment(ownerPlayerID, pos, def, expireTime - tnow, d, expireTime)
        end
        return 0.06
    end, 0.0)
end

function DotaKartItemSystem:ApplySpectralDaggerHit(caster, ownerPlayerID, targetPlayerID, target, def, pathExpireTime)
    if not DKValidUnit(target) then return end
    if self:IsPlayerStarActive(targetPlayerID) or self:IsKartUntargetable(targetPlayerID) then return end
    local now = DKNow()
    if not self:IsSpectralPathBuffed(targetPlayerID, now) then
        self:ApplyKartSlow(caster, target, tonumber(def.slow_refresh) or 0.30, tonumber(def.slow_pct) or 0.10, 0, 0.03)
    end
    if def.particle_hit ~= nil then self:CreateAttachedParticleRobust(def.particle_hit, target, 0.65, 150) end
    self:EmitSpectralDaggerSound(ownerPlayerID, target, def.sound_hit, target:GetAbsOrigin(), targetPlayerID, true)

    -- FIX95: após acertar, o alvo passa a emitir o Shadow Path somente até o fim do
    -- Path Duration original da adaga. Não reinicia os 12s; todos os segmentos desaparecem juntos.
    self:StartSpectralPathCreator(ownerPlayerID, targetPlayerID, target, def, pathExpireTime)
end

function DotaKartItemSystem:GetSpectralForceForward(playerID)
    local st = self:GetState(playerID)
    if st ~= nil then
        if st.force_forward_item == true and (st.force_forward_item_until or 0) >= DKNow() then return true end
        if st.input ~= nil and st.input.force_forward == true then return true end
    end
    return false
end

function DotaKartItemSystem:GetTrackPointNearestIndex(pos)
    local hud = self.hud or GameRules.DotaKartHUD
    local pts = hud and hud.trackWorldPoints or nil
    if pts == nil or #pts <= 0 then return nil end
    local best, bestDist = 1, nil
    for i, p in ipairs(pts) do
        local d = DKLength2D(pos, p)
        if bestDist == nil or d < bestDist then bestDist = d; best = i end
    end
    return best
end

function DotaKartItemSystem:GetTrackPointDirToTarget(pos, targetPos, preferBackward)
    local hud = self.hud or GameRules.DotaKartHUD
    local pts = hud and hud.trackWorldPoints or nil
    if pts == nil or #pts < 2 then return nil end
    local idx = self:GetTrackPointNearestIndex(pos)
    if idx == nil then return nil end
    local bestIdx = self:GetTrackPointNearestIndex(targetPos)
    if bestIdx == nil then return nil end
    local n = #pts
    local nextIdx = idx + 1
    if nextIdx > n then nextIdx = 1 end
    local prevIdx = idx - 1
    if prevIdx < 1 then prevIdx = n end
    local fwdSteps = (bestIdx - idx) % n
    local backSteps = (idx - bestIdx) % n
    local chosen = nil
    if preferBackward == true then
        chosen = prevIdx
    elseif preferBackward == false then
        chosen = nextIdx
    else
        chosen = fwdSteps <= backSteps and nextIdx or prevIdx
    end
    local wp = pts[chosen]
    if wp == nil then return nil end
    local dir = self:NormalizeDir2D(Vector(wp.x - pos.x, wp.y - pos.y, 0))
    if dir == nil then return nil end
    return dir
end


-- ============================================================
-- FIX96: Unstable Concoction
-- ============================================================
function DotaKartItemSystem:GetUnstableConcoctionStun(data, def, now)
    data = data or {}
    def = def or self.itemDefs.item_dotakart_unstable_concoction or {}
    local brewed = math.max(0, (now or DKNow()) - (tonumber(data.start_time or 0) or 0))
    local maxBrew = math.max(0.1, tonumber(def.max_brew_time) or 5.0)
    local maxStun = tonumber(def.max_stun) or 3.2
    return DKClamp((brewed / maxBrew) * maxStun, 0.15, maxStun)
end

function DotaKartItemSystem:ShowConcoctionTimer(hero, remaining, duration)
    if CustomGameEventManager == nil or not DKValidUnit(hero) then return end
    local pos = hero:GetAbsOrigin() + Vector(0,0,255)
    pcall(function()
        CustomGameEventManager:Send_ServerToAllClients("dotakart_concoction_timer", {
            entindex = hero:entindex(),
            remaining = math.max(0, tonumber(remaining) or 0),
            text = string.format("%.1f", math.max(0, tonumber(remaining) or 0)),
            duration = tonumber(duration) or 0.32,
            x = pos.x,
            y = pos.y,
            z = pos.z
        })
    end)
end

function DotaKartItemSystem:StartUnstableConcoction(playerID, itemName, def)
    local hero = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(hero) then return false end
    def = def or self.itemDefs[itemName] or {}
    local now = DKNow()
    self.activeConcoctions = self.activeConcoctions or {}
    self.activeConcoctions[playerID] = {
        caster = hero,
        def = def,
        start_time = now,
        explode_time = now + (tonumber(def.explode_time) or 5.5),
        max_brew_time = now + (tonumber(def.max_brew_time) or 5.0),
        next_timer = 0,
        thrown = false
    }

    local st = self:GetState(playerID)
    if st ~= nil then
        local maxBase = 880
        if self.controller ~= nil and self.controller.config ~= nil and self.controller.config.max_speed ~= nil then
            maxBase = tonumber(self.controller.config.max_speed) or maxBase
        end
        local pct = tonumber(def.move_speed_bonus_pct) or 10
        st.concoction_until = now + (tonumber(def.explode_time) or 5.5)
        st.item_max_speed_until = math.max(st.item_max_speed_until or 0, now + (tonumber(def.explode_time) or 5.5))
        st.item_max_speed = math.max(st.item_max_speed or 0, maxBase * (1.0 + pct / 100.0))
    end

    self:EmitKartSound(hero, def.sound_fuse, hero:GetAbsOrigin())
    self:SetHeldItemHUD(playerID, def.throw_item or "item_dotakart_unstable_concoction_throw", 0)
    print("[DotaKartItems] Player " .. tostring(playerID) .. " iniciou UNSTABLE CONCOCTION")
    return true
end

function DotaKartItemSystem:FindConcoctionTarget(playerID, pos, dir, range, backward)
    local frontDot = backward == true and 0.10 or 0.05
    return self:FindNearestEnemyKartInArc(playerID, pos, dir, range or 1200, frontDot)
end

function DotaKartItemSystem:ExplodeUnstableConcoction(ownerPlayerID, caster, pos, stunDuration, def)
    if pos == nil then return end
    def = def or self.itemDefs.item_dotakart_unstable_concoction or {}
    local radius = tonumber(def.radius) or 350
    self:DestroyDoppelDecoysInRadius(ownerPlayerID, pos, radius, "unstable_concoction_explosion")
    self:CreateWorldParticle(def.particle_explosion, pos + Vector(0,0,72), 1.25)
    self:EmitKartSound(caster, def.sound_stun, pos)
    for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
        local other = self:GetHeroForPlayer(otherID)
        if DKValidUnit(other) and DKLength2D(pos, other:GetAbsOrigin()) <= radius then
            self:ApplyKartStun(caster or other, other, stunDuration or 1.0)
            self:EmitKartSound(other, def.sound_stun, other:GetAbsOrigin())
        end
    end
end

function DotaKartItemSystem:CreateConcoctionProjectileFX(def, pos, dir, speed)
    local particle = def and def.particle or "particles/units/heroes/hero_alchemist/alchemist_unstable_concoction_projectile.vpcf"
    return self:CreateMissileParticle(particle, pos, dir or Vector(1,0,0), speed or 1400, 380)
end

function DotaKartItemSystem:UpdateConcoctionProjectileFX(fx, pos, dir, speed)
    self:UpdateMissileParticle(fx, pos, dir or Vector(1,0,0), speed or 1400, 380)
end

function DotaKartItemSystem:ThrowUnstableConcoction(playerID, itemName, throwDef)
    local data = self.activeConcoctions and self.activeConcoctions[playerID]
    local caster = self:GetHeroForPlayer(playerID)
    if data == nil or not DKValidUnit(caster) then
        self:SetHeldItemHUD(playerID, "", 0)
        return false
    end
    if data.thrown == true then return true end
    data.thrown = true

    local def = data.def or self.itemDefs.item_dotakart_unstable_concoction or throwDef or {}
    local now = DKNow()
    local stunDuration = self:GetUnstableConcoctionStun(data, def, now)
    local fwd = self:GetForwardForPlayer(playerID, caster)
    local stInput = self:GetState(playerID)
    local backward = false
    if stInput ~= nil and stInput.input ~= nil then backward = stInput.input.reverse == true and stInput.input.forward ~= true end
    if backward then fwd = fwd * -1 end
    fwd = self:NormalizeDir2D(fwd, caster:GetForwardVector())

    local start = caster:GetAbsOrigin() + fwd * 145 + Vector(0,0,110)
    local pos = Vector(start.x, start.y, start.z)
    local speed = tonumber(def.projectile_speed or throwDef.projectile_speed) or 1400
    local range = tonumber(def.cast_range or throwDef.cast_range) or 1200
    local hitRadius = tonumber(def.hit_radius or throwDef.hit_radius) or 170
    local target, targetPlayerID = self:FindConcoctionTarget(playerID, pos, fwd, range, backward)
    local homing = DKValidUnit(target)
    local fx = self:CreateConcoctionProjectileFX(def, pos, fwd, speed)
    local serial = self:NextProjectileSerial()
    local startTime = now
    local lastTime = now
    local traveled = 0
    local explodeTime = homing and (now + math.max(1.2, range / math.max(1, speed) + 2.0)) or (data.explode_time or (now + 0.25))

    self:EmitKartSound(caster, def.sound_throw or throwDef.sound_throw, start)
    self:SetHeldItemHUD(playerID, "", 0)

    GameRules:GetGameModeEntity():SetContextThink("DotaKartUnstableConcoctionProjectile_" .. tostring(serial), function()
        if not DKValidUnit(caster) then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            return nil
        end
        local tnow = DKNow()
        local dt = math.max(0.001, math.min(0.05, tnow - lastTime))
        lastTime = tnow

        if homing then
            if not DKValidUnit(target) or not self:IsHomingValidTarget(playerID, targetPlayerID) then
                local decoy = tonumber(targetPlayerID) and tonumber(targetPlayerID) >= 0 and self:GetDoppelDecoyForOwner(targetPlayerID) or nil
                if decoy ~= nil and DKValidUnit(decoy.unit) then
                    target = decoy.unit
                    targetPlayerID = decoy.target_id
                else
                    homing = false
                end
            end
            if homing then
                local targetPos = target:GetAbsOrigin() + Vector(0,0,88)
                local desired = self:NormalizeDir2D(targetPos - pos, fwd)
                local strength = DKClamp(def.homing_strength or 0.92, 0, 0.98)
                fwd = self:NormalizeDir2D(fwd * (1 - strength) + desired * strength, desired)
            end
        end

        local step = speed * dt
        traveled = traveled + step
        pos = pos + fwd * step
        pos.z = GetGroundHeight(pos, nil) + 92
        self:UpdateConcoctionProjectileFX(fx, pos, fwd, speed)

        if self:HandleSpecialProjectileTargetHit(playerID,pos,hitRadius,"unstable_concoction") then if fx~=nil then self:DestroyLinearParticle(fx,false) end; self.activeConcoctions[playerID]=nil; return nil end
        local hit, hitID = self:FindHeroHit(playerID, pos, hitRadius)
        if DKValidUnit(hit) then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            self:ExplodeUnstableConcoction(playerID, caster, hit:GetAbsOrigin(), stunDuration, def)
            self.activeConcoctions[playerID] = nil
            return nil
        end

        if (homing and traveled >= range * 1.5) or (not homing and tnow >= explodeTime) or tnow >= startTime + 6.0 then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            self:ExplodeUnstableConcoction(playerID, caster, pos, stunDuration, def)
            self.activeConcoctions[playerID] = nil
            return nil
        end
        return 0.02
    end, 0.02)

    print("[DotaKartItems] Player " .. tostring(playerID) .. " arremessou UNSTABLE CONCOCTION stun=" .. tostring(string.format("%.2f", stunDuration)) .. " homing=" .. tostring(targetPlayerID))
    return true
end

function DotaKartItemSystem:UpdateUnstableConcoctions(now)
    self.activeConcoctions = self.activeConcoctions or {}
    for playerID, data in pairs(self.activeConcoctions) do
        if data ~= nil and data.thrown ~= true then
            local hero = data.caster or self:GetHeroForPlayer(playerID)
            local def = data.def or self.itemDefs.item_dotakart_unstable_concoction or {}
            if not DKValidUnit(hero) then
                self.activeConcoctions[playerID] = nil
            else
                local remaining = (tonumber(data.explode_time or 0) or 0) - now
                if now >= (data.next_timer or 0) then
                    data.next_timer = now + 0.12
                    self:ShowConcoctionTimer(hero, remaining, 0.28)
                end
                if remaining <= 0 then
                    local stunDuration = self:GetUnstableConcoctionStun(data, def, now)
                    self:ExplodeUnstableConcoction(playerID, hero, hero:GetAbsOrigin(), stunDuration, def)
                    self:SetHeldItemHUD(playerID, "", 0)
                    self.activeConcoctions[playerID] = nil
                end
            end
        end
    end
end

function DotaKartItemSystem:GetPlayerIDOnePlaceBehind(playerID)
    local place = self:GetPlaceForPlayer(playerID)
    local wantedPlace = place + 1
    local count = self:GetRacerCount()
    if wantedPlace > count then return -1 end

    if self.hud ~= nil and self.hud.racers ~= nil then
        for otherID, racer in pairs(self.hud.racers) do
            if tonumber(otherID) ~= tonumber(playerID) and racer ~= nil and tonumber(racer.place or 0) == wantedPlace then
                return tonumber(otherID) or -1
            end
        end
    end

    if self.hud ~= nil and self.hud.lastRacers ~= nil then
        for _, racer in pairs(self.hud.lastRacers) do
            if racer ~= nil and tonumber(racer.player_id) ~= tonumber(playerID) and tonumber(racer.place or 0) == wantedPlace then
                return tonumber(racer.player_id) or -1
            end
        end
    end

    return -1
end

function DotaKartItemSystem:GetSpectralTargetOnePlaceAhead(playerID, caster, range)
    if self:GetPlaceForPlayer(playerID) <= 1 then return nil, -1 end
    local targetID = self:GetPlayerIDOnePlaceAhead(playerID)
    if targetID == nil or targetID < 0 then return nil, -1 end
    local target = self:GetHeroForPlayer(targetID)
    if self:IsPlayerInvisible(targetID) then local decoy=self:GetDoppelDecoyForOwner(targetID); if decoy and DKValidUnit(decoy.unit) then target=decoy.unit; targetID=decoy.target_id end end
    if not DKValidUnit(target) then return nil, -1 end
    if DKLength2D(caster:GetAbsOrigin(), target:GetAbsOrigin()) > (tonumber(range) or 2000) then return nil, -1 end
    return target, targetID
end

function DotaKartItemSystem:GetSpectralTargetOnePlaceBehind(playerID, caster, range)
    local targetID = self:GetPlayerIDOnePlaceBehind(playerID)
    if targetID == nil or targetID < 0 then return nil, -1 end
    local target = self:GetHeroForPlayer(targetID)
    if self:IsPlayerInvisible(targetID) then local decoy=self:GetDoppelDecoyForOwner(targetID); if decoy and DKValidUnit(decoy.unit) then target=decoy.unit; targetID=decoy.target_id end end
    if not DKValidUnit(target) then return nil, -1 end
    if DKLength2D(caster:GetAbsOrigin(), target:GetAbsOrigin()) > (tonumber(range) or 2000) then return nil, -1 end
    return target, targetID
end

function DotaKartItemSystem:IsHomingValidTarget(ownerPlayerID,targetPlayerID)
    targetPlayerID=tonumber(targetPlayerID) or -1
    if targetPlayerID<=-1000 then local data=self:GetDoppelDecoyByTargetID(targetPlayerID); return data~=nil and tonumber(data.owner_player_id)~=tonumber(ownerPlayerID) end
    if targetPlayerID<0 or tonumber(ownerPlayerID)==targetPlayerID then return false end
    if self.activeShukuchi and self.activeShukuchi[targetPlayerID] then return false end
    if self:IsKartUntargetable(targetPlayerID) then return false end
    if self:IsPlayerStarActive(targetPlayerID) or self:IsPlayerInvisible(targetPlayerID) then return false end
    return DKValidUnit(self:GetHeroForPlayer(targetPlayerID))
end

function DotaKartItemSystem:CreateSpectralDaggerProjectileFX(def, startPos, dir, speed)
    if ParticleManager == nil or startPos == nil then return nil end
    -- FIX94: usa apenas um VFX pontual/estável. A rota e colisão são 100% controladas por Lua.
    local names = { def.particle_tracking, def.particle_fallback, def.particle_glow }
    dir = self:NormalizeDir2D(dir or Vector(1,0,0))
    local fxs = {}
    local used = {}
    for _, particleName in ipairs(names) do
        if particleName ~= nil and particleName ~= "" and used[particleName] ~= true then
            used[particleName] = true
            local fx = nil
            local ok = pcall(function()
                fx = ParticleManager:CreateParticle(particleName, PATTACH_WORLDORIGIN, nil)
                ParticleManager:SetParticleControl(fx, 0, startPos)
                ParticleManager:SetParticleControl(fx, 1, startPos)
                ParticleManager:SetParticleControl(fx, 2, Vector(0,0,0))
                ParticleManager:SetParticleControl(fx, 3, startPos)
                ParticleManager:SetParticleControlForward(fx, 0, dir)
            end)
            if ok and fx ~= nil then table.insert(fxs, fx) end
            if #fxs >= 1 then break end
        end
    end
    if #fxs <= 0 then return nil end
    return fxs
end

function DotaKartItemSystem:UpdateSpectralDaggerProjectileFX(fxs, pos, dir, speed)
    if fxs == nil or ParticleManager == nil or pos == nil then return end
    dir = self:NormalizeDir2D(dir or Vector(1,0,0))
    for _, fx in ipairs(fxs or {}) do
        pcall(function()
            ParticleManager:SetParticleControl(fx, 0, pos)
            ParticleManager:SetParticleControl(fx, 1, pos)
            ParticleManager:SetParticleControl(fx, 2, Vector(0,0,0))
            ParticleManager:SetParticleControl(fx, 3, pos)
            ParticleManager:SetParticleControlForward(fx, 0, dir)
        end)
    end
end

function DotaKartItemSystem:DestroySpectralDaggerProjectileFX(fxs)
    if fxs == nil then return end
    for _, fx in ipairs(fxs or {}) do self:DestroyLinearParticle(fx, false) end
end

function DotaKartItemSystem:EmitSpectralDaggerSound(playerID, hero, soundDef, pos, extraPlayerID, isImpact)
    local sounds = self:NormalizeSoundList(soundDef)
    local origin = pos
    if origin == nil and DKValidUnit(hero) then origin = hero:GetAbsOrigin() end

    -- FIX95: o usuário confirmou os .vsnd nativos; tente primeiro o raw .vsnd e só depois aliases.
    local raw = isImpact == true and "sounds/weapons/hero/spectre/dagger_impact.vsnd" or "sounds/weapons/hero/spectre/dagger_cast.vsnd"
    local primary2d = isImpact == true and "dotakart_spectral_dagger_impact_2d" or "dotakart_spectral_dagger_cast_2d"
    local primary3d = isImpact == true and "dotakart_spectral_dagger_impact" or "dotakart_spectral_dagger_cast"

    local ordered = { raw, primary3d, primary2d }
    for _, s in ipairs(sounds) do table.insert(ordered, s) end

    local tried = {}
    local function trySound(soundName)
        if soundName == nil or soundName == "" or tried[soundName] == true then return end
        tried[soundName] = true
        if origin ~= nil and EmitSoundOnLocationWithCaster ~= nil then
            pcall(function() EmitSoundOnLocationWithCaster(origin, soundName, hero) end)
        end
        if StartSoundEventFromPosition ~= nil and origin ~= nil then
            pcall(function() StartSoundEventFromPosition(soundName, origin) end)
        end
        if DKValidUnit(hero) then
            pcall(function() EmitSoundOn(soundName, hero) end)
            pcall(function() StartSoundEvent(soundName, hero) end)
        end
    end

    for _, root in ipairs(ordered) do
        trySound(root)
        for _, alias in ipairs(self:GetUISoundAliases(root) or {}) do trySound(alias) end
    end

    -- Panorama fallback sem depender da distância/entidade; útil para o caster humano e vítima humana.
    local function ui(pid)
        if tonumber(pid) ~= nil then
            self:SendUISoundToPlayer(tonumber(pid), raw, "play", 0)
            self:SendUISoundToPlayer(tonumber(pid), primary2d, "play", 0)
            self:SendUISoundToPlayer(tonumber(pid), primary3d, "play", 0)
        end
    end
    ui(playerID)
    if extraPlayerID ~= nil and tonumber(extraPlayerID) ~= tonumber(playerID) then ui(extraPlayerID) end
end

function DotaKartItemSystem:AdvanceSpectralRouteIndex(route, preferBackward)
    local count = self:GetTrackPointCount()
    if count <= 0 or route == nil then return end
    if preferBackward == true then
        route.next_index = (tonumber(route.next_index or 1) or 1) - 1
        if route.next_index < 1 then route.next_index = count end
    else
        route.next_index = (tonumber(route.next_index or 1) or 1) + 1
        if route.next_index > count then route.next_index = 1 end
    end
end

function DotaKartItemSystem:GetSpectralRouteDirection(pos, targetPos, route, preferBackward)
    if pos == nil then return nil end
    local count = self:GetTrackPointCount()
    if count < 2 then
        if targetPos ~= nil then return self:NormalizeDir2D(targetPos - pos) end
        return nil
    end

    route = route or {}
    if route.next_index == nil then
        route.next_index = self:GetNearestTrackIndex(pos)
        self:AdvanceSpectralRouteIndex(route, preferBackward)
    end

    local arrive = 210
    local point = self:GetTrackPointWorld(route.next_index, nil)
    local guard = 0
    while point ~= nil and DKLength2D(pos, point) <= arrive and guard < 5 do
        self:AdvanceSpectralRouteIndex(route, preferBackward)
        point = self:GetTrackPointWorld(route.next_index, nil)
        guard = guard + 1
    end

    if point == nil then
        if targetPos ~= nil then return self:NormalizeDir2D(targetPos - pos) end
        return nil
    end
    return self:NormalizeDir2D(point - pos)
end

function DotaKartItemSystem:UseSpectralDagger(playerID, itemName, def)
    local caster = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(caster) then return false end

    local baseDir = self:GetForwardForPlayer(playerID, caster)
    local stInput = self:GetState(playerID)
    local backward = false
    if stInput ~= nil and stInput.input ~= nil then
        backward = stInput.input.reverse == true and stInput.input.forward ~= true
    end

    -- FIX107: atalho/manual agora é R + T. O campo continua chamado force_forward
    -- internamente para preservar compatibilidade com o controller/evento Panorama.
    local forceForward = self:GetSpectralForceForward(playerID)
    if forceForward then backward = false end
    if backward then baseDir = baseDir * -1 end
    baseDir = self:NormalizeDir2D(baseDir, caster:GetForwardVector())

    local ground = caster:GetAbsOrigin()
    local start = ground + baseDir * 155 + Vector(0, 0, 96)
    local pos = Vector(start.x, start.y, start.z)
    local speed = tonumber(def.speed) or 1200
    local range = tonumber(def.cast_range) or 2000
    local radius = tonumber(def.effect_radius or def.hit_radius) or 175
    local pathDuration = tonumber(def.path_duration) or 12.0
    local pathExpireTime = DKNow() + pathDuration

    local lockedTarget, lockedPlayerID = nil, -1
    if not forceForward then
        if backward == true then
            lockedTarget, lockedPlayerID = self:GetSpectralTargetOnePlaceBehind(playerID, caster, range)
        elseif self:GetPlaceForPlayer(playerID) > 1 then
            lockedTarget, lockedPlayerID = self:GetSpectralTargetOnePlaceAhead(playerID, caster, range)
        end
    end

    local hasLockedTarget = DKValidUnit(lockedTarget)
    local dir = baseDir
    if hasLockedTarget then
        dir = self:NormalizeDir2D((lockedTarget:GetAbsOrigin() + Vector(0,0,72)) - pos, baseDir)
    end

    local fx = self:CreateSpectralDaggerProjectileFX(def, pos, dir, speed)
    self:EmitSpectralDaggerSound(playerID, caster, def.sound_cast, start, nil, false)
    self:ConsumeHeldItem(playerID, itemName, def)

    -- Path Duration começa no uso do item. Todos os segmentos compartilham o mesmo expire time.
    self:SpawnSpectralPathSegment(playerID, ground, def, pathDuration, dir, pathExpireTime)

    local serial = self:NextProjectileSerial()
    local startTime = DKNow()
    local lastTime = startTime
    local traveled = 0
    local lastPathPos = Vector(pos.x, pos.y, pos.z)
    local pathSpacing = tonumber(def.path_segment_spacing) or 60
    local hitDone = false

    GameRules:GetGameModeEntity():SetContextThink("DotaKartSpectralDaggerThinker_" .. tostring(serial), function()
        if not DKValidUnit(caster) then
            self:DestroySpectralDaggerProjectileFX(fx)
            return nil
        end
        local now = DKNow()
        if now >= pathExpireTime then
            self:DestroySpectralDaggerProjectileFX(fx)
            return nil
        end

        local dt = math.max(0.001, math.min(0.05, now - lastTime))
        lastTime = now

        -- FIX107: sem rota de pista/waypoints. Se houver alvo válido, persegue diretamente.
        if hasLockedTarget then
            if not DKValidUnit(lockedTarget) or not self:IsHomingValidTarget(playerID, lockedPlayerID) then
                local decoy = tonumber(lockedPlayerID) and tonumber(lockedPlayerID) >= 0 and self:GetDoppelDecoyForOwner(lockedPlayerID) or nil
                if decoy ~= nil and DKValidUnit(decoy.unit) then
                    lockedTarget = decoy.unit
                    lockedPlayerID = decoy.target_id
                else
                    hasLockedTarget = false
                end
            end
            if hasLockedTarget then
                local targetPos = lockedTarget:GetAbsOrigin() + Vector(0, 0, 72)
                local desired = self:NormalizeDir2D(targetPos - pos, dir)
                local strength = DKClamp(def.homing_strength or 0.90, 0, 0.98)
                dir = self:NormalizeDir2D(dir * (1 - strength) + desired * strength, desired)
            end
        end

        local step = speed * dt
        traveled = traveled + step
        pos = pos + dir * step
        pos.z = GetGroundHeight(pos, nil) + 92
        self:UpdateSpectralDaggerProjectileFX(fx, pos, dir, speed)

        if DKLength2D(lastPathPos, pos) >= pathSpacing then
            lastPathPos = Vector(pos.x, pos.y, pos.z)
            self:SpawnSpectralPathSegment(playerID, pos, def, pathExpireTime - now, dir, pathExpireTime)
        end

        if self:BlockProjectileWithPowerCog(playerID, pos, radius * 0.90, "spectral_dagger_blocked") then
            self:DestroySpectralDaggerProjectileFX(fx)
            return nil
        end

        if self:HandleSpecialProjectileTargetHit(playerID,pos,radius,"spectral_dagger") then self:DestroySpectralDaggerProjectileFX(fx); return nil end
        local target, targetPlayerID = self:FindHeroHit(playerID, pos, radius)
        if DKValidUnit(target) and hitDone ~= true then
            hitDone = true
            self:ApplySpectralDaggerHit(caster, playerID, targetPlayerID, target, def, pathExpireTime)
            self:DestroySpectralDaggerProjectileFX(fx)
            return nil
        end

        if traveled >= range or (now - startTime) >= (tonumber(def.locked_lifetime) or 8.0) then
            self:DestroySpectralDaggerProjectileFX(fx)
            return nil
        end
        return 0.025
    end, 0.0)

    local mode = hasLockedTarget and (backward and "direct_homing_to_place_behind" or "direct_homing_to_place_ahead") or (backward and "backward_linear" or "forward_linear")
    print("[DotaKartItems] FIX107 Player " .. tostring(playerID) .. " usou SPECTRAL DAGGER mode=" .. tostring(mode) .. " force_forward_R=" .. tostring(forceForward) .. " target=" .. tostring(lockedPlayerID) .. " range=" .. tostring(range))
    return true
end

function DotaKartItemSystem:UpdateSpectralDaggerPaths(now)
    self.activeSpectralDaggerPaths = self.activeSpectralDaggerPaths or {}
    local alive = {}
    for _, seg in ipairs(self.activeSpectralDaggerPaths) do
        if seg ~= nil and now < (seg.expire_time or 0) then
            table.insert(alive, seg)
            for _, playerID in ipairs(self:GetRegisteredPlayerIDs()) do
                playerID = tonumber(playerID)
                if playerID ~= nil then
                    local hero = self:GetHeroForPlayer(playerID)
                    if DKValidUnit(hero) and DKLength2D(seg.pos, hero:GetAbsOrigin()) <= (seg.radius or 200) then
                        local def = self.itemDefs.item_dotakart_spectral_dagger or {}
                        if playerID == seg.owner then
                            self:SetSpectralPathBuff(playerID, def.path_buff_linger or 4.0, def.path_buff_bonus_pct or 0.10, def)
                        elseif (seg.hit_cd[playerID] or 0) <= now then
                            if not self:IsSpectralPathBuffed(playerID, now) then
                                self:ApplyKartSlow(nil, hero, tonumber(def.slow_refresh) or 0.30, tonumber(def.slow_pct) or 0.10, 0, 0.03)
                            end
                            seg.hit_cd[playerID] = now + 0.30
                        end
                    end
                end
            end
        else
            self:DestroySpectralPathSegment(seg)
        end
    end
    self.activeSpectralDaggerPaths = alive
end

function DotaKartItemSystem:PrintBoxes()
    print("[DotaKartItems] ===== CAIXAS REGISTRADAS =====")
    print("[DotaKartItems] total=" .. tostring(#self.boxes))
    for i, box in ipairs(self.boxes) do
        local p = box.ground_pos or box.pos or Vector(0,0,0)
        print("  #" .. tostring(i) .. " name=" .. tostring(box.name) .. " targetname=" .. tostring(box.targetname) .. " active=" .. tostring(box.active) .. " pos=" .. tostring(math.floor(p.x)) .. "," .. tostring(math.floor(p.y)) .. "," .. tostring(math.floor(p.z)))
    end
end

function DotaKartItemSystem:GetNearestBoxForPlayer(playerID)
    local hero = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(hero) then return nil, 999999 end

    local pos = hero:GetAbsOrigin()
    local nearest = nil
    local nearestDist = 999999

    for _, box in ipairs(self.boxes) do
        if box.active and box.pos ~= nil then
            local d = DKLength2D(pos, box.pos)
            if d < nearestDist then
                nearestDist = d
                nearest = box
            end
        end
    end

    return nearest, nearestDist
end

function DotaKartItemSystem:PrintNearestBox(playerID)
    playerID = tonumber(playerID) or 0
    local box, dist = self:GetNearestBoxForPlayer(playerID)
    if box == nil then
        print("[DotaKartItems] Nenhuma caixa ativa encontrada para player " .. tostring(playerID))
        return
    end
    print("[DotaKartItems] Caixa mais perto do player " .. tostring(playerID) .. ": " .. tostring(box.name) .. " dist=" .. tostring(math.floor(dist)) .. " radius=" .. tostring(self.config.pickup_radius))
end

function DotaKartItemSystem:ForcePickupNearest(playerID)
    playerID = tonumber(playerID) or 0
    local hero = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(hero) then
        print("[DotaKartItems] ForcePickup falhou: hero ausente player " .. tostring(playerID))
        return
    end

    local box, dist = self:GetNearestBoxForPlayer(playerID)
    if box == nil then
        print("[DotaKartItems] ForcePickup falhou: nenhuma caixa ativa")
        return
    end

    print("[DotaKartItems] ForcePickup player " .. tostring(playerID) .. " caixa=" .. tostring(box.name) .. " dist=" .. tostring(math.floor(dist)))
    self:OnPickupBox(playerID, hero, box)
end

function DotaKartItemSystem:OnThink()
    local now = DKNow()

    -- Atualiza roulette mesmo com sistema disabled para terminar a animacao de item.
    for playerID, roll in pairs(self.rolling) do
        self:UpdateRoulette(playerID, roll, now)
    end

    for playerID, charge in pairs(self.activeCharges or {}) do
        self:UpdateChargeOfDarkness(playerID, charge)
    end

    self:UpdatePowerCogs(now)
    self:UpdatePlagueWards(now)
    self:UpdateSwarmBeetles(now)
    self:UpdateDreamCoils(now)
    self:UpdateFrostShields(now)
    self:UpdateItemSteals(now)
    self:UpdateIceWalls(now)
    self:UpdateNatureGrasps(now)
    self:UpdateSpectralDaggerPaths(now)
    self:UpdateBattleHungers(now)
    self:UpdateXMarks(now)
    self:UpdateUnstableConcoctions(now)
    self:UpdateDoppelwalkDecoys(now)
    self:UpdateShukuchi(now)
    self:UpdateAstrals(now)
    self:UpdateBallLightning(now)
    self:UpdateStaticRemnants(now)
    self:UpdateCrystalClones(now)

    if self.enabled then
        for _, box in ipairs(self.boxes) do
            if not box.active and box.respawn_time ~= nil and box.respawn_time > 0 and now >= box.respawn_time then
                self:RespawnBox(box)
            end
        end
        self:CheckPickupCollisions(now)
    end

    return self.config.tick_rate
end

function DotaKartItemSystem:PrintItemTable()
    print("[DotaKartItems] ===== TABELA DE ITENS POR COLOCACAO FIX72 =====")
    local pools = self.itemPoolsByPlace or {}
    for place = 1, 8 do
        local pool = pools[place] or {}
        print("[DotaKartItems] Place " .. tostring(place))
        for _, entry in ipairs(pool) do
            local def = self.itemDefs[entry.item] or {}
            print("  - " .. tostring(entry.item) .. " | " .. tostring(def.label or "?") .. " | peso " .. tostring(entry.weight) .. " | " .. tostring(def.description or ""))
        end
    end
end


-- ============================================================
-- FIX19: Estrelinha/BKB
-- Invulnerável, imune a debuffs comuns e purga status negativos enquanto ativo.
-- ============================================================
modifier_dotakart_star = class({})

function modifier_dotakart_star:IsHidden() return false end
function modifier_dotakart_star:IsPurgable() return false end
function modifier_dotakart_star:RemoveOnDeath() return true end
function modifier_dotakart_star:GetTexture() return "item_black_king_bar" end

function modifier_dotakart_star:OnCreated(kv)
    if not IsServer() then return end
    self:StartIntervalThink(0.10)
end

function modifier_dotakart_star:OnIntervalThink()
    if not IsServer() then return end
    local parent = self:GetParent()
    if parent ~= nil and not parent:IsNull() then
        -- Remove stun/slow/root/silence e outros negativos enquanto a estrelinha está ativa.
        pcall(function()
            parent:Purge(false, true, false, true, true)
        end)
    end
end

function modifier_dotakart_star:CheckState()
    local state = {}
    if MODIFIER_STATE_INVULNERABLE ~= nil then state[MODIFIER_STATE_INVULNERABLE] = true end
    if MODIFIER_STATE_MAGIC_IMMUNE ~= nil then state[MODIFIER_STATE_MAGIC_IMMUNE] = true end
    if MODIFIER_STATE_DEBUFF_IMMUNE ~= nil then state[MODIFIER_STATE_DEBUFF_IMMUNE] = true end
    if MODIFIER_STATE_NO_UNIT_COLLISION ~= nil then state[MODIFIER_STATE_NO_UNIT_COLLISION] = true end
    return state
end

function modifier_dotakart_star:DeclareFunctions()
    local funcs = {}
    if MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING ~= nil then
        table.insert(funcs, MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING)
    end
    return funcs
end

function modifier_dotakart_star:GetModifierStatusResistanceStacking()
    return 100
end

-- ============================================================
-- FIX26: roleta de item via Panorama/UI.
-- A roleta troca imagens rapidamente por ~2.5s. O som "treasure_01" toca no final.
-- O som de spin é enviado como evento dedicado para o HUD, com fallback por aliases e repetição.
-- ============================================================
function DotaKartItemSystem:GetUISoundAliases(soundName)
    local aliases = {}
    local function add(v)
        if v == nil or v == "" then return end
        v = tostring(v)
        for _, x in ipairs(aliases) do
            if x == v then return end
        end
        table.insert(aliases, v)
    end

    soundName = tostring(soundName or "")
    add(soundName)
    local noExt = string.gsub(soundName, "%.vsnd$", "")
    add(noExt)
    local noSounds = string.gsub(noExt, "^sounds/", "")
    add(noSounds)
    add(string.gsub(noSounds, "/", "."))
    add(string.gsub(noSounds, "/", "_"))

    if string.find(soundName, "rylais_wheel_spin_02_lp", 1, true) or string.find(soundName, "rylais_wheel_spin_01_lp", 1, true) then
        add("ui.economy.rylais_wheel_spin_02_lp")
        add("economy.rylais_wheel_spin_02_lp")
        add("rylais_wheel_spin_02_lp")
        add("ui.economy.rylais_wheel_spin_01_lp")
        add("economy.rylais_wheel_spin_01_lp")
        add("rylais_wheel_spin_01_lp")
        add("Rylai.Wheel.Spin")
        add("Rylai_Wheel_Spin")
        add("UI.RylaiWheel.Spin")
    end

    if string.find(soundName, "mirana/leap", 1, true) or string.find(soundName, "mirana.leap", 1, true) then
        add("Hero_Mirana.Leap")
        add("Hero_Mirana.Leap.Cast")
        add("Hero_Mirana.Leap.Begin")
        add("Hero_Mirana.Leap1")
        add("Hero_Mirana.Leap2")
        add("Hero_Mirana.Leap3")
        add("Hero_Mirana.Leap4")
        add("Hero_Mirana.Leap.Start")
        add("Hero_Mirana.Leap.End")
        add("Ability.MiranaLeap")
        add("Mirana.Leap")
        add("mirana_leap")
        add("mirana.leap1")
        add("mirana.leap2")
        add("mirana.leap3")
        add("mirana.leap4")
    end

    -- FIX74: aliases do Burrowstrike. O raw .vsnd nem sempre toca direto;
    -- o soundevent customizado dotakart_burrowstrike_cast e os aliases do Sand King
    -- aumentam a chance de o som tocar tanto server-side quanto via Panorama.
    if string.find(soundName, "burrow", 1, true) or string.find(soundName, "sand_king", 1, true) or string.find(soundName, "SandKing", 1, true) or string.find(soundName, "Sandking", 1, true) then
        add("dotakart_burrowstrike_cast")
        add("Hero_SandKing.BurrowStrike")
        add("Hero_Sandking.BurrowStrike")
        add("Hero_SandKing.BurrowStrike.Target")
        add("Hero_Sandking.BurrowStrike.Target")
        add("Ability.SandKing_BurrowStrike")
        add("sand_king_burrow_attack")
    end

    if string.find(soundName, "treasure_01", 1, true) then
        add("ui.treasure_01")
        add("treasure_01")
        add("Treasure.Open")
        add("UI.Treasure.Open")
    end

    -- FIX39: aliases de sons do Lich para Frost Shield e Chain Frost.
    if string.find(soundName, "lich/frost_armor", 1, true) or string.find(soundName, "frost_armor", 1, true) then
        add("Hero_Lich.FrostArmor")
        add("Hero_Lich.FrostArmor.Cast")
        add("Hero_Lich.FrostArmorDamage")
        add("Hero_Lich.IceArmor")
        add("Hero_Lich.IceArmor.Cast")
        add("Hero_Lich.IceArmorDamage")
        add("Hero_Lich.FrostShield")
        add("Hero_Lich.FrostShield.Cast")
        add("Hero_Lich.FrostShield.Target")
        add("Hero_Lich.FrostShield.Pulse")
    end

    if string.find(soundName, "lich/chain_frost", 1, true) or string.find(soundName, "chain_frost", 1, true) then
        add("Hero_Lich.ChainFrost")
        add("Hero_Lich.ChainFrost.Cast")
        add("Hero_Lich.ChainFrostLoop")
        add("Hero_Lich.ChainFrost.Loop")
        add("Hero_Lich.ChainFrost.Projectile")
        add("Hero_Lich.ChainFrostImpact")
        add("Hero_Lich.ChainFrost.Impact")
        add("Hero_Lich.ChainFrost.Target")
    end


    -- FIX93: aliases robustos da Spectral Dagger. Primeiro os .vsnd confirmados
    -- pelo usuário no Asset Browser, depois soundevents custom/nativos.
    if string.find(soundName, "spectre/dagger", 1, true) or string.find(soundName, "dagger_cast", 1, true) or string.find(soundName, "dagger_impact", 1, true) or string.find(soundName, "spectral_dagger", 1, true) or string.find(soundName, "spectraldagger", 1, true) or string.find(soundName, "Spectre", 1, true) then
        add("sounds/weapons/hero/spectre/dagger_cast.vsnd")
        add("sounds/weapons/hero/spectre/dagger_impact.vsnd")
        add("weapons.hero.spectre.dagger_cast")
        add("weapons.hero.spectre.dagger_impact")
        add("dagger_cast")
        add("dagger_impact")
        add("dotakart_spectral_dagger_cast")
        add("dotakart_spectral_dagger_impact")
        add("Hero_Spectre.DaggerCast")
        add("Hero_Spectre.DaggerImpact")
        add("Hero_Spectre.SpectralDagger")
        add("Hero_Spectre.SpectralDagger.Cast")
        add("Hero_Spectre.SpectralDagger.Impact")
        add("Hero_Spectre.SpectralDagger.Target")
        add("Hero_Spectre.SpectralDagger.Projectile")
        add("Hero_Spectre.SpectralDagger.Loop")
        add("Ability.Spectre_SpectralDagger")
        add("Ability.SpectralDagger")
        add("Hero_Spectre.Dagger.Cast")
        add("Hero_Spectre.Dagger.Impact")
        add("spectre_dagger_cast")
        add("spectre_dagger_impact")
    end

    -- FIX102: aliases diretos dos sons customizados do DotA Kart, sem _c.
    if string.find(soundName, "dotakart_announcer_place_", 1, true) then
        local place = string.match(soundName, "dotakart_announcer_place_(%d+)")
        if place ~= nil then
            place = string.format("%02d", tonumber(place) or 1)
            add("sounds/vo_announcer_ann_custom_place_" .. place .. ".vsnd")
            add("vo_announcer_ann_custom_place_" .. place)
        end
    end
    if string.find(soundName, "vo_announcer_ann_custom_place_", 1, true) then
        local place = string.match(soundName, "place_(%d+)")
        if place ~= nil then
            place = string.format("%02d", tonumber(place) or 1)
            add("sounds/vo_announcer_ann_custom_place_" .. place .. ".vsnd")
            add("dotakart_announcer_place_" .. place)
            add("vo_announcer_ann_custom_place_" .. place)
        end
    end
    if string.find(soundName, "engine_idle", 1, true) or string.find(soundName, "dotakart_engine_idle", 1, true) then
        add("sounds/dotakart/kart engine/engine_idle.vsnd")
        add("dotakart_engine_idle")
        add("engine_idle")
    end

    return aliases
end

function DotaKartItemSystem:TryEmitUISoundServer(hero, soundName)
    local aliases = self:GetUISoundAliases(soundName)
    for _, s in ipairs(aliases) do
        pcall(function() EmitGlobalSound(s) end)
        if DKValidUnit(hero) then
            pcall(function() EmitSoundOn(s, hero) end)
            pcall(function() StartSoundEvent(s, hero) end)
        end
    end
end

function DotaKartItemSystem:TryStopUISoundServer(hero, soundName)
    -- FIX28: usado só para eventos realmente paráveis.
    -- Não tente StopSoundEvent em Rylai spin .vsnd: o Dota loga "non-existent soundevent" e o HUD já controla a duração.
    soundName = tostring(soundName or "")
    if string.find(soundName, "rylais_wheel_spin", 1, true) then return end
    local aliases = self:GetUISoundAliases(soundName)
    for _, s in ipairs(aliases) do
        if DKValidUnit(hero) then
            pcall(function() StopSoundOn(s, hero) end)
            pcall(function() StopSoundEvent(s, hero) end)
        end
    end
end

function DotaKartItemSystem:SendUISoundToPlayer(playerID, soundName, action, duration)
    if soundName == nil or soundName == "" then return end
    local payload = {
        sound = soundName,
        action = action or "play",
        duration = duration or 0
    }

    local player = nil
    if PlayerResource ~= nil and PlayerResource.GetPlayer ~= nil and tonumber(playerID) ~= nil then
        player = PlayerResource:GetPlayer(tonumber(playerID))
    end

    if player ~= nil then
        CustomGameEventManager:Send_ServerToPlayer(player, "dotakart_ui_sound", payload)
    elseif self.config and self.config.debug then
        print("[DotaKartItems] UI sound ignorado: player sem cliente " .. tostring(playerID) .. " sound=" .. tostring(soundName))
    end
end

function DotaKartItemSystem:SendRouletteEventToPlayer(playerID, phase, itemName, duration)
    local spinSounds = self:NormalizeSoundList(self.config and self.config.roulette_sound_loop or nil)
    local doneSounds = self:NormalizeSoundList(self.config and self.config.roulette_sound_done or nil)
    local payload = {
        phase = phase or "start",
        item = itemName or "",
        duration = tonumber(duration or 0) or 0,
        spin_sound = spinSounds[1] or "dotakart_itembox_spin_loop",
        done_sound = doneSounds[1] or "sounds/ui/treasure_01.vsnd"
    }

    local player = nil
    if PlayerResource ~= nil and PlayerResource.GetPlayer ~= nil and tonumber(playerID) ~= nil then
        player = PlayerResource:GetPlayer(tonumber(playerID))
    end

    if player ~= nil then
        CustomGameEventManager:Send_ServerToPlayer(player, "dotakart_roulette_fx", payload)
    elseif self.config and self.config.debug then
        print("[DotaKartItems] Roulette UI ignorada: player sem cliente " .. tostring(playerID))
    end
end
