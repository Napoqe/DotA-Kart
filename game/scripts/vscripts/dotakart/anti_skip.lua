-- DotA Kart - anti_skip.lua
-- FIX121: detects large illegal forward teleports across dk_track_* and returns the racer
-- with a Glimpse-style travel. Official dk_track_skip areas grant a temporary exemption.

if DotaKartAntiSkip == nil then
    DotaKartAntiSkip = class({})
end

local function DKASNow()
    if GameRules ~= nil and GameRules.GetGameTime ~= nil then
        return GameRules:GetGameTime()
    end
    return 0
end

local function DKASValidUnit(unit)
    return unit ~= nil and (unit.IsNull == nil or not unit:IsNull())
end

local function DKASLength2D(a, b)
    if a == nil or b == nil then return 0 end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

local function DKASCopyVector(v)
    if v == nil then return nil end
    return Vector(v.x or 0, v.y or 0, v.z or 0)
end

function DotaKartAntiSkip:Init(hud, controller)
    if self.initialized then
        self.hud = hud or self.hud
        self.controller = controller or self.controller
        return
    end
    self.initialized = true
    self.hud = hud or GameRules.DotaKartHUD
    self.controller = controller or GameRules.DotaKartController
    self.states = {}
    self.serial = 0
    self.config = {
        max_forward_segment_jump = 6,
        -- FIX122: also compare course progress against real world travel over a short window.
        -- This catches Leap cutting across a hairpin even when it moves in small steps.
        shortcut_window = 1.10,
        shortcut_min_segment_gain = 7,
        shortcut_min_path_gain = 900,
        shortcut_path_ratio = 1.55,
        shortcut_path_margin = 260,
        suspicious_confirm_window = 0.40,
        skip_grace = 4.0,
        teleport_grace = 1.25,
        glimpse_speed = 1000,
        glimpse_max_time = 1.8,
        glimpse_min_time = 0.12,
        think_interval = 0.03,
        sound_begin = "dotakart_glimpse_begin",
        sound_end = "dotakart_glimpse_end",
        target_particles = {
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_anticipate_position.vpcf",
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_anticipate_position_trail.vpcf",
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_anticipate_position_warp.vpcf",
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_start_position_circle.vpcf"
        },
        start_particles = {
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_start_flare.vpcf",
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_start_flare_glows.vpcf",
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_start_lightning.vpcf",
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_start_smoke.vpcf",
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_start_sparkly.vpcf",
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_start_tar_rope.vpcf",
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_start_target.vpcf",
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_start_trail.vpcf",
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_targetstart.vpcf"
        },
        travel_particles = {
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_travel.vpcf",
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_travel_sphere.vpcf",
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_travel_sphere_glow.vpcf",
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_glow.vpcf",
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_trail_electric_rpe.vpcf",
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_trail_rope.vpcf"
        },
        end_particles = {
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_end_drop.vpcf",
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_targetend.vpcf",
            "particles/units/heroes/hero_disruptor/disruptor_glimpse_targetend_sphere.vpcf"
        }
    }
end

function DotaKartAntiSkip:GetState(playerID)
    playerID = tonumber(playerID) or -1
    local st = self.states[playerID]
    if st == nil then
        st = {
            last_segment = nil,
            last_pos = nil,
            safe_pos = nil,
            safe_track_index = nil,
            safe_track_pos = nil,
            last_project_distance = nil,
            window_start_time = nil,
            window_start_segment = nil,
            window_start_distance = nil,
            window_start_pos = nil,
            window_start_track_index = nil,
            window_start_track_pos = nil,
            window_world_travel = 0,
            pending_return_pos = nil,
            pending_return_segment = nil,
            skip_grace_until = 0,
            teleport_grace_until = 0,
            pending_segment = nil,
            pending_until = 0,
            glimpse_active = false
        }
        self.states[playerID] = st
    end
    return st
end

