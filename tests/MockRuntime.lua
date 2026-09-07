local clock=0
local jobs={}
local function signal()
 local s={listeners={}}
 function s:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;s.listeners[#s.listeners+1]={fn,c};return c end
 function s:Fire(...)for _,x in ipairs(self.listeners)do if x[2].Connected then x[1](...)end end end
 return s
end
local heartbeat=signal()
local os={clock=function()return clock end,time=function()return 123456 end}
local task={delay=function(t,fn)jobs[#jobs+1]={clock+t,fn}end,spawn=function(fn)fn()end}
local function advance(t)
 clock+=t
 local remaining={};local due={}
 for _,j in ipairs(jobs)do if j[1]<=clock then due[#due+1]=j else remaining[#remaining+1]=j end end
 jobs=remaining;for _,j in ipairs(due)do j[2]()end
 heartbeat:Fire(t)
end
local keyLog={}
local env={keypress=function(k)keyLog[#keyLog+1]={clock,true,k}end,keyrelease=function(k)keyLog[#keyLog+1]={clock,false,k}end}
local function getgenv()return env end
local game={GetService=function(_,name)if name=='RunService' then return {Heartbeat=heartbeat}end;return {}end}
local function check(name,fn)local ok,err=pcall(fn);if not ok then error('FAIL '..name..': '..tostring(err))end;print('PASS '..name)end
-- Lightweight Roblox contract/layout model. Not an emulator of Roblox rendering or input dispatch.
local viewport={X=1280,Y=720}
local Vec={};Vec.__index=function(t,k)if k=='Magnitude'then return math.sqrt(t.X*t.X+t.Y*t.Y)end;return Vec[k]end
Vec.__sub=function(a,b)return setmetatable({X=a.X-b.X,Y=a.Y-b.Y,Z=(a.Z or 0)-(b.Z or 0)},Vec)end
local Vector2={new=function(x,y)return setmetatable({X=x,Y=y},Vec)end}
local Vector3={new=function(x,y,z)return setmetatable({X=x,Y=y,Z=z},Vec)end}
local UDim={new=function(s,o)return {Scale=s,Offset=o}end}
local UDim2={new=function(a,b,c,d)return {X=UDim.new(a or 0,b or 0),Y=UDim.new(c or 0,d or 0)}end}
UDim2.fromOffset=function(x,y)return UDim2.new(0,x,0,y)end;UDim2.fromScale=function(x,y)return UDim2.new(x,0,y,0)end
local Color3={new=function(r,g,b)return {R=r,G=g,B=b}end,fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end}
local ColorSequence={new=function(a,b)return {a,b}end}
local NumberSequence={new=function(a)return a end}
local Enum=setmetatable({},{__index=function(t,k)local v=setmetatable({},{__index=function(s,n)rawset(s,n,n);return n end});rawset(t,k,v);return v end})
local TweenInfo={new=function(...)return {...}end}
local instances={};local serial=0;local methods={};local dimensions
local function isGUI(o)return o and (o.ClassName=='Frame'or o.ClassName=='TextLabel'or o.ClassName=='TextBox'or o.ClassName=='TextButton'or o.ClassName=='ScrollingFrame'or o.ClassName=='CanvasGroup')end
local function children(o)local out={};for _,x in ipairs(instances)do if x.Parent==o and not x._destroyed then out[#out+1]=x end end;return out end
local function size(o,parentWidth,parentHeight)
 local p=o._props;local w=p.Size.X.Scale*parentWidth+p.Size.X.Offset;local h=p.Size.Y.Scale*parentHeight+p.Size.Y.Offset
 for _,c in ipairs(children(o))do if c.ClassName=='UISizeConstraint'then w=math.clamp(w,c.MinSize and c.MinSize.X or 0,c.MaxSize.X);h=math.clamp(h,c.MinSize and c.MinSize.Y or 0,c.MaxSize.Y)end end
 if p.AutomaticSize=='Y'then
  local sum,count,gap=0,0,0
  for _,c in ipairs(children(o))do if c.ClassName=='UIListLayout'then gap=c.Padding.Offset end end
  for _,c in ipairs(children(o))do if isGUI(c)and c.Visible then local _,ch=size(c,w,0);sum+=ch;count+=1 end end
  h=math.max(h,sum+math.max(0,count-1)*gap)
 end
 return w,h
end
dimensions=function(o)
 if not isGUI(o)then return 0,0,viewport.X,viewport.Y end
 local px,py,pw,ph=dimensions(o.Parent);local p=o._props;local w,h=size(o,pw,ph)
 local x,y=px+p.Position.X.Scale*pw+p.Position.X.Offset,py+p.Position.Y.Scale*ph+p.Position.Y.Offset
 local layout
 for _,sibling in ipairs(children(o.Parent))do if sibling.ClassName=='UIListLayout'then layout=sibling end end
 if layout then
  local preceding=0
  for _,sibling in ipairs(children(o.Parent))do if sibling==o then break end;if isGUI(sibling)and sibling.Visible then local _,sh=size(sibling,pw,ph);preceding+=sh+layout.Padding.Offset end end
  y=py+preceding;x=px
 end
 return x-p.AnchorPoint.X*w,y-p.AnchorPoint.Y*h,w,h
end
function methods:GetChildren()return children(self)end
function methods:GetDescendants()local out={};for _,c in ipairs(children(self))do out[#out+1]=c;for _,d in ipairs(c:GetDescendants())do out[#out+1]=d end end;return out end
function methods:IsA(name)return self.ClassName==name or name=='GuiObject'and isGUI(self)end
function methods:IsDescendantOf(o)local p=self.Parent;while p do if p==o then return true end;p=p.Parent end;return false end
function methods:GetPropertyChangedSignal(prop)self._signals[prop]=self._signals[prop]or signal();return self._signals[prop]end
function methods:Destroy()if self._destroyed then return end;self.Destroying:Fire();for _,c in ipairs(children(self))do c:Destroy()end;self._destroyed=true;self.Parent=nil end
function methods:FindFirstChild(name)for _,c in ipairs(children(self))do if c.Name==name then return c end end end
function methods:WaitForChild(name)return self:FindFirstChild(name)end
local Instance={}
function Instance.new(class)
 serial+=1
 local o={_id=serial,_props={ClassName=class,Name=class,Size=UDim2.fromOffset(100,100),Position=UDim2.fromOffset(0,0),AnchorPoint=Vector2.new(0,0),Visible=true,BackgroundTransparency=0,ZIndex=1,Text='',TextSize=14,Padding=UDim.new(0,0)},_signals={}}
 setmetatable(o,{__index=function(t,k)
  if methods[k]then return methods[k]end
  if k=='AbsolutePosition'then local x,y=dimensions(t);return Vector2.new(x,y)end
  if k=='AbsoluteSize'then local _,_,w,h=dimensions(t);return Vector2.new(w,h)end
  if k=='InputBegan'or k=='InputEnded'or k=='Activated'or k=='Destroying'or k=='FocusLost'then t._signals[k]=t._signals[k]or signal();return t._signals[k]end
  return t._props[k]
 end,__newindex=function(t,k,v)if k:sub(1,1)=='_'then rawset(t,k,v);return end;local old=t._props[k];t._props[k]=v;if old~=v and t._signals[k]then t._signals[k]:Fire()end end})
 instances[#instances+1]=o;return o
end
local root=Instance.new('CoreGui');local userInput={InputChanged=signal(),InputEnded=signal()};local render=signal()
local services={CoreGui=root,UserInputService=userInput,RunService={Heartbeat=heartbeat,RenderStepped=render},TweenService={Create=function(_,o,info,props)return {Play=function()for k,v in pairs(props)do o[k]=v end end}end},HttpService={JSONEncode=function()return '{}'end,JSONDecode=function()return {}end}}
game.GetService=function(_,name)return services[name]or {}end;game.GameId=123;game.PlaceId=456
local workspace={CurrentCamera={ViewportSize=viewport}}
local function toJSON(v)
 local t=type(v);if t=='nil'then return 'null'elseif t=='boolean'or t=='number'then return tostring(v)elseif t=='string'then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"'end
 local out={};if #v>0 then for _,x in ipairs(v)do out[#out+1]=toJSON(x)end;return '['..table.concat(out,',')..']'end
 for k,x in pairs(v)do out[#out+1]=toJSON(tostring(k))..':'..toJSON(x)end;return '{'..table.concat(out,',')..'}'
end
local function snapshot(app,label)
 local draw={}
 local function walk(o,clip)
  if not o.Visible then return end
  if isGUI(o)then
   local x,y,w,h=dimensions(o);local p=o._props;local radius=0
   for _,c in ipairs(children(o))do if c.ClassName=='UICorner'then radius=c.CornerRadius.Offset end end
   local color=p.BackgroundColor3 or Color3.fromRGB(255,255,255);local tc=p.TextColor3 or color
   draw[#draw+1]={id=o._id,name=o.Name,class=o.ClassName,x=x,y=y,w=w,h=h,bg={color.R,color.G,color.B},alpha=1-(p.BackgroundTransparency or 0),text=p.Text or '',fontSize=p.TextSize or 14,fg={tc.R,tc.G,tc.B},radius=radius,align=p.TextXAlignment or 'Left',wrap=p.TextWrapped or false,clip=clip}
   if o.ClassName=='ScrollingFrame'or o.ClipsDescendants then clip={x,y,w,h}end
  end
  local cs=children(o);table.sort(cs,function(a,b)if a.ZIndex==b.ZIndex then return a._id<b._id end;return a.ZIndex<b.ZIndex end)
  for _,c in ipairs(cs)do if isGUI(c)then walk(c,clip)end end
 end
 walk(app.root,{0,0,viewport.X,viewport.Y});if capture then capture(label,toJSON({width=viewport.X,height=viewport.Y,draw=draw}))end
end
