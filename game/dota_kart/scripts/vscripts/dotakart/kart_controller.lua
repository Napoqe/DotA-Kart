-- DotA Kart - kart_controller.lua
-- FIX51: hook pass-through collision exception + Green Shell support.
-- W = acelerar, S = ré/freio, A = virar esquerda, D = virar direita, T = usar item.
-- Movimento é feito pelo servidor com SetAbsOrigin, sem enviar ordens Move/Stop a cada tick.

if DotaKartController == nil then
    DotaKartController = class({})
end

-- FIX25: modifier real para desarmar herói/kart e impedir auto-attack/facing automático.
LinkLuaModifier("modifier_dotakart_kart_controlled", "dotakart/kart_controller.lua", LUA_MODIFIER_MOTION_NONE)

local function DKClamp(v, a, b)
    v = tonumber(v) or 0
    if v < a then return a end
    if v > b then return b end
    return v
end

local function DKApproach(current, target, delta)
    if current < target then
        current = current + delta
        if current > target then current = target end
    elseif current > target then
        current = current - delta
        if current < target then current = target end
    end
    return current
end

local function DKAtan2(y, x)
    if math.atan2 ~= nil then
        return math.atan2(y, x)
    end

    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        return math.pi / 2
    elseif x == 0 and y < 0 then
        return -math.pi / 2
    end

    return 0
end

local function DKNormalizeYaw(yaw)
    yaw = tonumber(yaw) or 0
    yaw = yaw % 360
    if yaw > 180 then yaw = yaw - 360 end
    if yaw < -180 then yaw = yaw + 360 end
    return yaw
end

local function DKBool(v)
    return v == true or v == 1 or v == "1" or v == "true"
end

local function DKValidUnit(unit)
    return unit ~= nil and not unit:IsNull()
end

local function DKNow()
    return GameRules:GetGameTime()
end

local function DKLength2DVec(v)
    if v == nil then return 0 end
    return math.sqrt((v.x or 0) * (v.x or 0) + (v.y or 0) * (v.y or 0))
end

local function DKDistance2DPos(a, b)
    if a == nil or b == nil then return 999999 end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

local function DKNormalize2DVec(v, fallback)
    local len = DKLength2DVec(v)
    if len <= 0.001 then return fallback or Vector(1, 0, 0) end
    return Vector((v.x or 0) / len, (v.y or 0) / len, 0)
end

local function DKGetPlayerIDFromEvent(eventSourceIndex, keys)
    -- CustomGameEvent pode chegar como número, HScript ou nil dependendo do contexto/hot reload.
    -- Nunca chame EntIndexToHScript em HScript, pois gera: expected integer but got hscript.
    if keys ~= nil then
        local pid = tonumber(keys.PlayerID or keys.player_id or keys.playerID)
        if pid ~= nil and pid >= 0 then
            return pid
        end
    end

    if eventSourceIndex ~= nil then
        if type(eventSourceIndex) == "number" then
            local ok, player = pcall(EntIndexToHScript, eventSourceIndex)
            if ok and player ~= nil and not player:IsNull() and player.GetPlayerID ~= nil then
                local pid = player:GetPlayerID()
                if pid ~= nil and pid >= 0 then
                    return pid
                end
            end
        elseif eventSourceIndex.GetPlayerID ~= nil then
            local pid = eventSourceIndex:GetPlayerID()
            if pid ~= nil and pid >= 0 then
                return pid
            end
        end
    end

    return -1
end

local function DKBuildBlockedOrders()
    local t = {}
    local names = {
        "DOTA_UNIT_ORDER_MOVE_TO_POSITION",
        "DOTA_UNIT_ORDER_MOVE_TO_TARGET",
        "DOTA_UNIT_ORDER_ATTACK_MOVE",
        "DOTA_UNIT_ORDER_ATTACK_TARGET",
        "DOTA_UNIT_ORDER_CAST_POSITION",
        "DOTA_UNIT_ORDER_CAST_TARGET",
        "DOTA_UNIT_ORDER_CAST_TARGET_TREE",
        "DOTA_UNIT_ORDER_CAST_NO_TARGET"
    }

    for _, name in ipairs(names) do
        local value = _G[name]
        if value ~= nil then
            t[value] = true
        end
    end

    return t
end

local DK_BLOCKED_ORDERS = DKBuildBlockedOrders()

function DotaKartController:Init(hud)
    if self.initialized then return end
    self.initialized = true

    self.hud = hud or GameRules.DotaKartHUD
    self.enabled = true
    self.states = {}
    self.heroes = {}
    self.heldItems = {}
    self._thinkStarted = false
    self._lastThinkTime = DKNow()

    self.config = {
        debug = false,
        tick_rate = 0.03,

        -- Ajustes principais de controle.
        -- FIX30: velocidade normal maior, sem depender de item.
        max_speed = 880,
        boost_max_speed = 1250,
        reverse_max_speed = 300,
        acceleration = 820,
        brake_acceleration = 1450,
        reverse_acceleration = 560,
        friction = 540,
        turn_rate = 150,
        min_turn_speed = 55,
        turn_at_zero_factor = 0.20,

        -- Ajustes de sensação/estabilidade.
        ground_z_offset = 0,
        stop_dota_orders_interval = 9999, -- FIX15: nao envia Stop em loop
        resolve_collision_interval = 0.18,
        no_unit_collision = true,
        block_default_move_orders = true,
        disable_auto_attack = true,
        set_no_attack_capability = true,
        start_with_test_item = false, -- FIX17: itens agora vêm das caixas
        test_item_name = "item_phase_boots",
        boost_duration = 1.20,
        boost_add_speed = 460,

        -- FIX26: stun de corrida. Em vez de só modifier_stunned do Dota,
        -- o kart desacelera até parar e gira visualmente estilo Mario Kart.
        stun_deceleration = 2600,
        stun_spin_rate = 980,

        -- 1 = steering normal. -1 inverte A/D se seu modelo/pista precisar.
        steering_sign = 1,

        -- FIX29: colisão estilo Mario Kart 64, high ground mais forte.
        collision_physics = true,
        collision_radius = 118,
        player_collision_radius = 150,
        tree_collision_radius = 96,
        obstacle_probe_radius = 72,
        -- FIX30: high ground bloqueia fora da pista, mas permite rampas/paths válidos.
        max_step_height = 44,
        track_lane_width = 900,
        track_max_step_height = 260,
        -- FIX74: bots publicos precisam conseguir subir rampas/escadas da pista.
        -- Mantem o bloqueio forte para humanos/off-road, mas permite maior delta vertical
        -- quando uma IA publica esta dentro da faixa da pista.
        public_ai_track_max_step_height = 900,
        high_ground_lookahead = 190,
        high_ground_pushback = 245,
        wall_bounce_speed_factor = 0.68,
        wall_pushback = 130,
        kart_push_factor = 0.55,
        kart_bump_speed_loss = 0.62,
        kart_bump_transfer = 0.34,
        min_bump_speed = 80,

        -- FIX30: drift/derrapagem visual ao virar em alta velocidade.
        drift_enabled = true,
        drift_min_speed = 560,
        drift_lateral_factor = 0.34,
        drift_speed_loss_factor = 0.985,

        -- FIX89: penalidade off-road. Fora da faixa da pista/dk_track_* ou em tile sem Path,
        -- o kart perde velocidade e fica instável. Star/BKB ignora a penalidade.
        offroad_enabled = true,
        offroad_speed_factor = 0.66,
        offroad_reverse_speed_factor = 0.78,
        offroad_accel_factor = 0.70,
        offroad_extra_friction = 620,
        offroad_instability_yaw = 52,
        offroad_lateral_drift = 95,
        offroad_min_speed_for_instability = 180,
        offroad_gridnav_required = true,
        -- FIX97: usa o pathing/GridNav do tile/mapa como referência principal de pista.
        -- VScript não expõe diretamente o nome do material/tile set (ex: radiant_basic),
        -- então a referência segura é GridNav:IsTraversable/IsBlocked.
        -- FIX98: não use GridNav como única referência, porque Block Wards não aparece como
        -- pista/grama para IsTraversable em todas as builds. A base volta a ser corredor dk_track_*
        -- + atalhos dk_track_skip, com GridNav apenas como ajuda/penalty quando expõe bloqueio.
        offroad_use_gridnav_only = false,
        official_path_sample_radius = 96,
        -- Experimental: se Block Wards aparecer como IsTraversable=true + IsBlocked=true,
        -- usa isso como tile de penalidade sem bloquear o kart.
        offroad_detect_ward_block_as_penalty = true,
        -- FIX96: entidades dk_track_skip são atalhos oficiais da pista.
        -- Dentro deste raio o kart não sofre penalidade de grama/no-path e não é bloqueado por GridNav/highground lateral.
        track_skip_name = "dk_track_skip",
        track_skip_radius = 1500,
        track_skip_cache_interval = 1.0,
        offroad_debug = false
    }

    -- FIX15: não use Dynamic_Wrap aqui. Em CustomGameEventManager ele pode chamar o método
    -- sem self, causando "attempt to index local 'self' (a number value)".
    CustomGameEventManager:RegisterListener("dotakart_input_state", function(eventSourceIndex, keys)
        return DotaKartController:OnInputState(eventSourceIndex, keys)
    end)
    CustomGameEventManager:RegisterListener("dotakart_input_item", function(eventSourceIndex, keys)
        return DotaKartController:OnInputItem(eventSourceIndex, keys)
    end)

    if GameRules:GetGameModeEntity() ~= nil then
        GameRules:GetGameModeEntity():SetExecuteOrderFilter(Dynamic_Wrap(DotaKartController, "OrderFilter"), self)
    end

    Convars:RegisterCommand("dk_controls_on", function()
        self:SetEnabled(true)
    end, "DotA Kart: liga controle manual do kart", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_controls_off", function()
        self:SetEnabled(false)
    end, "DotA Kart: desliga controle manual do kart", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_kart_stop", function()
        self:HardStopAll()
    end, "DotA Kart: zera velocidade dos karts", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_give_boost", function()
        self:GiveBoostToAll()
    end, "DotA Kart: dá item de boost para todos os karts", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_kart_teleport_start", function()
        self:TeleportAllToTrackStart()
    end, "DotA Kart: teleporta karts para dk_track_001 e alinha com dk_track_002", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_kart_debug", function()
        self.config.debug = not self.config.debug
        print("[DotaKartController] debug = " .. tostring(self.config.debug))
    end, "DotA Kart: alterna debug do controle", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_debug_offroad", function()
        local hero = self:GetHeroForPlayer(0)
        if not DKValidUnit(hero) then print("[DotaKartController] dk_debug_offroad: player 0 sem hero") return end
        local pos = hero:GetAbsOrigin()
        local trav, blocked, tree = "n/a", "n/a", "n/a"
        if GridNav ~= nil then
            pcall(function() trav = tostring(GridNav:IsTraversable(pos)) end)
            pcall(function() blocked = tostring(GridNav:IsBlocked(pos)) end)
            pcall(function() tree = tostring(GridNav:IsNearbyTree(pos, tonumber(self.config.tree_collision_radius) or 96, true)) end)
        end
        local skipCount = 0
        local pts = self:RefreshTrackSkipPoints(true) or {}
        skipCount = #pts
        local info = self:GetOffroadInfo(0, hero, pos, DKNow())
        print("[DotaKartController] dk_debug_offroad pos=(" .. math.floor(pos.x) .. "," .. math.floor(pos.y) .. "," .. math.floor(pos.z) .. ") traversable=" .. tostring(trav) .. " blocked=" .. tostring(blocked) .. " tree=" .. tostring(tree) .. " trackSkip=" .. tostring(self:IsPositionInsideTrackSkip(pos)) .. " skipCount=" .. tostring(skipCount) .. " insideTrack=" .. tostring(self:IsPositionInsideTrackLane(pos)) .. " officialPath=" .. tostring(self:IsPositionOnOfficialPath(pos)) .. " wardPenalty=" .. tostring(self:IsGridNavWardBlockPenaltyTile(pos)) .. " offroad=" .. tostring(info and info.active) .. " reason=" .. tostring(info and info.reason))
    end, "DotA Kart: imprime debug de GridNav/off-road/track_skip do player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_kart_invert_steer", function()
        self.config.steering_sign = -self.config.steering_sign
        print("[DotaKartController] steering_sign = " .. tostring(self.config.steering_sign))
    end, "DotA Kart: inverte A/D", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_kart_physics_on", function()
        self.config.collision_physics = true
        print("[DotaKartController] collision_physics = true")
    end, "DotA Kart: liga fisica de colisao", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_kart_physics_off", function()
        self.config.collision_physics = false
        print("[DotaKartController] collision_physics = false")
    end, "DotA Kart: desliga fisica de colisao", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_kart_drift_on", function()
        self.config.drift_enabled = true
        print("[DotaKartController] drift_enabled = true")
    end, "DotA Kart: liga derrapagem", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_kart_drift_off", function()
        self.config.drift_enabled = false
        print("[DotaKartController] drift_enabled = false")
    end, "DotA Kart: desliga derrapagem", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_kart_terrain_relax", function()
        self.config.track_lane_width = 1200
        self.config.track_max_step_height = 340
        print("[DotaKartController] terrain relax: lane_width=1200 track_step=340")
    end, "DotA Kart: permite rampas/paths mais altos", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_kart_terrain_strict", function()
        self.config.track_lane_width = 650
        self.config.track_max_step_height = 170
        print("[DotaKartController] terrain strict: lane_width=650 track_step=170")
    end, "DotA Kart: deixa high ground mais estrito", FCVAR_CHEAT)

    -- Testes sem teclado. Use para provar que o servidor consegue mover o herói/kart.
    Convars:RegisterCommand("dk_kart_test_forward_on", function()
        self:SetTestInput(0, true, false, false, false)
    end, "DotA Kart: simula W pressionado no player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_kart_test_reverse_on", function()
        self:SetTestInput(0, false, true, false, false)
    end, "DotA Kart: simula S pressionado no player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_kart_test_left_on", function()
        self:SetTestInput(0, true, false, true, false)
    end, "DotA Kart: simula W+A no player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_kart_test_right_on", function()
        self:SetTestInput(0, true, false, false, true)
    end, "DotA Kart: simula W+D no player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_kart_test_release", function()
        self:SetTestInput(0, false, false, false, false)
    end, "DotA Kart: solta todos inputs simulados no player 0", FCVAR_CHEAT)

    self:StartThink()

    print("[DotaKartController] Controle manual iniciado FIX51")
