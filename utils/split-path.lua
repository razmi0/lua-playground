local split = function(str)
    local x = {}
    for a in string.gmatch(str, "[^/]+") do
        table.insert(x, a)
    end
    return x
end


return split
