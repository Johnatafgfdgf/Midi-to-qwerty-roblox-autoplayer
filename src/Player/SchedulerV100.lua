local Scheduler = {}
Scheduler.__index = Scheduler

local RunService = game:GetService("RunService")

local function lowerBound(events, t)
    local lo, hi = 1, #events + 1
    while lo < hi do
        local mid = math.floor((lo + hi) / 2)
        if mid <= #events and events[mid].time < t then lo = mid + 1 else hi = mid end
    end
    return lo
end

local function freshStats()
    return {
        processed = 0,
        executed = 0,
        skipped = 0,
        failed = 0,
        late = 0,
        driftSumMs = 0,
        driftPeakMs = 0,
        driftEmaMs = 0,
        catchups = 0,
        frames = 0,
        overBudgetFrames = 0,
        maxEventsInFrame = 0,
        restored = 0,
    }
end

function Scheduler.new(noteManager)
    local self = setmetatable({}, Scheduler)
    self.noteManager = noteManager
    self.events = {}
    self.index = 1
    self.duration = 0
    self.position = 0
    self.speed = 1
    self.playing = false
    self.paused = false
    self.loopSong = false
    self.loopA, self.loopB = nil, nil
    self.maxLateMs = 90
    self.lateMode = "Adaptive"
    self.maxEventsPerFrame = 640
    self.restoreHeldOnSeek = true
    self.stats = freshStats()
    self.lastUi = 0
    self.uiInterval = .04
    return self
end

