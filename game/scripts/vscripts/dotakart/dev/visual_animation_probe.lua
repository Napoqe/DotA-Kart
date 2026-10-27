local ctrl=GameRules.DotaKartController
assert(IsInToolsMode() and ctrl)
if GameRules.KartVisualProbe and not GameRules.KartVisualProbe:IsNull() then UTIL_Remove(GameRules.KartVisualProbe) end
GameRules.KartVisualProbe=nil
DoIncludeScript("dotakart/kart_animation.lua",getfenv(1))
for _,name in ipairs({"invoker","brewmaster","tinker","lina","pudge","tiny","mirana","juggernaut"}) do
 local model="models/karts/"..name.."/seated/"..name.."_kart.vmdl"
 ctrl.kart_models["npc_dota_hero_"..name]=model
end
ctrl.kart_models.npc_dota_hero_dotakart_invoker=ctrl.kart_models.npc_dota_hero_invoker
print("[KART_PROP_QA] animated visuals loaded; check the real racers in Dota")
