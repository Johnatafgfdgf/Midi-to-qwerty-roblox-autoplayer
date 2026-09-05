local BOOTSTRAP_URL = "https://raw.githubusercontent.com/Johnatafgfdgf/Midi-to-qwerty-roblox-autoplayer/main/bootstrap.lua"
local ok, source = pcall(function()
    return game:HttpGet(BOOTSTRAP_URL)
end)
assert(ok and type(source) == "string", "[MIDIQWERTY] Failed to download bootstrap.lua")
local chunk, err = loadstring(source, "=MIDIQWERTY/bootstrap")
assert(chunk, "[MIDIQWERTY] Bootstrap compile error: " .. tostring(err))
local bootstrap = chunk()
assert(type(bootstrap) == "function", "[MIDIQWERTY] Invalid bootstrap module")
return bootstrap({
    owner = "Johnatafgfdgf",
    repo = "Midi-to-qwerty-roblox-autoplayer",
    branch = "main",
    version = "0.1.0",
})
