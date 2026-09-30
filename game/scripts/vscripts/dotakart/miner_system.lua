-- DotA Kart - mines map worker/miner NPC system.
-- FIX115: Hammer NPCs named "miner" seek nearby high ground, loop Meepo attack
-- animations with the Pitmouse Fraternity Axe, can be run over by karts, and respawn.

LinkLuaModifier("modifier_dotakart_miner_npc", "dotakart/miner_system.lua", LUA_MODIFIER_MOTION_NONE)

if DotaKartMinerSystem == nil then
    DotaKartMinerSystem = class({})
end

modifier_dotakart_miner_npc = class({})

function modifier_dotakart_miner_npc:IsHidden() return true end
function modifier_dotakart_miner_npc:IsPurgable() return false end
function modifier_dotakart_miner_npc:RemoveOnDeath() return false end
function modifier_dotakart_miner_npc:CheckState()
    return {
        [MODIFIER_STATE_NO_HEALTH_BAR] = true,
        [MODIFIER_STATE_DISARMED] = true,
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true,
    }
end

local MINER_WEAPON_MODEL = "models/items/meepo/ti8_meepo_pitmouse_fraternity_weapon/ti8_meepo_pitmouse_fraternity_weapon.vmdl"

local function DKMinerValid(unit)
    return unit ~= nil and not unit:IsNull()
end

local function DKMinerNow()
    if GameRules ~= nil and GameRules.GetGameTime ~= nil then
        return GameRules:GetGameTime()
    end
    return 0
end

local function DKMinerDistance2D(a, b)
    if a == nil or b == nil then return 999999 end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

local function DKMinerNormalize2D(v)
    if v == nil then return Vector(1, 0, 0) end
    local len = math.sqrt((v.x or 0) * (v.x or 0) + (v.y or 0) * (v.y or 0))
    if len < 0.001 then return Vector(1, 0, 0) end
    return Vector((v.x or 0) / len, (v.y or 0) / len, 0)
end

function DotaKartMinerSystem:Init(controller)
    self.controller = controller
    self.miners = self.miners or {}
    self.started = false
    self.config = {
        scan_interval = 0.75,
        think_interval = 0.05,
        work_arrive_distance = 105,
        move_retry_seconds = 1.00,
        move_timeout_seconds = 8.0,
        attack_anim_interval = 1.10,
        attack_anim_rate = 0.78,
        highground_min_delta = 56,
        highground_max_radius = 1050,
        highground_ring_step = 96,
        highground_angle_samples = 24,
        kart_hit_radius = 155,
        kart_min_hit_speed = 100,
        respawn_seconds = 5.0,
        crash_duration = 2.25,
        crash_slow_pct = 0.70,
        crash_instability_yaw = 185,
        crash_lateral = 155,
    }
end

function DotaKartMinerSystem:IsMinesMap()
    local mapName = ""
    if GetMapName ~= nil then
        pcall(function() mapName = string.lower(tostring(GetMapName() or "")) end)
    end
    if mapName == "mines" or string.match(mapName, "mines$") ~= nil then
        return true
    end

    -- Defensive Workshop Tools fallback: if Hammer already spawned an entity named
    -- "miner", enable the system even if GetMapName() returned an addon-prefixed name.
    if Entities ~= nil and Entities.FindByName ~= nil then
        local found = nil
        pcall(function() found = Entities:FindByName(nil, "miner") end)
        if found ~= nil then return true end
    end
    return false
end

function DotaKartMinerSystem:Start()
    if self.started then return end
    if not self:IsMinesMap() then
        print("[DotaKartMiner] mapa atual não usa miners; sistema inativo.")
        return
    end

    self.started = true
    self.nextScan = 0
    print("[DotaKartMiner] FIX115 iniciado no mapa mines.")

    local mode = GameRules ~= nil and GameRules:GetGameModeEntity() or nil
    if mode ~= nil then
        mode:SetContextThink("DotaKartMinerSystemThink", function()
            return self:OnThink()
        end, 0.05)
    end
end

