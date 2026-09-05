local App={};App.__index=App
local UIS=game:GetService("UserInputService")
local CoreGui=game:GetService("CoreGui")
local Players=game:GetService("Players")

local C={bg=Color3.fromRGB(12,14,22),panel=Color3.fromRGB(22,25,37),card=Color3.fromRGB(31,35,50),card2=Color3.fromRGB(40,45,63),accent=Color3.fromRGB(124,92,255),accent2=Color3.fromRGB(71,211,176),text=Color3.fromRGB(245,247,252),muted=Color3.fromRGB(157,165,187),danger=Color3.fromRGB(237,91,111)}
local function corner(o,r)local x=Instance.new("UICorner");x.CornerRadius=UDim.new(0,r or 12);x.Parent=o end
local function stroke(o,col)local x=Instance.new("UIStroke");x.Color=col or C.card2;x.Thickness=1;x.Transparency=.25;x.Parent=o end
local function styleText(o,size,col,bold)o.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham;o.TextSize=size or 14;o.TextColor3=col or C.text end
local function label(parent,text,height,bold)local l=Instance.new("TextLabel");l.BackgroundTransparency=1;l.Text=text or "";l.TextXAlignment=Enum.TextXAlignment.Left;l.TextYAlignment=Enum.TextYAlignment.Center;l.Size=UDim2.new(1,0,0,height or 26);styleText(l,bold and 16 or 14,nil,bold);l.Parent=parent;return l end
local function button(parent,text,height)local b=Instance.new("TextButton");b.AutoButtonColor=false;b.BackgroundColor3=C.card;b.Text=text or "Button";b.Size=UDim2.new(1,0,0,height or 48);styleText(b,14,C.text,true);corner(b,11);stroke(b);b.Parent=parent;return b end
local function list(parent,pad)local l=Instance.new("UIListLayout");l.Padding=UDim.new(0,pad or 8);l.SortOrder=Enum.SortOrder.LayoutOrder;l.Parent=parent;return l end
local function grid(parent,cols,h,pad)local g=Instance.new("UIGridLayout");g.CellPadding=UDim2.fromOffset(pad or 7,pad or 7);g.CellSize=UDim2.new(1/cols,-((pad or 7)*(cols-1))/cols,0,h or 46);g.SortOrder=Enum.SortOrder.LayoutOrder;g.Parent=parent;return g end
local function scroll(parent)local s=Instance.new("ScrollingFrame");s.BackgroundTransparency=1;s.BorderSizePixel=0;s.Size=UDim2.fromScale(1,1);s.CanvasSize=UDim2.new();s.AutomaticCanvasSize=Enum.AutomaticSize.Y;s.ScrollBarThickness=4;s.ScrollBarImageColor3=C.accent;s.ScrollingDirection=Enum.ScrollingDirection.Y;s.Parent=parent;return s end
local function fmt(t)t=math.max(0,t or 0);return string.format("%02d:%02d",math.floor(t/60),math.floor(t%60))end
local function clearGenerated(frame,keep)
    for _,v in ipairs(frame:GetChildren())do if v~=keep and not v:IsA("UIListLayout") and not v:IsA("UIGridLayout") then v:Destroy() end end
end

