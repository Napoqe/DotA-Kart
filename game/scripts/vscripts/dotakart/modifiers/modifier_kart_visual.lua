-- Loaded directly by LinkLuaModifier in both server and rendering-client scopes.
modifier_dotakart_kart_visual = class({})
function modifier_dotakart_kart_visual:OnCreated(keys)
    self.initial_stack = tonumber(keys and keys.stack_count) or 0
end
function modifier_dotakart_kart_visual:IsHidden() return true end
function modifier_dotakart_kart_visual:IsPurgable() return false end
function modifier_dotakart_kart_visual:RemoveOnDeath() return false end
function modifier_dotakart_kart_visual:CheckState()
    return { [MODIFIER_STATE_NO_HEALTH_BAR] = true }
end
function modifier_dotakart_kart_visual:DeclareFunctions()
    local properties = { MODIFIER_PROPERTY_OVERRIDE_ANIMATION, MODIFIER_PROPERTY_OVERRIDE_ANIMATION_RATE }
    if MODIFIER_PROPERTY_OVERRIDE_ANIMATION_WEIGHT then properties[#properties + 1] = MODIFIER_PROPERTY_OVERRIDE_ANIMATION_WEIGHT end
    return properties
end
function modifier_dotakart_kart_visual:GetOverrideAnimationWeight() return 1 end
function modifier_dotakart_kart_visual:GetOverrideAnimation()
    local encoded = self:GetStackCount()
    if encoded == 0 then encoded = self.initial_stack or 0 end
    return encoded % 4096
end
function modifier_dotakart_kart_visual:GetOverrideAnimationRate()
    local encoded = self:GetStackCount()
    if encoded == 0 then encoded = self.initial_stack or 0 end
    return math.max(0.1, math.floor(encoded / 4096) / 20)
end




