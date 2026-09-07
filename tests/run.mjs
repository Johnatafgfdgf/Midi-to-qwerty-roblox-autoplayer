import fs from 'node:fs';
import path from 'node:path';
import {LuauState} from 'luau-web';
const runtime=await LuauState.createAsync({print:console.log,warn:console.warn,capture:(name,data)=>{fs.mkdirSync('.tmp/layouts',{recursive:true});fs.writeFileSync('.tmp/layouts/'+name+'.json',data)}});
const files=fs.readdirSync('src',{recursive:true}).filter(p=>p.endsWith('.lua'));
let count=0;
for(const file of [...files.map(p=>'src/'+p),...fs.readdirSync('tests',{recursive:true}).filter(p=>p.endsWith('.lua')).map(p=>'tests/'+p)]){
 runtime.loadstring(fs.readFileSync(file,'utf8'),file,true);count++;
}
console.log('COMPILE PASS',count);
let source='local modules={}\n';
for(const f of files)source+=`modules[${JSON.stringify(f.replace(/\.lua$/,''))}]=function()\n${fs.readFileSync('src/'+f,'utf8')}\nend\n`;
for(const f of fs.readdirSync('tests/baseline'))source+=`modules[${JSON.stringify('baseline/'+f.replace('.lua',''))}]=function()\n${fs.readFileSync('tests/baseline/'+f,'utf8')}\nend\n`;
source+='local cache={}\nlocal function R(name) if not cache[name] then cache[name]=assert(modules[name],name)() end return cache[name] end\n';
source=fs.readFileSync('tests/MockRuntime.lua','utf8')+'\n'+source+'\n'+fs.readFileSync(process.argv[2]||'tests/Regression.lua','utf8');
await runtime.loadstring(source,'regression',true)();runtime.destroy();
