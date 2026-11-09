(function () {
    "use strict";

    /*
        DotA Kart - input client / Arcade controls hotfix
        ----------------------------------------------------
        W = acelerar
        S = freio / re
        A = virar esquerda
        D = virar direita
        T = usar item

        FIX16 importante:
        O Dota/Panorama mantém ConCommands entre reloads do Workshop Tools.
        Quando o mesmo nome é registrado de novo, aparece:
            Cannot create ConCommand '+dotakart15_forward' - already exists
        Aí o bind pode ficar apontando para callback antigo/morto e o herói para
        de responder no segundo teste.

        Solução: cada load cria nomes UNICOS de comando e rebinda W/S/A/D/T
        para esses nomes. Assim nunca dependemos de callback antigo em cache.

        Arcade: addoninfo declara W/S/A/D como teclas do addon. Os comandos
        declarados encaminham para o HUD atual, e os binds são reaplicados
        na seleção do herói, mudança de estado e contagem regressiva.
    */

    var ENABLED = true;
    var HEARTBEAT = 0.20;
    var REBIND_INTERVAL = 1.0;
    var REBIND_ATTEMPTS = 12;
    var rebindCount = 0;

    var RUN_ID = CreateRunID();
    var CMD = {
        forward: "dotakart16_" + RUN_ID + "_forward",
        reverse: "dotakart16_" + RUN_ID + "_reverse",
        left: "dotakart16_" + RUN_ID + "_left",
        right: "dotakart16_" + RUN_ID + "_right",
        item: "dotakart16_" + RUN_ID + "_item",
        // FIX141: per-load name like T. A fixed name stayed bound to the previous HUD load.
        self_item: "dotakart16_" + RUN_ID + "_self_item",
        force_forward: "dotakart16_" + RUN_ID + "_force_forward",
        release: "dotakart16_" + RUN_ID + "_release_all"
    };

    var input = {
        forward: false,
        reverse: false,
        left: false,
        right: false,
        force_forward: false
    };

    var lastSent = "";
    var lastSendTime = 0;
    var debug = false;

    function CreateRunID() {
        var t = 0;
        try {
            if (typeof Game !== "undefined" && typeof Game.Time === "function") {
                t = Math.floor(Game.Time() * 1000);
            }
        } catch (e) { }

        var d = 0;
        try {
            d = (new Date()).getTime() % 1000000000;
        } catch (e2) { }

        var r = Math.floor(Math.random() * 1000000);
        return String(d) + "_" + String(t) + "_" + String(r);
    }

    function Msg(text) {
        $.Msg("[DotA Kart Input Arcade] " + text);
    }

    function IsFunction(owner, name) {
        return owner && typeof owner[name] === "function";
    }

    function GetPlayerID() {
        if (typeof Players !== "undefined" && IsFunction(Players, "GetLocalPlayer")) {
            return Players.GetLocalPlayer();
        }
        return -1;
    }

    function InputSignature() {
        return [
            input.forward ? "1" : "0",
            input.reverse ? "1" : "0",
            input.left ? "1" : "0",
            input.right ? "1" : "0",
            input.force_forward ? "1" : "0"
        ].join("");
    }

    function SendState(force) {
        if (!ENABLED || typeof GameEvents === "undefined") return;
        if (!IsCurrentInput()) return;

        var now = IsFunction(Game, "Time") ? Game.Time() : 0;
        var sig = InputSignature();

        if (!force && sig === lastSent) {
            if (sig === "00000") return;
            if (now - lastSendTime < 0.25) return;
        }

        var changed = sig !== lastSent;
        lastSent = sig;
        lastSendTime = now;

        var playerID = GetPlayerID();

        GameEvents.SendCustomGameEventToServer("dotakart_input_state", {
            PlayerID: playerID,
            player_id: playerID,
            playerID: playerID,
            forward: input.forward ? 1 : 0,
            reverse: input.reverse ? 1 : 0,
            left: input.left ? 1 : 0,
            right: input.right ? 1 : 0,
            force_forward: input.force_forward ? 1 : 0
        });

        // Log releases too. A held-state heartbeat cannot tell whether a key-up
        // callback ran, and printing every heartbeat hides the transition.
        if (debug || changed) {
            Msg("send p" + playerID +
                " W=" + (input.forward ? 1 : 0) +
                " S=" + (input.reverse ? 1 : 0) +
                " A=" + (input.left ? 1 : 0) +
                " D=" + (input.right ? 1 : 0) +
                " R=" + (input.force_forward ? 1 : 0));
        }
    }

    function SetKey(name, down) {
        if (!ENABLED) return;

        down = !!down;
        if (input[name] === down) return;

        input[name] = down;

        // FIX108: R keeps the Spectral Dagger force-forward flag AND restores the old
        // hold-to-look-back camera from FIX51. The camera script is loaded before input.
        if (name === "force_forward") {
            try {
                if (GameUI && typeof GameUI.SetDotaKartRearView === "function") {
                    GameUI.SetDotaKartRearView(down);
                }
            } catch (e) { }
        }

        SendState(true);
    }

    function ReleaseAll() {
        var changed = input.forward || input.reverse || input.left || input.right || input.force_forward;
        input.forward = false;
        input.reverse = false;
        input.left = false;
        input.right = false;
        input.force_forward = false;
        try {
            if (GameUI && typeof GameUI.SetDotaKartRearView === "function") {
                GameUI.SetDotaKartRearView(false);
            }
        } catch (e) { }
        SendState(changed || true);
    }

    function UseItem(pressed) {
        if (!ENABLED || typeof GameEvents === "undefined") return;
        var playerID = GetPlayerID();
        GameEvents.SendCustomGameEventToServer("dotakart_input_item", {
            PlayerID: playerID,
            player_id: playerID,
            playerID: playerID,
            force_forward: input.force_forward ? 1 : 0,
            pressed: pressed ? 1 : 0
        });
        Msg("item p" + playerID + " down=" + (pressed ? 1 : 0));
    }

    function UseSelfItem() {
        if (!ENABLED || typeof GameEvents === "undefined") return;
        var playerID = GetPlayerID();
        // FIX123: route Q through the same proven server event channel used by T.
        // The server sees self_cast=1 and calls UseSelfItem instead of normal T use.
        GameEvents.SendCustomGameEventToServer("dotakart_input_item", {
            PlayerID: playerID, player_id: playerID, playerID: playerID,
            self_cast: 1, pressed: 1, force_forward: 0
        });
        Msg("self-item Q p" + playerID);
    }

    function AddCommand(name, callback) {
        if (!IsFunction(Game, "AddCommand")) {
            Msg("ERRO: Game.AddCommand nao existe neste contexto.");
            return false;
        }

        try {
            Game.AddCommand(name, callback, "", 0);
            return true;
        } catch (e) {
            Msg("ERRO AddCommand " + name + ": " + e);
            return false;
        }
    }

    function BindKey(key, command) {
        if (!IsFunction(Game, "CreateCustomKeyBind")) {
            Msg("AVISO: Game.CreateCustomKeyBind nao existe. Use bind manual no console.");
            return false;
        }

        try {
            Game.CreateCustomKeyBind(key, command);
            return true;
        } catch (e) {
            Msg("Falhou bind " + key + " -> " + command + ": " + e);
            return false;
        }
    }

    function RegisterCommands() {
        AddCommand("+" + CMD.forward, function () { SetKey("forward", true); });
        AddCommand("-" + CMD.forward, function () { SetKey("forward", false); });

        AddCommand("+" + CMD.reverse, function () { SetKey("reverse", true); });
        AddCommand("-" + CMD.reverse, function () { SetKey("reverse", false); });

        AddCommand("+" + CMD.left, function () { SetKey("left", true); });
        AddCommand("-" + CMD.left, function () { SetKey("left", false); });

        AddCommand("+" + CMD.right, function () { SetKey("right", true); });
        AddCommand("-" + CMD.right, function () { SetKey("right", false); });

        AddCommand("+" + CMD.item, function () { UseItem(true); });
        AddCommand("-" + CMD.item, function () { UseItem(false); });

        // FIX123: Q is a one-shot action. A plain command is more reliable than +/-
        // for Dota's normal ability hotkey while the legacy +/- commands stay as fallback.
        AddCommand(CMD.self_item, function () { UseSelfItem(); });

        AddCommand("+" + CMD.force_forward, function () { SetKey("force_forward", true); });
        AddCommand("-" + CMD.force_forward, function () { SetKey("force_forward", false); });

        AddCommand(CMD.release, function () { ReleaseAll(); });
    }

    // Arcade loads the addon's declared keys separately from ordinary Dota keys.
    // Stable names in addoninfo must forward to the CURRENT HUD after a Tools reload.
    // Keep the per-load commands above for runtime binds and release callbacks.
    function RegisterAddonDrivingCommands() {
        var config = GameUI.CustomUIConfig();
        if (config.dotaKartDrivingInput) config.dotaKartDrivingInput.release();
        config.dotaKartDrivingInput = { run: RUN_ID, setKey: SetKey, release: ReleaseAll, diagnose: DiagnoseInput, selfItem: UseSelfItem };
        // FIX141: stable manual-bind name forwards to the CURRENT HUD load.
        if (!config.dotaKartSelfItemRegistered) {
            AddCommand("dotakart_self_item", function () {
                var current = GameUI.CustomUIConfig().dotaKartDrivingInput;
                if (current && current.selfItem) current.selfItem();
            });
            config.dotaKartSelfItemRegistered = true;
        }

        function RegisterDirection(direction) {
            function Dispatch(down) {
                var current = GameUI.CustomUIConfig().dotaKartDrivingInput;
                if (current) current.setKey(direction, down);
            }
            AddCommand("+dotakart_drive_" + direction, function () { Dispatch(true); });
            AddCommand("-dotakart_drive_" + direction, function () { Dispatch(false); });
        }

        if (!config.dotaKartDrivingCommandsRegistered) {
            RegisterDirection("forward");
            RegisterDirection("reverse");
            RegisterDirection("left");
            RegisterDirection("right");
            config.dotaKartDrivingCommandsRegistered = true;
        }
        if (!config.dotaKartInputDiagnosticRegistered) {
            AddCommand("dotakart_input_debug", function () {
                var current = GameUI.CustomUIConfig().dotaKartDrivingInput;
                if (current && current.diagnose) current.diagnose();
            });
            config.dotaKartInputDiagnosticRegistered = true;
        }
    }

    function DiagnoseInput() {
        if (!IsCurrentInput()) return;
        Msg("diagnostic client run=" + RUN_ID + " input=" + InputSignature());
        function Request() {
            if (!IsCurrentInput()) return;
            GameEvents.SendCustomGameEventToServer("dotakart_input_debug", {
                PlayerID: GetPlayerID()
            });
        }
        Request();
        $.Schedule(0.5, Request);
    }

    function RebindForGameTransition() {
        if (!IsCurrentInput()) return;
        ReleaseAll();
        ApplyKeyBinds();
        // Hero selection and the native HUD may finish loading after the first bind.
        $.Schedule(0.25, ApplyKeyBinds);
        $.Schedule(1.0, ApplyKeyBinds);
    }

    function ApplyKeyBinds() {
        if (!IsCurrentInput()) return;
        BindKey("w", "+" + CMD.forward);
        BindKey("s", "+" + CMD.reverse);
        BindKey("a", "+" + CMD.left);
        BindKey("d", "+" + CMD.right);
        BindKey("t", "+" + CMD.item);
        BindKey("q", CMD.self_item);
        BindKey("r", "+" + CMD.force_forward);

        BindKey("W", "+" + CMD.forward);
        BindKey("S", "+" + CMD.reverse);
        BindKey("A", "+" + CMD.left);
        BindKey("D", "+" + CMD.right);
        BindKey("T", "+" + CMD.item);
        BindKey("Q", CMD.self_item);
        BindKey("R", "+" + CMD.force_forward);
    }

    function PrintManualBinds() {
        Msg("Comandos desta sessao:");
        Msg("bind w +" + CMD.forward);
        Msg("bind s +" + CMD.reverse);
        Msg("bind a +" + CMD.left);
        Msg("bind d +" + CMD.right);
        Msg("bind t +" + CMD.item);
        Msg("bind q " + CMD.self_item + "  // Astral Imprisonment self-cast");
        Msg("bind r +" + CMD.force_forward + "  // segure R: Rear View; R+T: Spectral Dagger force-forward/atalho");
    }

    function RebindThink() {
        if (rebindCount >= REBIND_ATTEMPTS) return;
        rebindCount++;
        ApplyKeyBinds();
        Msg("binds UNICOS W/S/A/D/T/R aplicados tentativa " + rebindCount + ". player=" + GetPlayerID() + " run=" + RUN_ID);
        $.Schedule(REBIND_INTERVAL, RebindThink);
    }

    function Heartbeat() {
        if (!IsCurrentInput()) return;
        $.Schedule(HEARTBEAT, Heartbeat);
        SendState(false);
    }

    function IsCurrentInput() {
        var current = GameUI.CustomUIConfig().dotaKartDrivingInput;
        return !current || current.run === RUN_ID;
    }

    function Init() {
        RegisterCommands();
        RegisterAddonDrivingCommands();
        GameEvents.Subscribe("dotakart_input_debug", function (data) {
            if (IsCurrentInput()) Msg("diagnostic server " + JSON.stringify(data));
        });
        GameEvents.Subscribe("game_rules_state_change", RebindForGameTransition);
        GameEvents.Subscribe("dota_player_update_assigned_hero", RebindForGameTransition);
        GameEvents.Subscribe("dotakart_countdown_update", function (data) {
            if (Number(data.show) === 1) ApplyKeyBinds();
        });
        RebindThink();
        ReleaseAll();
        Heartbeat();
        PrintManualBinds();
        Msg("script carregado INPUT_DIAGNOSTIC_2. Console: dotakart_input_debug");
    }

    Init();
})();
