local FIXED_COMMIT = "c27422ba2ae4df5f4c90f00ad141b8a2431bb6c2"
local BASE_URL = "https://raw.githubusercontent.com/Johnatafgfdgf/Midi-to-qwerty-roblox-autoplayer/"..FIXED_COMMIT.."/src/UI/AppMobileV041.lua"

local ok, source = pcall(function() return game:HttpGet(BASE_URL) end)
assert(ok and type(source)=="string", "[MIDIQWERTY] Failed to load v0.4.1 UI base")
local chunk, err = loadstring(source, "=MIDIQWERTY/UI/AppMobileV041.base")
assert(chunk, "[MIDIQWERTY] UI base compile error: "..tostring(err))
local Base = chunk()
assert(type(Base)=="table" and type(Base.new)=="function", "[MIDIQWERTY] Invalid UI base")

local Fixed = {}
setmetatable(Fixed, {__index=Base})

function Fixed.new(callbacks, config)
    local app = Base.new(callbacks, config)
    assert(app and app.pages and app.gui and app.main, "[MIDIQWERTY] UI base did not initialize")

    -- v0.4.1 bug: each ScrollingFrame lived inside holder.Visible=false.
    -- The tab switch only toggled the ScrollingFrame, so every page stayed hidden.
    for _, page in pairs(app.pages) do
        if page and page.Parent and page.Parent:IsA("Frame") then
            page.Parent.Visible = true
        end
    end

    -- Keep only the selected page visible. The holders themselves remain visible.
    local function showPage(name)
        for key, page in pairs(app.pages) do
            page.Visible = key == name
            if page.Parent then page.Parent.Visible = true end
        end
        for key, btn in pairs(app.nav or {}) do
            if btn and btn:IsA("GuiButton") then
                btn.BackgroundColor3 = key == name and Color3.fromRGB(121,86,255) or Color3.fromRGB(28,32,46)
            end
        end
        app.activeTab = name
    end

    -- Rebind tab buttons with a second, correct handler. Existing handlers may still run,
    -- but this one fixes the parent visibility every time after the tap.
    for name, btn in pairs(app.nav or {}) do
        if btn and btn:IsA("GuiButton") then
            btn.Activated:Connect(function()
                task.defer(function() showPage(name) end)
            end)
        end
    end

    -- Visible build marker and diagnostics.
    for _, d in ipairs(app.gui:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text == "v0.4.1 NEW UI" then
            d.Text = "v0.4.2 CONTENT FIX"
            d.Size = UDim2.fromOffset(126,24)
        end
    end

    app.gui.Name = "MIDIQWERTY_V042_CONTENTFIX"
    app.gui.Enabled = true
    app.gui.DisplayOrder = 10000
    app.main.Visible = true

    showPage("Songs")
    task.defer(function()
        showPage(app.activeTab or "Songs")
    end)

    return app
end

return Fixed
