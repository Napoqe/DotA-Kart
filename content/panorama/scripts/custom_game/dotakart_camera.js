(function () {
    "use strict";

    /*
        DotA Kart - camera MK64 FIX51
        ----------------------------------------------------
        FIX10: a camera agora usa DIRECAO DE MOVIMENTO primeiro.

        Motivo: em Dota 2 muitos heroes/modelos/montarias nao entregam um
        forward confiavel para camera de corrida. Antes o script usava
        Entities.GetForward() como fonte principal, entao yaw_offset parecia
        nao resolver porque a camera seguia a orientacao errada do modelo.

        Agora:
        1) usa deslocamento real do Hero/Kart para descobrir a direcao da pista;
        2) usa forward do heroi apenas como fallback;
        3) yaw_offset vem do camera_server.lua por GameEvent, entao editar so
           o JS pode ser sobrescrito pelo servidor. Use os comandos dk_camera_yaw_*.
    */

    var CAMERA_ENABLED = true;
    var DEBUG_CAMERA = false;

    var CFG = {
        distance: 720,
        pitch: 32,
        height_offset: 135,
        look_ahead: 240,

        // IMPORTANTE:
        // Este offset e aplicado na direcao de camera.
        // 180 geralmente coloca a camera atras da direcao de movimento.
        // Se ficar de frente/diagonal, teste os comandos dk_camera_yaw_0/90/180/270.
        yaw_offset: 270,

        // movement = melhor para kart; forward = usa frente do modelo; auto = tenta movement e fallback forward.
        direction_mode: "movement",

        yaw_smooth: 0.20,
        position_smooth: 0.25,
        update_rate: 0.03,
        force_target_lock: true,

        // Movimento minimo em unidades por tick para atualizar direcao.
        min_move_for_yaw: 2.5,

        // Offset separado caso o MODELO do heroi esteja virado 90/180 graus errado.
        // Normalmente deixe 0, porque usamos movement como principal.
        model_forward_offset: 0
    };

    var smoothedYaw = null;
    var smoothedLookAt = null;
    var lastPos = null;
    var lastHero = -1;
    var lastDriveYaw = null;
    var appliedStaticSettings = false;
    var debugTimer = 0;

    // FIX51: segurar R ativa visão traseira/rear view para mirar itens defensivos.
    var LOOK_BACK = false;
    var LOOK_BACK_RUN_ID = String((new Date()).getTime() % 1000000000) + "_" + String(Math.floor(Math.random() * 1000000));
    var LOOK_BACK_CMD = "dotakart51_" + LOOK_BACK_RUN_ID + "_look_back";

    // FIX108: dotakart_input.js owns the final R bind (R+T is also used by Spectral Dagger).
    // Export the already-existing rear-view state so one R press can drive BOTH systems
    // instead of the two Panorama scripts overwriting each other's keybind.
    GameUI.SetDotaKartRearView = function (enabled) {
        LOOK_BACK = !!enabled;
    };

    function Msg(text) {
        $.Msg("[DotA Kart Camera] " + text);
    }

    function IsFunction(owner, name) {
        return owner && typeof owner[name] === "function";
    }

    function ToNumber(value, fallback) {
        var n = Number(value);
        return isNaN(n) ? fallback : n;
    }

    function Clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value));
    }

    function DegToRad(deg) {
        return deg * Math.PI / 180.0;
    }

    function RadToDeg(rad) {
        return rad * 180.0 / Math.PI;
    }

    function NormalizeAngle(deg) {
        deg = deg % 360;
        if (deg > 180) deg -= 360;
        if (deg < -180) deg += 360;
        return deg;
    }

    function SmoothAngle(current, target, amount) {
        if (current === null || current === undefined) return NormalizeAngle(target);
        var delta = NormalizeAngle(target - current);
        return NormalizeAngle(current + delta * Clamp(amount, 0.01, 1.0));
    }

    function Lerp(a, b, t) {
        return a + (b - a) * Clamp(t, 0.0, 1.0);
    }

    function LerpVec(a, b, t) {
        if (!a) return [b[0], b[1], b[2] || 0];
        return [
            Lerp(a[0], b[0], t),
            Lerp(a[1], b[1], t),
            Lerp(a[2] || 0, b[2] || 0, t)
        ];
    }

    function IsValidEntity(entindex) {
        if (entindex === null || entindex === undefined || entindex <= 0) return false;
        if (!Entities) return false;
        if (IsFunction(Entities, "IsValidEntity")) return Entities.IsValidEntity(entindex);
        return true;
    }

    function GetLocalHero() {
        if (!Players || !Entities) return -1;

        var playerID = Players.GetLocalPlayer();
        var hero = -1;

        if (IsFunction(Players, "GetPlayerHeroEntityIndex")) {
            hero = Players.GetPlayerHeroEntityIndex(playerID);
        }

        if (!IsValidEntity(hero) && IsFunction(Players, "GetLocalPlayerPortraitUnit")) {
            hero = Players.GetLocalPlayerPortraitUnit();
        }

        return IsValidEntity(hero) ? hero : -1;
    }

    function GetAbsOrigin(entindex) {
        if (!IsValidEntity(entindex)) return null;
        if (!IsFunction(Entities, "GetAbsOrigin")) return null;

        var p = Entities.GetAbsOrigin(entindex);
        if (!p || p.length < 2) return null;

        return [ToNumber(p[0], 0), ToNumber(p[1], 0), ToNumber(p[2], 0)];
    }

    function GetYawFromForward(entindex) {
        if (!IsValidEntity(entindex)) return null;

        if (IsFunction(Entities, "GetForward")) {
            var f = Entities.GetForward(entindex);
            if (f && f.length >= 2) {
                var fx = ToNumber(f[0], 0);
                var fy = ToNumber(f[1], 0);
                var len2 = fx * fx + fy * fy;
                if (len2 > 0.0001) {
                    return NormalizeAngle(RadToDeg(Math.atan2(fy, fx)) + ToNumber(CFG.model_forward_offset, 0));
                }
            }
        }

        if (IsFunction(Entities, "GetAbsRotation")) {
            var r = Entities.GetAbsRotation(entindex);
            if (r && r.length >= 3) {
                return NormalizeAngle(ToNumber(r[1], 0) + ToNumber(CFG.model_forward_offset, 0));
            }
        }

        return null;
    }

    function GetYawFromMovement(currentPos) {
        if (!lastPos || !currentPos) return null;

        var dx = currentPos[0] - lastPos[0];
        var dy = currentPos[1] - lastPos[1];
        var len2 = dx * dx + dy * dy;
        var minMove = ToNumber(CFG.min_move_for_yaw, 2.5);

        if (len2 < minMove * minMove) return null;
        return NormalizeAngle(RadToDeg(Math.atan2(dy, dx)));
    }

    function PickDriveYaw(hero, pos) {
        var moveYaw = GetYawFromMovement(pos);
        var forwardYaw = GetYawFromForward(hero);
        var mode = String(CFG.direction_mode || "movement").toLowerCase();

        if (mode === "forward") {
            if (forwardYaw !== null) return { yaw: forwardYaw, source: "forward", moveYaw: moveYaw, forwardYaw: forwardYaw };
            if (moveYaw !== null) return { yaw: moveYaw, source: "movement-fallback", moveYaw: moveYaw, forwardYaw: forwardYaw };
        } else if (mode === "auto") {
            if (moveYaw !== null) return { yaw: moveYaw, source: "movement", moveYaw: moveYaw, forwardYaw: forwardYaw };
            if (forwardYaw !== null) return { yaw: forwardYaw, source: "forward-fallback", moveYaw: moveYaw, forwardYaw: forwardYaw };
        } else {
            // movement padrao: nunca deixa o modelo/montaria virar a camera para o lado errado.
            if (moveYaw !== null) return { yaw: moveYaw, source: "movement", moveYaw: moveYaw, forwardYaw: forwardYaw };
            if (lastDriveYaw !== null) return { yaw: lastDriveYaw, source: "last-movement", moveYaw: moveYaw, forwardYaw: forwardYaw };
            if (forwardYaw !== null) return { yaw: forwardYaw, source: "forward-initial", moveYaw: moveYaw, forwardYaw: forwardYaw };
        }

        if (lastDriveYaw !== null) return { yaw: lastDriveYaw, source: "last", moveYaw: moveYaw, forwardYaw: forwardYaw };
        if (smoothedYaw !== null) return { yaw: smoothedYaw, source: "camera", moveYaw: moveYaw, forwardYaw: forwardYaw };
        return { yaw: 0, source: "zero", moveYaw: moveYaw, forwardYaw: forwardYaw };
    }

    function ApplyStaticCameraSettings(force) {
        if (!GameUI) return;
        if (!force && appliedStaticSettings) return;

        if (IsFunction(GameUI, "SetCameraDistance")) {
            GameUI.SetCameraDistance(ToNumber(CFG.distance, 720));
        }

        if (IsFunction(GameUI, "SetCameraPitchMin")) {
            GameUI.SetCameraPitchMin(ToNumber(CFG.pitch, 32));
        }

        if (IsFunction(GameUI, "SetCameraPitchMax")) {
            GameUI.SetCameraPitchMax(ToNumber(CFG.pitch, 32));
        }

        if (IsFunction(GameUI, "SetCameraLookAtPositionHeightOffset")) {
            GameUI.SetCameraLookAtPositionHeightOffset(ToNumber(CFG.height_offset, 135));
        }

        // Se existir, evita o terreno empurrar a camera para angulos estranhos.
        if (IsFunction(GameUI, "SetCameraTerrainAdjustmentEnabled")) {
            GameUI.SetCameraTerrainAdjustmentEnabled(false);
        }

        appliedStaticSettings = true;
    }

    function ApplyCameraTarget(hero, lookAtPos, yaw) {
        if (!GameUI) return;

        ApplyStaticCameraSettings(false);

        if (IsFunction(GameUI, "SetCameraYaw")) {
            GameUI.SetCameraYaw(yaw);
        }

        if (IsFunction(GameUI, "SetCameraTargetPosition")) {
            GameUI.SetCameraTargetPosition(lookAtPos, CFG.update_rate);
            return;
        }

        if (CFG.force_target_lock && IsFunction(GameUI, "SetCameraTarget")) {
            GameUI.SetCameraTarget(hero);
        }
    }

    function ResetRuntimeSmoothing() {
        smoothedYaw = null;
        smoothedLookAt = null;
        lastPos = null;
        lastHero = -1;
        lastDriveYaw = null;
        appliedStaticSettings = false;
        debugTimer = 0;
    }

    function DebugCamera(source, driveYaw, cameraYaw, moveYaw, forwardYaw) {
        if (!DEBUG_CAMERA) return;

        debugTimer += ToNumber(CFG.update_rate, 0.03);
        if (debugTimer < 1.0) return;
        debugTimer = 0;

        Msg("source=" + source +
            " driveYaw=" + Math.round(driveYaw) +
            " cameraYaw=" + Math.round(cameraYaw) +
            " offset=" + CFG.yaw_offset +
            " move=" + (moveYaw === null ? "null" : Math.round(moveYaw)) +
            " fwd=" + (forwardYaw === null ? "null" : Math.round(forwardYaw)) +
            " mode=" + CFG.direction_mode);
    }

    function UpdateCamera() {
        $.Schedule(CFG.update_rate, UpdateCamera);

        if (!CAMERA_ENABLED) return;

        var hero = GetLocalHero();
        if (!IsValidEntity(hero)) return;

        var pos = GetAbsOrigin(hero);
        if (!pos) return;

        if (hero !== lastHero) {
            ResetRuntimeSmoothing();
            lastHero = hero;
        }

        var pick = PickDriveYaw(hero, pos);
        var driveYaw = NormalizeAngle(pick.yaw);
        lastDriveYaw = driveYaw;

        // A camera fica atras quando cameraYaw olha a partir do lado oposto da direcao do kart.
        // FIX51: segurando R, vira 180° para mostrar o que está atrás do kart.
        var cameraYaw = NormalizeAngle(driveYaw + ToNumber(CFG.yaw_offset, 270) + (LOOK_BACK ? 180 : 0));
        smoothedYaw = SmoothAngle(smoothedYaw, cameraYaw, LOOK_BACK ? 0.55 : ToNumber(CFG.yaw_smooth, 0.20));

        // O alvo visual mira um pouco à frente; no modo rear-view mira atrás do kart.
        var driveRad = DegToRad(driveYaw);
        var lookAhead = ToNumber(CFG.look_ahead, 240);
        var lookSign = LOOK_BACK ? -1 : 1;
        var targetLookAt = [
            pos[0] + Math.cos(driveRad) * lookAhead * lookSign,
            pos[1] + Math.sin(driveRad) * lookAhead * lookSign,
            pos[2]
        ];

        smoothedLookAt = LerpVec(smoothedLookAt, targetLookAt, ToNumber(CFG.position_smooth, 0.25));
        ApplyCameraTarget(hero, smoothedLookAt, smoothedYaw);
        DebugCamera(pick.source, driveYaw, smoothedYaw, pick.moveYaw, pick.forwardYaw);

        lastPos = [pos[0], pos[1], pos[2]];
    }

    function SetEnabled(enabled) {
        CAMERA_ENABLED = !!enabled;

        if (CAMERA_ENABLED) {
            ApplyStaticCameraSettings(true);
            ResetRuntimeSmoothing();
            Msg("ligada");
        } else {
            ResetRuntimeSmoothing();
            Msg("desligada");

            if (GameUI && IsFunction(GameUI, "SetCameraTarget")) {
                GameUI.SetCameraTarget(-1);
            }
        }
    }

    function ApplyConfig(data) {
        data = data || {};

        if (data.enabled !== undefined) CAMERA_ENABLED = !!data.enabled;
        if (data.debug !== undefined) DEBUG_CAMERA = !!data.debug;

        var keys = [
            "distance", "pitch", "height_offset", "look_ahead", "yaw_offset",
            "yaw_smooth", "position_smooth", "update_rate", "min_move_for_yaw",
            "model_forward_offset"
        ];

        for (var i = 0; i < keys.length; i++) {
            var k = keys[i];
            if (data[k] !== undefined) CFG[k] = ToNumber(data[k], CFG[k]);
        }

        if (data.force_target_lock !== undefined) CFG.force_target_lock = !!data.force_target_lock;
        if (data.direction_mode !== undefined) CFG.direction_mode = String(data.direction_mode || "movement");

        CFG.distance = Clamp(CFG.distance, 250, 1600);
        CFG.pitch = Clamp(CFG.pitch, 20, 70);
        CFG.height_offset = Clamp(CFG.height_offset, -100, 400);
        CFG.look_ahead = Clamp(CFG.look_ahead, 0, 700);
        CFG.update_rate = Clamp(CFG.update_rate, 0.01, 0.10);
        CFG.yaw_smooth = Clamp(CFG.yaw_smooth, 0.01, 1.0);
        CFG.position_smooth = Clamp(CFG.position_smooth, 0.01, 1.0);
        CFG.min_move_for_yaw = Clamp(CFG.min_move_for_yaw, 0.1, 40.0);
        CFG.yaw_offset = NormalizeAngle(CFG.yaw_offset);
        CFG.model_forward_offset = NormalizeAngle(CFG.model_forward_offset);

        ApplyStaticCameraSettings(true);
        ResetRuntimeSmoothing();

        Msg("config: mode=" + CFG.direction_mode + " yaw_offset=" + CFG.yaw_offset + " distance=" + CFG.distance + " pitch=" + CFG.pitch);
    }

    function OnCameraConfig(data) {
        ApplyConfig(data || {});
    }

    function OnCameraEnable(data) {
        SetEnabled(!data || data.enabled !== false);
    }

    function OnCameraDisable() {
        SetEnabled(false);
    }

    function RegisterLookBackBind() {
        try {
            if (Game && Game.AddCommand) {
                Game.AddCommand("+" + LOOK_BACK_CMD, function () { LOOK_BACK = true; }, "", 0);
                Game.AddCommand("-" + LOOK_BACK_CMD, function () { LOOK_BACK = false; }, "", 0);
            }
        } catch (e1) { }
        try {
            if (Game && Game.CreateCustomKeyBind) {
                Game.CreateCustomKeyBind("r", "+" + LOOK_BACK_CMD);
                Game.CreateCustomKeyBind("R", "+" + LOOK_BACK_CMD);
            }
        } catch (e2) { }
        Msg("rear-view bind: hold R");
    }

    function Init() {
        RegisterLookBackBind();
        if (typeof GameEvents !== "undefined") {
            GameEvents.Subscribe("dotakart_camera_config", OnCameraConfig);
            GameEvents.Subscribe("dotakart_camera_enable", OnCameraEnable);
            GameEvents.Subscribe("dotakart_camera_disable", OnCameraDisable);
        }

        ApplyStaticCameraSettings(true);
        Msg("script carregado FIX51");
        UpdateCamera();
    }

    Init();
})();
