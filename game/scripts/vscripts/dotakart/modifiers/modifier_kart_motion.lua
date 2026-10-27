-- Loaded directly by LinkLuaModifier in both server and rendering-client scopes.
modifier_dotakart_kart_motion = class({})
print("[KART_ANIM_QA] modifier script loaded: " .. (IsServer() and "server" or "client"))
function modifier_dotakart_kart_motion:OnCreated(keys)
    self.initial_stack = tonumber(keys and keys.stack_count) or 0
    print("[KART_ANIM_QA] modifier created: " .. (IsServer() and "server" or "client")
        .. " " .. self:GetParent():GetUnitName())
    print("[KART_ANIM_QA] enums idle=" .. tostring(ACT_DOTA_IDLE) .. " run=" .. tostring(ACT_DOTA_RUN))
end
function modifier_dotakart_kart_motion:IsHidden() return true end
function modifier_dotakart_kart_motion:IsPurgable() return false end
function modifier_dotakart_kart_motion:RemoveOnDeath() return false end
function modifier_dotakart_kart_motion:DeclareFunctions()
    local properties = { MODIFIER_PROPERTY_OVERRIDE_ANIMATION, MODIFIER_PROPERTY_OVERRIDE_ANIMATION_RATE }
    if MODIFIER_PROPERTY_OVERRIDE_ANIMATION_WEIGHT then properties[#properties + 1] = MODIFIER_PROPERTY_OVERRIDE_ANIMATION_WEIGHT end
    return properties
end
function modifier_dotakart_kart_motion:GetOverrideAnimationWeight() return 1 end
function modifier_dotakart_kart_motion:GetOverrideAnimation()
    local encoded = self:GetStackCount()
    if encoded == 0 then encoded = self.initial_stack or 0 end
    if not self.logged_override then
        print("[KART_ANIM_QA] override " .. (IsServer() and "server" or "client") .. " stack=" .. encoded)
        self.logged_override = true
    end
    return encoded % 4096
end
function modifier_dotakart_kart_motion:GetOverrideAnimationRate()
    local encoded = self:GetStackCount()
    if encoded == 0 then encoded = self.initial_stack or 0 end
    return math.max(0.1, math.floor(encoded / 4096) / 20)
end


