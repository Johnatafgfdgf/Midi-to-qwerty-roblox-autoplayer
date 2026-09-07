local Roll={};Roll.__index=Roll
function Roll.new(parent,C,Geometry)
 local self=setmetatable({C=C,geometry=Geometry,notes={},pool={},keys={},lookAhead=2.6},Roll)
 self.frame=C.surface(parent,{Name='PianoRoll',Size=UDim2.new(1,0,0,120),BackgroundColor3=Color3.fromRGB(8,12,21),ClipsDescendants=true})
 self.lanes=C.new('Frame',self.frame,{BackgroundTransparency=1,Size=UDim2.new(1,0,1,-30),ClipsDescendants=true})
 self.keyboard=C.new('Frame',self.frame,{BackgroundTransparency=1,Position=UDim2.new(0,0,1,-30),Size=UDim2.new(1,0,0,30)})
 local line=C.new('Frame',self.frame,{Position=UDim2.new(0,0,1,-31),Size=UDim2.new(1,0,0,1),BackgroundColor3=C.colors.accent,BorderSizePixel=0});line.ZIndex=5
 self.empty=C.label(self.lanes,'Selecione uma música para acompanhar as notas',12);self.empty.Size=UDim2.fromScale(1,1);self.empty.TextXAlignment=Enum.TextXAlignment.Center;self.empty.TextColor3=C.colors.muted
 return self
end
function Roll:setTimeline(timeline,profile)
 self.notes=timeline and timeline.notes or {};self.empty.Visible=#self.notes==0
 for _,k in pairs(self.keys)do k:Destroy()end;self.keys={}
 self.positions=self.geometry.build(profile.lowest,profile.highest)
 for n,p in pairs(self.positions)do
  local key=self.C.new('Frame',self.keyboard,{Name=tostring(n),BorderSizePixel=0,Position=UDim2.fromScale(p.x,0),Size=UDim2.new(p.width,-1,p.black and .62 or 1,0),BackgroundColor3=p.black and Color3.fromRGB(13,17,26) or Color3.fromRGB(191,201,217),ZIndex=p.black and 4 or 3})
  self.keys[n]=key
 end
 self.maxHold=0;for _,n in ipairs(self.notes)do self.maxHold=math.max(self.maxHold,(n.executionEnd or n.endTime)-n.startTime)end
end
function Roll:update(pos)
 if not self.frame.Visible then return end
 local height=self.lanes.AbsoluteSize.Y
 for n,key in pairs(self.keys)do key.BackgroundColor3=self.positions[n].black and Color3.fromRGB(13,17,26) or Color3.fromRGB(191,201,217)end
 local lo,hi=1,#self.notes+1
 while lo<hi do local mid=math.floor((lo+hi)/2);if mid<=#self.notes and self.notes[mid].startTime<pos-self.maxHold then lo=mid+1 else hi=mid end end
 local used=0
 for i=lo,#self.notes do
  local n=self.notes[i];if n.startTime>pos+self.lookAhead then break end
  local ending=n.executionEnd or n.keyReleaseTime or n.endTime
  local p=self.positions[n.mappedNote or n.note]
  if p and ending>=pos then
   used+=1;local block=self.pool[used]
   if not block then block=self.C.new('Frame',self.lanes,{BorderSizePixel=0});self.C.round(block,3);self.pool[used]=block end
   local color=n.parts and n.parts.hand=='Left' and self.C.colors.left or self.C.colors.right
   local y1=height-(ending-pos)/self.lookAhead*height;local y2=height-(n.startTime-pos)/self.lookAhead*height
   block.Position=UDim2.new(p.x,1,0,math.max(0,y1));block.Size=UDim2.new(p.width,-2,0,math.max(2,math.min(height,y2)-math.max(0,y1)));block.BackgroundColor3=color;block.Visible=true
   block.BackgroundTransparency=n.startTime<=pos and .02 or .18
   if n.startTime<=pos and self.keys[n.mappedNote or n.note]then self.keys[n.mappedNote or n.note].BackgroundColor3=color end
  end
 end
 for i=used+1,#self.pool do self.pool[i].Visible=false end
end
return Roll
