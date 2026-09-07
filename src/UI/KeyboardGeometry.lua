local K={}
function K.black(n)local p=n%12;return p==1 or p==3 or p==6 or p==8 or p==10 end
function K.build(low,high)
 -- Include bounding white keys when a range starts or ends on an accidental.
 if K.black(low)then low-=1 end;if K.black(high)then high+=1 end
 local whites=0;for n=low,high do if not K.black(n)then whites+=1 end end
 local keys={};local index=0
 for n=low,high do
  local b=K.black(n)
  if b then keys[n]={x=(index-.31)/whites,width=.62/whites,black=true,center=index/whites}
  else keys[n]={x=index/whites,width=1/whites,black=false,center=(index+.5)/whites};index+=1 end
 end
 return keys,low,high
end
return K
