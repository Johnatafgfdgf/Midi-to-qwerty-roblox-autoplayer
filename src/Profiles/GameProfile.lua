local G={};G.__index=G
function G.copy(v)if type(v)~='table' then return v end;local o={};for k,x in pairs(v)do o[k]=G.copy(x)end;return o end
function G.merge(a,b)
 for k,v in pairs(b or {})do
  if type(v)=='table' and type(a[k])=='table' and k~='enabledTracks' and k~='enabledChannels' and k~='handCorrections' then G.merge(a[k],v)else a[k]=G.copy(v)end
 end
 return a
end
function G.resolve(global,gameProfile,song)return G.merge(G.merge(G.copy(global),gameProfile),song)end
function G.new(FS,gameId,placeId)
 return setmetatable({FS=FS,path='MIDIQWERTY/game-profiles.json',key=tostring(gameId)..':'..tostring(placeId),data=FS.loadJson('MIDIQWERTY/game-profiles.json',{})},G)
end
function G:get()return self.data[self.key] or {}end
function G:save(settings)self.data[self.key]=G.copy(settings);return self.FS.saveJson(self.path,self.data)end
return G
