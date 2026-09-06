local App={}
App.__index=App

local Players=game:GetService("Players")
local CoreGui=game:GetService("CoreGui")
local UIS=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")

local T={
    bg=Color3.fromRGB(7,9,14),
    glass=Color3.fromRGB(16,19,29),
    glass2=Color3.fromRGB(22,26,38),
    raised=Color3.fromRGB(29,34,49),
    border=Color3.fromRGB(53,60,81),
    text=Color3.fromRGB(247,248,252),
    muted=Color3.fromRGB(151,160,181),
    faint=Color3.fromRGB(91,99,119),
    accent=Color3.fromRGB(128,93,255),
    accentSoft=Color3.fromRGB(95,78,170),
    left=Color3.fromRGB(62,216,185),
    right=Color3.fromRGB(139,98,255),
    danger=Color3.fromRGB(237,92,113),
    gold=Color3.fromRGB(242,190,88),
    white=Color3.fromRGB(232,236,244),
    black=Color3.fromRGB(26,30,42),
}

local function clamp(v,a,b)return math.max(a,math.min(b,v))end
local function fmt(t)
    t=math.max(0,tonumber(t) or 0)
    return string.format("%02d:%02d",math.floor(t/60),math.floor(t%60))
end
local function corner(o,r)local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r or 10);c.Parent=o;return c end
local function stroke(o,col,tr)local s=Instance.new("UIStroke");s.Color=col or T.border;s.Thickness=1;s.Transparency=tr or .45;s.Parent=o;return s end
local function textStyle(o,size,bold,col)
    o.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    o.TextSize=size or 11;o.TextColor3=col or T.text
end
local function label(parent,text,size,bold)
    local x=Instance.new("TextLabel")
    x.BackgroundTransparency=1;x.Text=text or "";x.TextXAlignment=Enum.TextXAlignment.Left;x.TextYAlignment=Enum.TextYAlignment.Center
    x.Size=UDim2.new(1,0,0,22);textStyle(x,size,bold);x.Parent=parent;return x
end
local function button(parent,text,w,h,accent)
    local b=Instance.new("TextButton")
    b.AutoButtonColor=false;b.Text=text or "";b.Size=UDim2.fromOffset(w or 44,h or 44)
    b.BackgroundColor3=accent and T.accent or T.raised;textStyle(b,11,true);corner(b,10);stroke(b,accent and T.accent or T.border,.45);b.Parent=parent
    return b
end
local function iconButton(parent,text,x,y,w,h)
    local b=button(parent,text,w or 42,h or 42,false);b.Position=UDim2.fromOffset(x or 0,y or 0);b.TextSize=15;return b
end
local function safe(cb,...)
    if type(cb)~="function" then return false end
    local ok=pcall(cb,...);return ok
end

local Maid={};Maid.__index=Maid
function Maid.new()return setmetatable({items={}},Maid)end
function Maid:give(x)table.insert(self.items,x);return x end
function Maid:clean()
    for i=#self.items,1,-1 do
        local x=self.items[i]
        if typeof(x)=="RBXScriptConnection" then pcall(function()x:Disconnect()end)
        elseif type(x)=="function" then pcall(x)
        elseif typeof(x)=="Instance" then pcall(function()x:Destroy()end) end
        self.items[i]=nil
    end
end

local function connect(maid,signal,fn)return maid:give(signal:Connect(fn))end

-- Central gesture router: only one drag/seek/slider owns touch at a time.
local InputRouter={};InputRouter.__index=InputRouter
function InputRouter.new(maid)
    local self=setmetatable({owner=nil,inputType=nil},InputRouter)
    connect(maid,UIS.InputChanged,function(i)
        local o=self.owner;if not o then return end
        if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement then
            if o.move then pcall(o.move,i.Position)end
        end
    end)
    connect(maid,UIS.InputEnded,function(i)
        local o=self.owner;if not o then return end
        if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
            self.owner=nil;if o.finish then pcall(o.finish,i.Position)end
        end
    end)
    return self
end
function InputRouter:begin(owner)if self.owner then return false end;self.owner=owner;return true end
function InputRouter:cancel()local o=self.owner;self.owner=nil;if o and o.cancel then pcall(o.cancel)end end

local function bindPressFeedback(maid,b)
    connect(maid,b.InputBegan,function(i)
        if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
            TweenService:Create(b,TweenInfo.new(.08),{BackgroundTransparency=.12}):Play()
        end
    end)
    connect(maid,b.InputEnded,function(i)
        if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
            TweenService:Create(b,TweenInfo.new(.12),{BackgroundTransparency=0}):Play()
        end
    end)
end

local function makeSeek(parent,router,maid,onCommit)
    local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Size=UDim2.new(1,0,0,32);root.Active=true;root.Parent=parent
    local track=Instance.new("Frame");track.AnchorPoint=Vector2.new(0,.5);track.Position=UDim2.new(0,0,.5,0);track.Size=UDim2.new(1,0,0,5);track.BackgroundColor3=Color3.fromRGB(52,58,76);corner(track,99);track.Parent=root
    local fill=Instance.new("Frame");fill.Size=UDim2.fromScale(0,1);fill.BackgroundColor3=T.accent;corner(fill,99);fill.Parent=track
    local knob=Instance.new("Frame");knob.AnchorPoint=Vector2.new(.5,.5);knob.Position=UDim2.fromScale(0,.5);knob.Size=UDim2.fromOffset(14,14);knob.BackgroundColor3=T.text;corner(knob,99);knob.Parent=track
    local bubble=Instance.new("TextLabel");bubble.Visible=false;bubble.AnchorPoint=Vector2.new(.5,1);bubble.Size=UDim2.fromOffset(54,26);bubble.BackgroundColor3=T.raised;bubble.Text="00:00";textStyle(bubble,9,true);corner(bubble,7);stroke(bubble,T.border,.4);bubble.Parent=root
    local obj={root=root,ratio=0,duration=0,dragging=false}
    function obj:set(r,dur)
        if not self.dragging then self.ratio=clamp(r or 0,0,1) end
        self.duration=dur or self.duration
        fill.Size=UDim2.fromScale(self.ratio,1);knob.Position=UDim2.fromScale(self.ratio,.5)
    end
    local function at(pos)
        local a=root.AbsolutePosition.X;local w=math.max(1,root.AbsoluteSize.X)
        local r=clamp((pos.X-a)/w,0,1);obj.ratio=r
        fill.Size=UDim2.fromScale(r,1);knob.Position=UDim2.fromScale(r,.5)
        bubble.Visible=true;bubble.Text=fmt(r*(obj.duration or 0));bubble.Position=UDim2.new(r,0,0,-1)
    end
    connect(maid,root.InputBegan,function(i)
        if i.UserInputType~=Enum.UserInputType.Touch and i.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        if router:begin({move=at,finish=function(pos)at(pos);obj.dragging=false;bubble.Visible=false;if onCommit then onCommit(obj.ratio)end end,cancel=function()obj.dragging=false;bubble.Visible=false end}) then
            obj.dragging=true;at(i.Position)
        end
    end)
    return obj
