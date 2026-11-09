-- Dota Kart HUD + minimap + laps/ranking system
-- Use este arquivo no addon_game_mode.lua: require("dotakart/hud_server")
-- Karts = heróis dos jogadores.

if DotaKartHUD == nil then
    DotaKartHUD = class({})
end

local function DKClamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function DKLength2D(a, b)
    local dx = b.x - a.x
    local dy = b.y - a.y
    return math.sqrt(dx * dx + dy * dy)
end

local function DKNow()
    return GameRules:GetGameTime()
end

local function DKValidUnit(unit)
    return unit ~= nil and not unit:IsNull()
end

local function DKToBool(value, defaultValue)
    if value == nil then return defaultValue end
    return value == true or value == 1 or value == "1"
end

local function DKGetDisplayHeroName(unit)
    if not DKValidUnit(unit) then return nil end

    local ent = -1
    pcall(function() ent = unit:entindex() end)
    if _G.DOTA_KART_UNIT_HERO_OVERRIDES ~= nil and ent ~= nil and _G.DOTA_KART_UNIT_HERO_OVERRIDES[ent] ~= nil then
        return _G.DOTA_KART_UNIT_HERO_OVERRIDES[ent]
    end

    local name = nil
    pcall(function() name = unit.dk_kart_hero_name end)
    if name ~= nil and name ~= "" then return name end
    pcall(function() name = unit.dotakart_display_hero end)
    if name ~= nil and name ~= "" then return name end
    pcall(function() name = unit.dotakart_public_ai_hero end)
    if name ~= nil and name ~= "" then return name end

    return unit:GetUnitName()
end

function DotaKartHUD:Init()
    print("[DotaKartHUD] Server helper iniciado")

    self.trackBounds = nil
    self.trackWorldPoints = {}
    self.trackSegments = {}
    self.trackLength = 0
    self.trackClosed = true

    self.racers = {}
    self.maxLaps = 3
    self.tickRate = 0.10
    self.raceRunning = false
    self.raceFinished = false
    self.raceStartTime = 0
    self.minLapSeconds = 3.0
    self.lapPassPercent = 0.72
    self.autoRegisterHeroes = true
    self.debugHud = false
    self._raceThinkStarted = false

    -- FIX47: sistema de volta validado por finish_line_gate + checkpoints.
    -- O primeiro cruzamento do finish_line_gate não conta como volta, igual ao start da corrida.
    self.finishGate = nil
    self.finishGatePos = nil
    self.finishGateRadius = 430
    self.finishGateExitRadius = 650
    self.strictFinishGateLaps = true
    self.firstFinishGatePassIsFree = true
    self.lapCheckpointPercents = { 0.25, 0.50, 0.75 }
    self.requiredLapCheckpoints = 3

    -- FIX83: validacao forte por entidades dk_track_*.
    -- Cruzar a linha so conta se o kart passou perto de pelo menos 60% dos pontos
    -- dk_track_001..dk_track_N nesta volta. Isso impede farmar volta indo e voltando
    -- na finish_line_gate sem completar a pista.
    self.trackPointVisitRadius = 1500
    self.requiredTrackPointVisitPercent = 0.60

    -- FIX43: placar final / tela de chegada.
    self.finishOrder = {}
    self.finishCount = 0
    self.finishScreenVisible = false

    -- FIX44: sons locais da corrida.
    -- Estes eventos estão definidos em soundevents/dotakart_announcer.vsndevts.
    self.lapCompleteSound = "dotakart_lap_complete"
    self.finalLapSound = "dotakart_final_lap"
    self.finishPlaceSoundPrefix = "dotakart_announcer_place_"

    -- FIX13: cache do último estado para reenviar quando o Panorama carregar/recarregar.
    self.lastTrackData = nil
    self.lastRacers = {}
    self.lastStates = {}

    if not self._clientReadyListenerRegistered then
        self._clientReadyListenerRegistered = true
        -- FIX15: listener por closure para preservar self.
        CustomGameEventManager:RegisterListener("dotakart_hud_client_ready", function(eventSourceIndex, keys)
            return DotaKartHUD:OnClientReady(eventSourceIndex, keys)
        end)
    end

    -- FIX8: por padrão a HUD usa eventos Panorama, não CustomNetTables.
    -- Isso elimina o spam "Unknown custom nettable" enquanto você testa.
    -- Se quiser voltar a usar net tables depois, coloque no addon_game_mode.lua:
    -- DOTA_KART_USE_NETTABLES = true
    self.useNetTables = (DOTA_KART_USE_NETTABLES == true)

    local defaultState = {
        lap = 1,
        max_laps = 3,
        time_ms = 0,
        place = 1,
        item = "",
        map_x = 0.68,
        map_y = 0.62,
        map_angle = 0
    }

    self:PublishState(0, defaultState)
    self:PublishRacers({})
    self:PublishTrack({ points = {}, closed = 1 })

    self:RegisterDebugCommands()
end

function DotaKartHUD:TrySetNetTable(key, value)
    if not self.useNetTables then
        return
    end

    CustomNetTables:SetTableValue("dotakart_hud", key, value)
end

function DotaKartHUD:PublishTrack(trackData)
    trackData = trackData or { points = {}, closed = 1 }
    self.lastTrackData = trackData
    self:TrySetNetTable("track", trackData)
    CustomGameEventManager:Send_ServerToAllClients("dotakart_hud_update", { track = trackData })
end

function DotaKartHUD:PublishRacers(racers)
    racers = racers or {}
    self.lastRacers = racers
    self:TrySetNetTable("racers", racers)
    CustomGameEventManager:Send_ServerToAllClients("dotakart_hud_update", {
        racers = racers,
        nameplate_decoys = self:GetDoppelwalkNameplates()
    })
end

function DotaKartHUD:PublishState(playerID, state)
    state = state or {}
    state.finish_gate_visible = 0
    if self.trackBounds ~= nil and self.finishGate ~= nil and not self.finishGate:IsNull() then
        state.finish_gate_x, state.finish_gate_y = self:WorldPositionToMap(self.finishGate:GetAbsOrigin())
        state.finish_gate_visible = 1
    end
    self.lastStates = self.lastStates or {}
    self.lastStates[playerID] = state
    self:TrySetNetTable("state_" .. tostring(playerID), state)

    local player = PlayerResource:GetPlayer(playerID)
    if player ~= nil then
        CustomGameEventManager:Send_ServerToPlayer(player, "dotakart_hud_update", state)
    end
end

function DotaKartHUD:GetPlayerIDFromEvent(eventSourceIndex, keys)
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
                if pid ~= nil and pid >= 0 then return pid end
            end
        elseif eventSourceIndex.GetPlayerID ~= nil then
            local pid = eventSourceIndex:GetPlayerID()
            if pid ~= nil and pid >= 0 then return pid end
        end
    end

    return -1
end

function DotaKartHUD:SendFullHudToPlayer(playerID)
    if playerID == nil or playerID < 0 then return end

    local player = PlayerResource:GetPlayer(playerID)
    if player == nil then return end

    -- Se a corrida/pista já foi criada antes do Panorama terminar de carregar, reenviamos aqui.
    if self.lastTrackData ~= nil and self.lastTrackData.points ~= nil and #self.lastTrackData.points >= 2 then
        CustomGameEventManager:Send_ServerToPlayer(player, "dotakart_hud_update", { track = self.lastTrackData })
    end

    if self.lastRacers ~= nil then
        CustomGameEventManager:Send_ServerToPlayer(player, "dotakart_hud_update", { racers = self.lastRacers })
    end

    local state = nil
    if self.lastStates ~= nil then
        state = self.lastStates[playerID] or self.lastStates[0]
    end

    if state ~= nil then
        CustomGameEventManager:Send_ServerToPlayer(player, "dotakart_hud_update", state)
    end

    -- FIX43: ao recarregar Panorama, reenvia placar de chegada apenas se este jogador já terminou.
    local racer = self.racers and self.racers[playerID]
    self:SendFinishBoardToPlayer(playerID, racer ~= nil and racer.finished == true)

    if self.debugHud then
        print("[DotaKartHUD] Reenviei HUD completo para player " .. tostring(playerID))
    end
end

function DotaKartHUD:OnClientReady(eventSourceIndex, keys)
    local playerID = self:GetPlayerIDFromEvent(eventSourceIndex, keys)
    if playerID < 0 then return end
    self:SendFullHudToPlayer(playerID)
end

