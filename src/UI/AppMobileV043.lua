local App={};App.__index=App
local UIS=game:GetService("UserInputService")
local Players=game:GetService("Players")
local CoreGui=game:GetService("CoreGui")

local C={
    bg=Color3.fromRGB(10,12,18),panel=Color3.fromRGB(18,21,31),card=Color3.fromRGB(28,32,46),
    card2=Color3.fromRGB(39,44,61),accent=Color3.fromRGB(122,88,255),accent2=Color3.fromRGB(72,210,178),
    text=Color3.fromRGB(246,248,252),muted=Color3.fromRGB(155,164,185),danger=Color3.fromRGB(239,90,111)
}

local function round(o,r)local x=Instance.new("UICorner");x.CornerRadius=UDim.new(0,r or 9);x.Parent=o end
local function outline(o,col)local x=Instance.new("UIStroke");x.Color=col or C.card2;x.Thickness=1;x.Transparency=.35;x.Parent=o end
local function styleText(o,size,bold,col)o.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham;o.TextSize=size or 11;o.TextColor3=col or C.text end
local function label(parent,text,h,bold)
    local x=Instance.new("TextLabel");x.BackgroundTransparency=1;x.Text=text or "";x.TextXAlignment=Enum.TextXAlignment.Left;x.TextYAlignment=Enum.TextYAlignment.Center
    x.Size=UDim2.new(1,0,0,h or 22);styleText(x,bold and 13 or 10,bold);x.Parent=parent;return x
end
local function button(parent,text,h)
    local x=Instance.new("TextButton");x.AutoButtonColor=false;x.BackgroundColor3=C.card;x.Text=text or "";x.Size=UDim2.new(1,0,0,h or 38);styleText(x,11,true);round(x,8);outline(x);x.Parent=parent;return x
end
local function addTextPadding(gui,left,right)
    local p=Instance.new("UIPadding");p.PaddingLeft=UDim.new(0,left or 8);p.PaddingRight=UDim.new(0,right or 8);p.Parent=gui;return p
end
local function vlist(parent,pad)
    local l=Instance.new("UIListLayout");l.FillDirection=Enum.FillDirection.Vertical;l.SortOrder=Enum.SortOrder.LayoutOrder;l.Padding=UDim.new(0,pad or 6);l.Parent=parent;return l
end
local function clearChildren(parent)
    for _,v in ipairs(parent:GetChildren()) do
        if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then v:Destroy() end
    end
end
local function scroll(parent)
    local s=Instance.new("ScrollingFrame");s.BackgroundTransparency=1;s.BorderSizePixel=0;s.Size=UDim2.fromScale(1,1);s.CanvasSize=UDim2.new();s.AutomaticCanvasSize=Enum.AutomaticSize.Y
    s.ScrollBarThickness=3;s.ScrollBarImageColor3=C.accent;s.ScrollingDirection=Enum.ScrollingDirection.Y;s.Parent=parent
    local p=Instance.new("UIPadding");p.PaddingRight=UDim.new(0,5);p.Parent=s
    return s
end
local function fmt(t)t=math.max(0,t or 0);return string.format("%02d:%02d",math.floor(t/60),math.floor(t%60))end
local function safe(cb,...)if type(cb)=="function" then local ok=pcall(cb,...);return ok end end

-- Manual row positioning. No UIGridLayout is used here. The previous builds
-- sat exactly on pixel boundaries and the last cell wrapped on some Android
-- viewports, causing missing/overlapping buttons.
local function rowButtons(parent,defs,h,gap)
    gap=gap or 6
    local row=Instance.new("Frame");row.BackgroundTransparency=1;row.Size=UDim2.new(1,0,0,h or 38);row.Parent=parent
    local n=#defs;local out={}
    for i,d in ipairs(defs) do
        local b=button(row,d.text or tostring(d),h or 38)
        b.Position=UDim2.new((i-1)/n,gap/2,0,0)
        b.Size=UDim2.new(1/n,-gap,1,0)
        if d.onClick then b.Activated:Connect(d.onClick) end
        out[i]=b
    end
    return out,row
