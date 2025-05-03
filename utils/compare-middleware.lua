local split = require("utils.split-path")

local function compareMw(mw, hd)
    if mw.method ~= "USE" and mw.method ~= hd.method then return false end
    local mwp, hdp = split(mw.path), split(hd.path)
    for i = 1, #mwp do
        local p = mwp[i]
        if p ~= "*" and p ~= hdp[i] then return false end
    end
    return true
end

return compareMw
