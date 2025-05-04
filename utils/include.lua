local function include(arr, target)
    for _, value in ipairs(arr) do
        if target == value then
            return true
        end
    end
    return
end

return include