end

local NOTE_NAMES={"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}
local function noteName(n)return NOTE_NAMES[(n%12)+1]..tostring(math.floor(n/12)-1)end

function App.new(callbacks,config)
    callbacks=callbacks or {};config=config or {};config.ui=config.ui or {}
    local self=setmetatable({callbacks=callbacks,config=config,pages={},nav={},allSongs={},song=nil,songFilter=config.ui.songFilter or "All",profileExpanded=false},App)

    local gui=Instance.new("ScreenGui");gui.Name="MIDIQWERTY_V043_POLISHED";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;gui.DisplayOrder=12000;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    local parent=(gethui and gethui()) or CoreGui
    if not pcall(function()gui.Parent=parent end) then gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui") end
    self.gui=gui

    local main=Instance.new("Frame");main.Name="Window";main.AnchorPoint=Vector2.new(.5,.5);main.Position=UDim2.fromScale(.35,.48);main.BackgroundColor3=C.bg;main.ClipsDescendants=true;round(main,13);outline(main);main.Parent=gui;self.main=main
    local function resize()
        local cam=workspace.CurrentCamera;local v=cam and cam.ViewportSize or Vector2.new(1280,720)
        if v.X>v.Y then
            main.Size=UDim2.fromOffset(math.clamp(v.X*.40,470,550),math.clamp(v.Y*.58,300,350))
        else
            main.Size=UDim2.fromOffset(math.clamp(v.X-20,320,410),math.clamp(v.Y*.68,430,590))
        end
    end
    resize();if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)end

    local header=Instance.new("Frame");header.BackgroundColor3=C.panel;header.Size=UDim2.new(1,0,0,44);header.Parent=main;self.header=header
    local title=label(header,"MIDI QWERTY",44,true);title.Position=UDim2.fromOffset(12,0);title.Size=UDim2.new(0,120,1,0);title.TextSize=14
    local badge=Instance.new("TextLabel");badge.BackgroundColor3=C.accent2;badge.Text="v0.4.3 POLISHED";badge.Size=UDim2.fromOffset(118,22);badge.Position=UDim2.fromOffset(132,11);styleText(badge,9,true,Color3.fromRGB(7,22,18));round(badge,7);badge.Parent=header
    local mini=button(header,"MINI",30);mini.Size=UDim2.fromOffset(48,30);mini.Position=UDim2.new(1,-100,0,7)
    local hide=button(header,"HIDE",30);hide.Size=UDim2.fromOffset(46,30);hide.Position=UDim2.new(1,-49,0,7)

    local body=Instance.new("Frame");body.BackgroundTransparency=1;body.Position=UDim2.fromOffset(7,51);body.Size=UDim2.new(1,-14,1,-58);body.Parent=main
    local rail=Instance.new("Frame");rail.BackgroundColor3=C.panel;rail.Size=UDim2.new(0,92,1,0);round(rail,10);rail.Parent=body
    local rp=Instance.new("UIPadding");rp.PaddingTop=UDim.new(0,7);rp.PaddingLeft=UDim.new(0,7);rp.PaddingRight=UDim.new(0,7);rp.PaddingBottom=UDim.new(0,7);rp.Parent=rail
    vlist(rail,4)
    local status=label(rail,"Pronto",20,false);status.TextSize=8;status.TextColor3=C.accent2;status.TextWrapped=true;self.message=status

    local content=Instance.new("Frame");content.BackgroundColor3=C.panel;content.Position=UDim2.fromOffset(99,0);content.Size=UDim2.new(1,-99,1,0);round(content,10);content.ClipsDescendants=true;content.Parent=body
    local cp=Instance.new("UIPadding");cp.PaddingTop=UDim.new(0,8);cp.PaddingLeft=UDim.new(0,8);cp.PaddingRight=UDim.new(0,8);cp.PaddingBottom=UDim.new(0,8);cp.Parent=content

    local function show(name)
        for n,p in pairs(self.pages) do p.Visible=n==name end
        for n,b in pairs(self.nav) do b.BackgroundColor3=n==name and C.accent or C.card end
        self.activeTab=name
    end
    self.showPage=show

    local specs={{"Songs","MUSICAS"},{"Player","PLAYER"},{"Parts","PARTES"},{"Piano","PIANO"},{"Human","HUMANO"},{"Settings","AJUSTES"},{"Diag","DIAG"}}
    for _,sp in ipairs(specs) do
        local key,txt=sp[1],sp[2]
        local b=button(rail,txt,29);b.TextSize=9;self.nav[key]=b;b.Activated:Connect(function()show(key)end)
        local page=scroll(content);page.Visible=false;vlist(page,6);self.pages[key]=page
    end

    -- SONGS
    local p=self.pages.Songs
    local pageTitle=label(p,"Biblioteca MIDI",24,true);pageTitle.TextSize=13
    local search=Instance.new("TextBox");search.PlaceholderText="Pesquisar musica...";search.Text="";search.ClearTextOnFocus=false;search.BackgroundColor3=C.card;search.Size=UDim2.new(1,0,0,38);search.TextXAlignment=Enum.TextXAlignment.Left;styleText(search,10,false);round(search,8);addTextPadding(search,10,10);search.Parent=p;self.searchBox=search
    local tools=rowButtons(p,{
        {text="Atualizar",onClick=function()safe(callbacks.onRefresh)end},
        {text="Todos",onClick=function()
            local opts={{"All","Todos"},{"Favorites","Favoritos"},{"Recent","Recentes"}};local idx=1
            for i,v in ipairs(opts)do if v[1]==self.songFilter then idx=i break end end
            idx=idx%#opts+1;self.songFilter=opts[idx][1];self.filterButton.Text=opts[idx][2];self:_renderSongs()
        end}
    },38,7)
    self.filterButton=tools[2]
    self.songStatus=label(p,"Procurando MIDIs...",20,false);self.songStatus.TextSize=9;self.songStatus.TextColor3=C.muted
    self.songList=Instance.new("Frame");self.songList.BackgroundTransparency=1;self.songList.AutomaticSize=Enum.AutomaticSize.Y;self.songList.Size=UDim2.new(1,0,0,0);self.songList.Parent=p;vlist(self.songList,5)
    search:GetPropertyChangedSignal("Text"):Connect(function()self:_renderSongs()end)

    -- PLAYER
    p=self.pages.Player
    self.songName=label(p,"Nenhum MIDI selecionado",26,true);self.songName.TextSize=13;self.songName.TextTruncate=Enum.TextTruncate.AtEnd
    self.songInfo=label(p,"Escolha uma musica na aba MUSICAS.",32,false);self.songInfo.TextWrapped=true;self.songInfo.TextSize=9;self.songInfo.TextColor3=C.muted
    local progress=Instance.new("Frame");progress.BackgroundColor3=C.card2;progress.Size=UDim2.new(1,0,0,10);round(progress,5);progress.Parent=p
    self.progress=Instance.new("Frame");self.progress.BackgroundColor3=C.accent;self.progress.Size=UDim2.fromScale(0,1);round(self.progress,5);self.progress.Parent=progress
    self.timeLabel=label(p,"00:00 / 00:00",18,false);self.timeLabel.TextSize=9;self.timeLabel.TextColor3=C.muted
    local ctr=rowButtons(p,{
        {text="|<",onClick=function()safe(callbacks.onPrev)end},{text="-5s",onClick=function()safe(callbacks.onSeekRelative,-5)end},
        {text="PLAY",onClick=function()safe(callbacks.onPlayPause)end},{text="+5s",onClick=function()safe(callbacks.onSeekRelative,5)end},{text=">|",onClick=function()safe(callbacks.onNext)end}
    },42,5);self.playButton=ctr[3]
    local transport=rowButtons(p,{
        {text="STOP",onClick=function()safe(callbacks.onStop)end},{text="1.00x",onClick=function()safe(callbacks.onCycleSpeed)end},{text="SOLTAR",onClick=function()safe(callbacks.onPanic)end}
    },36,6);self.speedButton=transport[2]
    label(p,"Parte tocada",18,true)
    local modeA=rowButtons(p,{
        {text="Ambas",onClick=function()safe(callbacks.onMode,"Both")end},{text="Esquerda",onClick=function()safe(callbacks.onMode,"Left")end},{text="Direita",onClick=function()safe(callbacks.onMode,"Right")end}
    },35,5)
    local modeB=rowButtons(p,{
        {text="Melodia",onClick=function()safe(callbacks.onMode,"Melody")end},{text="Acomp.",onClick=function()safe(callbacks.onMode,"Accompaniment")end},{text="Baixo",onClick=function()safe(callbacks.onMode,"Bass")end}
    },35,5)
    self.modeButtons={Both=modeA[1],Left=modeA[2],Right=modeA[3],Melody=modeB[1],Accompaniment=modeB[2],Bass=modeB[3]}
    local ab=rowButtons(p,{
        {text="Marcar A",onClick=function()safe(callbacks.onSetA)end},{text="Marcar B",onClick=function()safe(callbacks.onSetB)end},{text="Limpar A-B",onClick=function()safe(callbacks.onClearAB)end}
    },34,5)
    self.abLabel=label(p,"A: --   B: --",18,false);self.abLabel.TextSize=9;self.abLabel.TextColor3=C.muted
    self.currentNotes=label(p,"Ultima tecla: -",18,false);self.currentNotes.TextSize=9;self.currentNotes.TextColor3=C.accent2
    self.performanceInfo=label(p,"Performance pronta",34,false);self.performanceInfo.TextWrapped=true;self.performanceInfo.TextSize=9;self.performanceInfo.TextColor3=C.muted

    -- PARTS
    p=self.pages.Parts
    label(p,"Partes tocaveis",24,true)
    self.splitLabel=label(p,"Separacao: aguardando MIDI",22,true)
    self.confidenceLabel=label(p,"",20,false);self.confidenceLabel.TextSize=9;self.confidenceLabel.TextColor3=C.muted
    label(p,"Canais MIDI",18,true)
    self.channelBox=Instance.new("Frame");self.channelBox.BackgroundTransparency=1;self.channelBox.AutomaticSize=Enum.AutomaticSize.Y;self.channelBox.Size=UDim2.new(1,0,0,0);self.channelBox.Parent=p;vlist(self.channelBox,5)
    label(p,"Tracks",18,true)
    self.trackList=Instance.new("Frame");self.trackList.BackgroundTransparency=1;self.trackList.AutomaticSize=Enum.AutomaticSize.Y;self.trackList.Size=UDim2.new(1,0,0,0);self.trackList.Parent=p;vlist(self.trackList,5)

    -- PIANO
    p=self.pages.Piano
    label(p,"Perfil do piano",24,true)
    self.profileName=label(p,"Carregando perfil...",22,true);self.profileName.TextSize=10
    local pd=label(p,"Teste tres oitavas antes da musica. Isso confirma se o mapa bate com o piano do jogo.",34,false);pd.TextWrapped=true;pd.TextSize=9;pd.TextColor3=C.muted
    rowButtons(p,{
        {text="Testar C4",onClick=function()safe(callbacks.onTestNote,60)end},{text="Testar C5",onClick=function()safe(callbacks.onTestNote,72)end},{text="Testar C6",onClick=function()safe(callbacks.onTestNote,84)end}
    },40,5)
    self.mapToggle=button(p,"Mostrar mapa avancado",36);self.mapToggle.Activated:Connect(function()
        self.profileExpanded=not self.profileExpanded;self.mapToggle.Text=self.profileExpanded and "Ocultar mapa avancado" or "Mostrar mapa avancado";self:_renderProfile()
    end)
    self.profileList=Instance.new("Frame");self.profileList.BackgroundTransparency=1;self.profileList.AutomaticSize=Enum.AutomaticSize.Y;self.profileList.Size=UDim2.new(1,0,0,0);self.profileList.Visible=false;self.profileList.Parent=p;vlist(self.profileList,4)

    -- HUMAN
    p=self.pages.Human
    label(p,"Humanizacao musical",24,true)
    local hd=label(p,"A composicao continua igual. So entram microvariacoes de interpretacao. Para conferir conversao, use Exact.",38,false);hd.TextWrapped=true;hd.TextSize=9;hd.TextColor3=C.muted
    local pr1=rowButtons(p,{
        {text="Exact",onClick=function()safe(callbacks.onPreset,"Exact")end},{text="Very Subtle",onClick=function()safe(callbacks.onPreset,"Very Subtle")end}
    },38,6)
    local pr2=rowButtons(p,{
        {text="Natural",onClick=function()safe(callbacks.onPreset,"Natural")end},{text="Expressive",onClick=function()safe(callbacks.onPreset,"Expressive")end}
    },38,6)
    self.presetButtons={Exact=pr1[1],["Very Subtle"]=pr1[2],Natural=pr2[1],Expressive=pr2[2]}
    self.humanLabel=label(p,"Forca: 5%",22,true)
    local meter=Instance.new("Frame");meter.BackgroundColor3=C.card2;meter.Size=UDim2.new(1,0,0,8);round(meter,4);meter.Parent=p
    self.humanFill=Instance.new("Frame");self.humanFill.BackgroundColor3=C.accent2;self.humanFill.Size=UDim2.fromScale(.1,1);round(self.humanFill,4);self.humanFill.Parent=meter
    rowButtons(p,{
        {text="Menos",onClick=function()safe(callbacks.onHumanDelta,-.02)end},{text="Mais",onClick=function()safe(callbacks.onHumanDelta,.02)end}
    },38,6)

    -- SETTINGS
    p=self.pages.Settings
    label(p,"Fidelidade e conversao",24,true)
    local qhint=label(p,"Quantizacao altera o timing do MIDI. Para maxima fidelidade, deixe em Off.",34,false);qhint.TextWrapped=true;qhint.TextSize=9;qhint.TextColor3=C.muted
    local tr=rowButtons(p,{
        {text="-1",onClick=function()safe(callbacks.onTransposeDelta,-1)end},{text="Transpose: 0",onClick=function()safe(callbacks.onTransposeDelta,1)end},{text="+1",onClick=function()safe(callbacks.onTransposeDelta,1)end}
    },38,6);self.transposeButton=tr[2]
    self.rangeButton=button(p,"Range: SmartOctave",36);self.rangeButton.Activated:Connect(function()safe(callbacks.onCycleRange)end)
    self.quantButton=button(p,"Quantizacao: Off",36);self.quantButton.Activated:Connect(function()safe(callbacks.onCycleQuantization)end)
    label(p,"Maximo de notas por acorde",18,true)
    local mk=rowButtons(p,{
        {text="-",onClick=function()safe(callbacks.onMaxKeysDelta,-1)end},{text="16 notas",onClick=function()end},{text="+",onClick=function()safe(callbacks.onMaxKeysDelta,1)end}
    },36,6);self.maxKeysButton=mk[2]
    label(p,"Exportacao",18,true)
    rowButtons(p,{
        {text="Exportar QWERTY",onClick=function()safe(callbacks.onExportSequence)end},{text="Exportar analise",onClick=function()safe(callbacks.onExportAnalysis)end}
    },38,6)

    -- DIAGNOSTICS
    p=self.pages.Diag
    label(p,"Diagnosticos",24,true)
    self.backendLabel=label(p,"Input: ...",22,true);self.backendLabel.TextSize=10
    self.diagLabel=label(p,"Sem musica carregada.",170,false);self.diagLabel.TextWrapped=true;self.diagLabel.TextYAlignment=Enum.TextYAlignment.Top;self.diagLabel.TextSize=9;self.diagLabel.TextColor3=C.muted

    -- MINI PLAYER
    local miniFrame=Instance.new("Frame");miniFrame.Name="MiniPlayer";miniFrame.AnchorPoint=Vector2.new(0,1);miniFrame.Position=UDim2.new(.03,0,.94,0);miniFrame.Size=UDim2.fromOffset(360,52);miniFrame.BackgroundColor3=C.bg;miniFrame.Visible=false;round(miniFrame,12);outline(miniFrame);miniFrame.Parent=gui;self.miniFrame=miniFrame
    local miniVer=Instance.new("TextLabel");miniVer.BackgroundColor3=C.accent2;miniVer.Text="0.4.3";miniVer.Size=UDim2.fromOffset(44,20);miniVer.Position=UDim2.fromOffset(8,16);styleText(miniVer,8,true,Color3.fromRGB(7,22,18));round(miniVer,6);miniVer.Parent=miniFrame
    self.miniName=label(miniFrame,"Nenhum MIDI",52,true);self.miniName.Position=UDim2.fromOffset(58,0);self.miniName.Size=UDim2.new(1,-180,1,0);self.miniName.TextSize=10;self.miniName.TextTruncate=Enum.TextTruncate.AtEnd
    local miniPlay=button(miniFrame,"PLAY",34);miniPlay.Size=UDim2.fromOffset(52,34);miniPlay.Position=UDim2.new(1,-112,.5,-17);miniPlay.Activated:Connect(function()safe(callbacks.onPlayPause)end);self.miniPlay=miniPlay
    local miniOpen=button(miniFrame,"ABRIR",34);miniOpen.Size=UDim2.fromOffset(54,34);miniOpen.Position=UDim2.new(1,-56,.5,-17)

    -- HIDDEN/FLOATING
    local floating=button(gui,"MIDI",42);floating.Name="FloatingOpen";floating.Size=UDim2.fromOffset(72,42);floating.AnchorPoint=Vector2.new(.5,.5);floating.Position=UDim2.fromScale(config.ui.floatingX or .84,config.ui.floatingY or .72);floating.Visible=false;floating.BackgroundColor3=C.accent;self.floating=floating

    function self:setState(state)
        if state~="Full" and state~="Mini" and state~="Hidden" then state="Full" end
        self.state=state;gui.Enabled=true;main.Visible=state=="Full";miniFrame.Visible=state=="Mini";floating.Visible=state=="Hidden"
        safe(callbacks.onUiState,state,state=="Hidden" and floating.Position or nil)
    end
    mini.Activated:Connect(function()self:setState("Mini")end);hide.Activated:Connect(function()self:setState("Hidden")end);miniOpen.Activated:Connect(function()self:setState("Full")end);floating.Activated:Connect(function()self:setState("Full")end)

    -- Drag full window by header. A short tap on header does nothing.
    local dragging=false;local dragStart=nil;local startPos=nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true;dragStart=input.Position;startPos=main.Position end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and dragStart and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseMovement) then
            local v=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720);local d=input.Position-dragStart
            main.Position=UDim2.fromScale(math.clamp(startPos.X.Scale+d.X/v.X,.18,.82),math.clamp(startPos.Y.Scale+d.Y/v.Y,.20,.80))
        end
    end)
    UIS.InputEnded:Connect(function(input)if dragging and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then dragging=false end end)

    -- Drag floating button with movement threshold. A normal tap still opens.
    local fDrag=false;local fStart=nil;local fPos=nil;local fMoved=false
    floating.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then fDrag=true;fStart=input.Position;fPos=floating.Position;fMoved=false end
    end)
    UIS.InputChanged:Connect(function(input)
        if fDrag and fStart and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseMovement) then
            local d=input.Position-fStart;if d.Magnitude>10 then fMoved=true end
            local v=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
            floating.Position=UDim2.fromScale(math.clamp(fPos.X.Scale+d.X/v.X,.05,.95),math.clamp(fPos.Y.Scale+d.Y/v.Y,.08,.92))
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if fDrag and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then
            fDrag=false;safe(callbacks.onUiState,"Hidden",floating.Position);if not fMoved then task.defer(function()self:setState("Full")end)end
        end
    end)

    show("Songs");self:setState("Full")
    return self
