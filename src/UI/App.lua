local App={};App.__index=App
function App.new(R,state,cb,config)
 local C=R('UI/Components');local Layout=R('UI/Layout');local UIS=game:GetService('UserInputService');local Run=game:GetService('RunService');local Tween=game:GetService('TweenService')
 local self=setmetatable({R=R,C=C,state=state,cb=cb,config=config,windows={},controls={},subscriptions={},connections={},songs={},cloudSongs={},filter='All',source='Local',tab='Library',mode='Full',lastMode='Compact',rolls={},actions={},modal=nil},App)
 self.router=R('UI/InputRouter').new(UIS)
 local gui=C.new('ScreenGui',nil,{Name='MIDIQWERTY_GLASS',ResetOnSpawn=false,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=20000})
 local parent=(gethui and gethui())or game:GetService('CoreGui');if not pcall(function()gui.Parent=parent end)then gui.Parent=game:GetService('Players').LocalPlayer:WaitForChild('PlayerGui')end;self.gui=gui
 self.root=C.new('Frame',gui,{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)})
 local function listen(fn)local off=state:subscribe(fn);self.subscriptions[#self.subscriptions+1]=off end
 local function button(parent,text,fn,primary)local b=C.button(parent,text,fn,primary);return b end
 local function bindDrag(handle,window,mode,tap)
  local origin
  self.router:bind(handle,{begin=function()origin=window.Position end,move=function(p,drag)
   if not drag then return end;local start=self.router.owner.start;local v=self.root.AbsoluteSize
   local x,y=Layout.clamp(origin.X.Offset+p.X-start.X,origin.Y.Offset+p.Y-start.Y,window.AbsoluteSize.X,window.AbsoluteSize.Y,v.X,v.Y);window.Position=UDim2.fromOffset(x,y)
  end,finish=function(_,drag)
   if drag then local v=self.root.AbsoluteSize;config.ui.positions=config.ui.positions or {};config.ui.positions[mode]=Layout.normalized(window.Position.X.Offset,window.Position.Y.Offset,window.AbsoluteSize.X,window.AbsoluteSize.Y,v.X,v.Y);cb.saveUI(config.ui)
   elseif tap then tap()end
  end})
 end
 local function window(mode)
  local w=C.surface(self.root,{Name=mode,Visible=false});self.windows[mode]=w
  local header=C.row(w,48);header.Active=true;header.Position=UDim2.fromOffset(12,4);header.Size=UDim2.new(1,-24,0,48);bindDrag(header,w,mode)
  return w,header
 end
 local full,header=window('Full')
 local brand=C.label(header,'MIDI / QWERTY',15);brand.Font=Enum.Font.GothamBold;brand.Size=UDim2.new(1,-146,1,0)
 local compactButton=button(header,'▣',function()self:setMode('Compact')end);compactButton.Position=UDim2.new(1,-140,0,2)
 local miniButton=button(header,'—',function()self:setMode('Mini')end);miniButton.Position=UDim2.new(1,-92,0,2)
 local hideButton=button(header,'×',function()self:setMode('Hidden')end);hideButton.Position=UDim2.new(1,-44,0,2)
 local nav=C.row(full,44);nav.Position=UDim2.fromOffset(12,56);nav.Size=UDim2.new(1,-24,0,44)
 self.nav=C.segmented(nav,{{label='Músicas',value='Library'},{label='Player',value='Player'},{label='Expressão',value='Performance'},{label='Ajustes',value='Settings'}},function(v)self:showTab(v)end)
 self.pages={}
 for _,name in ipairs({'Library','Player','Performance','Settings'})do
  local p=C.new('ScrollingFrame',full,{Name=name,BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(16,112),Size=UDim2.new(1,-32,1,-128),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,Visible=false});self.pages[name]=p;C.list(p,8)
 end
 local function seek(parent)
  local bar=C.seekbar(parent,self.router,state,cb.seek);self.subscriptions[#self.subscriptions+1]=bar.unsubscribe
  local times=C.row(parent,16);local elapsed=C.label(times,'00:00',11);elapsed.Size=UDim2.fromScale(.5,1);elapsed.TextColor3=C.colors.muted
  local total=C.label(times,'00:00',11);total.Position=UDim2.fromScale(.5,0);total.Size=UDim2.fromScale(.5,1);total.TextXAlignment=Enum.TextXAlignment.Right;total.TextColor3=C.colors.muted
  listen(function(s)elapsed.Text=self:time(s.position);total.Text=self:time(s.duration)end)
 end
 local function speed(parent)
  local speed=C.speed(parent,self.router,state,cb.speedStep,function()self:speedPicker()end,cb.setSpeed);self.subscriptions[#self.subscriptions+1]=speed.unsubscribe;return speed.frame
 end
 local function transport(parent,small)
  local row=C.row(parent,48)
  local prev=button(row,'‹',cb.previous);prev.Position=UDim2.fromOffset(0,2)
  local play=button(row,'▶',cb.playPause,true);play.Position=UDim2.fromOffset(48,0);play.Size=UDim2.fromOffset(64,48);play.TextSize=23
  local next=button(row,'›',cb.next);next.Position=UDim2.fromOffset(104,2);play.Size=UDim2.fromOffset(52,48)
  local speedFrame=speed(row);speedFrame.Position=UDim2.new(1,-152,0,2);speedFrame.Size=UDim2.fromOffset(152,44)
  listen(function(s)play.Text=s.playing and 'Ⅱ' or '▶'end)
  return row
 end
 local function hands(parent)
  local control=C.segmented(parent,{{label='LH',value='Left'},{label='Ambas',value='Both'},{label='RH',value='Right'}},cb.hands);listen(function(s)control.set(s.hands)end);return control.frame
 end
 local function songTitle(parent)
  local title=C.label(parent,'Escolha uma música',17);title.Font=Enum.Font.GothamBold;title.Size=UDim2.new(1,0,0,26)
  listen(function(s)title.Text=s.song and s.song.name or 'Escolha uma música'end);return title
 end
 local function roll(parent,height)
  local r=R('UI/PianoRoll').new(parent,C,R('UI/KeyboardGeometry'));r.frame.Size=UDim2.new(1,0,0,height);self.rolls[#self.rolls+1]=r;return r
 end
 -- Full Player: spacious controls, full roll, secondary tools in a sheet.
 local p=self.pages.Player;songTitle(p)
 local meta=C.label(p,'',12);meta.TextColor3=C.colors.muted;listen(function(s)meta.Text=s.metadata or 'MIDI → interpretação → piano do jogo'end)
 roll(p,124);seek(p);transport(p);hands(p)
 local human=button(p,'Pianist',function()self:humanPicker()end);human.Size=UDim2.new(1,0,0,44)
 listen(function(s)human.Text=(s.humanPreset or 'Exact')..'  ·  '..math.floor((s.humanStrength or 0)*100)..'%   ⌄'end)
 local tools=button(p,'Fila · Loop · Soltar teclas',function()self:playerTools()end);tools.Size=UDim2.new(1,0,0,44)
 -- Compact: no library/sidebar; controls remain outside the roll.
 local compact,ch=window('Compact');local ct=C.label(ch,'',14);ct.Size=UDim2.new(1,-144,1,0);listen(function(s)ct.Text=s.song and s.song.name or 'Escolha uma música'end)
 for i,x in ipairs({{'↗','Full'},{'—','Mini'},{'×','Hidden'}})do local b=button(ch,x[1],function()self:setMode(x[2])end);b.Position=UDim2.new(1,-(4-i)*48+4,0,2)end
 local content=C.new('ScrollingFrame',compact,{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(12,56),Size=UDim2.new(1,-24,1,-66),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=2});C.list(content,2)
 roll(content,76);seek(content);transport(content,true)
 local quick=C.row(content,44);local hf=hands(quick);hf.Size=UDim2.new(.52,-4,1,0)
 local hp=button(quick,'',function()self:humanPicker()end);hp.Position=UDim2.fromScale(.52,0);hp.Size=UDim2.new(.48,0,1,0);hp.TextSize=12
 listen(function(s)hp.Text=(s.humanPreset or 'Exact')..' '..math.floor((s.humanStrength or 0)*100)..'% ⌄'end)
 -- Mini: a distinct two-row transport with seek, no piano roll.
 local mini,mh=window('Mini');local mt=C.label(mh,'',13);mt.Size=UDim2.new(1,-96,1,0);listen(function(s)mt.Text=s.song and s.song.name or 'Nenhuma música'end)
 local expand=button(mh,'↗',function()self:setMode('Compact')end);expand.Position=UDim2.new(1,-92,0,2)
 local hidden=button(mh,'×',function()self:setMode('Hidden')end);hidden.Position=UDim2.new(1,-44,0,2)
 local miniBody=C.new('Frame',mini,{BackgroundTransparency=1,Position=UDim2.fromOffset(12,50),Size=UDim2.new(1,-24,1,-60)});C.list(miniBody,0)
 local miniRow=C.row(miniBody,44);local mp=button(miniRow,'▶',cb.playPause,true);mp.Size=UDim2.fromOffset(54,44);listen(function(s)mp.Text=s.playing and 'Ⅱ' or '▶'end)
 local tm=C.label(miniRow,'',11);tm.Position=UDim2.fromOffset(64,0);tm.Size=UDim2.new(1,-248,1,0);tm.TextWrapped=true;tm.TextTruncate=Enum.TextTruncate.None;listen(function(s)tm.Text=self:time(s.position)..'\n'..self:time(s.duration)end)
 local sp=speed(miniRow);sp.Position=UDim2.new(1,-152,0,0);sp.Size=UDim2.fromOffset(152,44)
 local sb=C.seekbar(miniBody,self.router,state,cb.seek);self.subscriptions[#self.subscriptions+1]=sb.unsubscribe
 -- Hidden restores the preceding playback surface, never Full.
 local bubble=button(self.root,'♪',nil,true);bubble.Name='Hidden';bubble.Size=UDim2.fromOffset(56,56);bubble.TextSize=24;self.windows.Hidden=bubble
 bindDrag(bubble,bubble,'Hidden',function()self:setMode(self.lastMode)end)
 -- Library.
 p=self.pages.Library
 local source=C.segmented(p,{{label='Local',value='Local'},{label='Cloud',value='Cloud'}},function(v)self.source=v;self:renderSongs();if v=='Cloud'then self:searchCloud()end end);self.sourceControl=source;source.set('Local')
 self.search=C.textbox(p,'Buscar música');self.search:GetPropertyChangedSignal('Text'):Connect(function()if self.source=='Local'then self:renderSongs()else self:searchCloud()end end)
 local filters=C.segmented(p,{{label='Todas',value='All'},{label='Recentes',value='Recent'},{label='Favoritas',value='Favorites'}},function(v)self.filter=v;self.filterControl.set(v);self:renderSongs()end);self.filterControl=filters;filters.set('All')
 local refresh=button(p,'Atualizar biblioteca',cb.refresh);refresh.Size=UDim2.new(1,0,0,44)
 self.songList=C.new('Frame',p,{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y});C.list(self.songList,6)
 -- Performance uses presets first; technical knobs remain inside Advanced.
 p=self.pages.Performance
 local intro=C.label(p,'Interpretação musical',20);intro.Size=UDim2.new(1,0,0,30)
 local preset=button(p,'Escolher interpretação',function()self:humanPicker()end);preset.Size=UDim2.new(1,0,0,44)
 local strength=C.label(p,'Intensidade',14)
 local intensity=C.slider(p,self.router,0,1,state.value.humanStrength or 1,cb.strength,function(v)return math.floor(v*100)..'%'end)
 listen(function(s)strength.Text='Intensidade · '..math.floor(s.humanStrength*100)..'%';if not intensity.dragging then intensity:set(s.humanStrength)end end)
 for _,x in ipairs({{'Nova interpretação',cb.newPerformance},{'Tracks e mãos',function()self:tracks()end},{'Advanced ›',function()self:advanced()end}})do local b=button(p,x[1],x[2]);b.Size=UDim2.new(1,0,0,44)end
 -- Settings: persistent choices and technical tools, no status wall.
 p=self.pages.Settings
 for _,x in ipairs({{'Calibrar piano',function()self:calibrate()end},{'Salvar perfil deste jogo',cb.saveGame},{'Salvar ajustes desta música',cb.saveSong},{'Restaurar padrões globais',cb.resetOverrides},{'Conversão e alcance',function()self:conversion()end},{'Reset UI Position',function()config.ui.positions={};self:resize();cb.saveUI(config.ui)end},{'Reconectar input',cb.reconnect},{'Diagnostics',function()self:diagnostics()end},{'Novidades • 0.7.0-rc.1',function()self:changelog()end}})do local b=button(p,x[1],x[2]);b.Size=UDim2.new(1,0,0,44)end
 self.toastLabel=C.label(self.root,'',13);self.toastLabel.Name='Toast';self.toastLabel.Visible=false;self.toastLabel.BackgroundColor3=C.colors.panel;self.toastLabel.BackgroundTransparency=.05;self.toastLabel.TextXAlignment=Enum.TextXAlignment.Center;self.toastLabel.TextWrapped=true;self.toastLabel.Size=UDim2.new(1,-32,0,44);self.toastLabel.Position=UDim2.new(.5,0,1,-56);self.toastLabel.AnchorPoint=Vector2.new(.5,0);self.C.new('UISizeConstraint',self.toastLabel,{MaxSize=Vector2.new(420,44),MinSize=Vector2.new(0,0)});self.toastLabel.ZIndex=40;C.round(self.toastLabel,12)
 self.connections[#self.connections+1]=self.root:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()self:resize()end)
 self.connections[#self.connections+1]=Run.RenderStepped:Connect(function()
  local pos=cb.position();for _,r in ipairs(self.rolls)do if self.mode=='Compact' and r.frame:IsDescendantOf(compact)or self.mode=='Full' and self.tab=='Player' and r.frame:IsDescendantOf(full)then r:update(pos)end end
 end)
 self:resize();self:showTab('Library');self:setMode('Full')
 self.actions={Library=function()self:setMode('Full');self:showTab('Library')end,Player=function()self:setMode('Full');self:showTab('Player')end,Performance=function()self:showTab('Performance')end,Settings=function()self:showTab('Settings')end,Compact=function()self:setMode('Compact')end,Mini=function()self:setMode('Mini')end,Hidden=function()self:setMode('Hidden')end,Restore=function()self:setMode(self.lastMode)end,Seek=function()cb.seek(state.value.duration*.5)end,SpeedPlus=function()cb.speedStep(1)end,SpeedMinus=function()cb.speedStep(-1)end,Play=cb.playPause,Pause=cb.playPause,LH=function()cb.hands('Left')end,RH=function()cb.hands('Right')end,Both=function()cb.hands('Both')end}
 return self
end
function App:time(t)t=math.max(0,t or 0);return string.format('%02d:%02d',math.floor(t/60),math.floor(t%60))end
function App:resize()
 self.router:cancel();local L=self.R('UI/Layout');local v=self.root.AbsoluteSize
 for mode,w in pairs(self.windows)do local width,height=L.bounds(v.X,v.Y,mode);w.Size=UDim2.fromOffset(width,height);local x,y=L.position(v.X,v.Y,width,height,self.config.ui.positions and self.config.ui.positions[mode]);w.Position=UDim2.fromOffset(x,y)end
end
function App:setMode(mode)
 assert(self.windows[mode],'Invalid UI mode');self.router:cancel();self:closeModal()
 if self.mode=='Mini' or self.mode=='Compact'then self.lastMode=self.mode end
 self.mode=mode;for name,w in pairs(self.windows)do w.Visible=name==mode end
 if self.config.ui.transitions~=false then local w=self.windows[mode];local scale=w:FindFirstChild('TransitionScale');if not scale then scale=self.C.new('UIScale',w,{Name='TransitionScale',Scale=1})end;scale.Scale=.98;game:GetService('TweenService'):Create(scale,TweenInfo.new(.15),{Scale=1}):Play()end
 self.state:patch({uiMode=mode});self.config.ui.state=mode;self.cb.saveUI(self.config.ui)
end
function App:showTab(tab)
 self.tab=tab;self.nav.set(tab)
 for name,p in pairs(self.pages)do p.Visible=name==tab;if name==tab and self.config.ui.transitions~=false then p.Position=UDim2.fromOffset(24,112);game:GetService('TweenService'):Create(p,TweenInfo.new(.14),{Position=UDim2.fromOffset(16,112)}):Play()end end
end
function App:toast(message)
 self.toastSequence=(self.toastSequence or 0)+1;local id=self.toastSequence;self.toastLabel.Text=message;self.toastLabel.Visible=true
 task.delay(2.6,function()if not self.destroyed and id==self.toastSequence then self.toastLabel.Visible=false end end)
end
function App:closeModal()if self.modal then self.router:cancel();self.modal:Destroy();self.modal=nil end end
function App:sheet(title)
 self:closeModal();local body;self.modal,body=self.C.modal(self.root,title,function()self:closeModal()end);return body
end
function App:sheetButton(body,text,fn,primary)local b=self.C.button(body,text,fn,primary);b.Size=UDim2.new(1,0,0,44);return b end
function App:speedPicker()
 local b=self:sheet('Velocidade')
 for _,v in ipairs({.25,.5,.75,.9,1,1.1,1.25,1.5,1.75,2})do self:sheetButton(b,string.format('%.2f×',v),function()self.cb.setSpeed(v);self:closeModal()end,v==self.state.value.speed)end
 self.C.slider(b,self.router,.25,2,self.state.value.speed,function(v)self.cb.setSpeed(math.floor(v*100+.5)/100)end,function(v)return string.format('%.2f×',v)end)
end
function App:humanPicker()
 local b=self:sheet('Interpretação')
 for _,v in ipairs({'Exact','Subtle','Natural','Pianist','Expressive','Custom'})do self:sheetButton(b,v,function()self.cb.preset(v);self:closeModal()end,v==self.state.value.humanPreset)end
 self:sheetButton(b,'Nova interpretação',function()self.cb.newPerformance();self:closeModal()end)
end
function App:setSongs(songs)self.songs=songs;self:renderSongs()end
function App:searchCloud()
 self.searchGeneration=(self.searchGeneration or 0)+1;local id=self.searchGeneration;self.cb.cancelCloud()
 task.delay(.4,function()if self.destroyed or id~=self.searchGeneration or self.source~='Cloud'then return end;self.cb.searchCloud(self.search.Text)end)
end
function App:renderSongs()
 self.sourceControl.set(self.source)
 for _,c in ipairs(self.songList:GetChildren())do if not c:IsA('UIListLayout')then c:Destroy()end end
 local songs={};local query=string.lower(self.search.Text)
 for _,s in ipairs(self.source=='Local' and self.songs or self.cloudSongs)do
  if string.find(string.lower(s.name),query,1,true) and (self.filter~='Favorites' or s.favorite)and(self.filter~='Recent' or s.recentRank)then songs[#songs+1]=s end
 end
 if self.filter=='Recent'then table.sort(songs,function(a,b)return a.recentRank<b.recentRank end)end
 if #songs==0 then
  local title=self.C.label(self.songList,self.source=='Cloud' and 'Dodo Cloud indisponível' or '♪  Nenhuma música ainda',18);title.Size=UDim2.new(1,0,0,52)
  local sub=self.C.label(self.songList,self.source=='Cloud' and (self.cloudMessage or 'Consulte Diagnostics para detalhes.')or 'Adicione arquivos .mid em\nDelta/Workspace/MIDI/',13);sub.TextWrapped=true;sub.TextTruncate=Enum.TextTruncate.None;sub.Size=UDim2.new(1,0,0,58);sub.TextColor3=self.C.colors.muted
 end
 for _,song in ipairs(songs)do
  local row=self.C.row(self.songList,60);row.Name='SongRow'
  local name=self.C.label(row,song.name,14);name.Size=UDim2.new(1,-150,0,30)
  local meta=self.C.label(row,song.duration and (self:time(song.duration)..' · '..tostring(song.bpm or '—')..' BPM')or 'MIDI local',11);meta.Position=UDim2.fromOffset(0,30);meta.Size=UDim2.new(1,-150,0,24);meta.TextColor3=self.C.colors.muted
  local fav=self.C.button(row,song.favorite and '★' or '☆',function()self.cb.favorite(song)end);fav.Position=UDim2.new(1,-144,0,8)
  local more=self.C.button(row,'⋯',function()self:songActions(song)end);more.Position=UDim2.new(1,-96,0,8)
  local play=self.C.button(row,'▶',function()if self.source=='Cloud'then self.cb.download(song)else self.cb.selectSong(song,true)end end,true);play.Position=UDim2.new(1,-48,0,8)
 end
end
function App:songActions(song)
 local b=self:sheet(song.name)
 self:sheetButton(b,'Abrir no Player',function()self.cb.selectSong(song,false);self:closeModal()end)
 self:sheetButton(b,'Tocar agora',function()self.cb.selectSong(song,true);self:closeModal()end)
 self:sheetButton(b,'Tocar depois',function()self.cb.enqueue(song,true);self:closeModal()end)
 self:sheetButton(b,'Adicionar à fila',function()self.cb.enqueue(song,false);self:closeModal()end)
end
function App:playerTools()
 local b=self:sheet('Reprodução')
 self:sheetButton(b,'Soltar todas as teclas',function()self.cb.panic();self:closeModal()end)
 self:sheetButton(b,self.state.value.loop and 'Desativar loop' or 'Repetir música',function()self.cb.loop();self:closeModal()end)
 self:sheetButton(b,'Marcar início A',function()self.cb.markA()end);self:sheetButton(b,'Marcar fim B',function()self.cb.markB()end);self:sheetButton(b,'Limpar A–B',self.cb.clearAB)
 for i,s in ipairs(self.cb.queue())do self:sheetButton(b,tostring(i)..' · '..s.name,function()self.cb.removeQueue(i);self:playerTools()end)end
end
function App:tracks()
 local b=self:sheet('Tracks e mãos');local a=self.cb.analysis()
 if not a then self.C.label(b,'Selecione uma música primeiro.',14);return end
 for _,t in ipairs(a.tracks)do local on=self.config.parts.enabledTracks[t.index]~=false;self:sheetButton(b,(on and '● 'or '○ ')..t.name,function()self.cb.track(t.index,not on);self:tracks()end)end
 self:sheetButton(b,'Divisão automática',function()self.cb.split(nil);self:tracks()end)
 local input=self.C.textbox(b,'Divisão manual: nota MIDI (0–127)');input.Text=tostring(self.config.parts.splitNote or 60)
 self:sheetButton(b,'Aplicar divisão manual',function()local n=tonumber(input.Text);if n then self.cb.split(math.clamp(math.floor(n),0,127))end end)
end
function App:advanced()
 local b=self:sheet('Expressão · Advanced')
 for _,x in ipairs({{'timingMs','Tempo global',0,20},{'phraseMs','Frases',0,30},{'rubatoMs','Rubato',0,30},{'handMs','Independência das mãos',0,15},{'chordSpreadMs','Acordes',0,30},{'microMs','Microtiming',0,3},{'durationVariation','Articulação',0,.08},{'velocityPreservation','Preservar velocity',0,1},{'dynamicContour','Dinâmica',0,1},{'motifVariation','Variação de motivos',0,1}})do
  self.C.label(b,x[2],14);self.C.slider(b,self.router,x[3],x[4],self.config.humanize[x[1]] or 0,function(v)self.cb.humanParameter(x[1],v)end)
 end
 local seed=self.C.textbox(b,'Seed numérica');seed.Text=tostring(self.state.value.performanceSeed or 12345)
 self:sheetButton(b,'Usar seed fixa',function()local v=tonumber(seed.Text);if v then self.cb.seed(math.floor(v))end end)
 self:sheetButton(b,'Seed automática',function()self.cb.seed(nil)end)
 self:sheetButton(b,'Exportar análise da interpretação',self.cb.exportPerformance)
end
function App:conversion()
 local b=self:sheet('Piano do jogo')
 self.C.label(b,'Transposição',14);self.C.slider(b,self.router,-24,24,self.config.playback.transpose,function(v)self.cb.transpose(math.floor(v+.5))end)
 for _,v in ipairs({'Strict','SmartOctave','OctaveFold','Clamp'})do self:sheetButton(b,v,function()self.cb.range(v)end)end
 self.C.label(b,'Máximo de teclas simultâneas',14);self.C.slider(b,self.router,1,16,self.config.playback.maxSimultaneousKeys,function(v)self.cb.maxKeys(math.floor(v+.5))end)
end
function App:calibrate(step,draft)
 step=step or 1;draft=draft or self.cb.profileCopy();local tests={60,72,84};local note=tests[step]
 local b=self:sheet(note and ('Calibrar · '..({'C4','C5','C6'})[step])or 'Calibrar · alcance')
 if note then
  local input=self.C.textbox(b,'Tecla QWERTY correspondente');input.Text=draft.map[note] or ''
  self:sheetButton(b,'Testar tecla',function()if #input.Text==1 then self.cb.testToken(input.Text)end end)
  self:sheetButton(b,'Está correto · continuar',function()if #input.Text~=1 then self:toast('Informe uma tecla.');return end;draft.map[note]=input.Text;self:calibrate(step+1,draft)end,true)
 else
  local low=self.C.textbox(b,'Nota mais grave');low.Text=tostring(draft.lowest)
  local high=self.C.textbox(b,'Nota mais aguda');high.Text=tostring(draft.highest)
  self:sheetButton(b,'Salvar perfil deste jogo',function()local l,h=tonumber(low.Text),tonumber(high.Text);if l and h and l>=0 and h<=127 and l<h then draft.lowest=math.floor(l);draft.highest=math.floor(h);if self.cb.saveCalibration(draft)then self:closeModal()end else self:toast('Confira o alcance MIDI.')end end,true)
 end
end
function App:diagnostics()
 local b=self:sheet('Diagnostics');local text=self.C.label(b,self.cb.diagnostics(),12);text.TextWrapped=true;text.TextTruncate=Enum.TextTruncate.None;text.TextYAlignment=Enum.TextYAlignment.Top;text.Size=UDim2.new(1,0,0,360)
end
function App:changelog()
 local b=self:sheet('Novidades · 0.7.0-rc.1');local t=self.C.label(b,'Glass/dark com Full, Compact, Mini e bolha.\n\nVelocidade −/+ sincronizada. Seek com preview e confirmação no release.\n\nInterpretação por frases e motivos. Perfil por jogo e calibração guiada.\n\nRC: testes no Roblox e no aparelho ainda necessários.',14);t.TextWrapped=true;t.TextTruncate=Enum.TextTruncate.None;t.Size=UDim2.new(1,0,0,240);self.config.ui.lastSeenChangelog='0.7.0-rc.1';self.cb.saveUI(self.config.ui)
end
function App:setTimeline(t,profile)for _,r in ipairs(self.rolls)do r:setTimeline(t,profile)end end
function App:setCloud(results,message)self.cloudSongs=results or {};self.cloudMessage=message;self:renderSongs()end
function App:destroy()self.destroyed=true;self.router:destroy();for _,off in ipairs(self.subscriptions)do off()end;for _,c in ipairs(self.connections)do c:Disconnect()end;self.gui:Destroy()end
return App
