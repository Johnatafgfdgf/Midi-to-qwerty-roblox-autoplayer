local InputAdapter = {}
InputAdapter.__index = InputAdapter

local shiftedSymbols = { ["!"]="1",["@"]="2",["#"]="3",["$"]="4",["%"]="5",["^"]="6",["&"]="7",["*"]="8",["("]="9",[")"]="0" }
local digitEnum = { ["0"]="Zero",["1"]="One",["2"]="Two",["3"]="Three",["4"]="Four",["5"]="Five",["6"]="Six",["7"]="Seven",["8"]="Eight",["9"]="Nine" }

local function envFn(name)
    local env = (getgenv and getgenv()) or _G
    local v = rawget(env, name) or rawget(_G, name)
    return type(v) == "function" and v or nil
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
        token=token, base=base, shift=shift,
        vk=string.byte(upper),
        enumName=base:match("%d") and digitEnum[base] or upper,
        physical=upper .. (shift and ":S" or ":N"),
    }
end

function InputAdapter.new()
    local self = setmetatable({shiftRefs=0}, InputAdapter)
    self.keypress = envFn("keypress") or envFn("key_press") or envFn("key_down")
    self.keyrelease = envFn("keyrelease") or envFn("key_release") or envFn("key_up")
    self.backend = "Unavailable"
    if self.keypress and self.keyrelease then
        self.backend = "ExecutorKeyEvents"
    else
        local ok, vim = pcall(game.GetService, game, "VirtualInputManager")
        if ok and vim then self.vim, self.backend = vim, "VirtualInputManager" end
    end
    return self
end

function InputAdapter:physicalId(token)
    local s = spec(token)
    return s and s.physical or tostring(token)
end

function InputAdapter:_sendKey(down, s)
    if self.backend == "ExecutorKeyEvents" then
        local f = down and self.keypress or self.keyrelease
        return pcall(f, s.vk)
    elseif self.backend == "VirtualInputManager" then
        local keyCode = Enum.KeyCode[s.enumName]
        if not keyCode then return false, "Unsupported KeyCode: "..tostring(s.enumName) end
        return pcall(self.vim.SendKeyEvent, self.vim, down, keyCode, false, game)
    end
    return false, "No keyboard input backend available"
end

function InputAdapter:_shift(down)
    if self.backend == "ExecutorKeyEvents" then
        local f = down and self.keypress or self.keyrelease
        return pcall(f, 0x10)
    elseif self.backend == "VirtualInputManager" then
        return pcall(self.vim.SendKeyEvent, self.vim, down, Enum.KeyCode.LeftShift, false, game)
    end
    return false
end

function InputAdapter:tap(token)
    local s = spec(token)
    if not s then return false, "Unsupported token: "..tostring(token) end
    -- Keep modifier scope entirely inside one logical strike. This prevents
    -- Shift leaking into the next white note in dense mixed chords.
    if s.shift then self:_shift(true) end
    local ok, err = self:_sendKey(true, s)
    self:_sendKey(false, s)
    if s.shift then self:_shift(false) end
    return ok, err
end

function InputAdapter:press(token)
    local s = spec(token)
    if not s then return false, "Unsupported token: "..tostring(token) end
    if s.shift then
        if self.shiftRefs == 0 then self:_shift(true) end
        self.shiftRefs += 1
    end
    local ok, err = self:_sendKey(true, s)
    if not ok and s.shift then
        self.shiftRefs = math.max(0,self.shiftRefs-1)
        if self.shiftRefs == 0 then self:_shift(false) end
    end
    return ok, err
end

function InputAdapter:release(token)
    local s = spec(token)
    if not s then return false, "Unsupported token: "..tostring(token) end
    local ok, err = self:_sendKey(false, s)
    if s.shift then
        self.shiftRefs = math.max(0,self.shiftRefs-1)
        if self.shiftRefs == 0 then self:_shift(false) end
    end
    return ok, err
end

function InputAdapter:releaseModifiers()
    if self.shiftRefs > 0 then self:_shift(false) end
    self.shiftRefs = 0
end

function InputAdapter:diagnostics()
    return {backend=self.backend, available=self.backend~="Unavailable"}
end

return InputAdapter
