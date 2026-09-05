local BASE_COMMIT="d6ac2a6ae30d2e4fbb987fce9ddb187722964a36"
local URL="https://raw.githubusercontent.com/Johnatafgfdgf/Midi-to-qwerty-roblox-autoplayer/"..BASE_COMMIT.."/src/UI/AppMobileV050.lua"
local ok,source=pcall(function()return game:HttpGet(URL)end);assert(ok and type(source)=="string","[MIDIQWERTY] Failed to load v0.5.0 UI base")
local chunk,err=loadstring(source,"=MIDIQWERTY/UI/AppMobileV050.base");assert(chunk,"[MIDIQWERTY] UI base compile error: "..tostring(err));local Base=chunk();assert(type(Base)=="table" and type(Base.new)=="function","[MIDIQWERTY] Invalid UI base")
local App={};setmetatable(App,{__index=Base})
local C={card=Color3.fromRGB(28,32,46),card2=Color3.fromRGB(39,44,61),accent=Color3.fromRGB(122,88,255),green=Color3.fromRGB(72,210,178),text=Color3.fromRGB(246,248,252),muted=Color3.fromRGB(155,164,185),warn=Color3.fromRGB(245,180,72)}
local function round(o,r)local x=Instance.new("UICorner");x.CornerRadius=UDim.new(0,r or 8);x.Parent=o end
local function stroke(o)local x=Instance.new("UIStroke");x.Color=C.card2;x.Thickness=1;x.Transparency=.35;x.Parent=o end
local function font(o,size,bold,col)o.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham;o.TextSize=size or 10;o.TextColor3=col or C.text end
local function label(p,t,h,bold)local x=Instance.new("TextLabel");x.BackgroundTransparency=1;x.Text=t or "";x.TextXAlignment=Enum.TextXAlignment.Left;x.TextYAlignment=Enum.TextYAlignment.Center;x.Size=UDim2.new(1,0,0,h or 20);font(x,bold and 11 or 9,bold);x.Parent=p;return x end
local function button(p,t,h)local x=Instance.new("TextButton");x.AutoButtonColor=false;x.BackgroundColor3=C.card;x.Text=t or "";x.Size=UDim2.new(1,0,0,h or 34);font(x,10,true);round(x,8);stroke(x);x.Parent=p;return x end
local function row(p,defs,h,gap)gap=gap or 6;h=h or 34;local r=Instance.new("Frame");r.BackgroundTransparency=1;r.Size=UDim2.new(1,0,0,h);r.Parent=p;local n=#defs;local out={};for i,d in ipairs(defs)do local b=button(r,d.text,h);b.Position=UDim2.new((i-1)/n,gap/2,0,0);b.Size=UDim2.new(1/n,-gap,1,0);if d.click then b.Activated:Connect(d.click)end;out[i]=b end;return out end
local function safe(cb,...)if type(cb)=="function" then local ok=pcall(cb,...);return ok end end
local function clamp(v,a,b)return math.max(a,math.min(b,v))end

