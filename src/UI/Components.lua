local C={}
C.colors={bg=Color3.fromRGB(13,17,27),panel=Color3.fromRGB(25,30,46),edge=Color3.fromRGB(67,74,101),text=Color3.fromRGB(241,243,251),muted=Color3.fromRGB(163,173,194),accent=Color3.fromRGB(150,118,245),left=Color3.fromRGB(74,215,186),right=Color3.fromRGB(158,127,255)}
function C.new(class,parent,props)
 local o=Instance.new(class);for k,v in pairs(props or {})do o[k]=v end;o.Parent=parent;return o
end
function C.round(o,r)C.new('UICorner',o,{CornerRadius=UDim.new(0,r or 12)})end
function C.surface(parent,props)
 local f=C.new('Frame',parent,{BackgroundColor3=C.colors.bg,BackgroundTransparency=.08,BorderSizePixel=0});for k,v in pairs(props or {})do f[k]=v end
 C.round(f,18);C.new('UIStroke',f,{Color=C.colors.edge,Transparency=.42,Thickness=1})
 C.new('UIGradient',f,{Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(181,190,219)),Rotation=80})
 return f
end
function C.label(parent,text,size)
 return C.new('TextLabel',parent,{BackgroundTransparency=1,Text=text or '',TextColor3=C.colors.text,TextSize=size or 14,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,Size=UDim2.new(1,0,0,24),TextTruncate=Enum.TextTruncate.AtEnd})
end
function C.button(parent,text,fn,primary)
 local b=C.new('TextButton',parent,{Name=text,Text=text,TextXAlignment=Enum.TextXAlignment.Center,TextSize=14,Font=primary and Enum.Font.GothamBold or Enum.Font.GothamMedium,TextColor3=primary and C.colors.bg or C.colors.text,BackgroundColor3=primary and C.colors.accent or C.colors.panel,BackgroundTransparency=primary and 0 or .15,AutoButtonColor=false,BorderSizePixel=0,Size=UDim2.fromOffset(44,44)})
 C.round(b,primary and 16 or 10)
 if fn then b.Activated:Connect(fn)end
 b.InputBegan:Connect(function(i)if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then b.BackgroundTransparency=.35 end end)
 b.InputEnded:Connect(function()b.BackgroundTransparency=primary and 0 or .15 end)
 return b
end
C.IconButton=C.button
function C.textbox(parent,placeholder)
 local b=C.new('TextBox',parent,{PlaceholderText=placeholder,Text='',ClearTextOnFocus=false,TextSize=14,Font=Enum.Font.Gotham,TextColor3=C.colors.text,PlaceholderColor3=C.colors.muted,BackgroundColor3=C.colors.panel,BorderSizePixel=0,Size=UDim2.new(1,0,0,44),TextXAlignment=Enum.TextXAlignment.Left});C.round(b,12);C.new('UIPadding',b,{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)});return b
end
function C.list(parent,gap)
 return C.new('UIListLayout',parent,{Padding=UDim.new(0,gap or 8),SortOrder=Enum.SortOrder.LayoutOrder})
