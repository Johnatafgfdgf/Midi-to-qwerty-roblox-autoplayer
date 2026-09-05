local Profiles = {}

local sequence = {
    "1","!","2","@","3","4","$","5","%","6","^","7","8","*","9","(","0",
    "q","Q","w","W","e","E","r","R","t","T","y","Y","u","U","i","I","o","O","p","P",
    "a","A","s","S","d","D","f","F","g","G","h","H","j","J","k","K","l","L",
    "z","Z","x","X","c","C","v","V","b","B","n","N","m","M"
}

local map = {}
local lowest = 36
for i, token in ipairs(sequence) do map[lowest + i - 1] = token end
Profiles.VirtualPiano61 = {
    id = "VirtualPiano61",
    name = "Virtual Piano QWERTY",
    lowest = lowest,
    highest = lowest + #sequence - 1,
    map = map,
}

function Profiles.get(name) return Profiles[name] or Profiles.VirtualPiano61 end
function Profiles.list()
    local out = {}
    for k, v in pairs(Profiles) do if type(v) == "table" and v.map then out[#out + 1] = {id = k, name = v.name} end end
    return out
end
return Profiles
