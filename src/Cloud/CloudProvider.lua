-- Transport injection separates verified service routes from cancellation/state logic.
local P={};P.__index=P
function P.new(transport,options)
 return setmetatable({transport=transport,options=options or {},generation=0,state='Idle',lastError=nil},P)
end
function P:cancel()self.generation+=1;self.state='Idle'end
function P:health()return self.transport and {available=true,state=self.state}or {available=false,state='Unsupported'}end
function P:_request(method,arg,callback)
 self:cancel();local generation=self.generation
 if not self.transport or not self.transport[method]then self.state='Unsupported';self.lastError='Provider sem contrato público validado';callback(nil,self.lastError);return end
 self.state='Loading';local done=false
 local function finish(result,err)
  if done or generation~=self.generation then return end;done=true
  self.lastError=err;self.state=err and 'Error' or (type(result)=='table' and #result==0 and 'Empty'or 'Results');callback(result,err)
 end
 task.delay(self.options.timeoutSeconds or 6,function()if not done and generation==self.generation then self.state='Offline';done=true;self.lastError='Timeout';callback(nil,'Timeout')end end)
 task.spawn(function()local ok,res,err=pcall(self.transport[method],self.transport,arg);if ok then finish(res,err)else finish(nil,tostring(res))end end)
end
function P:search(q,cb)self:_request('search',q,cb)end
function P:getSong(id,cb)self:_request('getSong',id,cb)end
function P:download(song,cb)self:_request('download',song,cb)end
function P:diagnostics()return {state=self.state,error=self.lastError,verified=self.transport~=nil}end
return P
