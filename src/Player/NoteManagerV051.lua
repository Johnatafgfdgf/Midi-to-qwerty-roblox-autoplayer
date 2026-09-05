local NoteManager={};NoteManager.__index=NoteManager
function NoteManager.new(adapter)return setmetatable({adapter=adapter,refs={},tokens={},activeCount=0},NoteManager)end
function NoteManager:strike(token,opts)return self.adapter:strike(token,opts)end
function NoteManager:tap(token)return self.adapter:tap(token)end
function NoteManager:down(token)
    local id=self.adapter:physicalId(token);local count=self.refs[id] or 0;self.refs[id]=count+1;self.tokens[id]=token
    if count==0 then local ok,err=self.adapter:press(token);if not ok then self.refs[id]=nil;self.tokens[id]=nil;return false,err end;self.activeCount+=1 end
    return true
end
function NoteManager:up(token)
    local id=self.adapter:physicalId(token);local count=self.refs[id] or 0;if count<=0 then return true end
    count-=1
    if count==0 then self.refs[id]=nil;local original=self.tokens[id] or token;self.tokens[id]=nil;self.adapter:release(original);self.activeCount=math.max(0,self.activeCount-1) else self.refs[id]=count end
    return true
end
function NoteManager:releaseAll()
    for id,token in pairs(self.tokens)do pcall(function()self.adapter:release(token)end);self.refs[id],self.tokens[id]=nil,nil end
    if self.adapter.releaseExpressive then pcall(function()self.adapter:releaseExpressive()end)end
    if self.adapter.releaseModifiers then pcall(function()self.adapter:releaseModifiers()end)end
    self.activeCount=0
end
return NoteManager
