local OWNER="Johnatafgfdgf"
local REPO="Midi-to-qwerty-roblox-autoplayer"
local PINNED_COMMIT="6ab17804a2651c586b1e4bc51a34038d6899d5cd"
local VERSION="0.7.0-RC"

local env=(getgenv and getgenv()) or _G
if env.MIDIQWERTY and type(env.MIDIQWERTY.destroy)=="function" then pcall(env.MIDIQWERTY.destroy) end
env.MIDIQWERTY=nil;env.MIDIQWERTY_BUILD=VERSION

local Players=game:GetService("Players")
local CoreGui=game:GetService("CoreGui")
local TweenService=game:GetService("TweenService")

local function cleanup(parent)
    if not parent then return end
    for _,v in ipairs(parent:GetChildren())do
        if v:IsA("ScreenGui") and string.find(v.Name,"MIDIQWERTY",1,true) then pcall(function()v:Destroy()end)end
    end
end
pcall(function()cleanup(CoreGui)end)
pcall(function()if gethui then cleanup(gethui())end end)
pcall(function()cleanup(Players.LocalPlayer:FindFirstChildOfClass("PlayerGui"))end)

local boot=Instance.new("ScreenGui");boot.Name="MIDIQWERTY_BOOT_V070";boot.ResetOnSpawn=false;boot.DisplayOrder=22000
local parent=(gethui and gethui()) or CoreGui
if not pcall(function()boot.Parent=parent end)then boot.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")end
local veil=Instance.new("Frame");veil.BackgroundColor3=Color3.fromRGB(6,8,13);veil.Size=UDim2.fromScale(1,1);veil.Parent=boot
local card=Instance.new("Frame");card.AnchorPoint=Vector2.new(.5,.5);card.Position=UDim2.fromScale(.5,.5);card.Size=UDim2.fromOffset(350,150);card.BackgroundColor3=Color3.fromRGB(16,19,29);card.Parent=veil
local cc=Instance.new("UICorner");cc.CornerRadius=UDim.new(0,16);cc.Parent=card
local cs=Instance.new("UIStroke");cs.Color=Color3.fromRGB(55,61,83);cs.Transparency=.35;cs.Parent=card
local title=Instance.new("TextLabel");title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(18,16);title.Size=UDim2.new(1,-36,0,28);title.Text="MIDI QWERTY";title.TextXAlignment=Enum.TextXAlignment.Left;title.Font=Enum.Font.GothamBold;title.TextSize=18;title.TextColor3=Color3.fromRGB(247,248,252);title.Parent=card
local sub=Instance.new("TextLabel");sub.BackgroundTransparency=1;sub.Position=UDim2.fromOffset(18,44);sub.Size=UDim2.new(1,-36,0,20);sub.Text="v0.7 RC • preparando autoplayer";sub.TextXAlignment=Enum.TextXAlignment.Left;sub.Font=Enum.Font.Gotham;sub.TextSize=10;sub.TextColor3=Color3.fromRGB(150,159,181);sub.Parent=card
local status=Instance.new("TextLabel");status.BackgroundTransparency=1;status.Position=UDim2.fromOffset(18,77);status.Size=UDim2.new(1,-36,0,20);status.Text="Inicializando...";status.TextXAlignment=Enum.TextXAlignment.Left;status.Font=Enum.Font.Gotham;status.TextSize=9;status.TextColor3=Color3.fromRGB(150,159,181);status.Parent=card
local track=Instance.new("Frame");track.BackgroundColor3=Color3.fromRGB(42,47,63);track.Position=UDim2.fromOffset(18,111);track.Size=UDim2.new(1,-36,0,7);track.Parent=card;local tc=Instance.new("UICorner");tc.CornerRadius=UDim.new(1,0);tc.Parent=track
local fill=Instance.new("Frame");fill.BackgroundColor3=Color3.fromRGB(128,93,255);fill.Size=UDim2.fromScale(.04,1);fill.Parent=track;local fc=Instance.new("UICorner");fc.CornerRadius=UDim.new(1,0);fc.Parent=fill
local grad=Instance.new("UIGradient");grad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(62,216,185)),ColorSequenceKeypoint.new(.55,Color3.fromRGB(128,93,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(242,190,88))});grad.Parent=fill

