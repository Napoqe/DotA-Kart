-- Decoy overhead only: preserve its existing movement, targeting and lifetime.
modifier_dotakart_doppelwalk_decoy = class({})
function modifier_dotakart_doppelwalk_decoy:IsHidden() return true end
function modifier_dotakart_doppelwalk_decoy:IsPurgable() return false end
function modifier_dotakart_doppelwalk_decoy:CheckState()
    return { [MODIFIER_STATE_NO_HEALTH_BAR] = true }
end