function DotaKartMinerSystem:IsMinerUnit(unit)
    if not DKMinerValid(unit) then return false end
    if unit.GetUnitName == nil or unit.IsAlive == nil or unit.AddNewModifier == nil then return false end
    local name = ""
    local unitName = ""
    pcall(function() name = string.lower(tostring(unit:GetName() or "")) end)
    pcall(function() unitName = string.lower(tostring(unit:GetUnitName() or "")) end)
    local function matchesMiner(value)
        return value == "miner" or string.match(value, "^miner[_%-]%d+$") ~= nil
    end
    return matchesMiner(name) or matchesMiner(unitName)
end

function DotaKartMinerSystem:ScanHammerMiners()
    if Entities == nil then return end

    -- One full map scan catches Hammer targetnames such as miner_01 even if those NPCs
    -- spawned before npc_spawned was registered. This is done only once.
    if self.fullMapScanDone ~= true and Entities.First ~= nil and Entities.Next ~= nil then
        self.fullMapScanDone = true
        local ent = nil
        pcall(function() ent = Entities:First() end)
        local guard = 0
        while ent ~= nil and guard < 8192 do
            guard = guard + 1
            if self:IsMinerUnit(ent) then self:RegisterMiner(ent) end
            local nextEnt = nil
            pcall(function() nextEnt = Entities:Next(ent) end)
            ent = nextEnt
        end
    end

    if Entities.FindByName == nil then return end
    -- Cheap recurring scan for the common case where all Hammer workers share "miner".
    local cursor = nil
    local guard = 0
    while guard < 128 do
        guard = guard + 1
        local nextEnt = nil
        local ok = pcall(function() nextEnt = Entities:FindByName(cursor, "miner") end)
        if not ok or nextEnt == nil then break end
        self:RegisterMiner(nextEnt)
        cursor = nextEnt
    end
end

function DotaKartMinerSystem:OnNPCSpawned(unit)
    if not self.started then return end
    if self:IsMinerUnit(unit) then
        self:RegisterMiner(unit)
    end
end

function DotaKartMinerSystem:HideDefaultMeepoWeapon(unit)
    if not DKMinerValid(unit) then return end
    local child = nil
    pcall(function() child = unit:FirstMoveChild() end)
    local guard = 0
    while child ~= nil and guard < 64 do
        guard = guard + 1
        local nextChild = nil
        pcall(function() nextChild = child:NextMovePeer() end)
        local cls = ""
        local model = ""
        pcall(function() cls = string.lower(tostring(child:GetClassname() or "")) end)
        pcall(function() model = string.lower(tostring(child:GetModelName() or "")) end)
        if cls == "dota_item_wearable" and string.find(model, "weapon", 1, true) ~= nil then
            pcall(function() child:AddNoDraw() end)
        end
        child = nextChild
    end
end

function DotaKartMinerSystem:EquipPitmouseAxe(entry)
    if entry == nil or not DKMinerValid(entry.unit) then return end
    if DKMinerValid(entry.weapon) then return end

    self:HideDefaultMeepoWeapon(entry.unit)

    local weapon = nil
    if SpawnEntityFromTableSynchronous ~= nil then
        pcall(function()
            weapon = SpawnEntityFromTableSynchronous("prop_dynamic", {
                model = MINER_WEAPON_MODEL,
                DefaultAnim = "",
                solid = 0,
            })
        end)
    end
    if not DKMinerValid(weapon) then
        print("[DotaKartMiner] AVISO: não foi possível criar Pitmouse Fraternity Axe.")
        return
    end

    local merged = false
    if weapon.FollowEntity ~= nil then
        local ok = pcall(function() weapon:FollowEntity(entry.unit, true) end)
        merged = ok == true
    end
    if not merged and weapon.SetParent ~= nil then
        pcall(function() weapon:SetParent(entry.unit, "attach_attack1") end)
        pcall(function() weapon:SetLocalOrigin(Vector(0, 0, 0)) end)
        pcall(function() weapon:SetLocalAngles(0, 0, 0) end)
    end

    entry.weapon = weapon
end

function DotaKartMinerSystem:RemoveMinerWeapon(entry)
    if entry == nil or not DKMinerValid(entry.weapon) then
        if entry ~= nil then entry.weapon = nil end
        return
    end
    pcall(function() UTIL_Remove(entry.weapon) end)
    entry.weapon = nil
end

