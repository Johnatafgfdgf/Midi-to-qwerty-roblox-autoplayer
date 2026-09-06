local OWNER="Johnatafgfdgf"
local REPO="Midi-to-qwerty-roblox-autoplayer"
local PINNED_COMMIT="8498dfe65fa2f8ea90f4f88abc553d2682b4ac51"
local VERSION="0.6.1-PREMIUM-PLUS"

local env=(getgenv and getgenv()) or _G
if env.MIDIQWERTY and type(env.MIDIQWERTY.destroy)=="function" then pcall(env.MIDIQWERTY.destroy) end
env.MIDIQWERTY=nil;env.MIDIQWERTY_BUILD=VERSION

local Players=game:GetService("Players")
local CoreGui=game:GetService("CoreGui")
local TweenService=game:GetService("TweenService")

local function cleanup(parent)
 if not parent then return end
 for _,v in ipairs(parent:GetChildren())do
  if v:IsA("ScreenGui") and string.find(v.Name,"MIDIQWERTY",1,true)then pcall(function()v:Destroy()end)end
 end
end
pcall(function()cleanup(CoreGui)end);pcall(function()if gethui then cleanup(gethui())end end);pcall(function()cleanup(Players.LocalPlayer:FindFirstChildOfClass("PlayerGui"))end)

local boot=Instance.new("ScreenGui");boot.Name="MIDIQWERTY_BOOT_V061";boot.ResetOnSpawn=false;boot.DisplayOrder=21000;boot.IgnoreGuiInset=false
local parent=(gethui and gethui()) or CoreGui;if not pcall(function()boot.Parent=parent end)then boot.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")end
local veil=Instance.new("Frame");veil.BackgroundColor3=Color3.fromRGB(6,8,14);veil.BackgroundTransparency=.04;veil.Size=UDim2.fromScale(1,1);veil.Parent=boot
local card=Instance.new("Frame");card.AnchorPoint=Vector2.new(.5,.5);card.Position=UDim2.fromScale(.5,.5);card.Size=UDim2.fromOffset(350,165);card.BackgroundColor3=Color3.fromRGB(16,20,31);card.Parent=veil
local cr=Instance.new("UICorner");cr.CornerRadius=UDim.new(0,18);cr.Parent=card
local st=Instance.new("UIStroke");st.Color=Color3.fromRGB(63,70,96);st.Thickness=1;st.Transparency=.25;st.Parent=card
local grad=Instance.new("UIGradient");grad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(22,26,40)),ColorSequenceKeypoint.new(1,Color3.fromRGB(12,15,24))});grad.Rotation=90;grad.Parent=card
local note=Instance.new("TextLabel");note.BackgroundColor3=Color3.fromRGB(127,92,255);note.Size=UDim2.fromOffset(46,46);note.Position=UDim2.fromOffset(18,17);note.Text="♪";note.Font=Enum.Font.GothamBold;note.TextSize=23;note.TextColor3=Color3.new(1,1,1);note.Parent=card;local nc=Instance.new("UICorner");nc.CornerRadius=UDim.new(0,13);nc.Parent=note
local title=Instance.new("TextLabel");title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(76,16);title.Size=UDim2.new(1,-94,0,27);title.Text="MIDI QWERTY";title.TextXAlignment=Enum.TextXAlignment.Left;title.Font=Enum.Font.GothamBold;title.TextSize=18;title.TextColor3=Color3.fromRGB(247,248,252);title.Parent=card
local sub=Instance.new("TextLabel");sub.BackgroundTransparency=1;sub.Position=UDim2.fromOffset(76,42);sub.Size=UDim2.new(1,-94,0,20);sub.Text="Premium Plus • v0.6.1";sub.TextXAlignment=Enum.TextXAlignment.Left;sub.Font=Enum.Font.Gotham;sub.TextSize=10;sub.TextColor3=Color3.fromRGB(157,166,188);sub.Parent=card
local status=Instance.new("TextLabel");status.BackgroundTransparency=1;status.Position=UDim2.fromOffset(18,84);status.Size=UDim2.new(1,-36,0,22);status.Text="Preparando player...";status.TextXAlignment=Enum.TextXAlignment.Left;status.Font=Enum.Font.Gotham;status.TextSize=10;status.TextColor3=Color3.fromRGB(159,168,190);status.Parent=card
local track=Instance.new("Frame");track.BackgroundColor3=Color3.fromRGB(37,43,62);track.Position=UDim2.fromOffset(18,122);track.Size=UDim2.new(1,-36,0,9);track.Parent=card;local tc=Instance.new("UICorner");tc.CornerRadius=UDim.new(1,0);tc.Parent=track
local fill=Instance.new("Frame");fill.BackgroundColor3=Color3.fromRGB(127,92,255);fill.Size=UDim2.fromScale(.04,1);fill.Parent=track;local fc=Instance.new("UICorner");fc.CornerRadius=UDim.new(1,0);fc.Parent=fill
local fg=Instance.new("UIGradient");fg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(72,218,187)),ColorSequenceKeypoint.new(.55,Color3.fromRGB(139,98,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(245,194,91))});fg.Parent=fill
local stage=Instance.new("TextLabel");stage.BackgroundTransparency=1;stage.Position=UDim2.fromOffset(18,137);stage.Size=UDim2.new(1,-36,0,16);stage.Text="";stage.TextXAlignment=Enum.TextXAlignment.Right;stage.Font=Enum.Font.Gotham;stage.TextSize=8;stage.TextColor3=Color3.fromRGB(126,136,160);stage.Parent=card