function App.new(callbacks,config)
    local self=setmetatable({callbacks=callbacks or {},config=config,pages={},navButtons={},allSongs={},songFilter=config.ui.songFilter or "All",song=nil},App)
    local gui=Instance.new("ScreenGui");gui.Name="MIDIQWERTY_UI";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    local parent=(gethui and gethui()) or CoreGui
    if not pcall(function()gui.Parent=parent end) then gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui") end
    self.gui=gui

    local main=Instance.new("Frame");main.AnchorPoint=Vector2.new(.5,.5);main.Position=UDim2.fromScale(.5,.5);main.BackgroundColor3=C.bg;corner(main,18);stroke(main);main.Parent=gui;self.main=main
    local function resize()
        local v=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(420,720)
        local w=math.clamp(v.X-18,330,760);local h=math.clamp(v.Y-34,470,790)
        main.Size=UDim2.fromOffset(w,h)
    end
    resize();if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)end

    local top=Instance.new("Frame");top.BackgroundTransparency=1;top.Position=UDim2.fromOffset(14,10);top.Size=UDim2.new(1,-28,0,48);top.Parent=main
    local title=label(top,"MIDI → QWERTY",48,true);title.Size=UDim2.new(1,-112,1,0);title.TextSize=18
    local mini=button(top,"MINI",40);mini.Size=UDim2.fromOffset(56,40);mini.Position=UDim2.new(1,-112,0,3)
    local hide=button(top,"HIDE",40);hide.Size=UDim2.fromOffset(50,40);hide.Position=UDim2.new(1,-50,0,3)

    local status=label(main,"Pronto",24,false);status.Position=UDim2.fromOffset(14,58);status.Size=UDim2.new(1,-28,0,24);status.TextSize=12;status.TextColor3=C.accent2;self.message=status

    local nav=Instance.new("Frame");nav.BackgroundTransparency=1;nav.Position=UDim2.fromOffset(14,88);nav.Size=UDim2.new(1,-28,0,98);nav.Parent=main;grid(nav,4,44,6)
    local names={{"Songs","Músicas"},{"Player","Player"},{"Parts","Partes"},{"Piano","Piano"},{"Human","Humano"},{"Settings","Ajustes"},{"Diag","Diag"}}
    local content=Instance.new("Frame");content.BackgroundColor3=C.panel;content.Position=UDim2.fromOffset(14,196);content.Size=UDim2.new(1,-28,1,-210);corner(content,14);content.ClipsDescendants=true;content.Parent=main

    local function show(name)
        for n,p in pairs(self.pages)do p.Visible=n==name end
        for n,b in pairs(self.navButtons)do b.BackgroundColor3=n==name and C.accent or C.card end
        self.activeTab=name
    end
    for _,pair in ipairs(names)do
        local key,text=pair[1],pair[2];local b=button(nav,text,44);self.navButtons[key]=b;b.Activated:Connect(function()show(key)end)
        local holder=Instance.new("Frame");holder.BackgroundTransparency=1;holder.Position=UDim2.fromOffset(10,10);holder.Size=UDim2.new(1,-20,1,-20);holder.Visible=false;holder.Parent=content
        local p=scroll(holder);list(p,9);self.pages[key]=p
    end

    -- Songs
    local p=self.pages.Songs
    local search=Instance.new("TextBox");search.PlaceholderText="Pesquisar MIDI...";search.Text="";search.ClearTextOnFocus=false;search.BackgroundColor3=C.card;search.Size=UDim2.new(1,0,0,48);search.TextXAlignment=Enum.TextXAlignment.Left;search.Text="";styleText(search,14);corner(search,11);search.Parent=p;self.searchBox=search
    local songTools=Instance.new("Frame");songTools.BackgroundTransparency=1;songTools.Size=UDim2.new(1,0,0,48);songTools.Parent=p;local gt=grid(songTools,2,48,8)
    local refresh=button(songTools,"Atualizar",48);local filter=button(songTools,self.songFilter,48);self.filterButton=filter
    refresh.Activated:Connect(function()if self.callbacks.onRefresh then self.callbacks.onRefresh()end end)
    filter.Activated:Connect(function()local o={"All","Favorites","Recent"};local i=1;for j,v in ipairs(o)do if v==self.songFilter then i=j break end end;self.songFilter=o[i%#o+1];filter.Text=self.songFilter;self:_renderSongs()end)
    local songStat=label(p,"Procurando...",28,false);songStat.TextColor3=C.muted;songStat.TextSize=12;self.songStatus=songStat
    local songList=Instance.new("Frame");songList.BackgroundTransparency=1;songList.Size=UDim2.new(1,0,0,0);songList.AutomaticSize=Enum.AutomaticSize.Y;songList.Parent=p;list(songList,8);self.songList=songList
    search:GetPropertyChangedSignal("Text"):Connect(function()self:_renderSongs()end)

    -- Player
    p=self.pages.Player
    local songName=label(p,"Nenhum MIDI selecionado",34,true);songName.TextSize=18;self.songName=songName
    local info=label(p,"Abra Músicas e selecione um arquivo.",48,false);info.TextWrapped=true;info.TextColor3=C.muted;info.TextSize=12;self.songInfo=info
    local progress=Instance.new("Frame");progress.BackgroundColor3=C.card2;progress.Size=UDim2.new(1,0,0,14);corner(progress,7);progress.Parent=p
    local fill=Instance.new("Frame");fill.BackgroundColor3=C.accent;fill.Size=UDim2.fromScale(0,1);corner(fill,7);fill.Parent=progress;self.progress=fill
    local time=label(p,"00:00 / 00:00",28,false);time.TextColor3=C.muted;time.TextSize=12;self.timeLabel=time
    local controls=Instance.new("Frame");controls.BackgroundTransparency=1;controls.Size=UDim2.new(1,0,0,56);controls.Parent=p;grid(controls,5,56,7)
    local prev=button(controls,"|<",56);local back=button(controls,"-5s",56);local play=button(controls,"PLAY",56);local fwd=button(controls,"+5s",56);local nxt=button(controls,">|",56);self.playButton=play
    prev.Activated:Connect(function()if self.callbacks.onPrev then self.callbacks.onPrev()end end);back.Activated:Connect(function()if self.callbacks.onSeekRelative then self.callbacks.onSeekRelative(-5)end end);play.Activated:Connect(function()if self.callbacks.onPlayPause then self.callbacks.onPlayPause()end end);fwd.Activated:Connect(function()if self.callbacks.onSeekRelative then self.callbacks.onSeekRelative(5)end end);nxt.Activated:Connect(function()if self.callbacks.onNext then self.callbacks.onNext()end end)
    local row=Instance.new("Frame");row.BackgroundTransparency=1;row.Size=UDim2.new(1,0,0,48);row.Parent=p;grid(row,3,48,8)
    local stop=button(row,"STOP",48);local speed=button(row,"1.00x",48);local panic=button(row,"Soltar teclas",48);self.speedButton=speed
    stop.Activated:Connect(function()if self.callbacks.onStop then self.callbacks.onStop()end end);speed.Activated:Connect(function()if self.callbacks.onCycleSpeed then self.callbacks.onCycleSpeed()end end);panic.Activated:Connect(function()if self.callbacks.onPanic then self.callbacks.onPanic()end end)
    local partTitle=label(p,"Parte tocada",26,true);partTitle.TextSize=14
    local modes=Instance.new("Frame");modes.BackgroundTransparency=1;modes.Size=UDim2.new(1,0,0,104);modes.Parent=p;grid(modes,3,48,8)
    for _,m in ipairs({"Both","Left","Right","Melody","Accompaniment","Bass"})do local b=button(modes,m,48);b.Activated:Connect(function()if self.callbacks.onMode then self.callbacks.onMode(m)end end)end
    local loopRow=Instance.new("Frame");loopRow.BackgroundTransparency=1;loopRow.Size=UDim2.new(1,0,0,48);loopRow.Parent=p;grid(loopRow,3,48,8)
    local a=button(loopRow,"Marcar A",48);local bb=button(loopRow,"Marcar B",48);local clr=button(loopRow,"Limpar A-B",48)
    a.Activated:Connect(function()if self.callbacks.onSetA then self.callbacks.onSetA()end end);bb.Activated:Connect(function()if self.callbacks.onSetB then self.callbacks.onSetB()end end);clr.Activated:Connect(function()if self.callbacks.onClearAB then self.callbacks.onClearAB()end end)
    local ab=label(p,"A: --   B: --",28,false);ab.TextColor3=C.muted;self.abLabel=ab
    local active=label(p,"Última tecla: -",30,false);active.TextColor3=C.accent2;self.currentNotes=active
    local perf=label(p,"Performance pronta",48,false);perf.TextWrapped=true;perf.TextColor3=C.muted;perf.TextSize=11;self.performanceInfo=perf

    -- Parts
    p=self.pages.Parts
    local split=label(p,"Separação de mãos: aguardando MIDI",32,true);self.splitLabel=split
    local conf=label(p,"",26,false);conf.TextColor3=C.muted;conf.TextSize=12;self.confidenceLabel=conf
    local chTitle=label(p,"Canais",26,true);chTitle.TextSize=14
    local channels=Instance.new("Frame");channels.BackgroundTransparency=1;channels.Size=UDim2.new(1,0,0,212);channels.Parent=p;grid(channels,4,46,7);self.channelBox=channels
    local trTitle=label(p,"Tracks",26,true);trTitle.TextSize=14
    local tracks=Instance.new("Frame");tracks.BackgroundTransparency=1;tracks.Size=UDim2.new(1,0,0,0);tracks.AutomaticSize=Enum.AutomaticSize.Y;tracks.Parent=p;list(tracks,8);self.trackList=tracks

    -- Piano
    p=self.pages.Piano
    local prof=label(p,"Perfil de piano",32,true);self.profileName=prof
    local desc=label(p,"Teste o mapeamento antes de tocar uma música inteira. Se C4, C5 e C6 soarem na oitava correta, o perfil está alinhado.",60,false);desc.TextWrapped=true;desc.TextColor3=C.muted;desc.TextSize=12
    local tests=Instance.new("Frame");tests.BackgroundTransparency=1;tests.Size=UDim2.new(1,0,0,52);tests.Parent=p;grid(tests,3,52,8)
    for _,x in ipairs({{60,"C4"},{72,"C5"},{84,"C6"}})do local b=button(tests,"Testar "..x[2],52);b.Activated:Connect(function()if self.callbacks.onTestNote then self.callbacks.onTestNote(x[1])end end)end
    local editTitle=label(p,"Mapa MIDI -> QWERTY",26,true);editTitle.TextSize=14
    local profileList=Instance.new("Frame");profileList.BackgroundTransparency=1;profileList.Size=UDim2.new(1,0,0,0);profileList.AutomaticSize=Enum.AutomaticSize.Y;profileList.Parent=p;list(profileList,6);self.profileList=profileList

    -- Human
    p=self.pages.Human
    local ht=label(p,"Humanização musical",32,true)
    local hd=label(p,"Use Very Subtle para máxima fidelidade. Cada Play muda poucos milissegundos, sem trocar as notas do MIDI.",58,false);hd.TextWrapped=true;hd.TextColor3=C.muted;hd.TextSize=12
    local presets=Instance.new("Frame");presets.BackgroundTransparency=1;presets.Size=UDim2.new(1,0,0,104);presets.Parent=p;grid(presets,2,48,8)
    for _,x in ipairs({"Exact","Very Subtle","Natural","Expressive"})do local b=button(presets,x,48);b.Activated:Connect(function()if self.callbacks.onPreset then self.callbacks.onPreset(x)end end)end
    local hs=label(p,"Força: 0%",30,true);self.humanLabel=hs
    local hrow=Instance.new("Frame");hrow.BackgroundTransparency=1;hrow.Size=UDim2.new(1,0,0,52);hrow.Parent=p;grid(hrow,2,52,8)
    local hm=button(hrow,"Menos",52);local hp=button(hrow,"Mais",52);hm.Activated:Connect(function()if self.callbacks.onHumanDelta then self.callbacks.onHumanDelta(-.02)end end);hp.Activated:Connect(function()if self.callbacks.onHumanDelta then self.callbacks.onHumanDelta(.02)end end)

    -- Settings
    p=self.pages.Settings
    local st=label(p,"Conversão",32,true)
    local trans=button(p,"Transpose: 0",52);self.transposeButton=trans;trans.Activated:Connect(function()if self.callbacks.onTransposeDelta then self.callbacks.onTransposeDelta(1)end end)
    local trHelp=label(p,"Toque para +1 semitom. Use Piano > testes para conferir a oitava.",44,false);trHelp.TextWrapped=true;trHelp.TextColor3=C.muted;trHelp.TextSize=11
    local trow=Instance.new("Frame");trow.BackgroundTransparency=1;trow.Size=UDim2.new(1,0,0,52);trow.Parent=p;grid(trow,2,52,8)
    local tm=button(trow,"Transpose -1",52);local tp=button(trow,"Transpose +1",52);tm.Activated:Connect(function()if self.callbacks.onTransposeDelta then self.callbacks.onTransposeDelta(-1)end end);tp.Activated:Connect(function()if self.callbacks.onTransposeDelta then self.callbacks.onTransposeDelta(1)end end)
    local range=button(p,"Range: SmartOctave",52);self.rangeButton=range;range.Activated:Connect(function()if self.callbacks.onCycleRange then self.callbacks.onCycleRange()end end)
    local quant=button(p,"Quantização: Off",52);self.quantButton=quant;quant.Activated:Connect(function()if self.callbacks.onCycleQuantization then self.callbacks.onCycleQuantization()end end)
    local mk=label(p,"Máx. notas no acorde: 10",30,true);self.maxKeysLabel=mk
    local krow=Instance.new("Frame");krow.BackgroundTransparency=1;krow.Size=UDim2.new(1,0,0,52);krow.Parent=p;grid(krow,2,52,8)
    local km=button(krow,"-1",52);local kp=button(krow,"+1",52);km.Activated:Connect(function()if self.callbacks.onMaxKeysDelta then self.callbacks.onMaxKeysDelta(-1)end end);kp.Activated:Connect(function()if self.callbacks.onMaxKeysDelta then self.callbacks.onMaxKeysDelta(1)end end)
    local exports=Instance.new("Frame");exports.BackgroundTransparency=1;exports.Size=UDim2.new(1,0,0,52);exports.Parent=p;grid(exports,2,52,8)
    local ex1=button(exports,"Exportar QWERTY",52);local ex2=button(exports,"Exportar análise",52);ex1.Activated:Connect(function()if self.callbacks.onExportSequence then self.callbacks.onExportSequence()end end);ex2.Activated:Connect(function()if self.callbacks.onExportAnalysis then self.callbacks.onExportAnalysis()end end)

    -- Diagnostics
    p=self.pages.Diag
    local backend=label(p,"Input: ...",32,true);self.backendLabel=backend
    local diag=label(p,"Sem música carregada.",220,false);diag.TextWrapped=true;diag.TextYAlignment=Enum.TextYAlignment.Top;diag.TextColor3=C.muted;diag.TextSize=12;self.diagLabel=diag

    -- Mini player
    local miniFrame=Instance.new("Frame");miniFrame.AnchorPoint=Vector2.new(.5,1);miniFrame.Position=UDim2.new(.5,0,1,-18);miniFrame.Size=UDim2.new(.92,0,0,68);miniFrame.BackgroundColor3=C.bg;miniFrame.Visible=false;corner(miniFrame,16);stroke(miniFrame);miniFrame.Parent=gui;self.miniFrame=miniFrame
    local mn=label(miniFrame,"MIDI QWERTY",68,true);mn.Position=UDim2.fromOffset(14,0);mn.Size=UDim2.new(1,-160,1,0);mn.TextTruncate=Enum.TextTruncate.AtEnd;self.miniName=mn
    local mp=button(miniFrame,"PLAY",48);mp.Position=UDim2.new(1,-140,.5,-24);mp.Size=UDim2.fromOffset(62,48);mp.Activated:Connect(function()if self.callbacks.onPlayPause then self.callbacks.onPlayPause()end end)
    local open=button(miniFrame,"ABRIR",48);open.Position=UDim2.new(1,-70,.5,-24);open.Size=UDim2.fromOffset(62,48)

    -- Floating restore button
    local floating=button(gui,"MIDI",58);floating.Size=UDim2.fromOffset(64,58);floating.AnchorPoint=Vector2.new(.5,.5);floating.Position=UDim2.fromScale(config.ui.floatingX or .88,config.ui.floatingY or .55);floating.Visible=false;floating.BackgroundColor3=C.accent;self.floating=floating
    local dragging,dragStart,startPos=false,nil,nil
    floating.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true;dragStart=i.Position;startPos=floating.Position end end)
    UIS.InputChanged:Connect(function(i)if dragging and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then local v=workspace.CurrentCamera.ViewportSize;local d=i.Position-dragStart;floating.Position=UDim2.fromScale(math.clamp(startPos.X.Scale+d.X/v.X,.05,.95),math.clamp(startPos.Y.Scale+d.Y/v.Y,.08,.92)) end end)
    UIS.InputEnded:Connect(function(i)if dragging and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1) then dragging=false;if self.callbacks.onUiState then self.callbacks.onUiState("Hidden",floating.Position)end end end)

    function self:setState(state)
        self.state=state;main.Visible=state=="Full";miniFrame.Visible=state=="Mini";floating.Visible=state=="Hidden"
        if self.callbacks.onUiState then self.callbacks.onUiState(state,state=="Hidden" and floating.Position or nil)end
    end
    mini.Activated:Connect(function()self:setState("Mini")end);hide.Activated:Connect(function()self:setState("Hidden")end);open.Activated:Connect(function()self:setState("Full")end)
    floating.Activated:Connect(function()if not dragging then self:setState("Full")end end)

    show("Songs");self:setState(config.ui.state or "Full")
    return self