function Scheduler:setEvents(events, duration, rebuildAt)
    self:stop(false)
    self.events = {}
    for i, e in ipairs(events or {}) do
        local c = {}
        for k, v in pairs(e) do c[k] = v end
        c.sequence = c.sequence or i
        self.events[#self.events + 1] = c
    end
    table.sort(self.events, function(a, b)
        if a.time == b.time then return (a.sequence or 0) < (b.sequence or 0) end
        return a.time < b.time
    end)
    self.duration = math.max(0, duration or 0)
    self.rebuildAt = rebuildAt
    self.index, self.position = 1, 0
    self.stats = freshStats()
end

function Scheduler:setOptions(o)
    o = o or {}
    self.maxLateMs = math.clamp(tonumber(o.maxLateMs) or self.maxLateMs, 10, 1000)
    self.lateMode = o.lateMode or self.lateMode
    self.loopSong = o.loopSong == true
    self.maxEventsPerFrame = math.clamp(tonumber(o.maxEventsPerFrame) or self.maxEventsPerFrame, 64, 4096)
    self.uiInterval = math.clamp((tonumber(o.uiIntervalMs) or 40) / 1000, .016, .25)
    self.restoreHeldOnSeek = o.restoreHeldOnSeek ~= false
end

function Scheduler:setAB(a, b)
    if a and b and b > a then
        self.loopA = math.clamp(a, 0, self.duration)
        self.loopB = math.clamp(b, 0, self.duration)
    else
        self.loopA, self.loopB = nil, nil
    end
end

function Scheduler:_clockPosition()
    if not self.playing then return self.position end
    return self.positionAnchor + (os.clock() - self.clockAnchor) * self.speed
end

function Scheduler:_shouldSkip(e, lateMs)
    if self.lateMode == "CatchUp" then return false end
    local attack = e.action == "down" or e.action == "tap" or e.action == "strike"
    if not attack or lateMs <= self.maxLateMs then return false end
    if self.lateMode == "SkipLate" then return true end

    local n = e.note
    if n and n.parts and (n.parts.melody or n.parts.bass) then return false end
    local v = e.velocity or (n and n.velocity) or .5
    if v > 1 then v /= 127 end
    if v >= .82 then return false end
    return lateMs > self.maxLateMs * 2.5
end

function Scheduler:_dispatch(e)
    local okCall, ok, err = pcall(function()
        if e.action == "strike" then
            local scaledHold = (e.holdMs or 34) / math.max(.05, self.speed)
            return self.noteManager:strike(e.token, {
                velocity = e.velocity,
                holdMs = scaledHold,
                nativeVelocity = e.nativeVelocity,
                note = e.note,
            })
        elseif e.action == "tap" then
            return self.noteManager:tap(e.token)
        elseif e.action == "down" then
            return self.noteManager:down(e.token)
        elseif e.action == "up" then
            return self.noteManager:up(e.token)
        end
        return false, "unknown scheduler action: " .. tostring(e.action)
    end)

    if not okCall then return false, tostring(ok) end
    if ok == false then return false, tostring(err or "input rejected event") end
    return true
end

function Scheduler:_recordDrift(late)
    self.stats.driftSumMs += late
    self.stats.driftPeakMs = math.max(self.stats.driftPeakMs, late)
    if self.stats.processed <= 1 then self.stats.driftEmaMs = late
    else self.stats.driftEmaMs = self.stats.driftEmaMs * .92 + late * .08 end
    if late > self.maxLateMs then self.stats.late += 1 end
end

function Scheduler:_process(p)
    local processedFrame = 0
    local lastTime = nil
    local hardCap = self.maxEventsPerFrame * 2

    while self.index <= #self.events do
        local e = self.events[self.index]
        if e.time > p then break end

        if processedFrame >= self.maxEventsPerFrame and lastTime ~= nil and e.time ~= lastTime then
            break
        end
        if processedFrame >= hardCap then break end

        local late = math.max(0, (p - e.time) * 1000)
        self.stats.processed += 1
        processedFrame += 1
        self:_recordDrift(late)

        if self:_shouldSkip(e, late) then
            self.stats.skipped += 1
        else
            local ok, err = self:_dispatch(e)
            if ok then
                self.stats.executed += 1
                if late > self.maxLateMs and (e.action == "strike" or e.action == "tap" or e.action == "down") then
                    self.stats.catchups += 1
                end
                if self.onEvent then pcall(self.onEvent, e, late) end
            else
                self.stats.failed += 1
                if self.onError then pcall(self.onError, err, e) end
            end
        end

        lastTime = e.time
        self.index += 1
    end

    self.stats.frames += 1
    self.stats.maxEventsInFrame = math.max(self.stats.maxEventsInFrame, processedFrame)
    if self.index <= #self.events and self.events[self.index].time <= p then
        self.stats.overBudgetFrames += 1
    end
end

function Scheduler:_restoreHeldAt(position)
    if not self.restoreHeldOnSeek or position <= 0 then return end
    local stop = lowerBound(self.events, position) - 1
    if stop <= 0 then return end

    local active = {}
    for i = 1, stop do
        local e = self.events[i]
        if e.action == "down" then
            active[e.token] = (active[e.token] or 0) + 1
        elseif e.action == "up" and active[e.token] then
            active[e.token] = math.max(0, active[e.token] - 1)
        end
    end

    for token, count in pairs(active) do
        for _ = 1, count do
            local ok = self.noteManager:down(token)
            if ok ~= false then self.stats.restored += 1 end
        end
    end
end

function Scheduler:_connect()
    if self.connection then self.connection:Disconnect() end
    self.connection = RunService.Heartbeat:Connect(function()
        if not self.playing then return end
        local p = self:_clockPosition()
        self:_process(p)

        if self.loopB and p >= self.loopB then
            local nextEvent = self.events[self.index]
            if not nextEvent or nextEvent.time >= self.loopB then
                self:seek(self.loopA or 0, true)
                return
            end
        end

        local now = os.clock()
        if self.onPosition and now - self.lastUi >= self.uiInterval then
            self.lastUi = now
            self.onPosition(math.min(p, self.duration), self.duration, self.stats)
        end

        if p >= self.duration and self.index > #self.events then
            if self.loopSong and self.duration > 0 then
                self:seek(0, true)
            else
                self:stop(false)
                self.position = self.duration
                if self.onPosition then self.onPosition(self.duration, self.duration, self.stats) end
                if self.onFinished then self.onFinished() end
            end
        end
    end)
end

function Scheduler:play()
    if self.playing then return end
    if self.position >= self.duration then self.position, self.index = 0, 1 end

    self.noteManager:releaseAll()
    if self.rebuildAt and self.position > 0 then pcall(self.rebuildAt, self.position) end
    self:_restoreHeldAt(self.position)

    self.positionAnchor, self.clockAnchor = self.position, os.clock()
    self.playing, self.paused = true, false
    self.lastUi = 0
    self:_connect()
end

function Scheduler:pause()
    if not self.playing then return end
    self.position = math.min(self:_clockPosition(), self.duration)
    self.playing, self.paused = false, true
    if self.connection then self.connection:Disconnect(); self.connection = nil end
    self.noteManager:releaseAll()
    if self.onPosition then self.onPosition(self.position, self.duration, self.stats) end
end

function Scheduler:stop(reset)
    if self.playing then self.position = math.min(self:_clockPosition(), self.duration) end
    self.playing, self.paused = false, false
    if self.connection then self.connection:Disconnect(); self.connection = nil end
    self.noteManager:releaseAll()
    if reset ~= false then self.position, self.index = 0, 1 end
end

function Scheduler:seek(pos, keep)
    local was = keep == nil and self.playing or keep
    if self.playing then self:pause() else self.noteManager:releaseAll() end
    self.position = math.clamp(pos or 0, 0, self.duration)
    self.index = lowerBound(self.events, self.position)
    if was then self:play()
    elseif self.onPosition then self.onPosition(self.position, self.duration, self.stats) end
end

function Scheduler:setSpeed(v)
    v = math.clamp(v or 1, .25, 2)
    if self.playing then
        self.position = self:_clockPosition()
        self.positionAnchor, self.clockAnchor = self.position, os.clock()
    end
    self.speed = v
    if self.onSpeed then pcall(self.onSpeed, v) end
end

function Scheduler:isPlaying() return self.playing end
function Scheduler:getPosition() return math.clamp(self:_clockPosition(), 0, math.max(0, self.duration)) end
function Scheduler:getSpeed() return self.speed end

function Scheduler:diagnostics()
    return {
        playing = self.playing,
        position = self:getPosition(),
        duration = self.duration,
        index = self.index,
        eventCount = #self.events,
        speed = self.speed,
        lateMode = self.lateMode,
        maxLateMs = self.maxLateMs,
        maxEventsPerFrame = self.maxEventsPerFrame,
        stats = self.stats,
    }
end

function Scheduler:destroy()
    self:stop()
    self.onPosition, self.onEvent, self.onFinished, self.onSpeed, self.onError = nil, nil, nil, nil, nil
end

return Scheduler
