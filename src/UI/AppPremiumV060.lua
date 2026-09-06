local App = {}
App.__index = App

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local C = {
    bg = Color3.fromRGB(8,10,16),
    panel = Color3.fromRGB(15,18,28),
    panel2 = Color3.fromRGB(21,25,38),
    card = Color3.fromRGB(28,33,49),
    card2 = Color3.fromRGB(37,43,62),
    accent = Color3.fromRGB(127,92,255),
    accent2 = Color3.fromRGB(76,215,188),
    blue = Color3.fromRGB(86,160,255),
    gold = Color3.fromRGB(245,194,91),
    text = Color3.fromRGB(247,248,252),
    muted = Color3.fromRGB(155,163,184),
    danger = Color3.fromRGB(239,91,113),
    whiteKey = Color3.fromRGB(228,232,240),
    blackKey = Color3.fromRGB(29,34,48),
}

local NOTE_NAMES = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}
local BLACK_PC = {[1]=true,[3]=true,[6]=true,[8]=true,[10]=true}

local function safe(cb,...)
    if type(cb) ~= "function" then return false end
    local ok = pcall(cb,...)
    return ok
end

local function fmt(t)
    t = math.max(0,tonumber(t) or 0)
    return string.format("%02d:%02d",math.floor(t/60),math.floor(t%60))
end

local function round(o,r)
    local x = Instance.new("UICorner")
    x.CornerRadius = UDim.new(0,r or 10)
    x.Parent = o
    return x
end

local function stroke(o,col,transparency)
    local x = Instance.new("UIStroke")
    x.Color = col or C.card2
    x.Thickness = 1
    x.Transparency = transparency or .35
    x.Parent = o
    return x
end

local function padding(o,l,r,t,b)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0,l or 0)
    p.PaddingRight = UDim.new(0,r or l or 0)
    p.PaddingTop = UDim.new(0,t or l or 0)
    p.PaddingBottom = UDim.new(0,b or t or l or 0)
    p.Parent = o
    return p
end

local function textStyle(o,size,bold,col)
    o.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    o.TextSize = size or 11
    o.TextColor3 = col or C.text
end

local function label(parent,text,size,bold,height)
    local x = Instance.new("TextLabel")
    x.BackgroundTransparency = 1
    x.Text = text or ""
    x.TextXAlignment = Enum.TextXAlignment.Left
    x.TextYAlignment = Enum.TextYAlignment.Center
    x.Size = UDim2.new(1,0,0,height or 24)
    x.TextWrapped = false
    textStyle(x,size or 10,bold)
    x.Parent = parent
    return x
end

local function button(parent,text,height,accent)
    local x = Instance.new("TextButton")
    x.AutoButtonColor = false
    x.BackgroundColor3 = accent and C.accent or C.card
    x.Text = text or ""
    x.Size = UDim2.new(1,0,0,height or 38)
    textStyle(x,10,true)
    round(x,9)
    stroke(x,accent and C.accent or C.card2,.3)
    x.Parent = parent
    x.MouseEnter:Connect(function()
        if not UIS.TouchEnabled then TweenService:Create(x,TweenInfo.new(.12),{BackgroundColor3=accent and Color3.fromRGB(143,111,255) or C.card2}):Play() end
    end)
    x.MouseLeave:Connect(function()
        if not UIS.TouchEnabled then TweenService:Create(x,TweenInfo.new(.12),{BackgroundColor3=accent and C.accent or C.card}):Play() end
    end)
    return x
end

local function hrow(parent,defs,height,gap)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1,0,0,height or 38)
    row.Parent = parent
    gap = gap or 6
    local out = {}
    for i,d in ipairs(defs) do
        local b = button(row,d.text,height or 38,d.accent)
        b.Position = UDim2.new((i-1)/#defs,gap/2,0,0)
        b.Size = UDim2.new(1/#defs,-gap,1,0)
        if d.click then b.Activated:Connect(d.click) end
        out[i] = b
    end
    return out,row
end

local function vlist(parent,gap)
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Vertical
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0,gap or 7)
    l.Parent = parent
    return l
end

local function scroll(parent)
    local s = Instance.new("ScrollingFrame")
    s.BackgroundTransparency = 1
    s.BorderSizePixel = 0
    s.Size = UDim2.fromScale(1,1)
    s.CanvasSize = UDim2.new()
    s.AutomaticCanvasSize = Enum.AutomaticSize.Y
    s.ScrollBarThickness = 3
    s.ScrollBarImageColor3 = C.accent
    s.ScrollingDirection = Enum.ScrollingDirection.Y
    s.Parent = parent
    padding(s,0,5,0,4)
    vlist(s,7)
    return s
end

local function section(parent,titleText)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = C.panel2
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Size = UDim2.new(1,0,0,0)
    round(card,11)
    stroke(card,C.card2,.45)
    padding(card,10,10,9,10)
    card.Parent = parent
    vlist(card,6)
    local t = label(card,titleText,11,true,22)
    t.TextColor3 = C.text
    return card
end

local function clearDynamic(parent)
    for _,v in ipairs(parent:GetChildren()) do
        if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then v:Destroy() end
    end
end

local function makeDraggable(frame,handle,onEnd)
    local dragging,startInput,startPos=false,nil,nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true;startInput=input.Position;startPos=frame.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseMovement) then
            local d=input.Position-startInput
            frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then
            dragging=false;if onEnd then pcall(onEnd,frame.Position) end
        end
    end)
