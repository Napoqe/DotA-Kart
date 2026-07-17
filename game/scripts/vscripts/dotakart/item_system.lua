-- DotA Kart - item_system.lua
-- FIX51: local roulette sound, rear camera support hooks, Meat Hook pass-through, Green Shell Cogs tuning.
-- Caixa 3D: models/gameplay/breakingcrate_dest.vmdl
-- Animacoes: breakingcrate_idle, breakingcrate_dest_break_c, breakingcrate_dest_break_b, breakingcrate_dest_break

if DotaKartItemSystem == nil then
    DotaKartItemSystem = class({})
end

-- FIX19: modifiers dos itens reais do DotA Kart.
LinkLuaModifier("modifier_dotakart_star", "dotakart/item_system.lua", LUA_MODIFIER_MOTION_NONE)


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
        roulette_sound_loop = { "sounds/ui/economy/rylais_wheel_spin_01_lp.vsnd" },
        roulette_sound_done = { "sounds/ui/treasure_01.vsnd" },
        allow_pickup_when_holding_item = false
    }

    -- FIX22: Itens reais do DotA Kart.
    -- Os nomes continuam sendo itens reais do Dota para o DOTAItemImage mostrar ícone na HUD.
    self.itemDefs = {
        item_phase_boots = {
            label = "1 Nitro",
            description = "Um Nitro: impulso forte e curto. Some depois de usar.",
            icon_type = "custom",
            icon = "s2r://materials/items/nitro/nitro_1.vmat",
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
            description = "Dois Nitros independentes. Cada uso consome uma carga e muda o icone.",
            icon_type = "custom",
            icon = "s2r://materials/items/nitro/nitro_2.vmat",
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
            description = "Tres Nitros independentes. Cada uso consome uma carga e muda o icone: 3, 2, 1.",
            icon_type = "custom",
            icon = "s2r://materials/items/nitro/nitro_3.vmat",
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
            description = "15s invulneravel, imune a status, velocidade maxima, atravessa karts e atordoa quem colidir.",
            icon_type = "item",
            icon = "item_black_king_bar",
            kind = "star",
            quality = 6,
            duration = 15.0,
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
            description = "Salto em arco mais longo e alto. Percorre 950 unidades e ganha +8% de velocidade por 2s.",
            icon_type = "ability",
            icon = "mirana_leap",
            kind = "leap",
            quality = 3,
            distance = 950,
            speed = 1450,
            max_time = 0.66,
            arc_height = 380,
            move_speed_bonus_pct = 8,
            bonus_duration = 2.0,
            sound = {
                "sounds/weapons/hero/mirana/leap1.vsnd",
                "sounds/weapons/hero/mirana/leap2.vsnd",
                "sounds/weapons/hero/mirana/leap3.vsnd",
                "sounds/weapons/hero/mirana/leap4.vsnd"
            }
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
            shock_stun = 0.35,
            projectile_speed = 2300,
            projectile_range = 999999,
            max_active_projectiles = 15,
            bounce_radius = 105,
            bounce_cooldown = 0.10,
            cog_model = "models/heroes/rattletrap/rattletrap_cog.vmdl",
            sound_cast = { "sounds/weapons/hero/rattletrap/power_cogs.vsnd", "Hero_Rattletrap.Power_Cogs" },
            sound_impact = { "sounds/weapons/hero/rattletrap/power_cogs_impact.vsnd", "Hero_Rattletrap.Power_Cogs_Impact" }
        },
        item_wind_waker = {
            label = "Tornado",
            description = "Tornado em linha por 4000 unidades. Levanta karts atingidos por 3.5s e bloqueia itens/movimento.",
            icon_type = "ability",
            icon = "invoker_tornado",
            kind = "tornado",
            quality = 5,
            travel_distance = 4000,
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
            travel_distance = 1500,
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
            description = "Projétil teleguiado curto em arco. Range 1200. Stun aleatório de 1.5s a 6s ao acertar um kart.",
            icon_type = "ability",
            icon = "chaos_knight_chaos_bolt",
            kind = "chaos_bolt",
            quality = 5,
            cast_range = 1200,
            speed = 850,
            hit_radius = 155,
            homing_radius = 1400,
            homing_strength = 0.62,
            homing_front_dot = 0.05,
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
        item_shivas_guard = {
            label = "Frost Shield",
            description = "Escudo gelado por 8s. Pulsa a cada 1s em raio 600, causando slow de 35% por 0.5s.",
            icon_type = "ability",
            icon = "lich_frost_shield",
            kind = "frost_shield",
            quality = 4,
            duration = 8.0,
            pulse_radius = 600,
            pulse_interval = 1.0,
            pulse_slow_pct = 0.35,
            pulse_slow_duration = 0.5,
            particle_shield = "particles/units/heroes/hero_lich/lich_frost_armor.vpcf",
            -- FIX39: variante _c encontrada pelo usuário. Em alguns heróis ela aparece melhor que a versão base.
            particle_shield_c = "particles/units/heroes/hero_lich/lich_frost_armor_c.vpcf",
            particle_ice = "particles/units/heroes/hero_lich/lich_frost_armor_ice.vpcf",
            particle_ring = "particles/units/heroes/hero_lich/lich_frost_armor_ring.vpcf",
            -- FIX39: raw .vsnd + aliases. O site de sons do Lich confirma Frost Shield cast + target impact.
            sound_cast = {
                "sounds/weapons/hero/lich/frost_armor.vsnd",
                "sounds/weapons/hero/lich/frost_armor",
                "weapons/hero/lich/frost_armor",
                "Hero_Lich.FrostArmor",
                "Hero_Lich.FrostArmor.Cast",
                "Hero_Lich.IceArmor",
                "Hero_Lich.IceArmor.Cast",
                "Hero_Lich.FrostShield",
                "Hero_Lich.FrostShield.Cast",
                "Hero_Lich.FrostShield.Target"
            },
            sound_pulse = {
                "sounds/weapons/hero/lich/ice_age_target.vsnd",
                "sounds/weapons/hero/lich/frost_armor_damage.vsnd",
                "sounds/weapons/hero/lich/frost_armor_damage",
                "weapons/hero/lich/frost_armor_damage",
                "Hero_Lich.FrostArmorDamage",
                "Hero_Lich.IceArmorDamage",
                "Hero_Lich.FrostShield.Damage",
                "Hero_Lich.FrostShield.Tick",
                "Hero_Lich.FrostShield.Pulse",
                "Hero_Lich.FrostShield.Target"
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
    self.itemPools = {
        solo = {
            { item = "item_phase_boots", weight = 30 },
            { item = "item_yasha", weight = 24 },
            { item = "item_mask_of_madness", weight = 18 },
            { item = "item_force_staff", weight = 16 },
            { item = "item_blink", weight = 13 },
            { item = "item_hurricane_pike", weight = 13 },
            { item = "item_gungir", weight = 10 },
            { item = "item_cyclone", weight = 12 },
            { item = "item_orb_of_venom", weight = 10 },
            { item = "item_blade_mail", weight = 9 },
            { item = "item_wind_waker", weight = 7 },
            { item = "item_mage_slayer", weight = 8 },
            { item = "item_spell_steal", weight = 8 },
            { item = "item_basher", weight = 8 },
            { item = "item_glimmer_cape", weight = 8 },
            { item = "item_kaya", weight = 8 },
            { item = "item_shivas_guard", weight = 10 },
            { item = "item_sheepstick", weight = 7 },
            { item = "item_black_king_bar", weight = 8 }
        },
        front = {
            { item = "item_phase_boots", weight = 54 },
            { item = "item_yasha", weight = 20 },
            { item = "item_mask_of_madness", weight = 10 },
            { item = "item_force_staff", weight = 10 },
            { item = "item_blink", weight = 5 },
            { item = "item_hurricane_pike", weight = 4 },
            { item = "item_gungir", weight = 1 },
            { item = "item_cyclone", weight = 4 },
            { item = "item_orb_of_venom", weight = 8 },
            { item = "item_blade_mail", weight = 8 },
            { item = "item_wind_waker", weight = 2 },
            { item = "item_mage_slayer", weight = 7 },
            { item = "item_spell_steal", weight = 4 },
            { item = "item_basher", weight = 3 },
            { item = "item_glimmer_cape", weight = 5 },
            { item = "item_kaya", weight = 6 },
            { item = "item_shivas_guard", weight = 9 },
            { item = "item_sheepstick", weight = 1 },
            { item = "item_black_king_bar", weight = 1 }
        },
        middle = {
            { item = "item_phase_boots", weight = 28 },
            { item = "item_yasha", weight = 22 },
            { item = "item_mask_of_madness", weight = 18 },
            { item = "item_force_staff", weight = 17 },
            { item = "item_blink", weight = 14 },
            { item = "item_hurricane_pike", weight = 13 },
            { item = "item_gungir", weight = 10 },
            { item = "item_cyclone", weight = 12 },
            { item = "item_orb_of_venom", weight = 13 },
            { item = "item_blade_mail", weight = 12 },
            { item = "item_wind_waker", weight = 10 },
            { item = "item_mage_slayer", weight = 12 },
            { item = "item_spell_steal", weight = 11 },
            { item = "item_basher", weight = 11 },
            { item = "item_glimmer_cape", weight = 10 },
            { item = "item_kaya", weight = 12 },
            { item = "item_shivas_guard", weight = 13 },
            { item = "item_sheepstick", weight = 9 },
            { item = "item_shadow_blade", weight = 9 },
            { item = "item_black_king_bar", weight = 8 }
        },
        back = {
            { item = "item_phase_boots", weight = 10 },
            { item = "item_yasha", weight = 18 },
            { item = "item_mask_of_madness", weight = 22 },
            { item = "item_force_staff", weight = 19 },
            { item = "item_blink", weight = 18 },
            { item = "item_hurricane_pike", weight = 15 },
            { item = "item_gungir", weight = 14 },
            { item = "item_cyclone", weight = 17 },
            { item = "item_orb_of_venom", weight = 15 },
            { item = "item_blade_mail", weight = 15 },
            { item = "item_wind_waker", weight = 14 },
            { item = "item_mage_slayer", weight = 14 },
            { item = "item_spell_steal", weight = 16 },
            { item = "item_basher", weight = 14 },
            { item = "item_glimmer_cape", weight = 14 },
            { item = "item_kaya", weight = 16 },
            { item = "item_shivas_guard", weight = 16 },
            { item = "item_sheepstick", weight = 18 },
            { item = "item_shadow_blade", weight = 20 },
            { item = "item_black_king_bar", weight = 18 }
        }
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
        pos = visualPos,
        ground_pos = Vector(pos.x, pos.y, pos.z),
        yaw = yaw or 0,
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
        box.ent:SetAbsOrigin(box.pos)
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

function DotaKartItemSystem:RollItemForPlayer(playerID)
    local poolName = self:GetPoolNameForPlayer(playerID)
    local pool = self.itemPools[poolName] or self.itemPools.solo
    local place = self:GetPlaceForPlayer(playerID)

    -- Charge of Darkness nunca deve sair para o primeiro colocado.
    for _ = 1, 16 do
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
        sound_hero = hero,
        ui_started = true
    }

    -- FIX26: a roleta gira por ~2.5s, troca imagens rápido e pede som de spin no HUD.
    self:SendRouletteEventToPlayer(playerID, "start", finalItem, self.config.roulette_duration or 2.5)

    -- FIX51: som da roleta fica local no Panorama do jogador que pegou a caixa.

    if self.config.debug then
        print("[DotaKartItems] FIX27 Roulette player " .. tostring(playerID) .. " pool=" .. tostring(poolName) .. " final=" .. tostring(finalItem) .. " duration=" .. tostring(self.config.roulette_duration))
    end
end

function DotaKartItemSystem:UpdateRoulette(playerID, roll, now)
    if roll == nil then return end

    if now >= roll.end_time then
        self.rolling[playerID] = nil
        local hero = roll.sound_hero or self:GetHeroForPlayer(playerID)
        -- FIX28: não tentar parar Rylai spin por string/soundevent inexistente.
        -- O HUD para visualmente e toca treasure_01 no final.
        self:GiveItemToPlayer(playerID, roll.final_item, true)
        self:SendRouletteEventToPlayer(playerID, "done", roll.final_item, 0)
        -- FIX51: som de item escolhido toca apenas no cliente desse jogador via dotakart_roulette_fx.
        -- Não toca EmitGlobalSound/EmitKartSound aqui para evitar todos ouvirem na partida.
        return
    end

    if now >= (roll.next_tick or 0) then
        roll.next_tick = now + self.config.roulette_step
        local pool = self.itemPools[roll.pool_name] or self.itemPools.solo
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
    -- FIX39: toca por servidor, global fallback e Panorama local. Mantém feedback mesmo se um modo ignorar raw .vsnd.
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

function DotaKartItemSystem:FindHeroHit(casterPlayerID, projectilePos, radius)
    for _, playerID in ipairs(self:GetRegisteredPlayerIDs()) do
        if playerID ~= casterPlayerID then
            local hero = self:GetHeroForPlayer(playerID)
            if DKValidUnit(hero) and not self:IsPlayerStarActive(playerID) and not self:IsPlayerInvisible(playerID) then
                if self:LinePointHit(projectilePos, hero:GetAbsOrigin(), radius) then
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

    local dur = math.max(0.05, tonumber(duration) or 0.5)
    local targetPlayerID = self:GetPlayerIDForHero(target)

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
        if self:IsPlayerStarActive(targetPlayerID) then return nil end

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

    self:LockKart(playerID, 1.0)
    self:EmitKartSound(caster, def.sound_impact)
    if def ~= nil and def.particle_impact ~= nil then
        self:CreateWorldParticle(def.particle_impact, target:GetAbsOrigin() + Vector(0,0,96), 0.75)
    end

    GameRules:GetGameModeEntity():SetContextThink("DotaKartHookshotPull_" .. tostring(serial), function()
        if not DKValidUnit(caster) or not DKValidUnit(target) then return nil end
        local casterPos = caster:GetAbsOrigin()
        local targetPos = target:GetAbsOrigin()
        local toTarget = targetPos - casterPos
        toTarget.z = 0
        local dist = math.sqrt(toTarget.x * toTarget.x + toTarget.y * toTarget.y)

        if dist <= 135 then
            self:LockKart(playerID, 0.15)
            self:ApplyMiniStun(caster, target, stunDuration or 0.85)
            self:EmitKartSound(target, def.sound_damage)
            self:EmitKartSound(caster, def.sound_retract)
            return nil
        end

        local dir = toTarget / math.max(1, dist)
        local step = math.min(dist, speedValue * 0.03)
        local nextPos = casterPos + dir * step
        nextPos.z = GetGroundHeight(nextPos, caster)
        caster:SetAbsOrigin(nextPos)
        self:LockKart(playerID, 0.12)
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
    local distance = tonumber(def.distance) or 700
    local speed = tonumber(def.speed) or 1300
    local maxTime = tonumber(def.max_time) or (distance / math.max(1, speed))
    local startTime = DKNow()
    local endPos = start + dir * distance
    local serial = self:NextProjectileSerial()

    self:EmitLeapSound(playerID, caster, def.sound, start)
    self:ConsumeHeldItem(playerID, itemName, def)

    if st ~= nil then
        local now = DKNow()
        local bonusDuration = tonumber(def.bonus_duration) or 2.0
        st.item_max_speed_until = math.max(st.item_max_speed_until or 0, now + bonusDuration)
        st.item_max_speed = math.max(st.item_max_speed or 0, (self.controller and self.controller.config and self.controller.config.max_speed or 720) * (1 + ((def.move_speed_bonus_pct or 8) / 100)))
        st.speed = math.max(st.speed or 0, math.min(st.item_max_speed or 780, (st.speed or 0) + 220))
        st.locked_until = math.max(st.locked_until or 0, now + maxTime)
    end

    GameRules:GetGameModeEntity():SetContextThink("DotaKartLeap_" .. tostring(serial), function()
        if not DKValidUnit(caster) then return nil end
        local now = DKNow()
        local t = math.min(1.0, (now - startTime) / math.max(0.01, maxTime))
        local p = start + (endPos - start) * t
        local groundZ = GetGroundHeight(p, caster)
        local arcHeight = tonumber(def.arc_height) or 260
        -- FIX22: arco real do Leap. O herói/kart sobe no ar e cai no fim.
        p.z = groundZ + math.sin(math.pi * t) * arcHeight
        caster:SetAbsOrigin(p)
        if t >= 1.0 then
            local finalPos = endPos
            finalPos.z = GetGroundHeight(finalPos, caster)
            caster:SetAbsOrigin(finalPos)
            pcall(function() FindClearSpaceForUnit(caster, finalPos, true) end)
            return nil
        end
        return 0.03
    end, 0.03)

    print("[DotaKartItems] Player " .. tostring(playerID) .. " usou LEAP " .. (backward and "para tras" or "para frente"))
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

        for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
            if tonumber(otherID) ~= tonumber(playerID) and hitPlayers[otherID] ~= true then
                local other = self:GetHeroForPlayer(otherID)
                if DKValidUnit(other) and not self:IsPlayerStarActive(otherID) and DKLength2D(p, other:GetAbsOrigin()) <= radius then
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
    local forwardBlocked = self:IsProjectileBlockedByWorld(pos + dir * radius, radius)
    local rightBlocked = self:IsProjectileBlockedByWorld(pos + right * radius, radius)
    local leftBlocked = self:IsProjectileBlockedByWorld(pos - right * radius, radius)

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

function DotaKartItemSystem:CheckCogProjectileCollision(ownerPlayerID, cog, pos, radius)
    -- Projéteis de Power Cogs se anulam ao colidir com outro projétil de Cog.
    if self.activeCogProjectiles == nil or cog == nil or pos == nil then return false end
    radius = tonumber(radius) or 115
    for _, e in ipairs(self.activeCogProjectiles) do
        local other = e.cog
        if other ~= nil and other ~= cog and other.active == true and other.launched == true and other.pos ~= nil then
            if DKLength2D(pos, other.pos) <= radius then
                cog.active = false
                other.active = false
                self:RemoveCogVisual(cog)
                self:RemoveCogVisual(other)
                self:UnregisterCogProjectile(cog)
                self:UnregisterCogProjectile(other)
                if e.owner ~= nil then self:UpdatePowerCogsHUD(e.owner) end
                if ownerPlayerID ~= nil then self:UpdatePowerCogsHUD(ownerPlayerID) end
                return true
            end
        end
    end
    return false
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
    if self:IsPlayerStarActive(targetPlayerID) then return end
    cog.active = false
    self:UnregisterCogProjectile(cog)
    -- FIX39: impacto em herói usa arquivos específicos hero01/02/03/lf + fallback genérico.
    self:EmitKartSound(target, def.sound_impact, target:GetAbsOrigin())
    local impactSounds = self:NormalizeSoundList(def.sound_impact)
    if #impactSounds > 0 then
        self:TryEmitUISoundServer(target, impactSounds[DKRandomInt(1, #impactSounds)])
    end
    self:PushKartAwayFromPoint(cog.pos or target:GetAbsOrigin(), targetPlayerID, target, def.shock_push or 520, def.shock_stun or 0.35)
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
    cog.launched = true
    cog.owner = playerID
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
        local dt = 0.03
        local step = speed * dt
        local oldPos = Vector(pos.x, pos.y, pos.z)
        local nextPos = pos + dir * step
        nextPos.z = GetGroundHeight(nextPos, nil)

        -- FIX51: estilo Green Shell. Ao bater em árvore/terreno bloqueado, ricocheteia
        -- em vez de sumir. Só quebra ao acertar jogador, outro projétil ou pelo limite global.
        if self:IsProjectileBlockedByWorld(nextPos, bounceRadius, playerID) then
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

        if self:CheckCogProjectileCollision(playerID, cog, pos, radius * 0.85) then
            return nil
        end

        for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
            if tonumber(otherID) ~= tonumber(playerID) then
                local other = self:GetHeroForPlayer(otherID)
                if DKValidUnit(other) and DKLength2D(pos, other:GetAbsOrigin()) <= radius then
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

function DotaKartItemSystem:AddFrostShieldPersistentVFX(caster, def, data)
    if not DKValidUnit(caster) then return end
    data.fxs = data.fxs or {}
    local radius = tonumber(def.pulse_radius) or 600

    local function append(list)
        for _, fx in ipairs(list or {}) do
            table.insert(data.fxs, fx)
        end
    end

    append(self:CreateAttachedParticleRobust(def.particle_shield, caster, nil, radius))
    append(self:CreateAttachedParticleRobust(def.particle_shield_c, caster, nil, radius))
    append(self:CreateAttachedParticleRobust(def.particle_ice, caster, nil, 240))

    -- FIX39: fallback persistente que segue o kart atualizando CPs manualmente.
    self:CreateFrostWorldFollowParticle(def.particle_shield, caster, data, radius, 72)
    self:CreateFrostWorldFollowParticle(def.particle_shield_c, caster, data, radius, 72)
    self:CreateFrostWorldFollowParticle(def.particle_ring, caster, data, radius, 18)

    -- Fallback visual inicial.
    local pos = caster:GetAbsOrigin()
    self:CreateWorldParticle(def.particle_shield, pos + Vector(0,0,72), 1.2)
    self:CreateWorldParticle(def.particle_shield_c, pos + Vector(0,0,72), 1.2)
    self:CreateWorldParticle(def.particle_ice, pos + Vector(0,0,72), 1.2)
    self:CreateRadiusWorldParticle(def.particle_ring, pos + Vector(0,0,18), radius, 1.0)
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
        -- FIX38: recria um brilho curto a cada 0.25s para garantir feedback visual mesmo se o particle persistente não aparecer.
        next_visual = now + 0.05,
        fxs = {}
    }

    self.activeFrostShields[playerID] = data
    self:AddFrostShieldPersistentVFX(caster, def, data)
    self:EmitFrostShieldSound(playerID, caster, def.sound_cast, caster:GetAbsOrigin())
    self:ConsumeHeldItem(playerID, itemName, def)
    print("[DotaKartItems] FIX39 Player " .. tostring(playerID) .. " ativou FROST SHIELD por " .. tostring(duration) .. "s")
    return true
end

function DotaKartItemSystem:FrostShieldVisualTick(playerID, data, now)
    local caster = data.caster or self:GetHeroForPlayer(playerID)
    local def = data.def or self.itemDefs.item_shivas_guard or {}
    if not DKValidUnit(caster) then return end
    local pos = caster:GetAbsOrigin()

    -- Atualiza particles persistentes world-follow e cria brilho leve. Não depende de attach_hitloc.
    self:UpdateFrostWorldFollowParticles(caster, data)
    if def.particle_ice ~= nil then
        self:CreateWorldParticle(def.particle_ice, pos + Vector(0,0,72), 0.35)
    end
    if def.particle_shield_c ~= nil then
        self:CreateWorldParticle(def.particle_shield_c, pos + Vector(0,0,72), 0.35)
    end
end

function DotaKartItemSystem:FrostShieldPulse(playerID, data, now)
    local caster = data.caster or self:GetHeroForPlayer(playerID)
    local def = data.def or self.itemDefs.item_shivas_guard or {}
    if not DKValidUnit(caster) then return end

    local casterPos = caster:GetAbsOrigin()
    local radius = tonumber(def.pulse_radius) or 600
    local hitCount = 0

    -- Ring visível a cada pulso mesmo quando não há inimigo dentro do raio.
    self:UpdateFrostWorldFollowParticles(caster, data)
    self:CreateRadiusWorldParticle(def.particle_ring, casterPos + Vector(0, 0, 18), radius, 0.85)
    self:CreateWorldParticle(def.particle_shield, casterPos + Vector(0,0,72), 0.65)
    self:CreateWorldParticle(def.particle_shield_c, casterPos + Vector(0,0,72), 0.65)
    self:CreateWorldParticle(def.particle_ice, casterPos + Vector(0,0,72), 0.65)
    self:EmitFrostShieldSound(playerID, caster, def.sound_pulse, casterPos)

    for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
        if tonumber(otherID) ~= tonumber(playerID) then
            local other = self:GetHeroForPlayer(otherID)
            if DKValidUnit(other) and not self:IsPlayerStarActive(otherID) and DKLength2D(casterPos, other:GetAbsOrigin()) <= radius then
                hitCount = hitCount + 1
                self:ApplyKartSlow(caster, other, def.pulse_slow_duration or 0.5, def.pulse_slow_pct or 0.35, 0, 0.03)
                self:EmitFrostShieldSound(otherID, other, def.sound_pulse, other:GetAbsOrigin())
                self:CreateDebuffVictimVisual(other, def, "frost", def.pulse_slow_duration or 0.5)
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
                data.next_visual = now + 0.25
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
    if candidateID < 0 then return false end
    if candidateID == tonumber(casterPlayerID) then return false end
    if excludeImmediateID ~= nil and candidateID == tonumber(excludeImmediateID) then return false end
    if self:IsPlayerStarActive(candidateID) then return false end
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

    return bestHero, bestPlayerID
end

function DotaKartItemSystem:ChainFrostImpact(casterPlayerID, caster, targetPlayerID, target, remainingBounces, def)
    if not DKValidUnit(caster) or not DKValidUnit(target) then return end
    if self:IsPlayerStarActive(targetPlayerID) then return end

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
    local target = self:GetHeroForPlayer(targetPlayerID)
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
        target = self:GetHeroForPlayer(targetPlayerID)
        if not DKValidUnit(caster) then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            return nil
        end

        if not DKValidUnit(target) or self:IsPlayerStarActive(targetPlayerID) then
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
            self:ChainFrostImpact(casterPlayerID, caster, targetPlayerID, target, remainingBounces, def)
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
            if DKValidUnit(hero) and not self:IsPlayerStarActive(playerID) and not self:IsPlayerInvisible(playerID) then
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
            if DKValidUnit(other) and not self:IsPlayerStarActive(otherID) and not self:IsPlayerInvisible(otherID) then
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
    if self:IsPlayerStarActive(targetPlayerID) then return end

    local casterPos = caster:GetAbsOrigin()
    local targetPos = target:GetAbsOrigin()
    local newCaster = Vector(targetPos.x, targetPos.y, GetGroundHeight(targetPos, caster))
    local newTarget = Vector(casterPos.x, casterPos.y, GetGroundHeight(casterPos, target))

    caster:SetAbsOrigin(newCaster)
    target:SetAbsOrigin(newTarget)
    pcall(function() FindClearSpaceForUnit(caster, newCaster, true) end)
    pcall(function() FindClearSpaceForUnit(target, newTarget, true) end)

    if self.controller ~= nil and self.controller.SetKartLocked ~= nil then
        self.controller:SetKartLocked(casterPlayerID, 0.15)
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

        if not DKValidUnit(lockedTarget) or self:IsPlayerStarActive(lockedPlayerID) then
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

        -- Obstáculos/árvores anulam o efeito. Ignora os primeiros metros para não bater no próprio caster.
        if traveled > 220 and self:IsProjectileBlockedByWorld(pos, def.obstacle_check_radius or 90) then
            if missileFx ~= nil then self:DestroyLinearParticle(missileFx, false) end
            if self.config and self.config.debug then
                print("[DotaKartItems] Swap Missile bateu em obstaculo/arvore e foi anulado.")
            end
            return nil
        end

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
            if DKValidUnit(other) and not self:IsPlayerStarActive(otherID) then
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
    if targetID < 0 or not DKValidUnit(target) then
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
    if held == "item_blade_mail" and self.ClearPowerCogs ~= nil then
        self:ClearPowerCogs(playerID, reason or "item_steal")
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

function DotaKartItemSystem:FindRandomItemStealVictim(casterPlayerID)
    local candidates = {}
    for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
        if tonumber(otherID) ~= tonumber(casterPlayerID) then
            local hero = self:GetHeroForPlayer(otherID)
            local held = self:GetHeldItem(otherID)
            if DKValidUnit(hero) and self:IsStealableHeldItem(held) and self.rolling[otherID] == nil then
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
    data.complete_time = now + (tonumber(def.steal_delay) or 2.0)

    self:SetSpellStealTemporaryIcon(playerID, data.complete_time)
    self:ClearHeldItemForSteal(victim.playerID, "stolen_pending")
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

    if self:IsStealableHeldItem(stolenItem) then
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
                if st ~= nil then st.speed = 0 end
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

        for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
            if tonumber(otherID) ~= tonumber(playerID) and hitPlayers[otherID] ~= true then
                local other = self:GetHeroForPlayer(otherID)
                if DKValidUnit(other) and not self:IsPlayerStarActive(otherID) and DKLength2D(pos, other:GetAbsOrigin()) <= radius then
                    hitPlayers[otherID] = true
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
    local speed = tonumber(def.speed) or 850
    local range = tonumber(def.cast_range) or 1000
    local radius = tonumber(def.hit_radius) or 155
    local minStun = tonumber(def.min_stun) or 1.5
    local maxStun = tonumber(def.max_stun) or 6.0
    local arcHeight = tonumber(def.arc_height) or 210
    local frontDot = tonumber(def.homing_front_dot) or 0.05
    local lockedTarget, lockedPlayerID = self:FindNearestEnemyKartInArc(playerID, start, dir, def.homing_radius or range, frontDot)

    if def.particle_launch ~= nil then self:CreateWorldParticle(def.particle_launch, start, 0.8) end
    local fx = self:CreateMissileParticle(def.particle, pos, dir, speed, 420)
    self:EmitKartSound(caster, def.sound_cast, start)
    self:ConsumeHeldItem(playerID, itemName, def)

    local serial = self:NextProjectileSerial()
    local startTime = DKNow()
    local lastTime = startTime
    local traveled = 0
    local maxTime = range / math.max(1, speed) + 0.35

    GameRules:GetGameModeEntity():SetContextThink("DotaKartChaosBolt_" .. tostring(serial), function()
        if not DKValidUnit(caster) then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            return nil
        end
        local now = DKNow()
        local dt = math.max(0.001, math.min(0.05, now - lastTime))
        lastTime = now

        if not DKValidUnit(lockedTarget) or not self:IsHomingValidTarget(playerID, lockedPlayerID) then
            lockedTarget, lockedPlayerID = self:FindNearestEnemyKartInArc(playerID, pos, dir, def.homing_radius or range, frontDot)
        end
        if DKValidUnit(lockedTarget) then
            local targetPos = lockedTarget:GetAbsOrigin() + Vector(0,0,88)
            local desired = self:NormalizeDir2D(targetPos - pos)
            local strength = DKClamp(def.homing_strength or 0.62, 0, 0.90)
            dir = self:NormalizeDir2D(dir * (1 - strength) + desired * strength)
        end

        local step = speed * dt
        traveled = traveled + step
        local t = DKClamp(traveled / math.max(1, range), 0, 1)
        pos = pos + dir * step
        pos.z = GetGroundHeight(pos, nil) + 96 + math.sin(t * math.pi) * arcHeight
        self:UpdateMissileParticle(fx, pos, dir, speed, 420)

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

        if traveled >= range or (now - startTime) >= maxTime then
            if fx ~= nil then self:DestroyLinearParticle(fx, false) end
            return nil
        end
        return 0.03
    end, 0.03)

    print("[DotaKartItems] Player " .. tostring(playerID) .. " lançou CHAOS BOLT " .. (backward and "para tras" or "para frente"))
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
                    for _, otherID in ipairs(self:GetRegisteredPlayerIDs()) do
                        if tonumber(otherID) ~= tonumber(playerID) and not self:IsPlayerStarActive(otherID) then
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
    end

    return false
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
    self:UpdateFrostShields(now)
    self:UpdateItemSteals(now)
    self:UpdateIceWalls(now)

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
    print("[DotaKartItems] ===== TABELA DE ITENS POR CLASSIFICACAO =====")
    for poolName, pool in pairs(self.itemPools) do
        print("[DotaKartItems] Pool: " .. tostring(poolName))
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
    local payload = {
        phase = phase or "start",
        item = itemName or "",
        duration = tonumber(duration or 0) or 0,
        spin_sound = "sounds/ui/economy/rylais_wheel_spin_01_lp.vsnd",
        done_sound = "sounds/ui/treasure_01.vsnd"
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
