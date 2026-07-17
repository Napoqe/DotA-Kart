-- DotA Kart - camera_server.lua
-- Sistema de camera estilo Mario Kart 64 para Dota 2 Custom Game.
-- FIX25: adiciona presets de camera profunda e mantém yaw_offset 270.
-- Importante: editar apenas o JS pode ser sobrescrito por este arquivo via GameEvent.

if DotaKartCamera == nil then
    DotaKartCamera = class({})
end

function DotaKartCamera:Init()
    if self.initialized then return end
    self.initialized = true

    self.enabled = true
    self.heroes = {}

    self.config = {
        enabled = true,
        debug = false,

        -- Ajustes principais estilo MK64.
        distance = 720,
        pitch = 36,
        height_offset = 115,
        look_ahead = 240,

        -- FIX10:
        -- 180 geralmente coloca a camera ATRAS da direcao de movimento.
        -- Se no seu mapa/modelo ficar invertido, use dk_camera_yaw_0/90/180/270.
        yaw_offset = 270,

        -- movement = recomendado para kart;
        -- forward = frente do modelo;
        -- auto = movement quando move, fallback forward parado.
        direction_mode = "movement",

        yaw_smooth = 0.20,
        position_smooth = 0.25,
        update_rate = 0.03,
        force_target_lock = true,
        min_move_for_yaw = 2.5,
        model_forward_offset = 0
    }

    Convars:RegisterCommand("dk_camera_on", function()
        self:SetEnabledAll(true)
    end, "DotA Kart: liga camera MK64", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_camera_off", function()
        self:SetEnabledAll(false)
    end, "DotA Kart: desliga camera MK64", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_camera_reset", function()
        self:ApplyToAllPlayers(true)
    end, "DotA Kart: reaplica config da camera MK64", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_camera_mk64", function()
        self:SetPresetMK64()
        self:ApplyToAllPlayers(true)
    end, "DotA Kart: preset camera Mario Kart 64", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_camera_low", function()
        self:SetPresetLow()
        self:ApplyToAllPlayers(true)
    end, "DotA Kart: preset camera mais baixa/proxima", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_camera_far", function()
        self:SetPresetFar()
        self:ApplyToAllPlayers(true)
    end, "DotA Kart: preset camera mais distante", FCVAR_CHEAT)


    Convars:RegisterCommand("dk_camera_deep", function()
        self:SetPresetDeep()
        self:ApplyToAllPlayers(true)
    end, "DotA Kart: camera mais alta/longe para enxergar mais pista", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_camera_extreme", function()
        self:SetPresetExtreme()
        self:ApplyToAllPlayers(true)
    end, "DotA Kart: camera extrema; pode revelar limite de render do Dota", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_camera_debug", function()
        self.config.debug = not self.config.debug
        print("[DotaKartCamera] debug = " .. tostring(self.config.debug))
        self:ApplyToAllPlayers(true)
    end, "DotA Kart: alterna debug da camera", FCVAR_CHEAT)

    -- Offsets rapidos. Use estes em vez de editar somente o JS.
    Convars:RegisterCommand("dk_camera_yaw_0", function()
        self:SetYawOffset(0)
    end, "DotA Kart: camera yaw offset 0", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_camera_yaw_90", function()
        self:SetYawOffset(90)
    end, "DotA Kart: camera yaw offset 90", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_camera_yaw_180", function()
        self:SetYawOffset(180)
    end, "DotA Kart: camera yaw offset 180", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_camera_yaw_270", function()
        self:SetYawOffset(270)
    end, "DotA Kart: camera yaw offset 270/-90", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_camera_mode_movement", function()
        self:SetDirectionMode("movement")
    end, "DotA Kart: camera usa direcao de movimento", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_camera_mode_forward", function()
        self:SetDirectionMode("forward")
    end, "DotA Kart: camera usa frente do modelo", FCVAR_CHEAT)

    Convars:RegisterCommand("dk_camera_mode_auto", function()
        self:SetDirectionMode("auto")
    end, "DotA Kart: camera usa movimento + fallback forward", FCVAR_CHEAT)

    print("[DotaKartCamera] Helper iniciado FIX13 yaw_offset=270")
end

function DotaKartCamera:SetPresetMK64()
    self.config.distance = 720
    self.config.pitch = 36
    self.config.height_offset = 115
    self.config.look_ahead = 240
    self.config.yaw_offset = 270
    self.config.direction_mode = "movement"
    self.config.yaw_smooth = 0.20
    self.config.position_smooth = 0.25
    self.config.update_rate = 0.03
    self.config.force_target_lock = true
    self.config.min_move_for_yaw = 2.5
    self.config.model_forward_offset = 0
end

function DotaKartCamera:SetPresetLow()
    self.config.distance = 560
    self.config.pitch = 32
    self.config.height_offset = 90
    self.config.look_ahead = 260
    self.config.yaw_offset = 270
    self.config.direction_mode = "movement"
    self.config.yaw_smooth = 0.22
    self.config.position_smooth = 0.26
    self.config.update_rate = 0.03
    self.config.force_target_lock = true
    self.config.min_move_for_yaw = 2.5
    self.config.model_forward_offset = 0
end

function DotaKartCamera:SetPresetFar()
    self.config.distance = 900
    self.config.pitch = 42
    self.config.height_offset = 140
    self.config.look_ahead = 220
    self.config.yaw_offset = 270
    self.config.direction_mode = "movement"
    self.config.yaw_smooth = 0.16
    self.config.position_smooth = 0.20
    self.config.update_rate = 0.03
    self.config.force_target_lock = true
    self.config.min_move_for_yaw = 2.5
    self.config.model_forward_offset = 0
