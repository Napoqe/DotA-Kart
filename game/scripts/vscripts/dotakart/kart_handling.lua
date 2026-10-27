-- Tire grip and automatic drift. Position/collisions remain owned by the controller.
if DotaKartHandling == nil then DotaKartHandling = {} end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function angle(v) return (v + 180) % 360 - 180 end

function DotaKartHandling:Reset(st, yaw)
    st.motion_yaw = yaw
    st.drift_held = 0
    st.drift_steer = 0
    st.drift_weight = 0
    st.drift_active = false
    st.drift_slip_angle = 0
end

function DotaKartHandling:Update(config, st, yaw, speed, steer, dt)
    dt = math.max(0, dt)
    if not config.drift_enabled or speed < 120 or st.ball_lightning_active then
        -- Reverse keeps its existing inverted steering and full tire grip.
        self:Reset(st, yaw)
        return yaw, speed
    end
    local eligible = speed >= (config.drift_min_speed or 360) and steer ~= 0
    if eligible then
        if st.drift_steer ~= steer then st.drift_held = 0 end
        st.drift_held = (st.drift_held or 0) + dt
        st.drift_steer = steer
    else
        st.drift_held = 0
        st.drift_steer = 0
    end
    st.drift_active = eligible and st.drift_held >= (config.drift_hold_time or 0.12)
    local target = st.drift_active and 1 or 0
    st.drift_weight = target + ((st.drift_weight or 0) - target) * math.exp(-dt / (target == 1 and 0.18 or 0.12))
    local power = clamp(speed / math.max(1, config.max_speed or 880), 0, 1)
    local weight = st.drift_weight
    local grip = 13 - (13 - (config.drift_grip or 3.4)) * weight
    local limit = (10 + ((config.drift_max_angle or 28) - 10) * weight) * power
    local slip = angle(yaw - (st.motion_yaw or yaw)) * math.exp(-grip * dt)
    slip = clamp(slip, -limit, limit)
    st.motion_yaw = angle(yaw - slip)
    st.drift_slip_angle = math.abs(slip)
    speed = speed * math.exp(-(config.drift_speed_loss_per_second or 0.08) * weight * dt)
    return st.motion_yaw, speed
end

function DotaKartHandling:UpdateSound(controller, playerID, hero, st, now)
    local valid = hero ~= nil and not hero:IsNull() and hero:IsAlive()
    local blocked = not valid or not controller.enabled
        or (st.locked_until or 0) > now or (st.rooted_until or 0) > now
        or (st.stunned_until or 0) > now or (st.astral_enemy_until or 0) > now
        or st.anti_skip_glimpse_active or st.storm_hammer_transport_active or st.ball_lightning_active
    local hud = controller.hud or (GameRules and GameRules.DotaKartHUD)
    if hud and hud.raceRunning == false then blocked = true end
    if hud and hud.IsPlayerFinished and hud:IsPlayerFinished(playerID) then blocked = true end
    local sound
    if not blocked and controller.config.drift_enabled and (st.speed or 0) > 240 then
        local slip = st.drift_slip_angle or 0
        if st.drift_active and slip > 5 then sound = "dotakart_tire_drift"
        elseif slip > 3 then sound = "dotakart_tire_skid" end
    end
    if blocked then self:Reset(st, st.yaw or 0) end
    if st.drift_sound ~= sound or st.drift_sound_hero ~= hero then
        if st.drift_sound and st.drift_sound_hero and not st.drift_sound_hero:IsNull() then
            st.drift_sound_hero:StopSound(st.drift_sound)
        end
        st.drift_sound = sound
        st.drift_sound_hero = hero
        if sound then hero:EmitSound(sound) end
    end
end
