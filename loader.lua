local URL="https://raw.githubusercontent.com/Johnatafgfdgf/Midi-to-qwerty-roblox-autoplayer/main/loader_v050_HUMANLAB.lua?v=0.5.0"
local ok,source=pcall(function()return game:HttpGet(URL)end)
assert(ok and type(source)=="string","[MIDIQWERTY] Failed to download v0.5.0 loader")
local chunk,err=loadstring(source,"=MIDIQWERTY/loader_v050_HUMANLAB")
assert(chunk,"[MIDIQWERTY] v0.5.0 loader compile error: "..tostring(err))
return chunk()
