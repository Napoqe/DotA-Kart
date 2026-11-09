-- Make client-local archived preferences available during GameSetup, before heroes.
local M={}
function M:Init()
    self.units=self.units or {}
    if not self.listener then
        self.listener=CustomGameEventManager:RegisterListener('dotakart_music_mode_request',function(source,keys)
            local player=EntIndexToHScript(source)
            local id=player and player.GetPlayerID and player:GetPlayerID()
            local mode=tonumber(keys and keys.mode)
            if not id or id<0 or id>7 or (mode~=0 and mode~=1 and mode~=2) then return end
            -- Only the sending client's controller receives the requested mode.
            local unit=self.units[id]
            local hero=PlayerResource:GetSelectedHeroEntity(id)
            for _,entity in pairs({unit,hero}) do
                if entity and not entity:IsNull() then
                    local modifier=entity:FindModifierByName('modifier_dotakart_audio_preferences')
                    if modifier then modifier:SetStackCount(id+1+(mode+1)*16) end
                end
            end
        end)
    end
    GameRules:GetGameModeEntity():SetContextThink('DotaKartAudioPreferenceBootstrap',function()
        if not PlayerResource or GameRules:State_Get()<(DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP or 2) then return 1 end
        for id=0,7 do
            local player=PlayerResource:GetPlayer(id)
            if player and not (PlayerResource.IsFakeClient and PlayerResource:IsFakeClient(id))
                and (self.units[id]==nil or self.units[id]:IsNull()) then
                local team=PlayerResource:GetTeam(id)
                if not team or team<=1 then team=DOTA_TEAM_NEUTRALS or 4 end
                local unit=CreateUnitByName('npc_dotakart_audio_controller',Vector(0,0,0),false,player,player,team)
                if unit then
                    unit:SetOwner(player)
                    unit:SetControllableByPlayer(id,true)
                    unit:AddNoDraw()
                    if unit.SetHullRadius then unit:SetHullRadius(0) end
                    if unit.SetAttackCapability then unit:SetAttackCapability(DOTA_UNIT_CAP_NO_ATTACK or 0) end
                    -- Thinkers do not acquire a player ID from SetOwner. Replicate
                    -- the local audio owner explicitly through the modifier stack.
                    -- FIX134: the level-1 hidden ability makes the client load the modifier binding.
                    local link=unit:FindAbilityByName('dotakart_audio_link')
                    if link then link:SetLevel(1) else print('[DotA Kart Music] dotakart_audio_link missing on controller p'..tostring(id)) end
                    unit:AddNewModifier(unit,nil,'modifier_dotakart_audio_preferences',{player_id=id})
                    self.units[id]=unit
                end
            end
            if player and self.units[id] and not self.units[id]:IsNull() then
                -- FIX131: keep the controller on the racer's real team. It was created during
                -- GameSetup (team often unassigned -> neutrals), so later the client could stop
                -- receiving it in fog; its client modifier was destroyed and the native Dota /
                -- music-pack score was restored while "DotA Kart" music was selected.
                local currentTeam=PlayerResource:GetTeam(id)
                if currentTeam and currentTeam>1 and currentTeam~=(DOTA_TEAM_NEUTRALS or 4) and self.units[id]:GetTeamNumber()~=currentTeam then
                    self.units[id]:SetTeam(currentTeam)
                    print('[DotA Kart Music] audio controller p'..tostring(id)..' team -> '..tostring(currentTeam))
                end
                -- Keep the networked audio controller in the racer's client PVS.
                local hero=PlayerResource:GetSelectedHeroEntity(id)
                if hero and not hero:IsNull() then self.units[id]:SetAbsOrigin(hero:GetAbsOrigin()) end
                CustomGameEventManager:Send_ServerToPlayer(player,'dotakart_audio_controller',{player_id=id,entity_index=self.units[id]:entindex()})
            end
        end
        return 1
    end,1)
end
return M
