local split = require("utils.split-path")

local function compareMw(mw, hd)
    if mw.method ~= "USE" and mw.method ~= hd.method then
        return false
    end

    local mwp = split(mw.path)
    local hdp = split(hd.path)

    local hasWildcard = false
    for _, segment in ipairs(mwp) do
        if segment == "*" then
            hasWildcard = true
            break
        end
    end

    if not hasWildcard and #hdp > #mwp then
        return false
    end

    for i = 1, #mwp do
        local p = mwp[i]
        if p ~= "*" and p ~= hdp[i] then
            return false
        end
    end

    return true
end


return compareMw
