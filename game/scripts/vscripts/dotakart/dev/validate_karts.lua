-- Server diagnostics only: these checks do not certify the rendered bone pose.
local ctrl = GameRules.DotaKartController
assert(IsInToolsMode() and ctrl, "Tools game required")
local owned = {}
for _, st in pairs(ctrl.states) do
    local visual = st.kart_visual_entity
    if visual and not visual:IsNull() then owned[visual:entindex()] = true end
end
local count, orphaned = 0, 0
local prop = Entities:FindByClassname(nil, "prop_dynamic")
while prop do
    if string.find(prop:GetName() or "", "dk_kart_animation_", 1, true) == 1 then
        count = count + 1
        if not owned[prop:entindex()] then
            orphaned = orphaned + 1
            print("[KART_SERVER_QA] unowned visual entity=" .. tostring(prop:entindex()))
        end
    end
    prop = Entities:FindByClassname(prop, "prop_dynamic")
end
print(string.format("[KART_SERVER_QA] visual count=%d unowned=%d", count, orphaned))
for playerID = 0, 7 do
    local hero = ctrl:GetHeroForPlayer(playerID)
    if hero and not hero:IsNull() then
        local expected = ctrl.kart_models[hero:GetUnitName()]
        local sequence = hero:GetSequence()
        local st = ctrl:GetState(playerID)
        local visual = st.kart_visual_entity
        local renderedModel = visual and not visual:IsNull() and visual:GetModelName() or hero:GetModelName()
        local pass = expected == renderedModel and math.abs(hero:GetModelScale() - 1.2) < .01
            and hero:HasModifier("modifier_dotakart_kart_visual")
        print(string.format("[KART_SERVER_QA] %s player=%d entity=%d model=%s sequence=%s cycle=%.3f",
            pass and "PASS" or "FAIL", playerID, hero:entindex(), renderedModel, sequence, hero:GetCycle()))
        print(string.format("[KART_SERVER_QA] carrier player=%d overridden=%s model=%s", playerID,
            tostring(hero:HasModifier("modifier_dotakart_kart_carrier")), hero:GetModelName()))
        local pos = hero:GetAbsOrigin()
        if visual and not visual:IsNull() then
            print(string.format("[KART_SERVER_QA] render player=%d version=%s sequence=%s cycle=%.3f hidden=%s", playerID,
                tostring(st.kart_visual_version), tostring(visual:GetSequence()), visual:GetCycle(), tostring(st.kart_visual_hidden)))
            local vpos = visual:GetAbsOrigin()
            print(string.format("[KART_SERVER_QA] visual player=%d entity=%d model=%s hidden=%s delta=%.2f hero_pos=(%.0f,%.0f,%.0f) visual_pos=(%.0f,%.0f,%.0f)",
                playerID, visual:entindex(), visual:GetModelName(), tostring(st.kart_visual_hidden), (vpos-pos):Length(),
                pos.x,pos.y,pos.z,vpos.x,vpos.y,vpos.z))
        else
            print("[KART_SERVER_QA] missing visual player=" .. tostring(playerID))
        end
    end
end
print("[KART_SERVER_QA] Check wheel movement and seated pose visually in Dota; server sequences alone are insufficient.")
print(string.format("[KART_SERVER_QA] visual count=%d unowned=%d", count, orphaned))