function DotaKartMinerSystem:ConfigureMiner(entry)
    if entry == nil or not DKMinerValid(entry.unit) then return end
    local unit = entry.unit

    pcall(function() unit:SetIdleAcquire(false) end)
    pcall(function() unit:SetAcquisitionRange(0) end)
    pcall(function() unit:SetForceAttackTarget(nil) end)
    pcall(function() unit:SetAggroTarget(nil) end)
    if DOTA_UNIT_CAP_NO_ATTACK ~= nil then
        pcall(function() unit:SetAttackCapability(DOTA_UNIT_CAP_NO_ATTACK) end)
    end
    if not unit:HasModifier("modifier_dotakart_miner_npc") then
        pcall(function() unit:AddNewModifier(unit, nil, "modifier_dotakart_miner_npc", {}) end)
    end
    -- Extra fallback for models/builds that ignore MODIFIER_STATE_NO_HEALTH_BAR.
    if unit.SetHealthBarOffsetOverride ~= nil then
        pcall(function() unit:SetHealthBarOffsetOverride(-10000) end)
    end

    self:EquipPitmouseAxe(entry)
end

function DotaKartMinerSystem:IsUsableHighgroundPoint(point, unit)
    if point == nil then return false end
    if GridNav ~= nil then
        if GridNav.IsTraversable ~= nil then
            local traversable = true
            local ok = pcall(function() traversable = GridNav:IsTraversable(point) == true end)
            if ok and not traversable then return false end
        end
        if GridNav.IsBlocked ~= nil then
            local blocked = false
            local ok = pcall(function() blocked = GridNav:IsBlocked(point) == true end)
            if ok and blocked then return false end
        end
        if GridNav.IsNearbyTree ~= nil then
            local nearTree = false
            pcall(function() nearTree = GridNav:IsNearbyTree(point, 72, true) == true end)
            if nearTree then return false end
        end
    end
    return true
end

function DotaKartMinerSystem:FindNearestHighground(origin, unit)
    if origin == nil then return nil end
    local baseZ = GetGroundHeight(origin, unit)
    local best = nil
    local bestDist = 999999
    local cfg = self.config
    local step = math.max(64, tonumber(cfg.highground_ring_step) or 96)
    local maxRadius = math.max(step, tonumber(cfg.highground_max_radius) or 1050)
    local samples = math.max(8, tonumber(cfg.highground_angle_samples) or 24)
    local minDelta = tonumber(cfg.highground_min_delta) or 56

    local radius = step
    while radius <= maxRadius do
        for i = 0, samples - 1 do
            local ang = (math.pi * 2.0) * (i / samples)
            local sample = Vector(origin.x + math.cos(ang) * radius, origin.y + math.sin(ang) * radius, origin.z)
            local groundZ = GetGroundHeight(sample, unit)
            sample.z = groundZ
            if groundZ >= baseZ + minDelta and self:IsUsableHighgroundPoint(sample, unit) then
                local pathOK = true
                if GridNav ~= nil and GridNav.FindPathLength ~= nil then
                    local pathLen = -1
                    local ok = pcall(function() pathLen = GridNav:FindPathLength(origin, sample) end)
                    if ok and tonumber(pathLen) ~= nil and tonumber(pathLen) < 0 then
                        pathOK = false
                    end
                end
                if pathOK then
                    local dist = DKMinerDistance2D(origin, sample)
                    if dist < bestDist then
                        best = Vector(sample.x, sample.y, sample.z)
                        bestDist = dist
                    end
                end
            end
        end
        -- The first ring containing a reachable elevated point is necessarily the
        -- nearest ring; no reason to search farther once we found a candidate.
        if best ~= nil then break end
        radius = radius + step
    end
    return best
end

function DotaKartMinerSystem:IssueMoveToWork(entry, now)
    if entry == nil or not DKMinerValid(entry.unit) or entry.work_target == nil then return end
    now = now or DKMinerNow()
    entry.last_move_order = now
    entry.move_started_at = entry.move_started_at or now

    local order = {
        UnitIndex = entry.unit:entindex(),
        OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
        Position = entry.work_target,
        Queue = false,
    }
    local issued = false
    if ExecuteOrderFromTable ~= nil then
        issued = pcall(function() ExecuteOrderFromTable(order) end)
    end
    if not issued and entry.unit.MoveToPosition ~= nil then
        pcall(function() entry.unit:MoveToPosition(entry.work_target) end)
    end
end

