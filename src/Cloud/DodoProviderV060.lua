local Dodo = {}
Dodo.__index = Dodo

local HttpService = game:GetService("HttpService")

local BASES = {
    "https://api2.dodomusicstudio.com/v1/",
    "https://api.dundunstudio.com/v1/",
}

local function safeName(s)
    s = tostring(s or "cloud_song")
    s = s:gsub("[\\/:*?\"<>|]", "_")
    s = s:gsub("%s+", " ")
    if #s > 90 then s = s:sub(1,90) end
    return s
end

local function getEnvFn(name)
    local env = (getgenv and getgenv()) or _G
    local v = rawget(env,name) or rawget(_G,name)
    return type(v) == "function" and v or nil
end

local function httpGet(url)
    local request = getEnvFn("request") or getEnvFn("http_request") or (syn and syn.request)
    if request then
        local ok,res = pcall(request,{Url=url,Method="GET",Headers={Accept="application/json, application/octet-stream;q=0.9, */*;q=0.5"}})
        if ok and type(res)=="table" then
            local code = tonumber(res.StatusCode or res.Status or 0) or 0
            if code >= 200 and code < 300 then return res.Body end
            return nil,"HTTP "..tostring(code)
        end
    end
    local ok,res = pcall(function() return game:HttpGet(url) end)
    if ok then return res end
    return nil,tostring(res)
end

local function decodeJson(raw)
    if type(raw) ~= "string" then return nil end
    local ok,v = pcall(HttpService.JSONDecode,HttpService,raw)
    return ok and v or nil
end

local function songLike(t)
    if type(t) ~= "table" then return false end
    return t.songname ~= nil or t.songName ~= nil or t.fileId ~= nil or t.remoteUrl ~= nil or t.sidkey ~= nil or t.title ~= nil
end

local function normalize(t)
    if type(t) ~= "table" then return nil end
    local name = t.songname or t.songName or t.title or t.name
    if not name then return nil end
    return {
        id = tostring(t.sidkey or t.song_id or t.songId or t.id or t.fileId or name),
        name = tostring(name),
        singer = t.singer or t.artist or "",
        downloads = tonumber(t.real_downloads or t.downloads or 0) or 0,
        duration = t.songlength or t.duration,
        range = t.songrange or t.range,
        notes = t.notesnum or t.noteCount,
        category = t.category,
        tags = t.tags,
        fileId = t.fileId or t.file_id,
        remoteUrl = t.remoteUrl or t.remote_url or t.downloadUrl or t.download_url or t.url,
        raw = t,
        source = "Dodo",
    }
end

local function collectSongs(node,out,seen,depth)
    if depth > 7 or type(node) ~= "table" then return end
    if songLike(node) then
        local s = normalize(node)
        if s and not seen[s.id] then seen[s.id]=true;out[#out+1]=s end
    end
    for _,v in pairs(node) do
        if type(v)=="table" then collectSongs(v,out,seen,depth+1) end
    end
end

function Dodo.new(FS,config)
    return setmetatable({FS=FS,config=config or {},workingBase=nil,workingSearch=nil,lastError=nil},Dodo)
end

function Dodo:_candidateUrls(query)
    local q = HttpService:UrlEncode(query or "")
    local urls = {}
    for _,base in ipairs(BASES) do
        -- These names were recovered from the app itself. The provider probes only
        -- public unauthenticated GET routes and stops on the first valid song payload.
        urls[#urls+1] = {base=base,kind="search_v2",url=base.."search_v2?query="..q}
        urls[#urls+1] = {base=base,kind="music_search",url=base.."music/search_v2?query="..q}
        urls[#urls+1] = {base=base,kind="music",url=base.."music?search="..q}
        urls[#urls+1] = {base=base,kind="music",url=base.."music/?search="..q}
    end
    return urls
end

function Dodo:search(query)
    local candidates = self:_candidateUrls(query)
    if self.workingSearch then
        table.sort(candidates,function(a,b) return a.kind==self.workingSearch end)
    end
    local errors = {}
    for _,c in ipairs(candidates) do
        local raw,err = httpGet(c.url)
        if raw then
            local json = decodeJson(raw)
            if json then
                local songs,seen = {},{}
                collectSongs(json,songs,seen,0)
                if #songs > 0 then
                    self.workingBase,self.workingSearch=c.base,c.kind
                    table.sort(songs,function(a,b)
                        if a.downloads==b.downloads then return string.lower(a.name)<string.lower(b.name) end
                        return a.downloads>b.downloads
                    end)
                    return songs
                end
            end
        end
        errors[#errors+1] = c.kind..": "..tostring(err or "resposta sem músicas")
    end
    self.lastError = table.concat(errors," | ")
    return nil,"A biblioteca do Dodo não respondeu por uma rota pública compatível. O provider fica isolado para não afetar os MIDIs locais."
end

local function findUrl(node,depth)
    if depth>6 or type(node)~="table" then return nil end
    for _,k in ipairs({"download_url","downloadUrl","remoteUrl","remote_url","fileUrl","file_url","url"}) do
        if type(node[k])=="string" and node[k]:match("^https?://") then return node[k] end
    end
    for _,v in pairs(node) do
        if type(v)=="table" then local u=findUrl(v,depth+1);if u then return u end end
    end
end

function Dodo:download(song)
    if type(song)~="table" then return nil,"Música inválida" end
    local raw
    if type(song.remoteUrl)=="string" and song.remoteUrl:match("^https?://") then
        raw = select(1,httpGet(song.remoteUrl))
    elseif song.fileId then
        local bases = self.workingBase and {self.workingBase} or BASES
        for _,base in ipairs(bases) do
            local body = select(1,httpGet(base.."song_file/"..HttpService:UrlEncode(tostring(song.fileId))))
            if body then
                if body:sub(1,4)=="MThd" then raw=body;break end
                local json=decodeJson(body);local u=json and findUrl(json,0)
                if u then raw=select(1,httpGet(u));if raw then break end end
            end
        end
    end
    if not raw or raw:sub(1,4)~="MThd" then return nil,"O Dodo não forneceu um arquivo MIDI público válido para esta música." end

    local folder = self.config.downloadFolder or "Delta/Workspace/MIDI/Cloud"
    self.FS.ensureFolder("Delta")
    self.FS.ensureFolder("Delta/Workspace")
    self.FS.ensureFolder("Delta/Workspace/MIDI")
    self.FS.ensureFolder(folder)
    local path = folder.."/"..safeName(song.name)..".mid"
    local ok,err = self.FS.write(path,raw)
    if not ok then return nil,err end
    return path
end

function Dodo:diagnostics()
    return {provider="Dodo",base=self.workingBase,searchRoute=self.workingSearch,lastError=self.lastError}
end

return Dodo
