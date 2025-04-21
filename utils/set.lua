local Set = {}
Set.__index = Set

function Set.new()
    return setmetatable({}, Set)
end

function Set:has(key)
    if Set[key] then return true end
end

function Set:add(key)
    Set[key] = true
end

function Set:delete(key)
    Set[key] = nil
end

function Set:entries()
    local entries = {}
    for key, value in pairs(Set) do
        if value == true then
            table.insert(entries, key)
        end
    end
    return entries
end

return Set