function DotaKartAntiSkip:AuthorizeTeleport(playerID, duration)
    local st = self:GetState(playerID)
    st.teleport_grace_until = math.max(st.teleport_grace_until or 0, DKASNow() + (tonumber(duration) or self.config.teleport_grace or 1.25))
    st.pending_segment = nil
    st.pending_until = 0
    st.pending_return_pos = nil
    st.pending_return_segment = nil
end

function DotaKartAntiSkip:IsInsideOfficialSkip(pos)
    local controller = self.controller or GameRules.DotaKartController
    if controller ~= nil and controller.IsPositionInsideTrackSkip ~= nil and pos ~= nil then
        local ok, inside = pcall(function() return controller:IsPositionInsideTrackSkip(pos) end)
        return ok and inside == true
    end
    return false
end

-- FIX123: return targets are exact dk_track_* entity/world points, never an
-- arbitrary intermediate position sampled while the illegal shortcut was happening.
function DotaKartAntiSkip:GetTrackPointPosition(index, unit)
    local hud = self.hud or GameRules.DotaKartHUD
    local points = hud and hud.trackWorldPoints or nil
    if points == nil or #points == 0 then return nil, nil end
    local i = math.floor(tonumber(index) or 1)
    if i < 1 then i = 1 end
    if i > #points then i = #points end
    local raw = points[i]
    if raw == nil then return nil, nil end
    local p = DKASCopyVector(raw)
    if DKASValidUnit(unit) then
        local z = p.z or 0
        pcall(function() z = GetGroundHeight(p, unit) end)
        local controller = self.controller or GameRules.DotaKartController
        local offset = controller and controller.config and tonumber(controller.config.ground_z_offset) or 0
        p.z = z + offset
    end
    return p, i
end

function DotaKartAntiSkip:GetTrackPointYaw(index)
    local hud = self.hud or GameRules.DotaKartHUD
    local points = hud and hud.trackWorldPoints or nil
    if points == nil or #points < 2 then return nil end
    local i = math.floor(tonumber(index) or 1)
    if i < 1 then i = 1 end
    if i > #points then i = #points end
    local j = i + 1
    if j > #points then j = (hud and hud.trackClosed == false) and i or 1 end
    if j == i or points[i] == nil or points[j] == nil then return nil end
    local dx = points[j].x - points[i].x
    local dy = points[j].y - points[i].y
    if math.abs(dx) + math.abs(dy) < 0.01 then return nil end
    local angle = nil
    if math.atan2 ~= nil then angle = math.atan2(dy, dx) else angle = math.atan(dy / (math.abs(dx) < 0.001 and 0.001 or dx)) end
    return math.deg(angle)
end

function DotaKartAntiSkip:EmitWorldSound(name, pos, unit)
    if name == nil or name == "" or pos == nil then return end
    if EmitSoundOnLocationWithCaster ~= nil then
        pcall(function() EmitSoundOnLocationWithCaster(pos, name, unit) end)
    elseif StartSoundEventFromPosition ~= nil then
        pcall(function() StartSoundEventFromPosition(name, pos) end)
    end
end

function DotaKartAntiSkip:CreateWorldFX(name, pos, duration)
    if name == nil or name == "" or pos == nil or ParticleManager == nil then return nil end
    local fx = nil
    pcall(function()
        fx = ParticleManager:CreateParticle(name, PATTACH_WORLDORIGIN, nil)
        ParticleManager:SetParticleControl(fx, 0, pos)
        ParticleManager:SetParticleControl(fx, 1, pos)
    end)
    if fx ~= nil and duration ~= nil and duration > 0 then
        self.serial = (self.serial or 0) + 1
        local serial = self.serial
        GameRules:GetGameModeEntity():SetContextThink("DotaKartAntiSkipFX_" .. tostring(serial), function()
            pcall(function()
                ParticleManager:DestroyParticle(fx, false)
                ParticleManager:ReleaseParticleIndex(fx)
            end)
            return nil
        end, duration)
    end
    return fx
end

