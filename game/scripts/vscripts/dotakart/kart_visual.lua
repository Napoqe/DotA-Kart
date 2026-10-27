-- Animated rendering only. The real hero remains the racer, item target and
-- collision body; the prop has no collision and never drives its parent.
if DotaKartVisual == nil then DotaKartVisual = {} end
local visualVersion = 15
local carrierModel = "models/development/invisiblebox.vmdl"

local function valid(entity) return entity ~= nil and not entity:IsNull() end

-- One brief pause refreshes kart rendering on clients that otherwise only show
-- the animated props after a manual pause. This is a startup workaround, not
-- part of movement or item visibility. The client supplies the resume timer:
-- entity think callbacks stop executing during PauseGame in this Dota build.
function DotaKartVisual:InitStartupRefresh()
    if self.startupListenersRegistered then return end
    self.startupListenersRegistered = true
    CustomGameEventManager:RegisterListener("dotakart_render_refresh_armed", function(_, keys)
        if self.startupRefreshDone or not self.startupRefreshScheduled
            or tonumber(keys.token) ~= self.startupRefreshToken or GameRules:IsGamePaused() then return end
        self.startupRefreshOwnsPause = true
        PauseGame(true)
        print("[KART_SERVER_QA] startup render refresh paused briefly")
    end)
    CustomGameEventManager:RegisterListener("dotakart_render_refresh_resume", function(_, keys)
        if not self.startupRefreshOwnsPause or tonumber(keys.token) ~= self.startupRefreshToken then return end
        -- Consume ownership before unpausing so duplicate client replies cannot
        -- later resume a separate pause made by a player.
        self.startupRefreshOwnsPause = false
        self.startupRefreshDone = true
        self.startupRefreshScheduled = false
        if GameRules:IsGamePaused() then PauseGame(false) end
        print("[KART_SERVER_QA] startup render refresh resumed automatically by client")
    end)
end

function DotaKartVisual:RefreshBeforeRace()
    if self.startupRefreshScheduled or self.startupRefreshDone then return end
    if type(PauseGame) ~= "function" or type(Plat_FloatTime) ~= "function" then
        print("[KART_SERVER_QA] startup refresh unavailable: missing pause/real-time API")
        return
    end
    local mode = GameRules:GetGameModeEntity()
    if not valid(mode) then return end
    self:InitStartupRefresh()
    self.startupRefreshScheduled = true
    local startedAt = Plat_FloatTime()
    self.startupRefreshToken = (self.startupRefreshToken or 0) + 1
    local requestedAt = nil
    mode:SetContextThink("DotaKartStartupRenderRefresh", function()
        if self.startupRefreshDone then return nil end
        -- A pre-existing player pause must not be resumed by our timer.
        if GameRules:IsGamePaused() then return .03 end
        if requestedAt then
            if Plat_FloatTime() - requestedAt < 2 then return .03 end
            self.startupRefreshScheduled = false
            print("[KART_SERVER_QA] startup render refresh skipped: no client acknowledgement")
            return nil
        end
        local ctrl = GameRules.DotaKartController
        local ready, count = true, 0
        local now = GameRules:GetGameTime()
        for playerID, st in pairs(ctrl and ctrl.states or {}) do
            local hero = ctrl:GetHeroForPlayer(playerID)
            if valid(hero) and hero:IsAlive() then
                count = count + 1
                if not valid(st.kart_visual_entity) or st.kart_visual_hero ~= hero
                    or now < (st.kart_visual_ready_at or math.huge) then ready = false end
            end
        end
        if not ready or count == 0 then
            if Plat_FloatTime() - startedAt < 5 then return .03 end
            self.startupRefreshScheduled = false
            print("[KART_SERVER_QA] startup render refresh skipped: visuals not ready")
            return nil
        end
        requestedAt = Plat_FloatTime()
        -- Never pause until an active client has armed its independent timer.
        CustomGameEventManager:Send_ServerToAllClients("dotakart_render_refresh_prepare", {
            token = self.startupRefreshToken
        })
        print("[KART_SERVER_QA] startup render refresh requested; karts=" .. tostring(count))
        return .03
    end, .50)
end

function DotaKartVisual:Remove(st)
    if valid(st.kart_visual_entity) then UTIL_Remove(st.kart_visual_entity) end
    if valid(st.kart_visual_hero) then
        st.kart_visual_hero.dk_kart_animated_visual = nil
        st.kart_visual_hero:RemoveModifierByName("modifier_dotakart_kart_carrier")
        if st.kart_visual_model then
            st.kart_visual_hero:SetOriginalModel(st.kart_visual_model)
            st.kart_visual_hero:SetModel(st.kart_visual_model)
        end
        st.kart_visual_hero:SetRenderAlpha(255)
        if not st.kart_visual_hero:HasModifier("modifier_dotakart_astral_enemy") then
            st.kart_visual_hero:RemoveNoDraw()
        end
    end
    st.kart_visual_entity = nil
    st.kart_visual_hero = nil
    st.kart_visual_model = nil
    st.kart_visual_clip = nil
    st.kart_visual_rate = nil
    st.kart_visual_hidden = nil
    st.kart_visual_ready_at = nil
    st.kart_visual_rate_ready_at = nil
    st.kart_visual_carrier_hidden = nil
    st.kart_visual_version = nil
    st.kart_visual_parented = nil
    st.kart_visual_scale = nil
