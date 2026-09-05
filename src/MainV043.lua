local Wrapper = {}

local function patchConfigOnce()
    local env=(getgenv and getgenv()) or _G
    local readfile=rawget(env,"readfile") or rawget(_G,"readfile")
    local writefile=rawget(env,"writefile") or rawget(_G,"writefile")
    local isfile=rawget(env,"isfile") or rawget(_G,"isfile")
    if type(readfile)~="function" or type(writefile)~="function" then return end

    local path="MIDIQWERTY/config.json"
    if type(isfile)=="function" then
        local ok,exists=pcall(isfile,path)
        if not ok or not exists then return end
    end

    local ok,data=pcall(readfile,path)
    if not ok or type(data)~="string" then return end
    local HttpService=game:GetService("HttpService")
    local decodedOk,cfg=pcall(HttpService.JSONDecode,HttpService,data)
    if not decodedOk or type(cfg)~="table" then return end
    if cfg.migrationV043 then return end

    cfg.playback=cfg.playback or {}
    cfg.humanize=cfg.humanize or {}
    cfg.ui=cfg.ui or {}

    -- Real-device repair pass: restore a fidelity-first baseline once.
    -- The previous test video had 1/32 quantization enabled, which changes
    -- original MIDI timing. CatchUp also prevents frame stalls from deleting notes.
    cfg.playback.quantization="Off"
    cfg.playback.lateMode="CatchUp"
    cfg.playback.maxLateMs=120
    cfg.playback.maxSimultaneousKeys=16
    cfg.playback.maxNotesPerSecond=0
    cfg.playback.triggerMode="Tap"
    cfg.playback.collisionWindowMs=2.5

    cfg.humanize.preset="Very Subtle"
    cfg.humanize.enabled=true
    cfg.humanize.strength=.05
    cfg.humanize.timingMs=3
    cfg.humanize.chordSpreadMs=2
    cfg.humanize.durationVariation=.008

    cfg.ui.state="Full"
    cfg.migrationV043=true

    local encOk,encoded=pcall(HttpService.JSONEncode,HttpService,cfg)
    if encOk then pcall(writefile,path,encoded) end
end

function Wrapper.start(ctx)
    patchConfigOnce()
    local Base=ctx.Require("MainBase")
    return Base.start(ctx)
end

return Wrapper