end

function App:_renderSongs()
    if not self.songList then return end
    clearGenerated(self.songList)
    local q=string.lower(self.searchBox and self.searchBox.Text or "")
    for _,s in ipairs(self.allSongs or {})do
        local ok=q=="" or string.find(string.lower(s.name or s.path or ""),q,1,true)
        if self.songFilter=="Favorites" then ok=ok and s.favorite end
        if self.songFilter=="Recent" then ok=ok and s.recentRank~=nil end
        if ok then
            local b=button(self.songList,(s.favorite and "★ " or "")..(s.name or s.path),58);b.TextXAlignment=Enum.TextXAlignment.Left;b.TextTruncate=Enum.TextTruncate.AtEnd
            b.Activated:Connect(function()if self.callbacks.onSelectSong then self.callbacks.onSelectSong(s)end end)
        end
    end
end

function App:setSongs(songs,status)self.allSongs=songs or {};self.songStatus.Text=status or "";self:_renderSongs()end
function App:setMessage(x)self.message.Text=tostring(x or "")end
function App:setError(x)self.message.Text="Erro: "..tostring(x);self.message.TextColor3=C.danger end
function App:setBackend(x)self.backendLabel.Text="Input: "..tostring(x)end
function App:setFavorite(v)if self.song then self.song.favorite=v end end
function App:setSong(item,a,mapStats,perfStats)
    self.song=item;self.songName.Text=item and (item.name or item.path) or "Nenhum MIDI";self.miniName.Text=self.songName.Text
    if a then self.songInfo.Text=string.format("%d notas  •  %.1fs  •  range MIDI %s-%s",a.noteCount or 0,a.duration or 0,tostring(a.pitchMin or "?"),tostring(a.pitchMax or "?")) end
    if mapStats then self.performanceInfo.Text=string.format("Cobertura %.1f%%  •  adaptadas %d  •  descartadas %d  •  colisões %d",(mapStats.coverage or 0)*100,mapStats.adapted or 0,mapStats.dropped or 0,mapStats.collisions or 0) end