end

function DotaKartController:SetEnabled(enabled)
    self.enabled = enabled == true
    print("[DotaKartController] enabled = " .. tostring(self.enabled))

    if not self.enabled then
        self:HardStopAll()
    end
end

function DotaKartController:StartThink()
    if self._thinkStarted then return end
    self._thinkStarted = true
    self._lastThinkTime = DKNow()

    GameRules:GetGameModeEntity():SetContextThink("DotaKartControllerThink", function()
        return self:OnThink()
    end, self.config.tick_rate)
end

function DotaKartController:GetState(playerID)
    if self.states[playerID] == nil then
        self.states[playerID] = {
            input = {
                forward = false,
                reverse = false,
                left = false,
                right = false
            },
            speed = 0,
            yaw = nil,
            boost_until = 0,
            item_max_speed_until = 0,
            item_max_speed = 0,
            star_until = 0,
            hook_passthrough_until = 0,
            hook_passthrough_target = -1,
            burrow_airborne_until = 0,
            rooted_until = 0,
            spectral_path_buff_until = 0,
            spectral_path_bonus_pct = 0,
            spectral_unobstructed_until = 0,
            spectral_recovery_started = 0,
            spectral_last_safe_track_x = nil,
            spectral_last_safe_track_y = nil,
            spectral_last_safe_track_z = nil,
            slow_until = 0,
            slow_start_time = 0,
            slow_initial_pct = 0,
            slow_recover_per_tick = 0.001,
            slow_tick = 0.03,
            locked_until = 0,
            stunned_until = 0,
            stun_spin_yaw = 0,
            last_stop_order_time = 0,
            last_resolve_time = 0,
            last_collision_time = 0,
            bump_push_x = 0,
            bump_push_y = 0,
            last_debug_time = 0
        }
    end
    return self.states[playerID]
end

function DotaKartController:GetHeroForPlayer(playerID)
    if self.heroes[playerID] ~= nil and not self.heroes[playerID]:IsNull() then
        return self.heroes[playerID]
    end

    if PlayerResource ~= nil and PlayerResource:IsValidPlayerID(playerID) then
        local hero = PlayerResource:GetSelectedHeroEntity(playerID)
        if DKValidUnit(hero) then
            self.heroes[playerID] = hero
            return hero
        end
    end

    return nil
end

-- FIX68: bots publicos criados como fake clients aparecem em PlayerResource.
-- Sem este filtro, o controller manual processa o mesmo heroi do bot como se fosse
-- jogador humano sem input, enquanto DotaKartPublicAI tambem move o kart. Isso duplica
-- movimento e deixa a IA muito mais rapida que jogadores humanos.
function DotaKartController:IsPublicAIControlled(playerID, hero)
    local st = self.states and self.states[playerID]
    if st ~= nil and st.public_ai_controlled == true then return true end

    if _G.DOTA_KART_PUBLIC_AI_PLAYER_IDS ~= nil and _G.DOTA_KART_PUBLIC_AI_PLAYER_IDS[playerID] == true then
        return true
    end

    if DKValidUnit(hero) then
        local ent = -1
        pcall(function() ent = hero:entindex() end)
        if ent ~= nil and ent >= 0 and _G.DOTA_KART_PUBLIC_AI_UNIT_ENTS ~= nil and _G.DOTA_KART_PUBLIC_AI_UNIT_ENTS[ent] == true then
            return true
        end
    end

    return false
end

function DotaKartController:ApplyKartModifier(hero)
    if not DKValidUnit(hero) then return end

    -- FIX25: modifier escondido para impedir auto-attack/facing do Dota.
    if hero.AddNewModifier ~= nil and not hero:HasModifier("modifier_dotakart_kart_controlled") then
        pcall(function()
            hero:AddNewModifier(hero, nil, "modifier_dotakart_kart_controlled", {})
        end)
    end

    self:SuppressDotaAutoAttack(hero)
end

function DotaKartController:SuppressDotaAutoAttack(hero)
    if not DKValidUnit(hero) then return end
    if not self.config.disable_auto_attack then return end

    -- Não usar hero:Stop() aqui: Stop cortava animações e podia quebrar movimento.
    pcall(function()
        if hero.SetIdleAcquire ~= nil then hero:SetIdleAcquire(false) end
    end)
    pcall(function()
        if hero.SetAcquisitionRange ~= nil then hero:SetAcquisitionRange(0) end
    end)
    pcall(function()
        if hero.SetForceAttackTarget ~= nil then hero:SetForceAttackTarget(nil) end
    end)
    pcall(function()
        if hero.SetAggroTarget ~= nil then hero:SetAggroTarget(nil) end
    end)
    pcall(function()
        if self.config.set_no_attack_capability and hero.SetAttackCapability ~= nil and DOTA_UNIT_CAP_NO_ATTACK ~= nil then
            hero:SetAttackCapability(DOTA_UNIT_CAP_NO_ATTACK)
        end
    end)
