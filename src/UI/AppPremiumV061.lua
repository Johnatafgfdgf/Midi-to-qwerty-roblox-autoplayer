local BASE_COMMIT="2bafb0b243256a73d35cba690616a22168346e06"
local URL="https://raw.githubusercontent.com/Johnatafgfdgf/Midi-to-qwerty-roblox-autoplayer/"..BASE_COMMIT.."/src/UI/AppPremiumV060.lua"
local ok,source=pcall(function()return game:HttpGet(URL)end)
assert(ok and type(source)=="string","[MIDIQWERTY] Failed to load v0.6 UI base")
local chunk,err=loadstring(source,"=MIDIQWERTY/UI/AppPremiumV060.base")
assert(chunk,"[MIDIQWERTY] Base UI compile error: "..tostring(err))
local Base=chunk();assert(type(Base)=="table" and type(Base.new)=="function","[MIDIQWERTY] Invalid v0.6 UI base")

local App={};setmetatable(App,{__index=Base})
local TweenService=game:GetService("TweenService")
local VERSION="0.6.1"
local LEFT=Color3.fromRGB(72,218,187)
local RIGHT=Color3.fromRGB(139,98,255)
local BG=Color3.fromRGB(8,10,16)
local PANEL=Color3.fromRGB(18,22,34)
local CARD=Color3.fromRGB(29,34,50)
local TEXT=Color3.fromRGB(246,248,252)
local MUTED=Color3.fromRGB(156,165,187)

local function corner(o,r)local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r or 10);c.Parent=o end
local function stroke(o,col,trans)local s=Instance.new("UIStroke");s.Color=col or Color3.fromRGB(48,55,76);s.Thickness=1;s.Transparency=trans or .4;s.Parent=o end
local function txt(o,size,bold,col)o.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham;o.TextSize=size or 10;o.TextColor3=col or TEXT end
local function safe(cb,...)if type(cb)=="function" then pcall(cb,...)end end
local function lowerBound(notes,t)
    local lo,hi=1,#notes+1
    while lo<hi do local m=math.floor((lo+hi)/2);if m<=#notes and (notes[m].startTime or 0)<t then lo=m+1 else hi=m end end
    return lo
end
local function isBlack(n)local pc=n%12;return pc==1 or pc==3 or pc==6 or pc==8 or pc==10 end

