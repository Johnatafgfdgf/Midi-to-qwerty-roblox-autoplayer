local URL="https://raw.githubusercontent.com/Johnatafgfdgf/Midi-to-qwerty-roblox-autoplayer/main/loader_v100_PRO.lua?v=1.0.0"
local ok,source=pcall(function()return game:HttpGet(URL)end)
assert(ok and type(source)=="string","[MIDIQWERTY] Failed to download v1.0.0 loader")
local chunk,err=loadstring(source,"=MIDIQWERTY/loader_v100_PRO")
assert(chunk,"[MIDIQWERTY] v1.0.0 loader compile error: "..tostring(err))
return chunk()