function DotaKartMinerSystem:BeginWorking(entry, atPosition)
    if entry == nil or not DKMinerValid(entry.unit) then return end
    entry.working = true
    entry.next_attack_anim = 0
    entry.move_started_at = nil

    local pos = atPosition or entry.unit:GetAbsOrigin()
    local face = entry.work_forward
    if face == nil and entry.work_target ~= nil then
        face = DKMinerNormalize2D(entry.work_target - entry.spawn_pos)
    end
    if face == nil then face = entry.spawn_forward or Vector(1, 0, 0) end
    entry.work_forward = DKMinerNormalize2D(face)
    pcall(function() entry.unit:SetForwardVector(entry.work_forward) end)
end

function DotaKartMinerSystem:PlayMiningAttack(entry, now)
    if entry == nil or not DKMinerValid(entry.unit) then return end
    now = now or DKMinerNow()
    if now < (entry.next_attack_anim or 0) then return end

    local unit = entry.unit
    local rate = tonumber(self.config.attack_anim_rate) or 0.78
    pcall(function() unit:SetForwardVector(entry.work_forward or entry.spawn_forward or Vector(1, 0, 0)) end)
    if ACT_DOTA_ATTACK ~= nil then
        pcall(function() unit:RemoveGesture(ACT_DOTA_ATTACK) end)
        local ok = false
        if unit.StartGestureWithPlaybackRate ~= nil then
            ok = pcall(function() unit:StartGestureWithPlaybackRate(ACT_DOTA_ATTACK, rate) end)
        end
        if not ok and unit.StartGesture ~= nil then
            ok = pcall(function() unit:StartGesture(ACT_DOTA_ATTACK) end)
        end
        if not ok and unit.ForcePlayActivityOnce ~= nil then
            pcall(function() unit:ForcePlayActivityOnce(ACT_DOTA_ATTACK) end)
        end
    end
    entry.next_attack_anim = now + (tonumber(self.config.attack_anim_interval) or 1.10)
end

function DotaKartMinerSystem:RegisterMiner(unit)
    if not DKMinerValid(unit) or not self:IsMinerUnit(unit) then return nil end
    local ent = -1
    pcall(function() ent = unit:entindex() end)
    if ent == nil or ent < 0 then return nil end
    if self.miners[ent] ~= nil then return self.miners[ent] end

    local pos = unit:GetAbsOrigin()
    local forward = Vector(1, 0, 0)
    pcall(function() forward = unit:GetForwardVector() end)
    local unitName = ""
    local team = DOTA_TEAM_NEUTRALS or 4
    pcall(function() unitName = tostring(unit:GetUnitName() or "") end)
    pcall(function() team = unit:GetTeamNumber() end)

    local entry = {
        unit = unit,
        entindex = ent,
        unit_name = unitName,
        team = team,
        spawn_pos = Vector(pos.x, pos.y, pos.z),
        spawn_forward = DKMinerNormalize2D(forward),
        work_target = nil,
        work_forward = nil,
        working = false,
        next_attack_anim = 0,
        last_move_order = 0,
        move_started_at = nil,
        respawn_at = nil,
        hit_processed = false,
        external_control_until = 0,
        weapon = nil,
    }
    self.miners[ent] = entry

    self:ConfigureMiner(entry)
    entry.work_target = self:FindNearestHighground(entry.spawn_pos, unit)
    if entry.work_target ~= nil then
        entry.work_forward = DKMinerNormalize2D(entry.work_target - entry.spawn_pos)
        self:IssueMoveToWork(entry, DKMinerNow())
        print("[DotaKartMiner] miner " .. tostring(ent) .. " procurando highground próximo.")
    else
        entry.work_target = Vector(entry.spawn_pos.x, entry.spawn_pos.y, entry.spawn_pos.z)
        self:BeginWorking(entry, entry.spawn_pos)
        print("[DotaKartMiner] AVISO: miner " .. tostring(ent) .. " sem highground acessível; trabalhando no spawn.")
    end

    return entry
end

-- FIX116: API pequena para itens que interagem com miners. Power Cogs não chama
-- esta API e continua ignorando os workers completamente.
function DotaKartMinerSystem:FindMinerAtPosition(pos, radius)
    if pos == nil then return nil end
    radius = tonumber(radius) or 150
    for _, entry in pairs(self.miners or {}) do
        if entry ~= nil and DKMinerValid(entry.unit) and entry.unit:IsAlive() and entry.hit_processed ~= true then
            if DKMinerDistance2D(entry.unit:GetAbsOrigin(), pos) <= radius then
                return entry
            end
        end
    end
    return nil
