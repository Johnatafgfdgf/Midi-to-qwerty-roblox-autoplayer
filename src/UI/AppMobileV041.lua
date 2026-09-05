local App={};App.__index=App
local UIS=game:GetService("UserInputService")
local Players=game:GetService("Players")
local CoreGui=game:GetService("CoreGui")

local C={bg=Color3.fromRGB(10,12,18),panel=Color3.fromRGB(18,21,31),card=Color3.fromRGB(28,32,46),card2=Color3.fromRGB(38,43,60),accent=Color3.fromRGB(121,86,255),green=Color3.fromRGB(71,211,176),text=Color3.fromRGB(245,247,252),muted=Color3.fromRGB(154,163,185),danger=Color3.fromRGB(240,91,111)}
local function round(o,r)local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r or 9);c.Parent=o end
local function outline(o)local s=Instance.new("UIStroke");s.Color=C.card2;s.Transparency=.35;s.Thickness=1;s.Parent=o end
local function txt(o,size,bold,color)o.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham;o.TextSize=size or 12;o.TextColor3=color or C.text end
local function label(p,t,h,bold)local x=Instance.new("TextLabel");x.BackgroundTransparency=1;x.Text=t or "";x.TextXAlignment=Enum.TextXAlignment.Left;x.TextYAlignment=Enum.TextYAlignment.Center;x.Size=UDim2.new(1,0,0,h or 24);txt(x,bold and 13 or 11,bold);x.Parent=p;return x end
local function button(p,t,h)local x=Instance.new("TextButton");x.AutoButtonColor=false;x.BackgroundColor3=C.card;x.Text=t or "";x.Size=UDim2.new(1,0,0,h or 38);txt(x,11,true);round(x,8);outline(x);x.Parent=p;return x end
local function list(p,pad)local l=Instance.new("UIListLayout");l.Padding=UDim.new(0,pad or 6);l.SortOrder=Enum.SortOrder.LayoutOrder;l.Parent=p;return l end
local function grid(p,cols,h,pad)local g=Instance.new("UIGridLayout");pad=pad or 6;g.CellPadding=UDim2.fromOffset(pad,pad);g.CellSize=UDim2.new(1/cols,-(pad*(cols-1))/cols,0,h or 38);g.SortOrder=Enum.SortOrder.LayoutOrder;g.Parent=p;return g end
local function scroll(p)local s=Instance.new("ScrollingFrame");s.BackgroundTransparency=1;s.BorderSizePixel=0;s.Size=UDim2.fromScale(1,1);s.CanvasSize=UDim2.new();s.AutomaticCanvasSize=Enum.AutomaticSize.Y;s.ScrollBarThickness=3;s.ScrollBarImageColor3=C.accent;s.ScrollingDirection=Enum.ScrollingDirection.Y;s.Parent=p;local pad=Instance.new("UIPadding");pad.PaddingRight=UDim.new(0,5);pad.Parent=s;return s end
local function clear(p)for _,v in ipairs(p:GetChildren())do if not v:IsA("UIListLayout") and not v:IsA("UIGridLayout") and not v:IsA("UIPadding") then v:Destroy() end end end
local function fmt(t)t=math.max(0,t or 0);return string.format("%02d:%02d",math.floor(t/60),math.floor(t%60))end
local function call(f,...)if type(f)=="function" then pcall(f,...) end end

