local Library={}; Library.__index=Library
function Library.new(FS)
    local self=setmetatable({FS=FS,path="MIDIQWERTY/library.json"},Library)
    self.data=FS.loadJson(self.path,{favorites={},recent={},history={},songOverrides={},playlists={}})
    return self
end
function Library:save() self.FS.saveJson(self.path,self.data) end
function Library:isFavorite(path) return self.data.favorites[path]==true end
function Library:toggleFavorite(path) self.data.favorites[path]=not self:isFavorite(path); self:save(); return self.data.favorites[path] end
function Library:touch(path)
    local r={path=path,time=os.time()}; local out={r}
    for _,x in ipairs(self.data.recent) do if x.path~=path and #out<30 then out[#out+1]=x end end
    self.data.recent=out; local h=self.data.history[path] or {plays=0,totalSeconds=0}; h.plays+=1; h.lastPlayed=os.time(); self.data.history[path]=h; self:save()
end
function Library:addPlayedSeconds(path,seconds) local h=self.data.history[path] or {plays=0,totalSeconds=0}; h.totalSeconds=(h.totalSeconds or 0)+math.max(0,seconds or 0); self.data.history[path]=h; self:save() end
function Library:getOverride(path) return self.data.songOverrides[path] or {} end
function Library:setOverride(path,key,value) self.data.songOverrides[path]=self.data.songOverrides[path] or {}; self.data.songOverrides[path][key]=value; self:save() end
return Library