end

function DotaKartMinerSystem:BeginExternalPull(entry, duration)
    if entry == nil or not DKMinerValid(entry.unit) or not entry.unit:IsAlive() then return false end
    local now = DKMinerNow()
    entry.external_control_until = math.max(tonumber(entry.external_control_until) or 0, now + (tonumber(duration) or 3.0))
    entry.working = false
    entry.move_started_at = nil
    entry.last_move_order = now
    if ACT_DOTA_ATTACK ~= nil then pcall(function() entry.unit:RemoveGesture(ACT_DOTA_ATTACK) end) end
    pcall(function() entry.unit:Stop() end)
    return true
end

function DotaKartMinerSystem:EndExternalPull(entry)
    if entry == nil or not DKMinerValid(entry.unit) then return end
    entry.external_control_until = 0
    entry.working = false
    entry.move_started_at = nil
    entry.last_move_order = 0
end

function DotaKartMinerSystem:ApplyKartCrash(kartPlayerID)
    if self.controller == nil or self.controller.ApplyMinerCrash == nil then return end
    self.controller:ApplyMinerCrash(
        kartPlayerID,
        self.config.crash_duration,
        self.config.crash_slow_pct,
        self.config.crash_instability_yaw,
        self.config.crash_lateral
    )
end

function DotaKartMinerSystem:KillMinerByKart(entry, kartPlayerID, kartHero, now)
    if entry == nil or not DKMinerValid(entry.unit) or entry.hit_processed then return end
    if not entry.unit:IsAlive() then return end

    entry.hit_processed = true
    entry.working = false
    entry.respawn_at = (now or DKMinerNow()) + (tonumber(self.config.respawn_seconds) or 5.0)
    self:ApplyKartCrash(kartPlayerID)
    self:RemoveMinerWeapon(entry)

    if ACT_DOTA_ATTACK ~= nil then
        pcall(function() entry.unit:RemoveGesture(ACT_DOTA_ATTACK) end)
    end

    local killed = false
    if entry.unit.Kill ~= nil then
        killed = pcall(function() entry.unit:Kill(nil, kartHero) end)
    end
    if not killed or entry.unit:IsAlive() then
        pcall(function() entry.unit:ForceKill(false) end)
    end

    print("[DotaKartMiner] miner atropelado pelo kart p" .. tostring(kartPlayerID) .. "; respawn em " .. tostring(self.config.respawn_seconds) .. "s.")
end

function DotaKartMinerSystem:RespawnMiner(entry, now)
    if entry == nil or not DKMinerValid(entry.unit) then return false end
    local unit = entry.unit

    if unit:IsAlive() then
        -- Some hero-based Hammer NPCs may respawn automatically. Still force the
        -- original Hammer transform and reconfigure them.
    else
        local ok = false
        if unit.RespawnUnit ~= nil then
            ok = pcall(function() unit:RespawnUnit() end)
        end
        if (not ok or not unit:IsAlive()) and unit.RespawnHero ~= nil then
            pcall(function() unit:RespawnHero(false, false) end)
        end
    end

    if not unit:IsAlive() then return false end

    pcall(function() unit:SetAbsOrigin(entry.spawn_pos) end)
    if FindClearSpaceForUnit ~= nil then
        pcall(function() FindClearSpaceForUnit(unit, entry.spawn_pos, true) end)
    end
    pcall(function() unit:SetForwardVector(entry.spawn_forward or Vector(1, 0, 0)) end)
    pcall(function() unit:SetHealth(unit:GetMaxHealth()) end)

    entry.hit_processed = false
    entry.respawn_at = nil
    entry.external_control_until = 0
    entry.working = false
    entry.next_attack_anim = 0
    entry.last_move_order = 0
    entry.move_started_at = nil
    self:ConfigureMiner(entry)

    entry.work_target = self:FindNearestHighground(entry.spawn_pos, unit)
    if entry.work_target ~= nil then
        entry.work_forward = DKMinerNormalize2D(entry.work_target - entry.spawn_pos)
        self:IssueMoveToWork(entry, now)
    else
        entry.work_target = Vector(entry.spawn_pos.x, entry.spawn_pos.y, entry.spawn_pos.z)
        self:BeginWorking(entry, entry.spawn_pos)
    end

    print("[DotaKartMiner] miner " .. tostring(entry.entindex) .. " respawnado na posição original do Hammer.")
    return true
