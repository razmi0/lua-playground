local inspect = require("inspect")
local Set = require("utils.set")
local log = function(x) print(inspect(x)) end

local routesSet = Set.new()
local score = 0
local routes = {}
local encoded = ""

local RegExpRouter = {}
RegExpRouter.__index = RegExpRouter

function RegExpRouter.new()
    return setmetatable({}, RegExpRouter)
end

local expression = {
    capture = {
        index = "(%d+)",
        method = "(%a+)",
    },
    delimiter = function(str)
        return "::#" .. str .. "#::"
    end
}

function RegExpRouter:add(method, path, ...)
    -- prevent path duplication
    if routesSet:has(method .. path) then
        return
    end
    routesSet:add(method .. path)
    --
    local handlers = { ... }
    score = score + 1
    -- score is node index
    table.insert(routes, { handlers, method }) -- store route data as a "node"
    local added = expression.delimiter(score) .. path
    encoded = encoded .. added
end

---@alias Handlers function[]
---@return Handlers| false
function RegExpRouter:match(method, path)
    local prefixPattern = "::#" .. expression.capture.index .. "#::"
    local pattern = prefixPattern .. "(" .. path .. ")"
    local i, _ = (string.gmatch(encoded, pattern))()
    local route = routes[tonumber(i)]
    if not route then
        return false
    end
    local m = route[2]
    local handlers = route[1]
    if m ~= method then
        return { function()
            return 'METHOD NOT ALLOWED'
        end }
    end
    return handlers
end

--#region


local inserted_routes = {
    GET = {
        "/users/new",
        "/users/id",
        "/items/id",
        "/items/slug",
        "/products/category",
        "/articles/page",
        "/search/query/results",
        "/config/type/",
        "/files",
        "/",
        "/data",
        "/data/key",
        "/lookup/id",
        "/middleware"
    },
    POST = {
        "/api/v1/resource"
    },
}

local requested_routes = {
    GET = {
        "/users/new",
        "/users/id",
        "/items/456",
        "/items/my-item",
        "/items/invalid",
        "/items/Invalid-Item",
        "/products/electronics",
        "/products",
        "/products/",
        "/articles/5",
        "/articles",
        "/articles/abc",
        "/search/lua-trie/results",
        "/search/results",
        "/config/user/theme",
        "/config/user",
        "/config",
        "/files/css/style.css",
        "/files/index.html",
        "/files/",
        "/files",
        "/",
        "/data",
        "/data/with%20space",
        "/lookup/a%2Fb",
        "/middleware"
    },
    POST = {
        "/api/v1/posts/123/publish",
        "/api/v1/resource",
        "/api/v1/tags/abc",
        "/api/v1/posts/123",
        "/api/v1/posts/123/publish/now"
    }
}

local regexpRouter = RegExpRouter.new()
for m, paths in pairs(inserted_routes) do
    for i, path in ipairs(paths) do
        regexpRouter:add(m, path, function()
            return "FN" .. tostring(i)
        end)
    end
end
local results = {
    GET = {},
    POST = {}
}
for m, paths in pairs(requested_routes) do
    for i, path in ipairs(paths) do
        local handlers = regexpRouter:match(m, path)
        if type(handlers) == "table" then
            local r = handlers[1]()
            table.insert(results[m], {
                handlersResult = (handlers and r) or "NOT FOUND",
                path = path
            })
        else
            -- log(path .. " : " .. tostring(handlers))
        end
    end
end

log(encoded)


--#endregion
