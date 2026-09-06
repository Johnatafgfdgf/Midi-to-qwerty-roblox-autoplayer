local Dodo={};Dodo.__index=Dodo
local HttpService=game:GetService("HttpService")

local BASES={
    "https://api2.dodomusicstudio.com/v1/",
    "https://api.dundunstudio.com/v1/",
    "https://api2.dodomusicstudio.com/",
    "https://api.dundunstudio.com/",
}

local function safeName(s)
    s=tostring(s or "cloud_song"):gsub("[\\/:*?\"<>|]","_"):gsub("%s+"," ")
    if #s>90 then s=s:sub(1,90) end
    return s
end
local function envFn(name)
    local env=(getgenv and getgenv()) or _G;local v=rawget(env,name) or rawget(_G,name)
    return type(v)=="function" and v or nil
end
local function decode(raw)
    if type(raw)~="string" then return nil end
    local ok,v=pcall(HttpService.JSONDecode,HttpService,raw);return ok and v or nil
end

local function httpGet(url,timeout,acceptBinary)
    timeout=math.clamp(tonumber(timeout) or 5,1.5,10)
    local request=envFn("request") or envFn("http_request") or (syn and syn.request)
    local signal=Instance.new("BindableEvent");local finished=false;local result=nil
    local function finish(v)if finished then return end;finished=true;result=v;signal:Fire()end
    task.spawn(function()
        if request then
            local ok,res=pcall(request,{Url=url,Method="GET",Timeout=timeout,Headers={
                ["Accept"]=acceptBinary and "application/octet-stream, application/json;q=0.9, */*;q=0.5" or "application/json, */*;q=0.5",
                ["Accept-Language"]="en-US,en;q=0.8",
                ["User-Agent"]="DodoMusic/2.3.0 (Android) MIDIQWERTY-bridge",
            }})
            if ok and type(res)=="table" then
                local code=tonumber(res.StatusCode or res.Status or 0) or 0
                finish({ok=code>=200 and code<300,code=code,body=res.Body or "",headers=res.Headers})
            else finish({ok=false,code=0,error=tostring(res)}) end
        else
            local ok,body=pcall(function()return game:HttpGet(url)end)
            finish({ok=ok,code=ok and 200 or 0,body=ok and body or "",error=ok and nil or tostring(body)})
        end
    end)
    task.delay(timeout,function()finish({ok=false,code=0,error="timeout"})end)
    if not finished then signal.Event:Wait()end
    signal:Destroy();return result
end

local function songLike(t)
    return type(t)=="table" and (t.songname~=nil or t.songName~=nil or t.fileId~=nil or t.remoteUrl~=nil or t.sidkey~=nil or t.title~=nil)
end
local function normalize(t)
    if type(t)~="table" then return nil end
    local name=t.songname or t.songName or t.title or t.name;if not name then return nil end
    return {
        id=tostring(t.sidkey or t.song_id or t.songId or t.id or t.fileId or name),name=tostring(name),
        singer=t.singer or t.artist or "",downloads=tonumber(t.real_downloads or t.downloads or 0) or 0,
        duration=t.songlength or t.duration,range=t.songrange or t.range,notes=t.notesnum or t.noteCount,
        category=t.category,tags=t.tags,fileId=t.fileId or t.file_id,
        remoteUrl=t.remoteUrl or t.remote_url or t.downloadUrl or t.download_url or t.url,
        source="Dodo",raw=t,
    }