end

local function makeSeekBar(parent,height,onSeek)
    local root = Instance.new("Frame")
    root.BackgroundColor3 = C.card2
    root.Size = UDim2.new(1,0,0,height or 12)
    root.Active = true
    round(root,(height or 12)/2)
    root.Parent = parent
    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = C.accent
    fill.Size = UDim2.fromScale(0,1)
    round(fill,(height or 12)/2)
    fill.Parent = root
    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(.5,.5)
    knob.Position = UDim2.fromScale(0,.5)
    knob.Size = UDim2.fromOffset((height or 12)+5,(height or 12)+5)
    knob.BackgroundColor3 = C.text
    round(knob,99)
    knob.Parent = root
    local dragging=false
    local function seekAt(x)
        local a=root.AbsolutePosition.X;local w=math.max(1,root.AbsoluteSize.X)
        local r=math.clamp((x-a)/w,0,1)
        if onSeek then onSeek(r) end
    end
    root.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true;seekAt(i.Position.X) end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then seekAt(i.Position.X) end
    end)
    UIS.InputEnded:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1) then dragging=false end
    end)
    return {root=root,fill=fill,knob=knob,set=function(r)
        r=math.clamp(r or 0,0,1);fill.Size=UDim2.fromScale(r,1);knob.Position=UDim2.fromScale(r,.5)
    end}
end

-- Lightweight virtualized piano-roll. It draws only notes close to the playhead.
local PianoRoll = {}
PianoRoll.__index = PianoRoll
function PianoRoll.new(parent,lookAhead)
    local self=setmetatable({notes={},lookAhead=lookAhead or 3.5,low=36,high=96,pool={},active={}},PianoRoll)
    local root=Instance.new("Frame");root.BackgroundColor3=Color3.fromRGB(10,13,21);root.Size=UDim2.new(1,0,0,150);root.ClipsDescendants=true;round(root,10);stroke(root,C.card2,.5);root.Parent=parent;self.root=root
    local grid=Instance.new("Frame");grid.BackgroundTransparency=1;grid.Size=UDim2.new(1,0,1,-27);grid.Parent=root;self.grid=grid
    local keyboard=Instance.new("Frame");keyboard.BackgroundColor3=C.panel;keyboard.AnchorPoint=Vector2.new(0,1);keyboard.Position=UDim2.fromScale(0,1);keyboard.Size=UDim2.new(1,0,0,27);keyboard.ClipsDescendants=true;keyboard.Parent=root;self.keyboard=keyboard
    return self
end
function PianoRoll:_rebuildKeyboard()
    clearDynamic(self.keyboard)
    local count=math.max(1,self.high-self.low+1)
    for n=self.low,self.high do
        local pc=n%12
        local k=Instance.new("Frame")
        k.BorderSizePixel=0
        k.BackgroundColor3=BLACK_PC[pc] and C.blackKey or C.whiteKey
        k.Position=UDim2.new((n-self.low)/count,0,0,0)
        k.Size=UDim2.new(1/count,0,1,0)
        k.ZIndex=BLACK_PC[pc] and 2 or 1
        k.Parent=self.keyboard
    end
end
function PianoRoll:setNotes(notes,profile)
    self.notes=notes or {}
    self.low=profile and profile.lowest or 36
    self.high=profile and profile.highest or 96
    table.sort(self.notes,function(a,b)return (a.startTime or 0)<(b.startTime or 0)end)
    self:_rebuildKeyboard()
end
local function lowerBoundNotes(notes,t)
    local lo,hi=1,#notes+1
    while lo<hi do local m=math.floor((lo+hi)/2);if m<=#notes and (notes[m].startTime or 0)<t then lo=m+1 else hi=m end end
    return lo
end
function PianoRoll:_getFrame()
    local f=table.remove(self.pool)
    if not f then f=Instance.new("Frame");f.BorderSizePixel=0;round(f,3) end
    f.Visible=true;f.Parent=self.grid;return f
