local split = function(str)
    local x = {}
    if str == "/" then table.insert(x, "") end
    for a in string.gmatch(str, "[^/]+") do
        table.insert(x, a)
    end
    return x
end


return split
