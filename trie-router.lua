-- Trie-based router for HTTP-like routes supporting static, dynamic, wildcard segments,
-- optional segments expansion, Lua pattern validation, and middleware attachment.
-- @module router

---@alias StdMethod  "GET"|"POST"|"PUT"|"PATCH"|"HEAD"|"OPTIONS"|"USE"|"ALL"
---@alias Method StdMethod|string
---@alias Path string
---@alias Handler fun(...):any
---@alias Middleware fun(...):any
---@alias MatchResult Handler[]|Middleware[]

---Router Trie class
---@class Trie
---@field root table internal trie root node
local Trie                             = {}
Trie.__index                           = Trie
Trie.__name                            = "Trie"
local parse                            = require("utils.parse-path")
local split                            = require("utils.split-path")
local plainCopy                        = require("utils.plain-copy")
local prune                            = require("utils.prune")
local isCompatible                     = require("utils.compare-middleware")
local expand                           = require("utils.expand-optional")
local findBest                         = require("utils.specificity")
local MW_METHOD                        = "USE"
local MESSAGE_MATCHER_IS_ALREADY_BUILT = "Can not add a route since the matcher is already built"
local order                            = 0
local mws                              = {}
local hds                              = {}
local isMwPopulated                    = false
local function newNode()
    return { static = {}, dynamic = {}, wildcard = nil, handlers = {} }
end
local function nextOrder()
    order = order + 1
    return order
end

---Creates a new Trie router instance.
---@return Trie self
function Trie.new()
    order, mws, hds, isMwPopulated = 0, {}, {}, false
    return setmetatable({ root = newNode() }, Trie)
end

---Inserts a route handler or middleware into the trie.
---@param method Method HTTP or middleware method identifier
---@param path Path route pattern (supports optional `?`, wildcards `*`, dynamic `:param`)
---@param ... Handler|Middleware functions
---@return Trie self
function Trie:insert(method, path, ...)
    if isMwPopulated then
        error(MESSAGE_MATCHER_IS_ALREADY_BUILT)
        return self
    end

    local fns = { ... }
    if method == MW_METHOD then
        local score = nextOrder()
        mws[order] = {
            path = path,
            middlewares = { ... },
            method = MW_METHOD,
            score = score
        }
        return self
    end
    local variants = {}
    expand(split(path), 1, {}, variants, false)
    for _, parts in ipairs(variants) do
        local node, keys = self.root, {}
        for i, part in ipairs(parts) do
            local seg, typ, data, label = parse(part)

            -- 1) static
            if typ == "static" then
                node.static[seg] = node.static[seg] or newNode()
                node = node.static[seg]
            end

            -- 2) dynamic
            if typ == "dynamic" then
                local child = newNode()
                node.dynamic[#node.dynamic + 1] = {
                    node = child,
                    pattern = data.pattern,
                    score = #parts - i
                }
                node = child
                keys[#keys + 1] = label
            end

            -- 3) wildcard
            if typ == "wildcard" then
                local child = newNode()
                node.wildcard = { node = child, name = label }
                node = child
                keys[#keys + 1] = label
            end
        end

        local rec = node[method]
        if not rec then
            local s = nextOrder()
            rec = {
                handlers = fns,
                order = s,
                possibleKeys = keys,
                path = table.concat(parts, "/"),
                method = method
            }
            node[method] = rec
            hds[s] = rec
            if parts[#parts] == "*" then
                mws[s] = { path = path, middlewares = fns, method = method, order = s } -- add to mw candidate
            end
        else
            for _, fn in ipairs(fns) do
                rec.handlers[#rec.handlers + 1] = fn
            end
        end
    end

    return self
end

function Trie:clean()
    prune(self.root)
    mws, hds = nil, nil
    isMwPopulated = true
end

function Trie:attachMiddlewares()
    -- prevent mw insertion duplication
    for _, mwNode in pairs(mws) do mwNode.middlewares = plainCopy(mwNode.middlewares) end
    for i, mw in pairs(mws) do
        while true do
            i = i + 1
            local hd, nextMw = hds[i], mws[i]
            if not hd and not nextMw then break end
            -- ordered handlers and ordered mw make a linear (1,2, n .. n + 1) together
            -- if no handler AND no mw stored => gap in the linear sequence => all exploration of callbacks done
            if hd and isCompatible(mw, hd) then
                local list, handlers = mw.middlewares, hd.handlers
                local last = handlers[#handlers]
                handlers[#handlers] = nil -- remove last
                for _, m in ipairs(list) do handlers[#handlers + 1] = m end
                handlers[#handlers + 1] = last
            end
        end
    end
end

---Searches for handlers matching a given method and path.
---@param method Method HTTP method to match
---@param path Path to search
---@return MatchResult?, table? list of handlers and extracted params or nil
function Trie:search(method, path)
    if not isMwPopulated then
        self:attachMiddlewares() -- one shot last compilation step
        self:clean()             -- one shot optional cleanup
    end

    local node, parts, values, i = self.root, split(path), {}, 1
    if not node then return end

    while i <= #parts do
        local part = parts[i]
        local matched = false
        local function nextStep() i, matched = i + 1, true end

        -- 1) static
        if node.static and node.static[part] then
            node = node.static[part]
            nextStep()
        end

        -- 2) dynamic
        if not matched then
            local remain = #parts - i
            local best = findBest(node.dynamic, part, remain)
            if best then
                values[#values + 1] = part
                node = best
                nextStep()
            end
        end

        -- 3) wildcard
        if not matched then
            if node.wildcard then
                values[#values + 1] = table.concat(parts, "/", i, #parts)
                node = node.wildcard.node
                break
            end
        end

        if not matched then return end
    end

    -- end of path:
    local rec = node[method]
    if not rec then return end

    -- build params map from the ordered keys
    local params = {}
    for j, key in ipairs(rec.possibleKeys or {}) do
        params[key] = values[j]
    end

    return rec.handlers, params
end

-- debugging purpose
---@private
function Trie:__call()
    return self.root
end

return Trie
