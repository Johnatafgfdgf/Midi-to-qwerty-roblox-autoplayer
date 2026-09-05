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

function Scheduler.new(noteManager)
    local self = setmetatable({}, Scheduler)
    self.noteManager = noteManager
    self.events, self.index, self.duration = {}, 1, 0
    self.position, self.speed, self.playing, self.paused = 0, 1, false, false
    self.loopSong, self.maxLateMs, self.lateMode = false, 85, "Adaptive"
    self.stats = {processed = 0, skipped = 0, late = 0, driftSumMs = 0, driftPeakMs = 0}
    self.onPosition, self.onFinished, self.rebuildAt = nil, nil, nil
    self.lastUi = 0
    return self
end

function Scheduler:setEvents(events, duration, rebuildAt)
    self:stop(false)
    self.events, self.duration, self.rebuildAt = events or {}, duration or 0, rebuildAt
    self.index, self.position = 1, 0
    self.stats = {processed = 0, skipped = 0, late = 0, driftSumMs = 0, driftPeakMs = 0}
end

function Scheduler:setOptions(options)
    options = options or {}
    self.maxLateMs = options.maxLateMs or self.maxLateMs
    self.lateMode = options.lateMode or self.lateMode
    self.loopSong = options.loopSong == true
end

function Scheduler:_clockPosition()
    if not self.playing then return self.position end
    return self.positionAnchor + (os.clock() - self.clockAnchor) * self.speed
end

function Scheduler:_shouldSkip(e, lateMs)
    if e.action ~= "down" or lateMs <= self.maxLateMs then return false end
    if self.lateMode == "CatchUp" then return false end
    if self.lateMode == "SkipLate" then return true end
    local n = e.note
    if n and n.parts and (n.parts.melody or n.parts.bass) then return false end
    if n and (n.velocity or 64) >= 105 then return false end
    local remaining = n and (n.endTime - self:_clockPosition()) or 0
    return remaining < 0.055 or lateMs > self.maxLateMs * 2.2
end

function Scheduler:_process(nowPos)
    while self.index <= #self.events do
        local e = self.events[self.index]
        if e.time > nowPos then break end
        local lateMs = math.max(0, (nowPos - e.time) * 1000)
        self.stats.processed += 1
        self.stats.driftSumMs += lateMs
        self.stats.driftPeakMs = math.max(self.stats.driftPeakMs, lateMs)
        if lateMs > self.maxLateMs then self.stats.late += 1 end
        if self:_shouldSkip(e, lateMs) then
            self.stats.skipped += 1
        elseif e.action == "down" then
            self.noteManager:down(e.token)
        else
            self.noteManager:up(e.token)
        end
        self.index += 1
    end
end

function Scheduler:_connect()
    if self.connection then self.connection:Disconnect() end
    self.connection = RunService.Heartbeat:Connect(function()
        if not self.playing then return end
        local p = self:_clockPosition()
        self:_process(p)
        if self.onPosition and os.clock() - self.lastUi >= 0.1 then
            self.lastUi = os.clock()
            self.onPosition(math.min(p, self.duration), self.duration, self.stats)
        end
        if p >= self.duration then
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
    self.positionAnchor, self.clockAnchor = self.position, os.clock()
    self.playing, self.paused = true, false
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

function Scheduler:stop(resetPosition)
    if self.playing then self.position = math.min(self:_clockPosition(), self.duration) end
    self.playing, self.paused = false, false
    if self.connection then self.connection:Disconnect(); self.connection = nil end
    self.noteManager:releaseAll()
    if resetPosition ~= false then self.position, self.index = 0, 1 end
end

function Scheduler:seek(position, keepPlaying)
    local wasPlaying = keepPlaying == nil and self.playing or keepPlaying
    self:pause()
    self.position = math.clamp(position or 0, 0, self.duration)
    self.index = lowerBound(self.events, self.position)
    self.noteManager:releaseAll()
    if wasPlaying then self:play() elseif self.onPosition then self.onPosition(self.position, self.duration, self.stats) end
end

function Scheduler:setSpeed(speed)
    speed = math.clamp(speed or 1, 0.25, 2)
    if self.playing then
        self.position = self:_clockPosition()
        self.positionAnchor, self.clockAnchor = self.position, os.clock()
    end
    self.speed = speed
end

function Scheduler:isPlaying() return self.playing end
function Scheduler:getPosition() return self:_clockPosition() end

return Scheduler
