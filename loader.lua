local URL="https://raw.githubusercontent.com/Johnatafgfdgf/Midi-to-qwerty-roblox-autoplayer/main/loader_v061_PREMIUM_PLUS.lua?v=0.6.1"
local ok,source=pcall(function()return game:HttpGet(URL)end)
assert(ok and type(source)=="string","[MIDIQWERTY] Failed to download v0.6.1 loader")
local chunk,err=loadstring(source,"=MIDIQWERTY/loader_v061_PREMIUM_PLUS")
assert(chunk,"[MIDIQWERTY] v0.6.1 loader compile error: "..tostring(err))
return chunk()