function App.new(callbacks,config)
 callbacks=callbacks or {};config=config or {};config.ui=config.ui or {}
 local self=setmetatable({callbacks=callbacks,config=config,pages={},nav={},allSongs={},song=nil,songFilter="All"},App)
 local gui=Instance.new("ScreenGui");gui.Name="MIDIQWERTY_V041_NEWUI";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;gui.DisplayOrder=10000;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 local parent=(gethui and gethui()) or CoreGui
 if not pcall(function()gui.Parent=parent end) then gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui") end
 self.gui=gui

 local main=Instance.new("Frame");main.Name="Window";main.AnchorPoint=Vector2.new(.5,.5);main.Position=UDim2.fromScale(.37,.48);main.BackgroundColor3=C.bg;main.ClipsDescendants=true;round(main,13);outline(main);main.Parent=gui;self.main=main
 local function resize()
  local v=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
  if v.X>v.Y then main.Size=UDim2.fromOffset(math.clamp(v.X*.43,500,590),math.clamp(v.Y*.58,300,355)) else main.Size=UDim2.fromOffset(math.clamp(v.X-20,320,410),math.clamp(v.Y*.66,430,580)) end
 end
 resize();if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)end

 local header=Instance.new("Frame");header.BackgroundColor3=C.panel;header.Size=UDim2.new(1,0,0,46);header.Parent=main
 local title=label(header,"MIDI QWERTY",46,true);title.Position=UDim2.fromOffset(12,0);title.Size=UDim2.new(0,125,1,0);title.TextSize=15
 local badge=Instance.new("TextLabel");badge.BackgroundColor3=C.green;badge.Text="v0.4.1 NEW UI";badge.Size=UDim2.fromOffset(105,24);badge.Position=UDim2.fromOffset(136,11);txt(badge,10,true,Color3.fromRGB(8,22,18));round(badge,7);badge.Parent=header
 local mini=button(header,"MINI",32);mini.Size=UDim2.fromOffset(48,32);mini.Position=UDim2.new(1,-102,0,7)
 local hide=button(header,"HIDE",32);hide.Size=UDim2.fromOffset(48,32);hide.Position=UDim2.new(1,-51,0,7)

 local body=Instance.new("Frame");body.BackgroundTransparency=1;body.Position=UDim2.fromOffset(7,53);body.Size=UDim2.new(1,-14,1,-60);body.Parent=main
 local rail=Instance.new("Frame");rail.BackgroundColor3=C.panel;rail.Size=UDim2.new(0,104,1,0);round(rail,10);rail.Parent=body
 local rp=Instance.new("UIPadding");rp.PaddingTop=UDim.new(0,7);rp.PaddingLeft=UDim.new(0,7);rp.PaddingRight=UDim.new(0,7);rp.PaddingBottom=UDim.new(0,7);rp.Parent=rail
 list(rail,4)
 local status=label(rail,"Pronto",24,false);status.TextSize=9;status.TextColor3=C.green;status.TextWrapped=true;self.message=status
 local content=Instance.new("Frame");content.BackgroundColor3=C.panel;content.Position=UDim2.fromOffset(111,0);content.Size=UDim2.new(1,-111,1,0);round(content,10);content.ClipsDescendants=true;content.Parent=body
 local cp=Instance.new("UIPadding");cp.PaddingTop=UDim.new(0,8);cp.PaddingLeft=UDim.new(0,8);cp.PaddingRight=UDim.new(0,8);cp.PaddingBottom=UDim.new(0,8);cp.Parent=content

 local function show(name)
  for n,p in pairs(self.pages)do p.Visible=n==name end
  for n,b in pairs(self.nav)do b.BackgroundColor3=n==name and C.accent or C.card end
  self.activeTab=name
 end
 local spec={{"Songs","MUSICAS"},{"Player","PLAYER"},{"Parts","PARTES"},{"Piano","PIANO"},{"Human","HUMANO"},{"Settings","AJUSTES"},{"Diag","DIAG"}}
 for _,s in ipairs(spec)do
  local key,name=s[1],s[2];local b=button(rail,name,31);self.nav[key]=b;b.TextSize=10;b.Activated:Connect(function()show(key)end)
  local holder=Instance.new("Frame");holder.BackgroundTransparency=1;holder.Size=UDim2.fromScale(1,1);holder.Visible=false;holder.Parent=content
  local page=scroll(holder);list(page,6);self.pages[key]=page
 end

 local p=self.pages.Songs
 local search=Instance.new("TextBox");search.PlaceholderText="Pesquisar MIDI...";search.Text="";search.ClearTextOnFocus=false;search.BackgroundColor3=C.card;search.Size=UDim2.new(1,0,0,38);search.TextXAlignment=Enum.TextXAlignment.Left;txt(search,11,false);round(search,8);search.Parent=p;self.searchBox=search
 local tools=Instance.new("Frame");tools.BackgroundTransparency=1;tools.Size=UDim2.new(1,0,0,38);tools.Parent=p;grid(tools,2,38,6)
 local refresh=button(tools,"Atualizar",38);local filter=button(tools,"Todos",38);self.filterButton=filter
 refresh.Activated:Connect(function()call(callbacks.onRefresh)end)
 filter.Activated:Connect(function()local a={{"All","Todos"},{"Favorites","Favoritos"},{"Recent","Recentes"}};local idx=1;for i,v in ipairs(a)do if v[1]==self.songFilter then idx=i break end end;idx=idx%#a+1;self.songFilter=a[idx][1];filter.Text=a[idx][2];self:_renderSongs()end)
 self.songStatus=label(p,"Procurando MIDIs...",22,false);self.songStatus.TextSize=9;self.songStatus.TextColor3=C.muted
 local sl=Instance.new("Frame");sl.BackgroundTransparency=1;sl.AutomaticSize=Enum.AutomaticSize.Y;sl.Size=UDim2.new(1,0,0,0);sl.Parent=p;list(sl,5);self.songList=sl
 search:GetPropertyChangedSignal("Text"):Connect(function()self:_renderSongs()end)

 p=self.pages.Player
 self.songName=label(p,"Nenhum MIDI",26,true);self.songName.TextSize=14
 self.songInfo=label(p,"Selecione uma musica na aba MUSICAS.",34,false);self.songInfo.TextWrapped=true;self.songInfo.TextSize=9;self.songInfo.TextColor3=C.muted
 local bar=Instance.new("Frame");bar.BackgroundColor3=C.card2;bar.Size=UDim2.new(1,0,0,9);round(bar,5);bar.Parent=p
 self.progress=Instance.new("Frame");self.progress.BackgroundColor3=C.accent;self.progress.Size=UDim2.fromScale(0,1);round(self.progress,5);self.progress.Parent=bar
 self.timeLabel=label(p,"00:00 / 00:00",20,false);self.timeLabel.TextSize=9;self.timeLabel.TextColor3=C.muted
 local ctr=Instance.new("Frame");ctr.BackgroundTransparency=1;ctr.Size=UDim2.new(1,0,0,42);ctr.Parent=p;grid(ctr,5,42,5)
 local prev=button(ctr,"|<",42);local back=button(ctr,"-5",42);self.playButton=button(ctr,"PLAY",42);local fwd=button(ctr,"+5",42);local nxt=button(ctr,">|",42)
 prev.Activated:Connect(function()call(callbacks.onPrev)end);back.Activated:Connect(function()call(callbacks.onSeekRelative,-5)end);self.playButton.Activated:Connect(function()call(callbacks.onPlayPause)end);fwd.Activated:Connect(function()call(callbacks.onSeekRelative,5)end);nxt.Activated:Connect(function()call(callbacks.onNext)end)
 local row=Instance.new("Frame");row.BackgroundTransparency=1;row.Size=UDim2.new(1,0,0,36);row.Parent=p;grid(row,3,36,5)
 local stop=button(row,"STOP",36);self.speedButton=button(row,"1.00x",36);local panic=button(row,"SOLTAR",36)
 stop.Activated:Connect(function()call(callbacks.onStop)end);self.speedButton.Activated:Connect(function()call(callbacks.onCycleSpeed)end);panic.Activated:Connect(function()call(callbacks.onPanic)end)
 label(p,"Parte tocada",20,true)
 local modes=Instance.new("Frame");modes.BackgroundTransparency=1;modes.Size=UDim2.new(1,0,0,78);modes.Parent=p;grid(modes,3,36,5)
 for _,m in ipairs({"Both","Left","Right","Melody","Accompaniment","Bass"})do local b=button(modes,m,36);b.Activated:Connect(function()call(callbacks.onMode,m)end)end
 self.currentNotes=label(p,"Ultima tecla: -",20,false);self.currentNotes.TextSize=9;self.currentNotes.TextColor3=C.green
 self.performanceInfo=label(p,"Performance pronta",34,false);self.performanceInfo.TextSize=9;self.performanceInfo.TextWrapped=true;self.performanceInfo.TextColor3=C.muted

 p=self.pages.Parts
 self.splitLabel=label(p,"Separacao: aguardando MIDI",24,true)
 self.confidenceLabel=label(p,"",20,false);self.confidenceLabel.TextSize=9;self.confidenceLabel.TextColor3=C.muted
 label(p,"Canais",20,true)
 self.channelBox=Instance.new("Frame");self.channelBox.BackgroundTransparency=1;self.channelBox.Size=UDim2.new(1,0,0,82);self.channelBox.Parent=p;grid(self.channelBox,4,36,5)
 label(p,"Tracks",20,true)
 self.trackList=Instance.new("Frame");self.trackList.BackgroundTransparency=1;self.trackList.AutomaticSize=Enum.AutomaticSize.Y;self.trackList.Size=UDim2.new(1,0,0,0);self.trackList.Parent=p;list(self.trackList,5)

 p=self.pages.Piano
 self.profileName=label(p,"Perfil de piano",24,true)
 local pd=label(p,"Teste C4, C5 e C6 antes de tocar a musica inteira.",32,false);pd.TextSize=9;pd.TextWrapped=true;pd.TextColor3=C.muted
 local tests=Instance.new("Frame");tests.BackgroundTransparency=1;tests.Size=UDim2.new(1,0,0,40);tests.Parent=p;grid(tests,3,40,5)
 for _,x in ipairs({{60,"C4"},{72,"C5"},{84,"C6"}})do local b=button(tests,"Testar "..x[2],40);b.Activated:Connect(function()call(callbacks.onTestNote,x[1])end)end
 label(p,"Mapa MIDI -> QWERTY",20,true)
 self.profileList=Instance.new("Frame");self.profileList.BackgroundTransparency=1;self.profileList.AutomaticSize=Enum.AutomaticSize.Y;self.profileList.Size=UDim2.new(1,0,0,0);self.profileList.Parent=p;list(self.profileList,5)

 p=self.pages.Human
 label(p,"Humanizacao musical",24,true)
 local hd=label(p,"Use Exact para testar fidelidade. Depois aumente aos poucos.",32,false);hd.TextSize=9;hd.TextWrapped=true;hd.TextColor3=C.muted
 local presets=Instance.new("Frame");presets.BackgroundTransparency=1;presets.Size=UDim2.new(1,0,0,78);presets.Parent=p;grid(presets,2,36,5)
 for _,v in ipairs({"Exact","Very Subtle","Natural","Expressive"})do local b=button(presets,v,36);b.Activated:Connect(function()call(callbacks.onPreset,v)end)end
 self.humanLabel=label(p,"Forca: 0%",22,true)
 local hr=Instance.new("Frame");hr.BackgroundTransparency=1;hr.Size=UDim2.new(1,0,0,38);hr.Parent=p;grid(hr,2,38,5)
 local hm=button(hr,"Menos",38);local hp=button(hr,"Mais",38);hm.Activated:Connect(function()call(callbacks.onHumanDelta,-.02)end);hp.Activated:Connect(function()call(callbacks.onHumanDelta,.02)end)

 p=self.pages.Settings
 label(p,"Conversao",24,true)
 self.transposeButton=button(p,"Transpose: 0",36);self.transposeButton.Activated:Connect(function()call(callbacks.onTransposeDelta,1)end)
 local tr=Instance.new("Frame");tr.BackgroundTransparency=1;tr.Size=UDim2.new(1,0,0,38);tr.Parent=p;grid(tr,2,38,5)
 local tm=button(tr,"Transpose -1",38);local tp=button(tr,"Transpose +1",38);tm.Activated:Connect(function()call(callbacks.onTransposeDelta,-1)end);tp.Activated:Connect(function()call(callbacks.onTransposeDelta,1)end)
 self.rangeButton=button(p,"Range: SmartOctave",36);self.rangeButton.Activated:Connect(function()call(callbacks.onCycleRange)end)
 self.quantButton=button(p,"Quantizacao: Off",36);self.quantButton.Activated:Connect(function()call(callbacks.onCycleQuantization)end)
 self.maxKeysLabel=label(p,"Max. notas no acorde: 10",22,true)
 local kr=Instance.new("Frame");kr.BackgroundTransparency=1;kr.Size=UDim2.new(1,0,0,38);kr.Parent=p;grid(kr,2,38,5)
 local km=button(kr,"-1",38);local kp=button(kr,"+1",38);km.Activated:Connect(function()call(callbacks.onMaxKeysDelta,-1)end);kp.Activated:Connect(function()call(callbacks.onMaxKeysDelta,1)end)
 local ex=Instance.new("Frame");ex.BackgroundTransparency=1;ex.Size=UDim2.new(1,0,0,38);ex.Parent=p;grid(ex,2,38,5)
 local e1=button(ex,"Exportar QWERTY",38);local e2=button(ex,"Exportar analise",38);e1.Activated:Connect(function()call(callbacks.onExportSequence)end);e2.Activated:Connect(function()call(callbacks.onExportAnalysis)end)

 p=self.pages.Diag
 self.backendLabel=label(p,"Input: ...",24,true)
 self.diagLabel=label(p,"v0.4.1 NEW UI\nSem musica carregada.",180,false);self.diagLabel.TextSize=10;self.diagLabel.TextColor3=C.muted;self.diagLabel.TextWrapped=true;self.diagLabel.TextYAlignment=Enum.TextYAlignment.Top

 local miniFrame=Instance.new("Frame");miniFrame.AnchorPoint=Vector2.new(.5,1);miniFrame.Position=UDim2.new(.5,0,1,-10);miniFrame.Size=UDim2.fromOffset(330,52);miniFrame.BackgroundColor3=C.bg;miniFrame.Visible=false;round(miniFrame,11);outline(miniFrame);miniFrame.Parent=gui;self.miniFrame=miniFrame
 self.miniName=label(miniFrame,"MIDI QWERTY v0.4.1",52,true);self.miniName.Position=UDim2.fromOffset(10,0);self.miniName.Size=UDim2.new(1,-128,1,0);self.miniName.TextTruncate=Enum.TextTruncate.AtEnd
 local mp=button(miniFrame,"PLAY",36);mp.Size=UDim2.fromOffset(52,36);mp.Position=UDim2.new(1,-112,0,8);mp.Activated:Connect(function()call(callbacks.onPlayPause)end)
 local open=button(miniFrame,"ABRIR",36);open.Size=UDim2.fromOffset(52,36);open.Position=UDim2.new(1,-56,0,8)
 local floating=button(gui,"MIDI",52);floating.Size=UDim2.fromOffset(58,52);floating.Position=UDim2.fromScale(.9,.5);floating.AnchorPoint=Vector2.new(.5,.5);floating.BackgroundColor3=C.accent;floating.Visible=false;floating.Parent=gui;self.floating=floating

 function self:setState(state)
  if state~="Full" and state~="Mini" and state~="Hidden" then state="Full" end
  self.state=state;gui.Enabled=true;main.Visible=state=="Full";miniFrame.Visible=state=="Mini";floating.Visible=state=="Hidden";call(callbacks.onUiState,state,state=="Hidden" and floating.Position or nil)
 end
 mini.Activated:Connect(function()self:setState("Mini")end);hide.Activated:Connect(function()self:setState("Hidden")end);open.Activated:Connect(function()self:setState("Full")end);floating.Activated:Connect(function()self:setState("Full")end)

 local drag=false;local dragStart;local startPos
 header.Active=true;header.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true;dragStart=i.Position;startPos=main.Position end end)
 UIS.InputChanged:Connect(function(i)if drag and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then local v=workspace.CurrentCamera.ViewportSize;local d=i.Position-dragStart;main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)end end)
 UIS.InputEnded:Connect(function(i)if drag and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1) then drag=false end end)

 show("Songs");self:setState("Full")
 return self
