-- the handler is not the last functions. the handler is the one returning a response

local inspect = require("inspect")
local parse = require("utils.parse-path")
local split = require("utils.split-path")
local includes = require("utils.includes")

local plHandler = function() end


local urlPaths = {
    -- "/",
    -- "/users",
    -- "/users/me",
    -- "/users/123",
    -- "/products",
    -- "/products/:id?/:name",
    -- "/products/category/electronics/stored",
    -- "/products/tag/electronics",
    -- "/products/tag/electronics/trie",
    "/orders/name/id/items",
    -- "/orders/:id?{%d+}",
    "/orders/id",
    -- "/orders/pending",
    -- "/settings",
    -- "/api/v1/data",
    -- "/images/logo.png",
    -- "/css/style.css",
    -- "/js/script.js"
}

local Trie = {}
Trie.__index = Trie

function Trie.new()
    return setmetatable({
        value = {},
        score = 0
    }, Trie)
end

function Trie:__call()
    return self.value
end

function Trie:getScore()
    self.score = self.score + 1
    return self.score
end

function Trie:insert(method, path, handler)
    local parts = split(path)
    local currentNode = self.value
    if not currentNode then
        self.value = {}
        currentNode = self.value
    end

    local params = {}
    for i, part in ipairs(parts) do
        local segment, segmentType, partData = parse(part)


        -- create new empty node
        if not currentNode[segment] then
            currentNode[segment] = {}
        end
        --
        -- dynamic or static segment
        if partData then
            if segmentType == "dynamic" then
                table.insert(params, segment)
                currentNode[segment].pattern = partData.pattern
            end
            currentNode[segment].optionnal = partData.optionnal -- static can be optional too
        end
        --
        -- focus next node
        currentNode = currentNode[segment]
        --
        -- the end
        if i == #parts then
            if not currentNode[method] then
                currentNode[method] = {
                    handlers = { handler },  -- main handler
                    score = self:getScore(), -- createAt tracker counter
                    possibleKeys = params    -- not implemented yet
                }
            end
        end
        --
    end

    return self
end

function Trie:search(word)

end

local trie = Trie.new()
    :insert("USE", "/order/id", plHandler)
    :insert("GET", "/order/id", plHandler)
    :insert("GET", "/order/id/*", plHandler)
    :insert("GET", "/invoices/:id?{%d+}/:name", plHandler)
    :insert("POST", "/order/id", plHandler)

print(inspect(trie()))
