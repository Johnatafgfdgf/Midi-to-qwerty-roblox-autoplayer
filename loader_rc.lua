-- Immutable 0.7.0-rc.1 candidate. Stable promotion requires real-device approval.
local source=game:HttpGet('https://raw.githubusercontent.com/Johnatafgfdgf/Midi-to-qwerty-roblox-autoplayer/71db8c8ab6949e648fc8b147e8ea7f2eeb9b5d14/dist/autoplayer.lua')
local chunk,err=loadstring(source,'=MIDIQWERTY/GlassRC')
assert(chunk,err)
return chunk()
