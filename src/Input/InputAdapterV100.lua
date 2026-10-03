local InputAdapter = {}
InputAdapter.__index = InputAdapter

local shiftedSymbols = {
    ["!"]="1", ["@"]="2", ["#"]="3", ["$"]="4", ["%"]="5",
    ["^"]="6", ["&"]="7", ["*"]="8", ["("]="9", [")"]="0",
}
local digitEnum = {
    ["0"]="Zero", ["1"]="One", ["2"]="Two", ["3"]="Three", ["4"]="Four",
    ["5"]="Five", ["6"]="Six", ["7"]="Seven", ["8"]="Eight", ["9"]="Nine",
}

local function envFn(name)
    local env = (getgenv and getgenv()) or _G
    local value = rawget(env, name) or rawget(_G, name)
    return type(value) == "function" and value or nil
end

local function spec(token)
    if type(token) ~= "string" or #token ~= 1 then return nil end
    local base, shift = token, false
    if shiftedSymbols[token] then
        base, shift = shiftedSymbols[token], true
    elseif token:match("%u") then
        base, shift = string.lower(token), true
    end
    if not base:match("[%a%d]") then return nil end
    local upper = string.upper(base)
    return {
        token = token,
        base = base,
        shift = shift,
        vk = string.byte(upper),
        enumName = base:match("%d") and digitEnum[base] or upper,
        physical = upper,
    }
end

function InputAdapter.new()
    local self = setmetatable({
        destroyed = false,
        strikeGen = {},
        heldStrike = {},
        modifierDown = false,
        metrics = {
            sent = 0,
            failed = 0,
            strikes = 0,
            presses = 0,
            releases = 0,
            modifierPulses = 0,
            lastError = nil,
        },
    }, InputAdapter)

    self.keypress = envFn("keypress") or envFn("key_press") or envFn("key_down")
    self.keyrelease = envFn("keyrelease") or envFn("key_release") or envFn("key_up")
    self.velocityHook = envFn("MIDIQWERTY_VELOCITY_STRIKE")

    if self.keypress and self.keyrelease then
        self.backendKind = "ExecutorKeyEvents"
    else
        local ok, vim = pcall(game.GetService, game, "VirtualInputManager")
        if ok and vim then self.vim = vim; self.backendKind = "VirtualInputManager"
        else self.backendKind = "Unavailable" end
    end

    self.backend = self.backendKind
    if self.velocityHook then self.backend = self.backend .. " + VelocityHook" end
    return self
end

function InputAdapter:_fail(err)
    self.metrics.failed += 1
    self.metrics.lastError = tostring(err or "unknown input error")
    return false, self.metrics.lastError
end

function InputAdapter:physicalId(token)
    local s = spec(token)
    return s and s.physical or tostring(token)
end

function InputAdapter:_sendKey(down, s)
    if self.destroyed then return self:_fail("adapter destroyed") end

    local ok, result
    if self.backendKind == "ExecutorKeyEvents" then
        local f = down and self.keypress or self.keyrelease
        ok, result = pcall(f, s.vk)
    elseif self.vim then
        local keyCode = Enum.KeyCode[s.enumName]
        if not keyCode then return self:_fail("Unsupported KeyCode: " .. tostring(s.enumName)) end
        ok, result = pcall(self.vim.SendKeyEvent, self.vim, down, keyCode, false, game)
    else
        return self:_fail("No keyboard input backend available")
    end

    if not ok then return self:_fail(result) end
    self.metrics.sent += 1
    return true
end

function InputAdapter:_shift(down)
    if self.destroyed then return false end
    local ok, result
    if self.backendKind == "ExecutorKeyEvents" then
        local f = down and self.keypress or self.keyrelease
        ok, result = pcall(f, 0x10)
    elseif self.vim then
        ok, result = pcall(self.vim.SendKeyEvent, self.vim, down, Enum.KeyCode.LeftShift, false, game)
    else
        return false
    end

    if ok then self.modifierDown = down; self.metrics.sent += 1
    else self:_fail(result) end
    return ok
end

function InputAdapter:_keyDownWithModifiers(s)
    if not s.shift then return self:_sendKey(true, s) end
    self.metrics.modifierPulses += 1
    local shiftOk = self:_shift(true)
    if not shiftOk then return false, "failed to press Shift" end
    local ok, err = self:_sendKey(true, s)
    self:_shift(false)
    return ok, err
end

function InputAdapter:strike(token, opts)
    opts = opts or {}
    local s = spec(token)
    if not s then return self:_fail("Unsupported token: " .. tostring(token)) end

    local velocity = math.clamp(tonumber(opts.velocity) or .7, 0, 1)
    local holdMs = math.clamp(tonumber(opts.holdMs) or 34, 6, 15000)
    self.metrics.strikes += 1

    if self.velocityHook and opts.nativeVelocity ~= false then
        local ok, result = pcall(self.velocityHook, token, velocity, opts)
        if ok and result ~= false then return true end
    end

    local id = s.physical
    local gen = (self.strikeGen[id] or 0) + 1
    self.strikeGen[id] = gen

    local old = self.heldStrike[id]
    if old then pcall(function() self:_sendKey(false, old) end) end
    self.heldStrike[id] = s

    local ok, err = self:_keyDownWithModifiers(s)
    if not ok then self.heldStrike[id] = nil; return false, err end

    task.delay(holdMs / 1000, function()
        if self.destroyed or self.strikeGen[id] ~= gen then return end
        local held = self.heldStrike[id]
        if held then pcall(function() self:_sendKey(false, held) end) end
        if self.strikeGen[id] == gen then self.heldStrike[id] = nil end
    end)
    return true
end

function InputAdapter:tap(token)
    return self:strike(token, {holdMs = 18, velocity = .7, nativeVelocity = false})
end

function InputAdapter:press(token)
    local s = spec(token)
    if not s then return self:_fail("Unsupported token: " .. tostring(token)) end
    self.metrics.presses += 1
    return self:_keyDownWithModifiers(s)
end

function InputAdapter:release(token)
    local s = spec(token)
    if not s then return self:_fail("Unsupported token: " .. tostring(token)) end
    self.metrics.releases += 1
    return self:_sendKey(false, s)
end

function InputAdapter:releaseModifiers()
    if self.modifierDown then self:_shift(false) end
    self.modifierDown = false
end

function InputAdapter:releaseExpressive()
    for id, s in pairs(self.heldStrike) do
        pcall(function() self:_sendKey(false, s) end)
        self.heldStrike[id] = nil
        self.strikeGen[id] = (self.strikeGen[id] or 0) + 1
    end
end

function InputAdapter:destroy()
    self:releaseExpressive()
    self:releaseModifiers()
    self.destroyed = true
end

function InputAdapter:diagnostics()
    return {
        backend = self.backend,
        available = self.backendKind ~= "Unavailable",
        nativeVelocity = self.velocityHook ~= nil,
        expressiveStrike = true,
        maxStrikeHoldMs = 15000,
        sent = self.metrics.sent,
        failed = self.metrics.failed,
        strikes = self.metrics.strikes,
        presses = self.metrics.presses,
        releases = self.metrics.releases,
        modifierPulses = self.metrics.modifierPulses,
        lastError = self.metrics.lastError,
    }
end

return InputAdapter
