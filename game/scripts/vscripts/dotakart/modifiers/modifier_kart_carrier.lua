-- Hide opaque duplicate meshes without disabling the NPC render entity.
modifier_dotakart_kart_carrier = class({})
function modifier_dotakart_kart_carrier:IsHidden() return true end
function modifier_dotakart_kart_carrier:IsPurgable() return false end
function modifier_dotakart_kart_carrier:RemoveOnDeath() return false end
function modifier_dotakart_kart_carrier:AllowIllusionDuplicate() return false end
function modifier_dotakart_kart_carrier:DeclareFunctions()
    return { MODIFIER_PROPERTY_MODEL_CHANGE }
end
function modifier_dotakart_kart_carrier:GetModifierModelChange()
    return "models/development/invisiblebox.vmdl"
end
