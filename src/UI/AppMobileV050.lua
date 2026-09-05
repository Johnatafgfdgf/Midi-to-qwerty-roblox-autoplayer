local BASE_COMMIT="1bde113aaf682cbe7fc3d9c69785de1448a6709f"
local BASE_URL="https://raw.githubusercontent.com/Johnatafgfdgf/Midi-to-qwerty-roblox-autoplayer/"..BASE_COMMIT.."/src/UI/AppMobileV043.lua"

local ok,source=pcall(function()return game:HttpGet(BASE_URL)end)
assert(ok and type(source)=="string","[MIDIQWERTY] Failed to load v0.4.3 UI base")
local chunk,err=loadstring(source,"=MIDIQWERTY/UI/AppMobileV043.base")
assert(chunk,"[MIDIQWERTY] v0.4.3 UI compile error: "..tostring(err))
local Base=chunk()
assert(type(Base)=="table" and type(Base.new)=="function","[MIDIQWERTY] Invalid UI base")

local App={}
setmetatable(App,{__index=Base})

local C={
    card=Color3.fromRGB(28,32,46),card2=Color3.fromRGB(39,44,61),accent=Color3.fromRGB(122,88,255),
    green=Color3.fromRGB(72,210,178),text=Color3.fromRGB(246,248,252),muted=Color3.fromRGB(155,164,185),
}

local function round(o,r)local x=Instance.new("UICorner");x.CornerRadius=UDim.new(0,r or 8);x.Parent=o end
local function stroke(o)local x=Instance.new("UIStroke");x.Color=C.card2;x.Thickness=1;x.Transparency=.35;x.Parent=o end
local function font(o,size,bold,col)o.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham;o.TextSize=size or 10;o.TextColor3=col or C.text end
local function label(parent,text,h,bold)
    local x=Instance.new("TextLabel");x.BackgroundTransparency=1;x.Text=text or "";x.TextXAlignment=Enum.TextXAlignment.Left;x.TextYAlignment=Enum.TextYAlignment.Center
    x.Size=UDim2.new(1,0,0,h or 22);font(x,bold and 12 or 9,bold);x.Parent=parent;return x
end
local function button(parent,text,h)
    local x=Instance.new("TextButton");x.AutoButtonColor=false;x.BackgroundColor3=C.card;x.Text=text or "";x.Size=UDim2.new(1,0,0,h or 36);font(x,10,true);round(x,8);stroke(x);x.Parent=parent;return x
end
local function row(parent,defs,h,gap)
    gap=gap or 6;h=h or 36
    local r=Instance.new("Frame");r.BackgroundTransparency=1;r.Size=UDim2.new(1,0,0,h);r.Parent=parent
    local n=#defs;local out={}
    for i,d in ipairs(defs)do
        local b=button(r,d.text,h);b.Position=UDim2.new((i-1)/n,gap/2,0,0);b.Size=UDim2.new(1/n,-gap,1,0)
        if d.click then b.Activated:Connect(d.click)end
        out[i]=b
    end
    return out,r
end
local function safe(cb,...)
    if type(cb)=="function" then local ok=pcall(cb,...);return ok end
end
local function clamp(v,a,b)return math.max(a,math.min(b,v))end

