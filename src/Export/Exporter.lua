local Exporter={}
local function safe(s) return (s or "song"):gsub("[^%w%-%._]","_") end
local function stamp() return os.date("!%Y%m%d_%H%M%S") end
function Exporter.sequence(FS,item,mapped)
    FS.ensureFolder("MIDIQWERTY/exports")
    local lines={"# QWERTY performance export: "..(item.name or item.path)}
    for _,n in ipairs(mapped or {}) do lines[#lines+1]=string.format("[%08.3f] %s  MIDI:%d",n.startTime,n.token,n.originalNote or n.note) end
    local path="MIDIQWERTY/exports/"..safe(item.name).."_"..stamp().."_qwerty.txt"; FS.write(path,table.concat(lines,"\n")); return path
end
function Exporter.analysis(FS,item,a)
    FS.ensureFolder("MIDIQWERTY/exports")
    local lines={"MIDI Analysis","File: "..(item.name or item.path),string.format("Duration: %.3fs",a.duration or 0),"Notes: "..tostring(a.noteCount),"Tracks: "..tostring(#(a.tracks or {})),"Pitch range: "..tostring(a.pitchMin)..".."..tostring(a.pitchMax),"Peak polyphony: "..tostring(a.peakPolyphony),"Hand split: "..tostring(a.handSplit),"Voice count: "..tostring(a.voiceCount)}
    local path="MIDIQWERTY/exports/"..safe(item.name).."_"..stamp().."_analysis.txt"; FS.write(path,table.concat(lines,"\n")); return path
end
return Exporter
