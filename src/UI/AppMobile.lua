local App={};App.__index=App
local UIS=game:GetService("UserInputService")
local CoreGui=game:GetService("CoreGui")
local Players=game:GetService("Players")

local C={bg=Color3.fromRGB(12,14,22),panel=Color3.fromRGB(20,23,34),card=Color3.fromRGB(30,34,49),card2=Color3.fromRGB(40,45,63),accent=Color3.fromRGB(124,92,255),accent2=Color3.fromRGB(71,211,176),text=Color3.fromRGB(245,247,252),muted=Color3.fromRGB(157,165,187),danger=Color3.fromRGB(237,91,111)}
local function corner(o,r)local x=Instance.new("UICorner");x.CornerRadius=UDim.new(0,r or 10);x.Parent=o end
local function stroke(o,col)local x=Instance.new("UIStroke");x.Color=col or C.card2;x.Thickness=1;x.Transparency=.35;x.Parent=o end
local function styleText(o,size,bold,col)o.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham;o.TextSize=size or 13;o.TextColor3=col or C.text end
local function label(p,t,h,bold)local x=Instance.new("TextLabel");x.BackgroundTransparency=1;x.Text=t or "";x.TextXAlignment=Enum.TextXAlignment.Left;x.TextYAlignment=Enum.TextYAlignment.Center;x.Size=UDim2.new(1,0,0,h or 24);styleText(x,bold and 14 or 12,bold);x.Parent=p;return x end
local function button(p,t,h)local x=Instance.new("TextButton");x.AutoButtonColor=false;x.BackgroundColor3=C.card;x.Text=t or "";x.Size=UDim2.new(1,0,0,h or 40);styleText(x,12,true);corner(x,9);stroke(x);x.Parent=p;return x end
local function list(p,pad)local l=Instance.new("UIListLayout");l.Padding=UDim.new(0,pad or 6);l.SortOrder=Enum.SortOrder.LayoutOrder;l.Parent=p;return l end
local function grid(p,cols,h,pad)local g=Instance.new("UIGridLayout");pad=pad or 6;g.CellPadding=UDim2.fromOffset(pad,pad);g.CellSize=UDim2.new(1/cols,-(pad*(cols-1))/cols,0,h or 40);g.SortOrder=Enum.SortOrder.LayoutOrder;g.Parent=p;return g end
local function scroll(p)local s=Instance.new("ScrollingFrame");s.BackgroundTransparency=1;s.BorderSizePixel=0;s.Size=UDim2.fromScale(1,1);s.CanvasSize=UDim2.new();s.AutomaticCanvasSize=Enum.AutomaticSize.Y;s.ScrollBarThickness=3;s.ScrollBarImageColor3=C.accent;s.Parent=p;local pad=Instance.new("UIPadding");pad.PaddingRight=UDim.new(0,5);pad.Parent=s;return s end
local function clear(frame)for _,v in ipairs(frame:GetChildren())do if not v:IsA("UIListLayout") and not v:IsA("UIGridLayout") and not v:IsA("UIPadding") then v:Destroy() end end end
local function fmt(t)t=math.max(0,t or 0);return string.format("%02d:%02d",math.floor(t/60),math.floor(t%60))end
local function safeCall(cb,...)if type(cb)=="function" then local ok=pcall(cb,...);return ok end end