function DotaKartAntiSkip:CreateTravelFX(unit, startPos, targetPos)
    local fxs = {}
    if ParticleManager == nil then return fxs end
    for _,name in ipairs(self.config.travel_particles or {}) do
        local fx = nil
        pcall(function()
            fx = ParticleManager:CreateParticle(name, PATTACH_WORLDORIGIN, nil)
            ParticleManager:SetParticleControl(fx, 0, startPos)
            ParticleManager:SetParticleControl(fx, 1, targetPos)
            ParticleManager:SetParticleControl(fx, 2, targetPos)
        end)
        if fx ~= nil then table.insert(fxs, fx) end
    end
    return fxs
end

function DotaKartAntiSkip:DestroyFXList(fxs)
    if ParticleManager == nil then return end
    for _,fx in ipairs(fxs or {}) do
        pcall(function()
            ParticleManager:DestroyParticle(fx, false)
            ParticleManager:ReleaseParticleIndex(fx)
        end)
    end
end

function DotaKartAntiSkip:StartGlimpse(playerID, unit, returnPos, state)
    if not DKASValidUnit(unit) or returnPos == nil or state == nil or state.glimpse_active == true then return false end
    local startPos = DKASCopyVector(unit:GetAbsOrigin())
    local targetPos = DKASCopyVector(returnPos)
    local groundZ = GetGroundHeight(targetPos, unit)
    local controllerForGround = self.controller or GameRules.DotaKartController
    local groundOffset = controllerForGround and controllerForGround.config and tonumber(controllerForGround.config.ground_z_offset) or 0
    targetPos.z = groundZ + groundOffset
    local distance = DKASLength2D(startPos, targetPos)
    local travelTime = math.min(distance / math.max(1, tonumber(self.config.glimpse_speed) or 1000), tonumber(self.config.glimpse_max_time) or 1.8)
    travelTime = math.max(tonumber(self.config.glimpse_min_time) or 0.12, travelTime)

    state.glimpse_active = true
    state.pending_segment = nil
    state.pending_until = 0

    local controller = self.controller or GameRules.DotaKartController
    local controllerState = controller and controller.GetState and controller:GetState(playerID) or nil
    local savedLockedUntil = controllerState and tonumber(controllerState.locked_until) or 0
    local imposedLockUntil = DKASNow() + travelTime + 0.25
    if controllerState ~= nil then
        -- Hard freeze the normal kart controller/physics for the entire Glimpse return.
        -- The Glimpse thinker below is the only system allowed to change position.
        controllerState.anti_skip_glimpse_active = true
        controllerState.speed = 0
        controllerState.bump_push_x = 0
        controllerState.bump_push_y = 0
    end
    if controller ~= nil and controller.SetKartLocked ~= nil then
        controller:SetKartLocked(playerID, travelTime + 0.25)
    elseif controllerState ~= nil then
        controllerState.locked_until = math.max(controllerState.locked_until or 0, imposedLockUntil)
    end

    self:EmitWorldSound(self.config.sound_begin, startPos, unit)
    for _,name in ipairs(self.config.target_particles or {}) do self:CreateWorldFX(name, targetPos, travelTime + 0.7) end
    for _,name in ipairs(self.config.start_particles or {}) do self:CreateWorldFX(name, startPos, math.min(1.0, travelTime + 0.25)) end
    local travelFX = self:CreateTravelFX(unit, startPos, targetPos)

    self.serial = (self.serial or 0) + 1
    local serial = self.serial
    local beginTime = DKASNow()
    GameRules:GetGameModeEntity():SetContextThink("DotaKartAntiSkipGlimpse_" .. tostring(playerID) .. "_" .. tostring(serial), function()
        if not DKASValidUnit(unit) then
            self:DestroyFXList(travelFX)
            state.glimpse_active = false
            local cs = controller and controller.GetState and controller:GetState(playerID) or nil
            if cs ~= nil then cs.anti_skip_glimpse_active = false; cs.speed = 0 end
            return nil
        end

        local now = DKASNow()
        local liveState = controller and controller.GetState and controller:GetState(playerID) or nil
        if liveState ~= nil then
            liveState.anti_skip_glimpse_active = true
            liveState.speed = 0
            liveState.bump_push_x = 0
            liveState.bump_push_y = 0
        end
        local t = math.min(1, math.max(0, (now - beginTime) / math.max(0.01, travelTime)))
        local x = startPos.x + (targetPos.x - startPos.x) * t
        local y = startPos.y + (targetPos.y - startPos.y) * t
        local z = startPos.z + (targetPos.z - startPos.z) * t
        local current = Vector(x, y, z)
        pcall(function() unit:SetAbsOrigin(current) end)
        if ParticleManager ~= nil then
            for _,fx in ipairs(travelFX) do
                pcall(function()
                    ParticleManager:SetParticleControl(fx, 0, current)
                    ParticleManager:SetParticleControl(fx, 1, targetPos)
                    ParticleManager:SetParticleControl(fx, 2, targetPos)
                end)
            end
        end

        if t >= 1 then
            -- Exact checkpoint return: do not call FindClearSpaceForUnit here because it
            -- may offset the kart away from the dk_track_* entity that was selected.
            pcall(function() unit:SetAbsOrigin(targetPos) end)
            self:DestroyFXList(travelFX)
            for _,name in ipairs(self.config.end_particles or {}) do self:CreateWorldFX(name, targetPos, 1.2) end
            self:EmitWorldSound(self.config.sound_end, targetPos, unit)

            local cs = controller and controller.GetState and controller:GetState(playerID) or nil
            if cs ~= nil then
                -- Re-enable normal control only after the exact legal dk_track_* point is reached.
                cs.anti_skip_glimpse_active = false
                cs.speed = 0
                cs.bump_push_x = 0
                cs.bump_push_y = 0
                -- Remove only the lock imposed by Glimpse. Preserve a longer external lock.
                if (tonumber(cs.locked_until) or 0) <= imposedLockUntil + 0.05 then
                    cs.locked_until = math.max(savedLockedUntil or 0, now)
                end
                local legalYaw = self:GetTrackPointYaw(state.pending_return_segment)
                if legalYaw ~= nil then
                    cs.yaw = legalYaw
                    if controller ~= nil and controller.SetHeroFacing ~= nil then
                        pcall(function() controller:SetHeroFacing(unit, legalYaw) end)
                    end
                end
            end
            state.glimpse_active = false
            state.teleport_grace_until = now + (tonumber(self.config.teleport_grace) or 1.25)
            state.last_pos = DKASCopyVector(targetPos)
            state.safe_pos = DKASCopyVector(targetPos)
            state.safe_track_pos = DKASCopyVector(targetPos)
            state.safe_track_index = tonumber(state.pending_return_segment) or state.safe_track_index
            state.last_segment = tonumber(state.safe_track_index) or nil
            state.pending_return_segment = nil
            return nil
        end
        return tonumber(self.config.think_interval) or 0.03
    end, 0)

    print("[DotaKartAntiSkip] Player " .. tostring(playerID) .. " returned by Glimpse after illegal track skip")
    return true
