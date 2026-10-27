// DotA Kart GameSetup - FIX63
// Root Panel sem id: o compilador Panorama/GameSetup rejeita id no painel raiz.
// Usa apenas Button + Label. TextButton removido para evitar Resource Compile Failed no VXML GameSetup.
// Sem IIFE: funções chamadas por onactivate no XML precisam ficar globais.

var DotaKartGameSetup = DotaKartGameSetup || {};

DotaKartGameSetup.currentLaps = 3;
DotaKartGameSetup.currentBots = -1;
DotaKartGameSetup.currentRandomStarts = true;
DotaKartGameSetup.maxBots = 7;
DotaKartGameSetup.maxPlayers = 8;
DotaKartGameSetup.locked = false;
DotaKartGameSetup.collapsed = false;
DotaKartGameSetup.lastPayload = {};
DotaKartGameSetup.subscribed = false;
DotaKartGameSetup.requestStarted = false;
DotaKartGameSetup.teamBase = 6; // DOTA_TEAM_CUSTOM_1

DotaKartGameSetup.Root = function () {
    try { return $.GetContextPanel(); }
    catch (e) { return null; }
};

DotaKartGameSetup.Find = function (id) {
    try {
        var root = DotaKartGameSetup.Root();
        if (!root) return null;
        return root.FindChildTraverse(String(id).replace(/^#/, ""));
    }
    catch (e) { return null; }
};

DotaKartGameSetup.Localize = function (token) {
    if (!token) return "";
    if (token.charAt(0) !== "#") token = "#" + token;
    try {
        var text = $.Localize(token);
        if (text && text !== token) return text;
    } catch (e) {}
    return token.replace(/^#/, "");
};

DotaKartGameSetup.FormatToken = function (token, values) {
    var text = DotaKartGameSetup.Localize(token);
    values = values || {};
    for (var k in values) {
        if (values.hasOwnProperty(k)) {
            text = text.split("%" + k + "%").join(String(values[k]));
        }
    }
    return text;
};

DotaKartGameSetup.ButtonLabel = function (button) {
    if (!button) return null;
    try {
        var label = button.FindChildTraverse(button.id + "Label");
        if (label) return label;
        return button.FindChildTraverse("Label");
    } catch (e) { return null; }
};

DotaKartGameSetup.SetButtonText = function (buttonOrID, text) {
    var button = typeof buttonOrID === "string" ? DotaKartGameSetup.Find(buttonOrID) : buttonOrID;
    var label = DotaKartGameSetup.ButtonLabel(button);
    if (label) label.text = text;
};

DotaKartGameSetup.MakeButton = function (parent, id, className, text, callback) {
    var btn = $.CreatePanel("Button", parent, id);
    btn.AddClass(className);
    btn.hittest = true;
    var lbl = $.CreatePanel("Label", btn, id + "Label");
    lbl.text = text;
    if (callback) btn.SetPanelEvent("onactivate", callback);
    return btn;
};

DotaKartGameSetup.LocalPlayerID = function () {
    try {
        if (typeof Game !== "undefined" && Game.GetLocalPlayerID) {
            var gameID = Number(Game.GetLocalPlayerID());
            if (!isNaN(gameID) && gameID >= 0) return gameID;
        }
    } catch (e1) {}

    try {
        if (typeof Players !== "undefined" && Players.GetLocalPlayer) {
            var playerID = Number(Players.GetLocalPlayer());
            if (!isNaN(playerID) && playerID >= 0) return playerID;
        }
    } catch (e2) {}

    return -1;
};

DotaKartGameSetup.IsHost = function (payload) {
    var local = DotaKartGameSetup.LocalPlayerID();
    if (local < 0) return true;
    return local === Number((payload && payload.host_player_id) || 0);
};

DotaKartGameSetup.SendServer = function (name, extra) {
    extra = extra || {};
    var pid = DotaKartGameSetup.LocalPlayerID();
    if (pid >= 0) {
        extra.PlayerID = pid;
        extra.player_id = pid;
    }
    extra.setup_screen_event = 1;
    try {
        GameEvents.SendCustomGameEventToServer(name, extra);
    } catch (e) {
        try { $.Msg("[DotaKartSetup] send failed " + name + ": " + String(e)); } catch (ignore) {}
    }
};

DotaKartGameSetup.SetDisabled = function (panel, disabled) {
    if (!panel) return;
    panel.enabled = disabled !== true;
    panel.SetHasClass("DKSetupDisabled", disabled === true);
};

DotaKartGameSetup.GetPayloadNumber = function (payload, key, fallback) {
    var v = Number(payload && payload[key] !== undefined ? payload[key] : fallback);
    if (isNaN(v)) return fallback;
    return v;
};

DotaKartGameSetup.FormatCountdown = function (seconds) {
    seconds = Math.max(0, Math.ceil(Number(seconds) || 0));
    var minutes = Math.floor(seconds / 60);
    var secs = seconds % 60;
    return String(minutes) + ":" + (secs < 10 ? "0" : "") + String(secs);
};

DotaKartGameSetup.RefreshSettings = function (payload) {
    payload = payload || DotaKartGameSetup.lastPayload || {};

    DotaKartGameSetup.currentLaps = DotaKartGameSetup.GetPayloadNumber(payload, "laps", DotaKartGameSetup.currentLaps || 3);
    DotaKartGameSetup.currentBots = DotaKartGameSetup.GetPayloadNumber(payload, "bot_count", DotaKartGameSetup.currentBots);
    if (payload.random_start_positions !== undefined) DotaKartGameSetup.currentRandomStarts = Number(payload.random_start_positions) === 1;
    DotaKartGameSetup.maxBots = Math.max(0, Math.min(7, DotaKartGameSetup.GetPayloadNumber(payload, "max_bots", DotaKartGameSetup.maxBots || 7)));
    DotaKartGameSetup.maxPlayers = Math.max(1, Math.min(8, DotaKartGameSetup.GetPayloadNumber(payload, "max_players", DotaKartGameSetup.maxPlayers || 8)));
    DotaKartGameSetup.locked = Number(payload.locked || 0) === 1 || Number(payload.race_started || 0) === 1;

    var setupRemaining = DotaKartGameSetup.GetPayloadNumber(payload, "setup_remaining", 80);
    var setupTimer = DotaKartGameSetup.Find("DKSetupCountdown");
    if (setupTimer) {
        setupTimer.text = DotaKartGameSetup.FormatCountdown(setupRemaining);
        setupTimer.SetHasClass("DKSetupCountdownUrgent", setupRemaining > 0 && setupRemaining <= 10);
    }

    var panel = DotaKartGameSetup.Find("DKSetupSettingsPanel");
    var root = DotaKartGameSetup.Root();
    if (!panel || !root) return;

    var isHost = DotaKartGameSetup.IsHost(payload);
    root.SetHasClass("DKSetupLocked", DotaKartGameSetup.locked);
    root.SetHasClass("DKSetupNotHost", !isHost);
    panel.SetHasClass("DKSetupCollapsed", DotaKartGameSetup.collapsed);

    DotaKartGameSetup.SetButtonText("DKSetupCollapse", DotaKartGameSetup.collapsed ? "+" : "-");

    var lapStatus = DotaKartGameSetup.Find("DKSetupLapStatus");
    if (lapStatus) lapStatus.text = DotaKartGameSetup.FormatToken("DOTA_KART_SETUP_LAPS_VALUE", { laps: DotaKartGameSetup.currentLaps });

    for (var n = 2; n <= 5; n++) {
        var lapButton = DotaKartGameSetup.Find("DKSetupLap" + String(n));
        if (lapButton) {
            DotaKartGameSetup.SetDisabled(lapButton, !isHost || DotaKartGameSetup.locked);
            lapButton.SetHasClass("DKSetupSelected", n === DotaKartGameSetup.currentLaps);
        }
    }

    var botStatus = DotaKartGameSetup.Find("DKSetupBotStatus");
    if (botStatus) {
        botStatus.text = DotaKartGameSetup.currentBots < 0 ?
            DotaKartGameSetup.Localize("DOTA_KART_SETUP_BOTS_FILL") :
            DotaKartGameSetup.FormatToken("DOTA_KART_SETUP_BOTS_VALUE", { count: DotaKartGameSetup.currentBots });
    }

    var fillButton = DotaKartGameSetup.Find("DKSetupBotFill");
    if (fillButton) {
        DotaKartGameSetup.SetDisabled(fillButton, !isHost || DotaKartGameSetup.locked);
        fillButton.SetHasClass("DKSetupSelected", DotaKartGameSetup.currentBots < 0);
    }

    for (var b = 0; b <= 7; b++) {
        var botButton = DotaKartGameSetup.Find("DKSetupBot" + String(b));
        if (botButton) {
            var disabled = !isHost || DotaKartGameSetup.locked || b > DotaKartGameSetup.maxBots;
            DotaKartGameSetup.SetDisabled(botButton, disabled);
            botButton.SetHasClass("DKSetupSelected", DotaKartGameSetup.currentBots === b);
        }
    }

    var randomStarts = DotaKartGameSetup.Find("DKSetupRandomStarts");
    if (randomStarts) {
        DotaKartGameSetup.SetDisabled(randomStarts, !isHost || DotaKartGameSetup.locked);
        randomStarts.SetHasClass("DKSetupSelected", DotaKartGameSetup.currentRandomStarts);
        DotaKartGameSetup.SetButtonText(randomStarts, DotaKartGameSetup.Localize(DotaKartGameSetup.currentRandomStarts ? "DOTA_KART_SETUP_RANDOM_STARTS_ON" : "DOTA_KART_SETUP_RANDOM_STARTS_OFF"));
    }

    var hostStatus = DotaKartGameSetup.Find("DKSetupHostStatus");
    if (hostStatus) {
        if (DotaKartGameSetup.locked) hostStatus.text = DotaKartGameSetup.Localize("DOTA_KART_SETUP_STATUS_LOCKED");
        else if (isHost) hostStatus.text = DotaKartGameSetup.Localize("DOTA_KART_SETUP_STATUS_HOST");
        else hostStatus.text = DotaKartGameSetup.Localize("DOTA_KART_SETUP_STATUS_WAIT");
    }

    var confirm = DotaKartGameSetup.Find("DKSetupConfirm");
    if (confirm) DotaKartGameSetup.SetDisabled(confirm, !isHost || DotaKartGameSetup.locked);
};

DotaKartGameSetup.GetPlayerNameFromPayload = function (payload, playerID) {
    var key = "p" + String(playerID) + "_name";
    var name = payload && payload[key] ? String(payload[key]) : "";
    if (name !== "") return name;
    try {
        if (typeof Players !== "undefined" && Players.GetPlayerName) {
            name = Players.GetPlayerName(playerID);
            if (name && name !== "") return name;
        }
    } catch (e) {}
    return DotaKartGameSetup.FormatToken("DOTA_KART_SETUP_PLAYER_FALLBACK", { id: playerID + 1 });
};

DotaKartGameSetup.TeamLabel = function (slot) {
    var token = "#DOTA_CUSTOM" + String(slot + 1);
    try {
        var txt = $.Localize(token);
        if (txt && txt !== token) return txt;
    } catch (e) {}
    return DotaKartGameSetup.FormatToken("DOTA_KART_SETUP_SLOT_VALUE", { slot: slot + 1 });
};

DotaKartGameSetup.BuildTeams = function (payload) {
    payload = payload || DotaKartGameSetup.lastPayload || {};
    var list = DotaKartGameSetup.Find("DKSetupTeamsList");
    if (!list) return;

    list.RemoveAndDeleteChildren();

    var localID = DotaKartGameSetup.LocalPlayerID();
    var localTeam = -999;
    if (localID >= 0) localTeam = Number(payload["p" + String(localID) + "_team"] || -999);

    for (var slot = 0; slot < DotaKartGameSetup.maxPlayers; slot++) {
        var team = Number(payload["team" + String(slot)] || (DotaKartGameSetup.teamBase + slot));
        var occupant = -1;
        var occupantName = "";

        for (var pid = 0; pid < DotaKartGameSetup.maxPlayers; pid++) {
            if (Number(payload["p" + String(pid) + "_connected"] || 0) === 1) {
                var pteam = Number(payload["p" + String(pid) + "_team"] || -999);
                if (pteam === team) {
                    occupant = pid;
                    occupantName = DotaKartGameSetup.GetPlayerNameFromPayload(payload, pid);
                    break;
                }
            }
        }

        var row = $.CreatePanel("Panel", list, "DKSetupTeamRow" + String(slot));
        row.AddClass("DKSetupTeamRow");
        row.hittest = true;
        row.hittestchildren = true;
        if (localTeam === team) row.AddClass("DKSetupLocalTeam");

        var info = $.CreatePanel("Panel", row, "DKSetupTeamInfo" + String(slot));
        info.AddClass("DKSetupTeamInfo");

        var title = $.CreatePanel("Label", info, "DKSetupTeamName" + String(slot));
        title.AddClass("DKSetupTeamName");
        title.text = DotaKartGameSetup.TeamLabel(slot);

        var pname = $.CreatePanel("Label", info, "DKSetupPlayerName" + String(slot));
        pname.AddClass("DKSetupPlayerName");
        if (occupant >= 0) {
            pname.text = "★ " + occupantName;
        } else {
            pname.text = DotaKartGameSetup.Localize("DOTA_KART_SETUP_EMPTY_SLOT");
            pname.AddClass("DKSetupEmptyName");
        }

        (function (teamSlot, occ) {
            var text = occ >= 0 ? DotaKartGameSetup.Localize("DOTA_KART_SETUP_OCCUPIED") : DotaKartGameSetup.Localize("DOTA_KART_SETUP_JOIN");
            var btn = DotaKartGameSetup.MakeButton(row, "DKSetupJoin" + String(teamSlot), "DKSetupJoinButton", text, function () {
                DotaKartGameSetup.JoinTeam(teamSlot);
            });
            btn.SetHasClass("DKSetupOccupied", occ >= 0 && occ !== localID);
            DotaKartGameSetup.SetDisabled(btn, DotaKartGameSetup.locked || (occ >= 0 && occ !== localID));
        })(slot, occupant);
    }
};

DotaKartGameSetup.BuildPlayersOut = function (payload) {
    payload = payload || DotaKartGameSetup.lastPayload || {};
    var out = DotaKartGameSetup.Find("DKSetupPlayersOut");
    if (!out) return;
    out.RemoveAndDeleteChildren();

    var added = false;
    for (var pid = 0; pid < DotaKartGameSetup.maxPlayers; pid++) {
        if (Number(payload["p" + String(pid) + "_connected"] || 0) === 1) {
            var pteam = Number(payload["p" + String(pid) + "_team"] || -999);
            var inRaceTeam = false;
            for (var slot = 0; slot < DotaKartGameSetup.maxPlayers; slot++) {
                if (pteam === Number(payload["team" + String(slot)] || (DotaKartGameSetup.teamBase + slot))) {
                    inRaceTeam = true;
                    break;
                }
            }
            if (!inRaceTeam) {
                var lbl = $.CreatePanel("Label", out, "DKSetupOut" + String(pid));
                lbl.AddClass("DKSetupOutsidePlayer");
                lbl.text = DotaKartGameSetup.GetPlayerNameFromPayload(payload, pid);
                added = true;
            }
        }
    }

    if (!added) {
        var empty = $.CreatePanel("Label", out, "DKSetupOutEmpty");
        empty.AddClass("DKSetupOutsidePlayer");
        empty.text = DotaKartGameSetup.Localize("DOTA_KART_SETUP_NO_PLAYERS_OUT");
    }
};

DotaKartGameSetup.RefreshAll = function (payload) {
    payload = payload || {};
    DotaKartGameSetup.lastPayload = payload;
    DotaKartGameSetup.RefreshSettings(payload);
    DotaKartGameSetup.BuildTeams(payload);
    DotaKartGameSetup.BuildPlayersOut(payload);
};

DotaKartGameSetup.SendSettings = function (extra) {
    if (DotaKartGameSetup.locked) return;
    DotaKartGameSetup.SendServer("dotakart_host_settings", extra || {});
};

DotaKartGameSetup.SetLaps = function (laps) {
    if (DotaKartGameSetup.locked) return;
    DotaKartGameSetup.currentLaps = Math.max(2, Math.min(5, Number(laps) || 3));
    var copy = DotaKartGameSetup.lastPayload || {};
    copy.laps = DotaKartGameSetup.currentLaps;
    DotaKartGameSetup.RefreshSettings(copy);
    DotaKartGameSetup.SendSettings({ laps: DotaKartGameSetup.currentLaps });
};

DotaKartGameSetup.SetBots = function (count) {
    if (DotaKartGameSetup.locked) return;
    count = Number(count);
    if (isNaN(count) || count < 0) count = -1;
    else count = Math.max(0, Math.min(DotaKartGameSetup.maxBots, count));
    DotaKartGameSetup.currentBots = count;
    var copy = DotaKartGameSetup.lastPayload || {};
    copy.bot_count = DotaKartGameSetup.currentBots;
    DotaKartGameSetup.RefreshSettings(copy);
    DotaKartGameSetup.SendSettings({ bot_count: DotaKartGameSetup.currentBots });
};

DotaKartGameSetup.ToggleRandomStarts = function () {
    if (DotaKartGameSetup.locked || !DotaKartGameSetup.IsHost(DotaKartGameSetup.lastPayload)) return;
    var value = DotaKartGameSetup.currentRandomStarts ? 0 : 1;
    var copy = DotaKartGameSetup.lastPayload || {};
    copy.random_start_positions = value;
    DotaKartGameSetup.RefreshSettings(copy);
    DotaKartGameSetup.SendSettings({ random_start_positions: value });
};

DotaKartGameSetup.JoinTeam = function (slot) {
    if (DotaKartGameSetup.locked) return;
    slot = Math.max(0, Math.min(7, Number(slot) || 0));
    DotaKartGameSetup.SendServer("dotakart_setup_join_team", { team_slot: slot });
};

DotaKartGameSetup.JoinRandomTeam = function () {
    if (DotaKartGameSetup.locked) return;
    DotaKartGameSetup.SendServer("dotakart_setup_join_team", { random: 1 });
};

DotaKartGameSetup.LeaveTeam = function () {
    if (DotaKartGameSetup.locked) return;
    DotaKartGameSetup.SendServer("dotakart_setup_join_team", { leave: 1 });
};

DotaKartGameSetup.Confirm = function () {
    if (DotaKartGameSetup.locked) return;
    DotaKartGameSetup.SendServer("dotakart_setup_confirm", { confirm: 1, laps: DotaKartGameSetup.currentLaps, bot_count: DotaKartGameSetup.currentBots, random_start_positions: DotaKartGameSetup.currentRandomStarts ? 1 : 0 });
};

DotaKartGameSetup.ToggleCollapse = function () {
    DotaKartGameSetup.collapsed = !DotaKartGameSetup.collapsed;
    DotaKartGameSetup.RefreshSettings(DotaKartGameSetup.lastPayload || {});
};

DotaKartGameSetup.HookStaticButtons = function () {
    var n;
    for (n = 2; n <= 5; n++) {
        (function (laps) {
            var p = DotaKartGameSetup.Find("DKSetupLap" + String(laps));
            if (p) p.SetPanelEvent("onactivate", function () { DotaKartGameSetup.SetLaps(laps); });
        })(n);
    }

    var fill = DotaKartGameSetup.Find("DKSetupBotFill");
    if (fill) fill.SetPanelEvent("onactivate", function () { DotaKartGameSetup.SetBots(-1); });
    var grid = DotaKartGameSetup.Find("DKSetupRandomStarts");
    if (grid) grid.SetPanelEvent("onactivate", DotaKartGameSetup.ToggleRandomStarts);

    for (var b = 0; b <= 7; b++) {
        (function (count) {
            var p = DotaKartGameSetup.Find("DKSetupBot" + String(count));
            if (p) p.SetPanelEvent("onactivate", function () { DotaKartGameSetup.SetBots(count); });
        })(b);
    }

    var collapse = DotaKartGameSetup.Find("DKSetupCollapse");
    if (collapse) collapse.SetPanelEvent("onactivate", function () { DotaKartGameSetup.ToggleCollapse(); });

    var random = DotaKartGameSetup.Find("DKSetupRandomTeam");
    if (random) random.SetPanelEvent("onactivate", function () { DotaKartGameSetup.JoinRandomTeam(); });

    var leave = DotaKartGameSetup.Find("DKSetupLeaveTeam");
    if (leave) leave.SetPanelEvent("onactivate", function () { DotaKartGameSetup.LeaveTeam(); });

    var confirm = DotaKartGameSetup.Find("DKSetupConfirm");
    if (confirm) confirm.SetPanelEvent("onactivate", function () { DotaKartGameSetup.Confirm(); });
};

DotaKartGameSetup.RequestLoop = function () {
    DotaKartGameSetup.SendServer("dotakart_host_settings", { request: 1 });
    $.Schedule(1.0, DotaKartGameSetup.RequestLoop);
};

DotaKartGameSetup.Init = function () {
    DotaKartGameSetup.HookStaticButtons();
    DotaKartGameSetup.RefreshAll({ laps: 3, bot_count: -1, max_bots: 7, max_players: 8, host_player_id: 0, setup_remaining: 80 });
    if (!DotaKartGameSetup.subscribed) {
        try { GameEvents.Subscribe("dotakart_host_settings_update", DotaKartGameSetup.RefreshAll); } catch (e) {}
        DotaKartGameSetup.subscribed = true;
    }
    if (!DotaKartGameSetup.requestStarted) {
        DotaKartGameSetup.requestStarted = true;
        DotaKartGameSetup.RequestLoop();
    }
};

function DotaKartSetup_SetLaps2() { DotaKartGameSetup.SetLaps(2); }
function DotaKartSetup_SetLaps3() { DotaKartGameSetup.SetLaps(3); }
function DotaKartSetup_SetLaps4() { DotaKartGameSetup.SetLaps(4); }
function DotaKartSetup_SetLaps5() { DotaKartGameSetup.SetLaps(5); }
function DotaKartSetup_SetBotsFill() { DotaKartGameSetup.SetBots(-1); }
function DotaKartSetup_SetBots0() { DotaKartGameSetup.SetBots(0); }
function DotaKartSetup_SetBots1() { DotaKartGameSetup.SetBots(1); }
function DotaKartSetup_SetBots2() { DotaKartGameSetup.SetBots(2); }
function DotaKartSetup_SetBots3() { DotaKartGameSetup.SetBots(3); }
function DotaKartSetup_SetBots4() { DotaKartGameSetup.SetBots(4); }
function DotaKartSetup_SetBots5() { DotaKartGameSetup.SetBots(5); }
function DotaKartSetup_SetBots6() { DotaKartGameSetup.SetBots(6); }
function DotaKartSetup_SetBots7() { DotaKartGameSetup.SetBots(7); }
function DotaKartSetup_ToggleCollapse() { DotaKartGameSetup.ToggleCollapse(); }
function DotaKartSetup_ToggleRandomStarts() { DotaKartGameSetup.ToggleRandomStarts(); }
function DotaKartSetup_JoinRandomTeam() { DotaKartGameSetup.JoinRandomTeam(); }
function DotaKartSetup_LeaveTeam() { DotaKartGameSetup.LeaveTeam(); }
function DotaKartSetup_Confirm() { DotaKartGameSetup.Confirm(); }

$.Schedule(0.05, DotaKartGameSetup.Init);