end
function PianoRoll:update(pos)
    for _,f in ipairs(self.active) do f.Visible=false;f.Parent=nil;self.pool[#self.pool+1]=f end
    table.clear(self.active)
    if #self.notes==0 or self.grid.AbsoluteSize.X<=0 then return end
    local start=math.max(0,pos-.15);local finish=pos+self.lookAhead
    local i=math.max(1,lowerBoundNotes(self.notes,start)-3)
    local count=math.max(1,self.high-self.low+1);local h=math.max(1,self.grid.AbsoluteSize.Y)
    local shown=0
    while i<=#self.notes and shown<160 do
        local n=self.notes[i];local st=n.startTime or 0
        if st>finish then break end
        local pitch=n.mappedNote or n.note
        if pitch and pitch>=self.low and pitch<=self.high and (n.endTime or st)>=start then
            local f=self:_getFrame();shown+=1
            local x=(pitch-self.low)/count
            local w=math.max(2,self.grid.AbsoluteSize.X/count-1)
            local delta=st-pos
            local y=h-(delta/self.lookAhead)*h
            local dur=math.max(.03,(n.endTime or st+.08)-st)
            local ph=math.clamp((dur/self.lookAhead)*h,5,math.max(7,h*.45))
            f.Position=UDim2.new(x,0,0,y-ph)
            f.Size=UDim2.fromOffset(w,ph)
            if n.parts and n.parts.melody then f.BackgroundColor3=C.gold
            elseif n.parts and n.parts.hand=="Left" then f.BackgroundColor3=C.accent2
            else f.BackgroundColor3=C.accent end
            self.active[#self.active+1]=f
        end
        i+=1
    end
end

function App.new(callbacks,config)
    callbacks=callbacks or {};config=config or {};config.ui=config.ui or {};config.playback=config.playback or {};config.humanize=config.humanize or {};config.playback.expression=config.playback.expression or {}
    local self=setmetatable({callbacks=callbacks,config=config,pages={},nav={},songs={},cloudSongs={},position=0,duration=0,playing=false,state="Full",activeTab=config.ui.activeTab or "Library",librarySource=config.ui.librarySource or "Local",analysis=nil,profile=nil,perfNotes={}},App)

    local gui=Instance.new("ScreenGui");gui.Name="MIDIQWERTY_V060_PREMIUM";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;gui.DisplayOrder=15000;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    local parent=(gethui and gethui()) or CoreGui
    if not pcall(function()gui.Parent=parent end) then gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui") end
    self.gui=gui

    local shadow=Instance.new("Frame");shadow.AnchorPoint=Vector2.new(.5,.5);shadow.BackgroundColor3=Color3.new(0,0,0);shadow.BackgroundTransparency=.45;round(shadow,17);shadow.Parent=gui
    local main=Instance.new("Frame");main.AnchorPoint=Vector2.new(.5,.5);main.Position=UDim2.fromScale(.40,.49);main.BackgroundColor3=C.bg;main.ClipsDescendants=true;round(main,15);stroke(main,C.card2,.25);main.Parent=gui;self.main=main;self.shadow=shadow
    local grad=Instance.new("UIGradient");grad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(12,14,22)),ColorSequenceKeypoint.new(1,Color3.fromRGB(8,10,16))});grad.Rotation=90;grad.Parent=main

    local function resize()
        local v=(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1280,720)
        local landscape=v.X>=v.Y
        local w=landscape and math.clamp(v.X*.47,520,670) or math.clamp(v.X-18,330,430)
        local h=landscape and math.clamp(v.Y*.66,360,430) or math.clamp(v.Y*.72,470,620)
        main.Size=UDim2.fromOffset(w,h);shadow.Size=UDim2.fromOffset(w+12,h+14);shadow.Position=main.Position
    end
    resize();if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end

    local header=Instance.new("Frame");header.BackgroundTransparency=1;header.Size=UDim2.new(1,0,0,54);header.Parent=main;self.header=header
    local title=label(header,"MIDI QWERTY",15,true,28);title.Position=UDim2.fromOffset(14,7);title.Size=UDim2.new(0,160,0,25)
    local sub=label(header,"Premium Player • v0.6",9,false,18);sub.Position=UDim2.fromOffset(14,31);sub.Size=UDim2.new(0,190,0,16);sub.TextColor3=C.muted
    local mini=button(header,"MINI",34);mini.Size=UDim2.fromOffset(54,34);mini.Position=UDim2.new(1,-116,0,10)
    local hide=button(header,"×",34);hide.Size=UDim2.fromOffset(42,34);hide.Position=UDim2.new(1,-52,0,10);hide.TextSize=18
    makeDraggable(main,header,function()shadow.Position=main.Position end)

    local nav=Instance.new("Frame");nav.BackgroundColor3=C.panel;nav.Position=UDim2.fromOffset(9,57);nav.Size=UDim2.new(0,106,1,-66);round(nav,12);stroke(nav,C.card2,.5);nav.Parent=main;padding(nav,7,7,8,8);vlist(nav,6)
    self.status=label(nav,"Pronto",8,false,30);self.status.TextColor3=C.accent2;self.status.TextWrapped=true
    local navDefs={{"Library","BIBLIOTECA"},{"Player","PLAYER"},{"Performance","PERFORMANCE"},{"Settings","AJUSTES"}}

    local content=Instance.new("Frame");content.BackgroundColor3=C.panel;content.Position=UDim2.fromOffset(123,57);content.Size=UDim2.new(1,-132,1,-66);round(content,12);stroke(content,C.card2,.5);content.ClipsDescendants=true;content.Parent=main;padding(content,9,9,9,9)
    for _,d in ipairs(navDefs) do
        local b=button(nav,d[2],34);b.TextSize=8;self.nav[d[1]]=b
        local p=scroll(content);p.Visible=false;self.pages[d[1]]=p
        b.Activated:Connect(function()self:showPage(d[1])end)
    end

    -- LIBRARY
    local p=self.pages.Library
    label(p,"Biblioteca",14,true,26)
    local srcBtns=hrow(p,{
        {text="No aparelho",accent=true,click=function()self:setLibrarySource("Local")end},
        {text="Na nuvem",click=function()self:setLibrarySource("Cloud")end},
    },38,6);self.localSourceButton=srcBtns[1];self.cloudSourceButton=srcBtns[2]
    local search=Instance.new("TextBox");search.PlaceholderText="Pesquisar música...";search.ClearTextOnFocus=false;search.Text="";search.BackgroundColor3=C.card;search.Size=UDim2.new(1,0,0,40);search.TextXAlignment=Enum.TextXAlignment.Left;textStyle(search,10,false);round(search,9);stroke(search,C.card2,.35);padding(search,10,10,0,0);search.Parent=p;self.searchBox=search
    local tools=hrow(p,{
        {text="Atualizar",click=function()if self.librarySource=="Cloud" then safe(callbacks.onCloudSearch,search.Text) else safe(callbacks.onRefresh) end end},
        {text="Favoritos",click=function()self.config.ui.songFilter=self.config.ui.songFilter=="Favorites" and "All" or "Favorites";self:_renderLibrary()end},
    },36,6)
    self.libraryInfo=label(p,"Procurando músicas...",9,false,20);self.libraryInfo.TextColor3=C.muted
    self.libraryList=Instance.new("Frame");self.libraryList.BackgroundTransparency=1;self.libraryList.AutomaticSize=Enum.AutomaticSize.Y;self.libraryList.Size=UDim2.new(1,0,0,0);self.libraryList.Parent=p;vlist(self.libraryList,6)
    search:GetPropertyChangedSignal("Text"):Connect(function()if self.librarySource=="Local" then self:_renderLibrary() end end)

    -- PLAYER
    p=self.pages.Player
    self.songName=label(p,"Nenhuma música selecionada",14,true,28);self.songName.TextTruncate=Enum.TextTruncate.AtEnd
    self.songMeta=label(p,"Escolha um MIDI na Biblioteca.",9,false,24);self.songMeta.TextColor3=C.muted
    self.pianoRoll=PianoRoll.new(p,config.ui.pianoRollLookAhead or 3.5)
    local timeRow=Instance.new("Frame");timeRow.BackgroundTransparency=1;timeRow.Size=UDim2.new(1,0,0,18);timeRow.Parent=p
    self.timeLabel=label(timeRow,"00:00",9,false,18);self.timeLabel.Size=UDim2.new(.5,0,1,0);self.timeLabel.TextColor3=C.muted
    self.durationLabel=label(timeRow,"00:00",9,false,18);self.durationLabel.Position=UDim2.fromScale(.5,0);self.durationLabel.Size=UDim2.new(.5,0,1,0);self.durationLabel.TextXAlignment=Enum.TextXAlignment.Right;self.durationLabel.TextColor3=C.muted
    self.mainSeek=makeSeekBar(p,11,function(r)self:_seekRatio(r)end)
    local transport=hrow(p,{
        {text="‹‹ 5s",click=function()safe(callbacks.onSeekRelative,-5)end},
        {text="▶",accent=true,click=function()safe(callbacks.onPlayPause)end},
        {text="5s ››",click=function()safe(callbacks.onSeekRelative,5)end},
    },44,7);self.playButton=transport[2];self.playButton.TextSize=17
    local secondary=hrow(p,{
        {text="Anterior",click=function()safe(callbacks.onPrev)end},
        {text="1.00x",click=function()safe(callbacks.onCycleSpeed)end},
        {text="Próxima",click=function()safe(callbacks.onNext)end},
    },34,6);self.speedButton=secondary[2]
    local loop=hrow(p,{{text="Loop: OFF",click=function()safe(callbacks.onToggleLoopSong)end},{text="Soltar teclas",click=function()safe(callbacks.onPanic)end}},34,6);self.loopButton=loop[1]
    self.liveNotes=label(p,"Teclas: -",9,false,20);self.liveNotes.TextColor3=C.accent2

    -- PERFORMANCE
    p=self.pages.Performance
    label(p,"Performance",14,true,26)
    local parts=section(p,"Partes da música")
    self.modeButtons={}
    local r1=hrow(parts,{
        {text="Ambas",click=function()self:_selectMode("Both")end},{text="Esquerda",click=function()self:_selectMode("Left")end},{text="Direita",click=function()self:_selectMode("Right")end},
    },34,5)
    local r2=hrow(parts,{
        {text="Melodia",click=function()self:_selectMode("Melody")end},{text="Acomp.",click=function()self:_selectMode("Accompaniment")end},{text="Baixo",click=function()self:_selectMode("Bass")end},
    },34,5)
    self.modeButtons={Both=r1[1],Left=r1[2],Right=r1[3],Melody=r2[1],Accompaniment=r2[2],Bass=r2[3]}
    self.splitLabel=label(parts,"Separação: aguardando MIDI",9,false,20);self.splitLabel.TextColor3=C.muted
    self.trackBox=Instance.new("Frame");self.trackBox.BackgroundTransparency=1;self.trackBox.AutomaticSize=Enum.AutomaticSize.Y;self.trackBox.Size=UDim2.new(1,0,0,0);self.trackBox.Parent=parts;vlist(self.trackBox,5)

    local human=section(p,"Humanização")
    local preset=hrow(human,{
        {text="Exato",click=function()safe(callbacks.onPreset,"Exact")end},
        {text="Sutil",click=function()safe(callbacks.onPreset,"Very Subtle")end},
        {text="Pianista",accent=true,click=function()safe(callbacks.onPreset,"Pianist")end},
    },34,5)
    self.humanLabel=label(human,"Intensidade: 14%",9,false,20);self.humanLabel.TextColor3=C.muted
    hrow(human,{{text="-",click=function()safe(callbacks.onHumanDelta,-.02)end},{text="+",click=function()safe(callbacks.onHumanDelta,.02)end}},32,6)
    self.pressureLabel=label(human,"Toque: duração MIDI",9,false,20);self.pressureLabel.TextColor3=C.accent2

    -- SETTINGS
    p=self.pages.Settings
    label(p,"Ajustes",14,true,26)
    local playSec=section(p,"Reprodução")
    self.transposeLabel=label(playSec,"Transposição: 0",9,false,20);self.transposeLabel.TextColor3=C.muted
    hrow(playSec,{{text="-1",click=function()safe(callbacks.onTransposeDelta,-1)end},{text="+1",click=function()safe(callbacks.onTransposeDelta,1)end}},32,6)
    self.rangeLabel=label(playSec,"Faixa: SmartOctave",9,false,20);self.quantLabel=label(playSec,"Quantização: Off",9,false,20);self.maxKeysLabel=label(playSec,"Máx. teclas: 16",9,false,20)
    hrow(playSec,{{text="Faixa",click=function()safe(callbacks.onCycleRange)end},{text="Quantização",click=function()safe(callbacks.onCycleQuantization)end},{text="- teclas",click=function()safe(callbacks.onMaxKeysDelta,-1)end},{text="+ teclas",click=function()safe(callbacks.onMaxKeysDelta,1)end}},32,4)

    local touchSec=section(p,"Duração das teclas")
    self.holdLabel=label(touchSec,"MIDI • 18–650 ms • escala 90%",9,false,20);self.holdLabel.TextColor3=C.muted
    hrow(touchSec,{
        {text="Mais curto",click=function()safe(callbacks.onExpressionScaleDelta,-.05)end},
        {text="Mais longo",click=function()safe(callbacks.onExpressionScaleDelta,.05)end},
    },34,6)
    local tip=label(touchSec,"A tecla segue o NoteOff real do MIDI e solta antes da próxima repetição da mesma tecla.",9,false,40);tip.TextWrapped=true;tip.TextColor3=C.muted

    local pianoSec=section(p,"Piano / QWERTY")
    self.profileName=label(pianoSec,"Perfil: carregando...",9,false,20);self.profileName.TextColor3=C.muted
    hrow(pianoSec,{{text="Testar C4",click=function()safe(callbacks.onTestNote,60)end},{text="Testar C5",click=function()safe(callbacks.onTestNote,72)end},{text="Testar C6",click=function()safe(callbacks.onTestNote,84)end}},34,5)

    local diag=section(p,"Diagnóstico")
    self.backendLabel=label(diag,"Backend: verificando...",9,false,20);self.backendLabel.TextColor3=C.muted
    self.diagLabel=label(diag,"Sem dados de reprodução.",9,false,50);self.diagLabel.TextWrapped=true;self.diagLabel.TextColor3=C.muted

    -- MINI PLAYER
    local miniFrame=Instance.new("Frame");miniFrame.AnchorPoint=Vector2.new(.5,1);miniFrame.Position=UDim2.fromScale(.5,.96);miniFrame.Size=UDim2.fromOffset(430,92);miniFrame.BackgroundColor3=C.panel;miniFrame.Visible=false;round(miniFrame,14);stroke(miniFrame,C.card2,.25);miniFrame.Parent=gui;self.mini=miniFrame
    local miniTitle=label(miniFrame,"Nenhuma música",11,true,24);miniTitle.Position=UDim2.fromOffset(12,8);miniTitle.Size=UDim2.new(1,-130,0,24);miniTitle.TextTruncate=Enum.TextTruncate.AtEnd;self.miniTitle=miniTitle
    local miniPlay=button(miniFrame,"▶",40,true);miniPlay.Size=UDim2.fromOffset(44,40);miniPlay.Position=UDim2.new(1,-116,0,8);miniPlay.TextSize=16;miniPlay.Activated:Connect(function()safe(callbacks.onPlayPause)end);self.miniPlay=miniPlay
    local expand=button(miniFrame,"↗",40);expand.Size=UDim2.fromOffset(44,40);expand.Position=UDim2.new(1,-64,0,8);expand.TextSize=16;expand.Activated:Connect(function()self:setState("Full")end)
    local miniTime=label(miniFrame,"00:00 / 00:00",8,false,18);miniTime.Position=UDim2.fromOffset(12,34);miniTime.Size=UDim2.new(1,-140,0,18);miniTime.TextColor3=C.muted;self.miniTime=miniTime
    local miniSeekHolder=Instance.new("Frame");miniSeekHolder.BackgroundTransparency=1;miniSeekHolder.Position=UDim2.fromOffset(12,61);miniSeekHolder.Size=UDim2.new(1,-24,0,16);miniSeekHolder.Parent=miniFrame
    self.miniSeek=makeSeekBar(miniSeekHolder,9,function(r)self:_seekRatio(r)end)
    makeDraggable(miniFrame,miniFrame)

    -- HIDDEN BUBBLE
    local floating=button(gui,"♪",52,true);floating.Size=UDim2.fromOffset(56,56);floating.Position=UDim2.fromScale(config.ui.floatingX or .84,config.ui.floatingY or .72);floating.Visible=false;floating.TextSize=22;floating.Parent=gui;self.floating=floating
    makeDraggable(floating,floating,function(pos)safe(callbacks.onUiState,"Hidden",pos)end)
    floating.Activated:Connect(function()self:setState("Full")end)

    mini.Activated:Connect(function()self:setState("Mini")end)
    hide.Activated:Connect(function()self:setState("Hidden")end)
    self:showPage(self.activeTab)
    self:setLibrarySource(self.librarySource)
    self:setState("Full")
    return self
