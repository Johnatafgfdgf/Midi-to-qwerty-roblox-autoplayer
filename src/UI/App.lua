local App={};App.__index=App
local UIS=game:GetService("UserInputService");local CoreGui=game:GetService("CoreGui")
local C={bg=Color3.fromRGB(15,17,27),panel=Color3.fromRGB(24,27,41),panel2=Color3.fromRGB(34,38,56),accent=Color3.fromRGB(126,92,255),accent2=Color3.fromRGB(83,208,184),text=Color3.fromRGB(242,244,250),muted=Color3.fromRGB(157,164,186),danger=Color3.fromRGB(236,91,111)}
local function corner(o,r)local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r or 10);c.Parent=o end
local function stroke(o,col,t)local s=Instance.new("UIStroke");s.Color=col or C.panel2;s.Thickness=t or 1;s.Transparency=.2;s.Parent=o end
local function textStyle(o,size,col)o.Font=Enum.Font.Gotham;o.TextSize=size or 14;o.TextColor3=col or C.text end
local function label(parent,value,size,pos)local l=Instance.new("TextLabel");l.BackgroundTransparency=1;l.Text=value;l.TextXAlignment=Enum.TextXAlignment.Left;textStyle(l,14);l.Size=size or UDim2.new(1,0,0,24);if pos then l.Position=pos end;l.Parent=parent;return l end
local function button(parent,value,size)local b=Instance.new("TextButton");b.AutoButtonColor=false;b.BackgroundColor3=C.panel2;b.Size=size or UDim2.fromOffset(90,36);b.Text=value;textStyle(b,13);corner(b,9);b.Parent=parent;return b end
local function listLayout(parent,pad)local l=Instance.new("UIListLayout");l.Padding=UDim.new(0,pad or 8);l.SortOrder=Enum.SortOrder.LayoutOrder;l.Parent=parent;return l end
local function scroll(parent)local s=Instance.new("ScrollingFrame");s.BackgroundTransparency=1;s.BorderSizePixel=0;s.Size=UDim2.fromScale(1,1);s.CanvasSize=UDim2.new();s.AutomaticCanvasSize=Enum.AutomaticSize.Y;s.ScrollBarThickness=3;s.ScrollBarImageColor3=C.accent;s.Parent=parent;return s end
local function formatTime(s)s=math.max(0,s or 0);return string.format("%02d:%02d",math.floor(s/60),math.floor(s%60)) end

