local OWNER="Johnatafgfdgf"
local REPO="Midi-to-qwerty-roblox-autoplayer"
local PINNED_COMMIT="562bc1aa9292a51458716c395e77af7c26905ec3"
local VERSION="0.6.0-PREMIUM"

local env=(getgenv and getgenv()) or _G
if env.MIDIQWERTY and type(env.MIDIQWERTY.destroy)=="function" then pcall(env.MIDIQWERTY.destroy) end
env.MIDIQWERTY=nil;env.MIDIQWERTY_BUILD=VERSION

local Players=game:GetService("Players")
local CoreGui=game:GetService("CoreGui")
local TweenService=game:GetService("TweenService")

local function cleanup(parent)
    if not parent then return end
    for _,v in ipairs(parent:GetChildren()) do
        if v:IsA("ScreenGui") and string.find(v.Name,"MIDIQWERTY",1,true) then pcall(function()v:Destroy()end) end
    end
end
pcall(function()cleanup(CoreGui)end)
pcall(function()if gethui then cleanup(gethui())end end)
pcall(function()cleanup(Players.LocalPlayer:FindFirstChildOfClass("PlayerGui"))end)

-- Minimal premium boot screen. It shows real module-loading stages, not fake percentages.
local boot=Instance.new("ScreenGui");boot.Name="MIDIQWERTY_BOOT_V060";boot.ResetOnSpawn=false;boot.DisplayOrder=20000;boot.IgnoreGuiInset=false
local parent=(gethui and gethui()) or CoreGui
if not pcall(function()boot.Parent=parent end) then boot.Parent=Players.LocalPlayer:WaitForChild("PlayerGui") end
local veil=Instance.new("Frame");veil.BackgroundColor3=Color3.fromRGB(7,9,15);veil.BackgroundTransparency=.08;veil.Size=UDim2.fromScale(1,1);veil.Parent=boot
local card=Instance.new("Frame");card.AnchorPoint=Vector2.new(.5,.5);card.Position=UDim2.fromScale(.5,.5);card.Size=UDim2.fromOffset(330,150);card.BackgroundColor3=Color3.fromRGB(17,20,31);card.Parent=veil
local cr=Instance.new("UICorner");cr.CornerRadius=UDim.new(0,16);cr.Parent=card
local st=Instance.new("UIStroke");st.Color=Color3.fromRGB(50,57,78);st.Thickness=1;st.Transparency=.25;st.Parent=card
local title=Instance.new("TextLabel");title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(18,18);title.Size=UDim2.new(1,-36,0,28);title.Text="MIDI QWERTY";title.TextXAlignment=Enum.TextXAlignment.Left;title.Font=Enum.Font.GothamBold;title.TextSize=18;title.TextColor3=Color3.fromRGB(247,248,252);title.Parent=card
local badge=Instance.new("TextLabel");badge.BackgroundColor3=Color3.fromRGB(127,92,255);badge.Position=UDim2.fromOffset(18,51);badge.Size=UDim2.fromOffset(92,22);badge.Text="v0.6 PREMIUM";badge.Font=Enum.Font.GothamBold;badge.TextSize=8;badge.TextColor3=Color3.new(1,1,1);badge.Parent=card
local bc=Instance.new("UICorner");bc.CornerRadius=UDim.new(0,7);bc.Parent=badge
local status=Instance.new("TextLabel");status.BackgroundTransparency=1;status.Position=UDim2.fromOffset(18,83);status.Size=UDim2.new(1,-36,0,22);status.Text="Preparando módulos...";status.TextXAlignment=Enum.TextXAlignment.Left;status.Font=Enum.Font.Gotham;status.TextSize=10;status.TextColor3=Color3.fromRGB(159,168,190);status.Parent=card
local track=Instance.new("Frame");track.BackgroundColor3=Color3.fromRGB(37,43,62);track.Position=UDim2.fromOffset(18,118);track.Size=UDim2.new(1,-36,0,8);track.Parent=card
local tc=Instance.new("UICorner");tc.CornerRadius=UDim.new(1,0);tc.Parent=track
local fill=Instance.new("Frame");fill.BackgroundColor3=Color3.fromRGB(127,92,255);fill.Size=UDim2.fromScale(.05,1);fill.Parent=track
local fc=Instance.new("UICorner");fc.CornerRadius=UDim.new(1,0);fc.Parent=fill

local base=string.format("https://raw.githubusercontent.com/%s/%s/%s/src/",OWNER,REPO,PINNED_COMMIT)
local aliases={
    ["Main"]="MainV060",
    ["ConfigDefaults"]="ConfigDefaultsV060",
    ["UI/App"]="UI/AppPremiumV060",
    ["Piano/Mapper"]="Piano/MapperV060",
    ["Player/Scheduler"]="Player/SchedulerV060",
    ["Input/InputAdapter"]="Input/InputAdapterV051",
    ["Player/NoteManager"]="Player/NoteManagerV051",
    ["Performance/Humanizer"]="Performance/HumanizerV051",
    ["Cloud/DodoProvider"]="Cloud/DodoProviderV060",
}
local cache,loading={},{}
local loadedCount=0
local expected=21
local function setStage(txt)
    loadedCount+=1;status.Text=txt
    TweenService:Create(fill,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.fromScale(math.clamp(.05+loadedCount/expected*.9,.05,.95),1)}):Play()
end
local function Require(path)
    if cache[path]~=nil then return cache[path] end
    assert(not loading[path],"[MIDIQWERTY] Circular dependency: "..path)
    loading[path]=true
    local remote=aliases[path] or path
    setStage("Carregando "..remote:gsub("/"," › ").."...")
    local url=base..remote..".lua"
    local ok,source=pcall(function()return game:HttpGet(url)end)
    if not ok or type(source)~="string" then loading[path]=nil;error("[MIDIQWERTY] Download failed: "..remote.." | "..tostring(source),2)end
    local chunk,err=loadstring(source,"=MIDIQWERTY/"..remote)
    if not chunk then loading[path]=nil;error("[MIDIQWERTY] Compile failed: "..remote.." | "..tostring(err),2)end
    local good,result=pcall(chunk);loading[path]=nil
    if not good then error("[MIDIQWERTY] Runtime failed: "..remote.." | "..tostring(result),2)end
    if result==nil then result=true end
    cache[path]=result;return result
end

local ok,result=pcall(function()
    local Main=Require("Main")
    status.Text="Iniciando player..."
    return Main.start({Require=Require,meta={owner=OWNER,repo=REPO,branch=PINNED_COMMIT,version=VERSION,pinned=true}})
end)
if not ok then
    status.Text="Falha ao iniciar";status.TextColor3=Color3.fromRGB(239,91,113)
    warn("[MIDIQWERTY] "..tostring(result))
    task.delay(4,function()if boot then boot:Destroy()end end)
    error(result,0)
end

status.Text="Pronto";status.TextColor3=Color3.fromRGB(76,215,188)
TweenService:Create(fill,TweenInfo.new(.2),{Size=UDim2.fromScale(1,1)}):Play()
task.delay(.25,function()
    TweenService:Create(veil,TweenInfo.new(.25),{BackgroundTransparency=1}):Play()
    TweenService:Create(card,TweenInfo.new(.25),{BackgroundTransparency=1}):Play()
    task.wait(.27);if boot then boot:Destroy()end
end)
print("[MIDIQWERTY] Loaded "..VERSION.." @ "..PINNED_COMMIT:sub(1,8))
return result