end

function DotaKartVisual:Update(hero, st, model, clip, rate, now)
    if not valid(hero) then self:Remove(st); return end
    if st.kart_visual_hero ~= hero or st.kart_visual_model ~= model
        or st.kart_visual_version ~= visualVersion then self:Remove(st) end
    local visual = st.kart_visual_entity
    if not valid(visual) then
        if not hero:IsAlive() then return end
        visual = SpawnEntityFromTableSynchronous("prop_dynamic", {
            model = model, DefaultAnim = clip, solid = "0",
            origin = hero:GetAbsOrigin(),
            -- Eight moving kart visuals must reach every racing client, even
            -- when spawned outside that client's initial visibility area.
            -- 2048: always networked; other flags disable collision/navigation.
            spawnflags = 2048 + 256 + 512 + 1024,
            targetname = "dk_kart_animation_" .. tostring(hero:entindex())
        })
        if not valid(visual) then return end -- retain the seated hero if creation fails
        -- State owns this independent rendering entity's lifetime.
        visual:SetModelScale(hero:GetModelScale())
        -- One replicated hierarchy: the mesh uses the same interpolated transform
        -- as the hero instead of a second stream of 30 ms world-space teleports.
        if visual.SetParent and visual.SetLocalOrigin and visual.SetLocalAngles then
            local attached = pcall(function()
                visual:SetParent(hero, "")
                visual:SetLocalOrigin(Vector(0,0,0))
                visual:SetLocalAngles(0,0,0)
            end)
            st.kart_visual_parented = attached
            if not attached then pcall(function() visual:SetParent(nil, "") end) end
        end
        st.kart_visual_scale = hero:GetModelScale()
        st.kart_visual_entity = visual
        st.kart_visual_hero = hero
        st.kart_visual_model = model
        st.kart_visual_version = visualVersion
        st.kart_visual_ready_at = now + .25
        st.kart_visual_rate = 1
        st.kart_visual_hidden = false
        hero.dk_kart_animated_visual = visual
    end
    if not st.kart_visual_parented then
        visual:SetAbsOrigin(hero:GetAbsOrigin())
        local angles = hero:GetAnglesAsVector()
        visual:SetAbsAngles(angles.x, angles.y, angles.z)
    end
    hero.dk_kart_animated_visual = visual
    -- Bloodlust can resize the hero after the visual was created.
    if st.kart_visual_scale ~= hero:GetModelScale() then
        visual:SetModelScale(hero:GetModelScale())
        st.kart_visual_scale = hero:GetModelScale()
    end
    local warmingUp = now < (st.kart_visual_ready_at or 0)
    -- Keep native animation ticking; sending SetCycle each server tick does not
    -- reproduce the rendered NPC animation in this Dota build.
    if not warmingUp and st.kart_visual_clip ~= clip then
        DoEntFireByInstanceHandle(visual, "SetAnimationLooping", clip, 0, hero, hero)
        st.kart_visual_clip = clip
        -- Let the new sequence replicate before changing its playback rate.
        st.kart_visual_rate_ready_at = now + .10
    end
    local roundedRate = math.floor(rate * 20 + .5) / 20
    if not warmingUp and now >= (st.kart_visual_rate_ready_at or 0)
        and st.kart_visual_rate ~= roundedRate then
        DoEntFireByInstanceHandle(visual, "SetPlaybackRate", tostring(roundedRate), 0, hero, hero)
        st.kart_visual_rate = roundedRate
    end
    local imprisoned = hero:HasModifier("modifier_dotakart_astral_enemy")
        or (tonumber(st.astral_enemy_until) or 0) > now
    local invisible = hero:IsInvisible()
    -- The rendering entity starts enabled; item effects may disable it later.
    local hidden = not hero:IsAlive() or imprisoned or invisible
    if st.kart_visual_hidden ~= hidden then
        -- prop_dynamic has entity inputs, not the NPC Add/RemoveNoDraw methods.
        DoEntFireByInstanceHandle(visual, hidden and "TurnOff" or "TurnOn", "", 0, hero, hero)
        st.kart_visual_hidden = hidden
    end
    -- Only the prop renders the kart. Alpha alone cannot hide its opaque materials.
    -- The model override preserves the NPC's render entity and restores the real
    -- kart model for team-dependent invisibility or when the visual is removed.
    local carrierHidden = not invisible or not hero:IsAlive() or imprisoned
    local hasCarrier = hero:HasModifier("modifier_dotakart_kart_carrier")
    if carrierHidden and not hasCarrier then
        hero:AddNewModifier(hero, nil, "modifier_dotakart_kart_carrier", {})
    elseif not carrierHidden and hasCarrier then
        hero:RemoveModifierByName("modifier_dotakart_kart_carrier")
    end
    -- Spawn/wearable cleanup can call SetModel after the modifier was added.
    -- Keep the actual networked model consistent as well as the modifier.
    local desiredModel = carrierHidden and carrierModel or model
    if hero:GetModelName() ~= desiredModel then
        hero:SetOriginalModel(desiredModel)
        hero:SetModel(desiredModel)
    end
    if st.kart_visual_carrier_hidden ~= carrierHidden then hero:SetRenderAlpha(255) end
    st.kart_visual_carrier_hidden = carrierHidden
    if imprisoned then hero:AddNoDraw() else hero:RemoveNoDraw() end
end
