local function prune(node)
    for k, v in pairs(node) do
        if type(v) == "table" then
            if next(v) == nil then node[k] = nil else prune(v) end
        end
    end
end

return prune
