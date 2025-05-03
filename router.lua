local Trie                  = require("trie-router")

local Router                = {}
Router.__index              = Router
Router.__name               = "TrieRouter"
local defs                  = require("router-definitions")
local ALL_AVAILABLE_METHODS = defs.methods.ALL_AVAILABLE_METHODS
local ALL_METHOD            = defs.methods.ALL_METHOD
local STD_METHODS           = defs.methods.STD_METHODS

function Router.new()
    return setmetatable({
        trie = Trie.new()
    }, Router)
end

function Router:add(method, path, ...)
    if not ALL_AVAILABLE_METHODS:has(method) then
        error("Unknown method : " .. method)
        return
    end

    if method == ALL_METHOD then
        for _, m in ipairs(STD_METHODS:entries()) do
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
