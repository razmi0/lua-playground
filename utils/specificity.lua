local function findBest(nodes, ...)
    local validators = { ... }
    local best
    for _, d in ipairs(nodes or {}) do
        local valid = true
        for _, fn in ipairs(validators) do
            if not fn(d, best) then
                valid = false
                break
            end
        end
        if valid then
            best = d
        end
    end
    return best and best.node
end

return findBest