end

local function makeSlider(parent,router,maid,value,onCommit)
    local obj=makeSeek(parent,router,maid,function(r)if onCommit then onCommit(r)end end)
    obj.ratio=clamp(value or 0,0,1);obj:set(obj.ratio,1);return obj
end

local function makeSpeedControl(parent,maid,callbacks,compact)
    local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Size=UDim2.fromOffset(compact and 154 or 174,compact and 38 or 42);root.Parent=parent
    local minus=button(root,"−",compact and 38 or 42,compact and 38 or 42,false);minus.Position=UDim2.fromOffset(0,0);minus.TextSize=18
    local value=button(root,"1.00×",compact and 70 or 80,compact and 38 or 42,false);value.Position=UDim2.fromOffset(compact and 42 or 47,0);value.BackgroundColor3=T.glass2
    local plus=button(root,"+",compact and 38 or 42,compact and 38 or 42,false);plus.Position=UDim2.fromOffset(compact and 116 or 132,0);plus.TextSize=18
    bindPressFeedback(maid,minus);bindPressFeedback(maid,plus);bindPressFeedback(maid,value)
    connect(maid,minus.Activated,function()safe(callbacks.onSpeedDelta,-1)end)
    connect(maid,plus.Activated,function()safe(callbacks.onSpeedDelta,1)end)
    local popup=Instance.new("Frame");popup.Visible=false;popup.AnchorPoint=Vector2.new(.5,1);popup.Position=UDim2.new(.5,0,0,-7);popup.Size=UDim2.fromOffset(238,90);popup.BackgroundColor3=T.glass2;corner(popup,12);stroke(popup);popup.Parent=root
    local presets={.5,.75,1,1.25,1.5,2}
    for i,v in ipairs(presets) do
        local b=button(popup,string.format(v==1 and "1×" or "%.2g×",v),68,30,false)
        local col=(i-1)%3;local row=math.floor((i-1)/3)
        b.Position=UDim2.fromOffset(7+col*76,7+row*38);b.TextSize=9
        connect(maid,b.Activated,function()popup.Visible=false;safe(callbacks.onSetSpeed,v)end)
    end
    connect(maid,value.Activated,function()popup.Visible=not popup.Visible end)
    return {root=root,value=value,popup=popup,set=function(v)value.Text=string.format("%.2f×",v or 1)end}
end

local function whitePitch(pc)return pc==0 or pc==2 or pc==4 or pc==5 or pc==7 or pc==9 or pc==11 end
local PianoRoll={};PianoRoll.__index=PianoRoll
function PianoRoll.new(parent)
    local self=setmetatable({notes={},low=36,high=96,lookAhead=2.8,pool={},active={},keyFrames={},centers={},widths={}},PianoRoll)
    local root=Instance.new("Frame");root.BackgroundColor3=Color3.fromRGB(10,12,18);root.ClipsDescendants=true;corner(root,12);stroke(root,T.border,.55);root.Parent=parent;self.root=root
    local fall=Instance.new("Frame");fall.BackgroundTransparency=1;fall.Size=UDim2.new(1,0,1,-34);fall.ClipsDescendants=true;fall.Parent=root;self.fall=fall
    local hit=Instance.new("Frame");hit.BorderSizePixel=0;hit.BackgroundColor3=Color3.fromRGB(96,104,132);hit.BackgroundTransparency=.35;hit.AnchorPoint=Vector2.new(0,1);hit.Position=UDim2.new(0,0,1,-34);hit.Size=UDim2.new(1,0,0,1);hit.Parent=root
    local keys=Instance.new("Frame");keys.BackgroundColor3=T.black;keys.AnchorPoint=Vector2.new(0,1);keys.Position=UDim2.fromScale(0,1);keys.Size=UDim2.new(1,0,0,34);keys.ClipsDescendants=true;keys.Parent=root;self.keys=keys
    return self
