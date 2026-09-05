local Main={}
local function deepCopy(v)if type(v)~="table" then return v end;local o={};for k,x in pairs(v) do o[k]=deepCopy(x) end;return o end
local function merge(dst,src)if type(src)~="table" then return dst end;for k,v in pairs(src) do if type(v)=="table" and type(dst[k])=="table" then merge(dst[k],v) else dst[k]=deepCopy(v) end end;return dst end
local function normalizeBoolMap(t)local o={};for k,v in pairs(t or {}) do o[tonumber(k) or k]=v end;return o end

function Main.start(ctx)
    local R=ctx.Require
    local Defaults=R("ConfigDefaults");local FS=R("Storage/FileSystem");local Cache=R("Storage/Cache");local Library=R("Storage/Library")
    local Parser=R("MIDI/Parser");local TempoMap=R("MIDI/TempoMap");local Analyzer=R("MIDI/Analyzer")
    local Separator=R("Parts/Separator");local VoiceSeparator=R("Parts/VoiceSeparator")
    local Articulation=R("Performance/Articulation");local PhraseEngine=R("Performance/PhraseEngine");local Simplifier=R("Performance/Simplifier");local Quantizer=R("Performance/Quantizer");local Humanizer=R("Performance/Humanizer")
    local Profiles=R("Piano/Profiles");local ProfileStore=R("Piano/ProfileStore");local Mapper=R("Piano/Mapper")
    local InputAdapter=R("Input/InputAdapter");local NoteManager=R("Player/NoteManager");local Scheduler=R("Player/Scheduler");local Exporter=R("Export/Exporter");local UI=R("UI/App")

    FS.ensureFolder("MIDIQWERTY")
    local config=merge(deepCopy(Defaults),FS.loadJson("MIDIQWERTY/config.json",{}));config.parts.enabledTracks=normalizeBoolMap(config.parts.enabledTracks);config.parts.enabledChannels=normalizeBoolMap(config.parts.enabledChannels)
    local library=Library.new(FS);local profileStore=ProfileStore.new(FS,Profiles);local adapter=InputAdapter.new();local noteManager=NoteManager.new(adapter);local scheduler=Scheduler.new(noteManager)
    local app,current,mappedNotes,songs,currentIndex=nil,nil,{}, {},nil
    local speedSteps={.5,.75,1,1.1,1.25,1.5,2};local rangeSteps={"SmartOctave","OctaveFold","Strict","Clamp"};local quantSteps={"Off","1/8","1/16","1/32"}
    local abA,abB=config.playback.loopA,config.playback.loopB
    local function saveConfig()FS.saveJson("MIDIQWERTY/config.json",config) end
    local function averageBpm(a)if a.bpmMin and a.bpmMax then return (a.bpmMin+a.bpmMax)/2 end;return 120 end
    local function applySongOverride(path)
        local o=library:getOverride(path)
        if o.transpose~=nil then config.playback.transpose=o.transpose end;if o.rangeMode then config.playback.rangeMode=o.rangeMode end;if o.splitMode then config.parts.splitMode=o.splitMode end;if o.splitNote then config.parts.splitNote=o.splitNote end;if o.pianoProfile then config.pianoProfile=o.pianoProfile end
        if o.enabledTracks then config.parts.enabledTracks=normalizeBoolMap(o.enabledTracks) end;if o.enabledChannels then config.parts.enabledChannels=normalizeBoolMap(o.enabledChannels) end
    end
    local function saveOverride(k,v)if current then library:setOverride(current.item.path,k,v) end end

    local function rebuildPerformance(keepPosition,newSeed)
        if not current then return end
        local pos=scheduler:getPosition();local wasPlaying=scheduler:isPlaying();scheduler:stop(false)
        local filtered=Separator.filter(current.analysis.notes,config.playback.mode,config.parts)
        if current.tempo and config.playback.quantization~="Off" then filtered=Quantizer.apply(filtered,current.analysis.division,current.tempo,config.playback.quantization) end
        local simplified,simplifyStats=Simplifier.apply(filtered,{maxSimultaneousKeys=config.playback.maxSimultaneousKeys,maxNotesPerSecond=config.playback.maxNotesPerSecond,chordWindowMs=config.playback.chordWindowMs})
        if newSeed or not current.performanceSeed then current.performanceSeed=config.humanize.seedMode=="Fixed" and config.humanize.fixedSeed or Humanizer.autoSeed() end
        local human,perfStats=Humanizer.generate(simplified,config.humanize,{seed=current.performanceSeed,bpm=averageBpm(current.analysis),chordWindowMs=config.playback.chordWindowMs})
        local profile=profileStore:get(config.pianoProfile);local mapStats;mappedNotes,mapStats=Mapper.mapNotes(human,profile,config.playback);mapStats.simplified=simplifyStats.removed
        local events=Mapper.toEvents(mappedNotes)
        local function rebuildAt(t)for _,n in ipairs(mappedNotes) do if n.startTime<=t and n.endTime>t then noteManager:down(n.token) end;if n.startTime>t then break end end end
        scheduler:setEvents(events,current.analysis.duration,rebuildAt);scheduler:setOptions(config.playback);scheduler:setSpeed(config.playback.speed);scheduler:setAB(abA,abB)
        if keepPosition and pos>0 then scheduler:seek(math.min(pos,current.analysis.duration),false) end
        if app then app:setSong(current.item,current.analysis,mapStats,perfStats);app:setProfile(profile);app:setProgress(scheduler:getPosition(),current.analysis.duration,scheduler.stats,false);app:setAB(abA,abB) end
        if wasPlaying then scheduler:play() end
    end

    local function enrichAnalysis(analysis)
        Separator.classify(analysis,config.parts);local _,voiceCount=VoiceSeparator.assign(analysis.notes,.03);analysis.voiceCount=voiceCount;Articulation.annotate(analysis.notes);PhraseEngine.annotate(analysis.notes,averageBpm(analysis));return analysis
    end

    local function loadSong(item)
        noteManager:releaseAll();scheduler:stop();applySongOverride(item.path)
        local data,err=FS.read(item.path);if not data then app:setError(err);return end
        local cacheKey=Cache.key(data);local analysis,midi,tempo,cacheHit
        if config.playback.quantization=="Off" then analysis=Cache.load(FS,cacheKey);cacheHit=analysis~=nil end
        if not analysis then
            local ok,res=pcall(function()local m=Parser.parse(data);local t=TempoMap.new(m);local a=Analyzer.analyze(m,t);return {midi=m,tempo=t,analysis=a} end)
            if not ok then app:setError(res);return end;midi,tempo,analysis=res.midi,res.tempo,res.analysis;Cache.save(FS,cacheKey,analysis)
        end
        analysis=enrichAnalysis(analysis);current={item=item,midi=midi,tempo=tempo,analysis=analysis,cacheHit=cacheHit,cacheKey=cacheKey,performanceSeed=nil}
        for i,s in ipairs(songs) do if s.path==item.path then currentIndex=i break end end
        app:setAnalysis(analysis,config.parts.enabledTracks,config.parts.enabledChannels);app:setTranspose(config.playback.transpose);app:setRange(config.playback.rangeMode);app:setQuantization(config.playback.quantization);app:setMaxKeys(config.playback.maxSimultaneousKeys)
        library:touch(item.path);rebuildPerformance(false,true)
    end

    local function scanSongs()
        songs=FS.scanMidi(config.midiFolders)
        local recentRank={};for i,r in ipairs(library.data.recent or {}) do recentRank[r.path]=i end
        for _,s in ipairs(songs) do s.favorite=library:isFavorite(s.path);s.recentRank=recentRank[s.path] end
        app:setSongs(songs,#songs>0 and (#songs.." MIDI file(s) found") or "No MIDI found. Put .mid files in Delta/Workspace/MIDI/")
    end
    local function stepSong(delta)if #songs==0 then return end;local i=currentIndex or 1;i=((i-1+delta)%#songs)+1;loadSong(songs[i]) end
    local callbacks={}
    callbacks.onRefresh=scanSongs;callbacks.onSelectSong=loadSong;callbacks.onNext=function()stepSong(1)end;callbacks.onPrev=function()stepSong(-1)end
    callbacks.onPlayPause=function()if not current then return end;if scheduler:isPlaying() then scheduler:pause() else if scheduler:getPosition()<=.001 and config.humanize.seedMode=="Auto" then rebuildPerformance(false,true) end;scheduler:play() end;app:setProgress(scheduler:getPosition(),current.analysis.duration,scheduler.stats,scheduler:isPlaying()) end
    callbacks.onStop=function()if current then library:addPlayedSeconds(current.item.path,scheduler:getPosition()) end;scheduler:stop();if current then app:setProgress(0,current.analysis.duration,scheduler.stats,false) end end
    callbacks.onSeekRelative=function(d)if current then scheduler:seek(scheduler:getPosition()+d,scheduler:isPlaying()) end end;callbacks.onPanic=function()noteManager:releaseAll()end
    callbacks.onMode=function(mode)config.playback.mode=mode;saveConfig();rebuildPerformance(true,false)end
    callbacks.onToggleTrack=function(track,enabled)config.parts.enabledTracks[track]=enabled;saveConfig();saveOverride("enabledTracks",config.parts.enabledTracks);rebuildPerformance(true,false)end
    callbacks.onToggleChannel=function(channel,enabled)config.parts.enabledChannels[channel]=enabled;saveConfig();saveOverride("enabledChannels",config.parts.enabledChannels);rebuildPerformance(true,false)end
    callbacks.onToggleFavorite=function(item)item.favorite=library:toggleFavorite(item.path);scanSongs();if current and current.item.path==item.path then app:setFavorite(item.favorite) end end
    callbacks.onPreset=function(p)config.humanize.preset=p;if p=="Exact" then config.humanize.strength=0 elseif p=="Very Subtle" then config.humanize.strength=.08 elseif p=="Natural" then config.humanize.strength=.22 else config.humanize.strength=.42 end;app:setHumanStrength(config.humanize.strength);saveConfig();rebuildPerformance(true,true)end
    callbacks.onHumanDelta=function(d)config.humanize.strength=math.clamp(config.humanize.strength+d,0,1);config.humanize.preset="Custom";app:setHumanStrength(config.humanize.strength);saveConfig();rebuildPerformance(true,true)end
    callbacks.onTransposeDelta=function(d)config.playback.transpose=math.clamp(config.playback.transpose+d,-24,24);app:setTranspose(config.playback.transpose);saveConfig();saveOverride("transpose",config.playback.transpose);rebuildPerformance(true,false)end
    callbacks.onCycleSpeed=function()local best=1;for i,v in ipairs(speedSteps)do if math.abs(v-config.playback.speed)<.001 then best=i break end end;best=best%#speedSteps+1;config.playback.speed=speedSteps[best];scheduler:setSpeed(config.playback.speed);app:setSpeed(config.playback.speed);saveConfig()end
    callbacks.onCycleRange=function()local idx=1;for i,v in ipairs(rangeSteps)do if v==config.playback.rangeMode then idx=i break end end;config.playback.rangeMode=rangeSteps[idx%#rangeSteps+1];app:setRange(config.playback.rangeMode);saveConfig();saveOverride("rangeMode",config.playback.rangeMode);rebuildPerformance(true,false)end
    callbacks.onCycleQuantization=function()local idx=1;for i,v in ipairs(quantSteps)do if v==config.playback.quantization then idx=i break end end;config.playback.quantization=quantSteps[idx%#quantSteps+1];app:setQuantization(config.playback.quantization);saveConfig();if current then loadSong(current.item)end end
    callbacks.onMaxKeysDelta=function(d)config.playback.maxSimultaneousKeys=math.clamp(config.playback.maxSimultaneousKeys+d,1,16);app:setMaxKeys(config.playback.maxSimultaneousKeys);saveConfig();rebuildPerformance(true,false)end
    callbacks.onSetA=function()abA=scheduler:getPosition();config.playback.loopA=abA;if abB and abB<=abA then abB=nil;config.playback.loopB=nil end;scheduler:setAB(abA,abB);app:setAB(abA,abB);saveConfig()end
    callbacks.onSetB=function()local p=scheduler:getPosition();if abA and p>abA then abB=p;config.playback.loopB=abB;scheduler:setAB(abA,abB);app:setAB(abA,abB);saveConfig()end end
    callbacks.onClearAB=function()abA,abB=nil,nil;config.playback.loopA,config.playback.loopB=nil,nil;scheduler:setAB(nil,nil);app:setAB(nil,nil);saveConfig()end
    callbacks.onExportSequence=function()if current then local p=Exporter.sequence(FS,current.item,mappedNotes);app:setMessage("Exported: "..p)end end
    callbacks.onExportAnalysis=function()if current then local p=Exporter.analysis(FS,current.item,current.analysis);app:setMessage("Exported: "..p)end end
    callbacks.onProfileMapping=function(note,token)if type(token)=="string" and #token==1 then profileStore:setMapping(config.pianoProfile,note,token);rebuildPerformance(true,false)end end
    callbacks.onUiState=function(state,pos)config.ui.state=state;if pos then config.ui.floatingX=pos.X.Scale;config.ui.floatingY=pos.Y.Scale end;saveConfig()end

    app=UI.new(callbacks,config);app:setBackend(adapter.backend);app:setSpeed(config.playback.speed);app:setHumanStrength(config.humanize.strength);app:setTranspose(config.playback.transpose);app:setRange(config.playback.rangeMode);app:setQuantization(config.playback.quantization);app:setMaxKeys(config.playback.maxSimultaneousKeys);app:setProfile(profileStore:get(config.pianoProfile));app:setAB(abA,abB)
    scheduler.onPosition=function(pos,dur,stats)if app then app:setProgress(pos,dur,stats,scheduler:isPlaying())end end
    scheduler.onFinished=function()if app and current then app:setProgress(current.analysis.duration,current.analysis.duration,scheduler.stats,false)end end
    local activeTokens={};scheduler.onEvent=function(e)if e.action=="down" then activeTokens[e.token]=(activeTokens[e.token] or 0)+1 else local n=(activeTokens[e.token] or 0)-1;if n<=0 then activeTokens[e.token]=nil else activeTokens[e.token]=n end end;if app then local list={};for k in pairs(activeTokens)do list[#list+1]=k end;table.sort(list);app:setActiveNotes(list)end end
    scanSongs()
    local public={};function public.refresh()scanSongs()end;function public.stop()scheduler:stop();noteManager:releaseAll()end;function public.destroy()scheduler:stop();noteManager:releaseAll();if app then app:destroy()end end;function public.state()return{current=current and current.item.name or nil,position=scheduler:getPosition(),playing=scheduler:isPlaying(),backend=adapter.backend,config=config}end
    local env=(getgenv and getgenv()) or _G;env.MIDIQWERTY=public;return public
end
return Main
