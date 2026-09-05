local App = {}
App.__index = App

local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local C = {
    bg = Color3.fromRGB(16, 18, 28), panel = Color3.fromRGB(25, 28, 42), panel2 = Color3.fromRGB(34, 38, 56),
    accent = Color3.fromRGB(126, 92, 255), accent2 = Color3.fromRGB(90, 210, 190), text = Color3.fromRGB(241, 243, 250),
    muted = Color3.fromRGB(160, 166, 187), danger = Color3.fromRGB(235, 92, 110)
}

local function corner(o, r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 10); c.Parent=o end
local function stroke(o, color, t) local s=Instance.new("UIStroke"); s.Color=color or C.panel2; s.Thickness=t or 1; s.Transparency=.2; s.Parent=o end
local function text(o, size, color) o.Font=Enum.Font.Gotham; o.TextSize=size or 14; o.TextColor3=color or C.text end
local function button(parent, label, size)
    local b=Instance.new("TextButton"); b.AutoButtonColor=false; b.BackgroundColor3=C.panel2; b.Size=size or UDim2.fromOffset(90,36); b.Text=label; text(b,13); corner(b,9); b.Parent=parent
    b.MouseEnter:Connect(function() b.BackgroundColor3=C.accent end); b.MouseLeave:Connect(function() b.BackgroundColor3=C.panel2 end)
    return b
end
local function label(parent, value, size, pos)
    local l=Instance.new("TextLabel"); l.BackgroundTransparency=1; l.Text=value; l.TextXAlignment=Enum.TextXAlignment.Left; text(l,14); l.Size=size or UDim2.new(1,0,0,24); if pos then l.Position=pos end; l.Parent=parent; return l
end
local function listLayout(parent, pad)
    local l=Instance.new("UIListLayout"); l.Padding=UDim.new(0,pad or 8); l.SortOrder=Enum.SortOrder.LayoutOrder; l.Parent=parent; return l
end
local function scroll(parent)
    local s=Instance.new("ScrollingFrame"); s.BackgroundTransparency=1; s.BorderSizePixel=0; s.Size=UDim2.fromScale(1,1); s.CanvasSize=UDim2.new(); s.AutomaticCanvasSize=Enum.AutomaticSize.Y; s.ScrollBarThickness=3; s.Parent=parent; return s
end