function App.new(callbacks,config)
    local self=setmetatable({callbacks=callbacks or {},config=config,pages={},allSongs={},songFilter=config.ui.songFilter or "All",song=nil},App)
    local gui=Instance.new("ScreenGui");gui.Name="MIDIQWERTY_UI";gui.ResetOnSpawn=false;local parent=(gethui and gethui()) or CoreGui;local ok=pcall(function()gui.Parent=parent end);if not ok then gui.Parent=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end;self.gui=gui
    local main=Instance.new("Frame");main.AnchorPoint=Vector2.new(.5,.5);main.Position=UDim2.fromScale(.5,.5);main.Size=UDim2.fromOffset(438,584);main.BackgroundColor3=C.bg;corner(main,16);stroke(main);main.Parent=gui;self.main=main
    local scale=Instance.new("UIScale");scale.Parent=main;local function updateScale()local v=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(438,800);scale.Scale=math.min(1,(v.X-14)/438,(v.Y-20)/584)end;updateScale();if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)end
    local top=Instance.new("Frame");top.BackgroundTransparency=1;top.Position=UDim2.fromOffset(14,9);top.Size=UDim2.new(1,-28,0,42);top.Parent=main
    local title=label(top,"MIDI  •  QWERTY",UDim2.new(1,-104,1,0));title.Font=Enum.Font.GothamBold;title.TextSize=17
    local miniBtn=button(top,"—",UDim2.fromOffset(36,32));miniBtn.Position=UDim2.new(1,-78,0,2);local hideBtn=button(top,"×",UDim2.fromOffset(36,32));hideBtn.Position=UDim2.new(1,-36,0,2)
    local message=label(main,"",UDim2.new(1,-28,0,22),UDim2.fromOffset(14,48));message.TextSize=11;message.TextColor3=C.accent2;self.message=message
    local tabs=Instance.new("Frame");tabs.BackgroundTransparency=1;tabs.Position=UDim2.fromOffset(14,72);tabs.Size=UDim2.new(1,-28,0,36);tabs.Parent=main;local tl=Instance.new("UIListLayout");tl.FillDirection=Enum.FillDirection.Horizontal;tl.Padding=UDim.new(0,4);tl.Parent=tabs
    local content=Instance.new("Frame");content.BackgroundColor3=C.panel;content.Position=UDim2.fromOffset(14,116);content.Size=UDim2.new(1,-28,1,-130);corner(content,12);content.ClipsDescendants=true;content.Parent=main
    local tabNames={"Songs","Player","Parts","Piano","Human","Settings","Diag"}
    local function showTab(name)for n,p in pairs(self.pages)do p.Visible=n==name end;self.activeTab=name end
    for _,name in ipairs(tabNames)do local tb=button(tabs,name,UDim2.new(1/#tabNames,-4,1,0));tb.TextSize=10;tb.Activated:Connect(function()showTab(name)end);local p=Instance.new("Frame");p.BackgroundTransparency=1;p.Position=UDim2.fromOffset(10,10);p.Size=UDim2.new(1,-20,1,-20);p.Visible=false;p.Parent=content;self.pages[name]=p end

    -- SONGS
    local sp=self.pages.Songs
    local search=Instance.new("TextBox");search.PlaceholderText="Search MIDI…";search.Text="";search.ClearTextOnFocus=false;search.BackgroundColor3=C.panel2;search.Size=UDim2.new(1,-185,0,36);search.TextXAlignment=Enum.TextXAlignment.Left;textStyle(search,13);corner(search,9);search.Parent=sp;self.searchBox=search
    local refresh=button(sp,"↻",UDim2.fromOffset(42,36));refresh.Position=UDim2.new(1,-178,0,0);refresh.Activated:Connect(function()if self.callbacks.onRefresh then self.callbacks.onRefresh()end end)
    local filter=button(sp,self.songFilter,UDim2.fromOffset(128,36));filter.Position=UDim2.new(1,-128,0,0);self.filterButton=filter
    filter.Activated:Connect(function()local order={"All","Favorites","Recent"};local idx=1;for i,v in ipairs(order)do if v==self.songFilter then idx=i break end end;self.songFilter=order[idx%#order+1];self.config.ui.songFilter=self.songFilter;filter.Text=self.songFilter;self:_renderSongs()end)
    local stat=label(sp,"Scanning…",UDim2.new(1,0,0,26),UDim2.fromOffset(0,42));stat.TextColor3=C.muted;stat.TextSize=12;self.songStatus=stat
    local songList=scroll(sp);songList.Position=UDim2.fromOffset(0,70);songList.Size=UDim2.new(1,0,1,-70);listLayout(songList,7);self.songList=songList
    search:GetPropertyChangedSignal("Text"):Connect(function()self:_renderSongs()end)

    -- PLAYER
    local pp=self.pages.Player
    local songName=label(pp,"No MIDI selected",UDim2.new(1,-45,0,32));songName.Font=Enum.Font.GothamBold;songName.TextSize=18;self.songName=songName
    local fav=button(pp,"☆",UDim2.fromOffset(38,32));fav.Position=UDim2.new(1,-38,0,0);self.favoriteButton=fav;fav.Activated:Connect(function()if self.song and self.callbacks.onToggleFavorite then self.callbacks.onToggleFavorite(self.song)end end)
    local info=label(pp,"Select a song from Songs",UDim2.new(1,0,0,42),UDim2.fromOffset(0,34));info.TextWrapped=true;info.TextColor3=C.muted;info.TextSize=12;self.songInfo=info
    local bar=Instance.new("Frame");bar.BackgroundColor3=C.panel2;bar.Position=UDim2.fromOffset(0,83);bar.Size=UDim2.new(1,0,0,8);corner(bar,4);bar.Parent=pp;local progress=Instance.new("Frame");progress.BackgroundColor3=C.accent;progress.Size=UDim2.fromScale(0,1);corner(progress,4);progress.Parent=bar;self.progress=progress
    local timeLabel=label(pp,"00:00 / 00:00",UDim2.new(1,0,0,24),UDim2.fromOffset(0,97));timeLabel.TextColor3=C.muted;timeLabel.TextSize=12;self.timeLabel=timeLabel
    local ctr=Instance.new("Frame");ctr.BackgroundTransparency=1;ctr.Position=UDim2.fromOffset(0,126);ctr.Size=UDim2.new(1,0,0,42);ctr.Parent=pp;local cl=listLayout(ctr,6);cl.FillDirection=Enum.FillDirection.Horizontal;cl.HorizontalAlignment=Enum.HorizontalAlignment.Center
    local prev=button(ctr,"|◀",UDim2.fromOffset(52,40));local back=button(ctr,"-5",UDim2.fromOffset(48,40));local play=button(ctr,"▶",UDim2.fromOffset(66,40));local fwd=button(ctr,"+5",UDim2.fromOffset(48,40));local nextB=button(ctr,"▶|",UDim2.fromOffset(52,40));self.playButton=play
    prev.Activated:Connect(function()if self.callbacks.onPrev then self.callbacks.onPrev()end end);nextB.Activated:Connect(function()if self.callbacks.onNext then self.callbacks.onNext()end end);back.Activated:Connect(function()if self.callbacks.onSeekRelative then self.callbacks.onSeekRelative(-5)end end);fwd.Activated:Connect(function()if self.callbacks.onSeekRelative then self.callbacks.onSeekRelative(5)end end);play.Activated:Connect(function()if self.callbacks.onPlayPause then self.callbacks.onPlayPause()end end)
    local stop=button(pp,"■ Stop",UDim2.fromOffset(82,34));stop.Position=UDim2.fromOffset(0,178);stop.Activated:Connect(function()if self.callbacks.onStop then self.callbacks.onStop()end end)
    local speed=button(pp,"Speed 1.00×",UDim2.fromOffset(118,34));speed.Position=UDim2.fromOffset(90,178);self.speedButton=speed;speed.Activated:Connect(function()if self.callbacks.onCycleSpeed then self.callbacks.onCycleSpeed()end end)
    local panic=button(pp,"Release",UDim2.fromOffset(90,34));panic.Position=UDim2.fromOffset(216,178);panic.Activated:Connect(function()if self.callbacks.onPanic then self.callbacks.onPanic()end end)
    label(pp,"Part",UDim2.new(1,0,0,22),UDim2.fromOffset(0,222)).TextColor3=C.muted
    local modes=Instance.new("Frame");modes.BackgroundTransparency=1;modes.Position=UDim2.fromOffset(0,247);modes.Size=UDim2.new(1,0,0,78);modes.Parent=pp;local mg=Instance.new("UIGridLayout");mg.CellSize=UDim2.fromOffset(119,32);mg.CellPadding=UDim2.fromOffset(7,7);mg.Parent=modes
    for _,m in ipairs({"Both","Left","Right","Melody","Accompaniment","Bass"})do local b=button(modes,m);b.Activated:Connect(function()if self.callbacks.onMode then self.callbacks.onMode(m)end end)end
    local ab=Instance.new("Frame");ab.BackgroundTransparency=1;ab.Position=UDim2.fromOffset(0,338);ab.Size=UDim2.new(1,0,0,36);ab.Parent=pp;local al=listLayout(ab,6);al.FillDirection=Enum.FillDirection.Horizontal
    local aBtn=button(ab,"Set A",UDim2.fromOffset(76,34));local bBtn=button(ab,"Set B",UDim2.fromOffset(76,34));local clear=button(ab,"Clear A↔B",UDim2.fromOffset(102,34));local abText=label(ab,"A: --  B: --",UDim2.fromOffset(120,34));abText.TextSize=11;abText.TextColor3=C.muted;self.abLabel=abText
    aBtn.Activated:Connect(function()if self.callbacks.onSetA then self.callbacks.onSetA()end end);bBtn.Activated:Connect(function()if self.callbacks.onSetB then self.callbacks.onSetB()end end);clear.Activated:Connect(function()if self.callbacks.onClearAB then self.callbacks.onClearAB()end end)
    local exp1=button(pp,"Export QWERTY",UDim2.fromOffset(126,34));exp1.Position=UDim2.fromOffset(0,388);local exp2=button(pp,"Export analysis",UDim2.fromOffset(126,34));exp2.Position=UDim2.fromOffset(134,388);exp1.Activated:Connect(function()if self.callbacks.onExportSequence then self.callbacks.onExportSequence()end end);exp2.Activated:Connect(function()if self.callbacks.onExportAnalysis then self.callbacks.onExportAnalysis()end end)
    local currentNotes=label(pp,"Keys: —",UDim2.new(1,0,0,32),UDim2.fromOffset(0,430));currentNotes.TextColor3=C.accent2;currentNotes.TextSize=12;self.currentNotes=currentNotes
    local perf=label(pp,"Performance ready",UDim2.new(1,0,0,55),UDim2.fromOffset(0,462));perf.TextWrapped=true;perf.TextYAlignment=Enum.TextYAlignment.Top;perf.TextColor3=C.muted;perf.TextSize=11;self.performanceInfo=perf

    -- PARTS
    local parts=self.pages.Parts;local split=label(parts,"Hand split: waiting",UDim2.new(1,0,0,28));split.Font=Enum.Font.GothamBold;self.splitLabel=split
    local confidence=label(parts,"",UDim2.new(1,0,0,24),UDim2.fromOffset(0,28));confidence.TextColor3=C.muted;confidence.TextSize=11;self.confidenceLabel=confidence
    local channelBox=Instance.new("Frame");channelBox.BackgroundTransparency=1;channelBox.Position=UDim2.fromOffset(0,57);channelBox.Size=UDim2.new(1,0,0,72);channelBox.Parent=parts;local cg=Instance.new("UIGridLayout");cg.CellSize=UDim2.fromOffset(43,28);cg.CellPadding=UDim2.fromOffset(4,4);cg.Parent=channelBox;self.channelBox=channelBox
    local trackList=scroll(parts);trackList.Position=UDim2.fromOffset(0,138);trackList.Size=UDim2.new(1,0,1,-138);listLayout(trackList,7);self.trackList=trackList

    -- PIANO
    local piano=self.pages.Piano;local profileName=label(piano,"Profile",UDim2.new(1,0,0,30));profileName.Font=Enum.Font.GothamBold;self.profileName=profileName
    local ph=label(piano,"Edit a mapping token and leave the field to save it. One character per MIDI note.",UDim2.new(1,0,0,48),UDim2.fromOffset(0,32));ph.TextWrapped=true;ph.TextColor3=C.muted;ph.TextSize=11
    local profileList=scroll(piano);profileList.Position=UDim2.fromOffset(0,86);profileList.Size=UDim2.new(1,0,1,-86);listLayout(profileList,5);self.profileList=profileList

    -- HUMAN
    local hp=self.pages.Human;label(hp,"Human performance",UDim2.new(1,0,0,30)).Font=Enum.Font.GothamBold
    local hd=label(hp,"The MIDI stays the ground truth. Variation is limited to subtle musical timing/duration/chord spread.",UDim2.new(1,0,0,52),UDim2.fromOffset(0,32));hd.TextWrapped=true;hd.TextColor3=C.muted;hd.TextSize=11
    local preset=Instance.new("Frame");preset.BackgroundTransparency=1;preset.Position=UDim2.fromOffset(0,94);preset.Size=UDim2.new(1,0,0,88);preset.Parent=hp;local pg=Instance.new("UIGridLayout");pg.CellSize=UDim2.fromOffset(122,36);pg.CellPadding=UDim2.fromOffset(7,7);pg.Parent=preset
    for _,p in ipairs({"Exact","Very Subtle","Natural","Expressive"})do local b=button(preset,p);b.Activated:Connect(function()if self.callbacks.onPreset then self.callbacks.onPreset(p)end end)end
    local strength=label(hp,"Humanization: 22%",UDim2.new(1,0,0,34),UDim2.fromOffset(0,205));self.strengthLabel=strength;local minus=button(hp,"−",UDim2.fromOffset(48,36));minus.Position=UDim2.fromOffset(0,247);local plus=button(hp,"+",UDim2.fromOffset(48,36));plus.Position=UDim2.fromOffset(58,247);minus.Activated:Connect(function()if self.callbacks.onHumanDelta then self.callbacks.onHumanDelta(-.02)end end);plus.Activated:Connect(function()if self.callbacks.onHumanDelta then self.callbacks.onHumanDelta(.02)end end)
    local hs=label(hp,"Auto seed creates a slightly different interpretation each time playback starts from the beginning.",UDim2.new(1,0,0,60),UDim2.fromOffset(0,310));hs.TextWrapped=true;hs.TextColor3=C.muted

    -- SETTINGS
    local setp=self.pages.Settings;label(setp,"Playback",UDim2.new(1,0,0,30)).Font=Enum.Font.GothamBold
    local transpose=label(setp,"Transpose: 0",UDim2.fromOffset(165,34),UDim2.fromOffset(0,48));self.transposeLabel=transpose;local tm=button(setp,"−",UDim2.fromOffset(42,34));tm.Position=UDim2.fromOffset(175,48);local tp=button(setp,"+",UDim2.fromOffset(42,34));tp.Position=UDim2.fromOffset(225,48);tm.Activated:Connect(function()if self.callbacks.onTransposeDelta then self.callbacks.onTransposeDelta(-1)end end);tp.Activated:Connect(function()if self.callbacks.onTransposeDelta then self.callbacks.onTransposeDelta(1)end end)
    local range=button(setp,"Range: SmartOctave",UDim2.fromOffset(190,36));range.Position=UDim2.fromOffset(0,98);self.rangeButton=range;range.Activated:Connect(function()if self.callbacks.onCycleRange then self.callbacks.onCycleRange()end end)
    local quant=button(setp,"Quantize: Off",UDim2.fromOffset(190,36));quant.Position=UDim2.fromOffset(0,145);self.quantButton=quant;quant.Activated:Connect(function()if self.callbacks.onCycleQuantization then self.callbacks.onCycleQuantization()end end)
    local mk=label(setp,"Max simultaneous keys: 10",UDim2.fromOffset(205,36),UDim2.fromOffset(0,197));self.maxKeysLabel=mk;local km=button(setp,"−",UDim2.fromOffset(42,34));km.Position=UDim2.fromOffset(215,197);local kp=button(setp,"+",UDim2.fromOffset(42,34));kp.Position=UDim2.fromOffset(265,197);km.Activated:Connect(function()if self.callbacks.onMaxKeysDelta then self.callbacks.onMaxKeysDelta(-1)end end);kp.Activated:Connect(function()if self.callbacks.onMaxKeysDelta then self.callbacks.onMaxKeysDelta(1)end end)
    local backend=label(setp,"Input backend: detecting…",UDim2.new(1,0,0,38),UDim2.fromOffset(0,260));backend.TextColor3=C.muted;self.backendLabel=backend
    local folder=label(setp,"MIDI folder: Delta/Workspace/MIDI/",UDim2.new(1,0,0,50),UDim2.fromOffset(0,306));folder.TextWrapped=true;folder.TextColor3=C.muted

    -- DIAG
    local dp=self.pages.Diag;label(dp,"Diagnostics",UDim2.new(1,0,0,30)).Font=Enum.Font.GothamBold;local diag=label(dp,"No performance loaded.",UDim2.new(1,0,1,-40),UDim2.fromOffset(0,40));diag.TextYAlignment=Enum.TextYAlignment.Top;diag.TextWrapped=true;diag.TextColor3=C.muted;diag.TextSize=12;self.diagLabel=diag

    -- MINI/HIDDEN
    local mini=Instance.new("Frame");mini.AnchorPoint=Vector2.new(.5,1);mini.Position=UDim2.new(.5,0,1,-18);mini.Size=UDim2.fromOffset(360,72);mini.BackgroundColor3=C.bg;corner(mini,14);stroke(mini);mini.Visible=false;mini.Parent=gui;self.mini=mini
    local miniName=label(mini,"No MIDI",UDim2.new(1,-130,0,28),UDim2.fromOffset(14,8));miniName.Font=Enum.Font.GothamBold;self.miniName=miniName;local miniTime=label(mini,"00:00",UDim2.new(1,-130,0,22),UDim2.fromOffset(14,38));miniTime.TextColor3=C.muted;self.miniTime=miniTime
    local miniPlay=button(mini,"▶",UDim2.fromOffset(48,44));miniPlay.Position=UDim2.new(1,-110,0,14);miniPlay.Activated:Connect(function()if self.callbacks.onPlayPause then self.callbacks.onPlayPause()end end);local expand=button(mini,"⌃",UDim2.fromOffset(48,44));expand.Position=UDim2.new(1,-56,0,14);expand.Activated:Connect(function()self:setState("Full")end)
    local floating=button(gui,"♫",UDim2.fromOffset(54,54));floating.BackgroundColor3=C.accent;floating.Position=UDim2.fromScale(config.ui.floatingX or .88,config.ui.floatingY or .55);corner(floating,27);floating.Visible=false;self.floating=floating
    local dragging,dragStart,startPos=false,nil,nil;floating.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true;dragStart=i.Position;startPos=floating.Position end end);floating.InputEnded:Connect(function(i)if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end);UIS.InputChanged:Connect(function(i)if dragging and (i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement)then local d=i.Position-dragStart;floating.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)end end);floating.Activated:Connect(function()self:setState("Full")end);miniBtn.Activated:Connect(function()self:setState("Mini")end);hideBtn.Activated:Connect(function()self:setState("Hidden")end)
    showTab("Songs");self:setState(config.ui.state or "Full");return self
end

function App:setState(state)if state~="Full" and state~="Mini" and state~="Hidden" then state="Full" end;self.main.Visible=state=="Full";self.mini.Visible=state=="Mini";self.floating.Visible=state=="Hidden";self.config.ui.state=state;if self.callbacks.onUiState then self.callbacks.onUiState(state,self.floating.Position)end end
function App:_renderSongs()
    for _,c in ipairs(self.songList:GetChildren())do if c:IsA("Frame") then c:Destroy()end end
    local q=string.lower(self.searchBox and self.searchBox.Text or "")
    local list={};for _,item in ipairs(self.allSongs or {})do local ok=q=="" or string.find(string.lower(item.name),q,1,true);if self.songFilter=="Favorites" then ok=ok and item.favorite elseif self.songFilter=="Recent" then ok=ok and item.recentRank~=nil end;if ok then list[#list+1]=item end end
    if self.songFilter=="Recent" then table.sort(list,function(a,b)return (a.recentRank or 999)<(b.recentRank or 999)end)end
    for _,item in ipairs(list)do local row=Instance.new("Frame");row.BackgroundColor3=C.panel2;row.Size=UDim2.new(1,-5,0,44);corner(row,9);row.Parent=self.songList;local sel=button(row,"   "..item.name,UDim2.new(1,-50,1,0));sel.BackgroundTransparency=1;sel.TextXAlignment=Enum.TextXAlignment.Left;sel.Activated:Connect(function()if self.callbacks.onSelectSong then self.callbacks.onSelectSong(item)end end);local star=button(row,item.favorite and "★" or "☆",UDim2.fromOffset(44,36));star.Position=UDim2.new(1,-46,0,4);star.BackgroundTransparency=1;star.TextColor3=item.favorite and C.accent2 or C.muted;star.Activated:Connect(function()if self.callbacks.onToggleFavorite then self.callbacks.onToggleFavorite(item)end end)end
end
function App:setSongs(songs,msg)self.allSongs=songs or {};self.songStatus.Text=msg or (#self.allSongs.." MIDI file(s)");self:_renderSongs()end
function App:setSong(item,a,mapStats,perfStats)self.song=item;local name=item and item.name or "No MIDI";self.songName.Text=name;self.miniName.Text=name;self:setFavorite(item and item.favorite);if a then self.songInfo.Text=string.format("%.1fs • %d notes • %d tracks • poly %d • %d voices",a.duration,a.noteCount,#a.tracks,a.peakPolyphony,a.voiceCount or 0);self.splitLabel.Text="Hand split: MIDI "..tostring(a.handSplit or "?");self.confidenceLabel.Text=string.format("Hand confidence: %.0f%%",(a.handConfidence or 0)*100)end;if mapStats then self.performanceInfo.Text=string.format("Mapped %d/%d (%.1f%%) • adapted %d • dropped %d • simplified %d\nSeed %s • smart transpose %+d",mapStats.mapped,mapStats.total,mapStats.coverage*100,mapStats.adapted,mapStats.dropped,mapStats.simplified or 0,tostring(perfStats and perfStats.seed or "-"),mapStats.smartTranspose or 0)end end
function App:setFavorite(v)self.favoriteButton.Text=v and "★" or "☆";self.favoriteButton.TextColor3=v and C.accent2 or C.text end
function App:setAnalysis(a,enabledTracks,enabledChannels)
    for _,c in ipairs(self.trackList:GetChildren())do if c:IsA("GuiButton") then c:Destroy()end end;for _,c in ipairs(self.channelBox:GetChildren())do if c:IsA("GuiButton") then c:Destroy()end end
    local channels={};for i,info in ipairs(a.tracks or {})do local en=enabledTracks[i]~=false;local row=button(self.trackList,(en and "✓  " or "○  ")..(info.name or("Track "..i)).." • "..tostring(info.noteCount or 0),UDim2.new(1,-5,0,40));row.TextXAlignment=Enum.TextXAlignment.Left;row.Activated:Connect(function()en=not en;row.Text=(en and "✓  " or "○  ")..(info.name or("Track "..i)).." • "..tostring(info.noteCount or 0);if self.callbacks.onToggleTrack then self.callbacks.onToggleTrack(i,en)end end);for ch,v in pairs(info.channels or {})do if v then channels[tonumber(ch) or ch]=true end end end
    local chList={};for ch in pairs(channels)do chList[#chList+1]=ch end;table.sort(chList);for _,ch in ipairs(chList)do local en=enabledChannels[ch]~=false;local b=button(self.channelBox,(en and "✓" or "○")..ch,UDim2.fromOffset(43,28));b.TextSize=10;b.Activated:Connect(function()en=not en;b.Text=(en and "✓" or "○")..ch;if self.callbacks.onToggleChannel then self.callbacks.onToggleChannel(ch,en)end end)end
end
function App:setProfile(p)if not p then return end;self.profileName.Text=(p.name or p.id).."  •  MIDI "..p.lowest.."–"..p.highest;for _,c in ipairs(self.profileList:GetChildren())do if c:IsA("Frame") then c:Destroy()end end;for note=p.lowest,p.highest do local row=Instance.new("Frame");row.BackgroundColor3=C.panel2;row.Size=UDim2.new(1,-5,0,34);corner(row,8);row.Parent=self.profileList;local n=label(row,"MIDI "..note,UDim2.fromOffset(100,34),UDim2.fromOffset(10,0));n.TextSize=12;local box=Instance.new("TextBox");box.BackgroundColor3=C.bg;box.Position=UDim2.fromOffset(112,4);box.Size=UDim2.fromOffset(70,26);box.Text=tostring(p.map[note] or "");box.ClearTextOnFocus=false;textStyle(box,13);corner(box,6);box.Parent=row;box.FocusLost:Connect(function()local token=box.Text;if #token>1 then token=string.sub(token,1,1);box.Text=token end;if self.callbacks.onProfileMapping then self.callbacks.onProfileMapping(note,token)end end)end end
function App:setProgress(pos,dur,stats,playing)local ratio=dur>0 and math.clamp(pos/dur,0,1)or 0;self.progress.Size=UDim2.fromScale(ratio,1);local t=formatTime(pos).." / "..formatTime(dur);self.timeLabel.Text=t;self.miniTime.Text=t;self.playButton.Text=playing and "Ⅱ" or "▶";if stats then local avg=stats.processed>0 and stats.driftSumMs/stats.processed or 0;self.diagLabel.Text=string.format("Processed: %d\nSkipped: %d\nLate: %d\nAverage scheduler lateness: %.2f ms\nPeak scheduler lateness: %.2f ms",stats.processed,stats.skipped,stats.late,avg,stats.driftPeakMs)end end
function App:setBackend(v)self.backendLabel.Text="Input backend: "..tostring(v)end
function App:setSpeed(v)self.speedButton.Text=string.format("Speed %.2f×",v)end
function App:setHumanStrength(v)self.strengthLabel.Text=string.format("Humanization: %d%%",math.floor(v*100+.5))end
function App:setTranspose(v)self.transposeLabel.Text="Transpose: "..tostring(v)end
function App:setRange(v)self.rangeButton.Text="Range: "..tostring(v)end
function App:setQuantization(v)self.quantButton.Text="Quantize: "..tostring(v)end
function App:setMaxKeys(v)self.maxKeysLabel.Text="Max simultaneous keys: "..tostring(v)end
function App:setAB(a,b)self.abLabel.Text="A: "..(a and formatTime(a)or "--").."  B: "..(b and formatTime(b)or "--")end
function App:setActiveNotes(list)self.currentNotes.Text="Keys: "..(#list>0 and table.concat(list," ")or "—")end
function App:setMessage(msg)self.message.Text=tostring(msg or "")end
function App:setError(msg)self.songStatus.Text="Error: "..tostring(msg);self.songStatus.TextColor3=C.danger end
function App:destroy()if self.gui then self.gui:Destroy()end end
return App
