---@param arr any[]
---@param value any
local includes = function(arr, value)
    if not arr or not value then
        return false
    end
    for _, v in ipairs(arr) do
        if v == value then
            return true
        end
    end
    return false
end

return includes
