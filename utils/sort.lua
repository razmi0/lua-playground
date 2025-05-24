local function sort(arr, predicate)
    local n = #arr
    if n < 2 then return arr end
    for i = 1, n do
        for j = 1, n - i do
            local r = predicate(arr[j], arr[j + 1])
            if r then
                arr[j], arr[j + 1] = arr[j + 1], arr[j]
            end
        end
    end
    return arr
end


return sort
