-- DotA Kart Auto Drive
-- Faz os heroes/karts andarem sozinhos pelos pontos dk_track para testar minimap, ranking e laps.
-- FIX30: speed maior e usa colisão física/terrain relax do kart_controller.

if DotaKartAutoDrive == nil then
    DotaKartAutoDrive = class({})
end

local function DKValidUnit(unit)
    return unit ~= nil and not unit:IsNull()
end

local function DKDistance2D(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function DKGround(pos)
    return Vector(pos.x, pos.y, GetGroundHeight(pos, nil))
end

function DotaKartAutoDrive:Init(hud)
    self.hud = hud or DotaKartHUD
    self.running = false
    self.drivers = {}
    self.points = {}
    self.tickRate = 0.05
    self.arriveDistance = 170
    self.orderInterval = 0.20
    self.moveSpeed = 820
    self.debug = false
    self._thinkStarted = false
    print("[DotaKartAutoDrive] Helper iniciado")
end

function DotaKartAutoDrive:LoadTrackPoints(options)
    options = options or {}
    local hud = self.hud or DotaKartHUD

    if hud == nil then
        print("[DotaKartAutoDrive] ERRO: DotaKartHUD nao existe.")
        return false
    end

    if hud.trackWorldPoints == nil or #hud.trackWorldPoints < 2 then
        hud:BuildTrackPathFromEntities(options.prefix or "dk_track_", options.max_points or 1024, true, options.padding or 512)
    end

    self.points = hud.trackWorldPoints or {}

    if #self.points < 2 then
        print("[DotaKartAutoDrive] ERRO: nao ha pontos dk_track suficientes para AutoDrive.")
        return false
    end

    print("[DotaKartAutoDrive] Pontos carregados: " .. tostring(#self.points))
    return true
end


function DotaKartAutoDrive:GetPlayerStartEntity(playerID)
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

function DotaKartAutoDrive:GetYawTowardFinishLineFrom(pos)
    if pos == nil then return nil end
    local gate = Entities:FindByName(nil, "finish_line_gate")
    if gate == nil then return nil end
    local gpos = gate:GetAbsOrigin()
    local dx = gpos.x - pos.x
    local dy = gpos.y - pos.y
    if (dx * dx + dy * dy) < 16 then return nil end
    if math.atan2 ~= nil then
        return math.deg(math.atan2(dy, dx))
    end
    return math.deg(math.atan(dy / math.max(0.001, dx)))
end

function DotaKartAutoDrive:SetUnitYaw(unit, yaw)
    if not DKValidUnit(unit) or yaw == nil then return end
    local rad = math.rad(yaw)
    local fwd = Vector(math.cos(rad), math.sin(rad), 0)
    if unit.SetForwardVector ~= nil then pcall(function() unit:SetForwardVector(fwd) end) end
    if unit.FaceTowards ~= nil then pcall(function() unit:FaceTowards(unit:GetAbsOrigin() + fwd * 256) end) end
end

function DotaKartAutoDrive:GetNearestPointIndex(pos)
    if pos == nil or self.points == nil or #self.points == 0 then return 1 end
    local bestIndex = 1
    local bestDistSq = nil
    for i, p in ipairs(self.points) do
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

function DotaKartAutoDrive:GetStartPositionForDriver(playerID)
    local ent, name = self:GetPlayerStartEntity(playerID)
    if ent ~= nil then
        return DKGround(ent:GetAbsOrigin()), name
    end

    if self.points ~= nil and #self.points >= 1 then
        local startPos = DKGround(self.points[1])
        local offset = (playerID or 0) * 96
        return Vector(startPos.x + offset, startPos.y, startPos.z), "dk_track_001_fallback"
    end

    return Vector(0, 0, 0), "world_origin_fallback"
end

function DotaKartAutoDrive:AddDriver(playerID, unit, options)
    options = options or {}
    if not DKValidUnit(unit) then return false end
    if self.points == nil or #self.points < 2 then return false end

    if options.move_speed ~= nil then
        unit:SetBaseMoveSpeed(options.move_speed)
    end

    if options.no_attack == true then
        pcall(function() unit:SetIdleAcquire(false) end)
        pcall(function() unit:SetAcquisitionRange(0) end)
        if DOTA_UNIT_CAP_NO_ATTACK ~= nil then
            pcall(function() unit:SetAttackCapability(DOTA_UNIT_CAP_NO_ATTACK) end)
        end
    end

    local nextIndex = 2

    -- FIX47: AutoBot/AutoDrive usa player1_start_position...player8_start_position.
    if options.teleport_to_start then
        local startPos, sourceName = self:GetStartPositionForDriver(playerID)
        FindClearSpaceForUnit(unit, startPos, true)
        unit:Stop()
        self:SetUnitYaw(unit, self:GetYawTowardFinishLineFrom(startPos))

        local nearest = self:GetNearestPointIndex(startPos)
        nextIndex = nearest + 1
        if nextIndex > #self.points then nextIndex = 1 end

        if self.debug then
            print("[DotaKartAutoDrive] Driver " .. tostring(playerID) .. " largada=" .. tostring(sourceName) .. " next_index=" .. tostring(nextIndex))
        end
    end

    self.drivers[playerID] = {
        player_id = playerID,
        unit = unit,
        next_index = nextIndex,
        last_order_time = -9999,
        direct_drive = options.direct_drive == true or options.direct == true,
        no_attack = options.no_attack == true,
        move_speed = options.move_speed or self.moveSpeed or 820
    }

    print("[DotaKartAutoDrive] Driver registrado: player " .. tostring(playerID) .. " = " .. tostring(unit:GetUnitName()))
    self:IssueMoveOrder(self.drivers[playerID], true)
    return true
end

function DotaKartAutoDrive:RegisterAllHeroes(options)
    options = options or {}
    local count = 0

    if self.hud ~= nil and self.hud.AutoRegisterHeroKarts ~= nil then
        self.hud:AutoRegisterHeroKarts()
    end

    for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(playerID) then
            local hero = PlayerResource:GetSelectedHeroEntity(playerID)
            if DKValidUnit(hero) and hero:IsRealHero() then
                if self:AddDriver(playerID, hero, options) then
                    count = count + 1
                end
            end
        end
    end

    print("[DotaKartAutoDrive] Total de drivers: " .. tostring(count))
    return count
end

function DotaKartAutoDrive:Start(options)
    options = options or {}

    self.arriveDistance = options.arrive_distance or options.arriveDistance or self.arriveDistance or 170
    self.orderInterval = options.order_interval or options.orderInterval or self.orderInterval or 0.20
    self.tickRate = options.tick_rate or options.tickRate or self.tickRate or 0.05
    self.moveSpeed = options.move_speed or options.moveSpeed or self.moveSpeed or 820
    self.debug = options.debug == true
    self.drivers = {}

    if not self:LoadTrackPoints(options) then
        return false
    end

    local count = self:RegisterAllHeroes({
        teleport_to_start = options.teleport_to_start ~= false,
        move_speed = self.moveSpeed
    })

    if count <= 0 then
        print("[DotaKartAutoDrive] AVISO: nenhum heroi para dirigir ainda. Tente dk_autodrive_start depois do spawn.")
        return false
    end

    self.running = true
    self:StartThink()

    print("[DotaKartAutoDrive] AutoDrive iniciado.")
    return true
end

function DotaKartAutoDrive:Stop()
    self.running = false
    for _, driver in pairs(self.drivers or {}) do
        if DKValidUnit(driver.unit) then
            driver.unit:Stop()
        end
    end
    print("[DotaKartAutoDrive] AutoDrive parado.")
end

function DotaKartAutoDrive:StartThink()
    if self._thinkStarted then return end
    self._thinkStarted = true

    GameRules:GetGameModeEntity():SetContextThink("DotaKartAutoDriveThink", function()
        if self.running then
            self:Think()
        end
        return self.tickRate or 0.05
    end, self.tickRate or 0.05)
end

function DotaKartAutoDrive:GetTargetPoint(index)
    if self.points == nil or #self.points == 0 then return nil end
    if index > #self.points then index = 1 end
    if index < 1 then index = 1 end
    return DKGround(self.points[index])
end

function DotaKartAutoDrive:AdvanceTarget(driver)
    driver.next_index = (driver.next_index or 1) + 1
    if driver.next_index > #self.points then
        driver.next_index = 1
    end
end

function DotaKartAutoDrive:IssueMoveOrder(driver, force)
    if driver == nil or not DKValidUnit(driver.unit) then return end
    if driver.direct_drive == true then return end

    local now = GameRules:GetGameTime()
    if not force and (now - (driver.last_order_time or 0)) < (self.orderInterval or 0.20) then
        return
    end

    local target = self:GetTargetPoint(driver.next_index or 1)
    if target == nil then return end

    driver.last_order_time = now

    -- Reemite ordem constantemente para o jogador nao cancelar o teste sem querer.
    ExecuteOrderFromTable({
        UnitIndex = driver.unit:entindex(),
        OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
        Position = target,
        Queue = false
    })
end

function DotaKartAutoDrive:DirectDriveDriver(driver)
    if driver == nil then return end
    local unit = driver.unit
    if not DKValidUnit(unit) then return end

    local controller = GameRules and GameRules.DotaKartController or nil
    if controller ~= nil and driver.player_id ~= nil then
        if (controller.IsKartStunned ~= nil and controller:IsKartStunned(driver.player_id, GameRules:GetGameTime())) or
           (controller.IsKartLocked ~= nil and controller:IsKartLocked(driver.player_id, GameRules:GetGameTime())) then
            -- Não mover o bot durante stun/lock. O controller faz a desaceleração/spin.
            return
        end
    end

    if driver.no_attack == true then
        pcall(function() unit:SetIdleAcquire(false) end)
        pcall(function() unit:SetAcquisitionRange(0) end)
        if DOTA_UNIT_CAP_NO_ATTACK ~= nil then
            pcall(function() unit:SetAttackCapability(DOTA_UNIT_CAP_NO_ATTACK) end)
        end
    end

    local target = self:GetTargetPoint(driver.next_index or 1)
    if target == nil then return end

    local pos = unit:GetAbsOrigin()
    local dx = target.x - pos.x
    local dy = target.y - pos.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist <= (self.arriveDistance or 170) then
        if self.debug then
            print("[DotaKartAutoDrive] Player " .. tostring(driver.player_id) .. " chegou no ponto " .. tostring(driver.next_index))
        end
        self:AdvanceTarget(driver)
        target = self:GetTargetPoint(driver.next_index or 1)
        if target == nil then return end
        dx = target.x - pos.x
        dy = target.y - pos.y
        dist = math.sqrt(dx * dx + dy * dy)
    end

    if dist <= 1 then return end

    local speed = driver.move_speed or self.moveSpeed or 820
    if controller ~= nil and controller.GetKartSlowPct ~= nil and driver.player_id ~= nil then
        local slowPct = controller:GetKartSlowPct(driver.player_id, GameRules:GetGameTime()) or 0
        if slowPct > 0 then speed = math.max(120, speed * (1.0 - slowPct)) end
    end
    local dt = self.tickRate or 0.05
    local step = math.min(dist, speed * dt)
    local nx = dx / dist
    local ny = dy / dist
    local newPos = Vector(pos.x + nx * step, pos.y + ny * step, pos.z)
    newPos = DKGround(newPos)

    -- Movimento direto evita que o bot cancele a rota para atacar o jogador.
    -- FIX28: passa pelo mesmo sistema de colisão dos players.
    if controller ~= nil and controller.MoveUnitWithKartPhysics ~= nil then
        newPos = controller:MoveUnitWithKartPhysics(driver.player_id, unit, newPos, Vector(nx, ny, 0), speed, dt)
    else
        unit:SetAbsOrigin(newPos)
    end
    unit:SetForwardVector(Vector(nx, ny, 0))
    pcall(function() unit:FaceTowards(target) end)
    pcall(function() ResolveNPCPositions(newPos, 96) end)
end

function DotaKartAutoDrive:ThinkDriver(driver)
    if driver == nil then return end
    local unit = driver.unit
    if not DKValidUnit(unit) then return end

    -- FIX42: AutoBot que terminou a corrida para de pilotar.
    if GameRules ~= nil and GameRules.DotaKartHUD ~= nil and GameRules.DotaKartHUD.IsPlayerFinished ~= nil and driver.player_id ~= nil then
        if GameRules.DotaKartHUD:IsPlayerFinished(driver.player_id) then
            return
        end
    end

    local controller = GameRules and GameRules.DotaKartController or nil
    if controller ~= nil and driver.player_id ~= nil then
        if (controller.IsKartStunned ~= nil and controller:IsKartStunned(driver.player_id, GameRules:GetGameTime())) or
           (controller.IsKartLocked ~= nil and controller:IsKartLocked(driver.player_id, GameRules:GetGameTime())) then
            return
        end
    end

    if driver.direct_drive == true then
        self:DirectDriveDriver(driver)
        return
    end

    local target = self:GetTargetPoint(driver.next_index or 1)
    if target == nil then return end

    local pos = unit:GetAbsOrigin()
    local dist = DKDistance2D(pos, target)

    if dist <= (self.arriveDistance or 170) then
        if self.debug then
            print("[DotaKartAutoDrive] Player " .. tostring(driver.player_id) .. " chegou no ponto " .. tostring(driver.next_index))
        end
        self:AdvanceTarget(driver)
        self:IssueMoveOrder(driver, true)
        return
    end

    self:IssueMoveOrder(driver, false)
end

function DotaKartAutoDrive:Think()
    for _, driver in pairs(self.drivers or {}) do
        self:ThinkDriver(driver)
    end
end