end

function DotaKartController:RegisterHero(playerID, hero)
    if playerID == nil or playerID < 0 then return end
    if not DKValidUnit(hero) then return end

    self.heroes[playerID] = hero
    local st = self:GetState(playerID)

    if st.yaw == nil then
        st.yaw = self:GetTrackYawForHero(hero) or self:GetUnitYaw(hero) or 0
    end

    self:ApplyKartModifier(hero)
    self:SetHeroFacing(hero, st.yaw)

    if self.config.start_with_test_item and (self.heldItems[playerID] == nil or self.heldItems[playerID] == "") then
        self:SetHeldItem(playerID, self.config.test_item_name)
    end

    if self.config.debug then
        print("[DotaKartController] Hero/Kart registrado: player " .. tostring(playerID) .. " yaw=" .. tostring(math.floor(st.yaw or 0)))
    end
end

function DotaKartController:ApplyToExistingHeroes()
    for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(playerID) then
            local hero = PlayerResource:GetSelectedHeroEntity(playerID)
            if DKValidUnit(hero) then
                self:RegisterHero(playerID, hero)
            end
        end
    end
end

function DotaKartController:SetHeldItem(playerID, itemName, itemCharges)
    itemName = itemName or ""
    self.heldItems[playerID] = itemName

    if self.hud ~= nil and self.hud.SetRacerItem ~= nil then
        self.hud:SetRacerItem(playerID, itemName, itemCharges or 0)
    end
end

function DotaKartController:GiveBoostToAll()
    for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(playerID) then
            self:SetHeldItem(playerID, self.config.test_item_name)
            print("[DotaKartController] Boost entregue ao player " .. tostring(playerID))
        end
    end
end

function DotaKartController:SetTestInput(playerID, forward, reverse, left, right)
    local st = self:GetState(playerID)
    st.input.forward = forward == true
    st.input.reverse = reverse == true
    st.input.left = left == true
    st.input.right = right == true
    print("[DotaKartController] TEST input p" .. tostring(playerID) ..
        " W=" .. tostring(st.input.forward) ..
        " S=" .. tostring(st.input.reverse) ..
        " A=" .. tostring(st.input.left) ..
        " D=" .. tostring(st.input.right))
end

function DotaKartController:SetKartLocked(playerID, duration)
    local st = self:GetState(playerID)
    local now = DKNow()
    st.locked_until = math.max(st.locked_until or 0, now + (duration or 0.1))
    st.speed = 0
end

function DotaKartController:IsKartLocked(playerID, now)
    local st = self:GetState(playerID)
    return (st.locked_until or 0) > (now or DKNow())
end

function DotaKartController:SetKartRoot(playerID, duration)
    local st = self:GetState(playerID)
    local now = DKNow()
    local dur = math.max(0.05, tonumber(duration) or 1.0)
    st.rooted_until = math.max(st.rooted_until or 0, now + dur)
    st.speed = 0
    st.input.forward = false
    st.input.reverse = false
end

function DotaKartController:IsKartRooted(playerID, now)
    local st = self:GetState(playerID)
    return (st.rooted_until or 0) > (now or DKNow())
end

function DotaKartController:SetKartSlow(playerID, duration, slowPct, recoverPerTick, tickInterval)
    local st = self:GetState(playerID)
    local now = DKNow()
    local dur = math.max(0.05, tonumber(duration) or 15.0)
    local pct = DKClamp(tonumber(slowPct) or 0.5, 0, 0.95)
    st.slow_until = math.max(st.slow_until or 0, now + dur)
    st.slow_start_time = now
    st.slow_initial_pct = math.max(tonumber(st.slow_initial_pct or 0) or 0, pct)
    st.slow_recover_per_tick = tonumber(recoverPerTick) or 0.001
    st.slow_tick = tonumber(tickInterval) or 0.03
end

function DotaKartController:GetKartSlowPct(playerID, now)
    local st = self:GetState(playerID)
    now = now or DKNow()
    if (st.slow_until or 0) <= now then return 0 end
    local elapsed = math.max(0, now - (st.slow_start_time or now))
    local tick = math.max(0.001, tonumber(st.slow_tick) or 0.03)
    local steps = math.floor(elapsed / tick)
    local recover = steps * (tonumber(st.slow_recover_per_tick) or 0.001)
    local pct = (tonumber(st.slow_initial_pct) or 0) - recover
    return DKClamp(pct, 0, 0.95)
end

function DotaKartController:SetKartStunned(playerID, duration)
    local st = self:GetState(playerID)
    local now = DKNow()
    local dur = math.max(0.05, tonumber(duration) or 0.5)
    st.stunned_until = math.max(st.stunned_until or 0, now + dur)
    st.stun_spin_yaw = tonumber(st.stun_spin_yaw or st.yaw or 0) or 0
    st.was_stunned = true
    -- Remove aceleração de itens enquanto está rodando/parado pelo stun.
    st.boost_until = math.min(st.boost_until or 0, now)
    st.item_max_speed_until = math.min(st.item_max_speed_until or 0, now)
    st.item_max_speed = 0
end

function DotaKartController:IsKartStunned(playerID, now)
    local st = self:GetState(playerID)
    return (st.stunned_until or 0) > (now or DKNow())
end

function DotaKartController:UpdateStunnedKart(playerID, hero, st, dt, now)
    -- Stun estilo Mario Kart: desacelera até parar e gira o modelo, mas mantém o kart no chão.
    local decel = tonumber(self.config.stun_deceleration) or 2600
    st.speed = DKApproach(st.speed or 0, 0, decel * dt)

    st.stun_spin_yaw = DKNormalizeYaw((st.stun_spin_yaw or st.yaw or 0) + (self.config.stun_spin_rate or 980) * dt)
    self:SetHeroFacing(hero, st.stun_spin_yaw)

    local baseYaw = tonumber(st.yaw or 0) or 0
    local rad = math.rad(baseYaw)
    local forward = Vector(math.cos(rad), math.sin(rad), 0)
    local pos = hero:GetAbsOrigin()
    local nextPos = pos + forward * ((st.speed or 0) * dt)
    nextPos.z = GetGroundHeight(nextPos, hero) + self.config.ground_z_offset
    hero:SetAbsOrigin(nextPos)

    if now >= (st.stunned_until or 0) then
        st.speed = 0
        self:SetHeroFacing(hero, st.yaw or baseYaw)
    end
end

function DotaKartController:OnInputState(eventSourceIndex, keys)
    local playerID = DKGetPlayerIDFromEvent(eventSourceIndex, keys)
    if playerID < 0 then
        if self.config.debug then
            print("[DotaKartController] input ignorado: PlayerID ausente")
        end
        return
    end

    local st = self:GetState(playerID)
    local oldSig = (st.input.forward and "1" or "0") .. (st.input.reverse and "1" or "0") .. (st.input.left and "1" or "0") .. (st.input.right and "1" or "0")

    st.input.forward = DKBool(keys.forward)
    st.input.reverse = DKBool(keys.reverse)
    st.input.left = DKBool(keys.left)
    st.input.right = DKBool(keys.right)

    local newSig = (st.input.forward and "1" or "0") .. (st.input.reverse and "1" or "0") .. (st.input.left and "1" or "0") .. (st.input.right and "1" or "0")
    if self.config.debug and oldSig ~= newSig then
        print("[DotaKartController] input p" .. tostring(playerID) ..
            " W=" .. tostring(st.input.forward) ..
            " S=" .. tostring(st.input.reverse) ..
            " A=" .. tostring(st.input.left) ..
            " D=" .. tostring(st.input.right))
    end
end

function DotaKartController:OnInputItem(eventSourceIndex, keys)
    local playerID = DKGetPlayerIDFromEvent(eventSourceIndex, keys)
    if playerID < 0 then return end
    local st = self:GetState(playerID)
    st.force_forward_item = DKBool(keys and keys.force_forward)
    st.force_forward_item_until = DKNow() + 0.20
    self:UseItem(playerID)
end

function DotaKartController:UseItem(playerID)
    local hero = self:GetHeroForPlayer(playerID)
    if not DKValidUnit(hero) then return end

    if self:IsKartStunned(playerID, DKNow()) then
        if self.config.debug then
            print("[DotaKartController] Player " .. tostring(playerID) .. " tentou usar item durante STUN; bloqueado.")
        end
        return
    end

    local itemName = self.heldItems[playerID] or ""
    if itemName == "" then
        if self.config.debug then
            print("[DotaKartController] Player " .. tostring(playerID) .. " tentou usar item, mas esta sem item.")
        end
        return
    end

    -- FIX17: itens reais ficam no DotaKartItemSystem.
    -- Mantém o controller só como dono do input T e do estado do item na HUD.
    if GameRules.DotaKartItemSystem ~= nil and GameRules.DotaKartItemSystem.UseItem ~= nil then
        if GameRules.DotaKartItemSystem:UseItem(playerID, itemName) then
            return
        end
    end

    local st = self:GetState(playerID)
    local now = DKNow()

    -- Fallback antigo: boost simples.
    if itemName == "item_phase_boots" or itemName == "dotakart_item_boost" then
        st.boost_until = now + self.config.boost_duration
        st.speed = math.min(st.speed + self.config.boost_add_speed, self.config.boost_max_speed)
        self:SetHeldItem(playerID, "")
        print("[DotaKartController] Player " .. tostring(playerID) .. " usou BOOST fallback")
        return
    end

    self:SetHeldItem(playerID, "")
    print("[DotaKartController] Player " .. tostring(playerID) .. " usou item desconhecido: " .. tostring(itemName))