end


function DotaKartCamera:SetPresetDeep()
    -- FIX25: melhor tentativa de câmera com mais leitura de pista.
    -- Limite real de render/culling ainda é do Dota 2/Source 2.
    self.config.distance = 1180
    self.config.pitch = 50
    self.config.height_offset = 185
    self.config.look_ahead = 520
    self.config.yaw_offset = 270
    self.config.direction_mode = "movement"
    self.config.yaw_smooth = 0.14
    self.config.position_smooth = 0.18
    self.config.update_rate = 0.03
    self.config.force_target_lock = true
    self.config.min_move_for_yaw = 2.5
    self.config.model_forward_offset = 0
end

function DotaKartCamera:SetPresetExtreme()
    -- Pode ficar menos MK64, mas ajuda a testar até onde o Dota renderiza.
    self.config.distance = 1450
    self.config.pitch = 58
    self.config.height_offset = 260
    self.config.look_ahead = 760
    self.config.yaw_offset = 270
    self.config.direction_mode = "movement"
    self.config.yaw_smooth = 0.12
    self.config.position_smooth = 0.16
    self.config.update_rate = 0.03
    self.config.force_target_lock = true
    self.config.min_move_for_yaw = 2.5
    self.config.model_forward_offset = 0
end

function DotaKartCamera:NormalizeYaw(yaw)
    yaw = tonumber(yaw) or 0
    yaw = yaw % 360
    if yaw > 180 then yaw = yaw - 360 end
    if yaw < -180 then yaw = yaw + 360 end
    return yaw
end

function DotaKartCamera:SetYawOffset(yaw)
    self.config.yaw_offset = self:NormalizeYaw(yaw)
    print("[DotaKartCamera] yaw_offset = " .. tostring(self.config.yaw_offset))
    self:ApplyToAllPlayers(true)
end

function DotaKartCamera:SetDirectionMode(mode)
    if mode ~= "movement" and mode ~= "forward" and mode ~= "auto" then
        mode = "movement"
    end

    self.config.direction_mode = mode
    print("[DotaKartCamera] direction_mode = " .. tostring(mode))
    self:ApplyToAllPlayers(true)
end

function DotaKartCamera:CloneConfig()
    local t = {}
    for k, v in pairs(self.config) do
        t[k] = v
    end
    t.enabled = self.enabled
    return t
end

function DotaKartCamera:GetHeroForPlayer(playerID)
    if self.heroes[playerID] ~= nil and not self.heroes[playerID]:IsNull() then
        return self.heroes[playerID]
    end

    local hero = PlayerResource:GetSelectedHeroEntity(playerID)
    if hero ~= nil and not hero:IsNull() then
        self.heroes[playerID] = hero
        return hero
    end

    return nil
end

function DotaKartCamera:RegisterHero(playerID, hero)
    if playerID == nil or playerID < 0 then return end
    if hero == nil or hero:IsNull() then return end

    self.heroes[playerID] = hero

    if self.enabled then
        self:ApplyToPlayer(playerID, true)
    end

    print("[DotaKartCamera] Hero/Kart registrado para camera: player " .. tostring(playerID) .. " = " .. tostring(hero:GetUnitName()))
end

function DotaKartCamera:SendConfigToPlayer(playerID)
    local player = PlayerResource:GetPlayer(playerID)
    if player == nil then return end

    CustomGameEventManager:Send_ServerToPlayer(player, "dotakart_camera_config", self:CloneConfig())
end

function DotaKartCamera:ApplyToPlayer(playerID, force)
    if not PlayerResource:IsValidPlayerID(playerID) then return end

    local hero = self:GetHeroForPlayer(playerID)
    local player = PlayerResource:GetPlayer(playerID)
    if player == nil then return end

    if self.enabled and hero ~= nil and not hero:IsNull() then
        -- Prende a camera no kart pelo servidor.
        -- O Panorama controla distancia, pitch, yaw e look-ahead.
        PlayerResource:SetCameraTarget(playerID, hero)
        self:SendConfigToPlayer(playerID)

        if force or self.config.debug then
            print("[DotaKartCamera] Camera aplicada ao player " .. tostring(playerID) ..
                  " yaw_offset=" .. tostring(self.config.yaw_offset) ..
                  " mode=" .. tostring(self.config.direction_mode))
        end
    else
        PlayerResource:SetCameraTarget(playerID, nil)
        CustomGameEventManager:Send_ServerToPlayer(player, "dotakart_camera_disable", {})

        if force or self.config.debug then
            print("[DotaKartCamera] Camera removida do player " .. tostring(playerID))
        end
    end
end

function DotaKartCamera:ApplyToAllPlayers(force)
    for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(playerID) then
            self:ApplyToPlayer(playerID, force)
        end
    end
end

function DotaKartCamera:SetEnabledAll(enabled)
    self.enabled = enabled == true
    self.config.enabled = self.enabled

    print("[DotaKartCamera] enabled = " .. tostring(self.enabled))
    self:ApplyToAllPlayers(true)
end

function DotaKartCamera:ThinkApplyToExistingHeroes()
    for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(playerID) then
            local hero = PlayerResource:GetSelectedHeroEntity(playerID)
            if hero ~= nil and not hero:IsNull() then
                self:RegisterHero(playerID, hero)
            end
        end
    end
end
