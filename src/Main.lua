local Main = {}

local function deepCopy(v)
    if type(v)~="table" then return v end local o={}; for k,x in pairs(v) do o[k]=deepCopy(x) end; return o
end
local function merge(dst,src)
    if type(src)~="table" then return dst end
    for k,v in pairs(src) do if type(v)=="table" and type(dst[k])=="table" then merge(dst[k],v) else dst[k]=deepCopy(v) end end
    return dst
end

function Main.start(ctx)
    local R=ctx.Require
    local Defaults=R("ConfigDefaults")
    local FS=R("Storage/FileSystem")
    local Parser=R("MIDI/Parser")
    local TempoMap=R("MIDI/TempoMap")
    local Analyzer=R("MIDI/Analyzer")
    local Separator=R("Parts/Separator")
    local Humanizer=R("Performance/Humanizer")
    local Profiles=R("Piano/Profiles")
    local Mapper=R("Piano/Mapper")
    local InputAdapter=R("Input/InputAdapter")
    local NoteManager=R("Player/NoteManager")
    local Scheduler=R("Player/Scheduler")
    local UI=R("UI/App")

    FS.ensureFolder("MIDIQWERTY")
    local config=merge(deepCopy(Defaults),FS.loadJson("MIDIQWERTY/config.json",{}))
    local adapter=InputAdapter.new()
    local notes=NoteManager.new(adapter)
    local scheduler=Scheduler.new(notes)
    local app, current, mappedNotes, songs
    local speedSteps={0.5,0.75,1,1.1,1.25,1.5,2}
    local rangeSteps={"OctaveFold","Strict","Clamp"}

    local function saveConfig() FS.saveJson("MIDIQWERTY/config.json",config) end
    local function averageBpm(a) if a.bpmMin and a.bpmMax then return (a.bpmMin+a.bpmMax)/2 end return 120 end

    local function rebuildPerformance(keepPosition)
        if not current then return end
        local pos=scheduler:getPosition(); local wasPlaying=scheduler:isPlaying()
        scheduler:stop(false)
        local filtered=Separator.filter(current.analysis.notes,config.playback.mode,config.parts)
        local seed=config.humanize.seedMode=="Fixed" and config.humanize.fixedSeed or Humanizer.autoSeed()
        local human,perfStats=Humanizer.generate(filtered,config.humanize,{seed=seed,bpm=averageBpm(current.analysis),chordWindowMs=config.playback.chordWindowMs})
        local profile=Profiles.get(config.pianoProfile)
        local mapStats
        mappedNotes,mapStats=Mapper.mapNotes(human,profile,config.playback)
        local events=Mapper.toEvents(mappedNotes)
        local function rebuildAt(t)
            for _,n in ipairs(mappedNotes) do
                if n.startTime<=t and n.endTime>t then notes:down(n.token) end
                if n.startTime>t then break end
            end
        end
        scheduler:setEvents(events,current.analysis.duration,rebuildAt)
        scheduler:setOptions(config.playback); scheduler:setSpeed(config.playback.speed)
        if keepPosition and pos>0 then scheduler:seek(math.min(pos,current.analysis.duration),false) end
        if app then app:setSong(current.item,current.analysis,mapStats,perfStats); app:setProgress(scheduler:getPosition(),current.analysis.duration,scheduler.stats,false) end
        if wasPlaying then scheduler:play() end
    end

    local function loadSong(item)
        notes:releaseAll(); scheduler:stop()
        local data,err=FS.read(item.path); if not data then app:setError(err); return end
        local ok,result=pcall(function()
            local midi=Parser.parse(data)
            local tempo=TempoMap.new(midi)
            local analysis=Analyzer.analyze(midi,tempo)
            Separator.classify(analysis,config.parts)
            return {midi=midi,tempo=tempo,analysis=analysis}
        end)
        if not ok then app:setError(result); return end
        current={item=item,midi=result.midi,tempo=result.tempo,analysis=result.analysis}
        app:setAnalysis(current.analysis,config.parts.enabledTracks)
        rebuildPerformance(false)
    end

    local function scanSongs()
        songs=FS.scanMidi(config.midiFolders)
        app:setSongs(songs,#songs>0 and (#songs.." MIDI file(s) found") or "No MIDI found. Put .mid files in Delta/Workspace/MIDI/")
    end

    local callbacks={}
    callbacks.onRefresh=scanSongs
    callbacks.onSelectSong=loadSong
    callbacks.onPlayPause=function()
        if not current then return end
        if scheduler:isPlaying() then scheduler:pause() else
            if config.humanize.seedMode=="Auto" and scheduler:getPosition()<=0.001 then rebuildPerformance(false) end
            scheduler:play()
        end
        app:setProgress(scheduler:getPosition(),current.analysis.duration,scheduler.stats,scheduler:isPlaying())
    end
    callbacks.onStop=function() scheduler:stop(); if current then app:setProgress(0,current.analysis.duration,scheduler.stats,false) end end
    callbacks.onSeekRelative=function(d) if current then scheduler:seek(scheduler:getPosition()+d,scheduler:isPlaying()) end end
    callbacks.onPanic=function() notes:releaseAll() end
    callbacks.onMode=function(mode) config.playback.mode=mode; saveConfig(); rebuildPerformance(true) end
    callbacks.onToggleTrack=function(track,enabled) config.parts.enabledTracks[track]=enabled; saveConfig(); rebuildPerformance(true) end
    callbacks.onPreset=function(p)
        config.humanize.preset=p
        if p=="Exact" then config.humanize.strength=0 elseif p=="Very Subtle" then config.humanize.strength=.08 elseif p=="Natural" then config.humanize.strength=.22 else config.humanize.strength=.42 end
        app:setHumanStrength(config.humanize.strength); saveConfig(); rebuildPerformance(true)
    end
    callbacks.onHumanDelta=function(d) config.humanize.strength=math.clamp(config.humanize.strength+d,0,1); config.humanize.preset="Custom"; app:setHumanStrength(config.humanize.strength); saveConfig(); rebuildPerformance(true) end
    callbacks.onTransposeDelta=function(d) config.playback.transpose=math.clamp(config.playback.transpose+d,-24,24); app:setTranspose(config.playback.transpose); saveConfig(); rebuildPerformance(true) end
    callbacks.onCycleSpeed=function()
        local best=1; for i,v in ipairs(speedSteps) do if math.abs(v-config.playback.speed)<.001 then best=i break end end
        best=best%#speedSteps+1; config.playback.speed=speedSteps[best]; scheduler:setSpeed(config.playback.speed); app:setSpeed(config.playback.speed); saveConfig()
    end
    callbacks.onCycleRange=function()
        local idx=1; for i,v in ipairs(rangeSteps) do if v==config.playback.rangeMode then idx=i break end end
        config.playback.rangeMode=rangeSteps[idx%#rangeSteps+1]; app:setRange(config.playback.rangeMode); saveConfig(); rebuildPerformance(true)
    end
    callbacks.onUiState=function(state,pos) config.ui.state=state; if pos then config.ui.floatingX=pos.X.Scale; config.ui.floatingY=pos.Y.Scale end; saveConfig() end

    app=UI.new(callbacks,config)
    app:setBackend(adapter.backend); app:setSpeed(config.playback.speed); app:setHumanStrength(config.humanize.strength); app:setTranspose(config.playback.transpose); app:setRange(config.playback.rangeMode)
    scheduler.onPosition=function(pos,duration,stats) if app then app:setProgress(pos,duration,stats,scheduler:isPlaying()) end end
    scheduler.onFinished=function() if app and current then app:setProgress(current.analysis.duration,current.analysis.duration,scheduler.stats,false) end end
    scanSongs()

    local public={}
    function public.refresh() scanSongs() end
    function public.stop() scheduler:stop(); notes:releaseAll() end
    function public.destroy() scheduler:stop(); notes:releaseAll(); if app then app:destroy() end end
    function public.state() return {current=current and current.item.name or nil,position=scheduler:getPosition(),playing=scheduler:isPlaying(),backend=adapter.backend,config=config} end
    local env=(getgenv and getgenv()) or _G; env.MIDIQWERTY=public
    return public
end

return Main