end

function App:_seekRatio(r)
    if self.duration<=0 then return end
    local target=math.clamp(r,0,1)*self.duration
    if self.callbacks.onSeekAbsolute then safe(self.callbacks.onSeekAbsolute,target)
    else safe(self.callbacks.onSeekRelative,target-self.position) end
end

function App:showPage(name)
    if not self.pages[name] then return end
    self.activeTab=name;self.config.ui.activeTab=name
    for n,p in pairs(self.pages) do p.Visible=n==name end
    for n,b in pairs(self.nav) do b.BackgroundColor3=n==name and C.accent or C.card end
    safe(self.callbacks.onUiState,self.state,nil)
end

function App:setLibrarySource(source)
    self.librarySource=source=="Cloud" and "Cloud" or "Local";self.config.ui.librarySource=self.librarySource
    self.localSourceButton.BackgroundColor3=self.librarySource=="Local" and C.accent or C.card
    self.cloudSourceButton.BackgroundColor3=self.librarySource=="Cloud" and C.accent or C.card
    self.searchBox.PlaceholderText=self.librarySource=="Cloud" and "Pesquisar na biblioteca do Dodo..." or "Pesquisar MIDIs do aparelho..."
    self:_renderLibrary();safe(self.callbacks.onUiState,self.state,nil)
