local L={}
function L.bounds(vw,vh,mode)
 local aw,ah=math.max(1,vw-24),math.max(1,vh-24)
 local w,h
 if mode=='Full' then w=math.min(680,aw);h=math.min(540,ah)
 elseif mode=='Compact' then w=math.min(480,aw);h=math.min(330,ah)
 elseif mode=='Mini' then w=math.min(420,aw);h=156
 else w,h=56,56 end
 return w,math.min(h,ah)
end
function L.clamp(x,y,w,h,vw,vh)return math.clamp(x,0,math.max(0,vw-w)),math.clamp(y,0,math.max(0,vh-h))end
function L.position(vw,vh,w,h,saved)
 return L.clamp(saved and saved.x*(vw-w) or 12,saved and saved.y*(vh-h) or 12,w,h,vw,vh)
end
function L.normalized(x,y,w,h,vw,vh)return {x=x/math.max(1,vw-w),y=y/math.max(1,vh-h)}end
return L
