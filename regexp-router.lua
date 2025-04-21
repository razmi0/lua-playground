local inspect = require("inspect")
local Set = require("utils.set")
local parse = require("utils.parse-path")
local split = require("utils.split-path")
local log = function(x) print(inspect(x)) end

local expression = {
    placeholder = "***",
    capture = {
        index = "(%d+)",
        method = "(%a+)",
        param = "([%w_%-]+)",
    },
    delimiter = function(str)
        return "::#" .. str .. "#::?"
    end
}

local routesSet = Set.new()
local score = 0
local routes = {}
local encoded = {
    dynamic = "",
    static = ""
}
local add = function(method, path, ...)
    -- prevent path duplication
    if routesSet:has(method .. path) then
        return
    end
    routesSet:add(method .. path)
    --

    local pathType = "static"
    local handlers = { ... }
    local possibleKeys = {}
    local patternPath = ""
    score = score + 1
    local parts = split(path)

    for i, part in ipairs(parts) do
        local segment, type, data, label = parse(part)
        if type == "dynamic" then
            pathType = "dynamic" -- the path has at least one dynamic segment
            table.insert(possibleKeys, label)
            patternPath = patternPath .. "/" .. expression.capture.param
        end
        if type == "static" then
            patternPath = patternPath .. "/" .. segment
        end
    end

    -- score is node index
    table.insert(routes, { handlers, possibleKeys, method }) -- store route data as a "node"

    local added = expression.delimiter(score)
    if pathType == "dynamic" then
        added = added .. patternPath
    elseif pathType == "static" then
        added = added .. path
    end

    encoded[pathType] = encoded[pathType] .. added -- store it in correct encoded string
end

--#region
add(
    "GET", "/order/id", function(any)
        return ("hi handler 1 : " .. table.concat(any))
    end,
    function(any)
        return ("hi handler 2 : " .. table.concat(any))
    end
)
-- add(
--     "GET", "/cmd/:id", function(any)
--         return ("hi handler 5 : " .. table.concat(any))
--     end,
--     function(any)
--         return ("hi handler 6 : " .. table.concat(any))
--     end
-- )
add(
    "GET", "/user/:name", function(any)
        return ("hi handler 3 : " .. table.concat(any))
    end,
    function(any)
        return ("hi handler 4 : " .. table.concat(any))
    end
)
log(encoded)
--#endregion

local HTTP404 = function()
    return "not found"
end
local HTTP405 = function()
    return "method not allowed"
end

---@alias Handlers function[]
---@return Handlers, table<string>?
local match = function(method, path)
    local prefixPattern = "::#" .. expression.capture.index .. "#::"
    local pattern = prefixPattern .. "(" .. path .. ")"

    local i, _ = (string.gmatch(encoded.static, pattern))()
    local route = routes[tonumber(i)]

    if not route then
        -- match against dynamic
        local prefix, username = path:match("^(::#2#::)?/user/([%w_-]+)$")
        log(path)
        log(prefix)
        log(username)

        if username then
            print("Match found! Username:", username)
            if prefix then
                print("Prefix:", prefix)
            end
        else
            print("No match")
        end

        i, _ = (
            string.gmatch(
                "^(::#2#::)?/user/([%w_-]+)$", -- encoded.dynamic, -- ::#2#::/user/([%w_%-]+)
                path                           -- "/user/john_doe-123"
            ))()
        -- log(i)
        -- log(_)
        route = routes[tonumber(i)]

        if not route then
            return { HTTP404 }, {}
        end
    end

    local m = route[3]
    local handlers = route[1]
    local keys = route[2]

    if m ~= method then return { HTTP405 } end

    return handlers, keys
end



--#region
local handlers, params = match("GET", "/user/john_doe-123")
for _, handler in ipairs(handlers) do
    log(handler(params))
end
--#endregion
