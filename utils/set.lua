local Set = {}
Set.__index = Set

function Set.new()
    return setmetatable({}, Set)
end

function Set:has(key)
    if Set[key] then return true end
end

function Set:add(key)
    if type(key) == "table" then
        local keys = key
        for _, k in ipairs(keys) do
            Set[k] = true
        end
    else
        Set[key] = true
    end
    return self
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
