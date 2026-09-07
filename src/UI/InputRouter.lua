local Router={};Router.__index=Router
function Router.new(UIS)
 local self=setmetatable({connections={},owner=nil,threshold=8,bindings={}},Router)
 self.connections[1]=UIS.InputChanged:Connect(function(i)
  local o=self.owner;if not o then return end
  if i==o.input or (o.mouse and i.UserInputType==Enum.UserInputType.MouseMovement)then
   local distance=(i.Position-o.start).Magnitude
   if distance>=self.threshold then o.drag=true end
   if o.handlers.move then o.handlers.move(i.Position,o.drag)end
  end
 end)
 self.connections[2]=UIS.InputEnded:Connect(function(i)
  local o=self.owner;if o and (i==o.input or (o.mouse and i.UserInputType==Enum.UserInputType.MouseButton1))then
   self.owner=nil;if o.handlers.finish then o.handlers.finish(i.Position,o.drag)end
  end
 end)
 return self
end
function Router:bind(object,handlers)
 local c=object.InputBegan:Connect(function(i)
  local mouse=i.UserInputType==Enum.UserInputType.MouseButton1
  if self.owner or (not mouse and i.UserInputType~=Enum.UserInputType.Touch)then return end
  self.owner={object=object,input=i,mouse=mouse,start=i.Position,handlers=handlers,drag=false}
  if handlers.begin then handlers.begin(i.Position)end
 end)
 local token={};self.bindings[token]=c
 local destroyed;destroyed=object.Destroying:Connect(function()c:Disconnect();self.bindings[token]=nil;if self.owner and self.owner.object==object then self:cancel()end;destroyed:Disconnect()end)
 return c
end
function Router:cancel()local o=self.owner;self.owner=nil;if o and o.handlers.cancel then o.handlers.cancel()end end
function Router:destroy()self:cancel();for _,c in pairs(self.bindings)do c:Disconnect()end;table.clear(self.bindings);for _,c in ipairs(self.connections)do c:Disconnect()end;table.clear(self.connections)end
return Router
