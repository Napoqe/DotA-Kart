-- Tools-only recovery after a Lua exception cancelled the recurring think.
assert(IsInToolsMode(), "Tools game required")
local ctrl = GameRules.DotaKartController
assert(ctrl, "Kart controller unavailable")
DoIncludeScript("dotakart/modifiers/modifier_kart_visual.lua", getfenv(0))
LinkLuaModifier("modifier_dotakart_kart_carrier", "dotakart/modifiers/modifier_kart_carrier.lua", LUA_MODIFIER_MOTION_NONE)
DoIncludeScript("dotakart/kart_animation.lua", getfenv(0))
DoIncludeScript("dotakart/kart_visual.lua", getfenv(0))
DoIncludeScript("dotakart/kart_controller.lua", getfenv(0))
ctrl._thinkStarted = false
ctrl:StartThink()
print("[KART_INPUT_QA] controller restarted with protected animation updates")
print("[KART_SERVER_QA] pause_api=" .. type(PauseGame) .. " real_time_api=" .. type(Plat_FloatTime))
