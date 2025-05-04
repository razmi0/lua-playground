-- This fn is used in Trie:search method in dynamic nodes section
local function findBest(nodes, part, remain)
    local best
    for _, d in ipairs(nodes or {}) do
        local isValid, isBetter =
            not d.pattern or part:match(d.pattern),
            (not best or d.score or 0 > (best.score or 0))
        if
            remain >= (d.score or 0) -- enough segments left to match its branch
            and isValid              -- valid part
            and isBetter             -- longer branch = more specific = better
        then
            best = d
        end
    end
    return best and best.node
end

return findBest
