-- DotA Kart Public AI
-- FIX58: IA de corrida publica separada do AutoDrive de teste.
-- Pasta isolada: dotakart/ai/. Nao substitui auto_drive.lua.

if DotaKartPublicAI == nil then
    DotaKartPublicAI = class({})
end

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

local function DKApproach(current, target, delta)
    current = tonumber(current) or 0
    target = tonumber(target) or 0
    delta = math.max(0, tonumber(delta) or 0)
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

local function DKDistance2D(a, b)
    if a == nil or b == nil then return 999999 end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

local function DKLength2D(v)
    if v == nil then return 0 end
    return math.sqrt((v.x or 0) * (v.x or 0) + (v.y or 0) * (v.y or 0))
end

local function DKNormalize2D(v, fallback)
    local len = DKLength2D(v)
    if len <= 0.001 then return fallback or Vector(1, 0, 0) end
    return Vector((v.x or 0) / len, (v.y or 0) / len, 0)
end

local function DKGround(pos, unit)
    return Vector(pos.x, pos.y, GetGroundHeight(pos, unit))
end

local function DKRandomFloat(a, b)
    if RandomFloat ~= nil then return RandomFloat(a, b) end
    return a + (b - a) * math.random()
end

local function DKRandomInt(a, b)
    if RandomInt ~= nil then return RandomInt(a, b) end
    return math.random(a, b)
end

function DotaKartPublicAI:Init(gameMode, hud, controller, itemSystem)
    self.gameMode = gameMode
    self.hud = hud or GameRules.DotaKartHUD
    self.controller = controller or GameRules.DotaKartController
    self.itemSystem = itemSystem or GameRules.DotaKartItemSystem

    self.config = {
        enabled = DOTA_KART_PUBLIC_AI ~= false,
        max_players = tonumber(DOTA_KART_MAX_PLAYERS or 8) or 8,
        host_player_id = 0,
        default_laps = DKClamp(DOTA_KART_PUBLIC_AI_DEFAULT_LAPS or 3, 2, 5),
        min_laps = 2,
        max_laps = 5,
        default_bot_count = tonumber(DOTA_KART_PUBLIC_AI_BOT_COUNT or -1) or -1,
        min_bots = 0,
        max_bots = math.max(0, math.min(7, (tonumber(DOTA_KART_MAX_PLAYERS or 8) or 8) - 1)),
        setup_hold_seconds = tonumber(DOTA_KART_PUBLIC_AI_SETUP_HOLD_SECONDS or 0.0) or 0.0,
        tick_rate = 0.05,
        arrive_distance = 190,
        item_box_search_radius = 1150,
        item_box_use_ahead_radius = 780,
        item_enemy_behind_radius = 1050,
        item_use_check_min = 0.25,
        item_use_check_max = 0.65,
        same_speed_as_players = true,
        use_real_hero_bots = DOTA_KART_PUBLIC_AI_USE_REAL_HERO_BOTS ~= false,
        -- FIX69: visual proxy/prop_dynamic do FIX66 fica totalmente removido.
        -- Bots públicos agora são heróis reais integrados; o modelo do próprio herói deve ser preservado.
        visual_proxy = false,
        overtake_range = 760,
        overtake_side_offset = 230,
        overtake_hold_min = 1.10,
        overtake_hold_max = 1.90,
        overtake_check_interval = 0.18,
        debug = DOTA_KART_PUBLIC_AI_DEBUG == true
    }

    if self.config.default_bot_count < 0 then self.config.default_bot_count = -1 end
    if self.config.default_bot_count > self.config.max_bots then self.config.default_bot_count = self.config.max_bots end

    self.settings = {
        laps = self.config.default_laps,
        bot_count = self.config.default_bot_count
    }

    self.bots = {}
    self.track = {}
    self.running = false
    self._thinkStarted = false
    self.setupWindowStart = nil
    self.setupLocked = false

    -- FIX68: tabelas globais usadas pelo DotaKartController para reconhecer bots
    -- publicos integrados via fake client e impedir movimento duplicado.
    self.publicAIPlayerIDs = {}
    self.publicAIUnitEnts = {}
    _G.DOTA_KART_PUBLIC_AI_PLAYER_IDS = _G.DOTA_KART_PUBLIC_AI_PLAYER_IDS or {}
    _G.DOTA_KART_PUBLIC_AI_UNIT_ENTS = _G.DOTA_KART_PUBLIC_AI_UNIT_ENTS or {}

    pcall(function() self:CleanupLegacyVisualProxies() end)

    print("[DotaKartPublicAI] Sistema iniciado. enabled=" .. tostring(self.config.enabled) .. " laps=" .. tostring(self.settings.laps) .. " bots=" .. tostring(self.settings.bot_count))
end

function DotaKartPublicAI:GetConfiguredLaps()
    return DKClamp(self.settings and self.settings.laps or self.config.default_laps or 3, self.config.min_laps or 2, self.config.max_laps or 5)
end

function DotaKartPublicAI:SetConfiguredLaps(laps, source)
    laps = math.floor(DKClamp(laps, self.config.min_laps or 2, self.config.max_laps or 5))
    self.settings.laps = laps
    if self.hud ~= nil and self.hud.SetMaxLapsForRace ~= nil then
        pcall(function() self.hud:SetMaxLapsForRace(laps) end)
    end
    print("[DotaKartPublicAI] Voltas configuradas pelo host = " .. tostring(laps) .. " source=" .. tostring(source or ""))
    self:BroadcastHostSettings()
    return laps
end

function DotaKartPublicAI:GetConfiguredBotCount()
    local value = tonumber(self.settings and self.settings.bot_count or -1) or -1
    if value < 0 then return -1 end
    return math.floor(DKClamp(value, self.config.min_bots or 0, self.config.max_bots or 7))
end

function DotaKartPublicAI:SetConfiguredBotCount(count, source)
    count = tonumber(count)
    if count == nil or count < 0 then
        count = -1
    else
        count = math.floor(DKClamp(count, self.config.min_bots or 0, self.config.max_bots or 7))
    end

    self.settings.bot_count = count
    print("[DotaKartPublicAI] Computadores configurados pelo host = " .. tostring(count < 0 and "preencher vazios" or count) .. " source=" .. tostring(source or ""))

    if self.setupLocked ~= true and self.running ~= true then
        self:RemoveBotsNotAllowed()
    end

    self:BroadcastHostSettings()
    return count
end

function DotaKartPublicAI:GetSetupRemainingSeconds()
    if self.setupLocked == true then return 0 end
    local hold = tonumber(self.config.setup_hold_seconds or 0) or 0
    if hold <= 0 then return 0 end
    if self.setupWindowStart == nil then return hold end
    local left = hold - (DKNow() - self.setupWindowStart)
    if left < 0 then left = 0 end
    return left
end

function DotaKartPublicAI:ShouldDelayCountdownForHostSetup()
    if not self.config.enabled then return false, 0 end
    if self.setupLocked == true then return false, 0 end
    local hold = tonumber(self.config.setup_hold_seconds or 0) or 0
    if hold <= 0 then return false, 0 end
    if self.setupWindowStart == nil then
        self.setupWindowStart = DKNow()
        self:BroadcastHostSettings()
    end
    local left = self:GetSetupRemainingSeconds()
    self:BroadcastHostSettings()
    return left > 0.01, left
end

function DotaKartPublicAI:LockHostSetup()
    self.setupLocked = true
    self:BroadcastHostSettings()
end

function DotaKartPublicAI:BroadcastHostSettings()
    if CustomGameEventManager == nil then return end
    local payload = {
        laps = self:GetConfiguredLaps(),
        min_laps = self.config.min_laps or 2,
        max_laps = self.config.max_laps or 5,
        host_player_id = self.config.host_player_id or 0,
        setup_screen = DOTA_KART_PUBLIC_SETUP_SCREEN == true and 1 or 0,
        bots_enabled = self.config.enabled and 1 or 0,
        bot_count = self:GetConfiguredBotCount(),
        max_bots = self.config.max_bots or 7,
        fill_empty_slots = self:GetConfiguredBotCount() < 0 and 1 or 0,
        setup_remaining = math.ceil(self:GetSetupRemainingSeconds()),
        locked = self.setupLocked == true and 1 or 0,
        race_started = (self.gameMode ~= nil and self.gameMode.raceStarted == true) and 1 or 0,
        max_players = self.config.max_players or 8
    }

    -- FIX61: junto com as configurações do host, envia também o estado da seleção de equipes
    -- para a UI GameSetup custom reconstruir os slots sem depender da tela padrão do Dota.
    if self.gameMode ~= nil and self.gameMode.AppendSetupState ~= nil then
        pcall(function() self.gameMode:AppendSetupState(payload) end)
    end

    CustomGameEventManager:Send_ServerToAllClients("dotakart_host_settings_update", payload)
end