local base=string.format("https://raw.githubusercontent.com/%s/%s/%s/src/",OWNER,REPO,PINNED_COMMIT)
local aliases={
    ["Main"]="MainV070",
    ["ConfigDefaults"]="ConfigDefaultsV070",
    ["UI/App"]="UI/AppV070",
    ["Performance/Humanizer"]="Performance/HumanizerV070",
    ["Piano/Mapper"]="Piano/MapperV070",
    ["Player/Scheduler"]="Player/SchedulerV070",
    ["Input/InputAdapter"]="Input/InputAdapterV070",
    ["Player/NoteManager"]="Player/NoteManagerV051",
    ["Cloud/DodoProvider"]="Cloud/DodoProviderV061",
}
local cache,loading={},{};local count=0;local expected=22
local function stage(txt)
    count+=1;status.Text=txt
    TweenService:Create(fill,TweenInfo.new(.14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.fromScale(math.clamp(.04+count/expected*.91,.04,.95),1)}):Play()
end
local function Require(path)
    if cache[path]~=nil then return cache[path]end
    assert(not loading[path],"[MIDIQWERTY] Circular dependency: "..path);loading[path]=true
    local remote=aliases[path] or path;stage("Carregando "..remote:gsub("/"," › ").."...")
    local ok,source=pcall(function()return game:HttpGet(base..remote..".lua")end)
    if not ok or type(source)~="string"then loading[path]=nil;error("[MIDIQWERTY] Download failed: "..remote.." | "..tostring(source),2)end
    local chunk,err=loadstring(source,"=MIDIQWERTY/"..remote)
    if not chunk then loading[path]=nil;error("[MIDIQWERTY] Compile failed: "..remote.." | "..tostring(err),2)end
    local good,result=pcall(chunk);loading[path]=nil
    if not good then error("[MIDIQWERTY] Runtime failed: "..remote.." | "..tostring(result),2)end
    if result==nil then result=true end;cache[path]=result;return result
end

local function selfTest()
    stage("Validando Humanizer...")
    local H=Require("Performance/Humanizer")
    local fake={}
    for i=1,10 do
        fake[i]={note=60+((i-1)%5),startTime=(i-1)*.25,endTime=(i-1)*.25+.18,duration=.18,velocity=.65,phraseId=i<=5 and 1 or 2,parts={hand=i%2==0 and "Left" or "Right",melody=i%3==0}}
    end
    local exact=H.getPreset("Exact")
    local e,es=H.generate(fake,exact,{seed=4242,bpm=60,chordWindowMs=10})
    assert(#e==#fake and (es.maxTimingMs or 0)==0,"Exact preset changed timing")
    local pianist=H.getPreset("Pianist")
    local a,sa=H.generate(fake,pianist,{seed=4242,bpm=60,chordWindowMs=10})
    local b,sb=H.generate(fake,pianist,{seed=4242,bpm=60,chordWindowMs=10})
    assert(#a==#fake and (sa.maxTimingMs or 0)>0,"Pianist produced no timing variation")
    for i=1,#a do assert(math.abs((a[i].startTime or 0)-(b[i].startTime or 0))<1e-8,"Fixed seed is not deterministic")end
    return true
end

local ok,result=pcall(function()
    selfTest()
    local Main=Require("Main");status.Text="Montando interface..."
    return Main.start({Require=Require,meta={owner=OWNER,repo=REPO,branch=PINNED_COMMIT,version=VERSION,pinned=true}})
end)
if not ok then
    status.Text="Falha ao iniciar";status.TextColor3=Color3.fromRGB(237,92,113);warn("[MIDIQWERTY] "..tostring(result));task.delay(5,function()if boot then boot:Destroy()end end);error(result,0)
end
status.Text="Pronto";status.TextColor3=Color3.fromRGB(62,216,185);TweenService:Create(fill,TweenInfo.new(.18),{Size=UDim2.fromScale(1,1)}):Play()
task.delay(.22,function()TweenService:Create(veil,TweenInfo.new(.20),{BackgroundTransparency=1}):Play();TweenService:Create(card,TweenInfo.new(.20),{BackgroundTransparency=1,Position=UDim2.fromScale(.5,.48)}):Play();task.wait(.22);if boot then boot:Destroy()end end)
print("[MIDIQWERTY] Loaded "..VERSION.." @ "..PINNED_COMMIT:sub(1,8))
return result