function App.new(callbacks,config)
 callbacks=callbacks or {};config=config or {};config.playback=config.playback or {};config.humanize=config.humanize or {};config.playback.expression=config.playback.expression or {}
 local app=Base.new(callbacks,config);assert(app and app.pages and app.gui,"[MIDIQWERTY] Base UI failed")
 app.gui.Name="MIDIQWERTY_V051_EXPRESSION"
 for _,d in ipairs(app.gui:GetDescendants())do
  if d:IsA("TextLabel") and d.Text=="v0.5.0 HUMAN LAB" then d.Text="v0.5.1 EXPRESSION";d.Size=UDim2.fromOffset(130,22)
  elseif d:IsA("TextLabel") and d.Text=="0.5.0" then d.Text="0.5.1" end
 end
 local expr=config.playback.expression;expr.enabled=expr.enabled~=false;expr.nativeVelocity=expr.nativeVelocity~=false;expr.minHoldMs=expr.minHoldMs or 24;expr.maxHoldMs=expr.maxHoldMs or 92;expr.velocityInfluence=expr.velocityInfluence or .82;expr.articulationInfluence=expr.articulationInfluence or .70;expr.durationInfluence=expr.durationInfluence or .28
 config.humanize.velocityPreservation=config.humanize.velocityPreservation or .84;config.humanize.dynamicContour=config.humanize.dynamicContour or .55
 local labels={};local nativeAvailable=false
 local function persist()safe(callbacks.onUiState,app.state or "Full",nil)end
 local function rebuildExpression()persist();safe(callbacks.onMode,config.playback.mode or "Both")end
 local function rebuildHuman()persist();safe(callbacks.onHumanDelta,0)end
 local function refresh()
  if labels.mode then labels.mode.Text=expr.enabled and "Expressão de toque: ON" or "Expressão de toque: OFF" end
  if labels.pressure then
   if nativeAvailable and expr.nativeVelocity then labels.pressure.Text="Pressão nativa: DISPONÍVEL • velocity MIDI chega ao backend";labels.pressure.TextColor3=C.green
   else labels.pressure.Text="Pressão nativa: não disponível • usando duração + articulação + timing";labels.pressure.TextColor3=C.warn end
  end
  if labels.hold then labels.hold.Text=string.format("Janela de toque: %d–%d ms",math.floor(expr.minHoldMs),math.floor(expr.maxHoldMs))end
  if labels.vel then labels.vel.Text=string.format("Influência do velocity: %d%%",math.floor(expr.velocityInfluence*100+.5))end
  if labels.art then labels.art.Text=string.format("Influência da articulação: %d%%",math.floor(expr.articulationInfluence*100+.5))end
  if labels.dur then labels.dur.Text=string.format("Influência da duração MIDI: %d%%",math.floor(expr.durationInfluence*100+.5))end
  if labels.preserve then labels.preserve.Text=string.format("Preservar velocity original: %d%%",math.floor(config.humanize.velocityPreservation*100+.5))end
  if labels.contour then labels.contour.Text=string.format("Curva dinâmica de frase: %d%%",math.floor(config.humanize.dynamicContour*100+.5))end
 end
 do
  local p=app.pages.Human
  label(p,"PRESSÃO & TOQUE",22,true)
  local info=label(p,"O MIDI tem força/velocity. Se o piano só aceita QWERTY, não existe volume analógico real; a build traduz essa dinâmica em toque, duração, articulação, mãos e acordes.",48,false);info.TextWrapped=true;info.TextColor3=C.muted;info.TextSize=9
  labels.pressure=label(p,"Pressão nativa: verificando...",30,true);labels.pressure.TextWrapped=true
  labels.mode=label(p,"",18,true);local toggle=button(p,"Ligar/desligar expressão",34);toggle.Activated:Connect(function()expr.enabled=not expr.enabled;rebuildExpression();refresh()end)
  labels.hold=label(p,"",18,true)
  row(p,{{text="Min -5",click=function()expr.minHoldMs=clamp(expr.minHoldMs-5,8,expr.maxHoldMs);rebuildExpression();refresh()end},{text="Min +5",click=function()expr.minHoldMs=clamp(expr.minHoldMs+5,8,expr.maxHoldMs);rebuildExpression();refresh()end},{text="Max -5",click=function()expr.maxHoldMs=clamp(expr.maxHoldMs-5,expr.minHoldMs,260);rebuildExpression();refresh()end},{text="Max +5",click=function()expr.maxHoldMs=clamp(expr.maxHoldMs+5,expr.minHoldMs,260);rebuildExpression();refresh()end}},34,4)
  labels.vel=label(p,"",18,true);row(p,{{text="-10%",click=function()expr.velocityInfluence=clamp(expr.velocityInfluence-.1,0,1);rebuildExpression();refresh()end},{text="+10%",click=function()expr.velocityInfluence=clamp(expr.velocityInfluence+.1,0,1);rebuildExpression();refresh()end}},34,6)
  labels.art=label(p,"",18,true);row(p,{{text="-10%",click=function()expr.articulationInfluence=clamp(expr.articulationInfluence-.1,0,1);rebuildExpression();refresh()end},{text="+10%",click=function()expr.articulationInfluence=clamp(expr.articulationInfluence+.1,0,1);rebuildExpression();refresh()end}},34,6)
  labels.dur=label(p,"",18,true);row(p,{{text="-10%",click=function()expr.durationInfluence=clamp(expr.durationInfluence-.1,0,1);rebuildExpression();refresh()end},{text="+10%",click=function()expr.durationInfluence=clamp(expr.durationInfluence+.1,0,1);rebuildExpression();refresh()end}},34,6)
  labels.preserve=label(p,"",18,true);row(p,{{text="-5%",click=function()config.humanize.velocityPreservation=clamp(config.humanize.velocityPreservation-.05,.4,1);rebuildHuman();refresh()end},{text="+5%",click=function()config.humanize.velocityPreservation=clamp(config.humanize.velocityPreservation+.05,.4,1);rebuildHuman();refresh()end}},34,6)
  labels.contour=label(p,"",18,true);row(p,{{text="-5%",click=function()config.humanize.dynamicContour=clamp(config.humanize.dynamicContour-.05,0,1);rebuildHuman();refresh()end},{text="+5%",click=function()config.humanize.dynamicContour=clamp(config.humanize.dynamicContour+.05,0,1);rebuildHuman();refresh()end}},34,6)
 end
 local oldBackend=app.setBackend
 app.setBackend=function(self,x)
  if oldBackend then oldBackend(self,x)end
  nativeAvailable=type(x)=="string" and string.find(x,"VelocityHook",1,true)~=nil;refresh()
 end
 local oldSong=app.setSong
 app.setSong=function(self,item,a,mapStats,perfStats)
  if oldSong then oldSong(self,item,a,mapStats,perfStats)end
  if perfStats and self.performanceInfo and perfStats.velocityMin then
   self.performanceInfo.Text=self.performanceInfo.Text..string.format("  •  dinâmica %d–%d%%",math.floor((perfStats.velocityMin or 0)*100),math.floor((perfStats.velocityMax or 1)*100))
  end
 end
 refresh();return app
end
return App
