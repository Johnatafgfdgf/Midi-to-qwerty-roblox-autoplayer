local Fixed = {}

local function loadBase()
    local url = "https://raw.githubusercontent.com/Johnatafgfdgf/Midi-to-qwerty-roblox-autoplayer/main/src/UI/App.lua?v=0.3.2"
    local ok, source = pcall(function() return game:HttpGet(url) end)
    assert(ok and type(source)=="string", "[MIDIQWERTY] Failed to load base UI")
    local chunk, err = loadstring(source, "=MIDIQWERTY/UI/App.base")
    assert(chunk, "[MIDIQWERTY] Base UI compile error: "..tostring(err))
    local base = chunk()
    assert(type(base)=="table" and type(base.new)=="function", "[MIDIQWERTY] Invalid base UI")
    return base
end

local Base = loadBase()
setmetatable(Fixed, {__index=Base})

function Fixed.new(callbacks, config)
    config = config or {}
    config.ui = config.ui or {}
    config.ui.state = "Full"

    local app = Base.new(callbacks, config)
    assert(app and app.gui and app.main, "[MIDIQWERTY] UI did not initialize")

    pcall(function()
        app.gui.Enabled = true
        app.gui.DisplayOrder = 1000000
        app.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    end)

    local main = app.main
    local mini = app.miniFrame
    local floating = app.floating

    local function forceFull()
        if not app or not app.gui or app.gui.Parent == nil then return end
        app.state = "Full"
        app.gui.Enabled = true
        main.Visible = true
        main.AnchorPoint = Vector2.new(.5,.5)
        main.Position = UDim2.fromScale(.5,.5)
        main.ZIndex = 1
        if mini then mini.Visible = false end
        if floating then floating.Visible = false end
        if callbacks and callbacks.onUiState then pcall(callbacks.onUiState, "Full", nil) end
    end

    local function setState(_, state)
        if state ~= "Full" and state ~= "Mini" and state ~= "Hidden" then state = "Full" end
        app.state = state
        app.gui.Enabled = true
        main.Visible = state == "Full"
        if mini then mini.Visible = state == "Mini" end
        if floating then floating.Visible = state == "Hidden" end
        if state == "Full" then
            main.AnchorPoint = Vector2.new(.5,.5)
            main.Position = UDim2.fromScale(.5,.5)
            main.ZIndex = 1
        end
        if callbacks and callbacks.onUiState then
            pcall(callbacks.onUiState, state, state=="Hidden" and floating and floating.Position or nil)
        end
    end

    app.setState = setState
    app.forceFull = forceFull

    if floating then
        floating.Active = true
        floating.Selectable = true
        floating.ZIndex = 50
        floating.Activated:Connect(forceFull)
        floating.MouseButton1Click:Connect(forceFull)

        local pressPos = nil
        local moved = false
        floating.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                pressPos = input.Position
                moved = false
            end
        end)
        floating.InputChanged:Connect(function(input)
            if pressPos and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                if (input.Position - pressPos).Magnitude > 14 then moved = true end
            end
        end)
        floating.InputEnded:Connect(function(input)
            if pressPos and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
                local shouldOpen = not moved
                pressPos = nil
                moved = false
                if shouldOpen then task.defer(forceFull) end
            end
        end)
    end

    task.defer(forceFull)
    task.delay(.15, forceFull)
    task.delay(.75, forceFull)

    return app
end

return Fixed