-- Chame isto depois que o mapa carregar.
-- Coloque entidades info_target no Hammer com os nomes:
-- dk_track_001, dk_track_002, dk_track_003 ... seguindo o centro da pista, em ordem de corrida.
function DotaKartHUD:MakeTrackNameCandidates(prefix, i)
    local prefixes = {}
    prefix = prefix or "dk_track_"

    table.insert(prefixes, prefix)

    -- Aceita tanto dk_track_001 quanto dk_track001.
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

function DotaKartHUD:FindTrackPointEntity(prefix, i)
    local names = self:MakeTrackNameCandidates(prefix, i)
    for _, name in ipairs(names) do
        local ent = Entities:FindByName(nil, name)
        if ent ~= nil then
            return ent, name
        end
    end
    return nil, nil
end

-- Chame isto depois que o mapa carregar.
-- Aceita estes formatos:
-- dk_track_001, dk_track_002...
-- dk_track_1, dk_track_2...
-- dk_track001, dk_track002...
function DotaKartHUD:BuildTrackPathFromEntities(prefix, maxPoints, closed, padding)
    prefix = prefix or "dk_track_"
    maxPoints = maxPoints or 1024
    if closed == nil then closed = true end
    padding = padding or 512

    local worldPoints = {}
    local foundNames = {}
    local missingAfterLastFound = 0

    for i = 1, maxPoints do
        local ent, foundName = self:FindTrackPointEntity(prefix, i)

        if ent ~= nil then
            table.insert(worldPoints, ent:GetAbsOrigin())
            table.insert(foundNames, foundName)
            missingAfterLastFound = 0
        else
            missingAfterLastFound = missingAfterLastFound + 1

            -- Para nao varrer 1024 nomes quando so existem poucos pontos.
            -- So para depois de ja ter encontrado algum ponto e passar 32 indices vazios seguidos.
            if #worldPoints > 0 and missingAfterLastFound >= 32 then
                break
            end
        end
    end

    if #worldPoints < 2 then
        print("[DotaKartHUD] ERRO: nao encontrei pontos suficientes da pista.")
        print("[DotaKartHUD] Crie info_target com targetname: dk_track_001, dk_track_002, dk_track_003...")
        return false
    end

    -- FIX143: Rome has 470 dk_track_* points 250 apart; use every second one (500 apart).
    local romeTrack = GetMapName ~= nil and GetMapName() == "rome" and require("dotakart/maps/rome") or nil
    local stride = romeTrack ~= nil and romeTrack:GetTrackStride() or 1
    if stride > 1 then
        local thinPoints, thinNames = {}, {}
        for i = 1, #worldPoints, stride do
            table.insert(thinPoints, worldPoints[i]); table.insert(thinNames, foundNames[i])
        end
        worldPoints, foundNames = thinPoints, thinNames
    end

    self:SetTrackPathFromWorldPoints(worldPoints, closed, padding)

    print("[DotaKartHUD] Track path criado com " .. tostring(#worldPoints) .. " pontos. Comprimento: " .. tostring(math.floor(self.trackLength or 0)))
    print("[DotaKartHUD] Primeiro ponto: " .. tostring(foundNames[1]) .. " | Ultimo ponto: " .. tostring(foundNames[#foundNames]))

    return true
end


-- ============================================================
-- FIX47: Finish line gate + anti-cheat lap validation.
-- Crie no Hammer uma entidade com targetname: finish_line_gate.
-- O sistema também usa dk_track_* como checkpoints de progresso da volta.
-- ============================================================
function DotaKartHUD:FindFinishLineGate()
    local ent = Entities:FindByName(nil, "finish_line_gate")
    if ent == nil then
        ent = Entities:FindByName(nil, "finish_line_gate_001")
    end

    if ent ~= nil then
        self.finishGate = ent
        self.finishGatePos = ent:GetAbsOrigin()
        local gateName = "finish_line_gate"
        if ent.GetName ~= nil then
            local okName, valueName = pcall(function() return ent:GetName() end)
            if okName and valueName ~= nil and valueName ~= "" then gateName = valueName end
        end
        print("[DotaKartHUD] Finish line gate encontrado: " .. tostring(gateName) .. " pos=" .. tostring(math.floor(self.finishGatePos.x)) .. "," .. tostring(math.floor(self.finishGatePos.y)))
        return ent
    end

    self.finishGate = nil
    self.finishGatePos = nil
    print("[DotaKartHUD] AVISO: finish_line_gate nao encontrado. Fallback para wrap antigo em dk_track_001.")
    return nil
end

function DotaKartHUD:GetFinishGatePosition()
    if self.finishGate ~= nil and not self.finishGate:IsNull() then
        self.finishGatePos = self.finishGate:GetAbsOrigin()
    end
    if self.finishGatePos ~= nil then return self.finishGatePos end
    if self.trackWorldPoints ~= nil and #self.trackWorldPoints >= 1 then return self.trackWorldPoints[1] end
    return nil
end

function DotaKartHUD:IsInsideFinishGate(pos, radius)
    local gatePos = self:GetFinishGatePosition()
    if pos == nil or gatePos == nil then return false end
    return DKLength2D(pos, gatePos) <= (radius or self.finishGateRadius or 430)
end

function DotaKartHUD:ResetLapValidationForRacer(racer, now)
    if racer == nil then return end
    racer.max_distance_this_lap = 0
    racer.lap_checkpoints = {}
    racer.lap_checkpoint_count = 0
    racer.track_point_visits = {}
    racer.track_point_visit_count = 0
    racer.last_lap_time = now or racer.last_lap_time or 0
    -- FIX74: volta so fica armada depois que o kart sai de verdade da largada
    -- e cruza checkpoints em ordem; evita contar volta passando novamente na linha.
    racer.lap_valid_started = false
    racer.last_checkpoint_distance = nil
end

function DotaKartHUD:GetTrackPointRequiredVisitCount()
    local total = #(self.trackWorldPoints or {})
    if total <= 0 then return 0, 0 end
    local pct = tonumber(self.requiredTrackPointVisitPercent or 0.60) or 0.60
    pct = DKClamp(pct, 0.01, 1.0)
    return math.max(1, math.ceil(total * pct)), total
end

function DotaKartHUD:UpdateTrackPointVisits(racer, pos)
    if racer == nil or pos == nil then return end
    local points = self.trackWorldPoints or {}
    if #points <= 0 then return end

    racer.track_point_visits = racer.track_point_visits or {}
    racer.track_point_visit_count = tonumber(racer.track_point_visit_count or 0) or 0

    local radius = tonumber(self.trackPointVisitRadius or 1500) or 1500
    local radiusSq = radius * radius

    for i, p in ipairs(points) do
        if racer.track_point_visits[i] ~= true and p ~= nil then
            local dx = (pos.x or 0) - (p.x or 0)
            local dy = (pos.y or 0) - (p.y or 0)
            if (dx * dx + dy * dy) <= radiusSq then
                racer.track_point_visits[i] = true
                racer.track_point_visit_count = racer.track_point_visit_count + 1
                if self.debugHud then
                    local need, total = self:GetTrackPointRequiredVisitCount()
                    print("[DotaKartHUD] Player " .. tostring(racer.player_id) .. " dk_track visit " .. tostring(racer.track_point_visit_count) .. "/" .. tostring(total) .. " need=" .. tostring(need))
                end
            end
        end
    end
end

function DotaKartHUD:UpdateLapCheckpoints(racer, lastDistance, distance, len, pos)
    if racer == nil or len == nil or len <= 0 then return end
    if distance == nil then return end
    if racer.lap_checkpoints == nil then racer.lap_checkpoints = {} end
    racer.lap_checkpoint_count = tonumber(racer.lap_checkpoint_count or 0) or 0

    -- Nao aceite checkpoints enquanto o kart ainda esta dentro/colado na linha de chegada.
    -- Perto do finish_line_gate a projecao da pista pode alternar entre inicio/fim da spline
    -- e antes isso podia armar todos os checkpoints sem uma volta completa.
    if pos ~= nil and self:IsInsideFinishGate(pos, self.finishGateExitRadius or 650) then
        racer.last_checkpoint_distance = distance
        return
    end

    if racer.lap_valid_started ~= true and distance >= len * 0.12 then
        racer.lap_valid_started = true
    end

    local prev = tonumber(lastDistance or racer.last_checkpoint_distance or distance) or distance
    local delta = distance - prev
    racer.last_checkpoint_distance = distance

    -- Ignora wrap/teleporte para tras na validacao de checkpoint.
    if delta < -len * 0.20 then return end

    local checkpoints = self.lapCheckpointPercents or { 0.25, 0.50, 0.75 }
    for i, pct in ipairs(checkpoints) do
        local threshold = len * pct
        local previousOK = (i == 1) or racer.lap_checkpoints[i - 1] == true
        if previousOK and prev < threshold and distance >= threshold and racer.lap_checkpoints[i] ~= true then
            racer.lap_checkpoints[i] = true
            racer.lap_checkpoint_count = racer.lap_checkpoint_count + 1
            if self.debugHud then
                print("[DotaKartHUD] Player " .. tostring(racer.player_id) .. " checkpoint " .. tostring(i) .. "/" .. tostring(#checkpoints))
            end
        end
    end
end

function DotaKartHUD:IsForwardFinishWrap(lastDistance, distance, len)
    len = math.max(1, tonumber(len or self.trackLength or 1) or 1)
    if lastDistance == nil or distance == nil then return false end
    local delta = distance - lastDistance

    -- Normalmente o finish_line_gate fica no dk_track_001. Cruzar no sentido correto
    -- causa salto do fim da spline para o começo: dist alta -> dist baixa.
    return lastDistance > len * 0.55 and distance < len * 0.35 and delta < -len * 0.40
end

function DotaKartHUD:CanCompleteLapAtGate(racer, now, len, lastDistance, distance)
    if racer == nil then return false, "no_racer" end
    len = math.max(1, tonumber(len or self.trackLength or 1) or 1)

    local timeOK = (now - (racer.last_lap_time or 0)) >= (self.minLapSeconds or 2.0)
    if not timeOK then return false, "min_time" end

    if racer.lap_valid_started ~= true then return false, "not_left_start_zone" end

    local distanceOK = (racer.max_distance_this_lap or 0) >= len * (self.lapPassPercent or 0.72)
    if not distanceOK then return false, "not_enough_distance" end

    local checkpointNeed = tonumber(self.requiredLapCheckpoints or 3) or 3
    local checkpointOK = (racer.lap_checkpoint_count or 0) >= checkpointNeed
    if not checkpointOK then return false, "missing_checkpoints" end

    -- FIX83: validacao por proximidade real das entidades dk_track_*.
    -- Requer no minimo 60% dos pontos visitados antes de permitir completar volta.
    local trackNeed, trackTotal = self:GetTrackPointRequiredVisitCount()
    if trackTotal > 0 then
        local visited = tonumber(racer.track_point_visit_count or 0) or 0
        if visited < trackNeed then
            return false, "missing_track_points_" .. tostring(visited) .. "_of_" .. tostring(trackNeed)
        end
    end

    local directionOK = self:IsForwardFinishWrap(lastDistance, distance, len)

    -- Com finish_line_gate real, a projeção no dk_track_001 pode alternar entre o
    -- primeiro e o último segmento porque a pista é fechada. Se o jogador passou
    -- pelos checkpoints e chegou a >85% da pista, aceitar o gate mesmo sem wrap
    -- perfeito evita falso negativo na linha de chegada.
    if not directionOK and self.finishGatePos ~= nil then
        directionOK = (racer.max_distance_this_lap or 0) >= len * 0.85
    end

    if not directionOK then return false, "wrong_direction" end

    return true, "ok"
end

function DotaKartHUD:HandleFinishGateCrossing(racer, now, pos, lastDistance, distance, len)
    if racer == nil or pos == nil then return false end
    local gatePos = self:GetFinishGatePosition()
    if gatePos == nil then return false end

    local distGate = DKLength2D(pos, gatePos)
    local inside = distGate <= (self.finishGateRadius or 430)
    local exitRadius = self.finishGateExitRadius or ((self.finishGateRadius or 430) + 180)
    local previousPos = racer.finish_gate_last_pos
    racer.finish_gate_last_pos = Vector(pos.x, pos.y, pos.z)

    if racer.finish_gate_inside == true then
        if distGate > exitRadius then racer.finish_gate_inside = false end
        return false
    end

    -- Sweep the traveled segment: fast items can enter and leave the whole gate
    -- between two HUD samples, so testing only the endpoint misses their lap.
    local swept = false
    if previousPos ~= nil then
        local dx, dy = pos.x - previousPos.x, pos.y - previousPos.y
        local lengthSq = dx * dx + dy * dy
        if lengthSq > 0 then
            local t = DKClamp(((gatePos.x - previousPos.x) * dx + (gatePos.y - previousPos.y) * dy) / lengthSq, 0, 1)
            local closest = Vector(previousPos.x + dx * t, previousPos.y + dy * t, pos.z)
            swept = self:IsInsideFinishGate(closest, self.finishGateRadius or 430)
        end
    end
    if not inside and not swept then return false end

    -- Check physical direction as well as spline wrap, including boosted passes.
    if previousPos ~= nil and not self:IsForwardFinishWrap(lastDistance, distance, len) then
        local gateProject = self:ProjectPositionOnTrack(gatePos)
        for _, seg in ipairs(self.trackSegments or {}) do
            if seg.index == gateProject.nearest_segment then
                local dot = (pos.x - previousPos.x) * (seg.b.x - seg.a.x)
                    + (pos.y - previousPos.y) * (seg.b.y - seg.a.y)
                -- FIX130: do not latch finish_gate_inside on a backward sample (wall bounce,
                -- kart bump or projection ambiguity at the gate). Latching here blocked the
                -- real forward crossing until the kart left the gate, so the lap was lost.
                if dot <= 0 then return false end
                break
            end
        end
    end
    racer.finish_gate_inside = distGate <= exitRadius
    racer.finish_gate_passes = (tonumber(racer.finish_gate_passes or 0) or 0) + 1

    if self.firstFinishGatePassIsFree and racer.first_finish_gate_passed ~= true then
        racer.first_finish_gate_passed = true
        self:ResetLapValidationForRacer(racer, now)
        racer.path_distance = distance
        racer.finish_progress_pending_wrap = distance > len * 0.5
        print("[DotaKartHUD] Player " .. tostring(racer.player_id) .. " cruzou o finish_line_gate pela primeira vez: nao conta volta.")
        return true
    end

    local canComplete, reason = self:CanCompleteLapAtGate(racer, now, len, lastDistance, distance)
    if canComplete then
        self:CompleteLap(racer, now)
        -- The gate radius may be entered before projection wraps to segment 1.
        -- Do not add both a new lap AND the old lap's near-full distance.
        racer.finish_progress_pending_wrap = distance > len * 0.5
    else
        -- FIX130: always log rejected gate crossings (Mines lap investigation).
        local need, total = self:GetTrackPointRequiredVisitCount()
        print("[DotaKartHUD] Volta rejeitada p" .. tostring(racer.player_id) .. " reason=" .. tostring(reason) .. " checkpoints=" .. tostring(racer.lap_checkpoint_count or 0) .. " dk_track=" .. tostring(racer.track_point_visit_count or 0) .. "/" .. tostring(total) .. " need=" .. tostring(need) .. " maxDist=" .. tostring(math.floor(racer.max_distance_this_lap or 0)))
    end

    return true
end

function DotaKartHUD:OnRacerTeleported(playerID, pos)
    local racer = self.racers and self.racers[playerID]
    if racer == nil or pos == nil then return end
    -- X returns and position swaps are discontinuous, not driven gate crossings.
    racer.finish_gate_last_pos = Vector(pos.x, pos.y, pos.z)
    racer.finish_gate_inside = self:IsInsideFinishGate(pos, self.finishGateRadius or 430)
end

function DotaKartHUD:GetRacerProgressDistance(racer, distance, len)
    if racer.finish_progress_pending_wrap then
        return distance - len
    end
    return distance
end

function DotaKartHUD:DebugPrintTrack()
    local points = self.trackWorldPoints or {}
    print("[DotaKartHUD] Debug track: pontos carregados = " .. tostring(#points) .. ", length = " .. tostring(math.floor(self.trackLength or 0)))

    for i = 1, math.min(#points, 12) do
        local p = points[i]
        print("[DotaKartHUD] P" .. tostring(i) .. " = " .. tostring(math.floor(p.x)) .. ", " .. tostring(math.floor(p.y)) .. ", " .. tostring(math.floor(p.z)))
    end

    if #points > 12 then
        local p = points[#points]
        print("[DotaKartHUD] ... ultimo P" .. tostring(#points) .. " = " .. tostring(math.floor(p.x)) .. ", " .. tostring(math.floor(p.y)) .. ", " .. tostring(math.floor(p.z)))
    end
end

function DotaKartHUD:RebuildTrackSegments()
    self.trackSegments = {}
    self.trackLength = 0

    local points = self.trackWorldPoints or {}
    local count = #points
    if count < 2 then return end

    local lastIndex = self.trackClosed and count or (count - 1)
    for i = 1, lastIndex do
        local j = i + 1
        if j > count then j = 1 end

        local a = points[i]
        local b = points[j]
        local len = DKLength2D(a, b)

        if len > 1 then
            table.insert(self.trackSegments, {
                a = a,
                b = b,
                length = len,
                cumulative = self.trackLength,
                index = i
            })
            self.trackLength = self.trackLength + len
        end
    end
end

-- Se você já tem checkpoints em Lua, pode mandar os Vector diretamente.
function DotaKartHUD:SetTrackPathFromWorldPoints(worldPoints, closed, padding)
    if worldPoints == nil or #worldPoints < 2 then return false end
    if closed == nil then closed = true end
    padding = padding or 512

    self.trackWorldPoints = worldPoints
    self.trackClosed = closed
    self:RebuildTrackSegments()

    local minX = worldPoints[1].x
    local maxX = worldPoints[1].x
    local minY = worldPoints[1].y
    local maxY = worldPoints[1].y

    for _, pos in ipairs(worldPoints) do
        if pos.x < minX then minX = pos.x end
        if pos.x > maxX then maxX = pos.x end
        if pos.y < minY then minY = pos.y end
        if pos.y > maxY then maxY = pos.y end
    end

    minX = minX - padding
    maxX = maxX + padding
    minY = minY - padding
    maxY = maxY + padding

    local width = math.max(1, maxX - minX)
    local height = math.max(1, maxY - minY)

    self.trackBounds = {
        min_x = minX,
        max_x = maxX,
        min_y = minY,
        max_y = maxY,
        width = width,
        height = height
    }

    local points = {}
    for i, pos in ipairs(worldPoints) do
        points[i] = {
            x = DKClamp((pos.x - minX) / width, 0, 1),
            -- Inverte Y porque no mundo o Y sobe, mas no Panorama o Y desce.
            y = DKClamp(1 - ((pos.y - minY) / height), 0, 1)
        }
    end

    self:PublishTrack({
        points = points,
        closed = closed and 1 or 0,
        bounds = {
            min_x = minX,
            max_x = maxX,
            min_y = minY,
            max_y = maxY
        },
        length = self.trackLength
    })

    return true
end

function DotaKartHUD:WorldPositionToMap(pos)
    if pos == nil then return 0.5, 0.5 end

    local b = self.trackBounds
    if b == nil then
        return 0.5, 0.5
    end

    local nx = DKClamp((pos.x - b.min_x) / b.width, 0, 1)
    local ny = DKClamp(1 - ((pos.y - b.min_y) / b.height), 0, 1)
    return nx, ny
end

function DotaKartHUD:Atan2(y, x)
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

function DotaKartHUD:GetUnitMapAngle(unit)
    if unit == nil or unit:IsNull() then return 0 end

    local fwd = unit:GetForwardVector()
    local radians = self:Atan2(fwd.y, fwd.x)

    -- Negativo porque o eixo Y da HUD é invertido.
    return -math.deg(radians)
end

local RomeTrack = GetMapName ~= nil and GetMapName() == "rome" and require("dotakart/maps/rome") or nil

function DotaKartHUD:ProjectPositionOnTrack(pos)
    if pos == nil or self.trackSegments == nil or #self.trackSegments == 0 or self.trackLength <= 0 then
        return {
            distance = 0,
            normalized = 0,
            nearest_segment = 1,
            nearest_dist_sq = 0,
            t = 0
        }
    end

    local best = nil

    for _, seg in ipairs(self.trackSegments) do
        local ax = seg.a.x
        local ay = seg.a.y
        local bx = seg.b.x
        local by = seg.b.y
        local abx = bx - ax
        local aby = by - ay
        local apx = pos.x - ax
        local apy = pos.y - ay
        local lenSq = abx * abx + aby * aby
        local t = 0

        if lenSq > 1 then
            t = (apx * abx + apy * aby) / lenSq
            t = DKClamp(t, 0, 1)
        end

        local px = ax + abx * t
        local py = ay + aby * t
        local dx = pos.x - px
        local dy = pos.y - py
        local distSq = dx * dx + dy * dy
        local pathDistance = seg.cumulative + seg.length * t

        if best == nil or distSq < best.nearest_dist_sq then
            best = {
                distance = pathDistance,
                normalized = pathDistance / self.trackLength,
                nearest_segment = seg.index,
                nearest_dist_sq = distSq,
                t = t
            }
        end
    end

    if RomeTrack ~= nil and best ~= nil then best = RomeTrack:ProjectBranch(pos, self, best) end
    return best or {
        distance = 0,
        normalized = 0,
        nearest_segment = 1,
        nearest_dist_sq = 0,
        t = 0
    }
end

function DotaKartHUD:GetHeroForPlayer(playerID)
    if PlayerResource == nil then return nil end
    if not PlayerResource:IsValidPlayerID(playerID) then return nil end

    local hero = PlayerResource:GetSelectedHeroEntity(playerID)
    if DKValidUnit(hero) then return hero end

    return nil
end

function DotaKartHUD:RegisterKart(playerID, hero)
    if playerID == nil then return nil end

    if hero == nil then
        hero = self:GetHeroForPlayer(playerID)
    end

    if not DKValidUnit(hero) then
        return nil
    end

    local displayHero = DKGetDisplayHeroName(hero) or hero:GetUnitName()

    local existing = self.racers[playerID]
    if existing ~= nil then
        existing.unit = hero
        if existing.hero_override ~= nil and existing.hero_override ~= "" then
            existing.hero = existing.hero_override
        else
            existing.hero = displayHero
        end
        return existing
    end

    local racer = {
        player_id = playerID,
        unit = hero,
        hero = displayHero,
        completed_laps = 0,
        lap = 1,
        place = 1,
        path_distance = nil,
        max_distance_this_lap = 0,
        progress = 0,
        finished = false,
        finish_time_ms = nil,
        item = "",
        item_charges = 0,
        last_lap_time = -9999,
        lap_checkpoints = {},
        lap_checkpoint_count = 0,
        track_point_visits = {},
        track_point_visit_count = 0,
        lap_valid_started = false,
        last_checkpoint_distance = nil,
        last_project = nil
    }

    self.racers[playerID] = racer
    return racer
end

function DotaKartHUD:AutoRegisterHeroKarts()
    for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(playerID) then
            local hero = self:GetHeroForPlayer(playerID)
            if DKValidUnit(hero) then
                self:RegisterKart(playerID, hero)
            end
        end
    end
end

-- FIX131: racers that start already past the finish line (random grid slots outside the
-- gate radius) must not get the free first crossing; otherwise their real lap 1 crossing
-- was eaten as the free pass and the progress wrap dropped them to last place.
function DotaKartHUD:IsAheadOfFinishGate(pos)
    local gatePos = self:GetFinishGatePosition()
    if pos == nil or gatePos == nil or self.finishGatePos == nil then return false end
    local len = math.max(1, tonumber(self.trackLength or 1) or 1)
    local kart = self:ProjectPositionOnTrack(pos)
    local gate = self:ProjectPositionOnTrack(gatePos)
    local ahead = ((tonumber(kart.distance) or 0) - (tonumber(gate.distance) or 0)) % len
    return ahead < len * 0.5
end

function DotaKartHUD:ResetRacerForRace(racer, now)
    racer.completed_laps = 0
    racer.lap = 1
    racer.place = 1
    racer.path_distance = nil
    racer.max_distance_this_lap = 0
    racer.progress = 0
    racer.finished = false
    racer.finish_time_ms = nil
    racer.finish_place = nil
    racer.finish_removed = false
    racer.last_lap_time = now or 0
    racer.last_project = nil
    racer.first_finish_gate_passed = false
    racer.finish_gate_passes = 0
    racer.finish_progress_pending_wrap = false
    racer.finish_gate_last_pos = nil
    racer.lap_checkpoints = {}
    racer.lap_checkpoint_count = 0
    racer.track_point_visits = {}
    racer.track_point_visit_count = 0
    racer.lap_valid_started = false
    racer.last_checkpoint_distance = nil

    local unit = racer.unit
    if DKValidUnit(unit) then
        local pos = unit:GetAbsOrigin()
        racer.finish_gate_last_pos = Vector(pos.x, pos.y, pos.z)
        -- Se o jogador nasce dentro da área da linha, ele precisa sair e cruzar de novo.
        -- Isso evita contar a largada como volta.
        racer.finish_gate_inside = self:IsInsideFinishGate(unit:GetAbsOrigin(), self.finishGateRadius or 430)
        if self.firstFinishGatePassIsFree == true and (racer.finish_gate_inside == true or self:IsAheadOfFinishGate(pos)) then
            -- Nascer em cima/antes da linha já consome a passagem inicial gratuita.
            racer.first_finish_gate_passed = true
        end
    else
        racer.finish_gate_inside = false
    end
end

function DotaKartHUD:SetRacerItem(playerID, itemName, itemCharges)
    local racer = self.racers[playerID]
    if racer ~= nil then
        racer.item = itemName or ""
        racer.item_charges = tonumber(itemCharges or 0) or 0
    end
end

function DotaKartHUD:StartRace(options)
    options = options or {}

    self.maxLaps = options.max_laps or options.maxLaps or self.maxLaps or 3
    self.tickRate = options.tick_rate or options.tickRate or self.tickRate or 0.10
    self.minLapSeconds = options.min_lap_seconds or options.minLapSeconds or self.minLapSeconds or 3.0
    self.lapPassPercent = options.lap_pass_percent or options.lapPassPercent or self.lapPassPercent or 0.72
    self.debugHud = DKToBool(options.debug, self.debugHud)
    self.autoRegisterHeroes = DKToBool(options.auto_register_heroes or options.autoRegisterHeroes, true)

    local prefix = options.prefix or "dk_track_"
    local maxPoints = options.max_points or options.maxPoints or 512
    local closed = DKToBool(options.closed, true)
    local padding = options.padding or 512

    if self.trackWorldPoints == nil or #self.trackWorldPoints < 2 then
        self:BuildTrackPathFromEntities(prefix, maxPoints, closed, padding)
    else
        -- Reenvia o track para a HUD caso o Panorama tenha recarregado.
        self:SetTrackPathFromWorldPoints(self.trackWorldPoints, self.trackClosed, padding)
    end

    self.finishGateRadius = options.finish_gate_radius or options.finishGateRadius or self.finishGateRadius or 430
    self.finishGateExitRadius = options.finish_gate_exit_radius or options.finishGateExitRadius or self.finishGateExitRadius or 650
    self.firstFinishGatePassIsFree = DKToBool(options.first_finish_gate_pass_is_free or options.firstFinishGatePassIsFree, self.firstFinishGatePassIsFree)
    self.requiredLapCheckpoints = options.required_checkpoints or options.requiredCheckpoints or self.requiredLapCheckpoints or 3
    self.trackPointVisitRadius = options.track_point_visit_radius or options.trackPointVisitRadius or self.trackPointVisitRadius or 1500
    self.requiredTrackPointVisitPercent = options.required_track_point_visit_percent or options.requiredTrackPointVisitPercent or self.requiredTrackPointVisitPercent or 0.60
    self:FindFinishLineGate()

    if self.trackLength <= 0 then
        print("[DotaKartHUD] ERRO: não dá para iniciar corrida sem pista. Verifique dk_track_001...")
        return false
    end

    if self.autoRegisterHeroes then
        self:AutoRegisterHeroKarts()
    end

    local racerCount = 0
    for _, _ in pairs(self.racers) do
        racerCount = racerCount + 1
    end

    if racerCount == 0 then
        print("[DotaKartHUD] AVISO: nenhum herói/kart registrado ainda. Vou continuar tentando no TickRace.")
    end

    self.raceStartTime = DKNow()
    self.raceRunning = true
    self.raceFinished = false
    self.finishOrder = {}
    self.finishCount = 0
    self.finishScreenVisible = false
    self:PublishFinishBoard(false)

    for _, racer in pairs(self.racers) do
        self:ResetRacerForRace(racer, self.raceStartTime)
    end

    self:StartRaceThink()
    self:UpdateRaceNow()

    -- FIX13: reenvia o path algumas vezes porque Panorama pode carregar depois do servidor.
    for i = 1, 8 do
        GameRules:GetGameModeEntity():SetContextThink("DotaKartHUDTrackRefresh" .. tostring(i), function()
            if self.lastTrackData ~= nil then
                self:PublishTrack(self.lastTrackData)
            end
            if self.lastRacers ~= nil then
                self:PublishRacers(self.lastRacers)
            end
            return nil
        end, 0.25 * i)
    end

    local trackNeed, trackTotal = self:GetTrackPointRequiredVisitCount()
    print("[DotaKartHUD] Corrida iniciada. Voltas: " .. tostring(self.maxLaps) .. ", karts registrados: " .. tostring(racerCount) .. ", dk_track lap gate: " .. tostring(trackNeed) .. "/" .. tostring(trackTotal) .. " radius=" .. tostring(self.trackPointVisitRadius or 1500))
    return true
end

function DotaKartHUD:StopRace()
    self.raceRunning = false
    self.raceFinished = true
    print("[DotaKartHUD] Corrida parada/finalizada.")
end

function DotaKartHUD:StartRaceThink()
    if self._raceThinkStarted then return end
    self._raceThinkStarted = true

    local thinkEnt = GameRules:GetGameModeEntity()
    thinkEnt:SetContextThink("DotaKartHUDRaceThink", function()
        if self.raceRunning then
            self:UpdateRaceNow()
        end
        return self.tickRate or 0.10
    end, self.tickRate or 0.10)
end

-- FIX44: toca som 2D apenas para um jogador específico.
function DotaKartHUD:PlaySoundForPlayer(playerID, soundName, options)
    playerID = tonumber(playerID) or -1
    if playerID < 0 or soundName == nil or soundName == "" then return end

    local player = PlayerResource ~= nil and PlayerResource:GetPlayer(playerID) or nil
    if player == nil then return end

    -- Servidor tenta tocar soundevent; Panorama recebe fallback para raw .vsnd/event aliases.
    pcall(function() EmitSoundOnClient(soundName, player) end)
    CustomGameEventManager:Send_ServerToPlayer(player, "dotakart_ui_sound", {
        sound = soundName,
        action = "play",
        reason = options and options.reason or "race"
    })
end

function DotaKartHUD:PlayLapSoundForRacer(racer)
    if racer == nil or racer.player_id == nil then return end
    local completed = tonumber(racer.completed_laps or 0) or 0
    local maxLaps = math.max(1, tonumber(self.maxLaps or 3) or 3)

    -- Ao completar a penúltima volta, o jogador entrou na última volta: som diferente.
    if completed == maxLaps - 1 then
        self:PlaySoundForPlayer(racer.player_id, self.finalLapSound or "dotakart_final_lap", { reason = "final_lap" })
    elseif completed > 0 and completed < maxLaps then
        self:PlaySoundForPlayer(racer.player_id, self.lapCompleteSound or "dotakart_lap_complete", { reason = "lap_complete" })
    end
end

function DotaKartHUD:GetFinishPlaceSound(place)
    place = tonumber(place) or 0
    if place < 1 or place > 8 then return nil end
    return (self.finishPlaceSoundPrefix or "dotakart_announcer_place_") .. string.format("%02d", place)
end

function DotaKartHUD:PlayFinishPlaceSoundForRacer(racer)
    if racer == nil then return end
    local soundName = self:GetFinishPlaceSound(racer.finish_place or racer.place or 0)
    if soundName ~= nil then
        self:PlaySoundForPlayer(racer.player_id, soundName, { reason = "finish_place" })
    end
end

function DotaKartHUD:CompleteLap(racer, now)
    if racer == nil or racer.finished then return end

    racer.completed_laps = racer.completed_laps + 1
    racer.lap = math.min(racer.completed_laps + 1, self.maxLaps)
    racer.max_distance_this_lap = 0
    racer.lap_checkpoints = {}
    racer.lap_checkpoint_count = 0
    racer.track_point_visits = {}
    racer.track_point_visit_count = 0
    racer.lap_valid_started = false
    racer.last_checkpoint_distance = nil
    racer.last_lap_time = now

    print("[DotaKartHUD] Player " .. tostring(racer.player_id) .. " completou volta " .. tostring(racer.completed_laps) .. "/" .. tostring(self.maxLaps))

    if racer.completed_laps >= self.maxLaps then
        self:FinishRacer(racer, now, "lap_complete")
    else
        self:PlayLapSoundForRacer(racer)
    end
end

function DotaKartHUD:UpdateSingleRacer(racer, now)
    if racer == nil then return end

    local unit = racer.unit
    if not DKValidUnit(unit) then
        unit = self:GetHeroForPlayer(racer.player_id)
        racer.unit = unit
    end

    if racer.finished then
        racer.progress = self.maxLaps * math.max(1, self.trackLength or 1)
        return
    end

    if not DKValidUnit(unit) then return end
    if racer.hero_override ~= nil and racer.hero_override ~= "" then
        racer.hero = racer.hero_override
    else
        racer.hero = DKGetDisplayHeroName(unit) or unit:GetUnitName()
    end

    local pos = unit:GetAbsOrigin()
    local project = self:ProjectPositionOnTrack(pos)
    racer.last_project = project

    -- FIX33: guarda coordenadas de minimapa de todos os karts para renderizar
    -- mini-icones no HUD, incluindo bots/autobots.
    local mapX, mapY = self:WorldPositionToMap(pos)
    racer.map_x = mapX or 0.5
    racer.map_y = mapY or 0.5
    racer.map_angle = self:GetUnitMapAngle(unit) or 0

    -- FIX121: validate sudden forward track jumps before committing lap/progress data.
    -- Official dk_track_skip areas are exempted inside DotaKartAntiSkip.
    local antiSkip = GameRules and GameRules.DotaKartAntiSkip or nil
    if antiSkip ~= nil and antiSkip.OnRacerProjected ~= nil then
        local ok, blockProgress = pcall(function()
            return antiSkip:OnRacerProjected(racer, unit, pos, project, now)
        end)
        if ok and blockProgress == true then return end
    end

    local distance = project.distance or 0
    local len = math.max(1, self.trackLength or 1)

    if racer.finished then
        racer.progress = self.maxLaps * len
        racer.path_distance = distance
        return
    end

    if racer.path_distance == nil then
        racer.path_distance = distance
        racer.finish_gate_last_pos = Vector(pos.x, pos.y, pos.z)
        if self.finishGatePos ~= nil and (racer.completed_laps or 0) == 0 then
            racer.finish_progress_pending_wrap = distance > len * 0.5
        end
        racer.max_distance_this_lap = distance
        racer.lap_checkpoints = racer.lap_checkpoints or {}
        racer.lap_checkpoint_count = racer.lap_checkpoint_count or 0
        racer.track_point_visits = racer.track_point_visits or {}
        racer.track_point_visit_count = racer.track_point_visit_count or 0
        self:UpdateTrackPointVisits(racer, pos)
        racer.finish_gate_inside = self:IsInsideFinishGate(pos, self.finishGateRadius or 430)
        if self.firstFinishGatePassIsFree == true and (racer.finish_gate_inside == true or self:IsAheadOfFinishGate(pos)) then
            racer.first_finish_gate_passed = true
        end
        print("[DotaKartHUD] FIX131 start p" .. tostring(racer.player_id) .. " dist=" .. tostring(math.floor(distance)) .. "/" .. tostring(math.floor(len)) .. " insideGate=" .. tostring(racer.finish_gate_inside) .. " firstGateUsed=" .. tostring(racer.first_finish_gate_passed))
    else
        local lastDistance = racer.path_distance
        local delta = distance - lastDistance
        if self.finishGatePos ~= nil then
            if self:IsForwardFinishWrap(lastDistance, distance, len) then
                racer.finish_progress_pending_wrap = false
            elseif lastDistance < len * 0.35 and distance > len * 0.55 and delta > len * 0.40 then
                -- Reversing back across the seam must not grant almost a lap of
                -- ranking progress while completed_laps stays unchanged.
                racer.finish_progress_pending_wrap = true
            end
        end

        -- Movimento normal, ou pequena ré. Atualiza o maior progresso da volta atual.
        if delta > -len * 0.20 then
            if distance > (racer.max_distance_this_lap or 0) then
                racer.max_distance_this_lap = distance
            end
        end

        self:UpdateTrackPointVisits(racer, pos)
        self:UpdateLapCheckpoints(racer, lastDistance, distance, len, pos)

        local gateHandled = false
        if self.finishGatePos ~= nil then
            gateHandled = self:HandleFinishGateCrossing(racer, now, pos, lastDistance, distance, len)
        else
            -- Fallback para mapas antigos sem finish_line_gate: usa wrap antigo, mas ainda exige checkpoints.
            if self:IsForwardFinishWrap(lastDistance, distance, len) then
                if racer.first_finish_gate_passed ~= true and self.firstFinishGatePassIsFree then
                    racer.first_finish_gate_passed = true
                    self:ResetLapValidationForRacer(racer, now)
                    if self.debugHud then print("[DotaKartHUD] Primeiro wrap ignorado para player " .. tostring(racer.player_id)) end
                else
                    local canComplete, reason = self:CanCompleteLapAtGate(racer, now, len, lastDistance, distance)
                    if canComplete then
                        self:CompleteLap(racer, now)
                    elseif self.debugHud then
                        print("[DotaKartHUD] Wrap rejeitado p" .. tostring(racer.player_id) .. " reason=" .. tostring(reason))
                    end
                end
            end
        end

        racer.path_distance = distance
    end

    if racer.finished then
        racer.progress = self.maxLaps * len
    else
        racer.lap = math.min((racer.completed_laps or 0) + 1, self.maxLaps)
        racer.progress = (racer.completed_laps or 0) * len + self:GetRacerProgressDistance(racer, distance, len)
    end
end

function DotaKartHUD:BuildSortedRacerList(now)
    local list = {}

    for playerID, racer in pairs(self.racers) do
        if racer ~= nil then
            table.insert(list, racer)
        end
    end

    table.sort(list, function(a, b)
        if a.finished ~= b.finished then
            return a.finished == true
        end

        if a.finished and b.finished then
            return (a.finish_time_ms or 999999999) < (b.finish_time_ms or 999999999)
        end

        return (a.progress or 0) > (b.progress or 0)
    end)

    for i, racer in ipairs(list) do
        racer.place = i
    end

    return list
end

function DotaKartHUD:GetRacerNameplateData(racer)
    local unit = racer.unit
    local data = { entindex = -1, steam_id = "", is_bot = racer.is_bot and 1 or 0, nameplate_hidden = 1 }
    if unit ~= nil and not unit:IsNull() then
        data.entindex = unit:entindex()
        local hidden = unit.IsAlive ~= nil and not unit:IsAlive()
        if unit.IsInvisible ~= nil and unit:IsInvisible() then hidden = true end
        if unit.IsOutOfGame ~= nil and unit:IsOutOfGame() then hidden = true end
        data.nameplate_hidden = hidden and 1 or 0
    end
    local playerID = tonumber(racer.player_id) or -1
    if not racer.is_bot and playerID >= 0 and PlayerResource ~= nil
        and PlayerResource:IsValidPlayerID(playerID) and PlayerResource.GetSteamID ~= nil then
        -- Keep the 64-bit ID as a string all the way to Panorama.
        data.steam_id = tostring(PlayerResource:GetSteamID(playerID) or "")
    end
    return data
end

function DotaKartHUD:GetDoppelwalkNameplates()
    local result = {}
    local items = GameRules.DotaKartItemSystem
    local now = DKNow()
    for targetID, decoy in pairs((items and items.activeDoppelwalkDecoys) or {}) do
        -- The item table also contains owner aliases; send each clone only once.
        if type(targetID) == "number" and decoy ~= nil and not decoy.destroyed
            and now < (decoy.end_time or 0) and decoy.unit ~= nil and not decoy.unit:IsNull() then
            local owner = tonumber(decoy.owner_player_id) or -1
            local racer = self.racers and self.racers[owner]
            if racer ~= nil then
                local data = self:GetRacerNameplateData({ unit = decoy.unit, player_id = owner, is_bot = racer.is_bot })
                data.player_id = owner
                data.player_name = self:GetPlayerDisplayName(owner, racer)
                data.hero = racer.hero or "npc_dota_hero_wisp"
                data.is_decoy = 1
                result[#result + 1] = data
            end
        end
    end
    return result
end

function DotaKartHUD:UpdateRaceNow()
    if self.autoRegisterHeroes then
        self:AutoRegisterHeroKarts()
    end

    local now = DKNow()
    local raceTimeMs = 0
    if self.raceStartTime ~= nil and self.raceStartTime > 0 then
        raceTimeMs = math.floor((now - self.raceStartTime) * 1000)
    end

    for _, racer in pairs(self.racers) do
        self:UpdateSingleRacer(racer, now)
    end

    local sorted = self:BuildSortedRacerList(now)
    local standings = {}
    local allFinished = #sorted > 0

    for i, racer in ipairs(sorted) do
        if not racer.finished then
            allFinished = false
        end

        local nameplate = self:GetRacerNameplateData(racer)
        standings[i] = {
            player_id = racer.player_id,
            entindex = nameplate.entindex,
            steam_id = nameplate.steam_id,
            is_bot = nameplate.is_bot,
            nameplate_hidden = nameplate.nameplate_hidden,
            hero = racer.hero or "npc_dota_hero_wisp",
            place = racer.place or i,
            lap = racer.lap or 1,
            finished = racer.finished and 1 or 0,
            finish_time_ms = racer.finish_time_ms or 0,
            finish_place = racer.finish_place or 0,
            player_name = self:GetPlayerDisplayName(racer.player_id, racer),
            map_x = racer.map_x or 0.5,
            map_y = racer.map_y or 0.5,
            map_angle = racer.map_angle or 0
        }
    end

    self:SetRacers(standings)

    for _, racer in ipairs(sorted) do
        local stateTime = raceTimeMs
        if racer.finished and racer.finish_time_ms ~= nil then
            stateTime = racer.finish_time_ms
        end

        local debugText = nil
        if self.debugHud and racer.last_project ~= nil then
            debugText = "lap " .. tostring(racer.lap) .. "/" .. tostring(self.maxLaps) ..
                " dist " .. tostring(math.floor(racer.path_distance or 0)) .. "/" .. tostring(math.floor(self.trackLength or 0)) ..
                " seg " .. tostring(racer.last_project.nearest_segment or 0)
        end

        self:SetPlayerState(racer.player_id, {
            lap = racer.lap or 1,
            max_laps = self.maxLaps,
            time_ms = stateTime,
            place = racer.place or 1,
            item = racer.item or "",
            item_charges = racer.item_charges or 0,
            unit = racer.unit,
            debug = debugText
        })
    end

    if self.finishScreenVisible then
        self:PublishFinishBoard(true)
    end

    if allFinished and not self.raceFinished then
        self.raceFinished = true
        self.raceRunning = false
        print("[DotaKartHUD] Todos os karts terminaram a corrida.")
    end
end

-- Chame isto para cada jogador, preferencialmente a cada 0.1s ou quando algo mudar.
-- Se passar unit/hero/world_pos, o helper calcula map_x/map_y automaticamente.
function DotaKartHUD:SetPlayerState(playerID, state)
    if playerID == nil or state == nil then return end

    local mapX = state.map_x or state.mapX
    local mapY = state.map_y or state.mapY
    local mapAngle = state.map_angle or state.mapAngle or 0

    local pos = state.world_pos or state.worldPos
    local unit = state.unit or state.hero

    if unit ~= nil and not unit:IsNull() then
        pos = unit:GetAbsOrigin()
        if state.map_angle == nil and state.mapAngle == nil then
            mapAngle = self:GetUnitMapAngle(unit)
        end
    end

    if pos ~= nil and (mapX == nil or mapY == nil) then
        mapX, mapY = self:WorldPositionToMap(pos)
    end

    self:PublishState(playerID, {
        lap = state.lap or 1,
        max_laps = state.max_laps or state.maxLaps or self.maxLaps or 3,
        time_ms = state.time_ms or state.timeMs or 0,
        place = state.place or state.position or 1,
        item = state.item or state.item_name or "",
        item_charges = state.item_charges or state.itemCharges or state.charges or 0,
        map_x = mapX or 0.5,
        map_y = mapY or 0.5,
        map_angle = mapAngle or 0,
        debug = state.debug or nil
    })
end

function DotaKartHUD:SetPlayerStateFromUnit(playerID, unit, state)
    state = state or {}
    state.unit = unit
    self:SetPlayerState(playerID, state)
end


-- ============================================================
-- FIX43: comandos de teste de voltas e tela de chegada.
-- ============================================================
function DotaKartHUD:GetPlayerDisplayName(playerID, racer)
    playerID = tonumber(playerID) or -1

    -- FIX59: para jogadores humanos, usa o nome publico Steam/Dota mostrado pelo PlayerResource.
    if PlayerResource ~= nil and playerID >= 0 and PlayerResource:IsValidPlayerID(playerID) then
        local name = PlayerResource:GetPlayerName(playerID)
        if name ~= nil and name ~= "" then return name end
    end

    if racer ~= nil and racer.player_name ~= nil and racer.player_name ~= "" then
        return racer.player_name
    end

    -- Bots/slots sem PlayerResource não aparecem mais como "Kart" na tela final.
    if racer ~= nil and racer.is_bot == true then
        return "CPU " .. tostring((playerID >= 0 and playerID + 1) or "")
    end

    return "Player " .. tostring(playerID)
end

function DotaKartHUD:GetFinishResults()
    local results = {}
    local list = {}
    for _, racer in pairs(self.racers or {}) do
        if racer ~= nil and racer.finished == true then
            table.insert(list, racer)
        end
    end
    table.sort(list, function(a, b)
        local ap = tonumber(a.finish_place or 999) or 999
        local bp = tonumber(b.finish_place or 999) or 999
        if ap ~= bp then return ap < bp end
        return (tonumber(a.finish_time_ms or 999999999) or 999999999) < (tonumber(b.finish_time_ms or 999999999) or 999999999)
    end)

    for i, racer in ipairs(list) do
        results[i] = {
            player_id = racer.player_id,
            player_name = self:GetPlayerDisplayName(racer.player_id, racer),
            hero = racer.hero or "npc_dota_hero_wisp",
            place = racer.finish_place or i,
            time_ms = racer.finish_time_ms or 0
        }
    end
    return results
end

function DotaKartHUD:BuildFinishBoardDataForPlayer(playerID, visible)
    visible = visible == true
    return {
        visible = visible and 1 or 0,
        results = self:GetFinishResults(),
        max_laps = self.maxLaps or 3,
        player_id = playerID or -1
    }
end

function DotaKartHUD:SendFinishBoardToPlayer(playerID, visible)
    playerID = tonumber(playerID) or -1
    if playerID < 0 then return end
    local player = PlayerResource ~= nil and PlayerResource:GetPlayer(playerID) or nil
    if player == nil then return end

    local data = self:BuildFinishBoardDataForPlayer(playerID, visible)
    CustomGameEventManager:Send_ServerToPlayer(player, "dotakart_finish_update", data)
    -- Também envia pelo evento principal para sobreviver a reload do Panorama.
    CustomGameEventManager:Send_ServerToPlayer(player, "dotakart_hud_update", { finish = data })
end

function DotaKartHUD:PublishFinishBoard(visible)
    -- FIX43: a tela de chegada só aparece para jogadores que já terminaram.
    -- Jogadores ainda correndo recebem explicitamente visible=0 para não abrir a tela.
    visible = visible == true
    local maxPlayers = DOTA_MAX_TEAM_PLAYERS or 24
    for playerID = 0, maxPlayers - 1 do
        if PlayerResource ~= nil and PlayerResource:IsValidPlayerID(playerID) then
            local racer = self.racers and self.racers[playerID]
            local showForThisPlayer = visible and racer ~= nil and racer.finished == true
            self:SendFinishBoardToPlayer(playerID, showForThisPlayer)
        end
    end
end

function DotaKartHUD:HideFinishedKart(racer)
    if racer == nil or racer.finish_removed == true then return end
    local unit = racer.unit or self:GetHeroForPlayer(racer.player_id)
    if DKValidUnit(unit) then
        if racer.hero_override ~= nil and racer.hero_override ~= "" then
            racer.hero = racer.hero_override
        else
            racer.hero = DKGetDisplayHeroName(unit) or unit:GetUnitName()
        end
        racer.finish_removed = true
        pcall(function() unit:Stop() end)
        pcall(function() unit:AddNoDraw() end)
        pcall(function() unit:SetAbsOrigin(Vector(0, 0, -6000)) end)
        pcall(function() unit:AddNewModifier(unit, nil, "modifier_invulnerable", {}) end)
    end
end

function DotaKartHUD:FinishRacer(racer, now, reason)
    if racer == nil or racer.finished == true then return end
    now = now or DKNow()
    racer.finished = true
    racer.completed_laps = self.maxLaps
    racer.lap = self.maxLaps
    racer.finish_time_ms = math.floor((now - (self.raceStartTime or now)) * 1000)
    racer.progress = (self.maxLaps or 3) * math.max(1, self.trackLength or 1)
    self.finishCount = (tonumber(self.finishCount or 0) or 0) + 1
    racer.finish_place = self.finishCount
    self.finishScreenVisible = true

    self:PlayFinishPlaceSoundForRacer(racer)
    self:HideFinishedKart(racer)
    self:PublishFinishBoard(true)

    print("[DotaKartHUD] Player " .. tostring(racer.player_id) .. " terminou a corrida em " .. tostring(racer.finish_time_ms) .. " ms place=" .. tostring(racer.finish_place) .. " reason=" .. tostring(reason or ""))
end

function DotaKartHUD:IsPlayerFinished(playerID)
    local racer = self.racers and self.racers[playerID]
    return racer ~= nil and racer.finished == true
end

function DotaKartHUD:SetPlayerCompletedLaps(playerID, completedLaps)
    playerID = tonumber(playerID) or 0
    completedLaps = tonumber(completedLaps) or 0
    local racer = self.racers[playerID]
    if racer == nil then
        local hero = self:GetHeroForPlayer(playerID)
        if DKValidUnit(hero) then racer = self:RegisterKart(playerID, hero) end
    end
    if racer == nil then
        print("[DotaKartHUD] dk_set_lap: racer nao encontrado playerID=" .. tostring(playerID))
        return
    end

    local maxLaps = math.max(1, tonumber(self.maxLaps or 3) or 3)
    completedLaps = math.max(0, math.min(completedLaps, maxLaps))
    if completedLaps >= maxLaps then
        racer.completed_laps = maxLaps - 1
        self:FinishRacer(racer, DKNow(), "console")
        return
    end

    racer.finished = false
    racer.finish_time_ms = nil
    racer.finish_place = nil
    racer.finish_removed = false
    racer.completed_laps = completedLaps
    racer.lap = math.min(completedLaps + 1, maxLaps)
    racer.max_distance_this_lap = 0
    racer.path_distance = nil
    print("[DotaKartHUD] Player " .. tostring(playerID) .. " agora esta na volta " .. tostring(racer.lap) .. "/" .. tostring(maxLaps) .. " completed=" .. tostring(completedLaps))
    self:UpdateRaceNow()
end

function DotaKartHUD:SetMaxLapsForRace(maxLaps)
    maxLaps = math.max(1, math.min(99, tonumber(maxLaps) or self.maxLaps or 3))
    self.maxLaps = maxLaps
    print("[DotaKartHUD] Voltas necessarias para vencer = " .. tostring(self.maxLaps))
    self:UpdateRaceNow()
end

function DotaKartHUD:RegisterDebugCommands()
    if self._debugCommandsRegistered == true then return end
    self._debugCommandsRegistered = true

    Convars:RegisterCommand("dk_set_lap", function(_, a, b)
        local pid = tonumber(a) or 0
        local lap = tonumber(b)
        if lap == nil then lap = tonumber(a) or 1; pid = 0 end
        lap = math.max(1, math.floor(lap or 1))
        self:SetPlayerCompletedLaps(pid, lap - 1)
    end, "DotA Kart: dk_set_lap [playerID] <lap_atual>", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_set_completed_laps", function(_, a, b)
        local pid = tonumber(a) or 0
        local completed = tonumber(b)
        if completed == nil then completed = tonumber(a) or 0; pid = 0 end
        self:SetPlayerCompletedLaps(pid, completed)
    end, "DotA Kart: dk_set_completed_laps [playerID] <voltas_completas>", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_finish_player", function(_, a)
        local pid = tonumber(a) or 0
        local racer = self.racers and self.racers[pid]
        if racer == nil then
            local hero = self:GetHeroForPlayer(pid)
            if DKValidUnit(hero) then racer = self:RegisterKart(pid, hero) end
        end
        if racer ~= nil then self:FinishRacer(racer, DKNow(), "console_finish") end
    end, "DotA Kart: dk_finish_player [playerID]", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_finish_me", function()
        local racer = self.racers and self.racers[0]
        if racer ~= nil then self:FinishRacer(racer, DKNow(), "console_finish_me") end
    end, "DotA Kart: termina a corrida para player 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_set_max_laps", function(_, a)
        self:SetMaxLapsForRace(tonumber(a) or self.maxLaps or 3)
    end, "DotA Kart: dk_set_max_laps <voltas>", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_laps_add", function(_, a)
        self:SetMaxLapsForRace((tonumber(self.maxLaps or 3) or 3) + (tonumber(a) or 1))
    end, "DotA Kart: aumenta voltas necessarias", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_laps_sub", function(_, a)
        self:SetMaxLapsForRace((tonumber(self.maxLaps or 3) or 3) - (tonumber(a) or 1))
    end, "DotA Kart: diminui voltas necessarias", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_finish_board", function()
        self.finishScreenVisible = true
        self:PublishFinishBoard(true)
    end, "DotA Kart: mostra placar final", FCVAR_CHEAT)

    -- FIX47: comandos de debug do sistema de volta/linha de chegada.
    Convars:RegisterCommand("dk_lap_debug", function(_, a)
        local pid = tonumber(a) or 0
        local racer = self.racers and self.racers[pid]
        if racer == nil then
            print("[DotaKartHUD] Sem racer para player " .. tostring(pid))
            return
        end
        print("[DotaKartHUD] LAP DEBUG p" .. tostring(pid) ..
            " lap=" .. tostring(racer.lap) ..
            " completed=" .. tostring(racer.completed_laps) ..
            " firstGate=" .. tostring(racer.first_finish_gate_passed) ..
            " gatePasses=" .. tostring(racer.finish_gate_passes) ..
            " cp=" .. tostring(racer.lap_checkpoint_count) .. "/" .. tostring(self.requiredLapCheckpoints) ..
            " maxDist=" .. tostring(math.floor(racer.max_distance_this_lap or 0)) ..
            " trackLen=" .. tostring(math.floor(self.trackLength or 0)))
    end, "DotA Kart: debug de volta dk_lap_debug [playerID]", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_finish_gate_scan", function()
        self:FindFinishLineGate()
    end, "DotA Kart: procura finish_line_gate novamente", FCVAR_CHEAT)

    -- FIX44: testes rápidos dos sons de volta/final/colocação.
    Convars:RegisterCommand("dk_test_lap_sound", function(_, a)
        self:PlaySoundForPlayer(tonumber(a) or 0, self.lapCompleteSound or "dotakart_lap_complete", { reason = "console_lap_sound" })
    end, "DotA Kart: testa som de volta normal [playerID]", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_test_final_lap_sound", function(_, a)
        self:PlaySoundForPlayer(tonumber(a) or 0, self.finalLapSound or "dotakart_final_lap", { reason = "console_final_lap_sound" })
    end, "DotA Kart: testa som de ultima volta [playerID]", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_test_place_sound", function(_, a, b)
        local place = tonumber(a) or 1
        local playerID = tonumber(b) or 0
        local soundName = self:GetFinishPlaceSound(place)
        if soundName ~= nil then
            self:PlaySoundForPlayer(playerID, soundName, { reason = "console_place_sound" })
        end
    end, "DotA Kart: dk_test_place_sound <place 1-8> [playerID]", FCVAR_CHEAT)
end

-- racers deve ser uma tabela por posição:
-- {
--   [1] = { player_id = 0, hero = "npc_dota_hero_pudge", place = 1 },
--   [2] = { player_id = 1, hero = "npc_dota_hero_axe", place = 2 },
-- }
function DotaKartHUD:SetRacers(racers)
    self:PublishRacers(racers or {})
end

-- Envio imediato por evento. Útil para teste, item novo, troca de volta etc.
function DotaKartHUD:SendInstantUpdate(playerID, data)
    local player = PlayerResource:GetPlayer(playerID)
    if player == nil then return end
    CustomGameEventManager:Send_ServerToPlayer(player, "dotakart_hud_update", data or {})
end

-- Exemplo de teste. Remova depois.
function DotaKartHUD:TestUpdate()
    -- Testa path sem depender do Hammer, só para provar que o minimap desenha linhas dinâmicas.
    self:SetTrackPathFromWorldPoints({
        Vector(-6000,  4400, 0),
        Vector( 3800,  4200, 0),
        Vector( 5400,  1200, 0),
        Vector( 1800,   200, 0),
        Vector( 2600, -3600, 0),
        Vector(-3600, -3000, 0),
        Vector(-4800,   800, 0),
        Vector(-1600,  1700, 0),
    }, true, 512)

    DotaKartHUD:SetRacers({
        [1] = { player_id = 0, hero = "npc_dota_hero_pudge", place = 1 },
        [2] = { player_id = 1, hero = "npc_dota_hero_axe", place = 2 },
        [3] = { player_id = 2, hero = "npc_dota_hero_earthshaker", place = 3 },
        [4] = { player_id = 3, hero = "npc_dota_hero_snapfire", place = 4 },
        [5] = { player_id = 4, hero = "npc_dota_hero_techies", place = 5 }
    })

    for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(playerID) then
            DotaKartHUD:SetPlayerState(playerID, {
                lap = 1,
                max_laps = 3,
                time_ms = 7746,
                place = playerID + 1,
                item = "item_phase_boots",
                world_pos = Vector(0, 0, 0),
                map_angle = 25
            })
        end
    end
end
