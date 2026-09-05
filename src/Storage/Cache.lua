local Cache={}
local HttpService=game:GetService("HttpService")

local function checksum(data)
    local h=2166136261
    for i=1,#data do h=bit32.bxor(h,string.byte(data,i)); h=(h*16777619)%4294967296 end
    return string.format("%08x_%d",h,#data)
end
function Cache.key(data) return checksum(data) end
function Cache.path(key) return "MIDIQWERTY/cache/"..key..".json" end
function Cache.load(FS,key)
    local raw=FS.read(Cache.path(key)); if not raw then return nil end
    local ok,v=pcall(HttpService.JSONDecode,HttpService,raw); if not ok or type(v)~="table" or v.cacheVersion~=1 then return nil end
    return v.analysis
end
function Cache.save(FS,key,analysis)
    FS.ensureFolder("MIDIQWERTY/cache")
    local payload={cacheVersion=1,analysis=analysis}
    local ok,raw=pcall(HttpService.JSONEncode,HttpService,payload); if not ok then return false end
    return FS.write(Cache.path(key),raw)
end
return Cache