end

function App:_renderSongs()
    if not self.songList then return end
    clearChildren(self.songList)
    local q=string.lower(self.searchBox and self.searchBox.Text or "")
    local count=0
    for _,s in ipairs(self.allSongs or {}) do
        local ok=q=="" or string.find(string.lower(s.name or s.path or ""),q,1,true)
        if self.songFilter=="Favorites" then ok=ok and s.favorite end
        if self.songFilter=="Recent" then ok=ok and s.recentRank~=nil end
        if ok then
            count+=1
            local b=button(self.songList,(s.favorite and "★  " or "")..(s.name or s.path),44);b.TextXAlignment=Enum.TextXAlignment.Left;b.TextTruncate=Enum.TextTruncate.AtEnd;addTextPadding(b,10,8)
            b.Activated:Connect(function()safe(self.callbacks.onSelectSong,s)end)
        end
    end
    if count==0 then
        local empty=label(self.songList,"Nenhuma musica neste filtro.",32,false);empty.TextColor3=C.muted;empty.TextSize=9
    end
end

function App:setSongs(songs,status)self.allSongs=songs or {};self.songStatus.Text=status or "";self:_renderSongs()end
function App:setMessage(x)self.message.Text=tostring(x or "");self.message.TextColor3=C.accent2 end
function App:setError(x)self.message.Text="Erro: "..tostring(x);self.message.TextColor3=C.danger end
function App:setBackend(x)self.backendLabel.Text="Input: "..tostring(x)end
function App:setFavorite(v)if self.song then self.song.favorite=v end end

