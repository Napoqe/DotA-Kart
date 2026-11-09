// One local soundtrack owner. Custom playback waits until native music is muted.
$.Schedule(0.05, function () {
    try {
    var config = GameUI.CustomUIConfig();
    var root = $.GetContextPanel();
    var host = root.FindChildTraverse("DKMusicWidgetHost");
    $.Msg("[DotA Kart Music] init host=" + !!host);
    if (!host) return;
    var setupWidget = root.BHasClass("DKSetupRoot");
    // Hidden GameSetup panels can reload after the HUD. They must not take
    // ownership of the race voice or its polling loop.
    if (setupWidget && Game.GetState() > DOTA_GameState.DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP) return;
    var state = config.dotakartMusic;
    if (!state || state.version !== 3) {
        if (state && typeof state.handle === "number") Game.StopSound(state.handle);
        state = config.dotakartMusic = {
            version: 3, mode: 1, ready: false, chosen: false, pending: false,
            started: false, expanded: false, handle: null, nextTrackAt: 0, index: -1, phase: null, title: ""
        };
    }
    var tracks = [
        { event: "dotakart_music_radiant_overdrive", duration: 96, name: "Radiant Overdrive" },
        { event: "dotakart_music_rome_afterburner", duration: 96, name: "Rome Afterburner" },
        { event: "dotakart_music_ancient_highway", duration: 96, name: "Ancient Highway" },
        { event: "dotakart_music_starlight_circuit", duration: 96, name: "Starlight Circuit" }
    ];
    var setupTrack = { event: "dotakart_music_starting_grid", duration: 96, name: "Starting Grid" };
    var owner = {};
    // The engine clears UI sound voices when the gameplay HUD is created.
    // A handle from GameSetup is not proof that its voice is still playing.
    if (state.owner && typeof state.handle === "number") Game.StopSound(state.handle);
    state.handle = null; state.nextTrackAt = 0; state.phase = null; state.index = -1;
    state.owner = owner;
    function playbackPhase() {
        // FIX143: the Setup widget owns the soundtrack until the race HUD takes over, so it
        // keeps the Setup track through hero selection instead of stopping it there.
        if (setupWidget) return Game.GetState() < DOTA_GameState.DOTA_GAMERULES_STATE_PRE_GAME ? "setup" : "waiting";
        if (state.started) return "race";
        // FIX133: the Setup track also plays on the hero selection screen.
        var gs = Game.GetState();
        if (gs === DOTA_GameState.DOTA_GAMERULES_STATE_HERO_SELECTION ||
            (DOTA_GameState.DOTA_GAMERULES_STATE_STRATEGY_TIME !== undefined && gs === DOTA_GameState.DOTA_GAMERULES_STATE_STRATEGY_TIME)) return "setup";
        return "waiting";
    }
    function text(token) { return $.Localize("#DOTA_KART_" + token); }
    function label(parent, id, value, cls) {
        var p = $.CreatePanel("Label", parent, id); p.text = value;
        if (cls) p.AddClass(cls); return p;
    }
    function button(parent, id, value, callback) {
        var b = $.CreatePanel("Button", parent, id); b.AddClass("DKMusicButton");
        label(b, id + "Label", value); b.SetPanelEvent("onactivate", callback); return b;
    }
    host.RemoveAndDeleteChildren();
    var mini = button(host, "DKMusicMini", "♫", function () { state.expanded = !state.expanded; refresh(); });
    mini.AddClass("DKMusicMini");
    mini.SetPanelEvent("onmouseover", function () { $.DispatchEvent("DOTAShowTextTooltip", mini, text("MUSIC_MENU")); });
    mini.SetPanelEvent("onmouseout", function () { $.DispatchEvent("DOTAHideTextTooltip", mini); });
    var controls = $.CreatePanel("Panel", host, "DKMusicControls"); controls.AddClass("DKMusicControls");
    label(controls, "DKMusicHeading", text("MUSIC_MENU"), "DKMusicHeading");
    var custom = button(controls, "DKMusicCustom", "DotA Kart", function () { choose(1); });
    var native = button(controls, "DKMusicNative", "Dota 2", function () { choose(2); });
    var off = button(controls, "DKMusicOff", text("MUSIC_DISABLE"), function () { choose(0); });
    var next = button(controls, "DKMusicNext", text("MUSIC_NEXT"), function () { stop(); playNext(); refresh(); });
    var nowPlaying = label(controls, "DKMusicTrack", "", "DKMusicTrack");
    var prompt = $.CreatePanel("Panel", host, "DKMusicPrompt"); prompt.AddClass("DKMusicPrompt");
    label(prompt, "DKMusicPromptTitle", text("MUSIC_WELCOME"), "DKMusicTitle");
    label(prompt, "DKMusicPromptText", text("MUSIC_SOURCE_FIRST_RUN"), "DKMusicPromptText");
    var choices = $.CreatePanel("Panel", prompt, "DKMusicChoices"); choices.AddClass("DKMusicChoices");
    button(choices, "DKMusicKeep", "DotA Kart", function () { choose(1); });
    button(choices, "DKMusicUseNative", "Dota 2", function () { choose(2); });
    button(choices, "DKMusicMute", text("MUSIC_DISABLE"), function () { choose(0); });

    function stop() {
        if (typeof state.handle === "number") { try { Game.StopSound(state.handle); } catch (e) {} }
        state.handle = null; state.nextTrackAt = 0;
    }
    function localAudioState() {
        // FIX131: the local controller may be the hero's modifier instead of the audio unit.
        var candidates = [state.controller];
        try { candidates.push(Players.GetPlayerHeroEntityIndex(Game.GetLocalPlayerID())); } catch (e) {}
        for (var c = 0; c < candidates.length; c++) {
            var entity = candidates[c];
            if (typeof entity !== "number" || entity < 0 || !Entities.IsValidEntity(entity)) continue;
            for (var i = 0; i < Entities.GetNumBuffs(entity); i++) {
                var buff = Entities.GetBuff(entity, i);
                if (Buffs.GetName(entity, buff) !== "modifier_dotakart_audio_preferences") continue;
                var match = /^dotakart_audio_v3_(\d+)_(\d+)$/.exec(Buffs.GetTexture(entity, buff));
                if (match) return {mode: Number(match[1]) - 1, applied: Number(match[2]) - 1};
            }
        }
        return null;
    }
    function canPlayCustom() {
        try {
            return state.ready && state.mode === 1 &&
                state.applied === 1 &&
                Game.GetConvarFloat("snd_musicvolume") <= 0.00001;
        } catch (e) { return false; }
    }
    function playNext() {
        if (!canPlayCustom()) return;
        if (typeof state.handle === "number") stop();
        var phase = playbackPhase();
        if (phase === "waiting") return;
        if (state.phase !== phase) { state.index = -1; state.phase = phase; }
        var track;
        if (phase === "setup") track = setupTrack;
        else { state.index = (state.index + 1) % tracks.length; track = tracks[state.index]; }
        state.handle = Game.EmitSound(track.event);
        state.title = track.name;
        state.nextTrackAt = Game.Time() + track.duration;
        $.Msg("[DotA Kart Music] playing " + track.name + " handle=" + state.handle + " phase=" + phase);
    }
    function savePending() {
        if (!state.ready || !state.pending) return;
        GameEvents.SendCustomGameEventToServer("dotakart_music_mode_request", { mode: state.mode });
    }
    function choose(mode) {
        if (mode !== 0 && mode !== 1 && mode !== 2) return;
        if (mode === state.mode && state.chosen && !state.pending) return;
        // Stop the custom handle before native music can be restored.
        stop(); state.mode = mode; state.chosen = true; state.pending = true;
        if (state.started) state.expanded = false;
        savePending(); refresh();
    }
    function refresh() {
        host.SetHasClass("DKMusicRacing", state.started);
        host.SetHasClass("DKMusicExpanded", state.expanded);
        custom.SetHasClass("DKMusicSelected", state.mode === 1);
        native.SetHasClass("DKMusicSelected", state.mode === 2);
        off.SetHasClass("DKMusicSelected", state.mode === 0);
        mini.FindChildTraverse("DKMusicMiniLabel").text = state.mode === 0 ? "♪" : "♫";
        next.enabled = state.mode === 1 && state.ready;
        next.visible = state.mode === 1;
        nowPlaying.text = state.mode === 1 ? state.title : "";
        prompt.visible = state.ready && !state.chosen && !state.started;
        controls.visible = !prompt.visible && (!state.started || state.expanded);
    }
    function beginRace() {
        if (!state.started) { stop(); state.phase = null; state.index = -1; }
        state.started = true; state.expanded = false; prompt.visible = false; refresh();
    }
    function poll() {
        if (state.owner !== owner) return;
        if (!root.IsValid()) { stop(); return; }
        state.lastPoll = Game.Time();
        var audio = localAudioState();
        var ready = audio !== null;
        if (ready) {
            var saved = audio.mode;
            state.applied = audio.applied;
            if (!state.ready) {
                state.ready = true;
                if (!state.pending && (saved === 0 || saved === 1 || saved === 2)) { state.mode = saved; state.chosen = true; }
            }
            if (state.pending) {
                if (saved === state.mode) state.pending = false;
                else savePending();
            }
        } else state.ready = false;
        if (state.started && state.ready && !state.chosen) choose(state.mode);
        if (!setupWidget && !state.started && Game.GetState() >= DOTA_GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS) beginRace();
        var phase = playbackPhase();
        // FIX133: log why custom music is (not) playing whenever the reason changes.
        var reason;
        try {
            var nativeVolume = Game.GetConvarFloat("snd_musicvolume");
            reason = !state.ready ? "audio_state_not_ready" : state.mode !== 1 ? "mode_" + state.mode :
                state.applied !== 1 ? "applied_" + state.applied : nativeVolume > 0.00001 ? "native_volume_" + nativeVolume :
                phase === "waiting" ? "waiting_phase" : "ok_" + phase;
        } catch (e) { reason = "error_" + e; }
        if (reason !== state.lastReason) {
            state.lastReason = reason;
            $.Msg("[DotA Kart Music] state " + reason + " setupWidget=" + setupWidget + " gameState=" + Game.GetState() + " handle=" + state.handle);
        }
        if (state.phase !== phase) stop();
        if (phase === "waiting" || !canPlayCustom()) stop();
        else if (state.handle === null || Game.Time() >= state.nextTrackAt) playNext();
        refresh(); $.Schedule(.25, poll);
    }
    GameEvents.Subscribe("dotakart_countdown_update", function (payload) {
        if (state.owner !== owner) return;
        if (Number(payload.seconds) === 0 || payload.text === "GO!") beginRace();
    });
    GameEvents.Subscribe("dotakart_host_settings_update", function (payload) {
        if (state.owner !== owner) return;
        if (Number(payload.race_started) === 1 && !state.started) beginRace();
    });
    GameEvents.Subscribe("dotakart_audio_controller", function (payload) {
        if (state.owner === owner && Number(payload.player_id) === Game.GetLocalPlayerID()) state.controller = Number(payload.entity_index);
    });
    refresh(); poll();
    // Commands survive a map/UI reload in the engine. Diagnostics must never
    // prevent the playback poll from starting or bind a stale panel callback.
    var suffix = String(Math.floor(Math.random() * 1000000000));
    state.debugCommand = "dotakart_music_" + suffix;
    try {
        Game.AddCommand(state.debugCommand, function () {
            $.Msg("[DotA Kart Music] diagnostic " + JSON.stringify({mode:state.mode,ready:state.ready,pending:state.pending,chosen:state.chosen,handle:state.handle,title:state.title,phase:state.phase,controller:state.controller,applied:state.applied,audio:localAudioState(),owner:state.owner===owner,poll_age:Game.Time()-state.lastPoll,native_volume:Game.GetConvarFloat("snd_musicvolume")}));
        }, "DotA Kart: local soundtrack diagnostics", 0);
        Game.AddCommand(state.debugCommand + "_native", function () { choose(2); }, "DotA Kart: use native score", 0);
        Game.AddCommand(state.debugCommand + "_custom", function () { choose(1); }, "DotA Kart: use custom score", 0);
        Game.AddCommand(state.debugCommand + "_off", function () { choose(0); }, "DotA Kart: mute score", 0);
        $.Msg("[DotA Kart Music] widget active; diagnostic=" + state.debugCommand);
    } catch (e) { $.Msg("[DotA Kart Music] diagnostic registration: " + e); }
    } catch (error) { $.Msg("[DotA Kart Music] initialization error " + error + " " + error.stack); }
});
