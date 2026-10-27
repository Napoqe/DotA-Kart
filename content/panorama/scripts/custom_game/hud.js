(function () {
    "use strict";

    // TRUE = esconde o HUD padrão do Dota e deixa só o HUD do DotA Kart.
    var HIDE_DEFAULT_DOTA_HUD = true;

    // FIX8: usar somente GameEvents por padrão.
    // Assim a HUD funciona mesmo se custom_net_tables.txt estiver errado ou cacheado.
    var USE_NET_TABLES = false;

    var MAX_RACERS_VISIBLE = 8;

    // Tamanho usado pelo minimapa do HUD.
    // Deve bater com #DKMiniMap no hud.css.
    var MINIMAP_W = 330;
    var MINIMAP_H = 260;
    var MINIMAP_PADDING = 22;
    var TRACK_THICKNESS = 16;
    var TRACK_HASH = "";

    // FIX22: metadados reais dos itens do DotA Kart.
    // itemName continua usando itens reais do Dota para inventário/HUD, mas o ícone exibido pode ser ability.
    var ITEM_META = {
        item_phase_boots: {
            type: "custom",
            icon: "nitro_1",
            label: "1 Nitro",
            desc: "Um Nitro forte e curto."
        },
        item_yasha: {
            type: "custom",
            icon: "nitro_2",
            label: "2 Nitros",
            desc: "Duas cargas de Nitro. Cada uso atualiza o icone."
        },
        item_mask_of_madness: {
            type: "custom",
            icon: "nitro_3",
            label: "3 Nitros",
            desc: "Tres cargas de Nitro: 3, 2, 1."
        },
        item_black_king_bar: {
            type: "item",
            icon: "item_black_king_bar",
            label: "Estrelinha",
            desc: "15s invulneravel, atravessa karts e atordoa rivais na colisao."
        },
        item_force_staff: {
            type: "ability",
            icon: "pudge_meat_hook",
            label: "Meat Hook",
            desc: "Alcance 4000, mais rapido. Puxa inimigos ou caixas. S+T lança para tras."
        },
        item_blink: {
            type: "ability",
            icon: "rattletrap_hookshot",
            label: "Hookshot",
            desc: "Viaja ate 5000. Puxa voce ate o alvo e aplica stun."
        },
        item_hurricane_pike: {
            type: "ability",
            icon: "mirana_leap",
            label: "Leap",
            desc: "Salto em arco de 950 unidades, mais alto, +8% velocidade por 2s."
        },
        item_gungir: {
            type: "ability",
            icon: "mirana_arrow",
            label: "Sacred Arrow",
            desc: "Flecha ate 5000. Stun aumenta conforme a distancia."
        },
        item_cyclone: {
            type: "ability",
            icon: "vengefulspirit_magic_missile",
            label: "Swap Missile",
            desc: "Missil teleguiado em arco. Para tras causa stun, mas nao troca posicao."
        },
        item_shadow_blade: {
            type: "ability",
            icon: "spirit_breaker_charge_of_darkness",
            label: "Charge of Darkness",
            desc: "Persegue o kart uma posicao melhor. S cancela. Bash leve em quem encostar."
        },
        item_orb_of_venom: {
            type: "ability",
            icon: "venomancer_venomous_gale",
            label: "Venomous Gale",
            desc: "Projétil em linha range 1500. Slow inicial de 50% por ate 15s, recuperando aos poucos."
        },
        item_blade_mail: {
            type: "ability",
            icon: "rattletrap_power_cogs",
            label: "Power Cogs",
            desc: "3 engrenagens orbitam sem expirar. T arremessa uma carga por vez."
        },
        item_shivas_guard: {
            type: "ability",
            icon: "lich_frost_shield",
            label: "Frost Shield",
            desc: "Escudo por 8s. Pulsa slow de 35% a cada 1s em raio 600."
        },
        item_sheepstick: {
            type: "ability",
            icon: "lich_chain_frost",
            label: "Chain Frost",
            desc: "Orbe teleguiado. Salta ate 10 vezes e aplica slow de 65% por 2.5s."
        },
        item_wind_waker: {
            type: "ability",
            icon: "invoker_tornado",
            label: "Tornado",
            desc: "Tornado em linha ate 4000. Levanta karts por 3.5s e bloqueia movimento/itens."
        },
        item_mage_slayer: {
            type: "ability",
            icon: "tusk_ice_shards",
            label: "Ice Shards",
            desc: "Cria 7 shards por 5s. Se acertar kart, cria barreira na frente dele."
        },
        item_spell_steal: {
            type: "ability",
            icon: "rubick_spell_steal",
            label: "Item Steal",
            desc: "Procura por 5s um item adversário. Ao roubar, ambos mostram Spell Steal por 2s."
        },
        item_basher: {
            type: "ability",
            icon: "chaos_knight_chaos_bolt",
            label: "Chaos Bolt",
            desc: "Range 1200. Projétil teleguiado em arco. Stun aleatório de 1.5s a 6s."
        },
        item_glimmer_cape: {
            type: "ability",
            icon: "bounty_hunter_wind_walk",
            label: "Invisibility",
            desc: "Invisível por 15s. Projéteis teleguiados ignoram você."
        },
        item_kaya: {
            type: "ability",
            icon: "invoker_ice_wall",
            label: "Ice Wall",
            desc: "Deixa rastro de gelo por 5s. Rivais em contato recebem 60% slow."
        },
        item_dotakart_burrowstrike: {
            type: "ability",
            icon: "sandking_burrowstrike",
            label: "Burrowstrike",
            desc: "Spikes em linha; teleporta no fim, mantém velocidade e atordoa rivais."
        },
        item_dotakart_natures_grasp: {
            type: "ability",
            icon: "treant_natures_grasp",
            label: "Nature's Grasp",
            desc: "Cria uma linha de vinhas que aplicam root em karts adversários."
        },
        item_dotakart_bloodlust: {
            type: "ability",
            icon: "ogre_magi_bloodlust",
            label: "Bloodlust",
            desc: "Aumenta velocidade e tamanho do kart por 15s, com chance de Multicast."
        },
        item_dotakart_unstable_concoction: {
            type: "ability",
            icon: "alchemist_unstable_concoction",
            label: "Unstable Concoction",
            desc: "Prepara mistura instável; use de novo para arremessar antes de explodir."
        },
        item_dotakart_unstable_concoction_throw: {
            type: "ability",
            icon: "alchemist_unstable_concoction_throw",
            label: "Concoction Throw",
            desc: "Arremessa a mistura preparada."
        },
        item_dotakart_spectral_dagger: {
            type: "ability",
            icon: "spectre_spectral_dagger",
            label: "Spectral Dagger",
            desc: "Adaga teleguiada que cria Shadow Path; inimigos no caminho recebem slow."
        },
        item_dotakart_battle_hunger: {
            type: "ability",
            icon: "axe_battle_hunger",
            label: "Battle Hunger",
            desc: "+10% velocidade em você e -10% no rival 1 posição à frente por 15s. S+T mira atrás; acertar outro kart com item quebra o efeito."
        },
        item_dotakart_x_marks: {
            type: "ability",
            icon: "kunkka_x_marks_the_spot",
            label: "X Marks the Spot",
            desc: "Projétil range 2000; marca por 5s e retorna o kart ao X. S+T lança para trás."
        },
        item_dotakart_doppelwalk: { type: "ability", icon: "phantom_lancer_doppelwalk", label: "Doppelwalk", desc: "8s invisibility, +10% max speed and a moving decoy that can fool homing items." },
        item_dotakart_shukuchi: { type: "ability", icon: "weaver_shukuchi", label: "Shukuchi", desc: "Disjoints homing items, becomes invisible/phased and gains 1.5x max speed for 4s; stuns racers passed through." },
        item_dotakart_crystal_clone: { type: "ability", icon: "crystal_maiden_crystal_clone", label: "Crystal Clone", desc: "Places a 90s Crystal Maiden clone that explodes on kart/projectile contact and Frostbites nearby racers." },
        item_dotakart_astral_imprisonment: { type: "ability", icon: "obsidian_destroyer_astral_imprisonment", label: "Astral Imprisonment", desc: "Imprisons an adjacent-position rival for 4s; Q self-casts for mobile invulnerable protection." },
        item_dotakart_ball_lightning: { type: "ability", icon: "storm_spirit_ball_lightning", label: "Ball Lightning", desc: "Press T to activate; press T again to stop while preserving remaining charges. Reaching 0 charges removes the item and leaves a Static Remnant." },
        item_dotakart_homing_missile: { type: "ability", icon: "gyrocopter_homing_missile", label: "Homing Missile", desc: "Tracks the racer one place ahead through the course; S+T targets one place behind. Longer travel means a longer stun." },
        item_dotakart_plague_ward: { type: "ability", icon: "venomancer_plague_ward", label: "Plague Ward", desc: "Orbits for 45s, blocks enemy projectiles and fires poison shots that slow without dealing damage." },
        item_dotakart_the_swarm: { type: "ability", icon: "weaver_the_swarm", label: "The Swarm", desc: "Launches Beetles that latch onto enemy karts and build 3% movement slow every second for 16s." },
        item_dotakart_storm_hammer: { type: "ability", icon: "sven_storm_bolt", label: "Storm Hammer", desc: "1700 range; stuns racers in a 300 AoE for 2.5s. Forward casts carry the kart only when a racer or Item Box target is acquired; S+T throws backward." },
        item_dotakart_illusory_orb: { type: "ability", icon: "puck_illusory_orb", label: "Illusory Orb", desc: "Launches a slowing orb; press T again to teleport to it and create a short Dream Coil." },
        item_dotakart_torrent_storm: {
            type: "ability",
            icon: "kunkka_torrent",
            label: "Torrent Storm",
            desc: "Cria um Torrent a cada 0.25s por 5s ao redor do kart; cada um avisa 1.6s antes de lançar inimigos ao ar e aplicar 40% slow."
        }
    };

    function Find(id) {
        id = String(id || "").replace("#", "");
        return $.GetContextPanel().FindChildTraverse(id);
    }

    function ToNumber(value, fallback) {
        var n = Number(value);
        return isNaN(n) ? fallback : n;
    }

    function Clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value));
    }

    var DOTA_KART_NITRO_ICON_FILES = {
        // FIX106: usar o PNG original em content/materials; o Source 2 Resource
        // resolve para o VTEX compilado em game/materials/items/nitro.
        // Não usar *_png.vtex_c nem hash compilado direto no Panorama.
        nitro_1: "s2r://materials/items/nitro/1Nitro.png",
        nitro_2: "s2r://materials/items/nitro/2Nitro.png",
        nitro_3: "s2r://materials/items/nitro/3Nitro.png"
    };

    function ResolveCustomImagePath(icon) {
        icon = String(icon || "");

        if (icon === "nitro_1" || icon.indexOf("nitro_1") !== -1 || icon.indexOf("1nitro") !== -1) return DOTA_KART_NITRO_ICON_FILES.nitro_1;
        if (icon === "nitro_2" || icon.indexOf("nitro_2") !== -1 || icon.indexOf("2nitro") !== -1) return DOTA_KART_NITRO_ICON_FILES.nitro_2;
        if (icon === "nitro_3" || icon.indexOf("nitro_3") !== -1 || icon.indexOf("3nitro") !== -1) return DOTA_KART_NITRO_ICON_FILES.nitro_3;

        return icon;
    }

    function SetCustomImageSafe(panel, icon) {
        if (!panel) return;
        icon = ResolveCustomImagePath(icon);

        try { if (panel.SetImage) panel.SetImage(icon); } catch (e1) {}
        try { panel.src = icon; } catch (e2) {}
        try { panel.style.backgroundImage = 'url("' + icon + '")'; } catch (e3) {}
        try { panel.style.backgroundSize = "100% 100%"; } catch (e4) {}
    }

    function GetHeroIconName(heroName) {
        heroName = String(heroName || "");
        // FIX105: DOTAHeroImage não conhece o herói custom npc_dota_hero_dotakart_invoker;
        // usar o retrato padrão do Invoker no placar em tempo real, minimapa e finish screen.
        if (heroName === "npc_dota_hero_dotakart_invoker") return "npc_dota_hero_invoker";
        if (heroName === "dotakart_invoker") return "npc_dota_hero_invoker";
        return heroName || "npc_dota_hero_wisp";
    }

    function FormatRaceTime(totalMs) {
        totalMs = Math.max(0, Math.floor(ToNumber(totalMs, 0)));
        var minutes = Math.floor(totalMs / 60000);
        var seconds = Math.floor((totalMs % 60000) / 1000);
        var centis = Math.floor((totalMs % 1000) / 10);

        var mm = minutes < 10 ? "0" + minutes : "" + minutes;
        var ss = seconds < 10 ? "0" + seconds : "" + seconds;
        var cc = centis < 10 ? "0" + centis : "" + centis;

        return mm + "'" + ss + "\"" + cc;
    }

    function OrdinalSuffix(place) {
        place = Math.floor(ToNumber(place, 1));
        if (place === 1) return "st";
        if (place === 2) return "nd";
        if (place === 3) return "rd";
        return "th";
    }

    function SetLabelText(id, text) {
        var panel = Find(id);
        if (panel) panel.text = String(text);
    }

    function SetClass(panel, className, enabled) {
        if (panel) panel.SetHasClass(className, !!enabled);
    }

    function DisableDefaultElement(elementName) {
        if (typeof GameUI === "undefined") return;
        if (!GameUI.SetDefaultUIEnabled) return;
        if (typeof DotaDefaultUIElement_t === "undefined") return;
        if (DotaDefaultUIElement_t[elementName] === undefined) return;

        GameUI.SetDefaultUIEnabled(DotaDefaultUIElement_t[elementName], false);
    }

    function TryHideDefaultDotaHud() {
        if (!HIDE_DEFAULT_DOTA_HUD) return;

        var elements = [
            "DOTA_DEFAULT_UI_TOP_TIMEOFDAY",
            "DOTA_DEFAULT_UI_TOP_HEROES",
            "DOTA_DEFAULT_UI_FLYOUT_SCOREBOARD",
            "DOTA_DEFAULT_UI_ACTION_PANEL",
            "DOTA_DEFAULT_UI_ACTION_MINIMAP",
            "DOTA_DEFAULT_UI_INVENTORY_PANEL",
            "DOTA_DEFAULT_UI_INVENTORY_SHOP",
            "DOTA_DEFAULT_UI_INVENTORY_ITEMS",
            "DOTA_DEFAULT_UI_INVENTORY_QUICKBUY",
            "DOTA_DEFAULT_UI_INVENTORY_COURIER",
            "DOTA_DEFAULT_UI_INVENTORY_PROTECT",
            "DOTA_DEFAULT_UI_INVENTORY_GOLD",
            "DOTA_DEFAULT_UI_SHOP_SUGGESTEDITEMS"
        ];

        for (var i = 0; i < elements.length; i++) {
            DisableDefaultElement(elements[i]);
        }

        var root = $.GetContextPanel();
        while (root.GetParent && root.GetParent()) {
            root = root.GetParent();
        }

        var idsToHide = [
            "topbar",
            "TopBar",
            "minimap_container",
            "GlyphScanContainer",
            "RoshanTimerContainer",
            "inventory",
            "inventory_container",
            "inventory_tpscroll_container",
            "quickbuy",
            "lower_hud",
            "center_with_stats"
        ];

        for (var j = 0; j < idsToHide.length; j++) {
            var p = root.FindChildTraverse(idsToHide[j]);
            if (p) {
                p.visible = false;
                p.style.visibility = "collapse";
            }
        }
    }

    function UpdateTopHud(state) {
        state = state || {};

        var lap = Math.max(1, Math.floor(ToNumber(state.lap, 1)));
        var maxLaps = Math.max(1, Math.floor(ToNumber(state.max_laps, state.maxLaps || 3)));
        SetLabelText("#DKLapText", lap + "/" + maxLaps);
        SetLabelText("#DKTimerText", FormatRaceTime(state.time_ms || state.timeMs || 0));

        var itemName = state.item || state.item_name || "";
        var itemBox = Find("#DKItemBox");
        var itemImage = Find("#DKItemImage");
        var abilityImage = Find("#DKAbilityImage");
        var customImage = Find("#DKCustomItemImage");
        var itemNameLabel = Find("#DKItemName");
        var itemDescLabel = Find("#DKItemDesc");
        var itemCharges = Math.floor(ToNumber(state.item_charges || state.itemCharges || state.charges || 0, 0));
        var chargeLabel = Find("#DKItemCharges");
        var hasItem = itemName && itemName !== "none" && itemName !== "";
        var hasCharges = hasItem && itemCharges > 1;
        var meta = ITEM_META[itemName] || { type: "item", icon: itemName, label: itemName, desc: "" };
        var isAbilityIcon = hasItem && meta.type === "ability";
        var isCustomIcon = hasItem && meta.type === "custom";

        SetClass(itemBox, "HasItem", hasItem);
        SetClass(itemBox, "NoItem", !hasItem);
        SetClass(itemBox, "HasCharges", hasCharges);

        if (itemImage) {
            itemImage.visible = !!(hasItem && !isAbilityIcon && !isCustomIcon);
            itemImage.style.visibility = (hasItem && !isAbilityIcon && !isCustomIcon) ? "visible" : "collapse";
            if (hasItem && !isAbilityIcon && !isCustomIcon) itemImage.itemname = meta.icon || itemName;
        }
        if (abilityImage) {
            abilityImage.visible = !!isAbilityIcon;
            abilityImage.style.visibility = isAbilityIcon ? "visible" : "collapse";
            if (isAbilityIcon) abilityImage.abilityname = meta.icon || "";
        }
        if (customImage) {
            customImage.visible = !!isCustomIcon;
            customImage.style.visibility = isCustomIcon ? "visible" : "collapse";
            if (isCustomIcon) {
                SetCustomImageSafe(customImage, meta.icon || "");
            }
        }
        if (chargeLabel) {
            chargeLabel.text = hasCharges ? ("x" + itemCharges) : "";
        }
        if (itemNameLabel) {
            itemNameLabel.text = hasItem ? (meta.label || itemName) : "";
        }
        if (itemDescLabel) {
            itemDescLabel.text = hasItem ? (meta.desc || "") : "";
        }
    }

    function UpdatePlace(state) {
        state = state || {};
        var place = Math.max(1, Math.floor(ToNumber(state.place || state.position, 1)));
        SetLabelText("#DKPlaceNumber", place);
        SetLabelText("#DKPlaceSuffix", OrdinalSuffix(place));
    }

    function CreateRacerRow(parent, index, racer, localPlayerID) {
        racer = racer || {};

        var row = $.CreatePanel("Panel", parent, "DKRacerRow" + index);
        row.AddClass("DKRacerRow");

        var place = Math.max(1, Math.floor(ToNumber(racer.place || racer.position || index, index)));
        var playerID = Math.floor(ToNumber(racer.player_id || racer.playerID, -1));
        row.SetHasClass("LocalPlayer", playerID === localPlayerID);

        var placeLabel = $.CreatePanel("Label", row, "DKRacerPlace" + index);
        placeLabel.AddClass("DKRacerPlace");
        placeLabel.text = String(place);

        var portrait = $.CreatePanel("DOTAHeroImage", row, "DKRacerPortrait" + index);
        portrait.AddClass("DKRacerPortrait");
        portrait.heroname = GetHeroIconName(racer.hero || racer.hero_name || "npc_dota_hero_wisp");
        // Use the wide Dota-style hero portrait shape for the left standings HUD.
        portrait.heroimagestyle = "landscape";
    }

    function UpdateStandings(racers) {
        var parent = Find("#DKStandings");
        if (!parent) return;

        parent.RemoveAndDeleteChildren();

        racers = racers || [];
        var list = [];

        if (racers.length === undefined) {
            for (var key in racers) {
                if (racers.hasOwnProperty(key)) list.push(racers[key]);
            }
        } else {
            list = racers;
        }

        list.sort(function (a, b) {
            return ToNumber(a.place || a.position, 999) - ToNumber(b.place || b.position, 999);
        });

        var localPlayerID = Players.GetLocalPlayer();
        var count = Math.min(MAX_RACERS_VISIBLE, list.length);
        for (var i = 0; i < count; i++) {
            CreateRacerRow(parent, i + 1, list[i], localPlayerID);
        }
    }

    function AsArray(obj) {
        var arr = [];
        if (!obj) return arr;

        if (obj.length !== undefined) {
            return obj;
        }

        for (var key in obj) {
            if (obj.hasOwnProperty(key)) {
                arr.push(obj[key]);
            }
        }
        return arr;
    }

    function MakeTrackHash(points, closed) {
        var s = closed ? "c" : "o";
        for (var i = 0; i < points.length; i++) {
            s += ";" + Math.round(ToNumber(points[i].x, 0) * 1000) + "," + Math.round(ToNumber(points[i].y, 0) * 1000);
        }
        return s;
    }

    function MiniX(nx) {
        return MINIMAP_PADDING + Clamp(nx, 0, 1) * (MINIMAP_W - MINIMAP_PADDING * 2);
    }

    function MiniY(ny) {
        return MINIMAP_PADDING + Clamp(ny, 0, 1) * (MINIMAP_H - MINIMAP_PADDING * 2);
    }

    function CreateTrackSegment(parent, index, x1, y1, x2, y2) {
        var dx = x2 - x1;
        var dy = y2 - y1;
        var length = Math.sqrt(dx * dx + dy * dy);
        if (length < 2) return;

        var angle = Math.atan2(dy, dx) * 180.0 / Math.PI;
        var midX = (x1 + x2) * 0.5;
        var midY = (y1 + y2) * 0.5;

        var seg = $.CreatePanel("Panel", parent, "DKMiniTrackLine" + index);
        seg.AddClass("DKMiniTrackLine");
        seg.style.width = Math.round(length) + "px";
        seg.style.height = TRACK_THICKNESS + "px";
        seg.style.position = Math.round(midX - length * 0.5) + "px " + Math.round(midY - TRACK_THICKNESS * 0.5) + "px 0px";
        seg.style.transform = "rotateZ(" + angle + "deg)";
    }

    function RenderTrackPath(trackData) {
        var parent = Find("#DKMiniTrackLines");
        if (!parent) return;

        trackData = trackData || {};
        var points = AsArray(trackData.points || trackData.path || []);
        var closed = trackData.closed === true || trackData.closed === 1 || trackData.closed === "1";

        // FIX13: não desenha mais a pista falsa de 8 pontos.
        // Se o servidor ainda não enviou os dk_track_* reais, mantém o minimap vazio
        // e pede refresh pelo evento dotakart_hud_client_ready.
        if (points.length < 2) {
            RequestHudRefresh();
            return;
        }

        var hash = MakeTrackHash(points, closed);
        if (hash === TRACK_HASH) return;
        TRACK_HASH = hash;

        parent.RemoveAndDeleteChildren();

        var pixelPoints = [];
        for (var i = 0; i < points.length; i++) {
            pixelPoints.push({
                x: MiniX(ToNumber(points[i].x, 0.5)),
                y: MiniY(ToNumber(points[i].y, 0.5))
            });
        }

        for (var j = 0; j < pixelPoints.length - 1; j++) {
            CreateTrackSegment(parent, j, pixelPoints[j].x, pixelPoints[j].y, pixelPoints[j + 1].x, pixelPoints[j + 1].y);
        }

        if (closed && pixelPoints.length > 2) {
            CreateTrackSegment(parent, pixelPoints.length, pixelPoints[pixelPoints.length - 1].x, pixelPoints[pixelPoints.length - 1].y, pixelPoints[0].x, pixelPoints[0].y);
        }

        $.Msg("[DotaKartHUD] Mini-map path renderizado: " + points.length + " pontos.");
    }

    function UpdateMiniMap(state) {
        state = state || {};
        var marker = Find("#DKMiniMarker");
        if (!marker) return;

        // map_x / map_y são coordenadas normalizadas pelo servidor: 0..1.
        var rawX = (state.map_x !== undefined) ? state.map_x : state.mapX;
        var rawY = (state.map_y !== undefined) ? state.map_y : state.mapY;
        var rawAngle = (state.map_angle !== undefined) ? state.map_angle : state.mapAngle;

        var nx = Clamp(ToNumber(rawX, 0.68), 0, 1);
        var ny = Clamp(ToNumber(rawY, 0.62), 0, 1);
        var angle = ToNumber(rawAngle, 0);

        var x = Math.floor(MiniX(nx) - 9);
        var y = Math.floor(MiniY(ny) - 7);

        marker.style.position = x + "px " + y + "px 0px";
        marker.style.transform = "rotateZ(" + angle + "deg)";
    }

    function UpdateMiniRacerMarkers(racers) {
        var parent = Find("#DKMiniRacerMarkers");
        if (!parent) return;

        parent.RemoveAndDeleteChildren();

        var list = AsArray(racers || []);
        if (!list || list.length <= 0) return;

        list.sort(function (a, b) {
            return ToNumber(a.place || a.position, 999) - ToNumber(b.place || b.position, 999);
        });

        var localPlayerID = Players.GetLocalPlayer();
        var count = Math.min(MAX_RACERS_VISIBLE, list.length);
        for (var i = 0; i < count; i++) {
            var racer = list[i] || {};
            var playerID = Math.floor(ToNumber(racer.player_id || racer.playerID, -999));
            var rawX = (racer.map_x !== undefined) ? racer.map_x : racer.mapX;
            var rawY = (racer.map_y !== undefined) ? racer.map_y : racer.mapY;

            if (rawX === undefined || rawY === undefined) continue;

            var nx = Clamp(ToNumber(rawX, 0.5), 0, 1);
            var ny = Clamp(ToNumber(rawY, 0.5), 0, 1);
            var x = Math.floor(MiniX(nx) - 12);
            var y = Math.floor(MiniY(ny) - 12);

            var marker = $.CreatePanel("Panel", parent, "DKMiniRacerMarker" + String(playerID) + "_" + String(i));
            marker.AddClass("DKMiniRacerMarker");
            marker.SetHasClass("LocalPlayer", playerID === localPlayerID);
            marker.SetHasClass("BotPlayer", playerID !== localPlayerID);
            marker.style.position = x + "px " + y + "px 0px";

            var portrait = $.CreatePanel("DOTAHeroImage", marker, "DKMiniRacerIcon" + String(playerID) + "_" + String(i));
            portrait.AddClass("DKMiniRacerIcon");
            portrait.heroname = GetHeroIconName(racer.hero || racer.hero_name || "npc_dota_hero_wisp");

            var placeLabel = $.CreatePanel("Label", marker, "DKMiniRacerPlace" + String(playerID) + "_" + String(i));
            placeLabel.AddClass("DKMiniRacerPlace");
            placeLabel.text = String(Math.max(1, Math.floor(ToNumber(racer.place || racer.position || (i + 1), i + 1))));
        }
    }


    var lastAnnouncedFinishPlace = -1;

    function GetPublicFinishName(r, fallbackIndex) {
        r = r || {};
        var pid = ToNumber(r.player_id, -999);

        if (r.player_name && String(r.player_name) !== "") return String(r.player_name);
        if (r.name && String(r.name) !== "") return String(r.name);

        try {
            if (typeof Players !== "undefined" && Players.GetPlayerName && pid >= 0) {
                var steamName = Players.GetPlayerName(pid);
                if (steamName && String(steamName) !== "") return String(steamName);
            }
        } catch (e) {}

        return "CPU " + String((pid >= 0 ? pid + 1 : fallbackIndex + 1));
    }

    function PlayLocalFinishPlaceSound(results) {
        // FIX44: anúncios de chegada usam eventos dotakart_announcer_place_01..08.
        // Toca somente o soundevent customizado para evitar missing resource de raw vsnd.
        try {
            var localPlayerID = Players.GetLocalPlayer();
            for (var i = 0; i < results.length; i++) {
                var r = results[i];
                if (ToNumber(r.player_id, -999) !== localPlayerID) continue;
                var place = ToNumber(r.place, 0);
                if (place >= 1 && place <= 8 && lastAnnouncedFinishPlace !== place) {
                    lastAnnouncedFinishPlace = place;
                    var two = place < 10 ? ("0" + place) : String(place);
                    var eventName = "dotakart_announcer_place_" + two;
                    var aliasName = "vo_announcer_ann_custom_place_" + two;
                    try { Game.EmitSound(eventName); } catch (e0) {}
                    try { $.DispatchEvent("PlaySoundEffect", eventName); } catch (e1) {}
                    try { Game.EmitSound(aliasName); } catch (e2) {}
                    try { $.DispatchEvent("PlaySoundEffect", aliasName); } catch (e3) {}
                }
                return;
            }
        } catch (e3) {}
    }

    function UpdateFinishScreen(data) {
        data = data || {};
        var screen = Find("#DKFinishScreen");
        var rows = Find("#DKFinishRows");
        if (!screen || !rows) return;

        var visible = data.visible === true || data.visible === 1 || data.visible === "1";
        // Segurança extra no cliente: mesmo se o servidor mandar update global por engano,
        // só mostra para o jogador local quando ele está na lista de finalizados.
        var localPlayerID = (typeof Players !== "undefined" && Players.GetLocalPlayer) ? Players.GetLocalPlayer() : -1;
        var results = AsArray(data.results || []);
        var localFinished = false;
        for (var f = 0; f < results.length; f++) {
            if (ToNumber((results[f] || {}).player_id, -999) === localPlayerID) {
                localFinished = true;
                break;
            }
        }
        visible = visible && localFinished;

        screen.SetHasClass("Visible", visible);
        if (!visible) {
            rows.RemoveAndDeleteChildren();
            return;
        }

        rows.RemoveAndDeleteChildren();
        results.sort(function (a, b) {
            return ToNumber(a.place, 999) - ToNumber(b.place, 999);
        });

        for (var i = 0; i < results.length; i++) {
            var r = results[i] || {};
            var row = $.CreatePanel("Panel", rows, "DKFinishRow" + i);
            row.AddClass("DKFinishRow");

            var place = $.CreatePanel("Label", row, "DKFinishPlace" + i);
            place.AddClass("DKFinishPlace");
            place.text = String(ToNumber(r.place, i + 1));

            var icon = $.CreatePanel("DOTAHeroImage", row, "DKFinishHeroIcon" + i);
            icon.AddClass("DKFinishHeroIcon");
            icon.heroname = GetHeroIconName(r.hero || r.hero_name || "npc_dota_hero_wisp");

            var name = $.CreatePanel("Label", row, "DKFinishName" + i);
            name.AddClass("DKFinishName");
            name.text = GetPublicFinishName(r, i);

            var time = $.CreatePanel("Label", row, "DKFinishTime" + i);
            time.AddClass("DKFinishTime");
            time.text = FormatRaceTime(ToNumber(r.time_ms, 0));
        }

        PlayLocalFinishPlaceSound(results);
    }

    function HasHudStateFields(data) {
        if (!data) return false;
        return data.lap !== undefined || data.max_laps !== undefined || data.maxLaps !== undefined ||
            data.time_ms !== undefined || data.timeMs !== undefined || data.place !== undefined ||
            data.position !== undefined || data.item !== undefined || data.item_name !== undefined ||
            data.map_x !== undefined || data.mapX !== undefined || data.map_y !== undefined || data.mapY !== undefined;
    }

    function UpdateDebug(state) {
        var debugText = Find("#DKDebugText");
        if (!debugText || !state || !state.debug) return;
        var box = Find("#DKDebugBox");
        if (box) box.style.visibility = "visible";
        debugText.text = String(state.debug);
    }

    function ApplyHudState(state) {
        UpdateTopHud(state);
        UpdatePlace(state);
        UpdateMiniMap(state);
        UpdateDebug(state);
    }

    function OnGameEventHudUpdate(data) {
        if (HasHudStateFields(data)) ApplyHudState(data || {});
        if (data && data.racers) {
            UpdateStandings(data.racers);
            UpdateMiniRacerMarkers(data.racers);
        }
        if (data && data.track) RenderTrackPath(data.track);
        if (data && data.finish) UpdateFinishScreen(data.finish);
    }

    function OnNetTableChanged(tableName, key, value) {
        if (tableName !== "dotakart_hud") return;

        var localPlayerID = Players.GetLocalPlayer();
        if (key === "state_" + localPlayerID || key === "state") {
            ApplyHudState(value || {});
        }

        if (key === "racers") {
            UpdateStandings(value || {});
        }

        if (key === "track") {
            RenderTrackPath(value || {});
        }
    }

    function ReadInitialTables() {
        var localPlayerID = Players.GetLocalPlayer();
        var state = CustomNetTables.GetTableValue("dotakart_hud", "state_" + localPlayerID) ||
                    CustomNetTables.GetTableValue("dotakart_hud", "state") || {};
        var racers = CustomNetTables.GetTableValue("dotakart_hud", "racers") || {};
        var track = CustomNetTables.GetTableValue("dotakart_hud", "track") || {};

        ApplyHudState(state);
        UpdateStandings(racers);
        RenderTrackPath(track);
    }

    function EnsureRootFullscreen() {
        var ctx = $.GetContextPanel();
        if (ctx && ctx.style) {
            ctx.style.width = "100%";
            ctx.style.height = "100%";
            ctx.style.overflow = "noclip";
        }
        var hud = Find("#DotaKartHUD");
        if (hud && hud.style) {
            hud.style.width = "100%";
            hud.style.height = "100%";
            hud.style.visibility = "visible";
            hud.visible = true;
        }
    }

    function RequestHudRefresh() {
        if (typeof GameEvents === "undefined") return;
        var playerID = -1;
        if (typeof Players !== "undefined" && Players.GetLocalPlayer) {
            playerID = Players.GetLocalPlayer();
        }
        GameEvents.SendCustomGameEventToServer("dotakart_hud_client_ready", {
            PlayerID: playerID,
            player_id: playerID
        });
    }

    function ScheduleHudRefreshRequests() {
        // Panorama pode carregar depois da corrida já ter enviado o path.
        // Por isso pedimos o estado completo várias vezes nos primeiros segundos.
        for (var i = 0; i < 12; i++) {
            (function (delay) {
                $.Schedule(delay, function () {
                    RequestHudRefresh();
                });
            })(0.15 + i * 0.50);
        }
    }

    function ShowLoadedDebug() {
        var box = Find("#DKDebugBox");
        var text = Find("#DKDebugText");
        if (!box || !text) return;
        box.style.visibility = "visible";
        text.text = "DotaKart HUD carregado";
        $.Schedule(5.0, function () {
            if (box) box.style.visibility = "collapse";
        });
    }

    function Init() {
        $.Msg("[DotaKartHUD] HUD carregado FIX44.");
        EnsureRootFullscreen();
        ShowLoadedDebug();
        TryHideDefaultDotaHud();

        GameEvents.Subscribe("dotakart_hud_update", OnGameEventHudUpdate);
        GameEvents.Subscribe("dotakart_finish_update", UpdateFinishScreen);

        if (USE_NET_TABLES) {
            ReadInitialTables();
            CustomNetTables.SubscribeNetTableListener("dotakart_hud", OnNetTableChanged);
        }

        ScheduleHudRefreshRequests();
    }

    Init();
})();