end

function DotaKartController:GetUnitYaw(unit)
    if not DKValidUnit(unit) then return 0 end

    local fwd = unit:GetForwardVector()
    if fwd ~= nil then
        return DKNormalizeYaw(math.deg(DKAtan2(fwd.y, fwd.x)))
    end

    return 0
end

function DotaKartController:GetTrackYawForHero(hero)
    if self.hud == nil or self.hud.trackSegments == nil or #self.hud.trackSegments <= 0 then
        return nil
    end

    local pos = hero:GetAbsOrigin()
    local project = self.hud:ProjectPositionOnTrack(pos)
    local seg = self.hud.trackSegments[project.nearest_segment or 1]
    if seg == nil then
        seg = self.hud.trackSegments[1]
    end
    if seg == nil then return nil end

    local dx = seg.b.x - seg.a.x
    local dy = seg.b.y - seg.a.y
    return DKNormalizeYaw(math.deg(DKAtan2(dy, dx)))
end

function DotaKartController:GetHeroUnitName(hero)
    if not DKValidUnit(hero) then return "" end
    local name = ""
    pcall(function() name = tostring(hero:GetUnitName() or "") end)
    return name
end

function DotaKartController:GetCustomKartVisualYawOffset(hero)
    local heroName = self:GetHeroUnitName(hero)
    if DOTA_KART_CUSTOM_KART_FACING_YAW_OFFSET ~= nil then
        return tonumber(DOTA_KART_CUSTOM_KART_FACING_YAW_OFFSET[heroName] or 0) or 0
    end
    return 0
end

function DotaKartController:GetCustomKartGroundZOffset(hero)
    local heroName = self:GetHeroUnitName(hero)
    local offset = 0
    if DOTA_KART_CUSTOM_KART_GROUND_Z_OFFSET ~= nil then
        offset = tonumber(DOTA_KART_CUSTOM_KART_GROUND_Z_OFFSET[heroName] or 0) or 0
    end
    return offset
end

function DotaKartController:ApplyCustomKartVisualGroundOffset(hero, pos)
    if not DKValidUnit(hero) or pos == nil then return pos end
    local offset = self:GetCustomKartGroundZOffset(hero)
    if offset ~= 0 then
        pos = Vector(pos.x, pos.y, pos.z + offset)
        hero:SetAbsOrigin(pos)
    end
    return pos
end

function DotaKartController:SetHeroFacing(hero, yaw)
    if not DKValidUnit(hero) then return end

    yaw = DKNormalizeYaw((yaw or 0) + self:GetCustomKartVisualYawOffset(hero))
    local rad = math.rad(yaw)
    local fwd = Vector(math.cos(rad), math.sin(rad), 0)

    if hero.SetForwardVector ~= nil then
        hero:SetForwardVector(fwd)
    end

    if hero.FaceTowards ~= nil then
        local pos = hero:GetAbsOrigin()
        hero:FaceTowards(pos + fwd * 256)
    end

    if hero.SetAngles ~= nil then
        hero:SetAngles(0, yaw, 0)
    elseif hero.SetAbsAngles ~= nil then
        hero:SetAbsAngles(0, yaw, 0)
    end
end

