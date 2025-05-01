local Trie = require("trie-router")

local Router = {}
Router.__index = Router
Router.__name = "TrieRouter"

function Router.new()
    return setmetatable({
        trie = Trie.new()
    }, Router)
end

function Router:add(method, path, handlers)
    self.trie:insert(method, path, handlers)
end

function Router:match(method, path)
    return self.trie:search(method, path)
end

return Router
