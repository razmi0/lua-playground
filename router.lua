---@alias HTTPMethod string|"USE"|"ALL"

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
---@param method HTTPMethod
---@param path string
---@param ... fun(...: any): any
function Router:add(method, path, ...)
    self.trie:insert(method, path, ...)
end

---Find a route in the trie router
---@param method HTTPMethod
---@param path string
---@return TrieLeaf[] matches,  table<string, string>| {} params
function Router:match(method, path)
    return self.trie:search(method, path)
end

return Router
