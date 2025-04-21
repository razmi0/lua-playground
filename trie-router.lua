local inspect = require("inspect")
local parse = require("utils.parse-path")
local PATTERN_GROUPS = require("utils.patterns")
local split = require("utils.split-path")


local Trie = {}
Trie.__index = Trie

function Trie.new()
    return setmetatable({
        value = {},
        score = 0,
        mwSet = {},  -- used for middleware registration
        hdlSet = {}, -- used for middleware registration
        isMwPopulated = false
    }, Trie)
end

function Trie:__call()
    return self.value, self.mwSet, self.hdlSet
end

function Trie:getScore()
    self.score = self.score + 1
    return self.score
end

function Trie:insert(method, path, ...)
    local handlers = { ... }
    if method == "USE" then
        self.mwSet[self:getScore()] = {
            path = path,
            middlewares = handlers,
        }
        return self
    end

    local parts = split(path)
    print(inspect(parts))
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
                table.insert(params, segment:match(PATTERN_GROUPS.label))
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

    return self
end

local compare = function(mwPath, handlerPath)
    local mwParts = split(mwPath)
    local hdlParts = split(handlerPath)

    local replaceOpt = function(str)
        -- rm the third group ( optionnal )
        local dynamic, label, _, pattern = string.match(str, PATTERN_GROUPS.complete)
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
    self.mwSet = nil
end

function Trie:search(method, path)
    if not self.isMwPopulated then
        self:attachMiddlewares()
        self.isMwPopulated = true
    end

    local parts = split(path)
    local node = self.value -- Assuming self.value is the root node of the Trie
    local accValues = {}    -- Accumulate parameter values IN ORDER
    local numParts = #parts

    local function traverse(currentNode, partIdx)
        if partIdx > numParts then
            if currentNode[method] then
                local handlerNode = currentNode[method]
                local params = {}
                local expectedKeys = handlerNode.possibleKeys or {}
                for i, key in ipairs(expectedKeys) do
                    params[key] = accValues[i]
                end
                return handlerNode.handlers, params
            end
            for stored_path, childNode in pairs(currentNode) do
                local _, segmentType, data = parse(stored_path)
                if data and data.optionnal then
                    local paramValue = nil
                    local pushedParam = false
                    if segmentType == "dynamic" then
                        table.insert(accValues, paramValue)
                        pushedParam = true
                    end
                    local handlers, params = traverse(childNode, partIdx)

                    if handlers then
                        return handlers, params
                    end
                    -- Backtrack: If the optional path didn't lead to a match, remove the placeholder
                    if pushedParam then
                        table.remove(accValues)
                    end
                end
            end
            -- No match found after checking current node and optional paths
            return nil, nil
        else
            -- Processing current part
            local currentPart = parts[partIdx]
            local nextNode = nil
            local foundMatch = false -- Flag if currentPart led down a valid path segment

            -- 1. Static Match has highest priority
            if currentNode[currentPart] then
                local _, segmentType, data = parse(currentPart)
                if segmentType == "static" then
                    nextNode = currentNode[currentPart]
                    foundMatch = true
                    local handlers, params = traverse(nextNode, partIdx + 1)
                    if handlers then return handlers, params end
                    -- If static path didn't lead to a full match, backtrack and try other options
                    foundMatch = false
                end
            end

            -- 2. Dynamic/Wildcard Match
            if not foundMatch then
                for stored_path, childNode in pairs(currentNode) do
                    -- Skip the static path we might have already checked
                    if stored_path == currentPart then goto continue end
                    local original_key, segmentType, data, label = parse(stored_path)
                    if segmentType == "dynamic" then
                        local isValid = false
                        if data and data.pattern then
                            if string.match(currentPart, data.pattern) then
                                isValid = true
                            end
                        else
                            isValid = true
                        end
                        if isValid then
                            table.insert(accValues, currentPart)
                            nextNode = childNode
                            foundMatch = true
                            local handlers, params = traverse(nextNode, partIdx + 1)
                            if handlers then return handlers, params end
                            -- Backtrack if this dynamic path didn't lead to a match
                            table.remove(accValues)
                            foundMatch = false -- Reset to potentially try other dynamic nodes
                        end
                    elseif segmentType == "wildcard" then
                        local remainingValue = table.concat(parts, "/", partIdx)
                        table.insert(accValues, remainingValue) -- Add the single wildcard value
                        -- Wildcard consumes everything, check method directly on child node
                        if childNode[method] then
                            local handlerNode = childNode[method]
                            local params = {}
                            local expectedKeys = handlerNode.possibleKeys or {} -- Should contain the wildcard name
                            for i, key in ipairs(expectedKeys) do
                                params[key] = accValues[i]
                            end
                            return handlerNode.handlers, params
                        end
                        -- Backtrack if wildcard node didn't have the method
                        table.remove(accValues)
                        -- No need to set foundMatch=false, wildcard is usually terminal for path matching part
                        -- We just didn't find the right method.
                    end
                    ::continue::
                end
            end

            -- 3. Check for optional segments that can be skipped (new code)
            for stored_path, childNode in pairs(currentNode) do
                local original_key, segmentType, data = parse(stored_path)
                if data and data.optionnal then
                    local pushedParam = false
                    if segmentType == "dynamic" then
                        table.insert(accValues, nil) -- Push nil for skipped optional
                        pushedParam = true
                    end
                    -- Proceed to child node without incrementing partIdx
                    local handlers, params = traverse(childNode, partIdx)
                    if handlers then
                        return handlers, params
                    end
                    -- Backtrack if no match
                    if pushedParam then
                        table.remove(accValues)
                    end
                end
            end

            return nil, nil
        end
    end
    -- Start the traversal
    return traverse(node, 1)