local function patchRoll(roll)
    if not roll then return end
    function roll:_rebuildKeyboard()
        for _,v in ipairs(self.keyboard:GetChildren())do if v:IsA("GuiObject") then v:Destroy()end end
        local count=math.max(1,self.high-self.low+1)
        self.keyFrames={}
        for n=self.low,self.high do
            local k=Instance.new("Frame");k.BorderSizePixel=0;k.Name="Key_"..n;k:SetAttribute("MidiNote",n)
            k.BackgroundColor3=isBlack(n) and Color3.fromRGB(30,35,49) or Color3.fromRGB(226,231,240)
            k.Position=UDim2.new((n-self.low)/count,0,0,0);k.Size=UDim2.new(1/count,-1,1,0);k.Parent=self.keyboard
            self.keyFrames[n]=k
        end
    end
    function roll:update(pos)
        for _,f in ipairs(self.active or {})do f.Visible=false;f.Parent=nil;self.pool[#self.pool+1]=f end
        table.clear(self.active)
        if self.keyFrames then
            for n,k in pairs(self.keyFrames)do k.BackgroundColor3=isBlack(n) and Color3.fromRGB(30,35,49) or Color3.fromRGB(226,231,240) end
        end
        if #(self.notes or {})==0 or self.grid.AbsoluteSize.X<=0 then return end
        local start=math.max(0,pos-.12);local finish=pos+(self.lookAhead or 2.6)
        local i=math.max(1,lowerBound(self.notes,start)-4);local count=math.max(1,self.high-self.low+1);local h=math.max(1,self.grid.AbsoluteSize.Y);local shown=0
        while i<=#self.notes and shown<190 do
            local n=self.notes[i];local st=n.startTime or 0;if st>finish then break end
            local pitch=n.mappedNote or n.note
            if pitch and pitch>=self.low and pitch<=self.high and (n.endTime or st)>=start then
                local f=table.remove(self.pool)
                if not f then f=Instance.new("Frame");f.BorderSizePixel=0;corner(f,3)end
                f.Visible=true;f.Parent=self.grid;shown+=1
                local x=(pitch-self.low)/count;local w=math.max(2,self.grid.AbsoluteSize.X/count-1)
                local delta=st-pos;local y=h-(delta/(self.lookAhead or 2.6))*h
                local dur=math.max(.025,(n.endTime or st+.08)-st);local ph=math.clamp((dur/(self.lookAhead or 2.6))*h,5,math.max(8,h*.5))
                f.Position=UDim2.new(x,0,0,y-ph);f.Size=UDim2.fromOffset(w,ph)
                local col=n.parts and n.parts.hand=="Left" and LEFT or RIGHT
                f.BackgroundColor3=col;self.active[#self.active+1]=f
                if st<=pos and (n.endTime or st)>=pos and self.keyFrames and self.keyFrames[pitch] then self.keyFrames[pitch].BackgroundColor3=col end
            end
            i+=1
        end
    end
    roll:_rebuildKeyboard()
end

local function addChangelog(self,callbacks,config)
    local btn=Instance.new("TextButton");btn.AutoButtonColor=false;btn.BackgroundColor3=Color3.fromRGB(35,40,57);btn.Text="NEW";btn.Size=UDim2.fromOffset(44,28);btn.Position=UDim2.new(1,-166,0,13);txt(btn,8,true,Color3.fromRGB(245,198,91));corner(btn,8);stroke(btn);btn.Parent=self.header
    local shade=Instance.new("Frame");shade.BackgroundColor3=Color3.new(0,0,0);shade.BackgroundTransparency=.28;shade.Size=UDim2.fromScale(1,1);shade.Visible=false;shade.ZIndex=50;shade.Parent=self.gui
    local card=Instance.new("Frame");card.AnchorPoint=Vector2.new(.5,.5);card.Position=UDim2.fromScale(.5,.5);card.Size=UDim2.fromOffset(390,300);card.BackgroundColor3=PANEL;card.ZIndex=51;corner(card,16);stroke(card,Color3.fromRGB(70,76,103),.2);card.Parent=shade
    local title=Instance.new("TextLabel");title.BackgroundTransparency=1;title.Position=UDim2.fromOffset(18,15);title.Size=UDim2.new(1,-70,0,28);title.Text="Novidades • v0.6.1";title.TextXAlignment=Enum.TextXAlignment.Left;title.ZIndex=52;txt(title,16,true);title.Parent=card
    local close=Instance.new("TextButton");close.AutoButtonColor=false;close.BackgroundColor3=CARD;close.Text="×";close.Size=UDim2.fromOffset(36,36);close.Position=UDim2.new(1,-50,0,10);close.ZIndex=52;txt(close,18,true);corner(close,10);close.Parent=card
    local body=Instance.new("TextLabel");body.BackgroundTransparency=1;body.Position=UDim2.fromOffset(18,55);body.Size=UDim2.new(1,-36,1,-75);body.TextXAlignment=Enum.TextXAlignment.Left;body.TextYAlignment=Enum.TextYAlignment.Top;body.TextWrapped=true;body.ZIndex=52;txt(body,10,false,MUTED)
    body.Text="• Humanização Pianist refeita: timing, frase, mãos e acordes agora têm escala real.\n\n• Piano-roll usa somente duas cores: esquerda em verde-água e direita em violeta. Filtrar uma mão remove suas notas da visualização.\n\n• Cloud Dodo ganhou timeout, diagnóstico e mais rotas públicas compatíveis com o APK 2.3.0.\n\n• Transições de tela, animações Full/Mini/Hidden e acabamento visual melhorados.\n\n• Changelog interno e botão Nova interpretação adicionados."
    body.Parent=card
    local function show(v)
        shade.Visible=true;card.Size=UDim2.fromOffset(360,270);card.BackgroundTransparency=.08
        TweenService:Create(card,TweenInfo.new(.18,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(390,300),BackgroundTransparency=0}):Play()
        safe(callbacks.onChangelogSeen,VERSION)
    end
    local function hide()TweenService:Create(card,TweenInfo.new(.14),{Size=UDim2.fromOffset(370,282),BackgroundTransparency=.15}):Play();task.delay(.14,function()shade.Visible=false end)end
    btn.Activated:Connect(show);close.Activated:Connect(hide);shade.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then if i.Position.X<card.AbsolutePosition.X or i.Position.X>card.AbsolutePosition.X+card.AbsoluteSize.X or i.Position.Y<card.AbsolutePosition.Y or i.Position.Y>card.AbsolutePosition.Y+card.AbsoluteSize.Y then hide()end end end)
    if (config.ui and config.ui.lastSeenChangelog)~=VERSION then task.delay(.45,show)end
end

function App.new(callbacks,config)
    callbacks=callbacks or {};config=config or {};config.ui=config.ui or {}
    local app=Base.new(callbacks,config);assert(app and app.gui and app.main,"[MIDIQWERTY] v0.6 UI base failed")
    app.gui.Name="MIDIQWERTY_V061_PREMIUM_PLUS"
    for _,d in ipairs(app.gui:GetDescendants())do
        if d:IsA("TextLabel") and d.Text=="Premium Player • v0.6" then d.Text="Premium Player • v0.6.1" end
    end

    local accentLine=Instance.new("Frame");accentLine.BorderSizePixel=0;accentLine.BackgroundColor3=RIGHT;accentLine.Position=UDim2.fromOffset(14,51);accentLine.Size=UDim2.new(1,-28,0,2);accentLine.Parent=app.header
    local grad=Instance.new("UIGradient");grad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,LEFT),ColorSequenceKeypoint.new(.52,RIGHT),ColorSequenceKeypoint.new(1,Color3.fromRGB(245,194,91))});grad.Parent=accentLine

    patchRoll(app.pianoRoll)
    local legend=Instance.new("TextLabel");legend.BackgroundTransparency=1;legend.Size=UDim2.new(1,0,0,18);legend.Text="● Esquerda    ● Direita";legend.TextXAlignment=Enum.TextXAlignment.Center;txt(legend,9,true,MUTED);legend.Parent=app.pages.Player
    local rich=Instance.new("UIGradient");rich.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,LEFT),ColorSequenceKeypoint.new(.49,LEFT),ColorSequenceKeypoint.new(.51,RIGHT),ColorSequenceKeypoint.new(1,RIGHT)});rich.Parent=legend

    local humanCard=Instance.new("Frame");humanCard.BackgroundColor3=Color3.fromRGB(22,27,41);humanCard.AutomaticSize=Enum.AutomaticSize.Y;humanCard.Size=UDim2.new(1,0,0,0);corner(humanCard,11);stroke(humanCard);humanCard.Parent=app.pages.Performance
    local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0,10);pad.PaddingRight=UDim.new(0,10);pad.PaddingTop=UDim.new(0,8);pad.PaddingBottom=UDim.new(0,9);pad.Parent=humanCard
    local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,5);layout.Parent=humanCard
    local htitle=Instance.new("TextLabel");htitle.BackgroundTransparency=1;htitle.Size=UDim2.new(1,0,0,20);htitle.Text="Interpretação atual";htitle.TextXAlignment=Enum.TextXAlignment.Left;txt(htitle,10,true);htitle.Parent=humanCard
    local hstats=Instance.new("TextLabel");hstats.BackgroundTransparency=1;hstats.Size=UDim2.new(1,0,0,34);hstats.Text="Aguardando performance...";hstats.TextWrapped=true;hstats.TextXAlignment=Enum.TextXAlignment.Left;txt(hstats,9,false,MUTED);hstats.Parent=humanCard;app.humanStats=hstats
    local reroll=Instance.new("TextButton");reroll.AutoButtonColor=false;reroll.BackgroundColor3=RIGHT;reroll.Size=UDim2.new(1,0,0,34);reroll.Text="Nova interpretação";txt(reroll,10,true);corner(reroll,9);reroll.Parent=humanCard;reroll.Activated:Connect(function()safe(callbacks.onNewPerformance)end)

    local oldShow=app.showPage
    app.showPage=function(self,name)
        if not self.pages[name] then return end
        local old=self.activeTab
        if old==name then return oldShow(self,name)end
        local outgoing=self.pages[old];local incoming=self.pages[name]
        if outgoing and outgoing.Visible then TweenService:Create(outgoing,TweenInfo.new(.11,Enum.EasingStyle.Quad),{Position=UDim2.fromOffset(-10,0)}):Play()end
        task.delay(.07,function()
            oldShow(self,name);incoming.Position=UDim2.fromOffset(12,0)
            TweenService:Create(incoming,TweenInfo.new(.20,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=UDim2.fromOffset(0,0)}):Play()
            for n,b in pairs(self.nav)do TweenService:Create(b,TweenInfo.new(.15),{BackgroundColor3=n==name and RIGHT or Color3.fromRGB(28,33,49)}):Play()end
        end)
    end

    local oldState=app.setState
    local mainScale=Instance.new("UIScale");mainScale.Scale=1;mainScale.Parent=app.main
    local miniScale=Instance.new("UIScale");miniScale.Scale=1;miniScale.Parent=app.mini
    app.setState=function(self,state)
        if state=="Full" then
            oldState(self,"Full");mainScale.Scale=.96;self.main.BackgroundTransparency=.08;TweenService:Create(mainScale,TweenInfo.new(.20,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Scale=1}):Play();TweenService:Create(self.main,TweenInfo.new(.16),{BackgroundTransparency=0}):Play()
        elseif state=="Mini" then
            oldState(self,"Mini");miniScale.Scale=.93;TweenService:Create(miniScale,TweenInfo.new(.18,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
        else
            oldState(self,"Hidden");self.floating.Size=UDim2.fromOffset(48,48);TweenService:Create(self.floating,TweenInfo.new(.18,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(56,56)}):Play()
        end
    end

    local oldSong=app.setSong
    app.setSong=function(self,item,a,mapStats,perfStats)
        oldSong(self,item,a,mapStats,perfStats)
        if self.humanStats and perfStats then
            self.humanStats.Text=string.format("%s • intensidade %d%% • Δ médio %.1f ms • pico %.1f ms • σ %.1f ms",tostring(perfStats.preset or "Custom"),math.floor((perfStats.strength or config.humanize.strength or 0)*100+.5),perfStats.averageTimingMs or 0,perfStats.maxTimingMs or 0,perfStats.stdTimingMs or 0)
        end
    end
    local oldPerf=app.setPerformance
    app.setPerformance=function(self,notes,profile,perfStats)
        oldPerf(self,notes,profile);patchRoll(self.pianoRoll);self.pianoRoll:setNotes(notes or {},profile or self.profile)
        if self.humanStats and perfStats then self.humanStats.Text=string.format("%s • Δ médio %.1f ms • pico %.1f ms",tostring(perfStats.preset or "Custom"),perfStats.averageTimingMs or 0,perfStats.maxTimingMs or 0)end
    end

    addChangelog(app,callbacks,config)
    app:setState("Full")
    return app
end
return App
