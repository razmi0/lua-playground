--- A Trie (prefix tree) based router implementation for handling HTTP-like routes.
-- Supports static paths, dynamic optional segments and patterns validation (lua patterns),
-- wildcards (*), and middleware attachment.

---@alias Method "GET" | "ALL" | "POST" | "USE" | "PATCH" | "HEAD" | "PUT"
---@alias Path string
---@alias Handler fun(): any
---@alias Middleware fun():any
---@alias MatchResult Handler[] | Middleware[]

---@class Trie
---@field insert fun(self : Trie, method : Method, path : Path, ... : Handler)
---@field search fun(self : Trie, method : Method, path : Path)

local inspect = require("inspect")
local parse = require("utils.parse-path")
local split = require("utils.split-path")
local plainCopy = require("utils.plain-copy")
local definitions = require("router-definitions")



local score = 0
local mws = {}
local hds = {}
local isMwPopulated = false

local Trie = {}
Trie.__index = Trie

local function newNode()
    return {
        static   = {},  -- map<string, node>
        dynamic  = {},  -- list of { node = <node>, pattern = <regex?> }
        wildcard = nil, -- { node = <node>, name = <string> } or nil
        handlers = {},  -- map<method, handlerRecord>
    }
end

local function getScore()
    score = score + 1
    return score
end

local function compare(mw, handler)
    local mwParts = split(mw.path)
    local hdlParts = split(handler.path)

    if mw.method ~= "USE" then
        if mw.method ~= handler.method then
            return false
        end
    end

    for i = 1, #mwParts, 1 do
        if mwParts[i] == "*" then
            goto continue
        end
        if not hdlParts[i] then
            return false
        end
        -- can be optionnal and share all except last char"?"

        if mwParts[i] ~= hdlParts[i] then
            return false
        end
        ::continue::
    end
    return true
end

local function cleanup(obj)
    local isNode = function(x)
        return
            type(x) ~= "number" and
            type(x) ~= "string" and
            type(x) ~= "boolean" and
            type(x) ~= "function" and
            next(x) ~= "string"
    end
    function Traverse(node)
        for key, value in pairs(node) do
            if type(node[key]) == "table" then
                if next(value) == nil then
                    node[key] = nil
                elseif isNode(node[key]) then
                    Traverse(node[key])
                end
            end
        end
    end

    Traverse(obj)
end

local function expandOptionals(parts, i, acc, out, skippedOptional)
    if i > #parts then
        table.insert(out, plainCopy(acc))
        return
    end

    local p = parts[i]
    local isOptional = p:match("?")

    if isOptional then
        local base = string.gsub(p, "?", "")
        if not skippedOptional then
            -- include optional
            table.insert(acc, base)
            expandOptionals(parts, i + 1, acc, out, false)
            table.remove(acc)
        end
        -- skip optional
        expandOptionals(parts, i + 1, acc, out, true)
    else
        table.insert(acc, p)
        expandOptionals(parts, i + 1, acc, out, skippedOptional)
        table.remove(acc)
    end
end

--- Trie Router
---@contructor
---@return Trie
function Trie.new()
    score = 0
    mws = {}
    hds = {}
    isMwPopulated = false
    return setmetatable({
        root = newNode(),
    }, Trie)
end

