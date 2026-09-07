local Scheduler={}
Scheduler.__index=Scheduler
local RunService=game:GetService("RunService")

local function lowerBound(events,t)
    local lo,hi=1,#events+1
    while lo<hi do
        local mid=math.floor((lo+hi)/2)
        if mid<=#events and events[mid].time<t then lo=mid+1 else hi=mid end
    end
    return lo
end

function Scheduler.new(noteManager)
    local s=setmetatable({},Scheduler)
    s.noteManager=noteManager;s.events={};s.index=1;s.duration=0;s.position=0;s.speed=1;s.playing=false;s.paused=false
    s.loopSong=false;s.loopA=nil;s.loopB=nil;s.maxLateMs=140;s.lateMode="CatchUp"
    s.stats={processed=0,skipped=0,late=0,driftSumMs=0,driftPeakMs=0,catchups=0}
    s.lastUi=0;s.uiInterval=.05
    return s
end

function Scheduler:setEvents(events,duration,rebuildAt)
    self:stop(false);self.events=events or {};self.duration=duration or 0;self.rebuildAt=rebuildAt;self.index=1;self.position=0
    self.stats={processed=0,skipped=0,late=0,driftSumMs=0,driftPeakMs=0,catchups=0}
end
function Scheduler:setOptions(o)
    o=o or {};self.maxLateMs=o.maxLateMs or self.maxLateMs;self.lateMode=o.lateMode or self.lateMode;self.loopSong=o.loopSong==true
end
function Scheduler:setAB(a,b)
    if a and b and b>a then self.loopA,self.loopB=math.clamp(a,0,self.duration),math.clamp(b,0,self.duration)else self.loopA,self.loopB=nil,nil end
end
function Scheduler:_clockPosition()
    if not self.playing then return self.position end
    return self.positionAnchor+(os.clock()-self.clockAnchor)*self.speed
end
function Scheduler:_shouldSkip(e,lateMs)
    if self.lateMode=="CatchUp" then return false end
    if (e.action~="down" and e.action~="tap" and e.action~="strike") or lateMs<=self.maxLateMs then return false end
    if self.lateMode=="SkipLate" then return true end
    local n=e.note;if n and n.parts and (n.parts.melody or n.parts.bass)then return false end
    local v=e.velocity or(n and n.velocity)or .5;if v>1 then v=v/127 end;if v>=.82 then return false end
    return lateMs>self.maxLateMs*2.5
end
function Scheduler:_process(p)
    while self.index<=#self.events do
        local e=self.events[self.index];if e.time>p then break end
        local late=math.max(0,(p-e.time)*1000)
        self.stats.processed+=1;self.stats.driftSumMs+=late;self.stats.driftPeakMs=math.max(self.stats.driftPeakMs,late);if late>self.maxLateMs then self.stats.late+=1 end
        if self:_shouldSkip(e,late) then self.stats.skipped+=1
        elseif e.action=="strike" then self.noteManager:strike(e.token,{velocity=e.velocity,holdMs=e.holdMs,nativeVelocity=e.nativeVelocity,note=e.note})
        elseif e.action=="tap" then self.noteManager:tap(e.token)
        elseif e.action=="down" then self.noteManager:down(e.token)
        else self.noteManager:up(e.token) end
        if late>self.maxLateMs and(e.action=="strike" or e.action=="tap" or e.action=="down")then self.stats.catchups+=1 end
        if self.onEvent then pcall(self.onEvent,e)end
        self.index+=1
    end
end
function Scheduler:_connect()
    if self.connection then self.connection:Disconnect()end
    self.connection=RunService.Heartbeat:Connect(function()
        if not self.playing then return end
        local p=self:_clockPosition();self:_process(p)
        if self.loopB and p>=self.loopB then self:seek(self.loopA or 0,true);return end
        local now=os.clock()
        if self.onPosition and now-self.lastUi>=self.uiInterval then self.lastUi=now;self.onPosition(math.min(p,self.duration),self.duration,self.stats)end
        if p>=self.duration then
            if self.loopSong and self.duration>0 then self:seek(0,true)
            else
                self:stop(false);self.position=self.duration
                if self.onPosition then self.onPosition(self.duration,self.duration,self.stats)end
                if self.onFinished then self.onFinished()end
            end
        end
    end)
end
function Scheduler:play()
    if self.playing then return end
    if self.position>=self.duration then self.position,self.index=0,1 end
    self.noteManager:releaseAll()
    if self.rebuildAt and self.position>0 then pcall(self.rebuildAt,self.position)end
    self.positionAnchor,self.clockAnchor=self.position,os.clock();self.playing,self.paused=true,false;self.lastUi=0;self:_connect()
end
function Scheduler:pause()
    if not self.playing then return end
    self.position=math.min(self:_clockPosition(),self.duration);self.playing,self.paused=false,true
    if self.connection then self.connection:Disconnect();self.connection=nil end
    self.noteManager:releaseAll();if self.onPosition then self.onPosition(self.position,self.duration,self.stats)end
end
function Scheduler:stop(reset)
    if self.playing then self.position=math.min(self:_clockPosition(),self.duration)end
    self.playing,self.paused=false,false;if self.connection then self.connection:Disconnect();self.connection=nil end
    self.noteManager:releaseAll();if reset~=false then self.position,self.index=0,1 end
end
function Scheduler:seek(pos,keep)
    local was=keep==nil and self.playing or keep
    if self.playing then self:pause()else self.noteManager:releaseAll()end
    self.position=math.clamp(pos or 0,0,self.duration);self.index=lowerBound(self.events,self.position)
    if was then self:play()elseif self.onPosition then self.onPosition(self.position,self.duration,self.stats)end
end
function Scheduler:setSpeed(v)
    v=math.clamp(v or 1,.25,2)
    if self.playing then self.position=self:_clockPosition();self.positionAnchor,self.clockAnchor=self.position,os.clock()end
    self.speed=v
end
function Scheduler:isPlaying()return self.playing end
function Scheduler:getPosition()return self:_clockPosition()end
return Scheduler
