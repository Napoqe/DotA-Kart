-- Client-local music modes: 0 off, 1 DotA Kart, 2 native Dota. -1 is first run.
modifier_dotakart_audio_preferences=class({})
function modifier_dotakart_audio_preferences:IsHidden() return true end
function modifier_dotakart_audio_preferences:IsPurgable() return false end
function modifier_dotakart_audio_preferences:RemoveOnDeath() return false end
function modifier_dotakart_audio_preferences:GetTexture()
    -- Panorama cannot read VScript-created string ConVars through GetConvarInt.
    -- This hidden modifier exposes only the local controller's applied state.
    if IsServer() or not self.isAudioController then return 'dotakart_audio_wait' end
    return 'dotakart_audio_v3_'..tostring(Convars:GetInt('dotakart_music_mode_v2')+1)..'_'..tostring(Convars:GetInt('dotakart_music_applied_mode_v2')+1)
end
function modifier_dotakart_audio_preferences:CheckState()
    if self:GetParent():GetUnitName()~='npc_dotakart_audio_controller' then return {} end
    return {[MODIFIER_STATE_INVULNERABLE]=true,[MODIFIER_STATE_UNSELECTABLE]=true,
        [MODIFIER_STATE_NO_UNIT_COLLISION]=true,[MODIFIER_STATE_NO_HEALTH_BAR]=true,
        [MODIFIER_STATE_NOT_ON_MINIMAP]=true}
end

local MODE='dotakart_music_mode_v2'
local READY='dotakart_music_pref_ready_v2'
local APPLIED='dotakart_music_applied_mode_v2'
local ORIGINAL='dotakart_music_original_native_volume_v2'
local OWNED='dotakart_music_native_volume_owned_v2'
local function register(name,value,flags)
    local current=Convars:GetStr(name)
    if current==nil or current=='' then Convars:RegisterConvar(name,tostring(value),'DotA Kart local audio',flags or 0) end
end
local function validMode(value)
    value=tonumber(value)
    return value==0 or value==1 or value==2
end

function modifier_dotakart_audio_preferences:RestoreNativeVolume()
    if not self.overrideHeld then return end
    Convars:SetFloat('snd_musicvolume',self.nativeVolume)
    Convars:SetInt(OWNED,0)
    self.overrideHeld=false
end

function modifier_dotakart_audio_preferences:ApplyMusicMode()
    if (self.pendingConfigTicks or 0)>0 then return end
    local mode=Convars:GetInt(MODE)
    if mode==2 then
        self:RestoreNativeVolume()
        Convars:SetInt(APPLIED,2)
        return
    end
    -- Mute the native score before acknowledging custom playback to Panorama.
    local volume=Convars:GetFloat('snd_musicvolume')
    if not self.overrideHeld or volume>0.00001 then
        self.nativeVolume=math.max(0,math.min(1,volume))
        Convars:SetFloat(ORIGINAL,self.nativeVolume)
    end
    self.overrideHeld=true
    Convars:SetInt(OWNED,1)
    Convars:SetFloat('snd_musicvolume',0)
    if Convars:GetFloat('snd_musicvolume')<=0.00001 then Convars:SetInt(APPLIED,mode==0 and 0 or 1) end
end

function modifier_dotakart_audio_preferences:SaveMusicMode(mode)
    if not validMode(mode) then return end
    -- Save with the original native volume, never with the temporary mute.
    Convars:SetInt(APPLIED,-1)
    self:RestoreNativeVolume()
    Convars:SetInt(MODE,mode)
    if SendToConsole then SendToConsole('host_writeconfig') end
    -- SendToConsole queues commands for a later engine frame. Keep the original
    -- volume until that config write has run; Panorama waits for APPLIED meanwhile.
    self.pendingConfigTicks=2
end

function modifier_dotakart_audio_preferences:OnCreated(params)
    if IsServer() then
        local id=tonumber(params and params.player_id) or self:GetParent():GetPlayerOwnerID()
        if id and id>=0 then self:SetStackCount(id+1) end
        return
    end
    -- Player ownership / stack replication can arrive after OnCreated.
    self:StartIntervalThink(.05)
    self:TryInitialize()
end