end

function App:_renderSongs()
 if not self.songList then return end;clear(self.songList);local q=string.lower(self.searchBox and self.searchBox.Text or "");local shown=0
 for _,s in ipairs(self.allSongs or {})do local ok=q=="" or string.find(string.lower(s.name or s.path or ""),q,1,true);if self.songFilter=="Favorites" then ok=ok and s.favorite elseif self.songFilter=="Recent" then ok=ok and s.recentRank~=nil end;if ok then shown+=1;local b=button(self.songList,(s.favorite and "* " or "")..(s.name or s.path),42);b.TextXAlignment=Enum.TextXAlignment.Left;b.TextTruncate=Enum.TextTruncate.AtEnd;b.Activated:Connect(function()call(self.callbacks.onSelectSong,s)end)end end
 if shown==0 then local l=label(self.songList,"Nenhum MIDI nesta lista.",30,false);l.TextColor3=C.muted;l.TextSize=10 end
end
function App:setSongs(s,status)self.allSongs=s or {};self.songStatus.Text=status or "";self:_renderSongs()end
function App:setMessage(x)self.message.Text=tostring(x or "");self.message.TextColor3=C.green end
function App:setError(x)self.message.Text="Erro: "..tostring(x);self.message.TextColor3=C.danger end
function App:setBackend(x)self.backendLabel.Text="Input: "..tostring(x)end
function App:setFavorite(v)if self.song then self.song.favorite=v end end
function App:setSong(item,a,mapStats,perfStats)self.song=item;self.songName.Text=item and (item.name or item.path) or "Nenhum MIDI";self.miniName.Text="v0.4.1  "..self.songName.Text;if a then self.songInfo.Text=string.format("%d notas | %.1fs | MIDI %s-%s",a.noteCount or 0,a.duration or 0,tostring(a.pitchMin or "?"),tostring(a.pitchMax or "?"))end;if mapStats then self.performanceInfo.Text=string.format("Cobertura %.1f%% | adaptadas %d | descartadas %d",(mapStats.coverage or 0)*100,mapStats.adapted or 0,mapStats.dropped or 0)end end
function App:setProgress(pos,dur,stats,playing)local f=dur and dur>0 and math.clamp(pos/dur,0,1) or 0;self.progress.Size=UDim2.fromScale(f,1);self.timeLabel.Text=fmt(pos).." / "..fmt(dur);self.playButton.Text=playing and "PAUSE" or "PLAY";local avg=(stats and stats.processed or 0)>0 and (stats.driftSumMs or 0)/stats.processed or 0;self.diagLabel.Text=string.format("v0.4.1 NEW UI\nPosicao: %s\nEventos: %d\nAtrasados: %d\nIgnorados: %d\nDrift medio: %.2f ms\nPico: %.2f ms",fmt(pos),stats and stats.processed or 0,stats and stats.late or 0,stats and stats.skipped or 0,avg,stats and stats.driftPeakMs or 0)end
function App:setActiveNotes(t)self.currentNotes.Text="Ultima tecla: "..((t and #t>0)and table.concat(t," ")or "-")end
function App:setSpeed(v)self.speedButton.Text=string.format("%.2fx",v or 1)end
function App:setHumanStrength(v)self.humanLabel.Text=string.format("Forca: %d%%",math.floor((v or 0)*100+.5))end
function App:setTranspose(v)self.transposeButton.Text="Transpose: "..tostring(v or 0)end
function App:setRange(v)self.rangeButton.Text="Range: "..tostring(v)end
function App:setQuantization(v)self.quantButton.Text="Quantizacao: "..tostring(v)end
function App:setMaxKeys(v)self.maxKeysLabel.Text="Max. notas no acorde: "..tostring(v)end
function App:setAB()end
function App:setAnalysis(a,enabledTracks,enabledChannels)if not a then return end;self.splitLabel.Text="Separacao: "..tostring(a.splitNote or "auto");self.confidenceLabel.Text=string.format("Confianca %d%% | vozes %s",math.floor((a.handConfidence or 0)*100+.5),tostring(a.voiceCount or "?"));clear(self.channelBox);local used={};for _,n in ipairs(a.notes or {})do used[n.channel]=true end;for ch=1,16 do if used[ch] then local active=enabledChannels[ch]~=false;local b=button(self.channelBox,(active and "ON " or "OFF ").."Ch"..ch,36);b.Activated:Connect(function()active=not active;b.Text=(active and "ON " or "OFF ").."Ch"..ch;call(self.callbacks.onToggleChannel,ch,active)end)end end;clear(self.trackList);for _,tr in ipairs(a.tracks or {})do local active=enabledTracks[tr.index]~=false;local b=button(self.trackList,(active and "ON  " or "OFF ")..(tr.name or("Track "..tr.index)).."  "..tostring(tr.noteCount or 0),40);b.TextXAlignment=Enum.TextXAlignment.Left;b.Activated:Connect(function()active=not active;b.Text=(active and "ON  " or "OFF ")..(tr.name or("Track "..tr.index)).."  "..tostring(tr.noteCount or 0);call(self.callbacks.onToggleTrack,tr.index,active)end)end end
function App:setProfile(profile)if not profile then return end;self.profileName.Text=(profile.name or profile.id).." | MIDI "..tostring(profile.lowest).."-"..tostring(profile.highest);clear(self.profileList);for note=profile.lowest,profile.highest do local row=Instance.new("Frame");row.BackgroundColor3=C.card;row.Size=UDim2.new(1,0,0,34);round(row,7);row.Parent=self.profileList;local l=label(row,"MIDI "..note,34,false);l.Position=UDim2.fromOffset(8,0);l.Size=UDim2.new(.45,0,1,0);local box=Instance.new("TextBox");box.BackgroundColor3=C.card2;box.Text=profile.map[note] or "";box.Size=UDim2.new(.45,-8,0,26);box.Position=UDim2.new(.55,0,0,4);txt(box,11,true);round(box,6);box.Parent=row;box.FocusLost:Connect(function()if #box.Text==1 then call(self.callbacks.onProfileMapping,note,box.Text)else box.Text=profile.map[note] or "" end end)end end
function App:destroy()if self.gui then self.gui:Destroy()end end
return App