function App.new(callbacks,config)
    callbacks=callbacks or {};config=config or {};config.ui=config.ui or {}
    local self=setmetatable({callbacks=callbacks,config=config,pages={},nav={},allSongs={},song=nil,songFilter="All"},App)

    local gui=Instance.new("ScreenGui");gui.Name="MIDIQWERTY_UI";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;gui.DisplayOrder=5000;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    local parent=(gethui and gethui()) or CoreGui
    if not pcall(function()gui.Parent=parent end) then gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui") end
    self.gui=gui

    local main=Instance.new("Frame");main.Name="Window";main.AnchorPoint=Vector2.new(.5,.5);main.Position=UDim2.fromScale(.42,.48);main.BackgroundColor3=C.bg;main.ClipsDescendants=true;corner(main,14);stroke(main);main.Parent=gui;self.main=main
    local function resize()
        local v=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800,450)
        if v.X>v.Y then
            main.Size=UDim2.fromOffset(math.clamp(v.X*.44,470,560),math.clamp(v.Y*.68,300,380))
        else
            main.Size=UDim2.fromOffset(math.clamp(v.X-24,320,410),math.clamp(v.Y*.68,430,590))
        end
    end
    resize();if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)end

    local header=Instance.new("Frame");header.BackgroundTransparency=1;header.Size=UDim2.new(1,0,0,48);header.Parent=main
    local title=label(header,"MIDI › QWERTY",48,true);title.Position=UDim2.fromOffset(14,0);title.Size=UDim2.new(1,-132,1,0);title.TextSize=16
    local mini=button(header,"MINI",34);mini.Size=UDim2.fromOffset(50,34);mini.Position=UDim2.new(1,-108,0,7)
    local hide=button(header,"HIDE",34);hide.Size=UDim2.fromOffset(50,34);hide.Position=UDim2.new(1,-54,0,7)

    local body=Instance.new("Frame");body.BackgroundTransparency=1;body.Position=UDim2.fromOffset(8,48);body.Size=UDim2.new(1,-16,1,-56);body.Parent=main
    local rail=Instance.new("Frame");rail.BackgroundColor3=C.panel;rail.Size=UDim2.fromOffset(116,0);rail.Size=UDim2.new(0,116,1,0);corner(rail,11);rail.Parent=body
    local rp=Instance.new("UIPadding");rp.PaddingTop=UDim.new(0,8);rp.PaddingLeft=UDim.new(0,8);rp.PaddingRight=UDim.new(0,8);rp.PaddingBottom=UDim.new(0,8);rp.Parent=rail
    local rl=list(rail,5)
    local status=label(rail,"Pronto",28,false);status.TextSize=10;status.TextColor3=C.accent2;status.TextWrapped=true;self.message=status

    local content=Instance.new("Frame");content.BackgroundColor3=C.panel;content.Position=UDim2.fromOffset(124,0);content.Size=UDim2.new(1,-124,1,0);corner(content,11);content.ClipsDescendants=true;content.Parent=body
    local cp=Instance.new("UIPadding");cp.PaddingTop=UDim.new(0,10);cp.PaddingLeft=UDim.new(0,10);cp.PaddingRight=UDim.new(0,10);cp.PaddingBottom=UDim.new(0,10);cp.Parent=content

    local navSpec={{"Songs","Músicas"},{"Player","Player"},{"Parts","Partes"},{"Piano","Piano"},{"Human","Humano"},{"Settings","Ajustes"},{"Diag","Diag"}}
    local function show(name)
        for n,p in pairs(self.pages)do p.Visible=n==name end
        for n,b in pairs(self.nav)do b.BackgroundColor3=n==name and C.accent or C.card end
        self.activeTab=name
    end
    for _,sp in ipairs(navSpec)do
        local key,txt=sp[1],sp[2];local b=button(rail,txt,34);self.nav[key]=b;b.Activated:Connect(function()show(key)end)
        local holder=Instance.new("Frame");holder.BackgroundTransparency=1;holder.Size=UDim2.fromScale(1,1);holder.Visible=false;holder.Parent=content
        local page=scroll(holder);list(page,7);self.pages[key]=page
    end

    -- Songs
    local p=self.pages.Songs
    local search=Instance.new("TextBox");search.PlaceholderText="Pesquisar MIDI...";search.Text="";search.ClearTextOnFocus=false;search.BackgroundColor3=C.card;search.Size=UDim2.new(1,0,0,40);search.TextXAlignment=Enum.TextXAlignment.Left;styleText(search,12,false);corner(search,9);search.Parent=p;self.searchBox=search
    local tools=Instance.new("Frame");tools.BackgroundTransparency=1;tools.Size=UDim2.new(1,0,0,40);tools.Parent=p;grid(tools,2,40,6)
    local refresh=button(tools,"Atualizar",40);local filter=button(tools,"Todos",40);self.filterButton=filter
    refresh.Activated:Connect(function()safeCall(callbacks.onRefresh)end)
    filter.Activated:Connect(function()local o={{"All","Todos"},{"Favorites","Favoritos"},{"Recent","Recentes"}};local idx=1;for i,v in ipairs(o)do if v[1]==self.songFilter then idx=i break end end;idx=idx%#o+1;self.songFilter=o[idx][1];filter.Text=o[idx][2];self:_renderSongs()end)
    local songStatus=label(p,"Procurando...",24,false);songStatus.TextColor3=C.muted;songStatus.TextSize=10;self.songStatus=songStatus
    local songList=Instance.new("Frame");songList.BackgroundTransparency=1;songList.AutomaticSize=Enum.AutomaticSize.Y;songList.Size=UDim2.new(1,0,0,0);songList.Parent=p;list(songList,6);self.songList=songList
    search:GetPropertyChangedSignal("Text"):Connect(function()self:_renderSongs()end)

    -- Player
    p=self.pages.Player
    local songName=label(p,"Nenhum MIDI",28,true);songName.TextSize=15;self.songName=songName
    local info=label(p,"Selecione uma música.",38,false);info.TextWrapped=true;info.TextColor3=C.muted;info.TextSize=10;self.songInfo=info
    local bar=Instance.new("Frame");bar.BackgroundColor3=C.card2;bar.Size=UDim2.new(1,0,0,10);corner(bar,5);bar.Parent=p
    local fill=Instance.new("Frame");fill.BackgroundColor3=C.accent;fill.Size=UDim2.fromScale(0,1);corner(fill,5);fill.Parent=bar;self.progress=fill
    local time=label(p,"00:00 / 00:00",22,false);time.TextColor3=C.muted;time.TextSize=10;self.timeLabel=time
    local ctr=Instance.new("Frame");ctr.BackgroundTransparency=1;ctr.Size=UDim2.new(1,0,0,44);ctr.Parent=p;grid(ctr,5,44,5)
    local prev=button(ctr,"|<",44);local back=button(ctr,"-5",44);local play=button(ctr,"PLAY",44);local fwd=button(ctr,"+5",44);local nxt=button(ctr,">|",44);self.playButton=play
    prev.Activated:Connect(function()safeCall(callbacks.onPrev)end);back.Activated:Connect(function()safeCall(callbacks.onSeekRelative,-5)end);play.Activated:Connect(function()safeCall(callbacks.onPlayPause)end);fwd.Activated:Connect(function()safeCall(callbacks.onSeekRelative,5)end);nxt.Activated:Connect(function()safeCall(callbacks.onNext)end)
    local row=Instance.new("Frame");row.BackgroundTransparency=1;row.Size=UDim2.new(1,0,0,40);row.Parent=p;grid(row,3,40,6)
    local stop=button(row,"STOP",40);local speed=button(row,"1.00x",40);local panic=button(row,"Soltar",40);self.speedButton=speed
    stop.Activated:Connect(function()safeCall(callbacks.onStop)end);speed.Activated:Connect(function()safeCall(callbacks.onCycleSpeed)end);panic.Activated:Connect(function()safeCall(callbacks.onPanic)end)
    label(p,"Parte tocada",22,true)
    local modes=Instance.new("Frame");modes.BackgroundTransparency=1;modes.Size=UDim2.new(1,0,0,86);modes.Parent=p;grid(modes,3,40,6)
    for _,m in ipairs({"Both","Left","Right","Melody","Accompaniment","Bass"})do local b=button(modes,m,40);b.Activated:Connect(function()safeCall(callbacks.onMode,m)end)end
    local active=label(p,"Última tecla: -",22,false);active.TextColor3=C.accent2;active.TextSize=10;self.currentNotes=active
    local perf=label(p,"Performance pronta",38,false);perf.TextWrapped=true;perf.TextColor3=C.muted;perf.TextSize=10;self.performanceInfo=perf

    -- Parts
    p=self.pages.Parts
    self.splitLabel=label(p,"Separação: aguardando MIDI",26,true)
    self.confidenceLabel=label(p,"",22,false);self.confidenceLabel.TextColor3=C.muted;self.confidenceLabel.TextSize=10
    label(p,"Canais",22,true)
    local channels=Instance.new("Frame");channels.BackgroundTransparency=1;channels.Size=UDim2.new(1,0,0,92);channels.Parent=p;grid(channels,4,40,5);self.channelBox=channels
    label(p,"Tracks",22,true)
    local tracks=Instance.new("Frame");tracks.BackgroundTransparency=1;tracks.AutomaticSize=Enum.AutomaticSize.Y;tracks.Size=UDim2.new(1,0,0,0);tracks.Parent=p;list(tracks,6);self.trackList=tracks

    -- Piano
    p=self.pages.Piano
    self.profileName=label(p,"Perfil de piano",28,true)
    local desc=label(p,"Teste C4/C5/C6 antes de tocar a música inteira.",36,false);desc.TextWrapped=true;desc.TextColor3=C.muted;desc.TextSize=10
    local tests=Instance.new("Frame");tests.BackgroundTransparency=1;tests.Size=UDim2.new(1,0,0,42);tests.Parent=p;grid(tests,3,42,6)
    for _,x in ipairs({{60,"C4"},{72,"C5"},{84,"C6"}})do local b=button(tests,"Testar "..x[2],42);b.Activated:Connect(function()safeCall(callbacks.onTestNote,x[1])end)end
    label(p,"Mapa MIDI → QWERTY",22,true)
    local profileList=Instance.new("Frame");profileList.BackgroundTransparency=1;profileList.AutomaticSize=Enum.AutomaticSize.Y;profileList.Size=UDim2.new(1,0,0,0);profileList.Parent=p;list(profileList,5);self.profileList=profileList

    -- Human
    p=self.pages.Human
    label(p,"Humanização musical",28,true)
    local hdesc=label(p,"Comece em Exact ou Very Subtle enquanto validamos a conversão.",38,false);hdesc.TextWrapped=true;hdesc.TextColor3=C.muted;hdesc.TextSize=10
    local presets=Instance.new("Frame");presets.BackgroundTransparency=1;presets.Size=UDim2.new(1,0,0,86);presets.Parent=p;grid(presets,2,40,6)
    for _,x in ipairs({"Exact","Very Subtle","Natural","Expressive"})do local b=button(presets,x,40);b.Activated:Connect(function()safeCall(callbacks.onPreset,x)end)end
    self.humanLabel=label(p,"Força: 0%",24,true)
    local hr=Instance.new("Frame");hr.BackgroundTransparency=1;hr.Size=UDim2.new(1,0,0,42);hr.Parent=p;grid(hr,2,42,6)
    local hm=button(hr,"Menos",42);local hp=button(hr,"Mais",42);hm.Activated:Connect(function()safeCall(callbacks.onHumanDelta,-.02)end);hp.Activated:Connect(function()safeCall(callbacks.onHumanDelta,.02)end)

    -- Settings
    p=self.pages.Settings
    label(p,"Conversão",28,true)
    self.transposeButton=button(p,"Transpose: 0",40);self.transposeButton.Activated:Connect(function()safeCall(callbacks.onTransposeDelta,1)end)
    local tr=Instance.new("Frame");tr.BackgroundTransparency=1;tr.Size=UDim2.new(1,0,0,40);tr.Parent=p;grid(tr,2,40,6)
    local tm=button(tr,"-1 semitom",40);local tp=button(tr,"+1 semitom",40);tm.Activated:Connect(function()safeCall(callbacks.onTransposeDelta,-1)end);tp.Activated:Connect(function()safeCall(callbacks.onTransposeDelta,1)end)
    self.rangeButton=button(p,"Range: SmartOctave",40);self.rangeButton.Activated:Connect(function()safeCall(callbacks.onCycleRange)end)
    self.quantButton=button(p,"Quantização: Off",40);self.quantButton.Activated:Connect(function()safeCall(callbacks.onCycleQuantization)end)
    self.maxKeysLabel=label(p,"Máx. notas: 10",24,true)
    local kr=Instance.new("Frame");kr.BackgroundTransparency=1;kr.Size=UDim2.new(1,0,0,40);kr.Parent=p;grid(kr,2,40,6)
    local km=button(kr,"-1",40);local kp=button(kr,"+1",40);km.Activated:Connect(function()safeCall(callbacks.onMaxKeysDelta,-1)end);kp.Activated:Connect(function()safeCall(callbacks.onMaxKeysDelta,1)end)
    local ex=Instance.new("Frame");ex.BackgroundTransparency=1;ex.Size=UDim2.new(1,0,0,40);ex.Parent=p;grid(ex,2,40,6)
    local e1=button(ex,"Export QWERTY",40);local e2=button(ex,"Export análise",40);e1.Activated:Connect(function()safeCall(callbacks.onExportSequence)end);e2.Activated:Connect(function()safeCall(callbacks.onExportAnalysis)end)

    -- Diagnostics
    p=self.pages.Diag
    self.backendLabel=label(p,"Input: ...",26,true)
    self.diagLabel=label(p,"Sem música carregada.",180,false);self.diagLabel.TextWrapped=true;self.diagLabel.TextYAlignment=Enum.TextYAlignment.Top;self.diagLabel.TextColor3=C.muted;self.diagLabel.TextSize=10

    -- Mini / hidden
    local miniFrame=Instance.new("Frame");miniFrame.AnchorPoint=Vector2.new(0,1);miniFrame.Position=UDim2.new(0,14,1,-14);miniFrame.Size=UDim2.fromOffset(300,54);miniFrame.BackgroundColor3=C.bg;miniFrame.Visible=false;corner(miniFrame,12);stroke(miniFrame);miniFrame.Parent=gui;self.miniFrame=miniFrame
    self.miniName=label(miniFrame,"MIDI QWERTY",54,true);self.miniName.Position=UDim2.fromOffset(12,0);self.miniName.Size=UDim2.new(1,-124,1,0);self.miniName.TextTruncate=Enum.TextTruncate.AtEnd
    local miniPlay=button(miniFrame,"PLAY",38);miniPlay.Size=UDim2.fromOffset(48,38);miniPlay.Position=UDim2.new(1,-108,0,8);miniPlay.Activated:Connect(function()safeCall(callbacks.onPlayPause)end)
    local open=button(miniFrame,"ABRIR",38);open.Size=UDim2.fromOffset(52,38);open.Position=UDim2.new(1,-56,0,8)
    local floating=button(gui,"MIDI",50);floating.Size=UDim2.fromOffset(58,50);floating.AnchorPoint=Vector2.new(.5,.5);floating.Position=UDim2.fromScale(.9,.35);floating.BackgroundColor3=C.accent;floating.Visible=false;floating.Parent=gui;self.floating=floating

    function self:setState(state)
        state=(state=="Mini" or state=="Hidden") and state or "Full";self.state=state
        main.Visible=state=="Full";miniFrame.Visible=state=="Mini";floating.Visible=state=="Hidden";gui.Enabled=true
        safeCall(callbacks.onUiState,state,state=="Hidden" and floating.Position or nil)
    end
    mini.Activated:Connect(function()self:setState("Mini")end);hide.Activated:Connect(function()self:setState("Hidden")end);open.Activated:Connect(function()self:setState("Full")end);floating.Activated:Connect(function()self:setState("Full")end)

    -- Drag main window from header, but buttons remain clickable.
    local dragging=false;local startPointer;local startPos
    header.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true;startPointer=i.Position;startPos=main.Position end end)
    UIS.InputChanged:Connect(function(i)if dragging and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then local v=workspace.CurrentCamera.ViewportSize;local d=i.Position-startPointer;main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)
    UIS.InputEnded:Connect(function(i)if dragging and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1) then dragging=false end end)

    show("Songs");self:setState("Full")
    return self
