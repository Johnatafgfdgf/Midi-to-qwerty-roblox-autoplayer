from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
paths=[p for p in (root/'src').rglob('*.lua') if not re.search(r'V\d',p.name) and p.name not in ['AppFixed.lua','AppMobile.lua']]
boot='''-- Generated from clean src modules. Build: python scripts/build.py
local env=(getgenv and getgenv())or _G
if env.MIDIQWERTY and env.MIDIQWERTY.destroy then env.MIDIQWERTY.destroy()end
local boot=Instance.new('ScreenGui');boot.Name='MIDIQWERTY_LOADING';boot.ResetOnSpawn=false;boot.DisplayOrder=22000
local parent=(gethui and gethui())or game:GetService('CoreGui');if not pcall(function()boot.Parent=parent end)then boot.Parent=game:GetService('Players').LocalPlayer:WaitForChild('PlayerGui')end
local label=Instance.new('TextLabel');label.Size=UDim2.fromOffset(290,52);label.Position=UDim2.fromOffset(16,70);label.BackgroundColor3=Color3.fromRGB(17,22,34);label.TextColor3=Color3.fromRGB(237,240,249);label.TextSize=14;label.Font=Enum.Font.Gotham;label.Text='Inicializando…';label.Parent=boot
local round=Instance.new('UICorner');round.CornerRadius=UDim.new(0,14);round.Parent=label
local modules={}
'''
for p in sorted(paths):
 key=p.relative_to(root/'src').as_posix()[:-4]
 boot+='modules['+repr(key)+']=function()\n'+p.read_text()+'\nend\n'
boot+='''local cache={};local loading={}
local function R(name)
 if cache[name] then return cache[name]end
 assert(not loading[name], 'Circular dependency: '..name);loading[name]=true
 if name:match('MIDI/')then label.Text='Carregando MIDI engine…'elseif name:match('Input/')then label.Text='Preparando input…'elseif name:match('UI/')then label.Text='Montando interface…'end
 local result=assert(modules[name],'Missing module '..name)();cache[name]=result;loading[name]=nil;return result
end
local ok,result=pcall(function()return R('Main').start({Require=R})end)
boot:Destroy()
if not ok then error('[MIDIQWERTY RC] '..tostring(result),0)end
return result
'''
(root/'dist').mkdir(exist_ok=True);(root/'dist/autoplayer.lua').write_text(boot)
print('Bundled',len(paths),'modules',len(boot),'characters')
