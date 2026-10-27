-- Cosmetic animation only: physics continues to own position, speed and yaw.
require("dotakart/kart_visual")
if DotaKartAnimation == nil then DotaKartAnimation = {} end

local function clamp(value, low, high) return math.max(low, math.min(high, value)) end
local function angleDelta(value) return (value + 180) % 360 - 180 end
local clips = { "kart_idle", "kart_idle_left", "kart_idle_right",
    "kart_drive", "kart_drive_left", "kart_drive_right",
    "kart_reverse", "kart_reverse_left", "kart_reverse_right" }

-- Slots match the compiled clips. Steering keeps its physical wheel direction
-- in reverse; the existing controller reverses the vehicle's yaw response.
function DotaKartAnimation:SelectState(speed, steer)
    local direction = speed > 8 and 1 or (speed < -8 and -1 or 0)
    local column = steer > 0 and 1 or (steer < 0 and 2 or 0)
    local first = direction > 0 and 4 or (direction < 0 and 7 or 1)
    local rate = direction == 0 and 1 or clamp(math.abs(speed) / 880, 0.10, 2.5)
    return first + column, rate
end

function DotaKartAnimation:Update(controller, playerID, hero, st, dt, now)
    if hero == nil or hero:IsNull() then DotaKartVisual:Remove(st); return end
    local name = hero:GetUnitName()
    local custom = controller.kart_models and controller.kart_models[name]
    if custom == nil then DotaKartVisual:Remove(st); return end
    local speed = tonumber(st.speed) or 0
    local blocked = controller.enabled ~= true or not hero:IsAlive()
        or (tonumber(st.locked_until) or 0) > now
        or (tonumber(st.rooted_until) or 0) > now
        or (tonumber(st.stunned_until) or 0) > now
        or (tonumber(st.astral_enemy_until) or 0) > now
        or st.anti_skip_glimpse_active == true or st.storm_hammer_transport_active == true
    local hud = GameRules and GameRules.DotaKartHUD
    if hud and hud.IsPlayerFinished and hud:IsPlayerFinished(playerID) then blocked = true end
    if blocked then speed = 0 end

    local steer = 0
    if controller:IsPublicAIControlled(playerID, hero) then
        local yaw = tonumber(st.yaw) or 0
        if st.kart_animation_last_yaw ~= nil and math.abs(speed) > 8 then
            local turn = angleDelta(yaw - st.kart_animation_last_yaw) / math.max(0.001, dt)
            if speed < 0 then turn = -turn end
            -- Small route corrections must not restart a whole steering clip.
            local previous = st.kart_animation_ai_steer or 0
            if math.abs(turn) > 8 then steer = turn > 0 and 1 or -1
            elseif math.abs(turn) > 2 and previous * turn > 0 then steer = previous end
            st.kart_animation_ai_steer = steer
        end
        if st.kart_ai_visual_steer ~= nil then steer=st.kart_ai_visual_steer end
        st.kart_animation_last_yaw = yaw
    else
        local input = st.input or {}
        steer = (input.left and 1 or 0) - (input.right and 1 or 0)
        steer = steer * (tonumber(controller.config.steering_sign) or 1)
    end
    if blocked then steer = 0 end
    local slot, rate = self:SelectState(speed, steer)
    local activities = { ACT_DOTA_IDLE, ACT_DOTA_CAST_ABILITY_1, ACT_DOTA_CAST_ABILITY_2,
        ACT_DOTA_RUN, ACT_DOTA_CAST_ABILITY_3, ACT_DOTA_CAST_ABILITY_4,
        ACT_DOTA_ATTACK, ACT_DOTA_CAST_ABILITY_5, ACT_DOTA_CAST_ABILITY_6 }
    -- Stack count replicates animation selection/rate to the rendering client.
    local encoded = math.floor(rate * 20 + 0.5) * 4096 + activities[slot]
    local modifier = hero:FindModifierByName("modifier_dotakart_kart_visual")
    if modifier == nil then modifier = hero:AddNewModifier(hero, nil, "modifier_dotakart_kart_visual", { stack_count = encoded }) end
    if modifier and modifier:GetStackCount() ~= encoded then modifier:SetStackCount(encoded) end
    -- Animate the real NPC only when it is the visible fallback. Its invisible
    -- carrier model has no kart sequences; the prop owns those animations.
    local clip = clips[slot]
    if st.kart_visual_carrier_hidden ~= true then
        if hero.SetSequence and hero.SetCycle then
            if st.kart_animation_hero ~= hero or st.kart_animation_clip ~= clip
                or (hero.GetSequence and hero:GetSequence() ~= clip) then
                hero:SetSequence(clip)
                st.kart_animation_hero = hero
                st.kart_animation_clip = clip
                st.kart_animation_duration = hero.SequenceDuration and hero:SequenceDuration(clip) or 1
            end
            local duration = math.max(0.01, tonumber(st.kart_animation_duration) or 1)
            st.kart_animation_cycle = ((st.kart_animation_cycle or 0) + math.max(0, dt) * rate / duration) % 1
            hero:SetCycle(st.kart_animation_cycle)
        elseif hero.StartGestureWithPlaybackRate then
            -- Compatibility fallback: restart only on a state change, not every tick.
            local activity = modifier and modifier:GetOverrideAnimation()
            if activity and st.kart_animation_gesture ~= activity then
                if st.kart_animation_gesture and hero.RemoveGesture then hero:RemoveGesture(st.kart_animation_gesture) end
                hero:StartGestureWithPlaybackRate(activity, rate)
                st.kart_animation_gesture = activity
            end
        end
    end
    st.kart_animation_slot = slot
    st.kart_animation_rate = rate
    DotaKartVisual:Update(hero, st, custom, clip, rate, now)
end