end

function App:_renderSongs()
    clear(self.songList);local q=string.lower(self.searchBox.Text or "");local shown=0
    for _,s in ipairs(self.allSongs or {})do
        local ok=q=="" or string.find(string.lower(s.name or s.path or ""),q,1,true)
        if self.songFilter=="Favorites" then ok=ok and s.favorite end;if self.songFilter=="Recent" then ok=ok and s.recentRank~=nil end
        if ok then shown+=1;local b=button(self.songList,(s.favorite and "★ " or "")..(s.name or s.path),42);b.TextXAlignment=Enum.TextXAlignment.Left;b.TextTruncate=Enum.TextTruncate.AtEnd;b.Activated:Connect(function()safeCall(self.callbacks.onSelectSong,s)end)end
    end
    if shown==0 then local e=label(self.songList,"Nenhuma música nesta lista.",34,false);e.TextColor3=C.muted;e.TextSize=10 end
end
function App:setSongs(songs,status)self.allSongs=songs or {};self.songStatus.Text=status or "";self:_renderSongs()end
function App:setMessage(x)self.message.Text=tostring(x or "");self.message.TextColor3=C.accent2 end
function App:setError(x)self.message.Text="Erro: "..tostring(x);self.message.TextColor3=C.danger end
function App:setBackend(x)self.backendLabel.Text="Input: "..tostring(x)end
function App:setFavorite(v)if self.song then self.song.favorite=v end end
function App:setSong(item,a,mapStats,perfStats)
    self.song=item;self.songName.Text=item and (item.name or item.path) or "Nenhum MIDI";self.miniName.Text=self.songName.Text
    if a then self.songInfo.Text=string.format("%d notas • %.1fs • MIDI %s-%s",a.noteCount or 0,a.duration or 0,tostring(a.pitchMin or "?"),tostring(a.pitchMax or "?")) end
    if mapStats then self.performanceInfo.Text=string.format("Cobertura %.1f%% • adaptadas %d • descartadas %d",(mapStats.coverage or 0)*100,mapStats.adapted or 0,mapStats.dropped or 0) end