// ============================================================
// FIX26: roleta visual + som de spin/final.
// O servidor ainda manda o item fake no HUD em alta frequência, mas este bloco
// força uma sequência rápida de imagens local por ~2.5s e tenta tocar o loop da roleta.
// ============================================================
(function () {
    var activeLoops = {};
    var rouletteActive = false;
    var rouletteToken = 0;
    var rouletteItems = [
        "item_phase_boots",
        "item_yasha",
        "item_mask_of_madness",
        "item_black_king_bar",
        "item_force_staff",
        "item_blink",
        "item_hurricane_pike",
        "item_gungir",
        "item_cyclone",
        "item_shadow_blade",
        "item_orb_of_venom",
        "item_blade_mail",
        "item_shivas_guard",
        "item_sheepstick",
        "item_wind_waker",
        "item_mage_slayer",
        "item_spell_steal",
        "item_basher",
        "item_glimmer_cape",
        "item_kaya",
        "item_dotakart_burrowstrike",
        "item_dotakart_natures_grasp",
        "item_dotakart_bloodlust",
        "item_dotakart_unstable_concoction",
        "item_dotakart_spectral_dagger",
        "item_dotakart_battle_hunger",
        "item_dotakart_x_marks",
        "item_dotakart_doppelwalk",
        "item_dotakart_shukuchi",
        "item_dotakart_crystal_clone",
        "item_dotakart_astral_imprisonment",
        "item_dotakart_ball_lightning",
        "item_dotakart_homing_missile",
        "item_dotakart_plague_ward",
        "item_dotakart_the_swarm",
        "item_dotakart_storm_hammer",
        "item_dotakart_illusory_orb",
        "item_dotakart_torrent_storm"
    ];

    // ITEM_META do primeiro bloco é local àquele escopo; duplicamos o mínimo aqui para a roleta visual.
    var ROULETTE_ITEM_META = {
        item_phase_boots: { type: "custom", icon: "nitro_1", label: "1 Nitro" },
        item_yasha: { type: "custom", icon: "nitro_2", label: "2 Nitros" },
        item_mask_of_madness: { type: "custom", icon: "nitro_3", label: "3 Nitros" },
        item_black_king_bar: { type: "item", icon: "item_black_king_bar", label: "Estrelinha" },
        item_force_staff: { type: "ability", icon: "pudge_meat_hook", label: "Meat Hook" },
        item_blink: { type: "ability", icon: "rattletrap_hookshot", label: "Hookshot" },
        item_hurricane_pike: { type: "ability", icon: "mirana_leap", label: "Leap" },
        item_gungir: { type: "ability", icon: "mirana_arrow", label: "Sacred Arrow" },
        item_cyclone: { type: "ability", icon: "vengefulspirit_magic_missile", label: "Swap Missile" },
        item_shadow_blade: { type: "ability", icon: "spirit_breaker_charge_of_darkness", label: "Charge of Darkness" },
        item_orb_of_venom: { type: "ability", icon: "venomancer_venomous_gale", label: "Venomous Gale" },
        item_blade_mail: { type: "ability", icon: "rattletrap_power_cogs", label: "Power Cogs" },
        item_shivas_guard: { type: "ability", icon: "lich_frost_shield", label: "Frost Shield" },
        item_sheepstick: { type: "ability", icon: "lich_chain_frost", label: "Chain Frost" },
        item_wind_waker: { type: "ability", icon: "invoker_tornado", label: "Tornado" },
        item_mage_slayer: { type: "ability", icon: "tusk_ice_shards", label: "Ice Shards" },
        item_spell_steal: { type: "ability", icon: "rubick_spell_steal", label: "Item Steal" },
        item_basher: { type: "ability", icon: "chaos_knight_chaos_bolt", label: "Chaos Bolt" },
        item_glimmer_cape: { type: "ability", icon: "bounty_hunter_wind_walk", label: "Invisibility" },
        item_kaya: { type: "ability", icon: "invoker_ice_wall", label: "Ice Wall" },
        item_dotakart_burrowstrike: { type: "ability", icon: "sandking_burrowstrike", label: "Burrowstrike" },
        item_dotakart_natures_grasp: { type: "ability", icon: "treant_natures_grasp", label: "Nature's Grasp" },
        item_dotakart_bloodlust: { type: "ability", icon: "ogre_magi_bloodlust", label: "Bloodlust" },
        item_dotakart_unstable_concoction: { type: "ability", icon: "alchemist_unstable_concoction", label: "Unstable Concoction" },
        item_dotakart_unstable_concoction_throw: { type: "ability", icon: "alchemist_unstable_concoction_throw", label: "Concoction Throw" },
        item_dotakart_spectral_dagger: { type: "ability", icon: "spectre_spectral_dagger", label: "Spectral Dagger" },
        item_dotakart_battle_hunger: { type: "ability", icon: "axe_battle_hunger", label: "Battle Hunger" },
        item_dotakart_x_marks: { type: "ability", icon: "kunkka_x_marks_the_spot", label: "X Marks the Spot" },
        item_dotakart_doppelwalk: { type: "ability", icon: "phantom_lancer_doppelwalk", label: "Doppelwalk" },
        item_dotakart_shukuchi: { type: "ability", icon: "weaver_shukuchi", label: "Shukuchi" },
        item_dotakart_crystal_clone: { type: "ability", icon: "crystal_maiden_crystal_clone", label: "Crystal Clone" },
        item_dotakart_astral_imprisonment: { type: "ability", icon: "obsidian_destroyer_astral_imprisonment", label: "Astral Imprisonment" },
        item_dotakart_ball_lightning: { type: "ability", icon: "storm_spirit_ball_lightning", label: "Ball Lightning" },
        item_dotakart_homing_missile: { type: "ability", icon: "gyrocopter_homing_missile", label: "Homing Missile" },
        item_dotakart_plague_ward: { type: "ability", icon: "venomancer_plague_ward", label: "Plague Ward" },
        item_dotakart_the_swarm: { type: "ability", icon: "weaver_the_swarm", label: "The Swarm" },
        item_dotakart_storm_hammer: { type: "ability", icon: "sven_storm_bolt", label: "Storm Hammer" },
        item_dotakart_illusory_orb: { type: "ability", icon: "puck_illusory_orb", label: "Illusory Orb" },
        item_dotakart_torrent_storm: { type: "ability", icon: "kunkka_torrent", label: "Torrent Storm" }
    };

    function UniquePush(arr, v) {
        if (!v) return;
        v = String(v);
        for (var i = 0; i < arr.length; i++) {
            if (arr[i] === v) return;
        }
        arr.push(v);
    }

    function BuildSoundAliases(sound) {
        var aliases = [];
        sound = String(sound || "");
        UniquePush(aliases, sound);

        var noExt = sound.replace(/\.vsnd$/i, "");
        UniquePush(aliases, noExt);
        UniquePush(aliases, noExt.replace(/^sounds\//i, ""));
        UniquePush(aliases, noExt.replace(/^sounds\//i, "").replace(/\//g, "."));
        UniquePush(aliases, noExt.replace(/^sounds\//i, "").replace(/\//g, "_"));
        UniquePush(aliases, noExt.split("/").pop());

        // FIX102: soundevents customizados do DotA Kart + raw .vsnd lower-case, sem _c.
        if (sound.indexOf("dotakart_announcer_place_") !== -1) {
            UniquePush(aliases, sound);
            var mPlace = sound.match(/dotakart_announcer_place_(\d+)/);
            if (mPlace && mPlace[1]) {
                var p2 = mPlace[1];
                if (p2.length === 1) p2 = "0" + p2;
                UniquePush(aliases, "sounds/vo_announcer_ann_custom_place_" + p2 + ".vsnd");
                UniquePush(aliases, "vo_announcer_ann_custom_place_" + p2);
            }
        }
        if (sound.indexOf("engine_idle") !== -1 || sound.indexOf("dotakart_engine_idle") !== -1) {
            UniquePush(aliases, "sounds/dotakart/kart engine/engine_idle.vsnd");
            UniquePush(aliases, "dotakart_engine_idle");
        }
        if (sound.indexOf("dotakart_lap_complete") !== -1) {
            UniquePush(aliases, "dotakart_lap_complete");
            UniquePush(aliases, "sounds/ui/treasure_01.vsnd");
        }
        if (sound.indexOf("dotakart_final_lap") !== -1) {
            UniquePush(aliases, "dotakart_final_lap");
            UniquePush(aliases, "sounds/items/black_king_bar.vsnd");
        }

        if (sound.indexOf("dotakart_itembox_spin_loop") !== -1) {
            UniquePush(aliases, "dotakart_itembox_spin_loop");
            UniquePush(aliases, "sounds/rylais_wheel_spin_02_lp.vsnd");
        }
        if (sound.indexOf("dotakart_itembox_crate_break") !== -1) {
            UniquePush(aliases, "dotakart_itembox_crate_break");
            UniquePush(aliases, "sounds/wood_crate_break_03.vsnd");
        }
        if (sound.indexOf("rylais_wheel_spin_02_lp") !== -1 || sound.indexOf("rylais_wheel_spin_01_lp") !== -1) {
            UniquePush(aliases, "ui.economy.rylais_wheel_spin_02_lp");
            UniquePush(aliases, "economy.rylais_wheel_spin_02_lp");
            UniquePush(aliases, "rylais_wheel_spin_02_lp");
            UniquePush(aliases, "ui.economy.rylais_wheel_spin_01_lp");
            UniquePush(aliases, "economy.rylais_wheel_spin_01_lp");
            UniquePush(aliases, "rylais_wheel_spin_01_lp");
            UniquePush(aliases, "Rylai.Wheel.Spin");
            UniquePush(aliases, "Rylai_Wheel_Spin");
            UniquePush(aliases, "UI.RylaiWheel.Spin");
        }

        if (sound.indexOf("mirana/leap") !== -1 || sound.indexOf("mirana.leap") !== -1) {
            UniquePush(aliases, "Hero_Mirana.Leap");
            UniquePush(aliases, "Hero_Mirana.Leap.Cast");
            UniquePush(aliases, "Hero_Mirana.Leap1");
            UniquePush(aliases, "Hero_Mirana.Leap2");
            UniquePush(aliases, "Hero_Mirana.Leap3");
            UniquePush(aliases, "Hero_Mirana.Leap4");
            UniquePush(aliases, "Hero_Mirana.Leap.Start");
            UniquePush(aliases, "Hero_Mirana.Leap.End");
            UniquePush(aliases, "Ability.MiranaLeap");
            UniquePush(aliases, "Mirana.Leap");
            UniquePush(aliases, "mirana_leap");
            UniquePush(aliases, "mirana.leap1");
            UniquePush(aliases, "mirana.leap2");
            UniquePush(aliases, "mirana.leap3");
            UniquePush(aliases, "mirana.leap4");
        }

        if (sound.indexOf("burrow") !== -1 || sound.indexOf("sand_king") !== -1 || sound.indexOf("SandKing") !== -1 || sound.indexOf("Sandking") !== -1) {
            UniquePush(aliases, "dotakart_burrowstrike_cast");
            UniquePush(aliases, "Hero_SandKing.BurrowStrike");
            UniquePush(aliases, "Hero_Sandking.BurrowStrike");
            UniquePush(aliases, "Hero_SandKing.BurrowStrike.Target");
            UniquePush(aliases, "Hero_Sandking.BurrowStrike.Target");
            UniquePush(aliases, "Ability.SandKing_BurrowStrike");
            UniquePush(aliases, "sounds/weapons/hero/sand_king/sand_king_burrow_attack.vsnd");
            UniquePush(aliases, "sand_king_burrow_attack");
        }

        // FIX93: Spectral Dagger UI fallback aliases. Primeiro tenta os .vsnd nativos
        // confirmados no Asset Browser, depois aliases/soundevents.
        if (sound.indexOf("spectre") !== -1 || sound.indexOf("Spectre") !== -1 || sound.indexOf("spectral_dagger") !== -1 || sound.indexOf("spectraldagger") !== -1 || sound.indexOf("dagger_cast") !== -1 || sound.indexOf("dagger_impact") !== -1) {
            UniquePush(aliases, "sounds/weapons/hero/spectre/dagger_cast.vsnd");
            UniquePush(aliases, "sounds/weapons/hero/spectre/dagger_impact.vsnd");
            UniquePush(aliases, "weapons.hero.spectre.dagger_cast");
            UniquePush(aliases, "weapons.hero.spectre.dagger_impact");
            UniquePush(aliases, "dagger_cast");
            UniquePush(aliases, "dagger_impact");
            UniquePush(aliases, "dotakart_spectral_dagger_cast_2d");
            UniquePush(aliases, "dotakart_spectral_dagger_impact_2d");
            UniquePush(aliases, "dotakart_spectral_dagger_cast");
            UniquePush(aliases, "dotakart_spectral_dagger_impact");
            UniquePush(aliases, "Hero_Spectre.DaggerCast");
            UniquePush(aliases, "Hero_Spectre.DaggerImpact");
            UniquePush(aliases, "Hero_Spectre.SpectralDagger");
            UniquePush(aliases, "Hero_Spectre.SpectralDagger.Cast");
            UniquePush(aliases, "Hero_Spectre.SpectralDagger.Impact");
        }

        if (sound.indexOf("treasure_01") !== -1) {
            UniquePush(aliases, "ui.treasure_01");
            UniquePush(aliases, "treasure_01");
            UniquePush(aliases, "Treasure.Open");
            UniquePush(aliases, "UI.Treasure.Open");
        }

        // FIX39: aliases extras para sons do Lich usados nos itens Frost Shield / Chain Frost.
        if (sound.indexOf("lich/frost_armor") !== -1 || sound.indexOf("frost_armor") !== -1) {
            UniquePush(aliases, "Hero_Lich.FrostArmor");
            UniquePush(aliases, "Hero_Lich.FrostArmor.Cast");
            UniquePush(aliases, "Hero_Lich.FrostArmorDamage");
            UniquePush(aliases, "Hero_Lich.IceArmor");
            UniquePush(aliases, "Hero_Lich.IceArmor.Cast");
            UniquePush(aliases, "Hero_Lich.IceArmorDamage");
            UniquePush(aliases, "Hero_Lich.FrostShield");
            UniquePush(aliases, "Hero_Lich.FrostShield.Cast");
            UniquePush(aliases, "Hero_Lich.FrostShield.Target");
            UniquePush(aliases, "Hero_Lich.FrostShield.Pulse");
        }

        if (sound.indexOf("lich/chain_frost") !== -1 || sound.indexOf("chain_frost") !== -1) {
            UniquePush(aliases, "Hero_Lich.ChainFrost");
            UniquePush(aliases, "Hero_Lich.ChainFrost.Cast");
            UniquePush(aliases, "Hero_Lich.ChainFrostLoop");
            UniquePush(aliases, "Hero_Lich.ChainFrost.Loop");
            UniquePush(aliases, "Hero_Lich.ChainFrost.Projectile");
            UniquePush(aliases, "Hero_Lich.ChainFrostImpact");
            UniquePush(aliases, "Hero_Lich.ChainFrost.Impact");
            UniquePush(aliases, "Hero_Lich.ChainFrost.Target");
        }

        if (sound.indexOf("alchemist") !== -1 || sound.indexOf("Concoction") !== -1 || sound.indexOf("concoction") !== -1) {
            UniquePush(aliases, "dotakart_unstable_concoction_fuse");
            UniquePush(aliases, "dotakart_unstable_concoction_throw");
            UniquePush(aliases, "dotakart_unstable_concoction_stun");
            UniquePush(aliases, "sounds/weapons/hero/alchemist/unstable_concoction_fuse.vsnd");
            UniquePush(aliases, "sounds/weapons/hero/alchemist/unstable_concoction_throw.vsnd");
            UniquePush(aliases, "sounds/weapons/hero/alchemist/unstable_concoction_stun01.vsnd");
        }
        return aliases;
    }

    var soundHandles = {};
    var rouletteSpinSound = null;

    function TryEmit(alias) {
        // Game.EmitSound aceita string, mas Game.StopSound espera o HANDLE numérico retornado.
        // Nunca passe string para Game.StopSound: isso quebrava o hud.js no FIX27.
        try {
            if (Game && Game.EmitSound) {
                var h = Game.EmitSound(alias);
                if (typeof h === "number") {
                    if (!soundHandles[alias]) soundHandles[alias] = [];
                    soundHandles[alias].push(h);
                }
            }
        } catch (e1) {}
        try { $.DispatchEvent("PlaySoundEffect", alias); } catch (e2) {}
    }

    function TryStop(alias) {
        // StopSoundEffect aceita nome do evento; Game.StopSound NÃO.
        try { $.DispatchEvent("StopSoundEffect", alias); } catch (e2) {}
        try {
            if (Game && Game.StopSound && soundHandles[alias]) {
                for (var i = 0; i < soundHandles[alias].length; i++) {
                    var h = soundHandles[alias][i];
                    if (typeof h === "number") Game.StopSound(h);
                }
                soundHandles[alias] = [];
            }
        } catch (e1) {}
    }

    function PlaySoundMany(sound) {
        var aliases = BuildSoundAliases(sound);
        for (var i = 0; i < aliases.length; i++) TryEmit(aliases[i]);
    }

    function StopSoundMany(sound) {
        var aliases = BuildSoundAliases(sound);
        for (var i = 0; i < aliases.length; i++) TryStop(aliases[i]);
    }

    function StartRouletteSpinSound(spinSound) {
        rouletteSpinSound = spinSound || "dotakart_itembox_spin_loop";
        // FIX112: o novo spin é um soundevent custom. Toca somente o evento canônico para
        // não duplicar áudio tocando simultaneamente o evento e o raw .vsnd fallback.
        StopSoundMany(rouletteSpinSound);
        if (rouletteSpinSound === "dotakart_itembox_spin_loop") {
            TryEmit(rouletteSpinSound);
        } else {
            PlaySoundMany(rouletteSpinSound);
        }
    }

    function StopRouletteSpinSound() {
        if (!rouletteSpinSound) return;
        StopSoundMany(rouletteSpinSound);
        rouletteSpinSound = null;
    }

    function PlayRouletteTickPulse() {
        // Tick curto para reforçar a sensação da roleta sem empilhar o loop de spin.
        TryEmit("General.ButtonClick");
    }

    function SetCustomRouletteImageSafe(panel, icon) {
        SetCustomImageSafe(panel, icon);
    }

    function PlayUISound(data) {
        if (!data || !data.sound) return;
        var sound = String(data.sound);
        var action = data.action ? String(data.action) : "play";
        var duration = data.duration ? Number(data.duration) : 0;

        try {
            if (action === "stop_loop") {
                StopSoundMany(sound);
                activeLoops[sound] = false;
                return;
            }

            PlaySoundMany(sound);

            if (action === "start_loop") {
                activeLoops[sound] = true;
                if (duration > 0) {
                    $.Schedule(duration + 0.05, function () {
                        if (!activeLoops[sound]) return;
                        StopSoundMany(sound);
                        activeLoops[sound] = false;
                    });
                }
            }
        } catch (e) {
            $.Msg("[DotaKartHUD FIX28] Falha ao tocar som UI: " + sound + " err=" + e);
        }
    }

    function SetRouletteVisualItem(itemName) {
        var itemBox = $.GetContextPanel().FindChildTraverse("DKItemBox");
        var itemImage = $.GetContextPanel().FindChildTraverse("DKItemImage");
        var abilityImage = $.GetContextPanel().FindChildTraverse("DKAbilityImage");
        var customImage = $.GetContextPanel().FindChildTraverse("DKCustomItemImage");
        var itemNameLabel = $.GetContextPanel().FindChildTraverse("DKItemName");
        var itemDescLabel = $.GetContextPanel().FindChildTraverse("DKItemDesc");
        var chargeLabel = $.GetContextPanel().FindChildTraverse("DKItemCharges");
        var meta = ROULETTE_ITEM_META[itemName] || { type: "item", icon: itemName, label: itemName, desc: "Sorteando..." };
        var isAbilityIcon = meta.type === "ability";
        var isCustomIcon = meta.type === "custom";

        if (itemBox) {
            itemBox.SetHasClass("HasItem", true);
            itemBox.SetHasClass("NoItem", false);
            itemBox.SetHasClass("RouletteRolling", true);
        }
        if (itemImage) {
            itemImage.visible = !isAbilityIcon && !isCustomIcon;
            itemImage.style.visibility = (!isAbilityIcon && !isCustomIcon) ? "visible" : "collapse";
            if (!isAbilityIcon && !isCustomIcon) itemImage.itemname = meta.icon || itemName;
        }
        if (abilityImage) {
            abilityImage.visible = isAbilityIcon;
            abilityImage.style.visibility = isAbilityIcon ? "visible" : "collapse";
            if (isAbilityIcon) abilityImage.abilityname = meta.icon || "";
        }
        if (customImage) {
            customImage.visible = isCustomIcon;
            customImage.style.visibility = isCustomIcon ? "visible" : "collapse";
            if (isCustomIcon) {
                SetCustomRouletteImageSafe(customImage, meta.icon || "");
            }
        }
        if (itemNameLabel) itemNameLabel.text = meta.label || itemName;
        if (itemDescLabel) itemDescLabel.text = "Sorteando item...";
        if (chargeLabel) chargeLabel.text = "";
    }

    function StartRouletteFX(data) {
        rouletteToken++;
        var token = rouletteToken;
        rouletteActive = true;
        var duration = data && data.duration ? Number(data.duration) : 2.5;
        if (!duration || duration <= 0) duration = 2.5;
        var start = (Game && Game.GetGameTime) ? Game.GetGameTime() : (Date.now() / 1000.0);
        var step = 0;
        var spinSound = (data && data.spin_sound) || "dotakart_itembox_spin_loop";

        // FIX56: restaura o spin antigo 01_lp sem empilhar vários loops ao longo dos 2.5s.
        StartRouletteSpinSound(spinSound);

        function tick() {
            if (!rouletteActive || token !== rouletteToken) return;
            var now = (Game && Game.GetGameTime) ? Game.GetGameTime() : (Date.now() / 1000.0);
            if (now - start >= duration) return;

            var itemName = rouletteItems[step % rouletteItems.length];
            SetRouletteVisualItem(itemName);
            if ((step % 2) === 0) PlayRouletteTickPulse();
            step++;
            $.Schedule(0.065, tick);
        }
        tick();

        $.Schedule(duration + 0.05, function () {
            if (token !== rouletteToken) return;
            rouletteActive = false;
            StopRouletteSpinSound();
            var itemBox = $.GetContextPanel().FindChildTraverse("DKItemBox");
            if (itemBox) itemBox.SetHasClass("RouletteRolling", false);
        });
    }

    function FinishRouletteFX(data) {
        rouletteActive = false;
        rouletteToken++;
        StopRouletteSpinSound();
        PlaySoundMany((data && data.done_sound) || "sounds/ui/treasure_01.vsnd");
        var itemBox = $.GetContextPanel().FindChildTraverse("DKItemBox");
        if (itemBox) itemBox.SetHasClass("RouletteRolling", false);
    }

    function OnRouletteFX(data) {
        data = data || {};
        if (String(data.phase || "start") === "done") {
            FinishRouletteFX(data);
        } else {
            StartRouletteFX(data);
        }
    }

    if (typeof GameEvents !== "undefined") {
        GameEvents.Subscribe("dotakart_ui_sound", PlayUISound);
        GameEvents.Subscribe("dotakart_roulette_fx", OnRouletteFX);
    }
})();

// ============================================================
// FIX57: Chaos Bolt stun text above victim, visible only to clients
// whose camera/screen can render the victim.
// ============================================================
(function () {
    "use strict";

    function Find(id) {
        return $.GetContextPanel().FindChildTraverse(id.replace(/^#/, ""));
    }

    function GetChaosWorldPos(data) {
        data = data || {};
        var ent = Number(data.entindex || -1);
        try {
            if (ent >= 0 && typeof Entities !== "undefined" && Entities.GetAbsOrigin) {
                var o = Entities.GetAbsOrigin(ent);
                if (o && o.length >= 3) return [Number(o[0]), Number(o[1]), Number(o[2]) + 230];
            }
        } catch (e) {}
        return [Number(data.x || 0), Number(data.y || 0), Number(data.z || 0)];
    }

    function GetLocalPlayerIDSafe() {
        try {
            if (typeof Game !== "undefined" && Game.GetLocalPlayerID) return Number(Game.GetLocalPlayerID());
        } catch (e) {}
        return -1;
    }

    function IsEntityVisibleToLocalPlayer(ent) {
        if (ent < 0 || typeof Entities === "undefined") return true;
        var localPlayerID = GetLocalPlayerIDSafe();

        // Panorama APIs variam por build. Tenta as versões conhecidas com pcall JS.
        try {
            if (Entities.IsVisibleToPlayer && localPlayerID >= 0) {
                return !!Entities.IsVisibleToPlayer(ent, localPlayerID);
            }
        } catch (e1) {}
        try {
            if (Entities.IsEntityVisibleToPlayer && localPlayerID >= 0) {
                return !!Entities.IsEntityVisibleToPlayer(ent, localPlayerID);
            }
        } catch (e2) {}
        try {
            if (Entities.IsVisible && typeof Entities.IsVisible(ent) !== "undefined") {
                return !!Entities.IsVisible(ent);
            }
        } catch (e3) {}

        // Se a API de fog/visão não existir, o teste de tela abaixo ainda impede texto no centro para todos.
        return true;
    }

    function GetScreenSize(root) {
        var w = 0;
        var h = 0;
        try { w = Number($.GetContextPanel().actuallayoutwidth || 0); } catch (e1) {}
        try { h = Number($.GetContextPanel().actuallayoutheight || 0); } catch (e2) {}
        if ((!w || !h) && root) {
            try { w = Number(root.actuallayoutwidth || w || 0); } catch (e3) {}
            try { h = Number(root.actuallayoutheight || h || 0); } catch (e4) {}
        }
        if (!w || w <= 0) w = 1920;
        if (!h || h <= 0) h = 1080;
        return { w: w, h: h };
    }

    function WorldToScreenStrict(pos, root) {
        var x = -1;
        var y = -1;
        try {
            if (typeof Game !== "undefined" && Game.WorldToScreenX && Game.WorldToScreenY) {
                x = Number(Game.WorldToScreenX(pos[0], pos[1], pos[2]));
                y = Number(Game.WorldToScreenY(pos[0], pos[1], pos[2]));
            }
        } catch (e) {
            x = -1;
            y = -1;
        }

        var size = GetScreenSize(root);
        var margin = 24;
        if (isNaN(x) || isNaN(y)) return null;
        if (x < margin || y < margin || x > size.w - margin || y > size.h - margin) return null;
        return { x: x, y: y };
    }

    function ShowChaosStunText(data) {
        data = data || {};
        var root = Find("#DKFloatingTextRoot");
        if (!root) return;

        var ent = Number(data.entindex || -1);
        var dur = Math.max(0.6, Number(data.duration || 1.8));
        var start = (Game && Game.GetGameTime) ? Game.GetGameTime() : (Date.now() / 1000.0);
        var label = null;

        function ensureLabel() {
            if (label && label.IsValid && label.IsValid()) return label;
            label = $.CreatePanel("Label", root, "DKChaosStunText_" + String(Date.now()));
            label.AddClass("DKChaosStunText");
            label.text = String(data.text || "STUN");
            label.visible = false;
            return label;
        }

        function updatePosition() {
            var now = (Game && Game.GetGameTime) ? Game.GetGameTime() : (Date.now() / 1000.0);
            if (now - start >= dur) {
                if (label && label.DeleteAsync) label.DeleteAsync(0.0);
                return;
            }

            var p = GetChaosWorldPos(data);
            var screen = WorldToScreenStrict(p, root);
            var visible = screen !== null && IsEntityVisibleToLocalPlayer(ent);

            if (visible) {
                var l = ensureLabel();
                l.visible = true;
                l.style.visibility = "visible";
                l.style.position = String(Math.floor(screen.x - 120)) + "px " + String(Math.floor(screen.y - 72)) + "px 0px";
            } else if (label && label.IsValid && label.IsValid()) {
                // Sem fallback central: cliente que não está vendo/renderizando a vítima não recebe texto visual.
                label.visible = false;
                label.style.visibility = "collapse";
            }

            $.Schedule(0.03, updatePosition);
        }

        updatePosition();
    }

    function ShowMulticastText(data) {
        data = data || {};
        var root = Find("#DKFloatingTextRoot");
        if (!root) return;

        var ent = Number(data.entindex || -1);
        var dur = Math.max(0.75, Number(data.duration || 1.8));
        var start = (Game && Game.GetGameTime) ? Game.GetGameTime() : (Date.now() / 1000.0);
        var label = null;

        function ensureLabel() {
            if (label && label.IsValid && label.IsValid()) return label;
            label = $.CreatePanel("Label", root, "DKMulticastText_" + String(Date.now()));
            label.AddClass("DKMulticastText");
            label.text = String(data.text || "MULTICAST!") + (data.subtext ? "\n" + String(data.subtext) : "");
            label.visible = false;
            return label;
        }

        function updatePosition() {
            var now = (Game && Game.GetGameTime) ? Game.GetGameTime() : (Date.now() / 1000.0);
            if (now - start >= dur) {
                if (label && label.DeleteAsync) label.DeleteAsync(0.0);
                return;
            }

            var p = GetChaosWorldPos(data);
            var screen = WorldToScreenStrict(p, root);
            var visible = screen !== null && IsEntityVisibleToLocalPlayer(ent);

            if (visible) {
                var l = ensureLabel();
                var rise = Math.floor((now - start) * 22);
                l.visible = true;
                l.style.visibility = "visible";
                l.style.position = String(Math.floor(screen.x - 150)) + "px " + String(Math.floor(screen.y - 120 - rise)) + "px 0px";
            } else if (label && label.IsValid && label.IsValid()) {
                label.visible = false;
                label.style.visibility = "collapse";
            }

            $.Schedule(0.03, updatePosition);
        }

        updatePosition();
    }

    var concoctionLabels = {};
    function ShowConcoctionTimer(data) {
        data = data || {};
        var root = Find("#DKFloatingTextRoot");
        if (!root) return;
        var ent = Number(data.entindex || -1);
        if (ent < 0) return;
        var key = "ent" + String(ent);
        var label = concoctionLabels[key];
        if (!label || !(label.IsValid && label.IsValid())) {
            label = $.CreatePanel("Label", root, "DKConcoctionTimer_" + key);
            label.AddClass("DKConcoctionTimerText");
            concoctionLabels[key] = label;
        }
        var rem = Math.max(0, Number(data.remaining || 0));
        label.text = String(data.text || rem.toFixed(1));
        label.visible = true;
        label.style.visibility = "visible";
        var dur = Math.max(0.12, Number(data.duration || 0.30));
        var start = (Game && Game.GetGameTime) ? Game.GetGameTime() : (Date.now() / 1000.0);
        function updatePosition() {
            var now = (Game && Game.GetGameTime) ? Game.GetGameTime() : (Date.now() / 1000.0);
            if (now - start >= dur || rem <= 0) {
                if (label && label.IsValid && label.IsValid()) {
                    label.visible = false;
                    label.style.visibility = "collapse";
                }
                return;
            }
            var p = GetChaosWorldPos(data);
            var screen = WorldToScreenStrict(p, root);
            var visible = screen !== null && IsEntityVisibleToLocalPlayer(ent);
            if (visible) {
                label.visible = true;
                label.style.visibility = "visible";
                label.style.position = String(Math.floor(screen.x - 70)) + "px " + String(Math.floor(screen.y - 118)) + "px 0px";
            } else {
                label.visible = false;
                label.style.visibility = "collapse";
            }
            $.Schedule(0.03, updatePosition);
        }
        updatePosition();
    }

    if (typeof GameEvents !== "undefined") {
        GameEvents.Subscribe("dotakart_chaos_stun_text", ShowChaosStunText);
        GameEvents.Subscribe("dotakart_multicast_text", ShowMulticastText);
        GameEvents.Subscribe("dotakart_concoction_timer", ShowConcoctionTimer);
    }
})();

// ============================================================
// FIX122 legacy local item-use hints; Ball Lightning changed to T-toggle in FIX131.
// ============================================================
(function () {
    "use strict";
    var hintToken = 0;
    function HintFind(id) {
        return $.GetContextPanel().FindChildTraverse(String(id || "").replace(/^#/, ""));
    }
    function ShowItemHint(data) {
        data = data || {};
        var root = HintFind("#DKFloatingTextRoot");
        if (!root) return;
        var label = HintFind("#DKItemHintText");
        if (!label) {
            label = $.CreatePanel("Label", root, "DKItemHintText");
            label.AddClass("DKItemHintText");
        }
        hintToken++;
        var token = hintToken;
        label.text = String(data.text || "");
        label.visible = true;
        label.style.visibility = "visible";
        var duration = Math.max(0.5, Number(data.duration || 1.8));
        $.Schedule(duration, function () {
            if (token !== hintToken || !label || !(label.IsValid && label.IsValid())) return;
            label.visible = false;
            label.style.visibility = "collapse";
        });
    }
    if (typeof GameEvents !== "undefined") GameEvents.Subscribe("dotakart_item_hint", ShowItemHint);
})();

// ============================================================
// FIX50: Pre-race countdown HUD.
// Recebe dotakart_countdown_update do servidor. Os sons são tentados via
// Panorama como fallback, e os últimos 3 segundos aparecem no centro da tela.
// ============================================================
(function () {
    "use strict";

    var countdownToken = 0;

    function Find(id) {
        return $.GetContextPanel().FindChildTraverse(id.replace(/^#/, ""));
    }

    function TryPlayCountdownSound(sound) {
        if (!sound) return;
        sound = String(sound);
        try { if (Game && Game.EmitSound) Game.EmitSound(sound); } catch (e1) {}
        try { $.DispatchEvent("PlaySoundEffect", sound); } catch (e2) {}

        // Fallbacks para soundevent sem path/extensão, caso a build registre assim.
        var noExt = sound.replace(/\.vsnd$/i, "");
        var aliases = [
            noExt,
            noExt.replace(/^sounds\//i, ""),
            noExt.replace(/^sounds\//i, "").replace(/\//g, "."),
            noExt.replace(/^sounds\//i, "").split("/").pop()
        ];
        for (var i = 0; i < aliases.length; i++) {
            try { if (Game && Game.EmitSound) Game.EmitSound(aliases[i]); } catch (e3) {}
            try { $.DispatchEvent("PlaySoundEffect", aliases[i]); } catch (e4) {}
        }
    }

    function HideCountdownLater(token, delay) {
        $.Schedule(delay || 1.05, function () {
            if (token !== countdownToken) return;
            var screen = Find("#DKCountdownScreen");
            if (screen) screen.style.visibility = "collapse";
        });
    }

    function OnCountdownUpdate(data) {
        data = data || {};
        countdownToken++;
        var token = countdownToken;

        if (data.sound) TryPlayCountdownSound(data.sound);
        if (data.raw_sound) TryPlayCountdownSound(data.raw_sound);

        var screen = Find("#DKCountdownScreen");
        var text = Find("#DKCountdownText");
        if (!screen || !text) return;

        var show = Number(data.show || 0) === 1;
        var seconds = Number(data.seconds || 0);
        var label = String(data.text || "");
        var center = Number(data.center || 0) === 1;

        if (!show) {
            screen.style.visibility = "collapse";
            text.text = "";
            return;
        }

        // Por pedido: só os últimos 3 segundos aparecem no centro da tela.
        if (!center && seconds > 3) {
            screen.style.visibility = "collapse";
            return;
        }

        if (!label) label = seconds > 0 ? String(seconds) : "GO!";
        text.text = label;
        screen.SetHasClass("SmallCountdown", seconds > 3);
        screen.SetHasClass("GoCountdown", seconds <= 0 || label.toUpperCase() === "GO!");
        screen.style.visibility = "visible";

        HideCountdownLater(token, (seconds <= 0 || label.toUpperCase() === "GO!") ? 1.15 : 0.95);
    }

    if (typeof GameEvents !== "undefined") {
        GameEvents.Subscribe("dotakart_countdown_update", OnCountdownUpdate);
    }
})();

// ============================================================
// FIX58: host race setup + public AI settings.
// ============================================================
(function () {
    "use strict";

    var currentLaps = 3;
    var locked = false;

    function Find(id) {
        return $.GetContextPanel().FindChildTraverse(String(id).replace(/^#/, ""));
    }

    function IsLocalHost(payload) {
        var local = -1;
        try { local = Players.GetLocalPlayer(); } catch (e) { local = -1; }
        return local === Number((payload && payload.host_player_id) || 0);
    }

    function SetButtonSelected(laps) {
        for (var n = 2; n <= 5; n++) {
            var b = Find("#DKHostLap" + String(n));
            if (b) b.SetHasClass("Selected", n === Number(laps));
        }
    }

    function SendLaps(laps) {
        if (locked) return;
        laps = Math.max(2, Math.min(5, Number(laps) || 3));
        currentLaps = laps;
        SetButtonSelected(laps);
        if (typeof GameEvents !== "undefined") {
            GameEvents.SendCustomGameEventToServer("dotakart_host_settings", { laps: laps });
        }
    }

    function UpdateHostSetup(payload) {
        payload = payload || {};
        currentLaps = Number(payload.laps || currentLaps || 3);
        locked = Number(payload.locked || 0) === 1 || Number(payload.race_started || 0) === 1;

        var panel = Find("#DKHostSetupPanel");
        var status = Find("#DKHostSetupStatus");
        var hint = Find("#DKHostSetupHint");
        if (!panel) return;

        if (locked) {
            panel.style.visibility = "collapse";
            return;
        }

        panel.style.visibility = "visible";
        SetButtonSelected(currentLaps);

        var isHost = IsLocalHost(payload);
        var remaining = Number(payload.setup_remaining || 0);
        if (status) {
            if (isHost) {
                status.text = "Jogador 1/Host: escolha voltas (" + String(currentLaps) + ")" + (remaining > 0 ? " - " + String(remaining) + "s" : "");
            } else {
                status.text = "Host escolhendo voltas: " + String(currentLaps);
            }
        }
        if (hint) {
            var botCount = Number(payload.bot_count !== undefined ? payload.bot_count : -1);
            hint.text = botCount < 0 ? "Slots vazios serão preenchidos por bots IA." : ("Computadores IA: " + String(botCount));
        }

        for (var n = 2; n <= 5; n++) {
            var b = Find("#DKHostLap" + String(n));
            if (b) b.enabled = isHost;
        }
    }

    function HookButtons() {
        for (var n = 2; n <= 5; n++) {
            (function (laps) {
                var b = Find("#DKHostLap" + String(laps));
                if (b) {
                    b.SetPanelEvent("onactivate", function () { SendLaps(laps); });
                }
            })(n);
        }
    }

    $.Schedule(0.1, function () {
        HookButtons();
        if (typeof GameEvents !== "undefined") {
            GameEvents.Subscribe("dotakart_host_settings_update", UpdateHostSetup);
            GameEvents.SendCustomGameEventToServer("dotakart_host_settings", { request: 1 });
        }
    });
})();