function DotaKartPublicAI:OnHostSettingsEvent(keys)
    keys = keys or {}
    local playerID = tonumber(keys.PlayerID or keys.player_id or keys.playerID or -1) or -1

    if tonumber(keys.request or 0) == 1 then
        self:BroadcastHostSettings()
        return
    end

    if playerID < 0 and tonumber(keys.setup_screen_event or 0) == 1 then
        -- FIX60: em algumas versões do painel GameSetup o eventSourceIndex/PlayerID chega indefinido.
        -- Aceita como fallback para o host para não deixar os botões mortos; clientes com PlayerID
        -- válido continuam sendo validados normalmente abaixo.
        print("[DotaKartPublicAI] PlayerID indefinido no GameSetup; aceitando como fallback de host.")
        playerID = self.config.host_player_id or 0
    end

    if playerID ~= (self.config.host_player_id or 0) then
        print("[DotaKartPublicAI] Ignorando settings de player nao-host: " .. tostring(playerID))
        self:BroadcastHostSettings()
        return
    end

    if self.setupLocked == true or (self.gameMode ~= nil and self.gameMode.raceStarted == true) then
        self:BroadcastHostSettings()
        return
    end

    if keys.laps ~= nil then
        self:SetConfiguredLaps(tonumber(keys.laps) or self:GetConfiguredLaps(), "panorama_host")
    end

    if keys.bot_count ~= nil then
        self:SetConfiguredBotCount(tonumber(keys.bot_count), "panorama_host")
    end

    if tonumber(keys.lock or 0) == 1 then
        self:LockHostSetup()
    else
        self:BroadcastHostSettings()
    end
end

function DotaKartPublicAI:LoadTrackPoints()
    local hud = self.hud or GameRules.DotaKartHUD
    if hud == nil then return false end
    if hud.trackWorldPoints == nil or #hud.trackWorldPoints < 2 then
        hud:BuildTrackPathFromEntities("dk_track_", 1024, true, 512)
    end
    self.track = hud.trackWorldPoints or {}
    if #self.track < 2 then
        print("[DotaKartPublicAI] ERRO: nenhum caminho dk_track_ suficiente para bots.")
        return false
    end
    return true
end

function DotaKartPublicAI:IsFakeClientPlayerID(playerID)
    playerID = tonumber(playerID) or -1
    if playerID < 0 or PlayerResource == nil then return false end
    local fake = false
    if PlayerResource.IsFakeClient ~= nil then
        pcall(function() fake = PlayerResource:IsFakeClient(playerID) == true end)
    end
    return fake == true
end

function DotaKartPublicAI:IsHumanSlotOccupied(slot)
    slot = tonumber(slot) or -1
    if slot < 0 then return false end
    if PlayerResource == nil or PlayerResource.IsValidPlayerID == nil then return false end
    if not PlayerResource:IsValidPlayerID(slot) then return false end

    -- FIX67: bots criados como fake clients pelo AddBotPlayerWithEntityScript não devem
    -- bloquear os slots da IA pública como se fossem jogadores humanos.
    if self:IsFakeClientPlayerID(slot) then return false end

    local player = nil
    pcall(function() player = PlayerResource:GetPlayer(slot) end)
    local steam = 0
    pcall(function() steam = PlayerResource:GetSteamAccountID(slot) or 0 end)
    local conn = nil
    pcall(function() conn = PlayerResource:GetConnectionState(slot) end)

    if conn == DOTA_CONNECTION_STATE_DISCONNECTED or conn == DOTA_CONNECTION_STATE_ABANDONED then
        return false
    end

    return player ~= nil or (tonumber(steam) or 0) > 0 or conn == DOTA_CONNECTION_STATE_CONNECTED or conn == DOTA_CONNECTION_STATE_LOADING
end

function DotaKartPublicAI:GetStartPositionForSlot(slot)
    local controller = self.controller or GameRules.DotaKartController
    if controller ~= nil and controller.GetPlayerStartEntity ~= nil then
        local ent = controller:GetPlayerStartEntity(slot)
        if ent ~= nil then return DKGround(ent:GetAbsOrigin(), nil) end
    end

    local names = {
        "player" .. tostring((tonumber(slot) or 0) + 1) .. "_start_position",
        "player_" .. tostring((tonumber(slot) or 0) + 1) .. "_start_position"
    }
    for _, name in ipairs(names) do
        local ent = Entities:FindByName(nil, name)
        if ent ~= nil then return DKGround(ent:GetAbsOrigin(), nil) end
    end

    if self.track ~= nil and #self.track >= 1 then
        local p = self.track[1]
        local offset = (tonumber(slot) or 0) * 105
        return DKGround(Vector(p.x + offset, p.y + offset * 0.35, p.z), nil)
    end

    return Vector(0, 0, 0)
end

function DotaKartPublicAI:GetRaceTeamForSlot(slot)
    if self.gameMode ~= nil and self.gameMode.GetRaceTeamForSlot ~= nil then
        return self.gameMode:GetRaceTeamForSlot(slot)
    end
    if slot == 0 then return DOTA_TEAM_GOODGUYS end
    if slot == 1 then return DOTA_TEAM_BADGUYS end
    local customTeam = _G["DOTA_TEAM_CUSTOM_" .. tostring((tonumber(slot) or 0) + 1)]
    return customTeam
end

function DotaKartPublicAI:GetHumanMaxSpeed()
    local controller = self.controller or GameRules.DotaKartController
    if controller ~= nil and controller.config ~= nil and controller.config.max_speed ~= nil then
        return tonumber(controller.config.max_speed) or 880
    end
    return 880
end

function DotaKartPublicAI:GetHumanAcceleration()
    local controller = self.controller or GameRules.DotaKartController
    if controller ~= nil and controller.config ~= nil and controller.config.acceleration ~= nil then
        return tonumber(controller.config.acceleration) or 820
    end
    return 820
end


function DotaKartPublicAI:GetDefaultVisualHeroPool()
    -- FIX88: somente Invoker usa custom hero; os outros pilotos usam heróis padrão
    -- até seus modelos custom estarem prontos.
    return {
        "npc_dota_hero_dotakart_invoker",
        "npc_dota_hero_brewmaster",
        "npc_dota_hero_tinker",
        "npc_dota_hero_lina",
        "npc_dota_hero_pudge",
        "npc_dota_hero_tiny",
        "npc_dota_hero_mirana",
        "npc_dota_hero_juggernaut"
    }
end

function DotaKartPublicAI:GetConfiguredHeroPool()
    local source = DOTA_KART_AI_HERO_POOL
    local out = {}
    if type(source) == "table" then
        for _, heroName in ipairs(source) do
            if heroName ~= nil and heroName ~= "" and heroName ~= "npc_dota_hero_rattletrap" then
                table.insert(out, heroName)
            end
        end
    end

    -- Se por qualquer motivo a tabela global vier vazia/só Clock, usa a pool interna.
    if #out <= 0 then
        out = self:GetDefaultVisualHeroPool()
    end

    -- FIX84: não adiciona Clock/Rattletrap como fallback; bots públicos devem usar
    -- somente os 8 pilotos oficiais definidos pelo DotA Kart.
    return out
end

function DotaKartPublicAI:GetCanonicalHeroKey(heroName)
    heroName = tostring(heroName or "")
    if heroName == "" then return "" end
    -- FIX98: Invoker custom e Invoker base contam como o mesmo piloto.
    if heroName == "npc_dota_hero_dotakart_invoker" or heroName == "npc_dota_hero_invoker" then
        return "npc_dota_hero_invoker"
    end
    local baseMap = DOTA_KART_KART_BASE_HERO or {}
    if baseMap[heroName] ~= nil and baseMap[heroName] ~= "" then
        return tostring(baseMap[heroName])
    end
    return heroName
end

function DotaKartPublicAI:MarkHeroNameUsed(used, heroName)
    if used == nil then return end
    heroName = tostring(heroName or "")
    if heroName == "" then return end
    used[heroName] = true
    local key = self:GetCanonicalHeroKey(heroName)
    if key ~= nil and key ~= "" then used[key] = true end
end

function DotaKartPublicAI:IsHeroNameUsed(used, heroName)
    if used == nil then return false end
    heroName = tostring(heroName or "")
    if heroName == "" then return false end
    if used[heroName] == true then return true end
    local key = self:GetCanonicalHeroKey(heroName)
    return key ~= nil and key ~= "" and used[key] == true
end