end
function PianoRoll:setSize(h)self.root.Size=UDim2.new(1,0,0,h)end
function PianoRoll:_layoutKeyboard()
    for _,v in ipairs(self.keys:GetChildren())do v:Destroy()end
    self.keyFrames={};self.centers={};self.widths={}
    local whites={}
    for n=self.low,self.high do if whitePitch(n%12) then whites[#whites+1]=n end end
    local count=math.max(1,#whites)
    local index={};for i,n in ipairs(whites)do index[n]=i end
    for i,n in ipairs(whites)do
        local k=Instance.new("Frame");k.BorderSizePixel=0;k.BackgroundColor3=T.white;k.Position=UDim2.new((i-1)/count,0,0,0);k.Size=UDim2.new(1/count,-1,1,0);k.Parent=self.keys
        self.keyFrames[n]=k;self.centers[n]=(i-.5)/count;self.widths[n]=.86/count
    end
    for n=self.low,self.high do
        if not whitePitch(n%12) then
            local prev=n-1;while prev>=self.low and not whitePitch(prev%12)do prev-=1 end
            local pi=index[prev]
            if pi then
                local center=pi/count
                local k=Instance.new("Frame");k.BorderSizePixel=0;k.AnchorPoint=Vector2.new(.5,0);k.BackgroundColor3=T.black;k.Position=UDim2.new(center,0,0,0);k.Size=UDim2.new(.58/count,0,.62,0);k.ZIndex=3;k.Parent=self.keys
                self.keyFrames[n]=k;self.centers[n]=center;self.widths[n]=.52/count
            end
        end
    end
end
function PianoRoll:setNotes(notes,profile)
    self.notes=notes or {};self.low=profile and profile.lowest or 36;self.high=profile and profile.highest or 96
    table.sort(self.notes,function(a,b)return(a.startTime or 0)<(b.startTime or 0)end);self:_layoutKeyboard()
end
local function lowerBound(notes,t)
    local lo,hi=1,#notes+1
    while lo<hi do local m=math.floor((lo+hi)/2);if m<=#notes and (notes[m].startTime or 0)<t then lo=m+1 else hi=m end end
    return lo
end
function PianoRoll:_frame()
    local f=table.remove(self.pool)
    if not f then f=Instance.new("Frame");f.BorderSizePixel=0;corner(f,3)end
    f.Visible=true;f.Parent=self.fall;return f
end
function PianoRoll:update(pos)
    for _,f in ipairs(self.active)do f.Visible=false;f.Parent=nil;self.pool[#self.pool+1]=f end;table.clear(self.active)
    for n,k in pairs(self.keyFrames)do k.BackgroundColor3=whitePitch(n%12) and T.white or T.black end
    if #self.notes==0 then return end
    local start=math.max(0,pos-.08);local finish=pos+self.lookAhead
    local i=math.max(1,lowerBound(self.notes,start)-4);local shown=0
    while i<=#self.notes and shown<180 do
        local n=self.notes[i];local st=n.startTime or 0;if st>finish then break end
        local pitch=n.mappedNote or n.note;local center=pitch and self.centers[pitch]
        if center and (n.endTime or st)>=start then
            local f=self:_frame();shown+=1
            local w=self.widths[pitch] or .015;local delta=st-pos;local y=1-clamp(delta/self.lookAhead,0,1)
            local dur=math.max(.025,(n.endTime or st+.08)-st);local hh=clamp(dur/self.lookAhead,.035,.34)
            f.AnchorPoint=Vector2.new(.5,1);f.Position=UDim2.new(center,0,y,0);f.Size=UDim2.new(w,0,hh,0)
            local col=n.parts and n.parts.hand=="Left" and T.left or T.right;f.BackgroundColor3=col;self.active[#self.active+1]=f
            if st<=pos and (n.endTime or st)>=pos and self.keyFrames[pitch]then self.keyFrames[pitch].BackgroundColor3=col end
        end
        i+=1
    end
end

local function segmented(parent,maid,items,onSelect)
    local root=Instance.new("Frame");root.BackgroundColor3=T.glass2;root.Size=UDim2.new(1,0,0,38);corner(root,10);stroke(root,T.border,.55);root.Parent=parent
    local buttons={};local selected=nil
    for i,item in ipairs(items)do
        local b=Instance.new("TextButton");b.AutoButtonColor=false;b.BackgroundTransparency=1;b.Text=item.label;b.Size=UDim2.new(1/#items,-4,1,-4);b.Position=UDim2.new((i-1)/#items,2,0,2);textStyle(b,9,true,T.muted);corner(b,8);b.Parent=root;buttons[item.value]=b
        connect(maid,b.Activated,function()selected=item.value;for v,x in pairs(buttons)do x.BackgroundTransparency=v==selected and 0 or 1;x.BackgroundColor3=T.raised;x.TextColor3=v==selected and T.text or T.muted end;if onSelect then onSelect(selected)end end)
    end
    local obj={root=root,buttons=buttons,set=function(v)selected=v;for key,b in pairs(buttons)do b.BackgroundTransparency=key==v and 0 or 1;b.BackgroundColor3=T.raised;b.TextColor3=key==v and T.text or T.muted end end}
    return obj
end

local function sectionTitle(parent,text)
    local l=label(parent,text,11,true);l.Size=UDim2.new(1,0,0,24);l.TextColor3=T.text;return l
end
local function scroll(parent)
    local s=Instance.new("ScrollingFrame");s.BackgroundTransparency=1;s.BorderSizePixel=0;s.Size=UDim2.fromScale(1,1);s.AutomaticCanvasSize=Enum.AutomaticSize.Y;s.CanvasSize=UDim2.new();s.ScrollBarThickness=3;s.ScrollBarImageColor3=T.faint;s.Parent=parent
    local list=Instance.new("UIListLayout");list.Padding=UDim.new(0,8);list.SortOrder=Enum.SortOrder.LayoutOrder;list.Parent=s
    local pad=Instance.new("UIPadding");pad.PaddingBottom=UDim.new(0,8);pad.PaddingRight=UDim.new(0,4);pad.Parent=s
    return s
end

function App.new(callbacks,config)
    callbacks=callbacks or {};config=config or {};config.ui=config.ui or {};config.playback=config.playback or {};config.humanize=config.humanize or {}
    local self=setmetatable({callbacks=callbacks,config=config,maid=Maid.new(),pages={},nav={},songs={},cloudSongs={},position=0,duration=0,playing=false,state="Full",profile=nil,perfNotes={},activeTab=config.ui.activeTab or "Library",librarySource=config.ui.librarySource or "Local"},App)
    self.router=InputRouter.new(self.maid)

    local gui=Instance.new("ScreenGui");gui.Name="MIDIQWERTY_V070_RC";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=false;gui.DisplayOrder=16000;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    local parent=(gethui and gethui()) or CoreGui
    if not pcall(function()gui.Parent=parent end)then gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")end
    self.gui=gui;self.maid:give(gui)

    local full=Instance.new("Frame");full.AnchorPoint=Vector2.new(.5,.5);full.Position=UDim2.fromScale(.5,.5);full.BackgroundColor3=T.bg;full.ClipsDescendants=true;corner(full,16);stroke(full,T.border,.32);full.Parent=gui;self.full=full
    local gradient=Instance.new("UIGradient");gradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(12,14,22)),ColorSequenceKeypoint.new(1,T.bg)});gradient.Rotation=90;gradient.Parent=full
    local fullScale=Instance.new("UIScale");fullScale.Scale=1;fullScale.Parent=full;self.fullScale=fullScale

    local function fullSize()
        local v=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
        local landscape=v.X>=v.Y
        local w=landscape and clamp(v.X*.48,560,700) or clamp(v.X-18,330,460)
        local h=landscape and clamp(v.Y*.72,400,500) or clamp(v.Y*.74,500,680)
        full.Size=UDim2.fromOffset(w,h)
    end
    fullSize();if workspace.CurrentCamera then connect(self.maid,workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),fullSize)end

    local header=Instance.new("Frame");header.BackgroundTransparency=1;header.Size=UDim2.new(1,0,0,50);header.Parent=full;self.header=header
    local mark=Instance.new("Frame");mark.BackgroundColor3=T.accent;mark.Position=UDim2.fromOffset(12,10);mark.Size=UDim2.fromOffset(30,30);corner(mark,9);mark.Parent=header
    local note=label(mark,"♪",17,true);note.TextXAlignment=Enum.TextXAlignment.Center;note.Size=UDim2.fromScale(1,1)
    local title=label(header,"MIDI QWERTY",14,true);title.Position=UDim2.fromOffset(50,7);title.Size=UDim2.fromOffset(180,21)
    local sub=label(header,"game piano autoplayer • v0.7 RC",8,false);sub.Position=UDim2.fromOffset(50,27);sub.Size=UDim2.fromOffset(230,16);sub.TextColor3=T.muted
    local changelog=iconButton(header,"◷",0,7,38,36);changelog.Position=UDim2.new(1,-132,0,7)
    local compactBtn=iconButton(header,"▭",0,7,38,36);compactBtn.Position=UDim2.new(1,-90,0,7)
    local hideBtn=iconButton(header,"—",0,7,38,36);hideBtn.Position=UDim2.new(1,-48,0,7)

    -- Dedicated header drag area. It never overlaps transport or seek controls.
    local drag=Instance.new("Frame");drag.BackgroundTransparency=1;drag.Position=UDim2.fromOffset(0,0);drag.Size=UDim2.new(1,-150,1,0);drag.Active=true;drag.Parent=header
    connect(self.maid,drag.InputBegan,function(i)
        if i.UserInputType~=Enum.UserInputType.Touch and i.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        local start=i.Position;local startPos=full.Position;local moved=false
        self.router:begin({move=function(pos)
            local d=pos-start;if d.Magnitude>7 then moved=true end
            local vp=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
            local px=vp.X*startPos.X.Scale+startPos.X.Offset+d.X;local py=vp.Y*startPos.Y.Scale+startPos.Y.Offset+d.Y
            local hw=full.AbsoluteSize.X/2;local hh=full.AbsoluteSize.Y/2
            px=clamp(px,hw+6,vp.X-hw-6);py=clamp(py,hh+6,vp.Y-hh-6)
            full.Position=UDim2.fromOffset(px,py)
        end,finish=function()safe(callbacks.onUiState,"Full",full.Position)end})
    end)

    local tabs=Instance.new("Frame");tabs.BackgroundColor3=T.glass;tabs.Position=UDim2.fromOffset(10,51);tabs.Size=UDim2.new(1,-20,0,42);corner(tabs,11);stroke(tabs,T.border,.58);tabs.Parent=full
    local tabDefs={{"Library","Músicas"},{"Player","Player"},{"Performance","Performance"},{"Settings","Ajustes"}}
    for i,d in ipairs(tabDefs)do
        local b=Instance.new("TextButton");b.AutoButtonColor=false;b.BackgroundTransparency=1;b.Text=d[2];b.Size=UDim2.new(.25,-4,1,-4);b.Position=UDim2.new((i-1)*.25,2,0,2);textStyle(b,9,true,T.muted);corner(b,8);b.Parent=tabs;self.nav[d[1]]=b
        connect(self.maid,b.Activated,function()self:showPage(d[1])end)
    end
    local content=Instance.new("Frame");content.BackgroundTransparency=1;content.Position=UDim2.fromOffset(12,101);content.Size=UDim2.new(1,-24,1,-113);content.ClipsDescendants=true;content.Parent=full
    for _,d in ipairs(tabDefs)do local p=scroll(content);p.Visible=false;self.pages[d[1]]=p end

    -- Library
    local p=self.pages.Library
    local head=sectionTitle(p,"Biblioteca")
    self.sourceSeg=segmented(p,self.maid,{{label="No aparelho",value="Local"},{label="Na nuvem",value="Cloud"}},function(v)self:setLibrarySource(v)end)
    local search=Instance.new("TextBox");search.ClearTextOnFocus=false;search.PlaceholderText="Pesquisar música";search.Text="";search.BackgroundColor3=T.glass2;search.Size=UDim2.new(1,0,0,42);search.TextXAlignment=Enum.TextXAlignment.Left;textStyle(search,10,false);corner(search,10);stroke(search,T.border,.55);search.Parent=p;self.search=search
    local searchPad=Instance.new("UIPadding");searchPad.PaddingLeft=UDim.new(0,12);searchPad.PaddingRight=UDim.new(0,12);searchPad.Parent=search
    local libTools=Instance.new("Frame");libTools.BackgroundTransparency=1;libTools.Size=UDim2.new(1,0,0,36);libTools.Parent=p
    local refresh=button(libTools,"Atualizar",92,34,false);refresh.Position=UDim2.fromOffset(0,0)
    local fav=button(libTools,"Favoritas",92,34,false);fav.Position=UDim2.fromOffset(98,0)
    self.libraryInfo=label(libTools,"",8,false);self.libraryInfo.Position=UDim2.fromOffset(200,0);self.libraryInfo.Size=UDim2.new(1,-200,1,0);self.libraryInfo.TextXAlignment=Enum.TextXAlignment.Right;self.libraryInfo.TextColor3=T.muted
    self.libraryList=Instance.new("Frame");self.libraryList.BackgroundTransparency=1;self.libraryList.AutomaticSize=Enum.AutomaticSize.Y;self.libraryList.Size=UDim2.new(1,0,0,0);self.libraryList.Parent=p;local libList=Instance.new("UIListLayout");libList.Padding=UDim.new(0,6);libList.Parent=self.libraryList
    connect(self.maid,search:GetPropertyChangedSignal("Text"),function()if self.librarySource=="Local" then self:_renderLibrary()end end)
    connect(self.maid,refresh.Activated,function()if self.librarySource=="Cloud" then safe(callbacks.onCloudSearch,search.Text)else safe(callbacks.onRefresh)end end)
    connect(self.maid,fav.Activated,function()config.ui.songFilter=config.ui.songFilter=="Favorites" and "All" or "Favorites";fav.Text=config.ui.songFilter=="Favorites" and "Todas" or "Favoritas";self:_renderLibrary()end)

    -- Player
    p=self.pages.Player
    self.songName=sectionTitle(p,"Nenhuma música selecionada");self.songName.TextTruncate=Enum.TextTruncate.AtEnd
    self.songMeta=label(p,"Escolha um MIDI na Biblioteca.",8,false);self.songMeta.TextColor3=T.muted
    self.roll=PianoRoll.new(p);self.roll:setSize(156)
    local times=Instance.new("Frame");times.BackgroundTransparency=1;times.Size=UDim2.new(1,0,0,17);times.Parent=p
    self.timeNow=label(times,"00:00",8,false);self.timeNow.Size=UDim2.new(.5,0,1,0);self.timeNow.TextColor3=T.muted
    self.timeEnd=label(times,"00:00",8,false);self.timeEnd.Position=UDim2.fromScale(.5,0);self.timeEnd.Size=UDim2.new(.5,0,1,0);self.timeEnd.TextXAlignment=Enum.TextXAlignment.Right;self.timeEnd.TextColor3=T.muted
    self.seek=makeSeek(p,self.router,self.maid,function(r)if self.duration>0 then safe(callbacks.onSeekAbsolute,r*self.duration)end end)
    local transport=Instance.new("Frame");transport.BackgroundTransparency=1;transport.Size=UDim2.new(1,0,0,56);transport.Parent=p
    local prev=button(transport,"‹",44,44,false);prev.Position=UDim2.new(.5,-92,0,6);prev.TextSize=24
    self.play=button(transport,"▶",56,56,true);self.play.Position=UDim2.new(.5,-28,0,0);self.play.TextSize=19
    local nextB=button(transport,"›",44,44,false);nextB.Position=UDim2.new(.5,48,0,6);nextB.TextSize=24
    connect(self.maid,prev.Activated,function()safe(callbacks.onPrev)end);connect(self.maid,self.play.Activated,function()safe(callbacks.onPlayPause)end);connect(self.maid,nextB.Activated,function()safe(callbacks.onNext)end)
    local quick=Instance.new("Frame");quick.BackgroundTransparency=1;quick.Size=UDim2.new(1,0,0,42);quick.Parent=p
    self.speedFull=makeSpeedControl(quick,self.maid,callbacks,false);self.speedFull.root.Position=UDim2.fromOffset(0,0)
    self.modeFull=segmented(quick,self.maid,{{label="Ambas",value="Both"},{label="Esq.",value="Left"},{label="Dir.",value="Right"}},function(v)safe(callbacks.onMode,v)end);self.modeFull.root.Size=UDim2.new(1,-190,0,42);self.modeFull.root.Position=UDim2.fromOffset(190,0)
    self.live=label(p,"",8,false);self.live.TextColor3=T.muted

    -- Performance
    p=self.pages.Performance
    sectionTitle(p,"Interpretação")
    self.presetSeg=segmented(p,self.maid,{{label="Exato",value="Exact"},{label="Natural",value="Natural"},{label="Pianista",value="Pianist"},{label="Expr.",value="Expressive"}},function(v)safe(callbacks.onPreset,v)end)
    local strengthTitle=label(p,"Intensidade",9,true);strengthTitle.TextColor3=T.muted
    self.humanSlider=makeSlider(p,self.router,self.maid,config.humanize.strength or .72,function(r)safe(callbacks.onHumanStrength,r)end)
    self.humanStats=label(p,"Aguardando uma performance...",8,false);self.humanStats.TextWrapped=true;self.humanStats.Size=UDim2.new(1,0,0,40);self.humanStats.TextColor3=T.muted
    local reroll=button(p,"Nova interpretação",170,38,true);connect(self.maid,reroll.Activated,function()safe(callbacks.onNewPerformance)end)
    sectionTitle(p,"Partes")
    self.modePerf=segmented(p,self.maid,{{label="Ambas",value="Both"},{label="Mão esquerda",value="Left"},{label="Mão direita",value="Right"}},function(v)safe(callbacks.onMode,v)end)
    self.splitLabel=label(p,"Separação automática: aguardando MIDI",8,false);self.splitLabel.TextColor3=T.muted
    self.trackBox=Instance.new("Frame");self.trackBox.BackgroundTransparency=1;self.trackBox.AutomaticSize=Enum.AutomaticSize.Y;self.trackBox.Size=UDim2.new(1,0,0,0);self.trackBox.Parent=p;local tl=Instance.new("UIListLayout");tl.Padding=UDim.new(0,5);tl.Parent=self.trackBox

    -- Settings
    p=self.pages.Settings
    sectionTitle(p,"Reprodução")
    local transRow=Instance.new("Frame");transRow.BackgroundColor3=T.glass2;transRow.Size=UDim2.new(1,0,0,44);corner(transRow,10);stroke(transRow,T.border,.55);transRow.Parent=p
    self.transpose=label(transRow,"Transposição  0",9,true);self.transpose.Position=UDim2.fromOffset(12,0);self.transpose.Size=UDim2.new(1,-112,1,0)
    local tm=button(transRow,"−",38,34,false);tm.Position=UDim2.new(1,-86,0,5);local tp=button(transRow,"+",38,34,false);tp.Position=UDim2.new(1,-43,0,5)
    connect(self.maid,tm.Activated,function()safe(callbacks.onTransposeDelta,-1)end);connect(self.maid,tp.Activated,function()safe(callbacks.onTransposeDelta,1)end)
    local optRow=Instance.new("Frame");optRow.BackgroundTransparency=1;optRow.Size=UDim2.new(1,0,0,38);optRow.Parent=p
    self.rangeBtn=button(optRow,"Faixa: Smart",132,36,false);self.rangeBtn.Position=UDim2.fromOffset(0,0)
    self.quantBtn=button(optRow,"Quant: Off",110,36,false);self.quantBtn.Position=UDim2.fromOffset(138,0)
    self.loopBtn=button(optRow,"Loop: Off",100,36,false);self.loopBtn.Position=UDim2.fromOffset(254,0)
    connect(self.maid,self.rangeBtn.Activated,function()safe(callbacks.onCycleRange)end);connect(self.maid,self.quantBtn.Activated,function()safe(callbacks.onCycleQuantization)end);connect(self.maid,self.loopBtn.Activated,function()safe(callbacks.onToggleLoopSong)end)
    sectionTitle(p,"Toque / QWERTY")
    self.holdLabel=label(p,"Duração MIDI",8,false);self.holdLabel.TextColor3=T.muted
    local hold=Instance.new("Frame");hold.BackgroundTransparency=1;hold.Size=UDim2.new(1,0,0,36);hold.Parent=p
    local shorter=button(hold,"Mais curto",106,34,false);local longer=button(hold,"Mais longo",106,34,false);longer.Position=UDim2.fromOffset(112,0);local panic=button(hold,"Soltar tudo",106,34,false);panic.Position=UDim2.fromOffset(224,0)
    connect(self.maid,shorter.Activated,function()safe(callbacks.onExpressionScaleDelta,-.05)end);connect(self.maid,longer.Activated,function()safe(callbacks.onExpressionScaleDelta,.05)end);connect(self.maid,panic.Activated,function()safe(callbacks.onPanic)end)
    self.profileLabel=label(p,"Perfil: carregando...",8,false);self.profileLabel.TextColor3=T.muted
    self.backendLabel=label(p,"Backend: verificando...",8,false);self.backendLabel.TextColor3=T.muted
    self.diagLabel=label(p,"",8,false);self.diagLabel.TextWrapped=true;self.diagLabel.Size=UDim2.new(1,0,0,46);self.diagLabel.TextColor3=T.faint

    -- Compact player
    local compact=Instance.new("Frame");compact.AnchorPoint=Vector2.new(.5,.5);compact.Position=UDim2.fromScale(.5,.5);compact.Size=UDim2.fromOffset(590,276);compact.BackgroundColor3=T.bg;compact.Visible=false;compact.ClipsDescendants=true;corner(compact,15);stroke(compact,T.border,.3);compact.Parent=gui;self.compact=compact
    local ch=Instance.new("Frame");ch.BackgroundTransparency=1;ch.Size=UDim2.new(1,0,0,44);ch.Parent=compact
    self.compactTitle=label(ch,"Nenhuma música",11,true);self.compactTitle.Position=UDim2.fromOffset(14,0);self.compactTitle.Size=UDim2.new(1,-150,1,0);self.compactTitle.TextTruncate=Enum.TextTruncate.AtEnd
    local expand=iconButton(ch,"□",0,4,36,36);expand.Position=UDim2.new(1,-84,0,4);local cmini=iconButton(ch,"—",0,4,36,36);cmini.Position=UDim2.new(1,-44,0,4)
    local cdrag=Instance.new("Frame");cdrag.BackgroundTransparency=1;cdrag.Size=UDim2.new(1,-100,1,0);cdrag.Active=true;cdrag.Parent=ch
    connect(self.maid,cdrag.InputBegan,function(i)
        if i.UserInputType~=Enum.UserInputType.Touch and i.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        local st=i.Position;local sp=compact.Position
        self.router:begin({move=function(pos)local d=pos-st;compact.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)end,finish=function()safe(callbacks.onUiState,"Compact",compact.Position)end})
    end)
    self.compactRoll=PianoRoll.new(compact);self.compactRoll.root.Position=UDim2.fromOffset(12,48);self.compactRoll.root.Size=UDim2.new(1,-24,0,106)
    local ctime=label(compact,"00:00 / 00:00",8,false);ctime.Position=UDim2.fromOffset(12,157);ctime.Size=UDim2.new(1,-24,0,17);ctime.TextColor3=T.muted;self.compactTime=ctime
    local cseekHolder=Instance.new("Frame");cseekHolder.BackgroundTransparency=1;cseekHolder.Position=UDim2.fromOffset(12,174);cseekHolder.Size=UDim2.new(1,-24,0,32);cseekHolder.Parent=compact
    self.compactSeek=makeSeek(cseekHolder,self.router,self.maid,function(r)if self.duration>0 then safe(callbacks.onSeekAbsolute,r*self.duration)end end)
    local ccontrols=Instance.new("Frame");ccontrols.BackgroundTransparency=1;ccontrols.Position=UDim2.fromOffset(12,211);ccontrols.Size=UDim2.new(1,-24,0,46);ccontrols.Parent=compact
    self.compactPlay=button(ccontrols,"▶",46,46,true);self.compactPlay.Position=UDim2.fromOffset(0,0);self.compactPlay.TextSize=16;connect(self.maid,self.compactPlay.Activated,function()safe(callbacks.onPlayPause)end)
    self.speedCompact=makeSpeedControl(ccontrols,self.maid,callbacks,true);self.speedCompact.root.Position=UDim2.fromOffset(58,4)
    self.modeCompact=segmented(ccontrols,self.maid,{{label="Ambas",value="Both"},{label="E",value="Left"},{label="D",value="Right"}},function(v)safe(callbacks.onMode,v)end);self.modeCompact.root.Position=UDim2.fromOffset(224,4);self.modeCompact.root.Size=UDim2.new(1,-224,0,38)
    connect(self.maid,expand.Activated,function()self:setState("Full")end);connect(self.maid,cmini.Activated,function()self:setState("Mini")end)

    -- Mini player
    local mini=Instance.new("Frame");mini.AnchorPoint=Vector2.new(.5,1);mini.Position=UDim2.fromScale(.5,.96);mini.Size=UDim2.fromOffset(460,118);mini.BackgroundColor3=T.bg;mini.Visible=false;corner(mini,15);stroke(mini,T.border,.3);mini.Parent=gui;self.mini=mini
    local handle=Instance.new("Frame");handle.BackgroundColor3=T.faint;handle.AnchorPoint=Vector2.new(.5,0);handle.Position=UDim2.new(.5,0,0,6);handle.Size=UDim2.fromOffset(42,4);corner(handle,99);handle.Active=true;handle.Parent=mini
    connect(self.maid,handle.InputBegan,function(i)
        if i.UserInputType~=Enum.UserInputType.Touch and i.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        local st=i.Position;local sp=mini.Position
        self.router:begin({move=function(pos)local d=pos-st;mini.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)end,finish=function()safe(callbacks.onUiState,"Mini",mini.Position)end})
    end)
    self.miniTitle=label(mini,"Nenhuma música",10,true);self.miniTitle.Position=UDim2.fromOffset(12,14);self.miniTitle.Size=UDim2.new(1,-132,0,20);self.miniTitle.TextTruncate=Enum.TextTruncate.AtEnd
    self.miniTime=label(mini,"00:00 / 00:00",8,false);self.miniTime.Position=UDim2.fromOffset(12,34);self.miniTime.Size=UDim2.new(1,-132,0,17);self.miniTime.TextColor3=T.muted
    self.miniPlay=button(mini,"▶",42,42,true);self.miniPlay.Position=UDim2.new(1,-92,0,16);self.miniPlay.TextSize=15;connect(self.maid,self.miniPlay.Activated,function()safe(callbacks.onPlayPause)end)
    local mexpand=button(mini,"□",34,34,false);mexpand.Position=UDim2.new(1,-44,0,20);connect(self.maid,mexpand.Activated,function()self:setState("Compact")end)
    local mseekHolder=Instance.new("Frame");mseekHolder.BackgroundTransparency=1;mseekHolder.Position=UDim2.fromOffset(12,52);mseekHolder.Size=UDim2.new(1,-24,0,28);mseekHolder.Parent=mini
    self.miniSeek=makeSeek(mseekHolder,self.router,self.maid,function(r)if self.duration>0 then safe(callbacks.onSeekAbsolute,r*self.duration)end end)
    self.speedMini=makeSpeedControl(mini,self.maid,callbacks,true);self.speedMini.root.Position=UDim2.fromOffset(12,78)

    -- Hidden bubble
    local bubble=button(gui,"♪",54,54,true);bubble.Position=UDim2.fromScale(config.ui.floatingX or .86,config.ui.floatingY or .72);bubble.Visible=false;bubble.TextSize=20;bubble.Parent=gui;self.bubble=bubble
    local bubbleStart,bubblePos,moved
    connect(self.maid,bubble.InputBegan,function(i)
        if i.UserInputType~=Enum.UserInputType.Touch and i.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        bubbleStart=i.Position;bubblePos=bubble.Position;moved=false
        self.router:begin({move=function(pos)local d=pos-bubbleStart;if d.Magnitude>8 then moved=true end;bubble.Position=UDim2.new(bubblePos.X.Scale,bubblePos.X.Offset+d.X,bubblePos.Y.Scale,bubblePos.Y.Offset+d.Y)end,finish=function()if moved then safe(callbacks.onUiState,"Hidden",bubble.Position)else self:setState(config.ui.restoreState or "Compact")end end})
    end)

    connect(self.maid,compactBtn.Activated,function()self:setState("Compact")end)
    connect(self.maid,hideBtn.Activated,function()self:setState("Hidden")end)
    connect(self.maid,changelog.Activated,function()self:showChangelog()end)

    self:showPage(self.activeTab);self:setLibrarySource(self.librarySource);self:setState("Full")
    return self
