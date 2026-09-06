local Main={}

local function deepCopy(v)
    if type(v)~="table"then return v end
    local o={};for k,x in pairs(v)do o[k]=deepCopy(x)end;return o
end
local function merge(dst,src)
    if type(src)~="table"then return dst end
    for k,v in pairs(src)do if type(v)=="table"and type(dst[k])=="table"then merge(dst[k],v)else dst[k]=deepCopy(v)end end
    return dst
end
local function normalizeBoolMap(t)local o={};for k,v in pairs(t or {})do o[tonumber(k)or k]=v end;return o end

function Main.start(ctx)
    local R=ctx.Require
    local Defaults=R("ConfigDefaults");local FS=R("Storage/FileSystem");local Cache=R("Storage/Cache");local Library=R("Storage/Library")
    local Parser=R("MIDI/Parser");local TempoMap=R("MIDI/TempoMap");local Analyzer=R("MIDI/Analyzer")
    local Separator=R("Parts/Separator");local VoiceSeparator=R("Parts/VoiceSeparator")
    local Articulation=R("Performance/Articulation");local PhraseEngine=R("Performance/PhraseEngine");local Simplifier=R("Performance/Simplifier");local Quantizer=R("Performance/Quantizer");local Humanizer=R("Performance/Humanizer")
    local Profiles=R("Piano/Profiles");local ProfileStore=R("Piano/ProfileStore");local Mapper=R("Piano/Mapper")
    local InputAdapter=R("Input/InputAdapter");local NoteManager=R("Player/NoteManager");local Scheduler=R("Player/Scheduler");local UI=R("UI/App")
    local Dodo=R("Cloud/DodoProvider")

    FS.ensureFolder("MIDIQWERTY")
    local persisted=FS.loadJson("MIDIQWERTY/config.json",{})
    local config=merge(deepCopy(Defaults),persisted)
    if tonumber(persisted.version or 0)<12 then
        local keep={pianoProfile=persisted.pianoProfile,playback=persisted.playback,parts=persisted.parts,ui=persisted.ui}
        config=deepCopy(Defaults)
        if keep.pianoProfile then config.pianoProfile=keep.pianoProfile end
        if type(keep.playback)=="table"then
            for _,k in ipairs({"speed","transpose","rangeMode","maxSimultaneousKeys","loopSong"})do if keep.playback[k]~=nil then config.playback[k]=keep.playback[k]end end
        end
        if type(keep.parts)=="table"then config.parts.enabledTracks=normalizeBoolMap(keep.parts.enabledTracks);config.parts.enabledChannels=normalizeBoolMap(keep.parts.enabledChannels)end
        if type(keep.ui)=="table"then config.ui.floatingX=keep.ui.floatingX or config.ui.floatingX;config.ui.floatingY=keep.ui.floatingY or config.ui.floatingY end
    end
    config.version=12;config.ui=config.ui or {};config.ui.state="Full";config.parts.enabledTracks=normalizeBoolMap(config.parts.enabledTracks);config.parts.enabledChannels=normalizeBoolMap(config.parts.enabledChannels)
    FS.saveJson("MIDIQWERTY/config.json",config)

    local library=Library.new(FS);local profileStore=ProfileStore.new(FS,Profiles);local adapter=InputAdapter.new();local noteManager=NoteManager.new(adapter);local scheduler=Scheduler.new(noteManager);local cloud=Dodo.new(FS,config.cloud)
    local app,current,mappedNotes,songs,currentIndex=nil,nil,{}, {},nil
    local rangeSteps={"SmartOctave","OctaveFold","Strict","Clamp"};local quantSteps={"Off","1/8","1/16","1/32"}

    local function saveConfig()FS.saveJson("MIDIQWERTY/config.json",config)end
    local function averageBpm(a)if a and a.bpmMin and a.bpmMax then return(a.bpmMin+a.bpmMax)/2 end;return 120 end
    local function saveOverride(k,v)if current then library:setOverride(current.item.path,k,v)end end
    local function applySongOverride(path)
        local o=library:getOverride(path)
        if o.transpose~=nil then config.playback.transpose=o.transpose end;if o.rangeMode then config.playback.rangeMode=o.rangeMode end;if o.splitMode then config.parts.splitMode=o.splitMode end;if o.splitNote then config.parts.splitNote=o.splitNote end;if o.pianoProfile then config.pianoProfile=o.pianoProfile end
        if o.enabledTracks then config.parts.enabledTracks=normalizeBoolMap(o.enabledTracks)end;if o.enabledChannels then config.parts.enabledChannels=normalizeBoolMap(o.enabledChannels)end
    end
    local function enrichAnalysis(a)
        Separator.classify(a,config.parts);local _,vc=VoiceSeparator.assign(a.notes,.03);a.voiceCount=vc;Articulation.annotate(a.notes);PhraseEngine.annotate(a.notes,averageBpm(a));return a
    end

    local function rebuildPerformance(keepPosition,newSeed)
        if not current then return end
        local pos=scheduler:getPosition();local was=scheduler:isPlaying();scheduler:stop(false)
        local filtered=Separator.filter(current.analysis.notes,config.playback.mode,config.parts)
        if current.tempo and config.playback.quantization~="Off"then filtered=Quantizer.apply(filtered,current.analysis.division,current.tempo,config.playback.quantization)end
        local simplified,simplifyStats=Simplifier.apply(filtered,{maxSimultaneousKeys=config.playback.maxSimultaneousKeys,maxNotesPerSecond=config.playback.maxNotesPerSecond,chordWindowMs=config.playback.chordWindowMs})
        if newSeed or not current.performanceSeed then current.performanceSeed=config.humanize.seedMode=="Fixed"and config.humanize.fixedSeed or Humanizer.autoSeed()end
        local human,perfStats=Humanizer.generate(simplified,config.humanize,{seed=current.performanceSeed,bpm=averageBpm(current.analysis),chordWindowMs=config.playback.chordWindowMs})
        local profile=profileStore:get(config.pianoProfile);local mapStats;mappedNotes,mapStats=Mapper.mapNotes(human,profile,config.playback);mapStats.simplified=simplifyStats.removed
        local events=Mapper.toEvents(mappedNotes,config.playback);local duration=current.analysis.duration or 0
        for _,n in ipairs(mappedNotes)do duration=math.max(duration,n.endTime or n.startTime or 0)end
        current.performanceDuration=duration;current.perfStats=perfStats
        scheduler:setEvents(events,duration,nil);scheduler:setOptions(config.playback);scheduler:setSpeed(config.playback.speed);scheduler:setAB(config.playback.loopA,config.playback.loopB)
        if keepPosition and pos>0 then scheduler:seek(math.min(pos,duration),false)end
        if app then
            app:setSong(current.item,current.analysis,mapStats,perfStats);app:setProfile(profile);app:setPerformance(mappedNotes,profile,perfStats);app:setProgress(scheduler:getPosition(),duration,scheduler.stats,false);app:setExpression(config.playback.expression);app:setLoopSong(config.playback.loopSong);app:setSpeed(config.playback.speed);app:setMode(config.playback.mode);app:setHumanPreset(config.humanize.preset,config.humanize.strength)
        end
        if was then scheduler:play()end
    end

    local function loadSong(item)
        noteManager:releaseAll();scheduler:stop();applySongOverride(item.path)
        local data,err=FS.read(item.path);if not data then app:setError(err);return end
        local key=Cache.key(data);local analysis,midi,tempo,cacheHit
        if config.playback.quantization=="Off"then analysis=Cache.load(FS,key);cacheHit=analysis~=nil end
        if not analysis then
            local ok,res=pcall(function()local m=Parser.parse(data);local t=TempoMap.new(m);local a=Analyzer.analyze(m,t);return{midi=m,tempo=t,analysis=a}end)
            if not ok then app:setError(res);return end;midi,tempo,analysis=res.midi,res.tempo,res.analysis;Cache.save(FS,key,analysis)
        end
        analysis=enrichAnalysis(analysis);current={item=item,midi=midi,tempo=tempo,analysis=analysis,cacheHit=cacheHit,cacheKey=key,performanceSeed=nil}
        for i,s in ipairs(songs)do if s.path==item.path then currentIndex=i break end end
        app:setAnalysis(analysis,config.parts.enabledTracks,config.parts.enabledChannels);app:setTranspose(config.playback.transpose);app:setRange(config.playback.rangeMode);app:setQuantization(config.playback.quantization);library:touch(item.path);rebuildPerformance(false,true)
    end
    local function scanSongs()
        songs=FS.scanMidi(config.midiFolders);local recent={};for i,r in ipairs(library.data.recent or {})do recent[r.path]=i end
        for _,s in ipairs(songs)do s.favorite=library:isFavorite(s.path);s.recentRank=recent[s.path]end
        app:setSongs(songs,#songs>0 and(#songs.." MIDI encontrado(s)")or"Nenhum MIDI")
    end
    local function stepSong(d)if #songs==0 then return end;local i=currentIndex or 1;i=((i-1+d)%#songs)+1;loadSong(songs[i])end
    local function setSpeed(v)
        v=math.clamp(tonumber(v)or 1,.25,2);config.playback.speed=v;scheduler:setSpeed(v);saveConfig();if app then app:setSpeed(v)end
    end
    local function speedDelta(dir)
        local steps=config.playback.speedSteps or{.25,.5,.75,.9,1,1.1,1.25,1.5,1.75,2};local cur=config.playback.speed or 1;local best=1;local dist=math.huge
        for i,v in ipairs(steps)do local d=math.abs(v-cur);if d<dist then best,dist=i,d end end
        best=math.clamp(best+(dir>0 and 1 or -1),1,#steps);setSpeed(steps[best])
    end

    local cb={}
    cb.onRefresh=scanSongs;cb.onSelectSong=loadSong;cb.onNext=function()stepSong(1)end;cb.onPrev=function()stepSong(-1)end
    cb.onPlayPause=function()
        if not current then return end
        if scheduler:isPlaying()then scheduler:pause()else if scheduler:getPosition()<=.001 and config.humanize.seedMode=="Auto"then rebuildPerformance(false,true)end;scheduler:play()end
        app:setProgress(scheduler:getPosition(),current.performanceDuration or current.analysis.duration,scheduler.stats,scheduler:isPlaying())
    end
    cb.onSeekAbsolute=function(t)if current then scheduler:seek(t,scheduler:isPlaying())end end
    cb.onPanic=function()noteManager:releaseAll();app:setMessage("Teclas liberadas")end
    cb.onSpeedDelta=speedDelta;cb.onSetSpeed=setSpeed
    cb.onMode=function(mode)config.playback.mode=mode;saveConfig();rebuildPerformance(true,false)end
    cb.onToggleTrack=function(track,enabled)config.parts.enabledTracks[track]=enabled;saveConfig();saveOverride("enabledTracks",config.parts.enabledTracks);rebuildPerformance(true,false)end
    cb.onToggleFavorite=function(item)item.favorite=library:toggleFavorite(item.path);scanSongs();if current and current.item.path==item.path then app:setFavorite(item.favorite)end end
    cb.onPreset=function(name)Humanizer.applyPreset(config.humanize,name);saveConfig();rebuildPerformance(true,true);app:setMessage("Preset "..name.." aplicado")end
    cb.onHumanStrength=function(v)config.humanize.strength=math.clamp(v or 0,0,1);config.humanize.preset="Custom";saveConfig();rebuildPerformance(true,true)end
    cb.onNewPerformance=function()if current then rebuildPerformance(true,true);app:setMessage("Nova interpretação gerada")end end
    cb.onTransposeDelta=function(d)config.playback.transpose=math.clamp(config.playback.transpose+d,-24,24);app:setTranspose(config.playback.transpose);saveConfig();saveOverride("transpose",config.playback.transpose);rebuildPerformance(true,false)end
    cb.onCycleRange=function()local idx=1;for i,v in ipairs(rangeSteps)do if v==config.playback.rangeMode then idx=i break end end;config.playback.rangeMode=rangeSteps[idx%#rangeSteps+1];app:setRange(config.playback.rangeMode);saveConfig();saveOverride("rangeMode",config.playback.rangeMode);rebuildPerformance(true,false)end
    cb.onCycleQuantization=function()local idx=1;for i,v in ipairs(quantSteps)do if v==config.playback.quantization then idx=i break end end;config.playback.quantization=quantSteps[idx%#quantSteps+1];app:setQuantization(config.playback.quantization);saveConfig();if current then loadSong(current.item)end end
    cb.onToggleLoopSong=function()config.playback.loopSong=not config.playback.loopSong;scheduler:setOptions(config.playback);app:setLoopSong(config.playback.loopSong);saveConfig()end
    cb.onExpressionScaleDelta=function(d)local e=config.playback.expression;e.holdScale=math.clamp((e.holdScale or .96)+d,.25,1.35);app:setExpression(e);saveConfig();rebuildPerformance(true,false)end
    cb.onUiState=function(state,pos)config.ui.state=state or config.ui.state;if state and state~="Hidden"then config.ui.restoreState=state end;saveConfig()end
    cb.onChangelogSeen=function(v)config.ui.lastSeenChangelog=v;saveConfig()end
    cb.onCloudSearch=function(query)
        if not config.cloud.enabled then app:setCloudStatus("Cloud desativado")return end
        cloud:cancelSearch();app:setCloudStatus("Consultando Dodo Cloud...")
        task.spawn(function()local res,err=cloud:search(query or"");if res then app:setCloudSongs(res,#res.." resultado(s)")else app:setCloudSongs({},err or"Cloud indisponível")end end)
    end
    cb.onCloudDownload=function(song)
        app:setCloudStatus("Baixando "..tostring(song.name or"música").."...")
        task.spawn(function()local path,err=cloud:download(song);if path then app:setCloudStatus("Salvo em "..path);scanSongs()else app:setCloudStatus(err or"Falha no download")end end)
    end

    app=UI.new(cb,config);app:setBackend(adapter.backend);app:setSpeed(config.playback.speed);app:setMode(config.playback.mode);app:setHumanPreset(config.humanize.preset,config.humanize.strength);app:setTranspose(config.playback.transpose);app:setRange(config.playback.rangeMode);app:setQuantization(config.playback.quantization);app:setProfile(profileStore:get(config.pianoProfile));app:setExpression(config.playback.expression);app:setLoopSong(config.playback.loopSong)
    scheduler.onPosition=function(pos,dur,stats)if app then app:setProgress(pos,dur,stats,scheduler:isPlaying())end end
    scheduler.onFinished=function()if app and current then app:setProgress(current.performanceDuration or current.analysis.duration,current.performanceDuration or current.analysis.duration,scheduler.stats,false)end end
    scheduler.onEvent=function(e)if app and(e.action=="tap"or e.action=="strike"or e.action=="down")then app:setActiveNotes({e.token})end end
    scanSongs()

    local public={}
    function public.refresh()scanSongs()end
    function public.stop()scheduler:stop();noteManager:releaseAll()end
    function public.show()if app then app:setState("Full")end end
    function public.compact()if app then app:setState("Compact")end end
    function public.mini()if app then app:setState("Mini")end end
    function public.hide()if app then app:setState("Hidden")end end
    function public.destroy()scheduler:destroy();noteManager:releaseAll();if adapter.destroy then adapter:destroy()end;if app then app:destroy()end end
    function public.state()return{current=current and current.item.name or nil,position=scheduler:getPosition(),playing=scheduler:isPlaying(),speed=config.playback.speed,mode=config.playback.mode,backend=adapter.backend,config=config,cloud=cloud:diagnostics()}end
    local env=(getgenv and getgenv())or _G;env.MIDIQWERTY=public
    return public
end

return Main