end
function App:setProgress(pos,dur,stats,playing)
    self.progress.Size=UDim2.fromScale(dur and dur>0 and math.clamp(pos/dur,0,1) or 0,1);self.timeLabel.Text=fmt(pos).." / "..fmt(dur);self.playButton.Text=playing and "PAUSE" or "PLAY"
    local avg=(stats and stats.processed or 0)>0 and (stats.driftSumMs or 0)/stats.processed or 0
    self.diagLabel.Text=string.format("Posição: %s\nEventos: %d\nAtrasados: %d\nIgnorados: %d\nDrift médio: %.2f ms\nPico: %.2f ms",fmt(pos),stats and stats.processed or 0,stats and stats.late or 0,stats and stats.skipped or 0,avg,stats and stats.driftPeakMs or 0)
end
function App:setActiveNotes(t)self.currentNotes.Text="Última tecla: "..((t and #t>0) and table.concat(t," ") or "-")end
function App:setSpeed(v)self.speedButton.Text=string.format("%.2fx",v or 1)end
function App:setHumanStrength(v)self.humanLabel.Text=string.format("Força: %d%%",math.floor((v or 0)*100+.5))end
function App:setTranspose(v)self.transposeButton.Text="Transpose: "..tostring(v or 0)end
function App:setRange(v)self.rangeButton.Text="Range: "..tostring(v)end
function App:setQuantization(v)self.quantButton.Text="Quantização: "..tostring(v)end
function App:setMaxKeys(v)self.maxKeysLabel.Text="Máx. notas: "..tostring(v)end
function App:setAB()end
function App:setAnalysis(a,enabledTracks,enabledChannels)
    if not a then return end;self.splitLabel.Text="Separação: "..tostring(a.splitNote or "auto");self.confidenceLabel.Text=string.format("Confiança %d%% • vozes %s",math.floor((a.handConfidence or 0)*100+.5),tostring(a.voiceCount or "?"))
    clear(self.channelBox);local used={};for _,n in ipairs(a.notes or {})do used[n.channel]=true end
    for ch=1,16 do if used[ch] then local active=enabledChannels[ch]~=false;local b=button(self.channelBox,(active and "ON " or "OFF ")..ch,40);b.Activated:Connect(function()active=not active;b.Text=(active and "ON " or "OFF ")..ch;safeCall(self.callbacks.onToggleChannel,ch,active)end)end end
    clear(self.trackList);for _,tr in ipairs(a.tracks or {})do local active=enabledTracks[tr.index]~=false;local b=button(self.trackList,(active and "ON  " or "OFF ")..(tr.name or ("Track "..tr.index)),40);b.TextXAlignment=Enum.TextXAlignment.Left;b.Activated:Connect(function()active=not active;b.Text=(active and "ON  " or "OFF ")..(tr.name or ("Track "..tr.index));safeCall(self.callbacks.onToggleTrack,tr.index,active)end)end
end
function App:setProfile(profile)
    if not profile then return end;self.profileName.Text=(profile.name or profile.id).." • MIDI "..tostring(profile.lowest).."-"..tostring(profile.highest);clear(self.profileList)
    for note=profile.lowest,profile.highest do local row=Instance.new("Frame");row.BackgroundColor3=C.card;row.Size=UDim2.new(1,0,0,38);corner(row,8);row.Parent=self.profileList;local n=label(row,tostring(note),38,true);n.Position=UDim2.fromOffset(10,0);n.Size=UDim2.fromOffset(42,38);local box=Instance.new("TextBox");box.BackgroundColor3=C.card2;box.Text=profile.map[note] or "";box.ClearTextOnFocus=false;box.Size=UDim2.fromOffset(56,28);box.Position=UDim2.new(1,-64,0,5);styleText(box,12,true);corner(box,7);box.Parent=row;box.FocusLost:Connect(function()if #box.Text==1 then safeCall(self.callbacks.onProfileMapping,note,box.Text)else box.Text=profile.map[note] or "" end end)end
end
function App:destroy()if self.gui then self.gui:Destroy()end end
return App
