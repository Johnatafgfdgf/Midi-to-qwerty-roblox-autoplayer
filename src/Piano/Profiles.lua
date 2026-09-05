local Profiles = {}

-- Standard Roblox / Virtual Piano layout: 36 white keys laid out as
-- 1234567890 qwertyuiop asdfghjkl zxcvbnm, with Shift producing the
-- chromatic black key where that piano key actually has a sharp.
-- The musical range is C2..C7 (MIDI 36..96), exactly 61 chromatic notes.
local WHITE = "1234567890qwertyuiopasdfghjklzxcvbnm"
local WHITE_PC = {[0]=true,[2]=true,[4]=true,[5]=true,[7]=true,[9]=true,[11]=true}
local SHIFT_DIGIT = { ["1"]="!",["2"]="@",["3"]="#",["4"]="$",["5"]="%",["6"]="^",["7"]="&",["8"]="*",["9"]="(",["0"]=")" }

local function shifted(token)
    return SHIFT_DIGIT[token] or string.upper(token)
end

local function buildStandardMap(lowest, highest)
    local map, whiteIndex, previousWhite = {}, 1, nil
    for midi = lowest, highest do
        local pc = midi % 12
        if WHITE_PC[pc] then
            local token = string.sub(WHITE, whiteIndex, whiteIndex)
            assert(token ~= "", "Standard piano profile exhausted white keys")
            map[midi] = token
            previousWhite = token
            whiteIndex += 1
        else
            assert(previousWhite, "Black key cannot precede first white key")
            map[midi] = shifted(previousWhite)
        end
    end
    assert(whiteIndex - 1 == #WHITE, "Standard piano profile did not consume exactly 36 white keys")
    return map
end

Profiles.RobloxVirtualPiano61 = {
    id = "RobloxVirtualPiano61",
    name = "Roblox / Virtual Piano 61 (C2-C7)",
    lowest = 36,
    highest = 96,
    map = buildStandardMap(36, 96),
}

-- Compatibility alias for older saved configs. It intentionally points at
-- the corrected 61-note profile rather than the old erroneous 69-note map.
Profiles.VirtualPiano61 = Profiles.RobloxVirtualPiano61

function Profiles.get(name)
    return Profiles[name] or Profiles.RobloxVirtualPiano61
end

function Profiles.list()
    local out, seen = {}, {}
    for k, v in pairs(Profiles) do
        if type(v) == "table" and v.map and not seen[v] then
            seen[v] = true
            out[#out + 1] = {id = v.id or k, name = v.name}
        end
    end
    table.sort(out, function(a,b) return a.name < b.name end)
    return out
end

return Profiles
