local NoteManager = {}
NoteManager.__index = NoteManager

function NoteManager.new(adapter)
    return setmetatable({
        adapter = adapter,
        refs = {},
        tokens = {},
        activeCount = 0,
        failures = 0,
        lastError = nil,
    }, NoteManager)
end

function NoteManager:_result(ok, err)
    if ok == false then
        self.failures += 1
        self.lastError = tostring(err or "input failure")
    end
    return ok, err
end

function NoteManager:strike(token, opts)
    return self:_result(self.adapter:strike(token, opts))
end

function NoteManager:tap(token)
    return self:_result(self.adapter:tap(token))
end

function NoteManager:down(token)
    local id = self.adapter:physicalId(token)
    local count = self.refs[id] or 0

    if count == 0 then
        local ok, err = self.adapter:press(token)
        if not ok then return self:_result(false, err) end
        self.refs[id] = 1
        self.tokens[id] = token
        self.activeCount += 1
        return true
    end

    -- A real piano key must be released before it can be struck again.
    -- Retrigger the physical key while retaining the overlap reference count,
    -- so an older NoteOff cannot prematurely release the newest strike.
    local previous = self.tokens[id] or token
    pcall(function() self.adapter:release(previous) end)
    local ok, err = self.adapter:press(token)
    if not ok then return self:_result(false, err) end
    self.refs[id] = count + 1
    self.tokens[id] = token
    return true
end

function NoteManager:up(token)
    local id = self.adapter:physicalId(token)
    local count = self.refs[id] or 0
    if count <= 0 then return true end

    count -= 1
    if count == 0 then
        self.refs[id] = nil
        local original = self.tokens[id] or token
        self.tokens[id] = nil
        local ok, err = self.adapter:release(original)
        self.activeCount = math.max(0, self.activeCount - 1)
        return self:_result(ok, err)
    end

    self.refs[id] = count
    return true
end

function NoteManager:releaseAll()
    for id, token in pairs(self.tokens) do
        pcall(function() self.adapter:release(token) end)
        self.refs[id], self.tokens[id] = nil, nil
    end
    if self.adapter.releaseExpressive then pcall(function() self.adapter:releaseExpressive() end) end
    if self.adapter.releaseModifiers then pcall(function() self.adapter:releaseModifiers() end) end
    self.activeCount = 0
end

function NoteManager:diagnostics()
    return {
        activeCount = self.activeCount,
        failures = self.failures,
        lastError = self.lastError,
    }
end

return NoteManager