end

local trie = Trie.new()

local routes = {
    GET = {
        -- "/users/new",
        -- "/users/:id",
        -- "/items/:id{%d+}",
        -- "/items/:slug{%a+}",
        -- "/products/:category?",
        -- "/articles/:page?{%d+}",
        -- "/search/:query?/results",
        -- "/config/:type?/:key?",
        -- "/files/*",
        "/",
        -- "/data",
        -- "/data/:key",
        -- "/lookup/:id",
        -- "/middleware"
    },
    POST = {
        -- "/api/v1/:resource/:id{%d+}/:action?"
    },
}

local requested_routes = {
    GET = {
        -- "/users/new",
        -- "/users/123",
        -- "/items/456",
        -- "/items/my-item",
        -- "/items/invalid",      --Should not match any pattern
        -- "/items/Invalid-Item", -- Should not match any pattern
        -- "/products/electronics",
        -- "/products",
        -- "/products/",
        -- "/articles/5",
        -- "/articles",
        -- "/articles/abc", -- Should not match pattern
        -- "/search/lua-trie/results",
        -- "/search/results",
        -- "/config/user/theme",
        -- "/config/user",
        -- "/config",
        -- "/files/css/style.css",
        -- "/files/index.html",
        -- "/files/",
        -- "/files",
        "/",
        -- "/data",
        -- "/data/with%20space",
        -- "/lookup/a%2Fb",
        -- "/middleware"
    },
    POST = {
        -- "/api/v1/posts/123/publish",
        -- "/api/v1/users/456",
        -- "/api/v1/tags/abc",             -- Should not match id pattern
        -- "/api/v1/posts/123",            --Method mismatch (will be tested on your side)
        -- "/api/v1/posts/123/publish/now" --Too many segments
    }
}


local results = {
    POST = {},
    GET = {}
}
for method, paths in pairs(routes) do
    for i, path in ipairs(paths) do
        trie:insert(method, path, function() return "FN " .. i end)
    end
end



for method, paths in pairs(requested_routes) do
    for i, path in ipairs(paths) do
        local handlers, params = trie:search(method, path)
        table.insert(results[method], {
            path = path,
            result = {
                handlerResult = (handlers and handlers[1]()) or "NOT-FOUND",
                params = params
            }
        })
    end
end

local structure = trie()
print(inspect(structure))
