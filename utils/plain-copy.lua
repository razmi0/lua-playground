local plainCopy = function(t)
    local copy = {}
    for i = 1, #t do copy[i] = t[i] end
    return copy
end

return plainCopy
