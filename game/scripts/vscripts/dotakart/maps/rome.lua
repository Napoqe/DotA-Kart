-- Rome's roads are static meshes. Gameplay uses the same footprint as their source.
local data = require("dotakart/maps/rome_data")
local M = {}
function M:IsEnabled()
    return GetMapName ~= nil and GetMapName() == "rome"
end
-- FIX143: the HUD/bot path uses every TRACK_STRIDE-th dk_track_* on Rome. Data indices
-- below are the original dk_track_* numbers, so path indices are converted first.
local TRACK_STRIDE = 2
function M:GetTrackStride()
    if not self:IsEnabled() then return 1 end
    return TRACK_STRIDE
end
local function sourceIndex(index)
    return (math.floor(tonumber(index) or 1) - 1) * TRACK_STRIDE + 1
end
local function triangle(x,y,ax,ay,bx,by,cx,cy)
    local a=(x-ax)*(by-ay)-(y-ay)*(bx-ax)
    local b=(x-bx)*(cy-by)-(y-by)*(cx-bx)
    local c=(x-cx)*(ay-cy)-(y-cy)*(ax-cx)
    return not ((a < -0.001 or b < -0.001 or c < -0.001) and (a > 0.001 or b > 0.001 or c > 0.001))
end
local grid={}
for _,q in ipairs(data.road) do
    local minx,maxx=math.min(q[1],q[3],q[5],q[7]),math.max(q[1],q[3],q[5],q[7])
    local miny,maxy=math.min(q[2],q[4],q[6],q[8]),math.max(q[2],q[4],q[6],q[8])
    for x=math.floor(minx/1024),math.floor(maxx/1024) do
        for y=math.floor(miny/1024),math.floor(maxy/1024) do
            local key=x..":"..y;grid[key]=grid[key] or {};table.insert(grid[key],q)
        end
    end
end
function M:IsOnRoad(pos,branchOnly)
    if pos==nil or not self:IsEnabled() then return false end
    for _,q in ipairs(grid[math.floor(pos.x/1024)..":"..math.floor(pos.y/1024)] or {}) do
        if not branchOnly or q[9]==1 then
            if triangle(pos.x,pos.y,q[1],q[2],q[3],q[4],q[5],q[6])
                or triangle(pos.x,pos.y,q[1],q[2],q[5],q[6],q[7],q[8]) then return true end
        end
    end
    return false
end
function M:GetBranchProjection(pos)
    local best=nil
    for i=1,#data.branch-1 do
        local a,b=data.branch[i],data.branch[i+1]
        local dx,dy=b[1]-a[1],b[2]-a[2];local l2=dx*dx+dy*dy
        local t=math.max(0,math.min(1,((pos.x-a[1])*dx+(pos.y-a[2])*dy)/l2))
        local ds=(pos.x-a[1]-t*dx)^2+(pos.y-a[2]-t*dy)^2
        if best==nil or ds<best.dist_sq then best={dist_sq=ds,s=a[3]+(b[3]-a[3])*t} end
    end
    return best
end
function M:ProjectBranch(pos,hud,best)
    if not self:IsEnabled() or not self:IsOnRoad(pos,true) then return best end
    local p=self:GetBranchProjection(pos)
    if p==nil or p.dist_sq >= best.nearest_dist_sq then return best end
    local distance=data.entry_distance+(data.exit_distance-data.entry_distance)*p.s/data.branch_length
    distance=distance*hud.trackLength/data.track_length
    for _,seg in ipairs(hud.trackSegments) do
        if distance<=seg.cumulative+seg.length then
            return {distance=distance,normalized=distance/hud.trackLength,nearest_segment=seg.index,
                nearest_dist_sq=p.dist_sq,t=math.max(0,math.min(1,(distance-seg.cumulative)/seg.length)),rome_branch=true}
        end
    end
    return best
end
function M:GetBranchPoint(index)
    index=sourceIndex(index)
    if index<data.entry_index or index>data.exit_index then return nil end
    -- Main waypoints are evenly spaced, but use the exact main progress exported.
    local distance=data.waypoint_distances[index]
    local s=math.max(0,math.min(1,(distance-data.entry_distance)/(data.exit_distance-data.entry_distance)))*data.branch_length
    for i=1,#data.branch-1 do
        local a,b=data.branch[i],data.branch[i+1]
        if s<=b[3] then
            local t=(s-a[3])/(b[3]-a[3]);return Vector(a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,128)
        end
    end
    local p=data.branch[#data.branch];return Vector(p[1],p[2],128)
end
function M:AssignBots(bots)
    if not self:IsEnabled() then return end
    local fresh={}
    for _,bot in pairs(bots or {}) do
        if bot.rome_branch_preference==nil then table.insert(fresh,bot) end
    end
    for i=#fresh,2,-1 do local j=RandomInt and RandomInt(1,i) or math.random(i);fresh[i],fresh[j]=fresh[j],fresh[i] end
    local count=math.floor(#fresh/2)
    if #fresh==1 then count=(RandomInt and RandomInt(0,1) or math.random(0,1)) end
    for i,bot in ipairs(fresh) do bot.rome_branch_preference=i<=count end
end
function M:UpdateBotRoute(bot,index,pos)
    if not self:IsEnabled() then return end
    index=sourceIndex(index)
    if index<data.entry_index-3 or index>data.exit_index+2 then bot.rome_branch_active=nil;return end
    if bot.rome_branch_active==nil then
        if index>data.entry_index+2 then
            local p=self:GetBranchProjection(pos)
            bot.rome_branch_active=self:IsOnRoad(pos,true) and p.dist_sq<300^2
        else bot.rome_branch_active=bot.rome_branch_preference==true end
    end
end
function M:ResetBotRoute(bot,pos,project)
    if not self:IsEnabled() then return end
    bot.rome_branch_active=project and project.rome_branch==true or false
end
return M