function App:setSong(item,a,mapStats,perfStats)
    self.song=item;self.songName.Text=item and (item.name or item.path) or "Nenhum MIDI";self.miniName.Text=self.songName.Text
    if a then self.songInfo.Text=string.format("%d notas  •  %.1fs  •  MIDI %s-%s",a.noteCount or 0,a.duration or 0,tostring(a.pitchMin or "?"),tostring(a.pitchMax or "?")) end
    if mapStats then
        self.performanceInfo.Text=string.format("Cobertura %.1f%%  •  adaptadas %d  •  descartadas %d  •  colisoes corrigidas %d  •  simplificadas %d",
            (mapStats.coverage or 0)*100,mapStats.adapted or 0,mapStats.dropped or 0,mapStats.deduped or mapStats.collisions or 0,mapStats.simplified or 0)
    end
end

function App:setProgress(pos,dur,stats,playing)
    local f=dur and dur>0 and math.clamp(pos/dur,0,1) or 0;self.progress.Size=UDim2.fromScale(f,1);self.timeLabel.Text=fmt(pos).." / "..fmt(dur);self.playButton.Text=playing and "PAUSE" or "PLAY";self.miniPlay.Text=playing and "PAUSE" or "PLAY"
    local avg=(stats and stats.processed or 0)>0 and (stats.driftSumMs or 0)/stats.processed or 0
    self.diagLabel.Text=string.format("Posicao: %s\nEventos: %d\nAtrasados: %d\nIgnorados: %d\nCatch-ups: %d\nDrift medio: %.2f ms\nPico: %.2f ms",
        fmt(pos),stats and stats.processed or 0,stats and stats.late or 0,stats and stats.skipped or 0,stats and stats.catchups or 0,avg,stats and stats.driftPeakMs or 0)