function DotaKartController:RefreshTrackSkipPoints(force)
    local now = DKNow()
    if self._trackSkipPoints ~= nil and force ~= true and now < (self._nextTrackSkipRefresh or 0) then
        return self._trackSkipPoints
    end

    local points = {}
    local seen = {}
    local name = tostring((self.config and self.config.track_skip_name) or "dk_track_skip")

    local function addEnt(ent)
        if ent == nil then return end
        local idx = -1
        pcall(function() idx = ent:entindex() end)
        if idx ~= nil and seen[idx] == true then return end
        if idx ~= nil then seen[idx] = true end
        local ok, p = pcall(function() return ent:GetAbsOrigin() end)
        if ok and p ~= nil then table.insert(points, Vector(p.x, p.y, p.z)) end
    end

    if Entities ~= nil then
        if Entities.FindAllByName ~= nil then
            local ok, list = pcall(function() return Entities:FindAllByName(name) end)
            if ok and type(list) == "table" then
                for _, ent in pairs(list) do addEnt(ent) end
            end
        end
        if Entities.FindByName ~= nil then
            local ent = Entities:FindByName(nil, name)
            local guard = 0
            while ent ~= nil and guard < 1024 do
                addEnt(ent)
                ent = Entities:FindByName(ent, name)
                guard = guard + 1
            end
        end
    end

    self._trackSkipPoints = points
    self._nextTrackSkipRefresh = now + (tonumber(self.config and self.config.track_skip_cache_interval or 1.0) or 1.0)
    if self.config ~= nil and self.config.offroad_debug == true then
        print("[DotaKartController] FIX98 track_skip points=" .. tostring(#points) .. " name=" .. tostring(name))
    end
    return points
end

function DotaKartController:IsPositionInsideTrackSkip(pos)
    if pos == nil then return false end
    local points = self:RefreshTrackSkipPoints(false)
    if points == nil or #points <= 0 then return false end
    local radius = tonumber(self.config and self.config.track_skip_radius or 1500) or 1500
    local r2 = radius * radius
    for _, p in ipairs(points) do
        local dx = (pos.x or 0) - (p.x or 0)
        local dy = (pos.y or 0) - (p.y or 0)
        if (dx * dx + dy * dy) <= r2 then
            return true
        end
    end
    return false
end

function DotaKartController:IsPositionInsideTrackLane(pos)
    if pos == nil then return false end
    if self:IsPositionInsideTrackSkip(pos) then return true end
    local hud = self.hud or GameRules.DotaKartHUD
    if hud == nil or hud.ProjectPositionOnTrack == nil or hud.trackSegments == nil or #hud.trackSegments <= 0 then
        return false
    end

    local project = hud:ProjectPositionOnTrack(pos)
    local distSq = tonumber(project and project.nearest_dist_sq or 999999999) or 999999999
    local lane = tonumber(self.config.track_lane_width) or 900
    return distSq <= lane * lane
end
function DotaKartController:IsSpectralUnobstructed(playerID, now)
    local st = self:GetState(playerID)
    return st ~= nil and (tonumber(st.spectral_unobstructed_until or st.spectral_path_buff_until or 0) or 0) > (now or DKNow())
end

function DotaKartController:GetNearestTrackPointPosition(pos, hero)
    if pos == nil or self.hud == nil or self.hud.trackWorldPoints == nil or #self.hud.trackWorldPoints <= 0 then return nil end
    local idx = self:GetNearestTrackIndex(pos)
    local p = self.hud.trackWorldPoints[idx]
    if p == nil then return nil end
    return Vector(p.x, p.y, GetGroundHeight(p, hero))
end

function DotaKartController:RememberSpectralSafeTrackPoint(playerID, hero, st, pos)
    if st == nil or pos == nil then return end
    local safe = false
    if self:IsPositionInsideTrackLane(pos) then safe = true end
    if safe ~= true and self:IsPositionOnPathTile(pos) then safe = true end
    if safe ~= true then return end
    local p = self:GetNearestTrackPointPosition(pos, hero)
    if p == nil then return end
    st.spectral_last_safe_track_x = p.x
    st.spectral_last_safe_track_y = p.y
    st.spectral_last_safe_track_z = p.z
end

function DotaKartController:RecoverSpectralIfStuck(playerID, hero, st, now)
    if not DKValidUnit(hero) or st == nil then return false end
    local lastActive = tonumber(st.spectral_last_active_time or st.spectral_unobstructed_until or 0) or 0
    if lastActive <= 0 or now < lastActive then
        st.spectral_recovery_started = 0
        return false
    end
    if now > lastActive + 12.0 then
        st.spectral_recovery_started = 0
        return false
    end

    local pos = hero:GetAbsOrigin()
    local blocked = false
    local noPath = false
    pcall(function() blocked = self:IsWorldCollisionBlocked(pos, hero, pos, nil) == true end)
    noPath = self:IsPositionOnPathTile(pos) ~= true

    if blocked ~= true and noPath ~= true then
        st.spectral_recovery_started = 0
        self:RememberSpectralSafeTrackPoint(playerID, hero, st, pos)
        return false
    end

    if (tonumber(st.spectral_recovery_started or 0) or 0) <= 0 then
        st.spectral_recovery_started = now
        return false
    end

    local delay = tonumber(st.spectral_recovery_delay or 5.0) or 5.0
    if now - st.spectral_recovery_started < delay then return false end

    local target = nil
    if st.spectral_last_safe_track_x ~= nil then
        target = Vector(st.spectral_last_safe_track_x, st.spectral_last_safe_track_y, st.spectral_last_safe_track_z or 0)
        target.z = GetGroundHeight(target, hero) + (self.config.ground_z_offset or 0)
    else
        target = self:GetNearestTrackPointPosition(pos, hero)
        if target ~= nil then target.z = target.z + (self.config.ground_z_offset or 0) end
    end

    if target ~= nil then
        hero:SetAbsOrigin(target)
        pcall(function() FindClearSpaceForUnit(hero, target, true) end)
        st.speed = 0
        st.spectral_recovery_started = 0
        st.spectral_last_active_time = 0
        if self.config.debug then
            print("[DotaKartController] FIX91 Spectral recovery teleport p" .. tostring(playerID))
        end
        return true
    end
    return false
end

function DotaKartController:IsGridNavWardBlockPenaltyTile(pos)
    -- FIX98: tentativa segura para usar Block Wards como zona de penalidade.
    -- VScript não expõe uma função IsWardBlocked. Em algumas builds, uma célula marcada
    -- como Block Wards aparece como IsTraversable=true e IsBlocked=true. Quando isso
    -- acontece, tratamos como off-road/grama, mas não como parede.
    if pos == nil then return false end
    if self.config == nil or self.config.offroad_detect_ward_block_as_penalty ~= true then return false end
    if GridNav == nil or GridNav.IsTraversable == nil or GridNav.IsBlocked == nil then return false end
    local traversable = false
    local blocked = false
    local okT = pcall(function() traversable = GridNav:IsTraversable(pos) == true end)
    local okB = pcall(function() blocked = GridNav:IsBlocked(pos) == true end)
    return okT and okB and traversable == true and blocked == true
end

function DotaKartController:IsPositionOnPathTile(pos)
    if pos == nil or GridNav == nil or GridNav.IsTraversable == nil then return true end
    local ok, traversable = pcall(function() return GridNav:IsTraversable(pos) end)
    if not ok then return true end
    return traversable == true
end

function DotaKartController:IsPositionOnOfficialPath(pos)
    -- FIX97/FIX98: não há API Lua confiável para ler o material/tile set visual (radiant_basic)
    -- nem a layer Block Wards diretamente. Para gameplay usamos dk_track_*/dk_track_skip
    -- e o pathing exposto pelo GridNav.
    if pos == nil then return false end
    if self:IsPositionInsideTrackSkip(pos) then return true end
    if self:IsGridNavWardBlockPenaltyTile(pos) then return false end
    if GridNav == nil or GridNav.IsTraversable == nil then return true end

    local sample = tonumber(self.config and self.config.official_path_sample_radius or 96) or 96
    local probes = {
        pos,
        pos + Vector(sample, 0, 0),
        pos + Vector(-sample, 0, 0),
        pos + Vector(0, sample, 0),
        pos + Vector(0, -sample, 0)
    }

    for _, p in ipairs(probes) do
        local traversable = false
        local blocked = false
        local ok = pcall(function() traversable = GridNav:IsTraversable(p) == true end)
        if ok and traversable == true then
            if GridNav.IsBlocked ~= nil then
                pcall(function() blocked = GridNav:IsBlocked(p) == true end)
            end
            if blocked ~= true then return true end
        end
    end
    return false
end

function DotaKartController:GetOffroadInfo(playerID, hero, pos, now)
    local info = { active = false, reason = "track" }
    if self.config == nil or self.config.offroad_enabled ~= true then return info end
    if pos == nil then return info end

    -- Star/BKB mantém o comportamento já esperado: sem slow/penalidade off-road.
    if self.IsKartStarActive ~= nil and self:IsKartStarActive(playerID) then return info end
    -- FIX91: usuário no Shadow Path da Spectral Dagger fica desobstruído para cortar caminho.
    if self:IsSpectralUnobstructed(playerID, now) then return info end

    if self:IsPositionInsideTrackSkip(pos) then return info end

    if self:IsGridNavWardBlockPenaltyTile(pos) then
        info.active = true
        info.reason = "ward_block_penalty"
        return info
    end

    local onOfficialPath = self:IsPositionOnOfficialPath(pos)
    if self.config.offroad_use_gridnav_only == true then
        if onOfficialPath then return info end
        info.active = true
        info.reason = "no_official_path"
        return info
    end

    local insideTrack = self:IsPositionInsideTrackLane(pos)
    local onPath = true
    if self.config.offroad_gridnav_required ~= false then
        onPath = onOfficialPath
    end

    if insideTrack and onPath then return info end

    info.active = true
    if not insideTrack and not onPath then
        info.reason = "off_track_no_path"
    elseif not insideTrack then
        info.reason = "off_track"
    else
        info.reason = "no_path"
    end

    return info
end

function DotaKartController:ApplyOffroadMovePenalty(playerID, hero, oldPos, desiredPos, moveDir, dt, now)
    if oldPos == nil or desiredPos == nil then return desiredPos end
    local info = self:GetOffroadInfo(playerID, hero, oldPos, now or DKNow())
    if info.active ~= true then return desiredPos end

    local factor = tonumber(self.config.offroad_speed_factor) or 0.66
    local result = oldPos + (desiredPos - oldPos) * factor

    local dir = DKNormalize2DVec(moveDir or (desiredPos - oldPos), Vector(1, 0, 0))
    local right = Vector(dir.y, -dir.x, 0)
    local wobble = math.sin((now or DKNow()) * 8.5 + (tonumber(playerID) or 0) * 1.77)
    local lateral = wobble * (tonumber(self.config.offroad_lateral_drift) or 95) * (tonumber(dt) or self.config.tick_rate or 0.03)
    result = result + right * lateral
    result.z = GetGroundHeight(result, hero) + (self.config.ground_z_offset or 0)

    local st = self:GetState(playerID)
    if st ~= nil then
        st.offroad_until = (now or DKNow()) + 0.20
        st.offroad_reason = info.reason
        if (st.speed or 0) > (self.config.max_speed or 880) * factor then
            st.speed = DKApproach(st.speed or 0, (self.config.max_speed or 880) * factor, (self.config.offroad_extra_friction or 620) * (tonumber(dt) or 0.03))
        end
    end

    return result
end


function DotaKartController:IsWorldCollisionBlocked(pos, hero, oldPos, moveDir)
    if pos == nil then return false, "nil" end
    local spectralPID = nil
    if DKValidUnit(hero) and self.GetPlayerIDForHero ~= nil then
        pcall(function() spectralPID = self:GetPlayerIDForHero(hero) end)
    end
    if spectralPID ~= nil and spectralPID >= 0 and self:IsSpectralUnobstructed(spectralPID, DKNow()) then
        return false, "spectral_unobstructed"
    end
    if self:IsPositionInsideTrackSkip(pos) then
        return false, "track_skip"
    end
    if self:IsGridNavWardBlockPenaltyTile(pos) then
        return false, "ward_block_penalty_passable"
    end
    if self:IsPositionOnOfficialPath(pos) then
        return false, "official_path"
    end

    local radius = tonumber(self.config.obstacle_probe_radius) or 72
    local blocked = false
    local reason = ""
    local isPublicAI = false
    if DKValidUnit(hero) then
        local ent = -1
        pcall(function() ent = hero:entindex() end)
        if ent ~= nil and ent >= 0 and _G.DOTA_KART_PUBLIC_AI_UNIT_ENTS ~= nil and _G.DOTA_KART_PUBLIC_AI_UNIT_ENTS[ent] == true then
            isPublicAI = true
        end
    end

    if oldPos ~= nil then
        local oldGround = GetGroundHeight(oldPos, hero)
        local maxStep = tonumber(self.config.max_step_height) or 38

        local function checkHighGround(p)
            if p == nil then return false end
            local g = GetGroundHeight(p, hero)
            local diff = g - oldGround

            if diff <= maxStep then
                return false
            end

            -- FIX30: se o ponto está dentro da faixa da pista definida pelos dk_track_*,
            -- trata como rampa/path válido e permite subir terreno bem mais alto.
            -- Fora da pista, continua bloqueando high ground forte.
            if self:IsPositionInsideTrackLane(p) then
                local trackStep = tonumber(self.config.track_max_step_height) or 260
                if isPublicAI then
                    trackStep = tonumber(self.config.public_ai_track_max_step_height) or math.max(trackStep, 900)
                end
                if diff <= trackStep then
                    return false
                end
            end

            return true
        end

        if checkHighGround(pos) then
            return true, "high_ground"
        end

        -- FIX29: se o jogador insistir segurando W, o tick pode subir o morro em micro-passos.
        -- Por isso também olhamos alguns probes à frente; se houver subida grande logo adiante,
        -- empurra de volta antes de atravessar o high ground.
        if moveDir ~= nil then
            local dir = DKNormalize2DVec(moveDir, Vector(1,0,0))
            local look = tonumber(self.config.high_ground_lookahead) or 190
            for _, d in ipairs({ 48, 96, look }) do
                local probe = pos + dir * d
                -- FIX74: a IA publica usa waypoints; o lookahead de high ground estava
                -- tratando rampas/escadas validas como parede e fazia o bot dar re sem parar.
                -- Para bots dentro da pista, deixa o movimento do tick decidir a subida.
                if not (isPublicAI and self:IsPositionInsideTrackLane(probe)) then
                    if checkHighGround(probe) then
                        return true, "high_ground"
                    end
                end
            end
        end
    end

    if GridNav ~= nil then
        pcall(function()
            if GridNav:IsBlocked(pos) then
                blocked = true
                reason = "blocked"
            end
        end)
        pcall(function()
            if GridNav:IsNearbyTree(pos, tonumber(self.config.tree_collision_radius) or 96, true) then
                blocked = true
                reason = "tree"
            end
        end)
    end

    return blocked, reason
end


function DotaKartController:GetPlayerIDForHero(hero)
    if not DKValidUnit(hero) then return -1 end
    for playerID, h in pairs(self.heroes or {}) do
        if DKValidUnit(h) and h == hero then return tonumber(playerID) or -1 end
    end
    if PlayerResource ~= nil then
        for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
            if PlayerResource:IsValidPlayerID(playerID) then
                local h = self:GetHeroForPlayer(playerID)
                if DKValidUnit(h) and h == hero then return playerID end
            end
        end
    end
    return -1
end

function DotaKartController:GetRegisteredKartHeroes()
    local out = {}
    for playerID, hero in pairs(self.heroes or {}) do
        if DKValidUnit(hero) then
            out[playerID] = hero
        end
    end
    for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        if PlayerResource ~= nil and PlayerResource:IsValidPlayerID(playerID) then
            local hero = self:GetHeroForPlayer(playerID)
            if DKValidUnit(hero) then out[playerID] = hero end
        end
    end
    return out
end

function DotaKartController:IsKartStarActive(playerID)
    if GameRules ~= nil and GameRules.DotaKartItemSystem ~= nil and GameRules.DotaKartItemSystem.IsPlayerStarActive ~= nil then
        return GameRules.DotaKartItemSystem:IsPlayerStarActive(playerID) == true
    end
    local st = self:GetState(playerID)
    return st ~= nil and (st.star_until or 0) > GameRules:GetGameTime()
end

function DotaKartController:GetStarCollisionConfig()
    local def = nil
    if GameRules ~= nil and GameRules.DotaKartItemSystem ~= nil and GameRules.DotaKartItemSystem.itemDefs ~= nil then
        def = GameRules.DotaKartItemSystem.itemDefs.item_black_king_bar
    end
    return {
        stun = tonumber(def and def.star_collision_stun or 0.65) or 0.65,
        push = tonumber(def and def.star_collision_push or 230) or 230
    }
end

function DotaKartController:ApplyKartCollisionPhysics(playerID, hero, st, oldPos, desiredPos, moveDir, dt, now)
    if not self.config.collision_physics then return desiredPos end
    if not DKValidUnit(hero) or oldPos == nil or desiredPos == nil then return desiredPos end

    local dir = DKNormalize2DVec(moveDir or (desiredPos - oldPos), Vector(1,0,0))
    local blocked, reason = self:IsWorldCollisionBlocked(desiredPos, hero, oldPos, dir)
    if blocked then
        local push = tonumber(self.config.wall_pushback) or 130
        if reason == "high_ground" then
            push = tonumber(self.config.high_ground_pushback) or 240
        end
        local result = oldPos - dir * push
        result.z = GetGroundHeight(result, hero) + (self.config.ground_z_offset or 0)

        local oldSpeed = tonumber(st.speed) or 0
        st.speed = -math.max(math.abs(oldSpeed), 420) * (tonumber(self.config.wall_bounce_speed_factor) or 0.68)
        if math.abs(st.speed) < 80 then st.speed = 0 end

        if self.config.debug then
            print("[DotaKartController] colisao mundo p" .. tostring(playerID) .. " reason=" .. tostring(reason) .. " speed=" .. tostring(math.floor(oldSpeed)) .. " -> " .. tostring(math.floor(st.speed)))
        end
        return result
    end

    local radius = tonumber(self.config.player_collision_radius) or 150
    local result = Vector(desiredPos.x, desiredPos.y, desiredPos.z)

    for otherID, otherHero in pairs(self:GetRegisteredKartHeroes()) do
        if otherID ~= playerID and DKValidUnit(otherHero) then
            local otherPos = otherHero:GetAbsOrigin()
            local dist = DKDistance2DPos(result, otherPos)
            if dist > 0.01 and dist < radius then
                local normal = DKNormalize2DVec(result - otherPos, dir)
                local penetration = radius - dist
                local otherSt = self:GetState(otherID)

                -- FIX51: Meat Hook pode puxar o alvo exatamente para a frente do usuário.
                -- Por curto tempo, essa dupla ignora colisão entre si para o caster não ficar bloqueado.
                local selfHookPass = st ~= nil and (st.hook_passthrough_until or 0) > now and tonumber(st.hook_passthrough_target or -1) == tonumber(otherID)
                local otherHookPass = otherSt ~= nil and (otherSt.hook_passthrough_until or 0) > now and tonumber(otherSt.hook_passthrough_target or -1) == tonumber(playerID)
                -- FIX72: vítimas arremessadas para cima pelo Burrowstrike ficam sem colisão horizontal
                -- por alguns décimos, permitindo que karts passem por baixo enquanto estão no ar.
                local selfAirbornePass = st ~= nil and (st.burrow_airborne_until or 0) > now
                local otherAirbornePass = otherSt ~= nil and (otherSt.burrow_airborne_until or 0) > now
                if selfHookPass or otherHookPass or selfAirbornePass or otherAirbornePass then
                    -- Continua atravessando só esse kart durante pass-through/airborne.
                else
                local selfStar = self:IsKartStarActive(playerID)
                local otherStar = self:IsKartStarActive(otherID)

                -- FIX48: Estrelinha/BKB fica desobstruida contra karts adversarios.
                -- O kart com estrela atravessa a colisao e atordoa/empurra o rival, estilo Star do Mario Kart.
                if selfStar and not otherStar then
                    local cfg = self:GetStarCollisionConfig()
                    local pushOther = math.max(cfg.push, penetration + cfg.push)
                    local otherLocked = otherSt ~= nil and ((otherSt.stunned_until or 0) > now or (otherSt.locked_until or 0) > now)
                    local otherNew = otherPos - normal * pushOther
                    otherNew.z = GetGroundHeight(otherNew, otherHero) + (self.config.ground_z_offset or 0)
                    local otherBlocked = self:IsWorldCollisionBlocked(otherNew, otherHero, otherPos, -normal)
                    if not otherLocked and not otherBlocked then
                        otherHero:SetAbsOrigin(otherNew)
                    end
                    if otherSt ~= nil then
                        otherSt.speed = -math.max(math.abs(otherSt.speed or 0), 420)
                        otherSt.yaw = DKNormalizeYaw(math.deg(DKAtan2(-normal.y, -normal.x)))
                    end
                    self:SetKartStunned(otherID, cfg.stun)
                elseif otherStar and not selfStar then
                    local cfg = self:GetStarCollisionConfig()
                    result = result + normal * math.max(cfg.push, penetration + cfg.push)
                    result.z = GetGroundHeight(result, hero) + (self.config.ground_z_offset or 0)
                    st.speed = -math.max(math.abs(st.speed or 0), 420)
                    self:SetKartStunned(playerID, cfg.stun)
                else
                    local pushSelf = penetration * 0.58
                    local pushOther = penetration * (tonumber(self.config.kart_push_factor) or 0.55)

                    result = result + normal * pushSelf
                    result.z = GetGroundHeight(result, hero) + (self.config.ground_z_offset or 0)

                    local otherLocked = otherSt ~= nil and ((otherSt.stunned_until or 0) > now or (otherSt.locked_until or 0) > now)
                    local otherNew = otherPos - normal * pushOther
                    otherNew.z = GetGroundHeight(otherNew, otherHero) + (self.config.ground_z_offset or 0)
                    local otherBlocked = self:IsWorldCollisionBlocked(otherNew, otherHero, otherPos, -normal)
                    if not otherLocked and not otherBlocked then
                        otherHero:SetAbsOrigin(otherNew)
                    end

                    local speed = tonumber(st.speed) or 0
                    if math.abs(speed) >= (tonumber(self.config.min_bump_speed) or 80) then
                        st.speed = speed * (tonumber(self.config.kart_bump_speed_loss) or 0.62)
                        if otherSt ~= nil then
                            local transfer = math.abs(speed) * (tonumber(self.config.kart_bump_transfer) or 0.34)
                            local sign = speed >= 0 and 1 or -1
                            otherSt.speed = DKClamp((otherSt.speed or 0) + transfer * sign, -(self.config.reverse_max_speed or 260), self.config.boost_max_speed or 1100)
                            otherSt.yaw = DKNormalizeYaw(math.deg(DKAtan2(-normal.y, -normal.x)))
                        end
                    end
                end

                end

                if self.config.debug and now - (st.last_collision_time or 0) > 0.25 then
                    st.last_collision_time = now
                    print("[DotaKartController] colisao kart p" .. tostring(playerID) .. " <-> p" .. tostring(otherID) .. " pen=" .. tostring(math.floor(penetration)))
                end
            end
        end
    end

    return result
end

function DotaKartController:MoveUnitWithKartPhysics(playerID, hero, desiredPos, moveDir, speed, dt)
    if not DKValidUnit(hero) or desiredPos == nil then return desiredPos end
    local st = self:GetState(playerID)
    if speed ~= nil then
        st.speed = tonumber(speed) or st.speed or 0
    elseif st.speed == nil then
        st.speed = 0
    end
    local oldPos = hero:GetAbsOrigin()
    local now = DKNow()
    if (st.spectral_unobstructed_until or st.spectral_path_buff_until or 0) > now then
        st.spectral_last_active_time = math.max(tonumber(st.spectral_last_active_time or 0) or 0, tonumber(st.spectral_unobstructed_until or st.spectral_path_buff_until or now) or now)
        self:RememberSpectralSafeTrackPoint(playerID, hero, st, oldPos)
    else
        self:RecoverSpectralIfStuck(playerID, hero, st, now)
        oldPos = hero:GetAbsOrigin()
    end
    desiredPos = self:ApplyOffroadMovePenalty(playerID, hero, oldPos, desiredPos, moveDir, dt or self.config.tick_rate, now)
    local finalPos = self:ApplyKartCollisionPhysics(playerID, hero, st, oldPos, desiredPos, moveDir, dt or self.config.tick_rate, now)
    hero:SetAbsOrigin(finalPos)
    finalPos = self:ApplyCustomKartVisualGroundOffset(hero, finalPos)
    return finalPos
end

function DotaKartController:GetPlayerStartEntity(playerID)
    -- PlayerID 0 usa player1_start_position, PlayerID 7 usa player8_start_position.
    local slot = (tonumber(playerID) or 0) + 1
    local names = {
        "player" .. tostring(slot) .. "_start_position",
        "player_" .. tostring(slot) .. "_start_position"
    }

    for _, name in ipairs(names) do
        local ent = Entities:FindByName(nil, name)
        if ent ~= nil then return ent, name end
    end

    return nil, nil
end

function DotaKartController:GetYawFromEntity(ent)
    if ent == nil then return nil end

    if ent.GetForwardVector ~= nil then
        local ok, fwd = pcall(function() return ent:GetForwardVector() end)
        if ok and fwd ~= nil and (math.abs(fwd.x) + math.abs(fwd.y)) > 0.01 then
            return DKNormalizeYaw(math.deg(DKAtan2(fwd.y, fwd.x)))
        end
    end

    if ent.GetAnglesAsVector ~= nil then
        local ok, ang = pcall(function() return ent:GetAnglesAsVector() end)
        if ok and ang ~= nil then
            return DKNormalizeYaw(ang.y or 0)
        end
    end

    return nil
end
function DotaKartController:GetFinishLineGateEntity()
    local ent = Entities:FindByName(nil, "finish_line_gate")
    if ent ~= nil then return ent end
    ent = Entities:FindByClassname(nil, "finish_line_gate")
    return ent
end

function DotaKartController:GetYawTowardFinishLineFrom(pos)
    if pos == nil then return nil end
    local gate = self:GetFinishLineGateEntity()
    if gate == nil then return nil end
    local gpos = gate:GetAbsOrigin()
    local dx = gpos.x - pos.x
    local dy = gpos.y - pos.y
    if (dx * dx + dy * dy) < 16 then return nil end
    return DKNormalizeYaw(math.deg(DKAtan2(dy, dx)))
end


function DotaKartController:GetNearestTrackIndex(pos)
    if pos == nil or self.hud == nil or self.hud.trackWorldPoints == nil then return 1 end
    local bestIndex = 1
    local bestDistSq = nil
    for i, p in ipairs(self.hud.trackWorldPoints) do
        local dx = pos.x - p.x
        local dy = pos.y - p.y
        local dsq = dx * dx + dy * dy
        if bestDistSq == nil or dsq < bestDistSq then
            bestDistSq = dsq
            bestIndex = i
        end
    end
    return bestIndex
end

function DotaKartController:GetStartPositionAndYaw(playerID, hero)
    local ent, name = self:GetPlayerStartEntity(playerID)
    if ent ~= nil then
        local rawPos = ent:GetAbsOrigin()
        local pos = Vector(rawPos.x, rawPos.y, GetGroundHeight(rawPos, hero) + (self.config.ground_z_offset or 20))
        -- FIX49: na largada, sempre tenta apontar o kart para a linha de chegada.
        -- Isso resolve start_position sem rotação ou com rotação errada no Hammer.
        local yaw = self:GetYawTowardFinishLineFrom(pos) or self:GetYawFromEntity(ent)

        -- Se não houver finish_line_gate e a entidade não tiver rotação útil,
        -- aponta para o próximo dk_track_* mais próximo.
        if yaw == nil and self.hud ~= nil and self.hud.trackWorldPoints ~= nil and #self.hud.trackWorldPoints >= 2 then
            local idx = self:GetNearestTrackIndex(pos)
            local nextIdx = idx + 1
            if nextIdx > #self.hud.trackWorldPoints then nextIdx = 1 end
            local nextPoint = self.hud.trackWorldPoints[nextIdx]
            if nextPoint ~= nil then
                yaw = DKNormalizeYaw(math.deg(DKAtan2(nextPoint.y - pos.y, nextPoint.x - pos.x)))
            end
        end

        return pos, yaw, name
    end

    if self.hud == nil or self.hud.trackWorldPoints == nil or #self.hud.trackWorldPoints < 1 then
        return nil, nil, nil
    end

    local start = self.hud.trackWorldPoints[1]
    local yaw = nil
    if #self.hud.trackWorldPoints >= 2 then
        local p2 = self.hud.trackWorldPoints[2]
        yaw = DKNormalizeYaw(math.deg(DKAtan2(p2.y - start.y, p2.x - start.x)))
    end

    local offset = (tonumber(playerID) or 0) * 96
    local pos = Vector(start.x + offset, start.y, GetGroundHeight(start, hero) + (self.config.ground_z_offset or 20))
    yaw = self:GetYawTowardFinishLineFrom(pos) or yaw
    return pos, yaw, "dk_track_001_fallback"
end

function DotaKartController:TeleportAllToTrackStart()
    if self.hud == nil or self.hud.trackWorldPoints == nil or #self.hud.trackWorldPoints < 1 then
        print("[DotaKartController] Sem dk_track_001 para teleportar.")
        return
    end

    for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        local hero = self:GetHeroForPlayer(playerID)
        if DKValidUnit(hero) then
            local pos, yaw, sourceName = self:GetStartPositionAndYaw(playerID, hero)
            if pos ~= nil then
                FindClearSpaceForUnit(hero, pos, true)

                local st = self:GetState(playerID)
                st.speed = 0
                st.yaw = yaw or st.yaw or 0
                self:SetHeroFacing(hero, st.yaw)

                if self.config.debug then
                    print("[DotaKartController] Player " .. tostring(playerID) .. " largada=" .. tostring(sourceName) .. " yaw=" .. tostring(math.floor(st.yaw or 0)))
                end
            end
        end
    end

    print("[DotaKartController] Karts teleportados para player1_start_position...player8_start_position ou fallback dk_track_001.")
end

function DotaKartController:HardStopAll()
    for playerID, st in pairs(self.states) do
        st.speed = 0
        st.input.forward = false
        st.input.reverse = false
        st.input.left = false
        st.input.right = false

        local hero = self:GetHeroForPlayer(playerID)
        if DKValidUnit(hero) and hero.Stop ~= nil then
            hero:Stop()
        end
    end
end

function DotaKartController:IsControlledHero(unit)
    if not DKValidUnit(unit) then return false end
    for _, hero in pairs(self.heroes) do
        if DKValidUnit(hero) and hero == unit then
            return true
        end
    end
    return false
end

function DotaKartController:OrderFilter(keys)
    if not self.enabled or not self.config.block_default_move_orders then
        return true
    end

    local orderType = keys.order_type
    if not DK_BLOCKED_ORDERS[orderType] then
        return true
    end

    if keys.units ~= nil then
        for _, entIndex in pairs(keys.units) do
            local unit = nil
            local n = tonumber(entIndex)
            if n ~= nil then
                local ok, h = pcall(EntIndexToHScript, n)
                if ok then unit = h end
            elseif entIndex ~= nil and entIndex.IsNull ~= nil then
                unit = entIndex
            end

            if self:IsControlledHero(unit) then
                return false
            end
        end
    end

    return true
end

function DotaKartController:UpdateKart(playerID, hero, st, dt, now)
    if not DKValidUnit(hero) then return end

    -- FIX42: jogador que cruzou a chegada sai do mapa e não deve continuar recebendo física/controle.
    if GameRules ~= nil and GameRules.DotaKartHUD ~= nil and GameRules.DotaKartHUD.IsPlayerFinished ~= nil and GameRules.DotaKartHUD:IsPlayerFinished(playerID) then
        st.speed = 0
        st.input.forward = false
        st.input.reverse = false
        st.input.left = false
        st.input.right = false
        return
    end

    self:ApplyKartModifier(hero)
    self:SuppressDotaAutoAttack(hero)

    if st.yaw == nil then
        st.yaw = self:GetTrackYawForHero(hero) or self:GetUnitYaw(hero) or 0
    end

    -- FIX26: stun de corrida desacelera e gira; item fica bloqueado no UseItem.
    if (st.stunned_until or 0) > now then
        self:UpdateStunnedKart(playerID, hero, st, dt, now)
        return
    elseif st.was_stunned == true then
        st.was_stunned = false
        st.speed = 0
        self:SetHeroFacing(hero, st.yaw or self:GetUnitYaw(hero) or 0)
    end

    -- Meat Hook/Hookshot podem travar o kart temporariamente enquanto outro sistema move o herói.
    if (st.locked_until or 0) > now then
        st.speed = 0
        return
    end

    -- FIX72: root de corrida impede movimento, mas não bloqueia todos os itens.
    if (st.rooted_until or 0) > now then
        st.speed = 0
        st.input.forward = false
        st.input.reverse = false
        self:SetHeroFacing(hero, st.yaw or self:GetUnitYaw(hero) or 0)
        return
    end

    local input = st.input or {}
    local throttle = 0
    if input.forward then throttle = throttle + 1 end
    if input.reverse then throttle = throttle - 1 end

    local pos = hero:GetAbsOrigin()
    if (st.spectral_unobstructed_until or st.spectral_path_buff_until or 0) > now then
        st.spectral_last_active_time = math.max(tonumber(st.spectral_last_active_time or 0) or 0, tonumber(st.spectral_unobstructed_until or st.spectral_path_buff_until or now) or now)
        self:RememberSpectralSafeTrackPoint(playerID, hero, st, pos)
    else
        if self:RecoverSpectralIfStuck(playerID, hero, st, now) then return end
    end
    local offroad = self:GetOffroadInfo(playerID, hero, pos, now)

    local boosting = now < (st.boost_until or 0)
    local maxSpeed = boosting and self.config.boost_max_speed or self.config.max_speed
    -- FIX19: itens podem forçar max speed maior que o boost padrão.
    if (st.item_max_speed_until or 0) > now and (st.item_max_speed or 0) > maxSpeed then
        maxSpeed = st.item_max_speed
    end
    -- FIX91: bônus de velocidade do Shadow Path da Spectral Dagger.
    if (st.spectral_path_buff_until or 0) > now then
        local bonus = tonumber(st.spectral_path_bonus_pct or 0.10) or 0.10
        maxSpeed = maxSpeed * (1.0 + bonus)
        st.spectral_last_active_time = math.max(tonumber(st.spectral_last_active_time or 0) or 0, st.spectral_path_buff_until or now)
    end
    local reverseMax = self.config.reverse_max_speed

    if offroad ~= nil and offroad.active == true then
        local f = tonumber(self.config.offroad_speed_factor) or 0.66
        local rf = tonumber(self.config.offroad_reverse_speed_factor) or 0.78
        maxSpeed = math.max(160, maxSpeed * f)
        reverseMax = math.max(90, reverseMax * rf)
        st.offroad_until = now + 0.20
        st.offroad_reason = offroad.reason
        if (st.speed or 0) > maxSpeed then
            st.speed = DKApproach(st.speed or 0, maxSpeed, (self.config.offroad_extra_friction or 620) * dt)
        end
        if self.config.offroad_debug and now - (st.last_offroad_debug or 0) > 1.0 then
            st.last_offroad_debug = now
            print("[DotaKartController] off-road p" .. tostring(playerID) .. " reason=" .. tostring(offroad.reason) .. " max=" .. tostring(math.floor(maxSpeed)))
        end
    end

    -- FIX34: slow de corrida (Venomous Gale). O slow começa forte e recupera aos poucos.
    local slowPct = 0
    if self.GetKartSlowPct ~= nil then
        slowPct = self:GetKartSlowPct(playerID, now)
    end
    if slowPct > 0 then
        maxSpeed = math.max(90, maxSpeed * (1.0 - slowPct))
        reverseMax = math.max(80, reverseMax * (1.0 - slowPct * 0.55))
        if (st.speed or 0) > maxSpeed then
            st.speed = DKApproach(st.speed or 0, maxSpeed, (self.config.friction or 540) * 1.8 * dt)
        end
    end

    if throttle > 0 then
        local accel = self.config.acceleration
        if offroad ~= nil and offroad.active == true then accel = accel * (tonumber(self.config.offroad_accel_factor) or 0.70) end
        st.speed = st.speed + accel * dt
    elseif throttle < 0 then
        if st.speed > 45 then
            -- S funciona primeiro como freio quando o kart ainda está indo para frente.
            st.speed = st.speed - self.config.brake_acceleration * dt
        else
            st.speed = st.speed - self.config.reverse_acceleration * dt
        end
    else
        local fric = self.config.friction
        if offroad ~= nil and offroad.active == true then fric = fric + (tonumber(self.config.offroad_extra_friction) or 620) end
        st.speed = DKApproach(st.speed, 0, fric * dt)
    end

    st.speed = DKClamp(st.speed, -reverseMax, maxSpeed)

    local steer = 0
    if input.left then steer = steer + 1 end
    if input.right then steer = steer - 1 end

    if steer ~= 0 then
        local absSpeed = math.abs(st.speed)
        local speedFactor = DKClamp(absSpeed / math.max(1, self.config.max_speed), self.config.turn_at_zero_factor, 1.0)

        -- Em ré, a direção fica estilo carro: A/D inverte.
        local reverseSteer = 1
        if st.speed < -10 then reverseSteer = -1 end

        st.yaw = DKNormalizeYaw(st.yaw + steer * self.config.turn_rate * speedFactor * reverseSteer * self.config.steering_sign * dt)
    end

    if offroad ~= nil and offroad.active == true and math.abs(st.speed or 0) >= (tonumber(self.config.offroad_min_speed_for_instability) or 180) then
        local wobble = math.sin(now * 10.0 + (tonumber(playerID) or 0) * 2.17)
        local power = DKClamp(math.abs(st.speed or 0) / math.max(1, self.config.max_speed or 880), 0.20, 1.0)
        st.yaw = DKNormalizeYaw(st.yaw + wobble * (tonumber(self.config.offroad_instability_yaw) or 52) * power * dt)
    end

    local rad = math.rad(st.yaw)
    local forward = Vector(math.cos(rad), math.sin(rad), 0)
    local moveDir = forward
    local nextPos = pos + forward * (st.speed * dt)

    -- FIX30: derrapagem em alta velocidade. Ao virar rápido, o kart desliza para fora da curva.
    if self.config.drift_enabled and steer ~= 0 and (st.speed or 0) > (tonumber(self.config.drift_min_speed) or 560) then
        local driftMin = tonumber(self.config.drift_min_speed) or 560
        local denom = math.max(1, (self.config.max_speed or 880) - driftMin)
        local driftPower = DKClamp(((st.speed or 0) - driftMin) / denom, 0, 1)
        local right = Vector(forward.y, -forward.x, 0)
        local lateral = right * (steer * (st.speed or 0) * (tonumber(self.config.drift_lateral_factor) or 0.34) * driftPower * dt)
        nextPos = nextPos + lateral
        moveDir = DKNormalize2DVec((nextPos - pos), forward)
        st.speed = st.speed * (tonumber(self.config.drift_speed_loss_factor) or 0.985)
    end

    if offroad ~= nil and offroad.active == true and math.abs(st.speed or 0) >= (tonumber(self.config.offroad_min_speed_for_instability) or 180) then
        local power = DKClamp(math.abs(st.speed or 0) / math.max(1, self.config.max_speed or 880), 0.20, 1.0)
        local right = Vector(forward.y, -forward.x, 0)
        local wobble = math.sin(now * 8.0 + (tonumber(playerID) or 0) * 1.39)
        local lateral = right * (wobble * (tonumber(self.config.offroad_lateral_drift) or 95) * power * dt)
        nextPos = nextPos + lateral
        moveDir = DKNormalize2DVec((nextPos - pos), forward)
    end

    nextPos.z = GetGroundHeight(nextPos, hero) + self.config.ground_z_offset

    nextPos = self:ApplyKartCollisionPhysics(playerID, hero, st, pos, nextPos, moveDir, dt, now)
    hero:SetAbsOrigin(nextPos)
    nextPos = self:ApplyCustomKartVisualGroundOffset(hero, nextPos)
    self:SetHeroFacing(hero, st.yaw)

    -- FIX15: não chamar hero:Stop() em loop. Isso cortava animações e parecia spam de ordem.

    if now - (st.last_resolve_time or 0) >= self.config.resolve_collision_interval then
        ResolveNPCPositions(nextPos, 96)
        st.last_resolve_time = now
    end

    if self.config.debug and now - (st.last_debug_time or 0) >= 1.5 then
        st.last_debug_time = now
        -- Debug leve, sem spam absurdo.
        -- print("[DotaKartController] p" .. tostring(playerID) .. " speed=" .. tostring(math.floor(st.speed)) .. " yaw=" .. tostring(math.floor(st.yaw)))
    end
end

function DotaKartController:OnThink()
    local now = DKNow()
    local dt = now - (self._lastThinkTime or now)
    self._lastThinkTime = now
    dt = DKClamp(dt, 0.001, 0.10)

    if self.enabled then
        local processed = {}

        -- Jogadores reais.
        for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
            if PlayerResource:IsValidPlayerID(playerID) then
                local hero = self:GetHeroForPlayer(playerID)
                if DKValidUnit(hero) then
                    local st = self:GetState(playerID)

                    -- FIX68: se este PlayerResource pertence a IA publica integrada,
                    -- nao aplica o movimento manual do controller por cima da IA.
                    -- Mantem somente stun/lock/modifier, para efeitos de corrida continuarem.
                    if self:IsPublicAIControlled(playerID, hero) then
                        if (st.stunned_until or 0) > now or st.was_stunned == true or (st.locked_until or 0) > now then
                            self:UpdateKart(playerID, hero, st, dt, now)
                        else
                            self:ApplyKartModifier(hero)
                            self:SuppressDotaAutoAttack(hero)
                        end
                    else
                        self:UpdateKart(playerID, hero, st, dt, now)
                    end

                    processed[playerID] = true
                end
            end
        end

        -- FIX26: AutoBots criados por script não são PlayerResource válido,
        -- mas precisam receber stun/spin/autoattack-off pelo controller.
        for playerID, hero in pairs(self.heroes or {}) do
            if processed[playerID] ~= true and DKValidUnit(hero) then
                local st = self:GetState(playerID)

                -- FIX68: IA publica controla seu proprio movimento e chama UpdateKart durante stun.
                -- Aqui só mantemos o modifier/supressão para não duplicar deslocamento.
                if self:IsPublicAIControlled(playerID, hero) then
                    self:ApplyKartModifier(hero)
                    self:SuppressDotaAutoAttack(hero)
                elseif (st.stunned_until or 0) > now or st.was_stunned == true or (st.locked_until or 0) > now then
                    self:UpdateKart(playerID, hero, st, dt, now)
                else
                    self:ApplyKartModifier(hero)
                    self:SuppressDotaAutoAttack(hero)
                end
            end
        end
    end

    return self.config.tick_rate
end

-- Modifier invisível para reduzir interferência do movimento normal do Dota.
modifier_dotakart_kart_controlled = class({})

function modifier_dotakart_kart_controlled:IsHidden() return true end
function modifier_dotakart_kart_controlled:IsPurgable() return false end
function modifier_dotakart_kart_controlled:RemoveOnDeath() return false end

function modifier_dotakart_kart_controlled:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE,
        MODIFIER_PROPERTY_MOVESPEED_LIMIT,
        MODIFIER_PROPERTY_IGNORE_MOVESPEED_LIMIT,
        MODIFIER_PROPERTY_DISABLE_AUTOATTACK
    }
end

function modifier_dotakart_kart_controlled:GetModifierMoveSpeed_Absolute()
    return 1
end

function modifier_dotakart_kart_controlled:GetModifierMoveSpeed_Limit()
    return 1
end

function modifier_dotakart_kart_controlled:GetModifierIgnoreMovespeedLimit()
    return 1
end

function modifier_dotakart_kart_controlled:GetDisableAutoAttack()
    return 1
end

function modifier_dotakart_kart_controlled:CheckState()
    return {
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true,
        [MODIFIER_STATE_DISARMED] = true
    }
end
