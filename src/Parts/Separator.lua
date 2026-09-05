local Separator={}
local function lower(s) return string.lower(s or "") end
local leftHints={"left hand","left"," l.h","lh","bass"}; local rightHints={"right hand","right"," r.h","rh","treble","melody"}
local function containsAny(text,list) text=" "..lower(text).." "; for _,token in ipairs(list) do if string.find(text,token,1,true) then return true end end return false end
local function kmeansSplit(notes) if #notes==0 then return 60 end local c1,c2=48,72; for _=1,8 do local s1,n1,s2,n2=0,0,0,0; for _,n in ipairs(notes) do if math.abs(n.note-c1)<=math.abs(n.note-c2) then s1+=n.note;n1+=1 else s2+=n.note;n2+=1 end end; if n1>0 then c1=s1/n1 end; if n2>0 then c2=s2/n2 end end; if c1>c2 then c1,c2=c2,c1 end; return math.clamp(math.floor((c1+c2)/2+.5),48,72) end
local function groups(notes,w) local out,g={},nil; for _,n in ipairs(notes) do if not g or n.startTime-g.time>w then g={time=n.startTime,notes={}};out[#out+1]=g end;g.notes[#g.notes+1]=n end;return out end
function Separator.classify(analysis,options)
    options=options or {}; local notes=analysis.notes; local split=options.splitMode=="Fixed" and (options.splitNote or 60) or kmeansSplit(notes); local state={Left={pitch=split-7,time=-1},Right={pitch=split+7,time=-1}}; local confSum=0
    for index,n in ipairs(notes) do n.index=index;n.parts=n.parts or {};n.parts.track=n.track;n.parts.channel=n.channel;n.parts.percussion=n.channel==10; local info=analysis.tracks[n.track] or {}; local label=(info.name or "").." "..(info.instrument or "");local explicit;if containsAny(label,leftHints) and not containsAny(label,rightHints) then explicit="Left" end;if containsAny(label,rightHints) and not containsAny(label,leftHints) then explicit="Right" end
        local hand,confidence=explicit,1
        if not hand then local function score(which) local s=state[which];local pitchBias=which=="Left" and (n.note-split) or (split-n.note);local distance=math.abs(n.note-s.pitch);local dt=s.time<0 and 2 or math.min(n.startTime-s.time,2);return pitchBias*1.35+distance*(.38-.12*dt) end;local ls,rs=score("Left"),score("Right");hand=ls<=rs and "Left" or "Right";confidence=math.clamp(math.abs(ls-rs)/18,0,1) end
        n.parts.hand=hand;n.parts.handConfidence=confidence;confSum+=confidence;state[hand].pitch=n.note;state[hand].time=n.startTime
    end
    local gs=groups(notes,.035);local lm,lb
    for _,g in ipairs(gs) do table.sort(g.notes,function(a,b)return a.note<b.note end);local bass,melody=g.notes[1],g.notes[#g.notes];if #g.notes>1 then local bs=-math.huge;for _,n in ipairs(g.notes) do local cont=lm and -math.abs(n.note-lm)*.35 or 0;local s=n.note*.75+n.velocity*.12+cont;if s>bs then bs=s;melody=n end end;local low=math.huge;for _,n in ipairs(g.notes) do local cont=lb and math.abs(n.note-lb)*.25 or 0;local s=n.note+cont-n.velocity*.03;if s<low then low=s;bass=n end end end;melody.parts.melody=true;bass.parts.bass=true;lm,lb=melody.note,bass.note end
    for _,n in ipairs(notes) do n.parts.accompaniment=not n.parts.melody end
    analysis.handSplit=split;analysis.handConfidence=#notes>0 and confSum/#notes or 0;return analysis
end
function Separator.shouldInclude(n,mode,options) options=options or {};if n.parts.percussion and not options.percussion then return false end;if options.enabledTracks and next(options.enabledTracks) and options.enabledTracks[n.track]==false then return false end;if options.enabledChannels and next(options.enabledChannels) and options.enabledChannels[n.channel]==false then return false end;if mode=="Left" then return n.parts.hand=="Left" elseif mode=="Right" then return n.parts.hand=="Right" elseif mode=="Melody" then return n.parts.melody==true elseif mode=="Accompaniment" then return n.parts.accompaniment==true elseif mode=="Bass" then return n.parts.bass==true elseif type(mode)=="string" and mode:match("^Voice%d+$") then return n.parts.voice==tonumber(mode:match("%d+")) end;return true end
function Separator.filter(notes,mode,options) local out={};for _,n in ipairs(notes) do if Separator.shouldInclude(n,mode,options) then out[#out+1]=n end end;return out end
return Separator
