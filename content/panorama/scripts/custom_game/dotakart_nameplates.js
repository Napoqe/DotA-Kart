(function () {
    "use strict";
    var context = $.GetContextPanel();
    var plates = {};
    var racers = {};
    var width = 156;
    var height = 24;

    function Receive(data) {
        if (!data || data.racers === undefined) return;
        var incoming = data.racers || {};
        var next = {};
        function Collect(list, decoy) {
            // Lua arrays arrive either as arrays or objects with numeric keys.
            for (var key in list) {
                if (!Object.prototype.hasOwnProperty.call(list, key)) continue;
                var racer = list[key];
                if (!racer || racer.player_id === undefined) continue;
                var id = Number(racer.player_id);
                if (!isFinite(id) || id < 0) continue;
                var ent = Number(racer.entindex);
                if (decoy && (!isFinite(ent) || ent < 0)) continue;
                // Owner and illusion share identity, but never share a UI panel.
                next[decoy ? "decoy_" + ent : String(id)] = racer;
            }
        }
        Collect(incoming, false);
        Collect(data.nameplate_decoys || {}, true);
        racers = next;
        for (var old in plates) {
            if (!Object.prototype.hasOwnProperty.call(plates, old) || racers[old]) continue;
            plates[old].panel.DeleteAsync(0);
            delete plates[old];
        }
    }

    function Create(root, id) {
        var panel = $.CreatePanel("Panel", root, "DKNameplate_" + id);
        panel.AddClass("DKNameplate");
        panel.hittest = false;
        panel.hittestchildren = false;
        var avatar = $.CreatePanel("DOTAAvatarImage", panel, "");
        avatar.AddClass("DKNameplateAvatar");
        var bot = $.CreatePanel("DOTAHeroImage", panel, "");
        bot.AddClass("DKNameplateAvatar");
        bot.heroimagestyle = "icon";
        var name = $.CreatePanel("Label", panel, "");
        name.AddClass("DKNameplateText");
        name.html = false;
        return { panel: panel, avatar: avatar, bot: bot, name: name, steam: null };
    }

    function UpdateMetadata(plate, racer) {
        var id = Number(racer.player_id);
        var steam = String(racer.steam_id || "");
        var isBot = Number(racer.is_bot) === 1;
        var name = String(racer.player_name || "");
        if (!isBot) {
            var info = Game.GetPlayerInfo ? Game.GetPlayerInfo(id) : null;
            // Native client IDs are strings, avoiding any Lua number rounding.
            var clientSteam = String((info && info.player_steamid) || "");
            if (/^\d{16,20}$/.test(clientSteam)) steam = clientSteam;
        }
        if (!name) name = isBot ? "CPU " + (id + 1) : Players.GetPlayerName(id);
        plate.name.text = name || "Player " + (id + 1);
        var hasSteam = !isBot && /^\d{16,20}$/.test(steam) && steam !== "0";
        plate.avatar.visible = hasSteam;
        plate.bot.visible = !hasSteam;
        if (hasSteam && plate.steam !== steam) {
            plate.avatar.steamid = steam;
            plate.steam = steam;
        }
        plate.bot.heroname = String(racer.hero || "npc_dota_hero_wisp");
    }

    function Position(racer, root) {
        var ent = Number(racer.entindex);
        if (!isFinite(ent) || ent < 0 || Number(racer.nameplate_hidden) === 1) return null;
        if (!Entities.IsValidEntity(ent)) return null;
        // A fallback prop_dynamic decoy is visible but is not a living NPC.
        if (Number(racer.is_decoy) !== 1 && !Entities.IsAlive(ent)) return null;
        if (Entities.IsDormant && Entities.IsDormant(ent)) return null;
        var localID = Players.GetLocalPlayer();
        if (Entities.IsVisibleToPlayer && !Entities.IsVisibleToPlayer(ent, localID)) return null;
        var origin = Entities.GetAbsOrigin(ent);
        if (!origin || origin.length < 3) return null;
        var x = Number(Game.WorldToScreenX(origin[0], origin[1], origin[2] + 210));
        var y = Number(Game.WorldToScreenY(origin[0], origin[1], origin[2] + 210));
        if (!isFinite(x) || !isFinite(y) || x < 0 || y < 0) return null;
        // Projection uses physical screen pixels; Panorama positions use UI units.
        x /= Number(root.actualuiscale_x) || 1;
        y /= Number(root.actualuiscale_y) || 1;
        var w = Number(root.actuallayoutwidth);
        var h = Number(root.actuallayoutheight);
        if (!w || !h || x < width / 2 || x > w - width / 2 || y < height || y > h) return null;
        return { x: Math.round(x - width / 2), y: Math.round(y - height) };
    }

    function Tick() {
        if (!context.IsValid()) return;
        var root = context.FindChildTraverse("DKNameplates");
        if (root) {
            for (var id in racers) {
                if (!Object.prototype.hasOwnProperty.call(racers, id)) continue;
                var plate = plates[id] || (plates[id] = Create(root, id));
                try {
                    if (plate.racer !== racers[id]) {
                        UpdateMetadata(plate, racers[id]);
                        plate.racer = racers[id];
                    }
                    var pos = Position(racers[id], root);
                    plate.panel.visible = !!pos;
                    if (pos) plate.panel.style.position = pos.x + "px " + pos.y + "px 0px";
                } catch (error) {
                    plate.panel.visible = false;
                }
            }
        }
        $.Schedule(0.03, Tick);
    }

    GameEvents.Subscribe("dotakart_hud_update", Receive);
    $.Schedule(0.1, Tick);
})();