function Trie:insert(method, path, ...)
    local handlers = { ... }

    if not definitions.methods.ALL_AVAILABLE_METHODS:has(method) then
        return
    end

    if method == definitions.methods.ALL_METHOD then
        for _, m in ipairs(definitions.methods.ALL_AVAILABLE_METHODS:entries()) do
            self:insert(m, path, handlers)
        end
        return
    end

    if method == definitions.methods.MW_METHOD_METHOD then
        local s = getScore()
        mws[s] = { path = path, middlewares = handlers, method = definitions.methods.MW_METHOD, score = s }
        return self
    end

    -- 1. split + expand optionals into concrete paths
    local baseParts = split(path)
    local expanded = {}
    expandOptionals(baseParts, 1, {}, expanded)

    -- 2. for each concrete variant, walk/attach into the trie
    for _, parts in ipairs(expanded) do
        local node = self.root or newNode()
        self.root = node
        local paramNames = {}
        for idx, part in ipairs(parts) do
            local seg, typ, data, label = parse(part)
            if typ == "static" then
                node.static[seg] = node.static[seg] or newNode()
                node = node.static[seg]
            elseif typ == "dynamic" then
                local child = newNode()
                table.insert(node.dynamic, {
                    node       = child,
                    pattern    = data.pattern,
                    branchSize = #parts - idx,
                })
                node = child
                table.insert(paramNames, label)
            elseif typ == "wildcard" then
                local child = newNode()
                node.wildcard = { node = child, name = label }
                node = child
                table.insert(paramNames, label)
            else
                error("unknown segment type: " .. tostring(typ))
            end
        end

        -- 3. register handlers at the leaf
        local rec = node[method]
        if not rec then
            local s = getScore()
            if parts[#parts] == "*" then
                mws[s] = { path = path, middlewares = handlers, method = method, score = s }
            end
            rec = {
                handlers     = handlers,
                score        = s,
                possibleKeys = paramNames,
                path         = table.concat(parts, "/"),
                method       = method
            }
            node[method] = rec
            hds[s] = rec
        else
            -- append if already exists
            for _, h in ipairs(handlers) do
                table.insert(rec.handlers, h)
            end
        end
    end

    return self
end

function Trie:attachMiddlewares()
    -- prevent mw insertion duplication
    for _, mwNode in pairs(mws) do
        mwNode.middlewares = plainCopy(mwNode.middlewares)
    end

    for scored_indexed, mwNode in pairs(mws) do
        -- minimum score to receive a middleware
        local i = scored_indexed
        while true do
            i = i + 1
            -- potential target
            local handlerNode = hds[i]
            local continue = mws[i]
            -- score handlers and score middleware make a linear (1,2, n .. n + 1) together
            -- if no handlerset AND no mw stored, gap in the linear sequence => all exploration of callbacks done
            local stop = not handlerNode and not continue
            if stop then break end

            -- everything is available
            if handlerNode then
                local isCompatible = compare(mwNode, handlerNode)
                if isCompatible then
                    local middlewares = mwNode.middlewares
                    local handlers = handlerNode.handlers
                    local handlerFn = handlers[#handlers]
                    handlers[#handlers] = nil -- remove last

                    for _, mw in ipairs(middlewares) do
                        table.insert(handlers, mw)
                    end

                    table.insert(handlers, handlerFn)
                end
            end
        end
    end
    cleanup(self.root)
    mws = nil
    hds = nil
end

function Trie:search(method, path)
    if not isMwPopulated then
        self:attachMiddlewares()
        isMwPopulated = true
    end
    local parts = split(path)
    local node  = self.root
    if not node then
        return nil, nil
    end

    local values = {} -- capture dynamic & wildcard values in order
    local i, n   = 1, #parts

    while i <= n do
        local part = parts[i]

        -- 1) try static
        if node.static and node.static[part] then
            node = node.static[part]
            i = i + 1
        else
            local matched = false

            -- 2) try each dynamic child
            if node.dynamic then
                local remain = n - i -- how many segments we still have
                local bestDyn        -- we'll pick the dyn needing the most segments
                for _, dyn in ipairs(node.dynamic) do
                    if remain >= (dyn.branchSize or 0)
                        and (not dyn.pattern or part:match(dyn.pattern))
                    then
                        if not bestDyn
                            or (dyn.branchSize or 0) > (bestDyn.branchSize or 0)
                        then
                            bestDyn = dyn
                        end
                    end
                end
                if bestDyn then
                    table.insert(values, part)
                    node    = bestDyn.node
                    matched = true
                end
            end

            if matched then
                i = i + 1
            else
                -- 3) wildcard?
                if node.wildcard then
                    local rem = table.concat(parts, "/", i, n)
                    table.insert(values, rem)
                    node = node.wildcard.node
                    i = n + 1
                else
                    -- no route at all
                    return nil, nil
                end
            end
        end
    end

    -- 4) end of path:
    local rec = node[method]
    if not rec then
        return nil, nil
    end

    -- 5) build params map from the ordered keys
    local params = {}
    for idx, key in ipairs(rec.possibleKeys or {}) do
        params[key] = values[idx]
    end

    return rec.handlers, params
end

-- debugging purpose
---@private
function Trie:__call()
    return self.root
end

return Trie
