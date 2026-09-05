local URL="https://raw.githubusercontent.com/Johnatafgfdgf/Midi-to-qwerty-roblox-autoplayer/main/loader_v043_POLISHED.lua?v=0.4.3"
local ok,source=pcall(function()return game:HttpGet(URL)end)
assert(ok and type(source)=="string","[MIDIQWERTY] Failed to download v0.4.3 loader")
local chunk,err=loadstring(source,"=MIDIQWERTY/loader_v043_POLISHED")
assert(chunk,"[MIDIQWERTY] v0.4.3 loader compile error: "..tostring(err))
return chunk()