function modifier_dotakart_audio_preferences:TryInitialize()
    if self.isAudioController then return end
    if not GetLocalPlayerID then return end
    local id=self:GetStackCount()%16-1
    if id<0 then id=self:GetParent():GetPlayerOwnerID() end
    if id~=GetLocalPlayerID() then return end
    DotaKartLocalAudioCandidates=DotaKartLocalAudioCandidates or {}
    DotaKartLocalAudioCandidates[self]=true
    if DotaKartLocalAudioPreferencesVersion==2 then
        -- FIX130: the global guard could outlive its controller (map restart/reload without
        -- OnDestroy). Then no instance muted the native/music-pack score and Panorama never
        -- became ready, so Dota music played even with "DotA Kart" selected. Only defer to a
        -- controller that still exists; otherwise take over.
        local current=DotaKartLocalAudioController
        local alive=false
        if current~=nil and current~=self then
            pcall(function()
                local parent=current:GetParent()
                alive=current.isAudioController==true and parent~=nil and not parent:IsNull()
            end)
        end
        if alive then return end
        print('[DotA Kart Music] stale local controller replaced')
    end
    if not Convars or not Convars.RegisterConvar then return end
    local archive=FCVAR_ARCHIVE or 128
    local legacy=tonumber(Convars:GetStr('dotakart_music_enabled_v1'))
    register(MODE,(legacy==0 or legacy==1) and legacy or -1,archive)
    register(ORIGINAL,Convars:GetFloat('snd_musicvolume'),archive)
    register(OWNED,0,archive)
    register(READY,0,0);register(APPLIED,-1,0)
    -- Recover a stale mute if the previous process ended without cleanup.
    if Convars:GetInt(OWNED)==1 and Convars:GetFloat('snd_musicvolume')<=0.00001 then
        Convars:SetFloat('snd_musicvolume',Convars:GetFloat(ORIGINAL))
    end
    self.nativeVolume=Convars:GetFloat('snd_musicvolume')
    self.isAudioController=true
    -- Requests arrive through the standard custom-game event channel and a
    -- replicated modifier stack; arbitrary native client events are not loaded.
    self.lastRequest=-1
    self:ApplyMusicMode()
    Convars:SetInt(READY,1)
    DotaKartLocalAudioPreferencesVersion=2
    DotaKartLocalAudioController=self
    print('[DotA Kart Music] local controller ready, player '..tostring(id))
end

function modifier_dotakart_audio_preferences:OnIntervalThink()
    if IsServer() then return end
    if not self.isAudioController then self:TryInitialize();return end
    local requested=math.floor(self:GetStackCount()/16)%4-1
    if validMode(requested) and requested~=self.lastRequest then
        self.lastRequest=requested
        if Convars:GetInt(MODE)~=requested then self:SaveMusicMode(requested) end
    end
    if (self.pendingConfigTicks or 0)>0 then
        self.pendingConfigTicks=self.pendingConfigTicks-1
        if self.pendingConfigTicks>0 then return end
    end
    self:ApplyMusicMode()
end

function modifier_dotakart_audio_preferences:OnDestroy()
    if IsServer() then return end
    if DotaKartLocalAudioCandidates then DotaKartLocalAudioCandidates[self]=nil end
    if not self.isAudioController then return end
    -- FIX131: if the local hero (or controller unit) still has this modifier, hand control
    -- over without restoring the native score in between.
    for other in pairs(DotaKartLocalAudioCandidates or {}) do
        local valid=false
        pcall(function() local p=other:GetParent(); valid=p~=nil and not p:IsNull() end)
        if valid and other~=self then
            other.nativeVolume=self.nativeVolume
            other.overrideHeld=self.overrideHeld
            other.lastRequest=self.lastRequest
            other.isAudioController=true
            DotaKartLocalAudioController=other
            DotaKartLocalAudioPreferencesVersion=2
            self.isAudioController=false
            other:ApplyMusicMode()
            print('[DotA Kart Music] local controller handed over')
            return
        end
    end
    print('[DotA Kart Music] local controller destroyed; native music restored')
    self:RestoreNativeVolume()
    Convars:SetInt(READY,0);Convars:SetInt(APPLIED,-1)
    DotaKartLocalAudioPreferencesVersion=nil
    if DotaKartLocalAudioController==self then DotaKartLocalAudioController=nil end
    if SendToConsole then SendToConsole('host_writeconfig') end
end