end
function C.row(parent,height)return C.new('Frame',parent,{BackgroundTransparency=1,Size=UDim2.new(1,0,0,height or 44)})end
function C.segmented(parent,items,callback)
 local f=C.row(parent);local buttons={}
 for i,item in ipairs(items)do local b=C.button(f,item.label,function()callback(item.value)end);b.Size=UDim2.new(1/#items,-4,1,0);b.Position=UDim2.new((i-1)/#items,2,0,0);buttons[item.value]=b end
 return {frame=f,set=function(v)for key,b in pairs(buttons)do b.BackgroundColor3=key==v and C.colors.accent or C.colors.panel;b.TextColor3=key==v and C.colors.bg or C.colors.text end end}
end
function C.toggle(parent,text,value,callback)local b=C.button(parent,'',function()value=not value;callback(value)end);b.Size=UDim2.new(1,0,0,44);b.Text=text..(value and '  • ON' or '  • OFF');return b end
function C.slider(parent,router,min,max,value,commit,format)
 local f=C.row(parent,44);f.Active=true
 local track=C.new('Frame',f,{Position=UDim2.new(0,10,.5,-3),Size=UDim2.new(1,-20,0,6),BackgroundColor3=C.colors.edge,BorderSizePixel=0});C.round(track,3)
 local fill=C.new('Frame',track,{Size=UDim2.fromScale(0,1),BackgroundColor3=C.colors.accent,BorderSizePixel=0});C.round(fill,3)
 local thumb=C.new('Frame',track,{Size=UDim2.fromOffset(14,14),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(0,.5),BackgroundColor3=C.colors.text,BorderSizePixel=0});C.round(thumb,7)
 local hint=C.label(f,'',12);hint.Size=UDim2.fromOffset(74,28);hint.BackgroundColor3=C.colors.panel;hint.BackgroundTransparency=0;hint.Visible=false;hint.TextXAlignment=Enum.TextXAlignment.Center;C.round(hint,8)
 local self={frame=f,dragging=false,value=value}
 function self:set(v)self.value=math.clamp(v,min,max);local r=max>min and (self.value-min)/(max-min)or 0;fill.Size=UDim2.fromScale(r,1);thumb.Position=UDim2.fromScale(r,.5)end
 local function preview(p)local r=math.clamp((p.X-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1);self:set(min+r*(max-min));hint.Text=format and format(self.value) or string.format('%.2f',self.value);hint.Position=UDim2.fromOffset(math.clamp(p.X-f.AbsolutePosition.X-37,0,math.max(0,f.AbsoluteSize.X-74)),-24)end
 router:bind(f,{begin=function(p)self.dragging=true;hint.Visible=true;preview(p)end,move=function(p)preview(p)end,finish=function(p)preview(p);self.dragging=false;hint.Visible=false;commit(self.value)end,cancel=function()self.dragging=false;hint.Visible=false end})
 self:set(value);return self
end
function C.seekbar(parent,router,state,seek)
 local s=C.slider(parent,router,0,1,0,function(r)if state.value.duration>0 then seek(r*state.value.duration)end end,function(r)local t=r*(state.value.duration or 0);return string.format('%02d:%02d',t//60,t%60)end)
 s.unsubscribe=state:subscribe(function(v)if not s.dragging then s:set(v.duration>0 and v.position/v.duration or 0)end end);return s
end
function C.speed(parent,router,state,step,select,setSpeed)
 local f=C.row(parent);local minus=C.button(f,'−',nil);minus.Size=UDim2.fromOffset(44,44)
 local value=C.button(f,'1.00×',select);value.Position=UDim2.fromOffset(48,0);value.Size=UDim2.new(1,-96,1,0);value.BackgroundTransparency=.6
 local plus=C.button(f,'+',nil);plus.Position=UDim2.new(1,-44,0,0)
 for _,x in ipairs({{minus,-1},{plus,1}})do
  local generation=0;local repeated=false
  router:bind(x[1],{begin=function()generation+=1;local g=generation;repeated=false;task.delay(.4,function()if g~=generation or not router.owner then return end;repeated=true;local function repeatStep()if g~=generation or not router.owner then return end;step(x[2]);task.delay(.11,repeatStep)end;repeatStep()end)end,finish=function(_,drag)generation+=1;if not drag and not repeated then step(x[2])end end,cancel=function()generation+=1 end})
 end
 local unsub=state:subscribe(function(s)value.Text=string.format('%.2f×',s.speed or 1)end)
 return {frame=f,unsubscribe=unsub}
end
function C.modal(root,title,close)
 local overlay=C.new('Frame',root,{Name='Modal',BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.45,Size=UDim2.fromScale(1,1),Active=true,ZIndex=30})
 local box=C.surface(overlay,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(1,-32,1,-32),ZIndex=31})
 C.new('UISizeConstraint',box,{MaxSize=Vector2.new(470,540),MinSize=Vector2.new(0,0)})
 local label=C.label(box,title,18);label.Position=UDim2.fromOffset(16,10);label.Size=UDim2.new(1,-80,0,44)
 local x=C.button(box,'×',close);x.Position=UDim2.new(1,-56,0,10)
 local scale=C.new('UIScale',box,{Scale=.97});game:GetService('TweenService'):Create(scale,TweenInfo.new(.15),{Scale=1}):Play()
 local body=C.new('ScrollingFrame',box,{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(16,66),Size=UDim2.new(1,-32,1,-80),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3});C.list(body,10)
 return overlay,body
end
C.BottomSheet=C.modal;C.Modal=C.modal;C.Button=C.button;C.Slider=C.slider;C.SeekBar=C.seekbar;C.SpeedControl=C.speed;C.SegmentedControl=C.segmented;C.Toggle=C.toggle
return C
