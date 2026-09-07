-- Development channel; stable loader.lua intentionally remains v0.6.1.
local url='https://raw.githubusercontent.com/Johnatafgfdgf/Midi-to-qwerty-roblox-autoplayer/dev/glass-autoplayer/dist/autoplayer.lua'
local source=game:HttpGet(url)
local chunk,err=loadstring(source,'=MIDIQWERTY/GlassDev')
assert(chunk,err)
return chunk()
