local FileSystem = {}

local function fn(name)
    local env = (getgenv and getgenv()) or _G
    local value = rawget(env, name) or rawget(_G, name)
    return type(value) == "function" and value or nil
end

function FileSystem.capabilities()
    return {
        readfile = fn("readfile") ~= nil,
        writefile = fn("writefile") ~= nil,
        listfiles = fn("listfiles") ~= nil,
        isfile = fn("isfile") ~= nil,
        isfolder = fn("isfolder") ~= nil,
        makefolder = fn("makefolder") ~= nil,
    }
end

function FileSystem.ensureFolder(path)
    local isfolder, makefolder = fn("isfolder"), fn("makefolder")
    if isfolder and isfolder(path) then return true end
    if not makefolder then return false end
    local ok = pcall(makefolder, path)
    return ok
end

function FileSystem.read(path)
    local readfile = fn("readfile")
    if not readfile then return nil, "readfile unavailable" end
    local ok, data = pcall(readfile, path)
    if not ok then return nil, tostring(data) end
    return data
end

function FileSystem.write(path, data)
    local writefile = fn("writefile")
    if not writefile then return false, "writefile unavailable" end
    local ok, err = pcall(writefile, path, data)
    return ok, ok and nil or tostring(err)
end

local function normalizedExtension(path)
    return string.lower(path:match("%.([^%./\\]+)$") or "")
end

function FileSystem.scanMidi(folders)
    local listfiles, isfolder = fn("listfiles"), fn("isfolder")
    if not listfiles then return {}, "listfiles unavailable" end
    local found, seen = {}, {}
    for _, folder in ipairs(folders or {}) do
        local exists = true
        if isfolder then
            local ok, result = pcall(isfolder, folder)
            exists = ok and result
        end
        if exists then
            local ok, files = pcall(listfiles, folder)
            if ok and type(files) == "table" then
                for _, path in ipairs(files) do
                    local ext = normalizedExtension(path)
                    if (ext == "mid" or ext == "midi") and not seen[path] then
                        seen[path] = true
                        found[#found + 1] = {
                            path = path,
                            name = path:match("([^/\\]+)$") or path,
                        }
                    end
                end
            end
        end
    end
    table.sort(found, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
    return found
end

function FileSystem.loadJson(path, fallback)
    local HttpService = game:GetService("HttpService")
    local data = FileSystem.read(path)
    if not data then return fallback end
    local ok, decoded = pcall(HttpService.JSONDecode, HttpService, data)
    return ok and decoded or fallback
end

function FileSystem.saveJson(path, value)
    local HttpService = game:GetService("HttpService")
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, value)
    if not ok then return false, tostring(encoded) end
    return FileSystem.write(path, encoded)
end

return FileSystem
