local ProfileStore={}; ProfileStore.__index=ProfileStore
local HttpService=game:GetService("HttpService")
function ProfileStore.new(FS,builtin)
    local self=setmetatable({FS=FS,builtin=builtin,path="MIDIQWERTY/profiles.json",custom={}},ProfileStore)
    local raw=FS.loadJson(self.path,{})
    for id,p in pairs(raw) do
        local map={}; for k,v in pairs(p.map or {}) do map[tonumber(k) or k]=v end
        p.map=map; self.custom[id]=p
    end
    return self
end
function ProfileStore:get(id) return self.custom[id] or self.builtin.get(id) end
function ProfileStore:saveProfile(profile)
    assert(type(profile)=="table" and profile.id and profile.map,"Invalid profile")
    self.custom[profile.id]=profile
    local serial={}; for id,p in pairs(self.custom) do local m={}; for k,v in pairs(p.map) do m[tostring(k)]=v end; serial[id]={id=p.id,name=p.name,lowest=p.lowest,highest=p.highest,map=m} end
    self.FS.saveJson(self.path,serial); return true
end
function ProfileStore:setMapping(id,note,token)
    local base=self:get(id); if not base then return false end
    local p={id=id,name=base.name,lowest=base.lowest,highest=base.highest,map={}}; for k,v in pairs(base.map) do p.map[k]=v end
    p.map[note]=token; return self:saveProfile(p)
end
return ProfileStore
