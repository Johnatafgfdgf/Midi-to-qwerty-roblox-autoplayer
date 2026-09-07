local H={}
function H.run(app,state,cb)
 local results={}
 local function test(name,fn)local ok,err=pcall(fn);results[#results+1]={name=name,status=ok and 'PASS'or 'FAIL',error=not ok and tostring(err)or nil};print(name,ok and 'PASS'or tostring(err))end
 for _,name in ipairs({'Library','Player','Performance','Settings','Compact','Mini','Hidden','Restore'})do test(name,function()app.actions[name]();assert(app.windows[app.mode].Visible)end)end
 test('Speed +/− shared',function()local before=state.value.speed;cb.setSpeed(1);app.actions.SpeedPlus();assert(state.value.speed==1.05);app.actions.SpeedMinus();assert(state.value.speed==1);cb.setSpeed(before)end)
 for _,name in ipairs({'LH','RH','Both'})do test(name,function()app.actions[name]();assert(state.value.hands==({LH='Left',RH='Right',Both='Both'})[name])end)end
 for _,name in ipairs({'Exact','Subtle','Natural','Pianist','Expressive','Custom'})do test('Preset '..name,function()cb.preset(name);assert(state.value.humanPreset==name)end)end
 if state.value.song then
  test('Play/Pause',function()if state.value.playing then cb.playPause()end;cb.playPause();assert(state.value.playing);cb.playPause();assert(not state.value.playing)end)
  test('Seek',function()cb.seek(state.value.duration*.5);assert(math.abs(state.value.position-state.value.duration*.5)<.05)end)
 else results[#results+1]={name='Play/Pause/Seek',status='SKIP',error='Selecione um MIDI primeiro.'}end
 app:setMode('Compact');return results
end
return H