end
function App:setProgress(pos,dur,stats,playing)
    local f=dur and dur>0 and math.clamp(pos/dur,0,1) or 0;self.progress.Size=UDim2.fromScale(f,1);self.timeLabel.Text=fmt(pos).." / "..fmt(dur);self.playButton.Text=playing and "PAUSE" or "PLAY"
    local avg=(stats and stats.processed or 0)>0 and (stats.driftSumMs or 0)/stats.processed or 0
    self.diagLabel.Text=string.format("Posição: %s\nEventos: %d\nAtrasados: %d\nIgnorados: %d\nDrift médio: %.2f ms\nPico: %.2f ms",fmt(pos),stats and stats.processed or 0,stats and stats.late or 0,stats and stats.skipped or 0,avg,stats and stats.driftPeakMs or 0)
end
function App:setActiveNotes(t)self.currentNotes.Text="Última tecla: "..((t and #t>0) and table.concat(t," ") or "-")end
function App:setSpeed(v)self.speedButton.Text=string.format("%.2fx",v or 1)end
function App:setHumanStrength(v)self.humanLabel.Text=string.format("Força: %d%%",math.floor((v or 0)*100+.5))end
function App:setTranspose(v)self.transposeButton.Text="Transpose: "..tostring(v or 0)end
function App:setRange(v)self.rangeButton.Text="Range: "..tostring(v)end
function App:setQuantization(v)self.quantButton.Text="Quantização: "..tostring(v)end
function App:setMaxKeys(v)self.maxKeysLabel.Text="Máx. notas no acorde: "..tostring(v)end
function App:setAB(a,b)self.abLabel.Text="A: "..(a and fmt(a) or "--").."   B: "..(b and fmt(b) or "--")end

function App:setAnalysis(a,enabledTracks,enabledChannels)
    if not a then return end
    self.splitLabel.Text="Separação de mãos: "..tostring(a.splitNote or "auto")
    self.confidenceLabel.Text=string.format("Confiança: %d%%  •  vozes: %s",math.floor((a.handConfidence or 0)*100+.5),tostring(a.voiceCount or "?"))
    clearGenerated(self.channelBox)
    local used={};for _,n in ipairs(a.notes or {})do used[n.channel]=true end
    for ch=1,16 do if used[ch] then local active=enabledChannels[ch]~=false;local b=button(self.channelBox,(active and "ON " or "OFF ").."Ch"..ch,46);b.BackgroundColor3=active and C.card or C.card2;b.Activated:Connect(function()active=not active;b.Text=(active and "ON " or "OFF ").."Ch"..ch;if self.callbacks.onToggleChannel then self.callbacks.onToggleChannel(ch,active)end end)end end
    clearGenerated(self.trackList)
    for _,tr in ipairs(a.tracks or {})do
        local active=enabledTracks[tr.index]~=false;local b=button(self.trackList,(active and "ON  " or "OFF ")..(tr.name or ("Track "..tr.index)).."  •  "..tostring(tr.noteCount or 0).." notas",52);b.TextXAlignment=Enum.TextXAlignment.Left;b.Activated:Connect(function()active=not active;b.Text=(active and "ON  " or "OFF ")..(tr.name or ("Track "..tr.index)).."  •  "..tostring(tr.noteCount or 0).." notas";if self.callbacks.onToggleTrack then self.callbacks.onToggleTrack(tr.index,active)end end)
    end
end

function App:setProfile(profile)
    if not profile then return end
    self.profileName.Text=(profile.name or profile.id).."  •  MIDI "..tostring(profile.lowest).."-"..tostring(profile.highest)
    clearGenerated(self.profileList)
    for note=profile.lowest,profile.highest do
        local row=Instance.new("Frame");row.BackgroundColor3=C.card;row.Size=UDim2.new(1,0,0,48);corner(row,10);row.Parent=self.profileList
        local l=label(row,"MIDI "..note,48,true);l.Position=UDim2.fromOffset(12,0);l.Size=UDim2.new(.55,-12,1,0)
        local box=Instance.new("TextBox");box.BackgroundColor3=C.card2;box.Text=profile.map[note] or "";box.ClearTextOnFocus=false;box.Size=UDim2.new(.4,-12,0,38);box.Position=UDim2.new(.6,0,.5,-19);styleText(box,16,C.text,true);corner(box,9);box.Parent=row
        box.FocusLost:Connect(function()if self.callbacks.onProfileMapping and #box.Text==1 then self.callbacks.onProfileMapping(note,box.Text)else box.Text=profile.map[note] or "" end end)
    end
end

function App:destroy()if self.gui then self.gui:Destroy()end end
return App