end

function DotaKartMinerSystem:CheckKartCollisions(entry, now)
    if entry == nil or not DKMinerValid(entry.unit) or not entry.unit:IsAlive() then return end
    if self.controller == nil or self.controller.GetRegisteredKartHeroes == nil then return end

    local minerPos = entry.unit:GetAbsOrigin()
    local hitRadius = tonumber(self.config.kart_hit_radius) or 155
    local minSpeed = tonumber(self.config.kart_min_hit_speed) or 100
    for playerID, kart in pairs(self.controller:GetRegisteredKartHeroes()) do
        if DKMinerValid(kart) then
            local st = self.controller.GetState ~= nil and self.controller:GetState(playerID) or nil
            local speed = st ~= nil and math.abs(tonumber(st.speed) or 0) or 0
            if speed >= minSpeed and DKMinerDistance2D(kart:GetAbsOrigin(), minerPos) <= hitRadius then
                self:KillMinerByKart(entry, playerID, kart, now)
                return
            end
        end
    end
end

function DotaKartMinerSystem:UpdateMiner(entry, now)
    if entry == nil or not DKMinerValid(entry.unit) then return end
    local unit = entry.unit

    if not unit:IsAlive() then
        if entry.respawn_at == nil then
            entry.respawn_at = now + (tonumber(self.config.respawn_seconds) or 5.0)
            self:RemoveMinerWeapon(entry)
        end
        if now >= entry.respawn_at then
            self:RespawnMiner(entry, now)
        end
        return
    end

    -- If Dota auto-respawned a hero-based miner before our timer, keep it hidden from
    -- play until the requested DotA Kart respawn time, then restore the Hammer spawn.
    if entry.hit_processed and entry.respawn_at ~= nil and now < entry.respawn_at then
        pcall(function() unit:AddNoDraw() end)
        pcall(function() unit:SetAbsOrigin(entry.spawn_pos) end)
        return
    elseif entry.hit_processed and entry.respawn_at ~= nil and now >= entry.respawn_at then
        pcall(function() unit:RemoveNoDraw() end)
        self:RespawnMiner(entry, now)
        return
    end

    self:ConfigureMiner(entry)
    self:CheckKartCollisions(entry, now)
    if entry.hit_processed or not unit:IsAlive() then return end

    if (tonumber(entry.external_control_until) or 0) > now then
        return
    elseif (tonumber(entry.external_control_until) or 0) > 0 then
        self:EndExternalPull(entry)
    end

    if not entry.working then
        local dist = DKMinerDistance2D(unit:GetAbsOrigin(), entry.work_target)
        if dist <= (tonumber(self.config.work_arrive_distance) or 105) then
            self:BeginWorking(entry, unit:GetAbsOrigin())
        else
            if entry.move_started_at ~= nil and now - entry.move_started_at >= (tonumber(self.config.move_timeout_seconds) or 8.0) then
                -- Do not leave the worker stuck forever if a sampled highground point became
                -- unreachable because of dynamic path blockers. Work at the closest reached spot.
                self:BeginWorking(entry, unit:GetAbsOrigin())
            elseif now - (entry.last_move_order or 0) >= (tonumber(self.config.move_retry_seconds) or 1.0) then
                self:IssueMoveToWork(entry, now)
            end
        end
    end

    if entry.working then
        self:PlayMiningAttack(entry, now)
    end
end

function DotaKartMinerSystem:OnThink()
    if not self.started then return nil end
    local now = DKMinerNow()
    if now >= (self.nextScan or 0) then
        self:ScanHammerMiners()
        self.nextScan = now + (tonumber(self.config.scan_interval) or 0.75)
    end

    for ent, entry in pairs(self.miners or {}) do
        if entry == nil or not DKMinerValid(entry.unit) then
            self.miners[ent] = nil
        else
            self:UpdateMiner(entry, now)
        end
    end

    return tonumber(self.config.think_interval) or 0.05
end

return DotaKartMinerSystem