function App.new(callbacks, config)
    local self=setmetatable({callbacks=callbacks or {}, config=config, pages={}, mode="Both", song=nil},App)
    local gui=Instance.new("ScreenGui"); gui.Name="MIDIQWERTY_UI"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=false
    local parent = (gethui and gethui()) or CoreGui
    local ok=pcall(function() gui.Parent=parent end); if not ok then gui.Parent=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end
    self.gui=gui

    local main=Instance.new("Frame"); main.Name="Main"; main.AnchorPoint=Vector2.new(.5,.5); main.Position=UDim2.fromScale(.5,.5); main.Size=UDim2.new(0,430,0,570); main.BackgroundColor3=C.bg; corner(main,16); stroke(main,C.panel2,1); main.Parent=gui; self.main=main
    local scale=Instance.new("UIScale"); scale.Parent=main
    local function updateScale()
        local v=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(430,800)
        scale.Scale=math.min(1, (v.X-16)/430, (v.Y-24)/570)
    end
    updateScale(); if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale) end

    local top=Instance.new("Frame"); top.BackgroundTransparency=1; top.Position=UDim2.fromOffset(14,10); top.Size=UDim2.new(1,-28,0,42); top.Parent=main
    local title=label(top,"MIDI  •  QWERTY",UDim2.new(1,-90,1,0)); title.Font=Enum.Font.GothamBold; title.TextSize=17
    local miniBtn=button(top,"—",UDim2.fromOffset(36,32)); miniBtn.Position=UDim2.new(1,-78,0,2)
    local hideBtn=button(top,"×",UDim2.fromOffset(36,32)); hideBtn.Position=UDim2.new(1,-36,0,2)

    local tabs=Instance.new("Frame"); tabs.BackgroundTransparency=1; tabs.Position=UDim2.fromOffset(14,56); tabs.Size=UDim2.new(1,-28,0,38); tabs.Parent=main
    local tl=Instance.new("UIListLayout"); tl.FillDirection=Enum.FillDirection.Horizontal; tl.Padding=UDim.new(0,5); tl.Parent=tabs
    local content=Instance.new("Frame"); content.BackgroundColor3=C.panel; content.Position=UDim2.fromOffset(14,102); content.Size=UDim2.new(1,-28,1,-116); corner(content,12); content.ClipsDescendants=true; content.Parent=main

    local tabNames={"Songs","Player","Parts","Humanize","Settings","Diag"}
    local function showTab(name)
        for n,p in pairs(self.pages) do p.Visible=n==name end
        self.activeTab=name
    end
    for _,name in ipairs(tabNames) do
        local tb=button(tabs,name,UDim2.new(1/#tabNames,-5,1,0)); tb.TextSize=11
        tb.Activated:Connect(function() showTab(name) end)
        local p=Instance.new("Frame"); p.Name=name; p.BackgroundTransparency=1; p.Position=UDim2.fromOffset(10,10); p.Size=UDim2.new(1,-20,1,-20); p.Visible=false; p.Parent=content; self.pages[name]=p
    end

    -- Songs
    local sp=self.pages.Songs
    local refresh=button(sp,"↻  Refresh",UDim2.fromOffset(110,36)); refresh.Activated:Connect(function() if self.callbacks.onRefresh then self.callbacks.onRefresh() end end)
    local status=label(sp,"Scanning MIDI folders…",UDim2.new(1,-120,0,36),UDim2.fromOffset(120,0)); status.TextColor3=C.muted; self.songStatus=status
    local songList=scroll(sp); songList.Position=UDim2.fromOffset(0,46); songList.Size=UDim2.new(1,0,1,-46); listLayout(songList,7); self.songList=songList

    -- Player
    local pp=self.pages.Player
    local songName=label(pp,"No MIDI selected",UDim2.new(1,0,0,34)); songName.Font=Enum.Font.GothamBold; songName.TextSize=18; self.songName=songName
    local info=label(pp,"Select a .mid file from Songs",UDim2.new(1,0,0,46),UDim2.fromOffset(0,34)); info.TextWrapped=true; info.TextColor3=C.muted; self.songInfo=info
    local progressBg=Instance.new("Frame"); progressBg.BackgroundColor3=C.panel2; progressBg.Position=UDim2.fromOffset(0,88); progressBg.Size=UDim2.new(1,0,0,8); corner(progressBg,4); progressBg.Parent=pp
    local progress=Instance.new("Frame"); progress.BackgroundColor3=C.accent; progress.Size=UDim2.fromScale(0,1); corner(progress,4); progress.Parent=progressBg; self.progress=progress
    local timeLabel=label(pp,"00:00 / 00:00",UDim2.new(1,0,0,26),UDim2.fromOffset(0,101)); timeLabel.TextColor3=C.muted; self.timeLabel=timeLabel
    local controls=Instance.new("Frame"); controls.BackgroundTransparency=1; controls.Position=UDim2.fromOffset(0,134); controls.Size=UDim2.new(1,0,0,42); controls.Parent=pp; local cl=listLayout(controls,8); cl.FillDirection=Enum.FillDirection.Horizontal; cl.HorizontalAlignment=Enum.HorizontalAlignment.Center
    local stop=button(controls,"■",UDim2.fromOffset(56,40)); local play=button(controls,"▶",UDim2.fromOffset(72,40)); local back=button(controls,"-5s",UDim2.fromOffset(62,40)); local fwd=button(controls,"+5s",UDim2.fromOffset(62,40)); self.playButton=play
    stop.Activated:Connect(function() if self.callbacks.onStop then self.callbacks.onStop() end end)
    play.Activated:Connect(function() if self.callbacks.onPlayPause then self.callbacks.onPlayPause() end end)
    back.Activated:Connect(function() if self.callbacks.onSeekRelative then self.callbacks.onSeekRelative(-5) end end)
    fwd.Activated:Connect(function() if self.callbacks.onSeekRelative then self.callbacks.onSeekRelative(5) end end)
    label(pp,"Playable part",UDim2.new(1,0,0,26),UDim2.fromOffset(0,190)).TextColor3=C.muted
    local modes=Instance.new("Frame"); modes.BackgroundTransparency=1; modes.Position=UDim2.fromOffset(0,220); modes.Size=UDim2.new(1,0,0,82); modes.Parent=pp; local grid=Instance.new("UIGridLayout"); grid.CellSize=UDim2.fromOffset(118,34); grid.CellPadding=UDim2.fromOffset(8,8); grid.Parent=modes
    for _,m in ipairs({"Both","Left","Right","Melody","Accompaniment","Bass"}) do local b=button(modes,m); b.Activated:Connect(function() self.mode=m; if self.callbacks.onMode then self.callbacks.onMode(m) end end) end
    local speed=button(pp,"Speed 1.00×",UDim2.fromOffset(130,36)); speed.Position=UDim2.fromOffset(0,320); self.speedButton=speed; speed.Activated:Connect(function() if self.callbacks.onCycleSpeed then self.callbacks.onCycleSpeed() end end)
    local panic=button(pp,"Release keys",UDim2.fromOffset(130,36)); panic.Position=UDim2.fromOffset(140,320); panic.Activated:Connect(function() if self.callbacks.onPanic then self.callbacks.onPanic() end end)
    local perf=label(pp,"Performance: ready",UDim2.new(1,0,0,90),UDim2.fromOffset(0,370)); perf.TextWrapped=true; perf.TextYAlignment=Enum.TextYAlignment.Top; perf.TextColor3=C.muted; self.performanceInfo=perf

    -- Parts
    local parts=self.pages.Parts
    local split=label(parts,"Hand split: waiting for MIDI",UDim2.new(1,0,0,30)); split.Font=Enum.Font.GothamBold; self.splitLabel=split
    local partHelp=label(parts,"Tracks are classified into LH/RH plus melody, bass and accompaniment. Tap a track to include/exclude it.",UDim2.new(1,0,0,54),UDim2.fromOffset(0,32)); partHelp.TextWrapped=true; partHelp.TextColor3=C.muted
    local trackList=scroll(parts); trackList.Position=UDim2.fromOffset(0,92); trackList.Size=UDim2.new(1,0,1,-92); listLayout(trackList,7); self.trackList=trackList

    -- Humanize
    local hp=self.pages.Humanize
    label(hp,"Interpretation",UDim2.new(1,0,0,30)).Font=Enum.Font.GothamBold
    local hdesc=label(hp,"Subtle musical variation only. It changes microtiming and duration without inventing notes.",UDim2.new(1,0,0,56),UDim2.fromOffset(0,34)); hdesc.TextWrapped=true; hdesc.TextColor3=C.muted
    local presetBox=Instance.new("Frame"); presetBox.BackgroundTransparency=1; presetBox.Position=UDim2.fromOffset(0,100); presetBox.Size=UDim2.new(1,0,0,90); presetBox.Parent=hp; local pg=Instance.new("UIGridLayout"); pg.CellSize=UDim2.fromOffset(120,36); pg.CellPadding=UDim2.fromOffset(8,8); pg.Parent=presetBox
    for _,p in ipairs({"Exact","Very Subtle","Natural","Expressive"}) do local b=button(presetBox,p); b.Activated:Connect(function() if self.callbacks.onPreset then self.callbacks.onPreset(p) end end) end
    local strength=label(hp,"Humanization: 22%",UDim2.new(1,0,0,34),UDim2.fromOffset(0,210)); self.strengthLabel=strength
    local minus=button(hp,"−",UDim2.fromOffset(48,36)); minus.Position=UDim2.fromOffset(0,250); local plus=button(hp,"+",UDim2.fromOffset(48,36)); plus.Position=UDim2.fromOffset(58,250)
    minus.Activated:Connect(function() if self.callbacks.onHumanDelta then self.callbacks.onHumanDelta(-0.02) end end); plus.Activated:Connect(function() if self.callbacks.onHumanDelta then self.callbacks.onHumanDelta(0.02) end end)
    local seed=label(hp,"Each Play can generate a new performance seed.",UDim2.new(1,0,0,60),UDim2.fromOffset(0,310)); seed.TextWrapped=true; seed.TextColor3=C.muted

    -- Settings
    local setp=self.pages.Settings
    label(setp,"Playback settings",UDim2.new(1,0,0,30)).Font=Enum.Font.GothamBold
    local transpose=label(setp,"Transpose: 0",UDim2.fromOffset(180,36),UDim2.fromOffset(0,54)); self.transposeLabel=transpose
    local tm=button(setp,"−",UDim2.fromOffset(42,34)); tm.Position=UDim2.fromOffset(190,54); local tp=button(setp,"+",UDim2.fromOffset(42,34)); tp.Position=UDim2.fromOffset(240,54)
    tm.Activated:Connect(function() if self.callbacks.onTransposeDelta then self.callbacks.onTransposeDelta(-1) end end); tp.Activated:Connect(function() if self.callbacks.onTransposeDelta then self.callbacks.onTransposeDelta(1) end end)
    local range=button(setp,"Range: OctaveFold",UDim2.fromOffset(190,36)); range.Position=UDim2.fromOffset(0,108); self.rangeButton=range; range.Activated:Connect(function() if self.callbacks.onCycleRange then self.callbacks.onCycleRange() end end)
    local folder=label(setp,"Default folder: Delta/Workspace/MIDI/",UDim2.new(1,0,0,58),UDim2.fromOffset(0,168)); folder.TextWrapped=true; folder.TextColor3=C.muted
    local backend=label(setp,"Input backend: detecting…",UDim2.new(1,0,0,40),UDim2.fromOffset(0,230)); backend.TextColor3=C.muted; self.backendLabel=backend

    -- Diagnostics
    local dp=self.pages.Diag
    label(dp,"Diagnostics",UDim2.new(1,0,0,30)).Font=Enum.Font.GothamBold
    local diag=label(dp,"No performance loaded.",UDim2.new(1,0,1,-40),UDim2.fromOffset(0,40)); diag.TextYAlignment=Enum.TextYAlignment.Top; diag.TextWrapped=true; diag.TextColor3=C.muted; self.diagLabel=diag

    -- Mini player
    local mini=Instance.new("Frame"); mini.AnchorPoint=Vector2.new(.5,1); mini.Position=UDim2.new(.5,0,1,-18); mini.Size=UDim2.fromOffset(360,72); mini.BackgroundColor3=C.bg; corner(mini,14); stroke(mini,C.panel2); mini.Visible=false; mini.Parent=gui; self.mini=mini
    local miniName=label(mini,"No MIDI",UDim2.new(1,-130,0,28),UDim2.fromOffset(14,9)); miniName.Font=Enum.Font.GothamBold; self.miniName=miniName
    local miniTime=label(mini,"00:00",UDim2.new(1,-130,0,22),UDim2.fromOffset(14,38)); miniTime.TextColor3=C.muted; self.miniTime=miniTime
    local miniPlay=button(mini,"▶",UDim2.fromOffset(48,44)); miniPlay.Position=UDim2.new(1,-110,0,14); miniPlay.Activated:Connect(function() if self.callbacks.onPlayPause then self.callbacks.onPlayPause() end end)
    local expand=button(mini,"⌃",UDim2.fromOffset(48,44)); expand.Position=UDim2.new(1,-56,0,14); expand.Activated:Connect(function() self:setState("Full") end)

    -- Floating toggle
    local floating=button(gui,"♫",UDim2.fromOffset(54,54)); floating.Name="FloatingToggle"; floating.BackgroundColor3=C.accent; floating.Position=UDim2.fromScale(config.ui.floatingX or .88,config.ui.floatingY or .55); corner(floating,27); floating.Visible=false; self.floating=floating
    local dragging, dragStart, startPos=false,nil,nil
    floating.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; dragStart=i.Position; startPos=floating.Position end end)
    floating.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
    UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then local d=i.Position-dragStart; floating.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)
    floating.Activated:Connect(function() self:setState("Full") end)
    miniBtn.Activated:Connect(function() self:setState("Mini") end); hideBtn.Activated:Connect(function() self:setState("Hidden") end)

    showTab("Songs"); self:setState(config.ui.state or "Full")
    return self
