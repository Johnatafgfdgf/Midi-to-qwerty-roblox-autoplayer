local State={};State.__index=State
function State.new(initial)return setmetatable({value=initial or {},listeners={},revision=0},State)end
function State:patch(values)
 for k,v in pairs(values)do self.value[k]=v end
 self.revision+=1
 for _,fn in pairs(self.listeners)do fn(self.value,self.revision)end
end
function State:subscribe(fn)
 local token={};self.listeners[token]=fn;fn(self.value,self.revision)
 return function()self.listeners[token]=nil end
end
function State:destroy()table.clear(self.listeners)end
return State
