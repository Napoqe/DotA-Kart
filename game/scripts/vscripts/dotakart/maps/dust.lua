-- FIX136: map "dust" (Ancient Egypt desert). Pyramid walls, the skip entrance wall
-- (jump it with Leap or other movement items), decor obstacles and slow sand patches.
local data = require("dotakart/maps/dust_data")
local M = {}
function M:IsEnabled()
    return GetMapName ~= nil and GetMapName() == "dust"
end
local function toLocal(pos, cx, cy, yaw)
    local r = math.rad(yaw)
    local dx, dy = pos.x - cx, pos.y - cy
    local c, s = math.cos(r), math.sin(r)
    return dx * c + dy * s, -dx * s + dy * c
end
-- True when a kart/projectile at pos (with probe radius) hits solid scenery.
function M:IsBlocked(pos, radius)
    if pos == nil then return false end
    radius = tonumber(radius) or 0
    for _, p in ipairs(data.pyramids) do
        local lx, ly = toLocal(pos, p.x, p.y, p.yaw)
        if math.abs(lx) <= p.half + radius and math.abs(ly) <= p.half + radius then
            -- the road tunnel runs along the local X axis
            if math.abs(ly) + radius > p.tunnel_half then return true, "dust_pyramid" end
        end
    end
    for _, w in ipairs(data.walls) do
        local lx, ly = toLocal(pos, w.x, w.y, w.yaw)
        if math.abs(lx) <= w.half_length + radius and math.abs(ly) <= w.half_width + radius then return true, "dust_skip_wall" end
    end
    for _, c in ipairs(data.circles) do
        local dx, dy = pos.x - c[1], pos.y - c[2]
        local rr = c[3] + radius
        if dx * dx + dy * dy <= rr * rr then return true, "dust_decor" end
    end
    return false
end
function M:IsInSand(pos)
    if pos == nil then return false end
    for _, s in ipairs(data.sand) do
        local lx, ly = toLocal(pos, s.x, s.y, s.yaw)
        if (lx * lx) / (s.a * s.a) + (ly * ly) / (s.b * s.b) <= 1 then return true end
    end
    return false
end
-- FIX138: public bots have a high chance to steer around a sand patch on their route.
-- Returns the clear-side road point to drive to, or nil.
function M:GetSandAvoidTarget(bot, pos, moveDir)
    if pos == nil or moveDir == nil or bot == nil then return nil end
    bot.dust_sand_choice = bot.dust_sand_choice or {}
    for i, s in ipairs(data.sand) do
        local dx, dy = s.x - pos.x, s.y - pos.y
        local fwd = dx * moveDir.x + dy * moveDir.y
        local side = math.abs(dx * moveDir.y - dy * moveDir.x)
        if fwd > -200 and fwd < 2600 and side < 1100 then
            if bot.dust_sand_choice[i] == nil then
                bot.dust_sand_choice[i] = (RandomFloat and RandomFloat(0, 1) or math.random()) < (tonumber(data.bot_sand_avoid_chance) or 0.9)
            end
            if bot.dust_sand_choice[i] == true then
                local ax, ay = s.avoid_x - pos.x, s.avoid_y - pos.y
                if ax * moveDir.x + ay * moveDir.y > 120 then return Vector(s.avoid_x, s.avoid_y, pos.z) end
            end
        elseif fwd < -1500 or fwd > 6000 then
            bot.dust_sand_choice[i] = nil
        end
    end
    return nil
end
function M:GetSandSpeedFactor()
    return tonumber(data.sand_speed_factor) or 0.5
end
return M
