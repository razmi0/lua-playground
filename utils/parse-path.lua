---@alias DynamicData { optionnal : true|nil, pattern : string|nil }?


---@param str string
---@return string, "dynamic"|"static"|"wildcard", DynamicData
local function parse(str)
    if str == "*" then
        return "*", "wildcard"
    end

    local dynamic, seg, optionnal, pattern = str:match("^(:?)([%w%-%_]+)(%??){?(.-)}?$")

    local data = {
        optionnal = (optionnal == "?") or nil,
        pattern = (pattern ~= "" and pattern) or nil
    }

    if dynamic ~= ":" then
        return seg, "static", data
    end



    return seg, "dynamic", data
end

return parse
