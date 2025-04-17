-- the handler is not the last function in handlers[]. the handler is the one returning a response
-- a middleware that returns a response is an handler and will short-cut processing

-- redeclare a route => the first route is used not he second ( the first route return the response first short circuting the chain)
-- middleware are declared and queued and at the end of the registration process, the trie is searched and middleware are inserted
-- middleware are inserted if the score is superior to mw node

local inspect = require("inspect")
local parse = require("utils.parse-path")
local split = require("utils.split-path")
local includes = require("utils.includes")

local plHandler = function() print("im 1") end
local plHandler2 = function() print("im 2") end
local plHandler3 = function() print("im 3") end
local plHandler4 = function() print("im 4") end

local Trie = {}
Trie.__index = Trie

function Trie.new()
    return setmetatable({
        value = {},
        score = 0,
        mwSet = {}, -- used for middleware registration
        hdlSet = {} -- used for middleware registration
    }, Trie)
end

function Trie:__call()
    return self.value, self.mwSet, self.hdlSet
end

function Trie:getScore()
    self.score = self.score + 1
    return self.score
end

function Trie:insert(method, path, handlers)
    if method == "USE" then
        self.mwSet[self:getScore()] = {
            path = path,
            middlewares = handlers,
        }
    else
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
                if not currentNode[segment].optionnal then              -- later route declaration does not override
                    currentNode[segment].optionnal = partData.optionnal -- static can be optional too
                end
            end
            --
            -- focus next node
            currentNode = currentNode[segment]
            --
            -- the end
            if i == #parts then
                if not currentNode[method] then
                    local score = self:getScore()
                    currentNode[method] = {
                        handlers = handlers, -- main handler
                        score = score,       -- create tracker counter
                        possibleKeys = params,
                        path = path,
                        method = method
                    }
                    self.hdlSet[score] = currentNode[method]
                else
                    for _, handler in ipairs(handlers) do
                        table.insert(currentNode[method].handlers, 1, handler)
                    end
                end
            end
            --
        end
    end

    return self
end

local compare = function(mwPath, handlerPath)
    local mwParts = split(mwPath)
    local hdlParts = split(handlerPath)

    local replaceOpt = function(str)
        -- rm the third group ( optionnal )
        local dynamic, label, _, pattern = string.match(str, "^(:?)([%w%-%_*]+)(%??){?(.-)}?$")
        return dynamic .. label .. pattern
    end

    for i = 1, #mwParts, 1 do
        if not hdlParts[i] then
            return false
        end
        -- can be optionnal and share all except last char"?"
        local hdlSeg = replaceOpt(hdlParts[i])
        local mwSeg = replaceOpt(mwParts[i])
        -- "*?"
        if mwSeg == "*" then
            goto continue
        end
        if mwSeg ~= hdlSeg then
            return false
        end
        ::continue::
    end
    return true
end

function Trie:attachMiddlewares()
    -- mw are added if :
    -- the path match (with dynamic, pattern and wildcard but not optionnal)
    -- the score of the concrete route > score of mw
    for score, mwNode in pairs(self.mwSet) do
        -- minimum score to receive a middleware
        local i = score
        while true do
            i = i + 1
            -- potential target
            local handlerNode = self.hdlSet[i]
            local continue = self.mwSet[i]
            -- score handlers and score middleware make a linear (1,2, n .. n + 1) together
            -- if no handlerset AND no mw stored, gap in the linear sequence => all exploration of callbacks done
            local stop = not handlerNode and not continue
            if stop then break end
            -- everything is available
            if handlerNode then
                -- method comparison not implemented
                local isCompatible = compare(mwNode.path, handlerNode.path)
                if isCompatible then
                    local middlewares = mwNode.middlewares
                    local handlers = handlerNode.handlers
                    -- mw are inserted before first handler
                    local insertedIdx = 1
                    for _, mw in ipairs(middlewares) do
                        table.insert(handlers, insertedIdx, mw)
                        insertedIdx = insertedIdx + 1
                    end
                end
            end
        end
    end
end

function Trie:search(method, path)

end

local trie = Trie.new()
    :insert("USE", "/order/id?/*", {
        function()
            print("MIDDLEWARE 1")
        end,
        function()
            print("MIDDLEWARE 2")
        end
    })
    :insert("GET", "/order/id?/:where", {
        function()
            print("GET ROUTE /order/id?/:where 1")
        end,
        function()
            print("GET ROUTE /order/id?/:where 2")
        end
    })
    :insert("GET", "/order/name/name/me/you", { plHandler2 })

local handler_trie, mw_set, hdls_set = trie()

trie:attachMiddlewares()
-- print(inspect(handler_trie))
-- print("\n")
-- print(inspect(mw_set))
-- print("\n")
-- print(inspect(hdls_set))
