-- FIX134: ability Lua files are executed by the client VM as well as the server.
-- Linking here makes modifier_dotakart_audio_preferences known on the client, so its
-- client-side code (local music preference / native music mute) can run.
LinkLuaModifier("modifier_dotakart_audio_preferences", "dotakart/modifiers/modifier_audio_preferences.lua", LUA_MODIFIER_MOTION_NONE)

dotakart_audio_link = class({})
function dotakart_audio_link:IsHiddenAbilityCastable() return false end
function dotakart_audio_link:IsStealable() return false end
