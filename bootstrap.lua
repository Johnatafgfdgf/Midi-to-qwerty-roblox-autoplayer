return function(meta)
    local env=(getgenv and getgenv()) or _G
    if env.MIDIQWERTY and type(env.MIDIQWERTY.destroy)=="function" then
        pcall(env.MIDIQWERTY.destroy)
        env.MIDIQWERTY=nil
    end

    meta.version=tostring(meta.version or "dev")
    local base=string.format("https://raw.githubusercontent.com/%s/%s/%s/src/",meta.owner,meta.repo,meta.branch)
    local cache,loading={},{}

    local function Require(path)
        if cache[path]~=nil then return cache[path] end
        assert(not loading[path],"[MIDIQWERTY] Circular module dependency: "..path)
        loading[path]=true
        local remotePath=path
        if path=="UI/App" then remotePath="UI/AppMobile" end
        local url=base..remotePath..".lua?v="..meta.version
        local ok,source=pcall(function()return game:HttpGet(url)end)
        if not ok or type(source)~="string" then loading[path]=nil;error("[MIDIQWERTY] Failed to download module "..path..": "..tostring(source),2)end
        local chunk,err=loadstring(source,"=MIDIQWERTY/"..path)
        if not chunk then loading[path]=nil;error("[MIDIQWERTY] Compile error in "..path..": "..tostring(err),2)end
        local success,result=pcall(chunk);loading[path]=nil
        if not success then error("[MIDIQWERTY] Runtime error in "..path..": "..tostring(result),2)end
        if result==nil then result=true end
        cache[path]=result
        return result
    end

    local Main=Require("Main")
    return Main.start({Require=Require,meta=meta})
end
