---@class Router
---@field trie Trie internal trie router
local Router   = {}
Router.__index = Router
Router.__name  = "TrieRouter"
local Trie     = require("trie-router")
-- local STD_METHODS = { "GET", "POST", "PUT", "PATCH", "HEAD", "OPTIONS", "DELETE" }
-- local ALL_METHOD  = "ALL"
-- local ON_METHOD   = "ON"

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
    -- if method == ALL_METHOD then
    --     for _, m in ipairs(STD_METHODS) do
    --         self.trie:insert(m, path, ...)
    --     end
    --     return
    -- end

    -- if method == ON_METHOD then
    --     if type(method) ~= "table" then method = { method } end
    --     if type(path) ~= "table" then path = { path } end
    --     for _, m in ipairs(method) do
    --         for _, p in ipairs(path) do
    --             self.trie:insert(m, p, ...)
    --         end
    --     end
    -- end

    self.trie:insert(method, path, ...)
end

---Find a route in the trie router
---@param method Method HTTP method to match
---@param path Path to search
---@return MatchResult?, table? list of handlers and extracted params or nil
function Router:match(method, path)
    return self.trie:search(method, path)
end

return Router
