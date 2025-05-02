local Set = {}
Set.__index = Set

function Set.new()
    return setmetatable({}, Set)
end

function Set:has(key)
    if self[key] then return true end
end

function Set:add(key)
    if type(key) == "table" then
        local keys = key
        for _, k in ipairs(keys) do
            self[k] = true
        end
    else
        self[key] = true
    end
    return self
end

function Set:delete(key)
    self[key] = nil
end

function Set:entries()
    local entries = {}
    for key, value in pairs(self) do
        if value == true then
            table.insert(entries, key)
        end
    end
    return entries
end

return Set