function App.new(callbacks,config)
    callbacks=callbacks or {};config=config or {};config.humanize=config.humanize or {};config.playback=config.playback or {};config.ui=config.ui or {}
    local app=Base.new(callbacks,config)
    assert(app and app.pages and app.gui,"[MIDIQWERTY] Base UI failed")

    app.gui.Name="MIDIQWERTY_V050_DODO_LAB"
    for _,d in ipairs(app.gui:GetDescendants())do
        if d:IsA("TextLabel") and d.Text=="v0.4.3 POLISHED" then
            d.Text="v0.5.0 HUMAN LAB";d.Size=UDim2.fromOffset(128,22)
        elseif d:IsA("TextLabel") and d.Text=="0.4.3" then
            d.Text="0.5.0"
        end
    end

    local human=config.humanize
    human.swingMs=human.swingMs or .5
    human.rubato=human.rubato or .03
    human.handIndependence=human.handIndependence or .18
    human.phraseExpression=human.phraseExpression or .18
    human.latencyMs=human.latencyMs or 0
    human.expressionCurve=human.expressionCurve or "Soft"
    human.seedMode=human.seedMode or "Auto"
    human.fixedSeed=human.fixedSeed or 12345
    config.playback.lateMode=config.playback.lateMode or "CatchUp"
    config.playback.chordWindowMs=config.playback.chordWindowMs or 8
    config.playback.collisionWindowMs=config.playback.collisionWindowMs or 2.5
    config.ui.songSort=config.ui.songSort or "A-Z"

    local function rebuildHuman()
        safe(callbacks.onHumanDelta,0)
    end
    local function rebuildPlayback()
        safe(callbacks.onMode,config.playback.mode or "Both")
    end
    local function persistUi()
        safe(callbacks.onUiState,app.state or "Full",nil)
    end

    -- SONG LIBRARY: Dodo-inspired local sorting without an online dependency.
    local originalRender=app._renderSongs
    local sortModes={"A-Z","Z-A","Recentes","Favoritos"}
    local sortIndex=1
    for i,v in ipairs(sortModes)do if v==config.ui.songSort then sortIndex=i break end end
    app._renderSongs=function(self)
        local list=self.allSongs or {}
        table.sort(list,function(a,b)
            local mode=config.ui.songSort or "A-Z"
            if mode=="Z-A" then return string.lower(a.name or a.path or "")>string.lower(b.name or b.path or "") end
            if mode=="Recentes" then return (a.recentRank or 999999)<(b.recentRank or 999999) end
            if mode=="Favoritos" then
                if (a.favorite==true)~=(b.favorite==true) then return a.favorite==true end
            end
            return string.lower(a.name or a.path or "")<string.lower(b.name or b.path or "")
        end)
        return originalRender(self)
    end
    do
        local p=app.pages.Songs
        label(p,"Organização",18,true)
        local sortBtn=button(p,"Ordenar: "..config.ui.songSort,34)
        sortBtn.Activated:Connect(function()
            sortIndex=sortIndex%#sortModes+1;config.ui.songSort=sortModes[sortIndex];sortBtn.Text="Ordenar: "..config.ui.songSort
            app:_renderSongs();persistUi()
        end)
    end

    -- PIANO: compact live mapping reference inspired by the reference app's mapping previews.
    do
        local p=app.pages.Piano
        label(p,"Preview rápido do QWERTY",18,true)
        local white=label(p,"Brancas: 1234567890  qwertyuiop  asdfghjkl  zxcvbnm",34,false);white.TextWrapped=true;white.TextSize=9;white.TextColor3=C.muted
        local black=label(p,"Pretas: Shift + tecla anterior quando existir sustenido",30,false);black.TextWrapped=true;black.TextSize=9;black.TextColor3=C.muted
    end

    -- HUMAN LAB: useful ideas from Dodo's Human Engine, adapted to preserve MIDI pitches.
    local advancedLabels={}
    local function refreshHumanLabels()
        if advancedLabels.timing then advancedLabels.timing.Text=string.format("Timing: %.1f ms",human.timingMs or 0)end
        if advancedLabels.duration then advancedLabels.duration.Text=string.format("Duração: %.1f%%",(human.durationVariation or 0)*100)end
        if advancedLabels.chord then advancedLabels.chord.Text=string.format("Chord spread: %.1f ms",human.chordSpreadMs or 0)end
        if advancedLabels.swing then advancedLabels.swing.Text=string.format("Swing: %.1f ms",human.swingMs or 0)end
        if advancedLabels.rubato then advancedLabels.rubato.Text=string.format("Rubato: %d%%",math.floor((human.rubato or 0)*100+.5))end
        if advancedLabels.hands then advancedLabels.hands.Text=string.format("Diferença mãos: %d%%",math.floor((human.handIndependence or 0)*100+.5))end
        if advancedLabels.phrase then advancedLabels.phrase.Text=string.format("Fraseado: %d%%",math.floor((human.phraseExpression or 0)*100+.5))end
        if advancedLabels.latency then advancedLabels.latency.Text=string.format("Latência musical: %+d ms",math.floor(human.latencyMs or 0))end
        if advancedLabels.curve then advancedLabels.curve.Text="Curva: "..tostring(human.expressionCurve or "Soft")end
        if advancedLabels.seed then advancedLabels.seed.Text="Variação por Play: "..tostring(human.seedMode or "Auto")end
    end
    local function setHuman(key,value)
        human[key]=value;rebuildHuman();refreshHumanLabels()
    end
    local function applyLabPreset(name)
        local p={
            Pianist={strength=.18,timingMs=6,durationVariation=.018,chordSpreadMs=5,swingMs=.8,rubato=.11,handIndependence=.38,phraseExpression=.48,expressionCurve="Expressive"},
            Soft={strength=.14,timingMs=4,durationVariation=.022,chordSpreadMs=3,swingMs=.5,rubato=.09,handIndependence=.24,phraseExpression=.38,expressionCurve="Soft"},
            Energetic={strength=.17,timingMs=4,durationVariation=.010,chordSpreadMs=3,swingMs=1.4,rubato=.04,handIndependence=.20,phraseExpression=.26,expressionCurve="Strong"},
        }
        local s=p[name];if not s then return end
        for k,v in pairs(s)do human[k]=v end
        human.preset="Custom";rebuildHuman();refreshHumanLabels()
        if app.setHumanStrength then app:setHumanStrength(human.strength)end
    end
    do
        local p=app.pages.Human
        label(p,"Human Lab avançado",22,true)
        local hint=label(p,"Inspirado no Human Engine do app enviado. Só microtiming, duração e expressão: nenhuma nota MIDI é trocada.",42,false);hint.TextWrapped=true;hint.TextSize=9;hint.TextColor3=C.muted
        row(p,{
            {text="Pianist",click=function()applyLabPreset("Pianist")end},
            {text="Soft",click=function()applyLabPreset("Soft")end},
            {text="Energetic",click=function()applyLabPreset("Energetic")end},
        },36,5)

        advancedLabels.timing=label(p,"",18,true)
        row(p,{
            {text="-1 ms",click=function()setHuman("timingMs",clamp((human.timingMs or 0)-1,0,30))end},
            {text="+1 ms",click=function()setHuman("timingMs",clamp((human.timingMs or 0)+1,0,30))end},
        },34,6)
        advancedLabels.duration=label(p,"",18,true)
        row(p,{
            {text="-1%",click=function()setHuman("durationVariation",clamp((human.durationVariation or 0)-.01,0,.35))end},
            {text="+1%",click=function()setHuman("durationVariation",clamp((human.durationVariation or 0)+.01,0,.35))end},
        },34,6)
        advancedLabels.chord=label(p,"",18,true)
        row(p,{
            {text="-1 ms",click=function()setHuman("chordSpreadMs",clamp((human.chordSpreadMs or 0)-1,0,28))end},
            {text="+1 ms",click=function()setHuman("chordSpreadMs",clamp((human.chordSpreadMs or 0)+1,0,28))end},
        },34,6)
        advancedLabels.swing=label(p,"",18,true)
        row(p,{
            {text="-0.5",click=function()setHuman("swingMs",clamp((human.swingMs or 0)-.5,0,25))end},
            {text="+0.5",click=function()setHuman("swingMs",clamp((human.swingMs or 0)+.5,0,25))end},
        },34,6)
        advancedLabels.rubato=label(p,"",18,true)
        row(p,{
            {text="Menos",click=function()setHuman("rubato",clamp((human.rubato or 0)-.01,0,.35))end},
            {text="Mais",click=function()setHuman("rubato",clamp((human.rubato or 0)+.01,0,.35))end},
        },34,6)
        advancedLabels.hands=label(p,"",18,true)
        row(p,{
            {text="Menos",click=function()setHuman("handIndependence",clamp((human.handIndependence or 0)-.05,0,1))end},
            {text="Mais",click=function()setHuman("handIndependence",clamp((human.handIndependence or 0)+.05,0,1))end},
        },34,6)
        advancedLabels.phrase=label(p,"",18,true)
        row(p,{
            {text="Menos",click=function()setHuman("phraseExpression",clamp((human.phraseExpression or 0)-.05,0,1))end},
            {text="Mais",click=function()setHuman("phraseExpression",clamp((human.phraseExpression or 0)+.05,0,1))end},
        },34,6)
        advancedLabels.latency=label(p,"",18,true)
        row(p,{
            {text="-5 ms",click=function()setHuman("latencyMs",clamp((human.latencyMs or 0)-5,-80,80))end},
            {text="0",click=function()setHuman("latencyMs",0)end},
            {text="+5 ms",click=function()setHuman("latencyMs",clamp((human.latencyMs or 0)+5,-80,80))end},
        },34,5)
        advancedLabels.curve=label(p,"",18,true)
        local curves={"Linear","Soft","Expressive","Strong"};local ci=1
        for i,v in ipairs(curves)do if v==human.expressionCurve then ci=i break end end
        local curveBtn=button(p,"Trocar curva",34);curveBtn.Activated:Connect(function()ci=ci%#curves+1;setHuman("expressionCurve",curves[ci])end)
        advancedLabels.seed=label(p,"",18,true)
        row(p,{
            {text="Auto/Fixed",click=function()setHuman("seedMode",human.seedMode=="Fixed" and "Auto" or "Fixed")end},
            {text="Nova performance",click=function()rebuildHuman()end},
        },34,6)
        refreshHumanLabels()
    end

    -- PLAYBACK LAB: loop and timing policies seen in the reference app, adapted to Roblox.
    local playbackLabels={}
    local function refreshPlayback()
        if playbackLabels.loop then playbackLabels.loop.Text="Loop da música: "..(config.playback.loopSong and "ON" or "OFF")end
        if playbackLabels.late then playbackLabels.late.Text="Atrasos: "..tostring(config.playback.lateMode)end
        if playbackLabels.chord then playbackLabels.chord.Text=string.format("Janela de acorde: %.1f ms",config.playback.chordWindowMs or 8)end
        if playbackLabels.collision then playbackLabels.collision.Text=string.format("Fusão de colisões: %.1f ms",config.playback.collisionWindowMs or 2.5)end
    end
    do
        local p=app.pages.Settings
        label(p,"Playback avançado",22,true)
        playbackLabels.loop=label(p,"",18,true)
        local loopBtn=button(p,"Alternar loop",34);loopBtn.Activated:Connect(function()config.playback.loopSong=not config.playback.loopSong;rebuildPlayback();refreshPlayback()end)
        playbackLabels.late=label(p,"",18,true)
        local lateModes={"CatchUp","Adaptive","SkipLate"};local li=1
        for i,v in ipairs(lateModes)do if v==config.playback.lateMode then li=i break end end
        local lateBtn=button(p,"Trocar política de atraso",34);lateBtn.Activated:Connect(function()li=li%#lateModes+1;config.playback.lateMode=lateModes[li];rebuildPlayback();refreshPlayback()end)
        playbackLabels.chord=label(p,"",18,true)
        row(p,{
            {text="-1 ms",click=function()config.playback.chordWindowMs=clamp((config.playback.chordWindowMs or 8)-1,2,30);rebuildPlayback();refreshPlayback()end},
            {text="+1 ms",click=function()config.playback.chordWindowMs=clamp((config.playback.chordWindowMs or 8)+1,2,30);rebuildPlayback();refreshPlayback()end},
        },34,6)
        playbackLabels.collision=label(p,"",18,true)
        row(p,{
            {text="-0.5",click=function()config.playback.collisionWindowMs=clamp((config.playback.collisionWindowMs or 2.5)-.5,.5,10);rebuildPlayback();refreshPlayback()end},
            {text="+0.5",click=function()config.playback.collisionWindowMs=clamp((config.playback.collisionWindowMs or 2.5)+.5,.5,10);rebuildPlayback();refreshPlayback()end},
        },34,6)
        refreshPlayback()
    end

    -- Diagnostics summary for the new controls.
    local labDiag=label(app.pages.Diag,"",100,false);labDiag.TextWrapped=true;labDiag.TextYAlignment=Enum.TextYAlignment.Top;labDiag.TextSize=9;labDiag.TextColor3=C.muted
    local function refreshDiag()
        labDiag.Text=string.format("Human Lab\nTiming %.1f ms | Chord %.1f ms | Swing %.1f ms\nRubato %d%% | Mãos %d%% | Latência %+d ms\nCurva %s | Seed %s\nPlayback: %s | Loop %s | ChordWindow %.1f ms",
            human.timingMs or 0,human.chordSpreadMs or 0,human.swingMs or 0,
            math.floor((human.rubato or 0)*100+.5),math.floor((human.handIndependence or 0)*100+.5),math.floor(human.latencyMs or 0),
            tostring(human.expressionCurve),tostring(human.seedMode),tostring(config.playback.lateMode),config.playback.loopSong and "ON" or "OFF",config.playback.chordWindowMs or 8)
    end
    refreshDiag()

    local oldSetProgress=app.setProgress
    app.setProgress=function(self,...)
        local r=oldSetProgress(self,...);refreshDiag();return r
    end
    local oldSetHumanStrength=app.setHumanStrength
    app.setHumanStrength=function(self,v)
        local r=oldSetHumanStrength(self,v);refreshHumanLabels();refreshDiag();return r
    end

    return app
end

return App
