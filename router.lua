local inspect  = require("inspect")
---@class Router
---@field trie Trie internal trie router
local Router   = {}
Router.__index = Router
Router.__name  = "TrieRouter"
local Trie     = require("trie-router")

function Router.new()
    return setmetatable({
        trie = Trie.new()
    }, Router)
end

-- Add a route to trie router
---@param method Method
---@param path Path route pattern
---@param ... Handler|Middleware functions
function Router:add(method, path, ...)
    self.trie:insert(method, path, ...)
end

---Find a route in the trie router
---@param method Method HTTP method to match
---@param path Path to search
---@return MatchResult?, table? list of handlers and extracted params or nil
function Router:match(method, path)
    return self.trie:search(method, path)
end

local router = Router.new()

router.trie:insert("USE", "*", function()
    return "use"
end)

router.trie:insert("GET", "/items", function()
    return "static"
end)

local hs, p = router.trie:search("GET", "/static")

print(inspect(hs), inspect(p), inspect(router.trie.root))




return Router
