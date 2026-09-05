local URL="https://raw.githubusercontent.com/Johnatafgfdgf/Midi-to-qwerty-roblox-autoplayer/main/loader_v051_EXPRESSION.lua?v=0.5.1"
local ok,source=pcall(function()return game:HttpGet(URL)end)
assert(ok and type(source)=="string","[MIDIQWERTY] Failed to download v0.5.1 loader")
local chunk,err=loadstring(source,"=MIDIQWERTY/loader_v051_EXPRESSION")
assert(chunk,"[MIDIQWERTY] v0.5.1 loader compile error: "..tostring(err))
return chunk()