end

function App:_renderLibrary()
    clearDynamic(self.libraryList)
    local q=string.lower(self.searchBox.Text or "")
    local source=self.librarySource=="Cloud" and self.cloudSongs or self.songs
    local filtered={}
    for _,s in ipairs(source) do
        local name=string.lower(s.name or s.path or "")
        local ok=q=="" or string.find(name,q,1,true)
        if self.librarySource=="Local" and self.config.ui.songFilter=="Favorites" then ok=ok and s.favorite==true end
        if ok then filtered[#filtered+1]=s end
    end
    if #filtered==0 then
        local empty=Instance.new("Frame");empty.BackgroundColor3=C.panel2;empty.Size=UDim2.new(1,0,0,128);round(empty,12);empty.Parent=self.libraryList
        local icon=label(empty,"♫",34,true,46);icon.TextXAlignment=Enum.TextXAlignment.Center;icon.Position=UDim2.fromOffset(0,12);icon.Size=UDim2.new(1,0,0,46);icon.TextColor3=C.accent
        local msg=label(empty,self.librarySource=="Cloud" and "Nenhuma música da nuvem carregada" or "Nenhum MIDI encontrado",11,true,24);msg.TextXAlignment=Enum.TextXAlignment.Center;msg.Position=UDim2.fromOffset(0,60);msg.Size=UDim2.new(1,0,0,24)
        local sub=label(empty,self.librarySource=="Cloud" and "Pesquise acima para consultar o provider." or "Adicione .mid em Delta/Workspace/MIDI/",9,false,24);sub.TextXAlignment=Enum.TextXAlignment.Center;sub.Position=UDim2.fromOffset(0,88);sub.Size=UDim2.new(1,0,0,24);sub.TextColor3=C.muted
        return
    end
    for _,s in ipairs(filtered) do
        local row=Instance.new("Frame");row.BackgroundColor3=C.card;row.Size=UDim2.new(1,0,0,54);round(row,9);stroke(row,C.card2,.5);row.Parent=self.libraryList
        local name=label(row,s.name or "Música",10,true,22);name.Position=UDim2.fromOffset(10,6);name.Size=UDim2.new(1,-115,0,22);name.TextTruncate=Enum.TextTruncate.AtEnd
        local meta=label(row,self.librarySource=="Cloud" and ((s.singer and s.singer~="" and s.singer.." • " or "")..tostring(s.downloads or 0).." downloads") or (s.favorite and "★ Favorita" or "MIDI local"),8,false,17);meta.Position=UDim2.fromOffset(10,29);meta.Size=UDim2.new(1,-115,0,17);meta.TextColor3=C.muted
        local act=button(row,self.librarySource=="Cloud" and "BAIXAR" or "ABRIR",34,self.librarySource~="Cloud");act.Size=UDim2.fromOffset(76,34);act.Position=UDim2.new(1,-86,0,10);act.TextSize=8
        act.Activated:Connect(function()
            if self.librarySource=="Cloud" then safe(self.callbacks.onCloudDownload,s) else safe(self.callbacks.onSelectSong,s) end
        end)
        if self.librarySource=="Local" then
            local star=button(row,s.favorite and "★" or "☆",30);star.Size=UDim2.fromOffset(30,30);star.Position=UDim2.new(1,-122,0,12);star.TextSize=14
            star.Activated:Connect(function()safe(self.callbacks.onToggleFavorite,s)end)
        end
    end
end

function App:_selectMode(mode)
    self.config.playback.mode=mode
    for n,b in pairs(self.modeButtons) do b.BackgroundColor3=n==mode and C.accent or C.card end
    safe(self.callbacks.onMode,mode)
end

function App:setSongs(songs,status)
    self.songs=songs or {};self.libraryInfo.Text=status or (#self.songs.." MIDI(s)")
    if self.librarySource=="Local" then self:_renderLibrary() end
end
function App:setCloudSongs(songs,status)
    self.cloudSongs=songs or {};self.libraryInfo.Text=status or (#self.cloudSongs.." resultado(s) na nuvem")
    if self.librarySource=="Cloud" then self:_renderLibrary() end
end
function App:setCloudStatus(msg)self.libraryInfo.Text=tostring(msg or "")end

function App:setSong(item,a,mapStats,perfStats)
    self.song=item;self.songName.Text=item and item.name or "Nenhuma música";self.miniTitle.Text=self.songName.Text
    local bpm=a and a.bpmMin and math.floor(a.bpmMin+.5) or nil
    self.songMeta.Text=string.format("%s notas • %s • %s",tostring(a and a.noteCount or 0),bpm and (bpm.." BPM") or "tempo MIDI",a and fmt(a.duration) or "00:00")
    if perfStats and perfStats.averageTimingMs then
        self.status.Text=string.format("Performance pronta • %.1f ms",perfStats.averageTimingMs)
    else self.status.Text="Performance pronta" end
    if mapStats then
        self.diagLabel.Text=string.format("Cobertura %.1f%% • adaptadas %d • descartadas %d • colisões %d",(mapStats.coverage or 0)*100,mapStats.adapted or 0,mapStats.dropped or 0,mapStats.collisions or 0)
    end
end
function App:setPerformance(notes,profile)
    self.perfNotes=notes or {};self.pianoRoll:setNotes(self.perfNotes,profile or self.profile)
end
function App:setProgress(pos,dur,stats,playing)
    self.position=pos or 0;self.duration=dur or self.duration or 0;self.playing=playing==true
    local r=self.duration>0 and self.position/self.duration or 0
    self.mainSeek.set(r);self.miniSeek.set(r)
    self.timeLabel.Text=fmt(self.position);self.durationLabel.Text=fmt(self.duration);self.miniTime.Text=fmt(self.position).." / "..fmt(self.duration)
    self.playButton.Text=self.playing and "Ⅱ" or "▶";self.miniPlay.Text=self.playing and "Ⅱ" or "▶"
    self.pianoRoll:update(self.position)
    if stats then
        local avg=stats.processed>0 and (stats.driftSumMs or 0)/stats.processed or 0
        self.diagLabel.Text=string.format("Eventos %d • atrasados %d • pulados %d • drift %.1f ms • pico %.1f ms",stats.processed or 0,stats.late or 0,stats.skipped or 0,avg,stats.driftPeakMs or 0)
    end
end
function App:setActiveNotes(tokens)self.liveNotes.Text="Teclas: "..(#(tokens or {})>0 and table.concat(tokens," ") or "-")end
function App:setSpeed(v)self.speedButton.Text=string.format("%.2fx",v or 1)end
function App:setAB()end
function App:setFavorite(v)if self.song then self.song.favorite=v end;self:_renderLibrary()end
function App:setTranspose(v)self.transposeLabel.Text="Transposição: "..tostring(v or 0)end
function App:setRange(v)self.rangeLabel.Text="Faixa: "..tostring(v or "SmartOctave")end
function App:setQuantization(v)self.quantLabel.Text="Quantização: "..tostring(v or "Off")end
function App:setMaxKeys(v)self.maxKeysLabel.Text="Máx. teclas: "..tostring(v or 16)end
function App:setHumanStrength(v)self.humanLabel.Text=string.format("Intensidade: %d%%",math.floor((v or 0)*100+.5))end
function App:setLoopSong(v)self.loopButton.Text="Loop: "..(v and "ON" or "OFF");self.loopButton.BackgroundColor3=v and C.accent or C.card end
function App:setExpression(expr)
    expr=expr or {};self.holdLabel.Text=string.format("%s • %d–%d ms • escala %d%%",expr.durationMode or "MIDI",math.floor(expr.minHoldMs or 18),math.floor(expr.maxHoldMs or 650),math.floor((expr.holdScale or .9)*100+.5))
end
function App:setBackend(v)self.backendLabel.Text="Backend: "..tostring(v or "indisponível");self.backendLabel.TextColor3=tostring(v):find("Unavailable",1,true) and C.danger or C.accent2 end
function App:setProfile(profile)self.profile=profile;self.profileName.Text="Perfil: "..tostring(profile and profile.name or "não carregado");if self.perfNotes then self.pianoRoll:setNotes(self.perfNotes,profile) end end
function App:setAnalysis(a,enabledTracks,enabledChannels)
    self.analysis=a
    self.splitLabel.Text=string.format("Separação automática: MIDI %s • confiança %d%%",tostring(a and a.handSplit or "-"),math.floor((a and a.handConfidence or 0)*100+.5))
    clearDynamic(self.trackBox)
    if not a or not a.tracks then return end
    local count=0
    for i,t in ipairs(a.tracks) do
        if t and (t.noteCount or 0)>0 and count<10 then
            count+=1
            local on=enabledTracks[i]~=false
            local b=button(self.trackBox,(on and "✓ " or "○ ")..(t.name or ("Track "..i)).."  •  "..tostring(t.noteCount or 0).." notas",30)
            b.TextXAlignment=Enum.TextXAlignment.Left;padding(b,8,8,0,0);b.TextSize=8
            b.Activated:Connect(function()on=not on;b.Text=(on and "✓ " or "○ ")..(t.name or ("Track "..i)).."  •  "..tostring(t.noteCount or 0).." notas";safe(self.callbacks.onToggleTrack,i,on)end)
        end
    end
end

function App:setMessage(msg)self.status.Text=tostring(msg or "")end
function App:setError(msg)self.status.Text="Erro: "..tostring(msg or "");self.status.TextColor3=C.danger end

function App:setState(state)
    state=(state=="Mini" or state=="Hidden") and state or "Full";self.state=state
    self.main.Visible=state=="Full";self.shadow.Visible=state=="Full";self.mini.Visible=state=="Mini";self.floating.Visible=state=="Hidden"
    safe(self.callbacks.onUiState,state,nil)
end

function App:destroy()
    if self.gui then self.gui:Destroy() end
end

return App
