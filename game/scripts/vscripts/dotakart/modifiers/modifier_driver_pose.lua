-- Loaded directly by LinkLuaModifier in both server and rendering-client scopes.
modifier_dotakart_driver_pose = class({})
print("[KART_ANIM_QA] modifier script loaded: " .. (IsServer() and "server" or "client"))
function modifier_dotakart_driver_pose:OnCreated()
    print("[KART_ANIM_QA] modifier created: " .. (IsServer() and "server" or "client")
        .. " " .. self:GetParent():GetUnitName())
    print("[KART_ANIM_QA] enums idle=" .. tostring(ACT_DOTA_IDLE) .. " run=" .. tostring(ACT_DOTA_RUN))
end
function modifier_dotakart_driver_pose:IsHidden() return true end
function modifier_dotakart_driver_pose:IsPurgable() return false end
function modifier_dotakart_driver_pose:RemoveOnDeath() return false end
function modifier_dotakart_driver_pose:DeclareFunctions()
    local properties = { MODIFIER_PROPERTY_OVERRIDE_ANIMATION, MODIFIER_PROPERTY_OVERRIDE_ANIMATION_RATE }
    if MODIFIER_PROPERTY_OVERRIDE_ANIMATION_WEIGHT then properties[#properties + 1] = MODIFIER_PROPERTY_OVERRIDE_ANIMATION_WEIGHT end
    return properties
end
function modifier_dotakart_driver_pose:GetOverrideAnimationWeight() return 1 end
function modifier_dotakart_driver_pose:GetOverrideAnimation()
    local activities = { ACT_DOTA_IDLE, ACT_DOTA_CAST_ABILITY_1, ACT_DOTA_CAST_ABILITY_2,
        ACT_DOTA_RUN, ACT_DOTA_CAST_ABILITY_3, ACT_DOTA_CAST_ABILITY_4,
        ACT_DOTA_ATTACK, ACT_DOTA_CAST_ABILITY_5, ACT_DOTA_CAST_ABILITY_6 }
    return activities[self:GetStackCount() % 16] or ACT_DOTA_IDLE
end
function modifier_dotakart_driver_pose:GetOverrideAnimationRate()
    return math.max(0.1, math.floor(self:GetStackCount() / 16) / 20)
end