end
function App:setActiveNotes(t)self.currentNotes.Text="Ultima tecla: "..((t and #t>0) and table.concat(t," ") or "-")end
function App:setSpeed(v)self.speedButton.Text=string.format("%.2fx",v or 1)end
function App:setHumanStrength(v)local p=math.floor((v or 0)*100+.5);self.humanLabel.Text="Forca: "..p.."%";self.humanFill.Size=UDim2.fromScale(math.clamp((v or 0)/.5,0,1),1)end
function App:setTranspose(v)self.transposeButton.Text="Transpose: "..tostring(v or 0)end
function App:setRange(v)self.rangeButton.Text="Range: "..tostring(v)end
function App:setQuantization(v)self.quantButton.Text="Quantizacao: "..tostring(v)..(v=="Off" and "  ✓ recomendado" or "  ⚠ altera timing")end
function App:setMaxKeys(v)self.maxKeysButton.Text=tostring(v).." notas"end
function App:setAB(a,b)self.abLabel.Text="A: "..(a and fmt(a) or "--").."   B: "..(b and fmt(b) or "--")end

function App:setAnalysis(a,enabledTracks,enabledChannels)
    if not a then return end
    self.splitLabel.Text="Separacao de maos: "..tostring(a.splitNote or "auto")
    self.confidenceLabel.Text=string.format("Confianca: %d%%  •  vozes detectadas: %s",math.floor((a.handConfidence or 0)*100+.5),tostring(a.voiceCount or "?"))
    clearChildren(self.channelBox)
    local used={};for _,n in ipairs(a.notes or {})do used[n.channel]=true end
    local list={};for ch=1,16 do if used[ch] then list[#list+1]=ch end end
    for base=1,#list,4 do
        local defs={}
        for i=base,math.min(base+3,#list) do
            local ch=list[i];local active=enabledChannels[ch]~=false
            defs[#defs+1]={text=(active and "ON " or "OFF ").."Ch"..ch,onClick=function()
                active=not active;safe(self.callbacks.onToggleChannel,ch,active);task.defer(function()self:setAnalysis(a,enabledTracks,enabledChannels)end)
            end}
        end
        rowButtons(self.channelBox,defs,34,5)
    end
    clearChildren(self.trackList)
    for _,tr in ipairs(a.tracks or {}) do
        local active=enabledTracks[tr.index]~=false
        local b=button(self.trackList,(active and "ON   " or "OFF  ")..(tr.name or ("Track "..tr.index)).."  •  "..tostring(tr.noteCount or 0).." notas",38);b.TextXAlignment=Enum.TextXAlignment.Left;b.TextTruncate=Enum.TextTruncate.AtEnd;addTextPadding(b,9,8)
        b.Activated:Connect(function()active=not active;b.Text=(active and "ON   " or "OFF  ")..(tr.name or ("Track "..tr.index)).."  •  "..tostring(tr.noteCount or 0).." notas";safe(self.callbacks.onToggleTrack,tr.index,active)end)
    end
end

function App:_renderProfile()
    if not self.profileList then return end
    clearChildren(self.profileList);self.profileList.Visible=self.profileExpanded
    local profile=self.currentProfile;if not self.profileExpanded or not profile then return end
    for note=profile.lowest,profile.highest do
        local row=Instance.new("Frame");row.BackgroundColor3=C.card;row.Size=UDim2.new(1,0,0,36);round(row,7);row.Parent=self.profileList
        local n=label(row,string.format("%s  •  MIDI %d",noteName(note),note),36,false);n.Position=UDim2.fromOffset(9,0);n.Size=UDim2.new(1,-82,1,0);n.TextSize=9
        local box=Instance.new("TextBox");box.BackgroundColor3=C.card2;box.Text=tostring(profile.map[note] or "");box.ClearTextOnFocus=false;box.Size=UDim2.fromOffset(58,28);box.Position=UDim2.new(1,-64,.5,-14);styleText(box,10,true);round(box,6);box.Parent=row
        box.FocusLost:Connect(function()local t=box.Text;if #t==1 then safe(self.callbacks.onProfileMapping,note,t)else box.Text=tostring(profile.map[note] or "")end end)
    end
end
function App:setProfile(profile)
    if not profile then return end
    self.currentProfile=profile;self.profileName.Text=(profile.name or profile.id).."  •  MIDI "..tostring(profile.lowest).."-"..tostring(profile.highest)
    self.mapToggle.Text=self.profileExpanded and "Ocultar mapa avancado" or "Mostrar mapa avancado ("..tostring(profile.highest-profile.lowest+1)..")";self:_renderProfile()
end

function App:destroy()if self.gui then self.gui:Destroy()end end
return App
