local function u16(n)return string.char(math.floor(n/256)%256,n%256)end
local function u32(n)return string.char(math.floor(n/16777216)%256,math.floor(n/65536)%256,math.floor(n/256)%256,n%256)end
local function vlq(v)local bytes={v%128};v=math.floor(v/128);while v>0 do table.insert(bytes,1,v%128+128);v=math.floor(v/128)end;return string.char(table.unpack(bytes))end
local tr={}
for i=0,47 do local note=48+(i%12)*2;tr[#tr+1]=string.char(0,0x90,note,88)..vlq(180)..string.char(0x80,note,0)..vlq(60)..string.char(0xFF,0x01,0)end
tr[#tr+1]=string.char(0,0xFF,0x2F,0);tr=table.concat(tr)
local midi='MThd'..u32(6)..u16(0)..u16(1)..u16(480)..'MTrk'..u32(#tr)..tr
local saved={};env.readfile=function(path)if path:match('%.mid$')then return midi end;if saved[path]then return saved[path]end;error('not found')end;env.writefile=function(p,d)saved[p]=d end;env.isfile=function()return true end;env.isfolder=function(p)return p=='MIDI'or p=='MIDIQWERTY'end;env.makefolder=function()end;env.listfiles=function()return {'MIDI/Estudo de frases.mid'}end
local public=R('Main').start({Require=R});local app=public.app
check('Main boots real App module and loads fixture',function()assert(app.mode=='Full'and app.tab=='Library');assert(public.callbacks.selectSong({name='Estudo de frases.mid',path='MIDI/Estudo de frases.mid'},false));assert(public.state().duration>10)end)
check('UI action harness',function()local results=public.runUITest();for _,r in ipairs(results)do assert(r.status=='PASS',r.name..':'..tostring(r.error))end end)
check('Modal actions instantiate without runtime errors',function()for _,method in ipairs({'speedPicker','humanPicker','playerTools','tracks','advanced','conversion','calibrate','diagnostics','changelog'})do app[method](app);assert(app.modal);app:closeModal();assert(not app.modal)end end)
check('seek preview waits for release',function()
 app:setMode('Mini');local f
 for _,o in ipairs(app.windows.Mini:GetDescendants())do if o.ClassName=='Frame' and o.Active and o.AbsoluteSize.Y==44 then f=o end end
 assert(f,'seek surface missing');local before=public.state().position
 local i={UserInputType=Enum.UserInputType.Touch,Position=Vector3.new(f.AbsolutePosition.X+f.AbsoluteSize.X*.8,f.AbsolutePosition.Y+20,0)}
 f.InputBegan:Fire(i);assert(public.state().position==before);userInput.InputEnded:Fire(i);assert(public.state().position>public.state().duration*.7)
end)
check('bubble threshold tap drag and viewport clamp',function()
 app:setMode('Hidden');local b=app.windows.Hidden;local i={UserInputType=Enum.UserInputType.Touch,Position=Vector3.new(20,20,0)};b.InputBegan:Fire(i);i.Position=Vector3.new(23,21,0);userInput.InputChanged:Fire(i);userInput.InputEnded:Fire(i);assert(app.mode~='Hidden')
 app:setMode('Hidden');b.InputBegan:Fire(i);i.Position=Vector3.new(9000,9000,0);userInput.InputChanged:Fire(i);userInput.InputEnded:Fire(i);assert(app.mode=='Hidden');assert(b.Position.X.Offset+b.AbsoluteSize.X<=viewport.X and b.Position.Y.Offset+b.AbsoluteSize.Y<=viewport.Y)
end)
check('one gesture owns router; second touch ignored',function()
 local b=app.windows.Hidden;local a={UserInputType='Touch',Position=Vector3.new(0,0,0)};local second={UserInputType='Touch',Position=Vector3.new(1,1,0)};b.InputBegan:Fire(a);local owner=app.router.owner;b.InputBegan:Fire(second);assert(app.router.owner==owner);userInput.InputEnded:Fire(second);assert(app.router.owner==owner);userInput.InputEnded:Fire(a);assert(app.router.owner==nil)
end)
public.callbacks.hands('Both');public.callbacks.preset('Pianist');public.callbacks.seek(2)
for _,v in ipairs({{1280,720},{1920,864},{2400,1080},{390,844},{844,390}})do
 viewport.X,viewport.Y=v[1],v[2];app:resize()
 for _,mode in ipairs({'Full','Compact','Mini','Hidden'})do
  app:setMode(mode);app:showTab('Player');render:Fire()
  check('Layout '..v[1]..'x'..v[2]..' '..mode,function()
   local w=app.windows[mode];local p,s=w.AbsolutePosition,w.AbsoluteSize;assert(p.X>=0 and p.Y>=0 and p.X+s.X<=v[1]and p.Y+s.Y<=v[2])
   for _,o in ipairs(w:GetDescendants())do if o.ClassName=='TextButton'or o.ClassName=='TextBox'then assert(o.AbsoluteSize.X>=43.9 and o.AbsoluteSize.Y>=43.9,o.Name..' target '..o.AbsoluteSize.X..'x'..o.AbsoluteSize.Y)end end
  end)
  snapshot(app,tostring(v[1])..'x'..tostring(v[2])..'-'..mode)
 end
end
public.destroy();check('destroy tears down state and heartbeat',function()assert(next(public.store.listeners)==nil);assert(app.destroyed)end)