end

-- Called before HUD commits a projected path jump. Returns true when normal HUD progress
-- should be frozen for this sample (suspicious jump or active Glimpse).
function DotaKartAntiSkip:OnRacerProjected(racer, unit, pos, project, now)
    if racer == nil or not DKASValidUnit(unit) or pos == nil or project == nil then return false end
    local hud = self.hud or GameRules.DotaKartHUD
    if hud == nil or hud.raceRunning ~= true or racer.finished == true then
        local st = self:GetState(racer.player_id)
        st.last_segment = nil
        st.last_pos = nil
        st.safe_pos = nil
        st.safe_track_index = nil
        st.safe_track_pos = nil
        st.last_project_distance = nil
        st.window_start_time = nil
        st.window_start_segment = nil
        st.window_start_distance = nil
        st.window_start_pos = nil
        st.window_start_track_index = nil
        st.window_start_track_pos = nil
        st.window_world_travel = 0
        st.pending_return_pos = nil
        st.pending_return_segment = nil
        st.pending_segment = nil
        st.pending_until = 0
        st.glimpse_active = false
        return false
    end

    local playerID = tonumber(racer.player_id) or -1
    if playerID < 0 then return false end
    local st = self:GetState(playerID)
    now = tonumber(now) or DKASNow()

    if st.glimpse_active == true then return true end

    local currentSegment = tonumber(project.nearest_segment) or 1
    local currentPos = DKASCopyVector(pos)
    local insideSkip = self:IsInsideOfficialSkip(currentPos)
    if insideSkip then
        st.skip_grace_until = now + (tonumber(self.config.skip_grace) or 4.0)
    end

    local currentDistance = tonumber(project.distance) or 0
    if st.last_segment == nil or st.last_pos == nil or st.safe_pos == nil then
        local trackPos, trackIndex = self:GetTrackPointPosition(currentSegment, unit)
        st.last_segment = currentSegment
        st.last_pos = currentPos
        st.safe_pos = currentPos
        st.safe_track_index = trackIndex or currentSegment
        st.safe_track_pos = DKASCopyVector(trackPos or currentPos)
        st.last_project_distance = currentDistance
        st.window_start_time = now
        st.window_start_segment = currentSegment
        st.window_start_distance = currentDistance
        st.window_start_pos = DKASCopyVector(currentPos)
        st.window_start_track_index = st.safe_track_index
        st.window_start_track_pos = DKASCopyVector(st.safe_track_pos)
        st.window_world_travel = 0
        st.pending_return_pos = nil
        st.pending_return_segment = nil
        st.pending_segment = nil
        return false
    end

    local authorized = now <= (tonumber(st.teleport_grace_until) or 0) or now <= (tonumber(st.skip_grace_until) or 0)
    local worldStep = DKASLength2D(currentPos, st.last_pos)
    local segmentJump = currentSegment - (tonumber(st.last_segment) or currentSegment)
    local hud = self.hud or GameRules.DotaKartHUD
    local trackLength = math.max(1, tonumber(hud and hud.trackLength) or 1)

    if st.window_start_time == nil or st.window_start_segment == nil or st.window_start_distance == nil then
        st.window_start_time = now
        st.window_start_segment = tonumber(st.last_segment) or currentSegment
        st.window_start_distance = tonumber(st.last_project_distance) or currentDistance
        st.window_start_pos = DKASCopyVector(st.safe_pos or currentPos)
        st.window_start_track_index = st.safe_track_index or st.window_start_segment
        st.window_start_track_pos = DKASCopyVector(st.safe_track_pos or st.window_start_pos)
        st.window_world_travel = 0
    end
    st.window_world_travel = (tonumber(st.window_world_travel) or 0) + worldStep
    local windowAge = now - (tonumber(st.window_start_time) or now)
    local windowSegmentGain = currentSegment - (tonumber(st.window_start_segment) or currentSegment)
    local windowPathGain = currentDistance - (tonumber(st.window_start_distance) or currentDistance)

    -- Crossing the finish line wraps project.distance; start a fresh observation window.
    if windowPathGain < -trackLength * 0.35 then
        st.window_start_time = now
        st.window_start_segment = currentSegment
        st.window_start_distance = currentDistance
        st.window_start_pos = DKASCopyVector(currentPos)
        local wrapTrackPos, wrapTrackIndex = self:GetTrackPointPosition(currentSegment, unit)
        st.window_start_track_index = wrapTrackIndex or currentSegment
        st.window_start_track_pos = DKASCopyVector(wrapTrackPos or currentPos)
        st.window_world_travel = 0
        windowAge = 0
        windowSegmentGain = 0
        windowPathGain = 0
    end

    -- FIX143: a big forward jump only counts as a skip when the track distance gained is much
    -- larger than the real distance moved (a cut). Burrowstrike/Leap straight along the road
    -- move many dk_track_* segments in one sample but gain about the same distance they travel.
    local stepPathGain = currentDistance - (tonumber(st.last_project_distance) or currentDistance)
    if stepPathGain < -trackLength * 0.35 then stepPathGain = stepPathGain + trackLength end
    local suspiciousSegmentJump = segmentJump > (tonumber(self.config.max_forward_segment_jump) or 6)
        and stepPathGain > worldStep * (tonumber(self.config.shortcut_path_ratio) or 1.55)
            + (tonumber(self.config.shortcut_path_margin) or 260)
    local suspiciousShortcutCut = windowAge <= (tonumber(self.config.shortcut_window) or 1.10)
        and windowSegmentGain >= (tonumber(self.config.shortcut_min_segment_gain) or 7)
        and windowPathGain >= (tonumber(self.config.shortcut_min_path_gain) or 900)
        and windowPathGain > ((tonumber(st.window_world_travel) or 0) * (tonumber(self.config.shortcut_path_ratio) or 1.55)
            + (tonumber(self.config.shortcut_path_margin) or 260))

    -- Official dk_track_skip and explicitly authorized teleports bypass both tests.
    -- A second suspicious sample is still required to avoid false positives at crossings.
    local suspicious = (not authorized) and (suspiciousSegmentJump or suspiciousShortcutCut)

    if authorized then
        st.pending_segment = nil
        st.pending_until = 0
        st.pending_return_pos = nil
        st.pending_return_segment = nil
        st.window_start_time = now
        st.window_start_segment = currentSegment
        st.window_start_distance = currentDistance
        st.window_start_pos = DKASCopyVector(currentPos)
        local authTrackPos, authTrackIndex = self:GetTrackPointPosition(currentSegment, unit)
        st.window_start_track_index = authTrackIndex or currentSegment
        st.window_start_track_pos = DKASCopyVector(authTrackPos or currentPos)
        st.window_world_travel = 0
    end

    -- Confirmation is based on the racer remaining near/ahead of the suspicious projected
    -- segment on the next HUD sample. We do not require the path/world ratio to be identical
    -- on the second sample, because the first sample intentionally freezes the safe anchor.
    if (not authorized) and st.pending_segment ~= nil and now <= (tonumber(st.pending_until) or 0)
        and currentSegment >= ((tonumber(st.pending_segment) or currentSegment) - 1) then
        self:StartGlimpse(playerID, unit, st.pending_return_pos or st.safe_track_pos or st.safe_pos, st)
        return true
    end

    if suspicious then
        st.pending_segment = currentSegment
        st.pending_until = now + (tonumber(self.config.suspicious_confirm_window) or 0.40)
        -- FIX123: return to the exact last legal dk_track_* checkpoint. For a
        -- continuous curve cut, use the track point from the beginning of the window.
        if suspiciousShortcutCut then
            st.pending_return_segment = tonumber(st.window_start_track_index) or tonumber(st.window_start_segment) or tonumber(st.safe_track_index)
            st.pending_return_pos = DKASCopyVector(st.window_start_track_pos or st.safe_track_pos or st.safe_pos)
        else
            st.pending_return_segment = tonumber(st.safe_track_index) or tonumber(st.last_segment)
            st.pending_return_pos = DKASCopyVector(st.safe_track_pos or st.safe_pos)
        end
        return true
    end

    -- If the first suspicious sample was just nearest-segment ambiguity, allow recovery.
    if st.pending_segment ~= nil then
        st.pending_segment = nil
        st.pending_until = 0
        st.pending_return_pos = nil
        st.pending_return_segment = nil
    end

    st.last_segment = currentSegment
    st.last_pos = currentPos
    st.safe_pos = currentPos
    local safeTrackPos, safeTrackIndex = self:GetTrackPointPosition(currentSegment, unit)
    st.safe_track_index = safeTrackIndex or currentSegment
    st.safe_track_pos = DKASCopyVector(safeTrackPos or currentPos)
    st.last_project_distance = currentDistance

    if (now - (tonumber(st.window_start_time) or now)) > (tonumber(self.config.shortcut_window) or 1.10) then
        st.window_start_time = now
        st.window_start_segment = currentSegment
        st.window_start_distance = currentDistance
        st.window_start_pos = DKASCopyVector(currentPos)
        st.window_start_track_index = st.safe_track_index or currentSegment
        st.window_start_track_pos = DKASCopyVector(st.safe_track_pos or currentPos)
        st.window_world_travel = 0
    end
    return false
end
