local FileSystem = {}

local function fn(name)
    local env = (getgenv and getgenv()) or _G
    local value = rawget(env, name) or rawget(_G, name)
    return type(value) == "function" and value or nil
end

local function normalize(path)
    path = tostring(path or ""):gsub("\\", "/"):gsub("/+", "/")
    return path:gsub("/$", "")
end

function FileSystem.capabilities()
    return {
        readfile = fn("readfile") ~= nil,
        writefile = fn("writefile") ~= nil,
        listfiles = fn("listfiles") ~= nil,
        isfile = fn("isfile") ~= nil,
        isfolder = fn("isfolder") ~= nil,
        makefolder = fn("makefolder") ~= nil,
        delfile = fn("delfile") ~= nil,
    }
end

function FileSystem.ensureFolder(path)
    path = normalize(path)
    local isfolder, makefolder = fn("isfolder"), fn("makefolder")
    if path == "" then return true end
    if isfolder then
        local ok, yes = pcall(isfolder, path)
        if ok and yes then return true end
    end
    if not makefolder then return false, "makefolder unavailable" end

    local prefix = path:sub(1, 1) == "/" and "/" or ""
    local current = prefix
    for part in path:gmatch("[^/]+") do
        current = current == "" or current == "/" and (current .. part) or (current .. "/" .. part)
        local exists = false
        if isfolder then
            local ok, yes = pcall(isfolder, current)
            exists = ok and yes
        end
        if not exists then
            local ok, err = pcall(makefolder, current)
            if not ok and isfolder then
                local ok2, yes2 = pcall(isfolder, current)
                if not (ok2 and yes2) then return false, tostring(err) end
            elseif not ok then
                return false, tostring(err)
            end
        end
    end
    return true
end

function FileSystem.read(path, maxBytes)
    local readfile = fn("readfile")
    if not readfile then return nil, "readfile unavailable" end
    local ok, data = pcall(readfile, path)
    if not ok then return nil, tostring(data) end
    if type(data) ~= "string" then return nil, "readfile returned non-string data" end
    if maxBytes and #data > maxBytes then
        return nil, string.format("file too large: %.1f MB (limit %.1f MB)", #data / 1048576, maxBytes / 1048576)
    end
    return data
end

function FileSystem.write(path, data)
    local writefile = fn("writefile")
    if not writefile then return false, "writefile unavailable" end
    local folder = normalize(tostring(path):match("^(.*)/[^/]+$") or "")
    if folder ~= "" then FileSystem.ensureFolder(folder) end
    local ok, err = pcall(writefile, path, data)
    return ok, ok and nil or tostring(err)
end

local function normalizedExtension(path)
    return string.lower(path:match("%.([^%./\\]+)$") or "")
end

function FileSystem.scanMidi(folders, options)
    options = options or {}
    local listfiles, isfolder = fn("listfiles"), fn("isfolder")
    if not listfiles then return {}, {error = "listfiles unavailable"} end

    local recursive = options.recursiveScan ~= false
    local maxDepth = math.clamp(tonumber(options.maxScanDepth) or 3, 0, 8)
    local maxFiles = math.clamp(tonumber(options.maxFiles) or 600, 1, 5000)
    local found, seen, visited = {}, {}, {}
    local scannedFolders, stopped = 0, false

    local function walk(folder, depth)
        if stopped then return end
        folder = normalize(folder)
        if visited[folder] then return end
        visited[folder] = true

        if isfolder then
            local ok, yes = pcall(isfolder, folder)
            if not (ok and yes) then return end
        end

        local ok, entries = pcall(listfiles, folder)
        if not ok or type(entries) ~= "table" then return end
        scannedFolders += 1

        for _, rawPath in ipairs(entries) do
            if stopped then break end
            local path = normalize(rawPath)
            local folderEntry = false
            if isfolder then
                local okFolder, yes = pcall(isfolder, path)
                folderEntry = okFolder and yes
            end

            if folderEntry then
                if recursive and depth < maxDepth then walk(path, depth + 1) end
            else
                local ext = normalizedExtension(path)
                local key = string.lower(path)
                if (ext == "mid" or ext == "midi") and not seen[key] then
                    seen[key] = true
                    found[#found + 1] = {
                        path = path,
                        name = path:match("([^/\\]+)$") or path,
                    }
                    if #found >= maxFiles then stopped = true end
                end
            end
        end
    end

    for _, folder in ipairs(folders or {}) do
        walk(folder, 0)
        if stopped then break end
    end

    table.sort(found, function(a, b)
        local an, bn = string.lower(a.name), string.lower(b.name)
        if an == bn then return string.lower(a.path) < string.lower(b.path) end
        return an < bn
    end)

    return found, {
        scannedFolders = scannedFolders,
        midiFiles = #found,
        truncated = stopped,
    }
end

function FileSystem.loadJson(path, fallback)
    local HttpService = game:GetService("HttpService")
    local function decode(candidate)
        local data = FileSystem.read(candidate)
        if not data then return nil end
        local ok, decoded = pcall(HttpService.JSONDecode, HttpService, data)
        if ok and type(decoded) == "table" then return decoded end
        return nil
    end
    return decode(path) or decode(path .. ".bak") or fallback
end

function FileSystem.saveJson(path, value, options)
    options = options or {}
    local HttpService = game:GetService("HttpService")
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, value)
    if not ok then return false, tostring(encoded) end

    if options.backup ~= false then
        local existing = FileSystem.read(path)
        if existing then FileSystem.write(path .. ".bak", existing) end
    end
    return FileSystem.write(path, encoded)
end

return FileSystem