end

function App:_renderLibrary()
    for _,v in ipairs(self.libraryList:GetChildren())do if not v:IsA("UIListLayout")then v:Destroy()end end
    local source=self.librarySource=="Cloud" and self.cloudSongs or self.songs
    local q=string.lower(self.search.Text or "");local filtered={}
    for _,s in ipairs(source or {})do
        local ok=q=="" or string.find(string.lower(s.name or s.path or ""),q,1,true)
        if self.librarySource=="Local" and self.config.ui.songFilter=="Favorites"then ok=ok and s.favorite==true end
        if ok then filtered[#filtered+1]=s end
    end
    if #filtered==0 then
        local empty=Instance.new("Frame");empty.BackgroundColor3=T.glass2;empty.Size=UDim2.new(1,0,0,108);corner(empty,12);stroke(empty,T.border,.6);empty.Parent=self.libraryList
        local icon=label(empty,"♫",28,true);icon.TextXAlignment=Enum.TextXAlignment.Center;icon.Position=UDim2.fromOffset(0,12);icon.Size=UDim2.new(1,0,0,34);icon.TextColor3=T.accent
        local t=label(empty,self.librarySource=="Cloud" and "Nenhum resultado da nuvem" or "Nenhum MIDI encontrado",11,true);t.TextXAlignment=Enum.TextXAlignment.Center;t.Position=UDim2.fromOffset(0,48);t.Size=UDim2.new(1,0,0,22)
        local s=label(empty,self.librarySource=="Cloud" and "Use Atualizar para consultar o provider." or "Adicione .mid em Delta/Workspace/MIDI/",8,false);s.TextXAlignment=Enum.TextXAlignment.Center;s.Position=UDim2.fromOffset(0,72);s.Size=UDim2.new(1,0,0,20);s.TextColor3=T.muted
        return
    end
    for _,song in ipairs(filtered)do
        local row=Instance.new("Frame");row.BackgroundColor3=T.glass2;row.Size=UDim2.new(1,0,0,54);corner(row,10);stroke(row,T.border,.58);row.Parent=self.libraryList
        local n=label(row,song.name or "Música",10,true);n.Position=UDim2.fromOffset(10,5);n.Size=UDim2.new(1,-118,0,22);n.TextTruncate=Enum.TextTruncate.AtEnd
        local meta=label(row,self.librarySource=="Cloud" and ((song.singer and song.singer~="" and song.singer.." • " or "")..tostring(song.downloads or 0).." downloads") or (song.favorite and "★ Favorita" or "MIDI local"),8,false);meta.Position=UDim2.fromOffset(10,28);meta.Size=UDim2.new(1,-118,0,18);meta.TextColor3=T.muted
        local act=button(row,self.librarySource=="Cloud" and "Baixar" or "Abrir",72,34,self.librarySource=="Local");act.Position=UDim2.new(1,-82,0,10);act.TextSize=9
        connect(self.maid,act.Activated,function()if self.librarySource=="Cloud"then safe(self.callbacks.onCloudDownload,song)else safe(self.callbacks.onSelectSong,song);self:showPage("Player")end end)
        if self.librarySource=="Local"then local star=button(row,song.favorite and "★" or "☆",30,30,false);star.Position=UDim2.new(1,-116,0,12);connect(self.maid,star.Activated,function()safe(self.callbacks.onToggleFavorite,song)end)end
    end
end

function App:showPage(name)
    if not self.pages[name]then return end
    local old=self.activeTab;self.activeTab=name;self.config.ui.activeTab=name
    for n,p in pairs(self.pages)do p.Visible=n==name end
    for n,b in pairs(self.nav)do
        b.BackgroundTransparency=n==name and 0 or 1;b.BackgroundColor3=T.raised;b.TextColor3=n==name and T.text or T.muted
    end
    local p=self.pages[name];p.Position=UDim2.fromOffset(8,0);TweenService:Create(p,TweenInfo.new(.16,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=UDim2.fromOffset(0,0)}):Play()
    safe(self.callbacks.onUiState,self.state,nil)
end
function App:setLibrarySource(v)
    self.librarySource=v=="Cloud" and "Cloud" or "Local";self.config.ui.librarySource=self.librarySource;self.sourceSeg:set(self.librarySource);self.search.PlaceholderText=self.librarySource=="Cloud" and "Pesquisar na nuvem" or "Pesquisar no aparelho";self:_renderLibrary();safe(self.callbacks.onUiState,self.state,nil)
end
function App:setSongs(songs,status)self.songs=songs or {};self.libraryInfo.Text=status or (#self.songs.." MIDI(s)");if self.librarySource=="Local"then self:_renderLibrary()end end
function App:setCloudSongs(songs,status)self.cloudSongs=songs or {};self.libraryInfo.Text=status or (#self.cloudSongs.." resultado(s)");if self.librarySource=="Cloud"then self:_renderLibrary()end end
function App:setCloudStatus(msg)self.libraryInfo.Text=tostring(msg or "")end
function App:setSong(item,a,mapStats,perfStats)
    local name=item and item.name or "Nenhuma música";self.songName.Text=name;self.compactTitle.Text=name;self.miniTitle.Text=name
    local bpm=a and a.bpmMin and math.floor(a.bpmMin+.5)or nil;self.songMeta.Text=string.format("%s notas • %s • %s",tostring(a and a.noteCount or 0),bpm and bpm.." BPM" or "tempo MIDI",a and fmt(a.duration)or "00:00")
    if perfStats then self.humanStats.Text=string.format("%s • Δ %.1f ms • σ %.1f ms • mãos %.1f ms • acordes %.1f ms • tempo %.1f%%…%.1f%%",tostring(perfStats.preset or "Custom"),perfStats.averageTimingMs or 0,perfStats.stdTimingMs or 0,perfStats.averageHandDifferenceMs or 0,perfStats.averageChordSpreadMs or 0,perfStats.localTempoMin or 0,perfStats.localTempoMax or 0)end
    if mapStats then self.diagLabel.Text=string.format("Cobertura %.1f%% • adaptadas %d • descartadas %d • colisões %d",(mapStats.coverage or 0)*100,mapStats.adapted or 0,mapStats.dropped or 0,mapStats.collisions or 0)end
end
function App:setPerformance(notes,profile,perfStats)
    self.perfNotes=notes or {};self.profile=profile or self.profile;self.roll:setNotes(self.perfNotes,self.profile);self.compactRoll:setNotes(self.perfNotes,self.profile)
    if perfStats then self.humanStats.Text=string.format("%s • Δ %.1f ms • σ %.1f ms • mãos %.1f ms • acordes %.1f ms",tostring(perfStats.preset or "Custom"),perfStats.averageTimingMs or 0,perfStats.stdTimingMs or 0,perfStats.averageHandDifferenceMs or 0,perfStats.averageChordSpreadMs or 0)end
end
function App:setProgress(pos,dur,stats,playing)
    self.position=pos or 0;self.duration=dur or self.duration or 0;self.playing=playing==true;local r=self.duration>0 and self.position/self.duration or 0
    self.seek:set(r,self.duration);self.compactSeek:set(r,self.duration);self.miniSeek:set(r,self.duration)
    self.timeNow.Text=fmt(self.position);self.timeEnd.Text=fmt(self.duration);self.compactTime.Text=fmt(self.position).." / "..fmt(self.duration);self.miniTime.Text=fmt(self.position).." / "..fmt(self.duration)
    local glyph=self.playing and "Ⅱ" or "▶";self.play.Text=glyph;self.compactPlay.Text=glyph;self.miniPlay.Text=glyph
    self.roll:update(self.position);self.compactRoll:update(self.position)
    if stats then local avg=stats.processed>0 and(stats.driftSumMs or 0)/stats.processed or 0;self.diagLabel.Text=string.format("Eventos %d • atrasados %d • pulados %d • drift %.1f ms • pico %.1f ms",stats.processed or 0,stats.late or 0,stats.skipped or 0,avg,stats.driftPeakMs or 0)end
end
function App:setSpeed(v)self.speedFull.set(v);self.speedCompact.set(v);self.speedMini.set(v)end
function App:setMode(v)self.modeFull:set(v);self.modePerf:set(v);self.modeCompact:set(v)end
function App:setHumanPreset(name,strength)self.presetSeg:set(name);self.humanSlider:set(strength or 0,1)end
function App:setHumanStrength(v)self.humanSlider:set(v or 0,1)end
function App:setTranspose(v)self.transpose.Text="Transposição  "..tostring(v or 0)end
function App:setRange(v)self.rangeBtn.Text="Faixa: "..tostring(v or "Smart")end
function App:setQuantization(v)self.quantBtn.Text="Quant: "..tostring(v or "Off")end
function App:setMaxKeys(v)end
function App:setLoopSong(v)self.loopBtn.Text="Loop: "..(v and "On" or "Off");self.loopBtn.BackgroundColor3=v and T.accentSoft or T.raised end
function App:setExpression(e)e=e or {};self.holdLabel.Text=string.format("Duração %s • %d–%d ms • escala %d%%",e.durationMode or "MIDI",e.minHoldMs or 14,e.maxHoldMs or 1400,math.floor((e.holdScale or .96)*100+.5))end
function App:setBackend(v)self.backendLabel.Text="Backend: "..tostring(v or "indisponível");self.backendLabel.TextColor3=tostring(v):find("Unavailable",1,true)and T.danger or T.muted end
function App:setProfile(p)self.profile=p;self.profileLabel.Text="Perfil: "..tostring(p and p.name or "não carregado");self.roll:setNotes(self.perfNotes,p);self.compactRoll:setNotes(self.perfNotes,p)end
function App:setAnalysis(a,enabledTracks,enabledChannels)
    self.splitLabel.Text=string.format("Separação: MIDI %s • confiança %d%%",tostring(a and a.handSplit or "-"),math.floor((a and a.handConfidence or 0)*100+.5))
    for _,v in ipairs(self.trackBox:GetChildren())do if not v:IsA("UIListLayout")then v:Destroy()end end
    if not a or not a.tracks then return end
    local count=0
    for i,t in ipairs(a.tracks)do if t and(t.noteCount or 0)>0 and count<10 then count+=1;local on=enabledTracks[i]~=false;local b=button(self.trackBox,(on and "✓ " or "○ ")..(t.name or("Track "..i)).." • "..tostring(t.noteCount or 0),self.trackBox.AbsoluteSize.X>0 and self.trackBox.AbsoluteSize.X or 350,32,false);b.Size=UDim2.new(1,0,0,32);b.TextXAlignment=Enum.TextXAlignment.Left;connect(self.maid,b.Activated,function()on=not on;b.Text=(on and "✓ " or "○ ")..(t.name or("Track "..i)).." • "..tostring(t.noteCount or 0);safe(self.callbacks.onToggleTrack,i,on)end)end end
end
function App:setFavorite(v)if self.song then self.song.favorite=v end;self:_renderLibrary()end
function App:setActiveNotes(tokens)self.live.Text=#(tokens or {})>0 and("Teclas: "..table.concat(tokens," "))or ""end
function App:setMessage(msg)self:toast(tostring(msg or ""),false)end
function App:setError(msg)self:toast(tostring(msg or "Erro"),true)end
function App:toast(msg,isError)
    if self.toastFrame then self.toastFrame:Destroy()end
    local f=Instance.new("TextLabel");f.AnchorPoint=Vector2.new(.5,1);f.Position=UDim2.fromScale(.5,.94);f.Size=UDim2.fromOffset(320,42);f.BackgroundColor3=isError and T.danger or T.raised;f.Text=msg;textStyle(f,9,true);corner(f,11);stroke(f,T.border,.5);f.Parent=self.gui;self.toastFrame=f
    f.TextTransparency=1;f.BackgroundTransparency=1;TweenService:Create(f,TweenInfo.new(.16),{TextTransparency=0,BackgroundTransparency=0}):Play();task.delay(2.4,function()if f.Parent then TweenService:Create(f,TweenInfo.new(.18),{TextTransparency=1,BackgroundTransparency=1}):Play();task.delay(.2,function()if f.Parent then f:Destroy()end end)end end)
end
function App:showChangelog()
    if self.changelogModal and self.changelogModal.Parent then self.changelogModal.Visible=true;return end
    local shade=Instance.new("Frame");shade.BackgroundColor3=Color3.new(0,0,0);shade.BackgroundTransparency=.30;shade.Size=UDim2.fromScale(1,1);shade.Parent=self.gui;self.changelogModal=shade
    local card=Instance.new("Frame");card.AnchorPoint=Vector2.new(.5,.5);card.Position=UDim2.fromScale(.5,.5);card.Size=UDim2.fromOffset(380,292);card.BackgroundColor3=T.glass;corner(card,15);stroke(card,T.border,.3);card.Parent=shade
    local title=label(card,"Novidades • v0.7 RC",14,true);title.Position=UDim2.fromOffset(16,12);title.Size=UDim2.new(1,-64,0,26)
    local close=button(card,"×",36,36,false);close.Position=UDim2.new(1,-48,0,8);close.TextSize=17;connect(self.maid,close.Activated,function()shade.Visible=false;safe(self.callbacks.onChangelogSeen,"0.7")end)
    local body=Instance.new("TextLabel");body.BackgroundTransparency=1;body.Position=UDim2.fromOffset(16,50);body.Size=UDim2.new(1,-32,1,-64);body.TextXAlignment=Enum.TextXAlignment.Left;body.TextYAlignment=Enum.TextYAlignment.Top;body.TextWrapped=true;textStyle(body,9,false,T.muted);body.Text="• UI Glass/Dark refeita do zero, sem herdar as versões 0.6.\n\n• Full, Compact, Mini e Hidden têm funções próprias.\n\n• Velocidade agora usa − / valor / + em Full, Compact e Mini.\n\n• Seekbar aceita tap e arraste com preview de tempo.\n\n• Humanizer ganhou curvas de tempo local, frase, mãos, motivos e acordes.\n\n• Duração de teclas longas deixa de ser cortada em 260 ms e passa a acompanhar a velocidade.";body.Parent=card
end
function App:setState(state)
    if state~="Full"and state~="Compact"and state~="Mini"and state~="Hidden"then state="Full"end
    self.state=state;if state~="Hidden"then self.config.ui.restoreState=state end
    self.full.Visible=state=="Full";self.compact.Visible=state=="Compact";self.mini.Visible=state=="Mini";self.bubble.Visible=state=="Hidden"
    if state=="Full"then self.fullScale.Scale=.97;TweenService:Create(self.fullScale,TweenInfo.new(.17,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Scale=1}):Play()
    elseif state=="Compact"then local sc=self.compact:FindFirstChildOfClass("UIScale")or Instance.new("UIScale",self.compact);sc.Scale=.96;TweenService:Create(sc,TweenInfo.new(.17,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Scale=1}):Play()end
    safe(self.callbacks.onUiState,state,nil)
end
function App:destroy()self.router:cancel();self.maid:clean()end
return App