end
local function collect(node,out,seen,depth)
    if depth>8 or type(node)~="table" then return end
    if songLike(node) then local s=normalize(node);if s and not seen[s.id] then seen[s.id]=true;out[#out+1]=s end end
    for _,v in pairs(node)do if type(v)=="table" then collect(v,out,seen,depth+1)end end
end
local function findUrl(node,depth)
    if depth>7 or type(node)~="table" then return nil end
    for _,k in ipairs({"download_url","downloadUrl","remoteUrl","remote_url","fileUrl","file_url","url"})do if type(node[k])=="string" and node[k]:match("^https?://") then return node[k]end end
    for _,v in pairs(node)do if type(v)=="table" then local u=findUrl(v,depth+1);if u then return u end end end
end

function Dodo.new(FS,config)
    return setmetatable({FS=FS,config=config or {},working=nil,lastError=nil,lastProbe={},searchGeneration=0},Dodo)
end
function Dodo:_candidates(query)
    local q=HttpService:UrlEncode(query or "");local urls={}
    local function add(base,path,kind)urls[#urls+1]={base=base,path=path,kind=kind,url=base..path}end
    -- Order by the strings actually present in APK 2.3.0: /music/, a paged list,
    -- search_v2 and song_file/{fileId}. Root and /v1 variants are both tried.
    for _,base in ipairs(BASES)do
        add(base,"music/?pageOffset=0&query="..q,"music-query")
        add(base,"search_v2?query="..q.."&pageOffset=0","search-v2-query")
        add(base,"music/?pageOffset=0&keyword="..q,"music-keyword")
    end
    if self.working then
        table.sort(urls,function(a,b)
            local aa=(a.base==self.working.base and a.kind==self.working.kind) and 0 or 1
            local bb=(b.base==self.working.base and b.kind==self.working.kind) and 0 or 1
            return aa<bb
        end)
    end
    return urls
end
function Dodo:search(query)
    self.searchGeneration+=1;local gen=self.searchGeneration;local probe={}
    local perRequest=math.clamp(tonumber(self.config.timeoutSeconds) or 4,2,6)
    local deadline=os.clock()+14
    local candidates=self:_candidates(query)
    for idx,c in ipairs(candidates)do
        if gen~=self.searchGeneration then return nil,"Busca cancelada" end
        local remaining=deadline-os.clock();if remaining<=.25 then break end
        local r=httpGet(c.url,math.min(perRequest,remaining),false)
        probe[#probe+1]={route=c.kind,base=c.base,code=r and r.code or 0,error=r and r.error or nil}
        if r and r.ok and type(r.body)=="string" then
            local json=decode(r.body)
            if json then
                local songs,seen={},{};collect(json,songs,seen,0)
                if #songs>0 then
                    table.sort(songs,function(a,b)if a.downloads==b.downloads then return string.lower(a.name)<string.lower(b.name)end;return a.downloads>b.downloads end)
                    self.working={base=c.base,kind=c.kind};self.lastProbe=probe;self.lastError=nil;return songs
                end
            end
        end
        if idx>=8 and not self.working then break end
    end
    self.lastProbe=probe
    local timeoutCount,httpCodes=0,{}
    for _,p in ipairs(probe)do if p.error=="timeout" then timeoutCount+=1 end;if p.code and p.code>0 then httpCodes[tostring(p.code)]=true end end
    local codes={};for k in pairs(httpCodes)do codes[#codes+1]=k end;table.sort(codes)
    local detail=(#codes>0 and ("HTTP "..table.concat(codes,",")) or (timeoutCount>0 and "timeout/rede bloqueada" or "sem resposta JSON compatível"))
    self.lastError="Dodo Cloud indisponível: "..detail
    return nil,self.lastError..". A API pública do APK 2.3.0 não respondeu de forma compatível. Os MIDIs locais continuam funcionando."
end
function Dodo:download(song)
    if type(song)~="table" then return nil,"Música inválida" end
    local raw;local timeout=math.clamp(tonumber(self.config.timeoutSeconds) or 5,2,8)
    if type(song.remoteUrl)=="string" and song.remoteUrl:match("^https?://") then local r=httpGet(song.remoteUrl,timeout,true);if r and r.ok then raw=r.body end end
    if (not raw or raw:sub(1,4)~="MThd") and song.fileId then
        local bases={};if self.working then bases[1]=self.working.base end;for _,b in ipairs(BASES)do bases[#bases+1]=b end;local seen={}
        for _,base in ipairs(bases)do
            if not seen[base] then
                seen[base]=true
                for _,path in ipairs({"song_file/"..HttpService:UrlEncode(tostring(song.fileId)),"music/song_file/"..HttpService:UrlEncode(tostring(song.fileId))})do
                    local r=httpGet(base..path,timeout,true)
                    if r and r.ok and type(r.body)=="string" then
                        if r.body:sub(1,4)=="MThd" then raw=r.body;break end
                        local j=decode(r.body);local u=j and findUrl(j,0);if u then local rr=httpGet(u,timeout,true);if rr and rr.ok then raw=rr.body end end
                    end
                    if raw and raw:sub(1,4)=="MThd" then break end
                end
            end
            if raw and raw:sub(1,4)=="MThd" then break end
        end
    end
    if not raw or raw:sub(1,4)~="MThd" then return nil,"O Dodo não forneceu um MIDI público válido para esta música." end
    local folder=self.config.downloadFolder or "Delta/Workspace/MIDI/Cloud";self.FS.ensureFolder("Delta");self.FS.ensureFolder("Delta/Workspace");self.FS.ensureFolder("Delta/Workspace/MIDI");self.FS.ensureFolder(folder)
    local path=folder.."/"..safeName(song.name)..".mid";local ok,err=self.FS.write(path,raw);if not ok then return nil,err end;return path
end
function Dodo:cancelSearch()self.searchGeneration+=1 end
function Dodo:diagnostics()return{provider="Dodo",working=self.working,lastError=self.lastError,lastProbe=self.lastProbe}end
return Dodo