local spin=true;task.spawn(function()local seq={"♪","♫","♬","♫"};local i=1;while spin and note.Parent do note.Text=seq[i];i=i%#seq+1;task.wait(.18)end end)

local base=string.format("https://raw.githubusercontent.com/%s/%s/%s/src/",OWNER,REPO,PINNED_COMMIT)
local aliases={
 ["Main"]="MainV061",
 ["ConfigDefaults"]="ConfigDefaultsV061",
 ["UI/App"]="UI/AppPremiumV061",
 ["Piano/Mapper"]="Piano/MapperV060",
 ["Player/Scheduler"]="Player/SchedulerV060",
 ["Input/InputAdapter"]="Input/InputAdapterV051",
 ["Player/NoteManager"]="Player/NoteManagerV051",
 ["Performance/Humanizer"]="Performance/HumanizerV061",
 ["Cloud/DodoProvider"]="Cloud/DodoProviderV061",
}
local cache,loading={},{};local count=0;local expected=21
local function setStage(txt)
 count+=1;status.Text=txt;stage.Text=string.format("%d/%d",math.min(count,expected),expected)
 TweenService:Create(fill,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.fromScale(math.clamp(.04+count/expected*.91,.04,.95),1)}):Play()
end
local function Require(path)
 if cache[path]~=nil then return cache[path]end
 assert(not loading[path],"[MIDIQWERTY] Circular dependency: "..path);loading[path]=true
 local remote=aliases[path] or path;setStage("Carregando "..remote:gsub("/"," › ").."...")
 local url=base..remote..".lua";local ok,source=pcall(function()return game:HttpGet(url)end)
 if not ok or type(source)~="string" then loading[path]=nil;error("[MIDIQWERTY] Download failed: "..remote.." | "..tostring(source),2)end
 local chunk,err=loadstring(source,"=MIDIQWERTY/"..remote);if not chunk then loading[path]=nil;error("[MIDIQWERTY] Compile failed: "..remote.." | "..tostring(err),2)end
 local good,result=pcall(chunk);loading[path]=nil;if not good then error("[MIDIQWERTY] Runtime failed: "..remote.." | "..tostring(result),2)end;if result==nil then result=true end;cache[path]=result;return result
end

local ok,result=pcall(function()
 local Main=Require("Main");status.Text="Montando interface...";return Main.start({Require=Require,meta={owner=OWNER,repo=REPO,branch=PINNED_COMMIT,version=VERSION,pinned=true}})
end)
if not ok then
 spin=false;status.Text="Falha ao iniciar";status.TextColor3=Color3.fromRGB(239,91,113);stage.Text="VER CONSOLE";warn("[MIDIQWERTY] "..tostring(result));task.delay(5,function()if boot then boot:Destroy()end end);error(result,0)
end
spin=false;status.Text="Pronto";status.TextColor3=Color3.fromRGB(72,218,187);stage.Text="100%";TweenService:Create(fill,TweenInfo.new(.20),{Size=UDim2.fromScale(1,1)}):Play()
task.delay(.28,function()TweenService:Create(card,TweenInfo.new(.22),{BackgroundTransparency=1,Position=UDim2.fromScale(.5,.48)}):Play();TweenService:Create(veil,TweenInfo.new(.25),{BackgroundTransparency=1}):Play();task.wait(.27);if boot then boot:Destroy()end end)
print("[MIDIQWERTY] Loaded "..VERSION.." @ "..PINNED_COMMIT:sub(1,8));return result