function DotaKartPublicAI:GetBotHeroCandidates(slot)
    local pool = self:GetConfiguredHeroPool()
    local humanUsed = self:GetHumanHeroNames()
    local botUsed = self:GetBotHeroNames()
    local used = {}
    for k, v in pairs(humanUsed or {}) do if v == true then used[k] = true end end
    for k, v in pairs(botUsed or {}) do if v == true then used[k] = true end end

    local candidates = {}

    -- FIX98: 1 personagem por jogador/piloto. Invoker custom e Invoker base contam como o mesmo piloto.
    for _, heroName in ipairs(pool) do
        if heroName ~= nil and heroName ~= "" and heroName ~= "npc_dota_hero_rattletrap" and not self:IsHeroNameUsed(used, heroName) then
            table.insert(candidates, heroName)
        end
    end
    for _, heroName in ipairs(pool) do
        if heroName ~= nil and heroName ~= "" and heroName == "npc_dota_hero_rattletrap" and not self:IsHeroNameUsed(used, heroName) then
            table.insert(candidates, heroName)
        end
    end

    -- Se todas as opções estiverem usadas, ainda respeita humanos e tenta sobras não-humanas.
    if #candidates <= 0 then
        for _, heroName in ipairs(pool) do
            if heroName ~= nil and heroName ~= "" and heroName ~= "npc_dota_hero_rattletrap" and not self:IsHeroNameUsed(humanUsed, heroName) then
                table.insert(candidates, heroName)
            end
        end
        for _, heroName in ipairs(pool) do
            if heroName ~= nil and heroName ~= "" and heroName == "npc_dota_hero_rattletrap" and not self:IsHeroNameUsed(humanUsed, heroName) then
                table.insert(candidates, heroName)
            end
        end
    end

    if #candidates <= 0 then
        for _, heroName in ipairs(pool) do
            if heroName ~= nil and heroName ~= "" and heroName ~= "npc_dota_hero_rattletrap" then
                table.insert(candidates, heroName)
            end
        end
    end

    if #candidates <= 0 then candidates = { "npc_dota_hero_pudge" } end

    -- Evita Clock na IA publica enquanto existirem outras opções.
    if #candidates > 1 then
        local noClock = {}
        for _, heroName in ipairs(candidates) do
            if heroName ~= "npc_dota_hero_rattletrap" then table.insert(noClock, heroName) end
        end
        if #noClock > 0 then candidates = noClock end
    end


    -- Rotaciona a lista por slot/tempo para não ficar sempre no primeiro nome após hot reload.
    local shift = ((tonumber(slot) or 0) * 3 + math.floor((DKNow() or 0) * 10)) % #candidates
    if shift > 0 then
        local rotated = {}
        for i = 1, #candidates do
            local idx = ((i + shift - 1) % #candidates) + 1
            table.insert(rotated, candidates[idx])
        end
        candidates = rotated
    end

    return candidates
end

function DotaKartPublicAI:GetHumanHeroNames()
    local used = {}
    local maxPlayers = math.min(8, tonumber(self.config.max_players or DOTA_KART_MAX_PLAYERS or 8) or 8)
    for playerID = 0, maxPlayers - 1 do
        if self:IsHumanSlotOccupied(playerID) and PlayerResource ~= nil then
            local hero = nil
            pcall(function() hero = PlayerResource:GetSelectedHeroEntity(playerID) end)
            if DKValidUnit(hero) then
                local name = hero:GetUnitName()
                self:MarkHeroNameUsed(used, name)
            end
        end
    end
    return used
end

function DotaKartPublicAI:GetBotHeroNames()
    local used = {}
    for _, bot in pairs(self.bots or {}) do
        if bot ~= nil and DKValidUnit(bot.unit) then
            local name = bot.hero_name or bot.display_hero_name
            if (name == nil or name == "") and self.unitHeroOverrides ~= nil then
                local ent = -1
                pcall(function() ent = bot.unit:entindex() end)
                name = self.unitHeroOverrides[ent]
            end
            if (name == nil or name == "") and _G.DOTA_KART_UNIT_HERO_OVERRIDES ~= nil then
                local ent = -1
                pcall(function() ent = bot.unit:entindex() end)
                name = _G.DOTA_KART_UNIT_HERO_OVERRIDES[ent]
            end
            if name == nil or name == "" then name = bot.unit:GetUnitName() end
            self:MarkHeroNameUsed(used, name)
        end
    end
    return used
end

function DotaKartPublicAI:ChooseBotHeroName(slot)
    local candidates = self:GetBotHeroCandidates(slot)
    local picked = candidates[1] or "npc_dota_hero_pudge"
    local list = ""
    for i, heroName in ipairs(candidates or {}) do
        if i > 1 then list = list .. "," end
        list = list .. tostring(heroName)
    end
    print("[DotaKartPublicAI] FIX69 escolha heroi real slot=" .. tostring(slot) .. " picked=" .. tostring(picked) .. " candidates=[" .. list .. "]")
    return picked
end

function DotaKartPublicAI:GetHeroModel(heroName)
    heroName = tostring(heroName or "")
    local models = DOTA_KART_AI_HERO_MODELS or {}
    local model = models[heroName]
    if model ~= nil and model ~= "" then return model end
    return models.npc_dota_hero_rattletrap or "models/heroes/rattletrap/rattletrap.vmdl"
end

function DotaKartPublicAI:ApplyBotVisualHero(unit, heroName)
    if not DKValidUnit(unit) then return end
    heroName = tostring(heroName or "npc_dota_hero_rattletrap")

    -- FIX69: não força mais SetModel/SetOriginalModel.
    -- Depois do FIX67 os bots públicos são heróis reais integrados; forçar modelo manualmente
    -- herda o bug do FIX66/FIX65 e pode quebrar animações/attachments/escala do herói.
    -- Esta função agora só guarda metadados para HUD/ranking e garante que a unidade real não
    -- fique escondida por AddNoDraw antigo.
    self.unitHeroOverrides = self.unitHeroOverrides or {}
    _G.DOTA_KART_UNIT_HERO_OVERRIDES = _G.DOTA_KART_UNIT_HERO_OVERRIDES or {}
    local ent = -1
    pcall(function() ent = unit:entindex() end)
    if ent ~= nil and ent >= 0 then
        self.unitHeroOverrides[ent] = heroName
        _G.DOTA_KART_UNIT_HERO_OVERRIDES[ent] = heroName
    end

    pcall(function() unit.dk_kart_hero_name = heroName end)
    pcall(function() unit.dotakart_display_hero = heroName end)
    pcall(function() unit.dotakart_public_ai_hero = heroName end)
    pcall(function() unit:RemoveNoDraw() end)
end

function DotaKartPublicAI:CleanupLegacyVisualProxies()
    -- FIX69: remove prop_dynamic legado do FIX66 se o addon for recarregado sem reiniciar o Dota.
    if Entities == nil or Entities.FindByName == nil then return 0 end
    local removed = 0
    for id = 0, 64 do
        local name = "dk_public_ai_visual_" .. tostring(id)
        local ent = Entities:FindByName(nil, name)
        local guard = 0
        while ent ~= nil and guard < 16 do
            local nextEnt = Entities:FindByName(ent, name)
            pcall(function() UTIL_Remove(ent) end)
            removed = removed + 1
            guard = guard + 1
            ent = nextEnt
        end
    end
    if removed > 0 then
        print("[DotaKartPublicAI] FIX69 removeu " .. tostring(removed) .. " visual_proxy/prop_dynamic legado do FIX66")
    end
    return removed
end

function DotaKartPublicAI:DestroyBotVisualProxy(bot)
    -- FIX69: mantém apenas limpeza defensiva de handles antigos. Não cria nem atualiza proxy visual.
    if bot == nil then return end
    if DKValidUnit(bot.visual_proxy) then
        pcall(function() UTIL_Remove(bot.visual_proxy) end)
    end
    bot.visual_proxy = nil
    if DKValidUnit(bot.unit) then pcall(function() bot.unit:RemoveNoDraw() end) end
end

function DotaKartPublicAI:CreateBotVisualProxy(bot)
    -- FIX69: função mantida como stub para compatibilidade de hot reload, mas o sistema
    -- FIX66 de prop_dynamic foi desativado de verdade.
    if bot ~= nil and DKValidUnit(bot.unit) then pcall(function() bot.unit:RemoveNoDraw() end) end
    return nil
end

function DotaKartPublicAI:UpdateBotVisualProxy(bot, pos, dir)
    -- FIX69: sem proxy visual. A unidade real do herói integrado é o próprio kart/bot.
    if bot ~= nil and DKValidUnit(bot.unit) then pcall(function() bot.unit:RemoveNoDraw() end) end
end

function DotaKartPublicAI:CapturePlayerIDs()
    local before = {}
    if PlayerResource ~= nil and PlayerResource.IsValidPlayerID ~= nil then
        local max = DOTA_MAX_TEAM_PLAYERS or 64
        for id = 0, max - 1 do
            local ok, valid = pcall(function() return PlayerResource:IsValidPlayerID(id) end)
            if ok and valid then before[id] = true end
        end
    end
    return before
end

function DotaKartPublicAI:GetHeroForPlayerID(playerID, heroName)
    if PlayerResource == nil then return nil end
    playerID = tonumber(playerID) or -1
    if playerID < 0 then return nil end
    local hero = nil
    pcall(function() hero = PlayerResource:GetSelectedHeroEntity(playerID) end)
    if DKValidUnit(hero) then
        if heroName == nil or heroName == "" or hero:GetUnitName() == heroName then return hero end
    end
    local player = nil
    pcall(function() player = PlayerResource:GetPlayer(playerID) end)
    if player ~= nil then
        pcall(function()
            if player.GetAssignedHero ~= nil then hero = player:GetAssignedHero() end
        end)
        if DKValidUnit(hero) then
            if heroName == nil or heroName == "" or hero:GetUnitName() == heroName then return hero end
        end
    end
    return nil
end

function DotaKartPublicAI:FindNewBotHero(heroName, team, spawn, beforeIDs)
    beforeIDs = beforeIDs or {}
    if PlayerResource ~= nil and PlayerResource.IsValidPlayerID ~= nil then
        local max = DOTA_MAX_TEAM_PLAYERS or 64
        for id = 0, max - 1 do
            local ok, valid = pcall(function() return PlayerResource:IsValidPlayerID(id) end)
            if ok and valid then
                local isNew = beforeIDs[id] ~= true
                local isFake = self:IsFakeClientPlayerID(id)
                if isNew or isFake then
                    local hero = self:GetHeroForPlayerID(id, heroName)
                    if DKValidUnit(hero) then return hero, id end
                end
            end
        end
    end

    -- Fallback por raio: útil se a API criou o herói mas ainda não amarrou PlayerResource.
    if FindUnitsInRadius ~= nil and spawn ~= nil then
        local targetType = DOTA_UNIT_TARGET_HERO or 1
        local targetTeam = DOTA_UNIT_TARGET_TEAM_BOTH or 3
        local targetFlags = (DOTA_UNIT_TARGET_FLAG_INVULNERABLE or 0) + (DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD or 0) + (DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES or 0)
        local order = FIND_ANY_ORDER or 0
        local units = FindUnitsInRadius(team, spawn, nil, 2200, targetTeam, targetType, targetFlags, order, false)
        for _, u in pairs(units or {}) do
            if DKValidUnit(u) and u:GetUnitName() == heroName then
                local ownerID = -1
                pcall(function() ownerID = u:GetPlayerOwnerID() end)
                return u, ownerID
            end
        end
    end
    return nil, nil
end

function DotaKartPublicAI:CreateHeroForExistingPlayer(playerID, heroName, spawn)
    if CreateHeroForPlayer == nil or PlayerResource == nil then return nil end
    local player = nil
    pcall(function() player = PlayerResource:GetPlayer(playerID) end)
    if player == nil then return nil end

    local hero = self:GetHeroForPlayerID(playerID, heroName)
    if DKValidUnit(hero) then return hero end

    local ok, created = pcall(function() return CreateHeroForPlayer(heroName, player) end)
    if ok and DKValidUnit(created) then
        created:SetAbsOrigin(spawn)
        return created
    end
    return nil
end

function DotaKartPublicAI:TryCreateDotAKartInvokerFromBaseBot(slot, team, spawn)
    -- FIX92: algumas builds do AddBotPlayerWithEntityScript não aceitam override_hero custom
    -- diretamente. Para permitir que a IA escolha o Invoker custom, cria um bot Invoker base
    -- e troca para npc_dota_hero_dotakart_invoker logo em seguida.
    if GameRules == nil or GameRules.AddBotPlayerWithEntityScript == nil then return nil, nil, "api_missing" end
    if PlayerResource == nil then return nil, nil, "playerresource_missing" end

    local before = self:CapturePlayerIDs()
    local botName = "CPU " .. tostring((tonumber(slot) or 0) + 1)
    local scriptName = "dotakart/ai/public_ai_bot_entity"
    local ok, result = pcall(function() return GameRules:AddBotPlayerWithEntityScript("npc_dota_hero_invoker", botName, team, scriptName) end)
    if not ok then
        ok, result = pcall(function() return GameRules:AddBotPlayerWithEntityScript("npc_dota_hero_invoker", botName, team, scriptName, false) end)
    end
    if not ok then
        print("[DotaKartPublicAI] FIX92 fallback Invoker base falhou para custom Invoker: " .. tostring(result))
        return nil, nil, "base_addbot_failed"
    end

    local baseHero, botPlayerID = self:FindNewBotHero("npc_dota_hero_invoker", team, spawn, before)
    if botPlayerID == nil or tonumber(botPlayerID) == nil or tonumber(botPlayerID) < 0 then
        if DKValidUnit(baseHero) then pcall(function() botPlayerID = baseHero:GetPlayerOwnerID() end) end
    end

    local customHero = nil
    if tonumber(botPlayerID) ~= nil and tonumber(botPlayerID) >= 0 and PlayerResource.ReplaceHeroWith ~= nil then
        local okReplace, replaced = pcall(function()
            return PlayerResource:ReplaceHeroWith(tonumber(botPlayerID), "npc_dota_hero_dotakart_invoker", 0, 0)
        end)
        if okReplace and DKValidUnit(replaced) then
            customHero = replaced
        else
            customHero = self:GetHeroForPlayerID(botPlayerID, "npc_dota_hero_dotakart_invoker")
        end
    end

    if not DKValidUnit(customHero) then
        customHero = self:CreateHeroForExistingPlayer(botPlayerID, "npc_dota_hero_dotakart_invoker", spawn)
    end

    if DKValidUnit(customHero) then
        customHero:SetAbsOrigin(spawn)
        FindClearSpaceForUnit(customHero, spawn, true)
        print("[DotaKartPublicAI] FIX92 bot custom Invoker criado via base fallback slot=" .. tostring(slot) .. " playerID=" .. tostring(botPlayerID))
        return customHero, botPlayerID, "addbot_base_then_replace_custom_invoker"
    end

    print("[DotaKartPublicAI] FIX92 fallback base Invoker executou, mas custom Invoker não apareceu.")
    return nil, botPlayerID, "custom_invoker_replace_failed"
end

function DotaKartPublicAI:TryCreateIntegratedBotPlayerHero(slot, heroName, team, spawn)
    if self.config == nil or self.config.use_real_hero_bots ~= true then return nil, nil, "disabled" end
    if GameRules == nil or GameRules.AddBotPlayerWithEntityScript == nil then return nil, nil, "api_missing" end

    local before = self:CapturePlayerIDs()
    local botName = "CPU " .. tostring((tonumber(slot) or 0) + 1)
    local scriptName = "dotakart/ai/public_ai_bot_entity"
    local result = nil
    local ok = false
    local err = nil

    -- API documentada: AddBotPlayerWithEntityScript(heroName, playerName, team, entityScript[, unknownBool])
    ok, result = pcall(function() return GameRules:AddBotPlayerWithEntityScript(heroName, botName, team, scriptName) end)
    if not ok then
        err = result
        ok, result = pcall(function() return GameRules:AddBotPlayerWithEntityScript(heroName, botName, team, scriptName, false) end)
    end
    if not ok then
        print("[DotaKartPublicAI] FIX67 AddBotPlayerWithEntityScript falhou hero=" .. tostring(heroName) .. " err=" .. tostring(result or err))
        return nil, nil, "addbot_failed"
    end

    local hero = nil
    local botPlayerID = nil

    -- Algumas builds retornam o próprio herói; outras retornam o player handle.
    if result ~= nil and result.IsNull ~= nil and not result:IsNull() and result.GetUnitName ~= nil and result:GetUnitName() == heroName then
        hero = result
        pcall(function() botPlayerID = result:GetPlayerOwnerID() end)
    elseif result ~= nil then
        pcall(function()
            if result.GetPlayerID ~= nil then botPlayerID = result:GetPlayerID() end
        end)
        if botPlayerID ~= nil and tonumber(botPlayerID) ~= nil and tonumber(botPlayerID) >= 0 then
            hero = self:GetHeroForPlayerID(botPlayerID, heroName)
            if not DKValidUnit(hero) then hero = self:CreateHeroForExistingPlayer(botPlayerID, heroName, spawn) end
        end
        if not DKValidUnit(hero) then
            pcall(function()
                if result.GetAssignedHero ~= nil then hero = result:GetAssignedHero() end
            end)
            if DKValidUnit(hero) then pcall(function() botPlayerID = hero:GetPlayerOwnerID() end) end
        end
    end

    if not DKValidUnit(hero) then
        hero, botPlayerID = self:FindNewBotHero(heroName, team, spawn, before)
    end

    if DKValidUnit(hero) then
        print("[DotaKartPublicAI] FIX67 bot integrado criado slot=" .. tostring(slot) .. " playerID=" .. tostring(botPlayerID) .. " hero=" .. tostring(heroName))
        return hero, botPlayerID, "addbot_integrated"
    end

    print("[DotaKartPublicAI] FIX67 AddBot executou, mas o heroi ainda nao foi encontrado hero=" .. tostring(heroName))
    return nil, botPlayerID, "hero_not_found"
end

function DotaKartPublicAI:TryCreateDirectHeroUnit(heroName, team, spawn)
    pcall(function() PrecacheUnitByNameAsync(heroName, function() end) end)
    local unit = nil
    local ok, created = pcall(function() return CreateUnitByName(heroName, spawn, true, nil, nil, team) end)
    if ok then unit = created end
    if DKValidUnit(unit) then
        local actualName = unit:GetUnitName()
        if actualName == heroName then return unit, "direct_create" end
        print("[DotaKartPublicAI] FIX67 CreateUnitByName retornou " .. tostring(actualName) .. " ao tentar " .. tostring(heroName))
        UTIL_Remove(unit)
    end
    return nil, "direct_failed"
end

function DotaKartPublicAI:ApplyCustomInvokerVisualToBaseBot(unit, displayHeroName)
    if not DKValidUnit(unit) then return end
    local heroName = tostring(displayHeroName or "npc_dota_hero_dotakart_invoker")
    if GameRules ~= nil and GameRules.AddonTemplate ~= nil and GameRules.AddonTemplate.ApplyCustomKartHeroModel ~= nil then
        pcall(function() GameRules.AddonTemplate:ApplyCustomKartHeroModel(unit) end)
    end
    self:ApplyBotVisualHero(unit, heroName)
    pcall(function() unit.dk_kart_custom_ai_invoker = true end)
end

function DotaKartPublicAI:TryCreateCustomInvokerAsStableBaseBot(slot, team, spawn)
    -- FIX104: criar npc_dota_hero_dotakart_invoker diretamente ou via ReplaceHeroWith pode
    -- falhar como "invalid" e deixar o bot parado/fora do grid. Usa Invoker base integrado
    -- para obter PlayerID/controle normal, e aplica o modelo custom do kart no próprio herói.
    local unit, botPlayerID, mode = self:TryCreateIntegratedBotPlayerHero(slot, "npc_dota_hero_invoker", team, spawn)
    if DKValidUnit(unit) then
        pcall(function() unit:SetAbsOrigin(spawn) end)
        pcall(function() FindClearSpaceForUnit(unit, spawn, true) end)
        self:ApplyCustomInvokerVisualToBaseBot(unit, "npc_dota_hero_dotakart_invoker")
        return unit, botPlayerID, "base_invoker_bot_custom_visual"
    end

    unit, mode = self:TryCreateDirectHeroUnit("npc_dota_hero_invoker", team, spawn)
    if DKValidUnit(unit) then
        self:ApplyCustomInvokerVisualToBaseBot(unit, "npc_dota_hero_dotakart_invoker")
        return unit, nil, "direct_base_invoker_custom_visual"
    end

    return nil, nil, "custom_invoker_base_failed"
end

function DotaKartPublicAI:CreateIntegratedHeroUnitForSlot(slot, heroName, team, spawn)
    local unit, botPlayerID, mode = nil, nil, nil

    -- FIX104: o piloto Invoker custom da IA usa Invoker base integrado com visual custom.
    -- Isso evita ReplaceHeroWith inválido, spawn errado e bot parado, mas mantém um único
    -- piloto Invoker na lógica de heróis únicos.
    if heroName == "npc_dota_hero_dotakart_invoker" then
        unit, botPlayerID, mode = self:TryCreateCustomInvokerAsStableBaseBot(slot, team, spawn)
        if DKValidUnit(unit) then return unit, botPlayerID, mode end
        return nil, nil, "custom_invoker_failed"
    end

    unit, botPlayerID, mode = self:TryCreateIntegratedBotPlayerHero(slot, heroName, team, spawn)
    if DKValidUnit(unit) then return unit, botPlayerID, mode end

    -- Fallback: se a API de fake client não existir no ambiente, tenta criar o herói real por unidade.
    unit, mode = self:TryCreateDirectHeroUnit(heroName, team, spawn)
    if DKValidUnit(unit) then return unit, nil, mode end

    -- FIX84: sem fallback para Clock/Rattletrap. Se um piloto oficial falhar, o slot fica sem bot
    -- e o erro aparece no console para corrigirmos o herói/modelo certo.
    print("[DotaKartPublicAI] FIX93 falhou criar piloto oficial: " .. tostring(heroName))
    return nil, nil, "failed"
end

function DotaKartPublicAI:RegisterPublicAIControlIDs(slot, botPlayerID, unit)
    self.publicAIPlayerIDs = self.publicAIPlayerIDs or {}
    self.publicAIUnitEnts = self.publicAIUnitEnts or {}
    _G.DOTA_KART_PUBLIC_AI_PLAYER_IDS = _G.DOTA_KART_PUBLIC_AI_PLAYER_IDS or {}
    _G.DOTA_KART_PUBLIC_AI_UNIT_ENTS = _G.DOTA_KART_PUBLIC_AI_UNIT_ENTS or {}

    local function markPlayer(id)
        id = tonumber(id)
        if id ~= nil and id >= 0 then
            self.publicAIPlayerIDs[id] = true
            _G.DOTA_KART_PUBLIC_AI_PLAYER_IDS[id] = true
            if self.controller ~= nil and self.controller.GetState ~= nil then
                local st = self.controller:GetState(id)
                st.public_ai_controlled = true
                st.input = st.input or {}
                st.input.forward = false
                st.input.reverse = false
                st.input.left = false
                st.input.right = false
            end
        end
    end

    markPlayer(slot)
    markPlayer(botPlayerID)

    if DKValidUnit(unit) then
        local ownerID = -1
        pcall(function() ownerID = unit:GetPlayerOwnerID() end)
        -- Nunca marca o host/player 0 por acidente. Alguns handles criados por script podem
        -- retornar 0 como owner temporario; o controle por entindex ja cobre o heroi real do bot.
        if tonumber(ownerID) ~= 0 or tonumber(slot) == 0 or tonumber(botPlayerID) == 0 then
            markPlayer(ownerID)
        end

        local ent = -1
        pcall(function() ent = unit:entindex() end)
        if ent ~= nil and ent >= 0 then
            self.publicAIUnitEnts[ent] = true
            _G.DOTA_KART_PUBLIC_AI_UNIT_ENTS[ent] = true
        end
    end
end

function DotaKartPublicAI:UnregisterPublicAIControlIDs(bot)
    if bot == nil then return end
    self.publicAIPlayerIDs = self.publicAIPlayerIDs or {}
    self.publicAIUnitEnts = self.publicAIUnitEnts or {}
    _G.DOTA_KART_PUBLIC_AI_PLAYER_IDS = _G.DOTA_KART_PUBLIC_AI_PLAYER_IDS or {}
    _G.DOTA_KART_PUBLIC_AI_UNIT_ENTS = _G.DOTA_KART_PUBLIC_AI_UNIT_ENTS or {}

    local function unmarkPlayer(id)
        id = tonumber(id)
        if id ~= nil and id >= 0 then
            self.publicAIPlayerIDs[id] = nil
            _G.DOTA_KART_PUBLIC_AI_PLAYER_IDS[id] = nil
            if self.controller ~= nil and self.controller.states ~= nil and self.controller.states[id] ~= nil then
                self.controller.states[id].public_ai_controlled = nil
            end
        end
    end

    unmarkPlayer(bot.player_id)
    unmarkPlayer(bot.bot_player_id)

    if DKValidUnit(bot.unit) then
        local ownerID = -1
        pcall(function() ownerID = bot.unit:GetPlayerOwnerID() end)
        unmarkPlayer(ownerID)

        local ent = -1
        pcall(function() ent = bot.unit:entindex() end)
        if ent ~= nil and ent >= 0 then
            self.publicAIUnitEnts[ent] = nil
            _G.DOTA_KART_PUBLIC_AI_UNIT_ENTS[ent] = nil
        end
    end
end

function DotaKartPublicAI:GetWantedBotSlots()
    local wanted = {}
    local maxPlayers = math.min(8, tonumber(self.config.max_players or DOTA_KART_MAX_PLAYERS or 8) or 8)
    local free = {}

    -- Slot 0 fica reservado para o jogador 1/host.
    for slot = 1, maxPlayers - 1 do
        if not self:IsHumanSlotOccupied(slot) then
            table.insert(free, slot)
        end
    end

    local configured = self:GetConfiguredBotCount()
    if configured < 0 then
        for _, slot in ipairs(free) do wanted[slot] = true end
    else
        local count = math.min(configured, #free)
        for i = 1, count do wanted[free[i]] = true end
    end

    return wanted, free
end

function DotaKartPublicAI:RemoveBotSlot(slot)
    self.bots = self.bots or {}
    local bot = self.bots and self.bots[slot]
    if bot ~= nil then self:UnregisterPublicAIControlIDs(bot) end
    if bot ~= nil then self:DestroyBotVisualProxy(bot) end
    if bot ~= nil and DKValidUnit(bot.unit) then
        local ent = -1
        pcall(function() ent = bot.unit:entindex() end)
        if ent ~= nil and ent >= 0 then
            if self.unitHeroOverrides ~= nil then self.unitHeroOverrides[ent] = nil end
            if _G.DOTA_KART_UNIT_HERO_OVERRIDES ~= nil then _G.DOTA_KART_UNIT_HERO_OVERRIDES[ent] = nil end
        end
        UTIL_Remove(bot.unit)
    end
    if self.hud ~= nil and self.hud.racers ~= nil then self.hud.racers[slot] = nil end
    if self.controller ~= nil then
        if self.controller.heroes ~= nil then self.controller.heroes[slot] = nil end
        if self.controller.states ~= nil then self.controller.states[slot] = nil end
        if self.controller.heldItems ~= nil then self.controller.heldItems[slot] = nil end
    end
    self.bots[slot] = nil
end

function DotaKartPublicAI:RemoveBotsNotAllowed()
    local wanted = self:GetWantedBotSlots()
    for slot, bot in pairs(self.bots or {}) do
        if wanted[slot] ~= true or self:IsHumanSlotOccupied(slot) then
            self:RemoveBotSlot(slot)
        end
    end
end

function DotaKartPublicAI:GetNearestTrackIndex(pos)
    if self.track == nil or #self.track <= 0 then return 1 end
    local best = 1
    local bestDist = nil
    for i, p in ipairs(self.track) do
        local d = DKDistance2D(pos, p)
        if bestDist == nil or d < bestDist then
            bestDist = d
            best = i
        end
    end
    return best
end

function DotaKartPublicAI:CreateBotForSlot(slot)
    if self.bots[slot] ~= nil and DKValidUnit(self.bots[slot].unit) then return self.bots[slot] end
    if self:IsHumanSlotOccupied(slot) then return nil end

    local team = self:GetRaceTeamForSlot(slot)
    if team == nil then
        print("[DotaKartPublicAI] ERRO: time invalido para bot slot " .. tostring(slot))
        return nil
    end

    local spawn = self:GetStartPositionForSlot(slot)
    local candidates = self:GetBotHeroCandidates(slot)
    local heroName = nil
    local unit, botPlayerID, creationMode = nil, nil, nil

    -- FIX98: tenta candidatos em sequência. Isso evita que falha do Custom Invoker crie
    -- outro Invoker base ou repita piloto já usado.
    for _, candidate in ipairs(candidates or {}) do
        local u, pid, mode = self:CreateIntegratedHeroUnitForSlot(slot, candidate, team, spawn)
        if DKValidUnit(u) then
            unit = u
            botPlayerID = pid
            creationMode = mode
            heroName = candidate
            break
        end
        print("[DotaKartPublicAI] FIX98 candidato falhou slot=" .. tostring(slot) .. " hero=" .. tostring(candidate) .. " mode=" .. tostring(mode))
    end

    if not DKValidUnit(unit) then
        print("[DotaKartPublicAI] ERRO: nao consegui criar bot integrado slot " .. tostring(slot) .. " candidates=" .. tostring(#(candidates or {})))
        return nil
    end

    local actualName = unit:GetUnitName()
    if actualName ~= heroName then
        print("[DotaKartPublicAI] FIX67 AVISO: slot=" .. tostring(slot) .. " sorteou=" .. tostring(heroName) .. " unidade=" .. tostring(actualName) .. " mode=" .. tostring(creationMode))
        -- Mantém o nome no HUD/ranking, mas não força modelo.
        self:ApplyBotVisualHero(unit, heroName)
    end

    pcall(function() unit:RemoveNoDraw() end)
    pcall(function() unit:SetTeam(team) end)
    pcall(function() unit:SetOwner(nil) end)
    pcall(function() unit:SetControllableByPlayer(-1, false) end)
    pcall(function() unit:SetIdleAcquire(false) end)
    pcall(function() unit:SetAcquisitionRange(0) end)
    pcall(function() unit:SetForceAttackTarget(nil) end)
    pcall(function() unit:SetAggroTarget(nil) end)
    if DOTA_UNIT_CAP_NO_ATTACK ~= nil then pcall(function() unit:SetAttackCapability(DOTA_UNIT_CAP_NO_ATTACK) end) end

    local humanMaxSpeed = self:GetHumanMaxSpeed()
    unit:SetBaseMoveSpeed(humanMaxSpeed)
    unit:SetHullRadius(55)
    unit:SetAbsOrigin(spawn)
    FindClearSpaceForUnit(unit, spawn, true)

    local nearest = self:GetNearestTrackIndex(spawn)
    local nextIndex = nearest + 1
    if nextIndex > #self.track then nextIndex = 1 end

    local laneSign = (slot % 2 == 0) and 1 or -1
    local laneOffset = laneSign * DKRandomFloat(60, 155)
    local speed = humanMaxSpeed

    local bot = {
        player_id = slot,
        bot_player_id = botPlayerID,
        unit = unit,
        next_index = nextIndex,
        lane_offset = laneOffset,
        lane_jitter = DKRandomFloat(-28, 28),
        next_lane_change = DKNow() + DKRandomFloat(2.5, 5.5),
        hero_name = heroName,
        display_hero_name = heroName,
        creation_mode = creationMode,
        base_speed = speed,
        target_speed = speed,
        current_speed = 0,
        next_overtake_check = 0,
        overtake_offset = 0,
        overtake_until = 0,
        next_item_check = DKNow() + DKRandomFloat(0.5, 1.4),
        next_item_use = 0,
        last_dir = Vector(1, 0, 0)
    }
    self.bots[slot] = bot
    self:RegisterPublicAIControlIDs(slot, botPlayerID, unit)
    self:ApplyBotVisualHero(unit, heroName)

    if self.hud ~= nil and self.hud.RegisterKart ~= nil then
        local racer = self.hud:RegisterKart(slot, unit)
        if racer ~= nil then
            racer.is_bot = true
            racer.player_name = "CPU " .. tostring(slot + 1)
            racer.hero_override = heroName
            racer.hero = heroName
        end
    end
    if self.controller ~= nil and self.controller.RegisterHero ~= nil then
        self.controller:RegisterHero(slot, unit)
        self:ApplyBotVisualHero(unit, heroName)
    end
    if self.itemSystem ~= nil and self.itemSystem.SetEnabled ~= nil then
        self.itemSystem:SetEnabled(true)
    end

    -- Evita que o bot padrão do Dota tente comandar o fake client por cima da nossa IA de kart.
    pcall(function() GameRules:SetBotThinkingEnabled(false) end)
    pcall(function()
        if GameRules:GetGameModeEntity() ~= nil and GameRules:GetGameModeEntity().SetBotThinkingEnabled ~= nil then
            GameRules:GetGameModeEntity():SetBotThinkingEnabled(false)
        end
    end)

    print("[DotaKartPublicAI] FIX69 Bot publico integrado: slot=" .. tostring(slot) .. " botPlayerID=" .. tostring(botPlayerID) .. " hero=" .. tostring(heroName) .. " unit=" .. tostring(actualName) .. " mode=" .. tostring(creationMode) .. " team=" .. tostring(team) .. " speed=" .. tostring(math.floor(speed)) .. " duplicate_controller_move=off model_proxy=removed lane=" .. tostring(math.floor(laneOffset)))
    return bot
end

function DotaKartPublicAI:PreparePublicBots()
    pcall(function() self:CleanupLegacyVisualProxies() end)
    if not self.config.enabled then return 0 end
    if not self:LoadTrackPoints() then return 0 end

    local created = 0
    local wanted = self:GetWantedBotSlots()

    -- Remove bots que não batem mais com a configuração do host ou slots ocupados por humanos.
    self:RemoveBotsNotAllowed()

    -- Slot 0 fica reservado para o jogador 1/host. Slots vazios restantes seguem a config.
    for slot, _ in pairs(wanted) do
        if not self:IsHumanSlotOccupied(slot) then
            if self.bots[slot] == nil or not DKValidUnit(self.bots[slot].unit) then
                if self:CreateBotForSlot(slot) ~= nil then created = created + 1 end
            end
        end
    end

    self:BroadcastHostSettings()
    return created
end

function DotaKartPublicAI:GetPoint(index)
    if self.track == nil or #self.track <= 0 then return nil end
    index = tonumber(index) or 1
    if index < 1 then index = 1 end
    if index > #self.track then index = 1 end
    local p = self.track[index]
    return DKGround(p, nil)
end

function DotaKartPublicAI:AdvanceTarget(bot)
    bot.next_index = (tonumber(bot.next_index) or 1) + 1
    if bot.next_index > #self.track then bot.next_index = 1 end
end

function DotaKartPublicAI:GetOffsetTarget(bot)
    local base = self:GetPoint(bot.next_index or 1)
    if base == nil then return nil, Vector(1,0,0) end
    local nextIndex = (tonumber(bot.next_index) or 1) + 1
    if nextIndex > #self.track then nextIndex = 1 end
    local ahead = self:GetPoint(nextIndex) or base
    local dir = DKNormalize2D(ahead - base, bot.last_dir or Vector(1,0,0))
    local right = Vector(-dir.y, dir.x, 0)
    local offset = (tonumber(bot.lane_offset) or 0) + (tonumber(bot.lane_jitter) or 0)
    if (bot.overtake_until or 0) > DKNow() then
        offset = offset + (tonumber(bot.overtake_offset) or 0)
    end
    local target = base + right * offset
    target.z = GetGroundHeight(target, bot.unit)
    return target, dir
end

function DotaKartPublicAI:GetBestItemBoxTarget(bot, pos, fwd)
    local itemSystem = self.itemSystem or GameRules.DotaKartItemSystem
    if itemSystem == nil or itemSystem.boxes == nil then return nil end
    if itemSystem.PlayerCanReceiveItem ~= nil and not itemSystem:PlayerCanReceiveItem(bot.player_id) then return nil end

    local best = nil
    local bestScore = nil
    local radius = tonumber(self.config.item_box_search_radius) or 1150

    for _, box in ipairs(itemSystem.boxes) do
        if box ~= nil and box.active == true and not box.being_pulled and box.pos ~= nil then
            local bpos = box.ground_pos or box.pos
            local toBox = bpos - pos
            local dist = DKLength2D(toBox)
            if dist <= radius and dist >= 80 then
                local dir = DKNormalize2D(toBox, fwd)
                local dot = dir.x * fwd.x + dir.y * fwd.y
                if dot > 0.20 then
                    local score = dist - dot * 240
                    if bestScore == nil or score < bestScore then
                        bestScore = score
                        best = DKGround(bpos, nil)
                    end
                end
            end
        end
    end

    return best
end

function DotaKartPublicAI:GetUpcomingItemBox(bot, pos, fwd, radius)
    local itemSystem = self.itemSystem or GameRules.DotaKartItemSystem
    if itemSystem == nil or itemSystem.boxes == nil then return nil, 999999, 0 end

    local best = nil
    local bestDist = 999999
    local bestDot = 0
    radius = tonumber(radius or self.config.item_box_use_ahead_radius or 780) or 780

    for _, box in ipairs(itemSystem.boxes) do
        if box ~= nil and box.active == true and not box.being_pulled and box.pos ~= nil then
            local bpos = box.ground_pos or box.pos
            local toBox = bpos - pos
            local dist = DKLength2D(toBox)
            if dist <= radius and dist >= 90 then
                local dir = DKNormalize2D(toBox, fwd)
                local dot = dir.x * fwd.x + dir.y * fwd.y
                if dot > 0.32 and dist < bestDist then
                    best = box
                    bestDist = dist
                    bestDot = dot
                end
            end
        end
    end

    return best, bestDist, bestDot
end

function DotaKartPublicAI:FindEnemy(bot, range, frontDotMin, wantBehind)
    local unit = bot.unit
    if not DKValidUnit(unit) then return nil, -1, 999999, 0 end
    local pos = unit:GetAbsOrigin()
    local fwd = DKNormalize2D(bot.last_dir or unit:GetForwardVector(), Vector(1,0,0))
    local bestUnit = nil
    local bestID = -1
    local bestDist = 999999
    local bestDot = 0

    local ids = {}
    if self.itemSystem ~= nil and self.itemSystem.GetRegisteredPlayerIDs ~= nil then
        ids = self.itemSystem:GetRegisteredPlayerIDs()
    elseif self.hud ~= nil and self.hud.racers ~= nil then
        for pid, _ in pairs(self.hud.racers) do table.insert(ids, pid) end
    end

    for _, otherID in ipairs(ids) do
        otherID = tonumber(otherID)
        if otherID ~= nil and otherID ~= bot.player_id then
            local other = nil
            if self.controller ~= nil and self.controller.GetHeroForPlayer ~= nil then
                other = self.controller:GetHeroForPlayer(otherID)
            end
            if DKValidUnit(other) then
                local d = DKDistance2D(pos, other:GetAbsOrigin())
                if d <= (range or 900) then
                    local dir = DKNormalize2D(other:GetAbsOrigin() - pos, fwd)
                    local dot = dir.x * fwd.x + dir.y * fwd.y
                    local ok = true
                    if wantBehind == true then ok = dot < -0.15 end
                    if frontDotMin ~= nil then ok = ok and dot >= frontDotMin end
                    if ok and d < bestDist then
                        bestUnit = other
                        bestID = otherID
                        bestDist = d
                        bestDot = dot
                    end
                end
            end
        end
    end

    return bestUnit, bestID, bestDist, bestDot
end

function DotaKartPublicAI:ChooseOvertakeSide(bot, pos, fwd, blocker)
    local right = Vector(-fwd.y, fwd.x, 0)
    local side = 1
    if DKValidUnit(blocker) then
        local toOther = blocker:GetAbsOrigin() - pos
        local lateral = toOther.x * right.x + toOther.y * right.y
        -- Vai para o lado oposto do kart bloqueando a frente.
        side = lateral >= 0 and -1 or 1
    elseif (tonumber(bot.lane_offset) or 0) > 0 then
        side = -1
    end

    -- Se houver outro kart no lado escolhido, troca para o outro lado.
    local ids = {}
    if self.itemSystem ~= nil and self.itemSystem.GetRegisteredPlayerIDs ~= nil then
        ids = self.itemSystem:GetRegisteredPlayerIDs()
    elseif self.hud ~= nil and self.hud.racers ~= nil then
        for pid, _ in pairs(self.hud.racers) do table.insert(ids, pid) end
    end

    local function sideBlocked(testSide)
        for _, otherID in ipairs(ids) do
            otherID = tonumber(otherID)
            if otherID ~= nil and otherID ~= bot.player_id then
                local other = nil
                if self.controller ~= nil and self.controller.GetHeroForPlayer ~= nil then
                    other = self.controller:GetHeroForPlayer(otherID)
                end
                if DKValidUnit(other) then
                    local toOther = other:GetAbsOrigin() - pos
                    local forwardDist = toOther.x * fwd.x + toOther.y * fwd.y
                    local lateral = toOther.x * right.x + toOther.y * right.y
                    if forwardDist > -120 and forwardDist < 620 and lateral * testSide > 80 and math.abs(lateral) < 360 then
                        return true
                    end
                end
            end
        end
        return false
    end

    if sideBlocked(side) and not sideBlocked(-side) then side = -side end
    return side
end

function DotaKartPublicAI:UpdateOvertake(bot, pos, fwd, now)
    if now < (bot.next_overtake_check or 0) then return end
    bot.next_overtake_check = now + (tonumber(self.config.overtake_check_interval or 0.18) or 0.18)

    local blocker = self:FindEnemy(bot, self.config.overtake_range or 760, 0.42, false)
    if DKValidUnit(blocker) then
        local side = self:ChooseOvertakeSide(bot, pos, fwd, blocker)
        bot.overtake_offset = side * (tonumber(self.config.overtake_side_offset or 230) or 230)
        bot.overtake_until = now + DKRandomFloat(self.config.overtake_hold_min or 1.10, self.config.overtake_hold_max or 1.90)
        bot.next_lane_change = math.max(bot.next_lane_change or 0, now + 1.0)
    elseif (bot.overtake_until or 0) <= now then
        bot.overtake_offset = 0
    end
end

function DotaKartPublicAI:UseHeldItem(bot, reverse)
    local itemSystem = self.itemSystem or GameRules.DotaKartItemSystem
    local controller = self.controller or GameRules.DotaKartController
    if itemSystem == nil or itemSystem.UseItem == nil then return false end

    local playerID = bot.player_id
    local itemName = itemSystem:GetHeldItem(playerID)
    if itemName == nil or itemName == "" then return false end

    if controller ~= nil and controller.GetState ~= nil then
        local st = controller:GetState(playerID)
        st.input = st.input or {}
        local oldForward = st.input.forward
        local oldReverse = st.input.reverse
        st.input.forward = reverse ~= true
        st.input.reverse = reverse == true
        pcall(function() itemSystem:UseItem(playerID, itemName) end)
        GameRules:GetGameModeEntity():SetContextThink("DotaKartPublicAI_ResetInput_" .. tostring(playerID), function()
            local st2 = controller:GetState(playerID)
            st2.input = st2.input or {}
            st2.input.forward = oldForward == true
            st2.input.reverse = oldReverse == true
            return nil
        end, 0.12)
    else
        pcall(function() itemSystem:UseItem(playerID, itemName) end)
    end

    bot.next_item_use = DKNow() + DKRandomFloat(1.1, 2.2)
    return true
end

function DotaKartPublicAI:ThinkItemUse(bot, now)
    if now < (bot.next_item_check or 0) then return end
    bot.next_item_check = now + DKRandomFloat(self.config.item_use_check_min or 0.25, self.config.item_use_check_max or 0.65)
    if now < (bot.next_item_use or 0) then return end

    local itemSystem = self.itemSystem or GameRules.DotaKartItemSystem
    if itemSystem == nil or itemSystem.itemDefs == nil then return end
    if itemSystem.rolling ~= nil and itemSystem.rolling[bot.player_id] ~= nil then return end

    local itemName = itemSystem:GetHeldItem(bot.player_id)
    if itemName == nil or itemName == "" then return end
    local def = itemSystem.itemDefs[itemName]
    if def == nil then return end

    local kind = def.kind or ""
    local unit = bot.unit
    local pos = DKValidUnit(unit) and unit:GetAbsOrigin() or Vector(0,0,0)
    local fwd = DKNormalize2D(bot.last_dir or (DKValidUnit(unit) and unit:GetForwardVector() or Vector(1,0,0)), Vector(1,0,0))

    local ahead = self:FindEnemy(bot, 1500, 0.20, false)
    local near = self:FindEnemy(bot, 650, nil, false)
    local behind = self:FindEnemy(bot, self.config.item_enemy_behind_radius or 1050, nil, true)

    -- FIX59: se há adversário próximo atrás, usa item para trás, EXCETO Hooks.
    -- Meat Hook/Hookshot para trás criam muito caos e foram excluídos conforme pedido.
    if DKValidUnit(behind) and kind ~= "meat_hook" and kind ~= "hookshot" then
        if kind == "ice_wall" then
            -- Ice Wall já nasce atrás do kart; não precisa inverter direção.
            self:UseHeldItem(bot, false)
            return
        elseif kind == "sacred_arrow" or kind == "swap_missile" or kind == "venomous_gale" or
            kind == "chaos_bolt" or kind == "spectral_dagger" or kind == "battle_hunger" or kind == "x_marks" or kind == "ice_shards" or kind == "tornado" then
            self:UseHeldItem(bot, true)
            return
        elseif kind == "star" or kind == "frost_shield" or kind == "power_cogs" or kind == "invisibility" or kind == "torrent_storm" or kind == "doppelwalk" or kind == "shukuchi" or kind == "crystal_clone" then
            self:UseHeldItem(bot, false)
            return
        elseif kind == "nitro" then
            if DKRandomFloat(0, 1) < 0.65 then self:UseHeldItem(bot, false) end
            return
        end
    end

    -- FIX59: se existe caixa de item logo adiante e o bot ainda está segurando item,
    -- ele gasta o item para liberar o slot e continuar alternando itens, como jogador humano.
    local boxAhead, boxDist = self:GetUpcomingItemBox(bot, pos, fwd, self.config.item_box_use_ahead_radius or 780)
    if boxAhead ~= nil and boxDist <= (self.config.item_box_use_ahead_radius or 780) then
        self:UseHeldItem(bot, false)
        return
    end

    if kind == "nitro" then
        if DKValidUnit(ahead) or boxAhead ~= nil or DKRandomFloat(0, 1) < 0.45 then self:UseHeldItem(bot, false) end
    elseif kind == "star" or kind == "invisibility" or kind == "frost_shield" or kind == "bloodlust" or kind == "torrent_storm" or kind == "doppelwalk" or kind == "shukuchi" or kind == "crystal_clone" then
        if DKValidUnit(near) or DKRandomFloat(0, 1) < 0.30 then self:UseHeldItem(bot, false) end
    elseif kind == "power_cogs" then
        if DKValidUnit(near) then self:UseHeldItem(bot, false) end
    elseif kind == "ice_wall" then
        if DKValidUnit(behind) or DKRandomFloat(0, 1) < 0.40 then self:UseHeldItem(bot, false) end
    elseif kind == "charge_darkness" or kind == "chain_frost" or kind == "item_steal" then
        if DKValidUnit(near) or DKValidUnit(ahead) then self:UseHeldItem(bot, false) end
    elseif kind == "meat_hook" or kind == "hookshot" or kind == "sacred_arrow" or kind == "swap_missile" or kind == "venomous_gale" or kind == "chaos_bolt" or kind == "spectral_dagger" or kind == "battle_hunger" or kind == "x_marks" or kind == "ice_shards" or kind == "tornado" then
        if DKValidUnit(ahead) then self:UseHeldItem(bot, false) end
    else
        if DKRandomFloat(0, 1) < 0.20 then self:UseHeldItem(bot, false) end
    end
end

function DotaKartPublicAI:ThinkBot(bot, now, dt)
    if bot == nil or not DKValidUnit(bot.unit) then return end
    if self.hud ~= nil and self.hud.IsPlayerFinished ~= nil and self.hud:IsPlayerFinished(bot.player_id) then return end

    local controller = self.controller or GameRules.DotaKartController
    if controller ~= nil and controller.IsKartStunned ~= nil then
        if controller:IsKartStunned(bot.player_id, now) or (controller.IsKartLocked ~= nil and controller:IsKartLocked(bot.player_id, now)) then
            -- FIX68: com o movimento manual do controller bloqueado para fake clients da IA,
            -- a propria IA chama o UpdateKart apenas durante stun/lock para manter spin/parada.
            if controller.UpdateKart ~= nil and controller.GetState ~= nil then
                local st = controller:GetState(bot.player_id)
                controller:UpdateKart(bot.player_id, bot.unit, st, dt or (self.config.tick_rate or 0.05), now)
            end
            pcall(function() bot.unit:RemoveNoDraw() end)
            return
        end
    end

    -- FIX81: esta versão restaurada da public_ai.lua também precisa respeitar Root.
    -- Root impede movimento do kart; itens de mobilidade continuam bloqueados no item_system.lua.
    if controller ~= nil and controller.IsKartRooted ~= nil and controller:IsKartRooted(bot.player_id, now) then
        bot.current_speed = 0
        if controller.GetState ~= nil then
            local st = controller:GetState(bot.player_id)
            if st ~= nil then
                st.speed = 0
                st.input = st.input or {}
                st.input.forward = false
                st.input.reverse = false
                st.input.left = false
                st.input.right = false
            end
        end
        pcall(function() bot.unit:SetForwardVector(bot.last_dir or bot.unit:GetForwardVector()) end)
        pcall(function() bot.unit:RemoveNoDraw() end)
        self:ThinkItemUse(bot, now)
        return
    end

    if now >= (bot.next_lane_change or 0) then
        bot.lane_jitter = DKRandomFloat(-45, 45)
        bot.next_lane_change = now + DKRandomFloat(2.0, 5.0)
    end

    local unit = bot.unit
    pcall(function() unit:SetIdleAcquire(false) end)
    pcall(function() unit:SetAcquisitionRange(0) end)

    local target, trackDir = self:GetOffsetTarget(bot)
    if target == nil then return end

    local pos = unit:GetAbsOrigin()
    self:UpdateOvertake(bot, pos, DKNormalize2D(trackDir or bot.last_dir or Vector(1,0,0), Vector(1,0,0)), now)
    target, trackDir = self:GetOffsetTarget(bot)
    if target == nil then return end

    local toTarget = target - pos
    local dist = DKLength2D(toTarget)

    if dist <= (self.config.arrive_distance or 190) then
        self:AdvanceTarget(bot)
        target, trackDir = self:GetOffsetTarget(bot)
        if target == nil then return end
        toTarget = target - pos
        dist = DKLength2D(toTarget)
    end

    local moveDir = DKNormalize2D(toTarget, trackDir or bot.last_dir or Vector(1,0,0))
    local boxTarget = self:GetBestItemBoxTarget(bot, pos, moveDir)
    if boxTarget ~= nil then
        local toBox = boxTarget - pos
        if DKLength2D(toBox) > 55 then
            target = boxTarget
            moveDir = DKNormalize2D(toBox, moveDir)
            dist = DKLength2D(toBox)
        end
    end

    bot.last_dir = moveDir

    -- FIX64: IA pública usa a mesma velocidade máxima/aceleração dos jogadores humanos,
    -- em vez da velocidade fixa 650 do bot de teste/AutoDrive.
    local maxSpeed = self:GetHumanMaxSpeed()
    local accel = self:GetHumanAcceleration()
    local st = nil
    if controller ~= nil and controller.GetState ~= nil then
        st = controller:GetState(bot.player_id)
        if st ~= nil and (st.item_max_speed_until or 0) > now and (st.item_max_speed or 0) > maxSpeed then
            maxSpeed = st.item_max_speed
        end
    end

    local currentSpeed = tonumber(bot.current_speed or 0) or 0
    if st ~= nil and (st.speed or 0) > currentSpeed then currentSpeed = st.speed end
    currentSpeed = DKApproach(currentSpeed, maxSpeed, accel * dt)
    local speed = currentSpeed

    if controller ~= nil and controller.GetKartSlowPct ~= nil then
        local slowPct = controller:GetKartSlowPct(bot.player_id, now) or 0
        if slowPct > 0 then speed = math.max(140, speed * (1.0 - slowPct)) end
    end
    bot.current_speed = speed

    local step = math.min(dist, speed * dt)
    local desired = pos + moveDir * step
    desired.z = GetGroundHeight(desired, unit)

    local finalPos = desired
    if controller ~= nil and controller.MoveUnitWithKartPhysics ~= nil then
        finalPos = controller:MoveUnitWithKartPhysics(bot.player_id, unit, desired, moveDir, speed, dt)
    else
        unit:SetAbsOrigin(desired)
    end

    local yaw = DKNormalizeYaw(math.deg(DKAtan2(moveDir.y, moveDir.x)))
    if controller ~= nil and controller.GetState ~= nil then
        local st = controller:GetState(bot.player_id)
        st.yaw = yaw
        st.speed = speed
    end
    if controller ~= nil and controller.SetHeroFacing ~= nil then
        pcall(function() controller:SetHeroFacing(unit, yaw) end)
    else
        pcall(function() unit:SetForwardVector(moveDir) end)
        pcall(function() unit:FaceTowards(finalPos + moveDir * 256) end)
    end
    pcall(function() unit:RemoveNoDraw() end)
    pcall(function() ResolveNPCPositions(finalPos, 96) end)

    self:ThinkItemUse(bot, now)
end

function DotaKartPublicAI:StartRaceBots()
    if not self.config.enabled then return end
    if not self:LoadTrackPoints() then return end
    self.running = true
    self:StartThink()
    print("[DotaKartPublicAI] IA publica iniciada. bots=" .. tostring(self:GetBotCount()))
end

function DotaKartPublicAI:GetBotCount()
    local n = 0
    for _, bot in pairs(self.bots or {}) do
        if bot ~= nil and DKValidUnit(bot.unit) then n = n + 1 end
    end
    return n
end

function DotaKartPublicAI:StartThink()
    if self._thinkStarted == true then return end
    self._thinkStarted = true
    self._lastThinkTime = DKNow()
    GameRules:GetGameModeEntity():SetContextThink("DotaKartPublicAIThink", function()
        local now = DKNow()
        if self.running == true then
            local dt = now - (self._lastThinkTime or now)
            self._lastThinkTime = now
            dt = DKClamp(dt, 0.01, 0.10)
            for _, bot in pairs(self.bots or {}) do
                self:ThinkBot(bot, now, dt)
            end
        end
        if now >= (self._nextSettingsBroadcast or 0) then
            self._nextSettingsBroadcast = now + 1.0
            self:BroadcastHostSettings()
        end
        return self.config.tick_rate or 0.05
    end, self.config.tick_rate or 0.05)
end

function DotaKartPublicAI:Stop()
    self.running = false
end

function DotaKartPublicAI:RemoveBots()
    for slot, bot in pairs(self.bots or {}) do
        if bot ~= nil then self:UnregisterPublicAIControlIDs(bot) end
        if bot ~= nil then self:DestroyBotVisualProxy(bot) end
        if bot ~= nil and DKValidUnit(bot.unit) then
            local ent = -1
            pcall(function() ent = bot.unit:entindex() end)
            if ent ~= nil and ent >= 0 then
                if self.unitHeroOverrides ~= nil then self.unitHeroOverrides[ent] = nil end
                if _G.DOTA_KART_UNIT_HERO_OVERRIDES ~= nil then _G.DOTA_KART_UNIT_HERO_OVERRIDES[ent] = nil end
            end
            UTIL_Remove(bot.unit)
        end
        if self.hud ~= nil and self.hud.racers ~= nil then self.hud.racers[slot] = nil end
        if self.controller ~= nil then
            if self.controller.heroes ~= nil then self.controller.heroes[slot] = nil end
            if self.controller.states ~= nil then self.controller.states[slot] = nil end
            if self.controller.heldItems ~= nil then self.controller.heldItems[slot] = nil end
        end
    end
    self.bots = {}
    self.running = false
    print("[DotaKartPublicAI] Bots publicos removidos.")
end