end

function App:setState(state)
    if state~="Full" and state~="Mini" and state~="Hidden" then state="Full" end
    self.main.Visible=state=="Full"; self.mini.Visible=state=="Mini"; self.floating.Visible=state=="Hidden"; self.config.ui.state=state
    if self.callbacks.onUiState then self.callbacks.onUiState(state,self.floating.Position) end
end

function App:setSongs(songs, message)
    for _,c in ipairs(self.songList:GetChildren()) do if c:IsA("GuiButton") then c:Destroy() end end
    self.songStatus.Text=message or (#songs.." MIDI file(s)")
    for _,item in ipairs(songs) do
        local row=button(self.songList,item.name,UDim2.new(1,-5,0,42)); row.TextXAlignment=Enum.TextXAlignment.Left; row.Text="   "..item.name
        row.Activated:Connect(function() if self.callbacks.onSelectSong then self.callbacks.onSelectSong(item) end end)
    end
end

function App:setSong(item, analysis, mapStats, perfStats)
    self.song=item; local name=item and item.name or "No MIDI selected"; self.songName.Text=name; self.miniName.Text=name
    if analysis then
        self.songInfo.Text=string.format("%.1fs  •  %d notes  •  %d tracks  •  polyphony %d",analysis.duration,analysis.noteCount,#analysis.tracks,analysis.peakPolyphony)
        self.splitLabel.Text="Auto hand split: MIDI note "..tostring(analysis.handSplit or "?")
    end
    if mapStats then self.performanceInfo.Text=string.format("Mapped %d/%d notes (%.1f%%)\nAdapted: %d  •  Dropped: %d\nPerformance seed: %s",mapStats.mapped,mapStats.total,mapStats.coverage*100,mapStats.adapted,mapStats.dropped,tostring(perfStats and perfStats.seed or "-")) end
end

function App:setAnalysis(analysis, enabledTracks)
    for _,c in ipairs(self.trackList:GetChildren()) do if c:IsA("GuiButton") then c:Destroy() end end
    for i,info in ipairs(analysis.tracks or {}) do
        local enabled=enabledTracks[i]~=false
        local row=button(self.trackList,(enabled and "✓  " or "○  ")..(info.name or ("Track "..i)).."  •  "..tostring(info.noteCount or 0).." notes",UDim2.new(1,-5,0,42)); row.TextXAlignment=Enum.TextXAlignment.Left
        row.Activated:Connect(function() enabled=not enabled; row.Text=(enabled and "✓  " or "○  ")..(info.name or ("Track "..i)).."  •  "..tostring(info.noteCount or 0).." notes"; if self.callbacks.onToggleTrack then self.callbacks.onToggleTrack(i,enabled) end end)
    end
end

local function formatTime(s) s=math.max(0,s or 0); return string.format("%02d:%02d",math.floor(s/60),math.floor(s%60)) end
function App:setProgress(pos,duration,stats,playing)
    local ratio=duration>0 and math.clamp(pos/duration,0,1) or 0; self.progress.Size=UDim2.fromScale(ratio,1)
    local t=formatTime(pos).." / "..formatTime(duration); self.timeLabel.Text=t; self.miniTime.Text=t; self.playButton.Text=playing and "Ⅱ" or "▶"
    if stats then local avg=stats.processed>0 and stats.driftSumMs/stats.processed or 0; self.diagLabel.Text=string.format("Events processed: %d\nSkipped: %d\nLate: %d\nAverage scheduling lateness: %.2f ms\nPeak scheduling lateness: %.2f ms",stats.processed,stats.skipped,stats.late,avg,stats.driftPeakMs) end
end
function App:setBackend(name) self.backendLabel.Text="Input backend: "..tostring(name) end
function App:setSpeed(v) self.speedButton.Text=string.format("Speed %.2f×",v) end
function App:setHumanStrength(v) self.strengthLabel.Text=string.format("Humanization: %d%%",math.floor(v*100+.5)) end
function App:setTranspose(v) self.transposeLabel.Text="Transpose: "..tostring(v) end
function App:setRange(v) self.rangeButton.Text="Range: "..tostring(v) end
function App:setError(msg) self.songStatus.Text="Error: "..tostring(msg); self.songStatus.TextColor3=C.danger end
function App:destroy() if self.gui then self.gui:Destroy() end end

return App
