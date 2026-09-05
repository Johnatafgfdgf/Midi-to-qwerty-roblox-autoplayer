local OWNER="Johnatafgfdgf"
local REPO="Midi-to-qwerty-roblox-autoplayer"
local PINNED_COMMIT="c27422ba2ae4df5f4c90f00ad141b8a2431bb6c2"
local VERSION="0.4.1-NEWUI"

local env=(getgenv and getgenv()) or _G
if env.MIDIQWERTY and type(env.MIDIQWERTY.destroy)=="function" then pcall(env.MIDIQWERTY.destroy) end
env.MIDIQWERTY=nil
env.MIDIQWERTY_BUILD=VERSION

local function cleanup(parent)
    if not parent then return end
    for _,v in ipairs(parent:GetChildren()) do
        if v:IsA("ScreenGui") and (v.Name=="MIDIQWERTY_UI" or v.Name=="MIDIQWERTY_V041_NEWUI" or string.find(v.Name,"MIDIQWERTY",1,true)) then
            pcall(function()v:Destroy()end)
        end
    end
end
pcall(function() cleanup(game:GetService("CoreGui")) end)
pcall(function() if gethui then cleanup(gethui()) end end)
pcall(function() cleanup(game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")) end)

local base=string.format("https://raw.githubusercontent.com/%s/%s/%s/src/",OWNER,REPO,PINNED_COMMIT)
local cache,loading={},{}
local function Require(path)
    if cache[path]~=nil then return cache[path] end
    assert(not loading[path],"[MIDIQWERTY] Circular dependency: "..path)
    loading[path]=true
    local remote=path
    if path=="UI/App" then remote="UI/AppMobileV041" end
    local url=base..remote..".lua"
    local ok,source=pcall(function()return game:HttpGet(url)end)
    if not ok or type(source)~="string" then loading[path]=nil;error("[MIDIQWERTY] Download failed: "..remote.." | "..tostring(source),2) end
    local chunk,err=loadstring(source,"=MIDIQWERTY/"..remote)
    if not chunk then loading[path]=nil;error("[MIDIQWERTY] Compile failed: "..remote.." | "..tostring(err),2) end
    local good,result=pcall(chunk);loading[path]=nil
    if not good then error("[MIDIQWERTY] Runtime failed: "..remote.." | "..tostring(result),2) end
    if result==nil then result=true end
    cache[path]=result
    return result
end

local Main=Require("Main")
local app=Main.start({Require=Require,meta={owner=OWNER,repo=REPO,branch=PINNED_COMMIT,version=VERSION,pinned=true}})
print("[MIDIQWERTY] Loaded "..VERSION.." @ "..PINNED_COMMIT:sub(1,8))
return app
