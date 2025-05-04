local Router      = {}
Router.__index    = Router
Router.__name     = "TrieRouter"
local Trie        = require("trie-router")
local include     = require("utils.include")
local STD_METHODS = { "GET", "POST", "PUT", "PATCH", "HEAD", "OPTIONS", "DELETE" }
local ALL_METHOD  = "ALL"

function Router.new()
    return setmetatable({
        trie = Trie.new()
    }, Router)
end

function Router:add(method, path, ...)
    if method == ALL_METHOD then
        for _, m in ipairs(STD_METHODS) do
            self.trie:insert(m, path, ...)
        end
        return
    end

    self.trie:insert(method, path, ...)
end

function Router:match(method, path)
    return self.trie:search(method, path)
end

return Router
