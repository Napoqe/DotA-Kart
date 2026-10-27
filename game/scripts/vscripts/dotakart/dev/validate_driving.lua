-- Manual Tools test only. Uses real controller ticks, then stops and restores the kart.
local ctrl = GameRules.DotaKartController
local hero = ctrl and ctrl:GetHeroForPlayer(0)
assert(IsInToolsMode() and hero and not hero:IsNull(), "Tools game with a human kart required")
assert(not ctrl._drivingQA, "Driving validation already running")
local st = ctrl:GetState(0)
local origin, yaw = hero:GetAbsOrigin(), st.yaw
local input = {}; for k,v in pairs(st.input) do input[k]=v end
local testPos, testYaw
local bestLength = 0
for _,seg in ipairs(ctrl.hud.trackSegments or {}) do
    local pos = (seg.a + seg.b) * 0.5
    if seg.length > bestLength and GridNav:IsTraversable(pos)
            and not GridNav:IsBlocked(pos) and not GridNav:IsNearbyTree(pos, 128, true) then
        bestLength, testPos = seg.length, pos
        local dir = seg.b - seg.a
        testYaw = math.deg(math.atan2(dir.y, dir.x))
    end
end
assert(testPos, "No clear road segment found")
testPos.z = GetGroundHeight(testPos, hero) + ctrl.config.ground_z_offset
local phases = {
    {"forward", 1.0, 880, true, false, false, false, "kart_drive"},
    {"left", 1.1, 880, true, false, true, false, "kart_drive_left"},
    {"recovery", 1.0, nil, true, false, false, false, "kart_drive"},
    {"right", 1.1, 880, true, false, false, true, "kart_drive_right"},
    {"reverse", .6, -300, false, true, false, false, "kart_reverse"},
    {"reverse_left", .6, -300, false, true, true, false, "kart_reverse_left"},
    {"reverse_right", .6, -300, false, true, false, true, "kart_reverse_right"}
}
local index, started, previous, samples, aligned, clip, drift, sound, slip = 0
local function finish()
    ctrl._drivingQA = nil
    st.input = input; st.speed = 0; st.yaw = yaw
    DotaKartHandling:Reset(st, yaw)
    hero:SetAbsOrigin(origin); ctrl:SetHeroFacing(hero, yaw)
    DotaKartHandling:UpdateSound(ctrl, 0, hero, st, GameRules:GetGameTime())
    DotaKartAnimation:Update(ctrl, 0, hero, st, .03, GameRules:GetGameTime())
    print("[KART_DRIVE_QA] finished; kart stopped and restored")
end
local function nextPhase(now)
    index = index + 1
    local phase = phases[index]
    if not phase then finish(); return false end
    if phase[3] then
        hero:SetAbsOrigin(testPos); st.yaw = testYaw; st.speed = phase[3]
        DotaKartHandling:Reset(st, testYaw); ctrl:SetHeroFacing(hero, testYaw)
    end
    ctrl:SetTestInput(0, phase[4], phase[5], phase[6], phase[7])
    started, previous, samples, aligned, clip, drift, sound, slip = now, hero:GetAbsOrigin(), 0, 1, false, false, false, 0
    print("[KART_DRIVE_QA] starting " .. phase[1])
    return true
end
ctrl._drivingQA = true
nextPhase(GameRules:GetGameTime())
GameRules:GetGameModeEntity():SetContextThink("DotaKartValidateDriving", function()
    local ok, result = xpcall(function()
        if hero:IsNull() or not hero:IsAlive() then error("Kart unavailable") end
        local now, phase = GameRules:GetGameTime(), phases[index]
        local pos = hero:GetAbsOrigin()
        local delta = pos - previous; previous = pos
        if delta:Length2D() > 1 and phase[1] ~= "recovery" then
            samples = samples + 1
            local move = delta:Normalized(); local fwd = hero:GetForwardVector()
            local dot = move.x * fwd.x + move.y * fwd.y
            if phase[3] < 0 then dot = -dot end
            aligned = math.min(aligned, dot)
        end
        local visual = st.kart_visual_entity
        local animated = visual and not visual:IsNull() and visual or hero
        clip = clip or animated:GetSequence() == phase[8]
        drift = drift or st.drift_active == true
        sound = sound or st.drift_sound == "dotakart_tire_drift"
        slip = math.max(slip, st.drift_slip_angle or 0)
        if now - started >= phase[2] then
            local turn = (st.yaw - testYaw + 180) % 360 - 180
            local pass = clip and ctrl:GetCustomKartVisualYawOffset(hero) == 0
            if phase[1] == "left" or phase[1] == "right" then
                pass = pass and drift and sound and slip > 5 and samples > 5
            elseif phase[1] == "recovery" then
                pass = pass and not st.drift_active and not st.drift_sound and (st.drift_slip_angle or 0) < 1
            else
                pass = pass and samples > 5 and aligned > .97
            end
            if phase[1] == "left" or phase[1] == "reverse_right" then pass = pass and turn > 5 end
            if phase[1] == "right" or phase[1] == "reverse_left" then pass = pass and turn < -5 end
            print(string.format("[KART_DRIVE_QA] %s %s samples=%d alignment=%.3f turn=%.2f slip=%.2f drift=%s sound=%s clip=%s",
                pass and "PASS" or "FAIL", phase[1], samples, aligned, turn, slip, tostring(drift), tostring(sound), tostring(clip)))
            if not nextPhase(now) then return nil end
        end
        return .03
    end, debug.traceback)
    if not ok then print("[KART_DRIVE_QA] FAIL " .. tostring(result)); finish(); return nil end
    return result
end, .03)
