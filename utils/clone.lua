local clone = function(fns)
    local hs = {}
    for _, h in ipairs(fns) do
        hs[#hs + 1] = h
    end
    return hs
end


return clone
