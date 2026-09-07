local Main={}
function Main.start(ctx)
 local R=ctx.Require;local FS=R('Storage/FileSystem');local G=R('Profiles/GameProfile');local Defaults=R('ConfigDefaults');local Human=R('Performance/Humanizer');local Pipeline=R('Performance/PerformanceTimeline')
 FS.ensureFolder('MIDIQWERTY')
 -- Development config is isolated from stable; old versions can still run unchanged.
 local global=G.merge(G.copy(Defaults),FS.loadJson('MIDIQWERTY/settings-v070.json',{}))
 local gameProfiles=G.new(FS,game.GameId,game.PlaceId)
 local library=R('Storage/Library').new(FS);library.data.songOverridesV070=library.data.songOverridesV070 or {}
 local config=G.resolve(global,gameProfiles:get(),nil)
 local function normalize()for _,k in ipairs({'enabledTracks','enabledChannels'})do local map={};for n,v in pairs(config.parts[k]or {})do map[tonumber(n)or n]=v end;config.parts[k]=map end end
 normalize()
 local profiles=R('Piano/ProfileStore').new(FS,R('Piano/Profiles'))
 local adapter=R('Input/InputAdapter').new();local manager=R('Player/NoteManager').new(adapter);local scheduler=R('Player/Scheduler').new(manager)
 local state=R('State/PlayerState').new({song=false,playing=false,position=0,duration=0,speed=config.playback.speed,loop=config.playback.loopSong,hands=config.playback.mode,humanPreset=config.humanize.preset,humanStrength=config.humanize.strength,performanceSeed=0,uiMode='Full'})
 local cloud=R('Cloud/DodoProvider').new(R,FS,config.cloud)
 local current,timeline,app;local songs={};local queue={};local destroyed=false
 local function saveGlobal()FS.saveJson('MIDIQWERTY/settings-v070.json',global)end
 local function toast(text)if app then app:toast(text)end end
 local function sync()
  state:patch({song=current and current.item or false,playing=scheduler:isPlaying(),position=scheduler:getPosition(),duration=timeline and timeline.duration or 0,speed=config.playback.speed,loop=config.playback.loopSong,hands=config.playback.mode,humanPreset=config.humanize.preset,humanStrength=config.humanize.strength,performanceSeed=current and current.seed or 0})
 end
 local function resolvedProfile()return profiles:get(config.pianoProfile)or profiles:get(Defaults.pianoProfile)end
 local function rebuild(keep,newSeed)
  if not current then sync();return end
  local pos=scheduler:getPosition();local playing=scheduler:isPlaying()
  local seed=current.seed
  if newSeed or not seed then seed=config.humanize.seedMode=='Fixed' and config.humanize.fixedSeed or Human.autoSeed()end
  local ok,result=pcall(Pipeline.build,R,current.analysis,current.tempo,config,resolvedProfile(),seed)
  if not ok then toast('Falha na interpretação; reprodução anterior preservada.');warn(result);return false end
  current.seed=seed;timeline=result;scheduler:setEvents(timeline.events,timeline.duration);scheduler:setOptions(config.playback);scheduler:setSpeed(config.playback.speed);scheduler:setAB(config.playback.loopA,config.playback.loopB)
  if keep then scheduler:seek(math.min(pos,timeline.duration),false)end
  app:setTimeline(timeline,resolvedProfile());if playing then scheduler:play()end;sync();return true
 end
 local function scan()
  songs=FS.scanMidi(config.midiFolders);local ranks={};for i,v in ipairs(library.data.recent)do ranks[v.path]=i end
  for _,s in ipairs(songs)do s.favorite=library:isFavorite(s.path);s.recentRank=ranks[s.path];local m=library.data.metadata and library.data.metadata[s.path];if m then s.duration=m.duration;s.bpm=m.bpm end end
  app:setSongs(songs)
 end
 local function updateConfig(nextConfig)
  table.clear(config);G.merge(config,nextConfig);normalize()
 end
 local function selectSong(item,play)
  local data,err=FS.read(item.path);if not data then toast('Não foi possível ler o MIDI.');warn(err);return false end
  local ok,result=pcall(function()local midi=R('MIDI/Parser').parse(data);local tempo=R('MIDI/TempoMap').new(midi);return {midi=midi,tempo=tempo,analysis=R('MIDI/Analyzer').analyze(midi,tempo)}end)
  if not ok then toast('Arquivo MIDI inválido.');warn(result);return false end
  scheduler:stop();current={item=item,analysis=result.analysis,tempo=result.tempo,midi=result.midi}
  updateConfig(G.resolve(global,gameProfiles:get(),library.data.songOverridesV070[item.path]))
  if not rebuild(false,true)then return false end
  library:touch(item.path);library.data.metadata=library.data.metadata or {};library.data.metadata[item.path]={duration=result.analysis.duration,bpm=math.floor(result.analysis.bpmMin or 120)};library:save();scan()
  state:patch({metadata=string.format('%s · %d BPM · %d notas',app:time(timeline.duration),math.floor(result.analysis.bpmMin or 120),#timeline.notes)})
  app:showTab('Player');if play then scheduler:play()end;sync();toast('MIDI carregado.');return true
 end
 local function subset()
  return {pianoProfile=config.pianoProfile,playback=G.copy(config.playback),parts=G.copy(config.parts),humanize=G.copy(config.humanize)}
 end
 local cb={}
 cb.position=function()return scheduler:getPosition()end
 cb.selectSong=selectSong;cb.refresh=scan
 cb.saveUI=function(ui)global.ui=G.copy(ui);saveGlobal()end
 cb.playPause=function()
  if not current then toast('Escolha uma música.');return end
  if scheduler:isPlaying()then scheduler:pause()else scheduler:play()end;sync()
 end
 cb.seek=function(t)if current then scheduler:seek(t,scheduler:isPlaying());sync()end end
 cb.setSpeed=function(v)if type(v)~='number' or v~=v then return end;config.playback.speed=math.clamp(v,.25,2);scheduler:setSpeed(config.playback.speed);sync()end
 cb.speedStep=function(direction)cb.setSpeed(math.floor((config.playback.speed+direction*.05)*100+.5)/100)end
 cb.hands=function(v)config.playback.mode=v;rebuild(true,false);sync()end
 cb.preset=function(v)config.humanize=Human.applyPreset(config.humanize,v);rebuild(true,false);sync()end
 cb.strength=function(v)config.humanize.strength=math.clamp(v,0,1);rebuild(true,false);sync()end
 cb.newPerformance=function()if config.humanize.seedMode=='Fixed'then toast('Seed fixa: interpretação reproduzível.');else rebuild(true,true);toast('Nova interpretação criada.')end end
 cb.humanParameter=function(k,v)config.humanize=Human.applyPreset(config.humanize,config.humanize.preset);config.humanize.preset='Custom';config.humanize[k]=v;rebuild(true,false);sync()end
 cb.seed=function(v)config.humanize.seedMode=v and 'Fixed' or 'Auto';if v then config.humanize.fixedSeed=math.clamp(v,1,2147483646)end;rebuild(true,true);sync()end
 cb.track=function(index,on)config.parts.enabledTracks[index]=on;rebuild(true,false)end
 cb.split=function(n)config.parts.splitMode=n and 'Fixed' or 'Auto';config.parts.splitNote=n or 60;rebuild(true,false)end
 cb.analysis=function()return current and current.analysis end
 cb.transpose=function(v)config.playback.transpose=v;rebuild(true,false)end
 cb.range=function(v)config.playback.rangeMode=v;rebuild(true,false)end
 cb.maxKeys=function(v)config.playback.maxSimultaneousKeys=v;rebuild(true,false)end
 cb.panic=function()scheduler:pause();manager:releaseAll();sync();toast('Teclas liberadas.')end
 cb.loop=function()config.playback.loopSong=not config.playback.loopSong;scheduler:setOptions(config.playback);sync()end
 cb.markA=function()config.playback.loopA=scheduler:getPosition();toast('Início A marcado.')end
 cb.markB=function()config.playback.loopB=scheduler:getPosition();scheduler:setAB(config.playback.loopA,config.playback.loopB);toast(scheduler.loopB and 'Trecho A–B ativado.'or 'Marque B depois de A.')end
 cb.clearAB=function()config.playback.loopA=nil;config.playback.loopB=nil;scheduler:setAB(nil,nil);toast('Trecho A–B removido.')end
 cb.favorite=function(item)library:toggleFavorite(item.path);scan()end
 cb.enqueue=function(song,first)if first then table.insert(queue,1,song)else queue[#queue+1]=song end;toast('Música adicionada à fila.')end
 cb.queue=function()return queue end
 cb.removeQueue=function(i)table.remove(queue,i)end
 local function step(d)
  local index=0;for i,s in ipairs(songs)do if current and s.path==current.item.path then index=i end end
  if #songs>0 then selectSong(songs[(index-1+d)%#songs+1],scheduler:isPlaying())end
 end
 cb.next=function()if #queue>0 then selectSong(table.remove(queue,1),true)else step(1)end end
 cb.previous=function()step(-1)end
 cb.saveGame=function()local ok=gameProfiles:save(subset());toast(ok and 'Perfil do jogo salvo.'or 'Não foi possível salvar o perfil.')end
 cb.saveSong=function()if not current then toast('Selecione uma música.');return end;library.data.songOverridesV070[current.item.path]=subset();library:save();toast('Ajustes da música salvos.')end
 cb.resetOverrides=function()gameProfiles:save({});if current then library.data.songOverridesV070[current.item.path]=nil;library:save()end;updateConfig(G.copy(global));rebuild(true,false);sync();toast('Padrões globais restaurados.')end
 cb.profileCopy=function()return G.copy(resolvedProfile())end
 cb.testToken=function(token)scheduler:pause();manager:releaseAll();manager:tap(token);sync();toast('Tecla de teste enviada: '..token)end
 cb.saveCalibration=function(p)
  for n=p.lowest,p.highest do if not p.map[n]then toast('Há notas sem mapeamento neste alcance.');return false end end
  p.id='Game_'..tostring(game.GameId)..'_'..tostring(game.PlaceId);p.name='Piano deste jogo';profiles:saveProfile(p);config.pianoProfile=p.id;cb.saveGame();rebuild(true,false);return true
 end
 cb.reconnect=function()scheduler:pause();manager:releaseAll();adapter=R('Input/InputAdapter').new();manager.adapter=adapter;sync();toast('Input reinicializado.')end
 cb.exportPerformance=function()if timeline then local ok=FS.write('MIDIQWERTY/performance.csv',Pipeline.csv(timeline));toast(ok and 'Análise salva em MIDIQWERTY/performance.csv'or 'Não foi possível salvar a análise.')end end
 cb.cancelCloud=function()cloud:cancel()end
 cb.searchCloud=function(q)cloud:search(q,function(results,err)if not destroyed then app:setCloud(results,err or cloud.lastError)end end)end
 cb.download=function(song)cloud:download(song,function(path,err)if not destroyed then if path then scan();toast('MIDI baixado.')else toast(err or 'Cloud indisponível.')end end end)end
 cb.diagnostics=function()
  local c=cloud:diagnostics();local stats=scheduler.stats;local m=timeline and timeline.mapping or {};local p=timeline and timeline.stats or {}
  return string.format('Backend: %s\nCloud: %s\n%s\n\nEventos: %d\nAtrasados: %d\nDrift pico: %.2f ms\nCobertura: %.1f%%\nColisões: %d\nTiming médio: %.3f ms\nSeed: %s\n\nPrioridade: global → jogo → música\nVelocity física depende do piano/backend.\nPedal preservado nos dados; não há CC64 universal via QWERTY.',adapter.backend,c.state,c.error or '',stats.processed,stats.late,stats.driftPeakMs,(m.coverage or 0)*100,m.collisions or 0,p.averageTimingMs or 0,tostring(current and current.seed or '—'))
 end
 app=R('UI/App').new(R,state,cb,config)
 scheduler.onPosition=function()sync()end
 scheduler.onFinished=function()sync();if #queue>0 then selectSong(table.remove(queue,1),true)end end
 scan();sync()
 local public={app=app,store=state,callbacks=cb}
 function public.show()app:setMode('Full')end
 function public.hide()app:setMode('Hidden')end
 function public.stop()scheduler:stop();sync()end
 function public.state()return state.value end
 function public.destroy()destroyed=true;cloud:cancel();scheduler:stop();manager:releaseAll();app:destroy();state:destroy()end
 function public.runUITest()return R('UI/TestHarness').run(app,state,cb)end
 local env=(getgenv and getgenv())or _G;env.MIDIQWERTY=public;return public
end
return Main
