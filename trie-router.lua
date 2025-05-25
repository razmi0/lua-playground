---@class Trie
---@field private root table
---@field order integer
---@field new fun(): Trie
---@field insert fun(self: Trie, method: HTTPMethod, path: string, ...: fun(...: any): any)
---@field search fun(self: Trie, method: HTTPMethod, path: string): TrieLeaf[], table<string, string>

---@class TrieNode
---@field mws TrieLeaf[]
---@field static table<string, TrieNode>
---@field dynamic TrieDynamicNode[]
---@field leaf? TrieLeaf[]

---@class TrieDynamicNode
---@field node TrieNode
---@field pattern? string
---@field score? integer

---@class TrieLeaf
---@field handlers fun()[]
---@field method HTTPMethod
---@field order integer
---@field possibleKeys string[]
---@field params table<string, string>?

local parse  = require("utils.parse-path")
local split  = require("utils.split-path")
local expand = require("utils.expand-optional")
local sort   = require("utils.sort")
local clone  = require("utils.clone")


---@param nodes TrieDynamicNode[]
---@param ... fun(node: TrieDynamicNode, best: TrieDynamicNode?): boolean
---@return TrieNode
local function findBest(nodes, ...)
    local validators = { ... }
    local best
    for _, d in ipairs(nodes or {}) do
        local valid = true
        for _, fn in ipairs(validators) do
            if not fn(d, best) then
                valid = false
                break
            end
        end
        if valid then
            best = d
        end
    end
    return best and best.node
end

---@return TrieNode
local function newNode()
    return {
        mws = {},
        static = {},
        dynamic = {}
    }
end

---@param self Trie
---@return integer
local function nextOrder(self)
    self.order = self.order + 1
    return self.order
end

local Trie = {}
Trie.__index = Trie

---@return TrieNode
function Trie.new()
    return setmetatable({
        root = newNode(),
        order = 0
    }, Trie)
end

---@param method HTTPMethod
---@param path string
---@param ... fun(...: any): any
function Trie:insert(method, path, ...)
    local fns = { ... }
    local variants = {}
    expand(split(path), 1, {}, variants, false)

    for _, parts in ipairs(variants) do
        local node, keys = self.root, {}
        for i, part in ipairs(parts) do
            local isLast = i == #parts
            local seg, typ, data, label = parse(part)

            if typ == "static" then
                node.static[seg] = node.static[seg] or newNode()
                node = node.static[seg]
            end

            if typ == "dynamic" or (typ == "wildcard" and not isLast) then
                local child = newNode()
                node.dynamic[#node.dynamic + 1] = {
                    node = child,
                    pattern = data.pattern,
                    score = #parts - i
                }
                node = child
                keys[#keys + 1] = (label or "*")
            end

            if typ == "wildcard" and isLast then
                keys[#keys + 1] = (label or "*")
                node.mws[#node.mws + 1] = {
                    handlers = clone(fns),
                    order = nextOrder(self),
                    method = method,
                    possibleKeys = keys
                }
                return
            end
        end

        local rec = node.leaf or {}
        rec[#rec + 1] = {
            handlers = clone(fns),
            order = nextOrder(self),
            method = method,
            possibleKeys = keys
        }
        node.leaf = rec
    end
end

---@param method HTTPMethod
---@param path string
---@return TrieLeaf[] results,  table<string, string>| {} params
function Trie:search(method, path)
    local node, parts, values, i, matched, queue = self.root, split(path), {}, 1, false, {}

    local methodCheck = function(mw)
        return mw.method == "USE" or method == mw.method or mw.method == "ALL"
    end

    while i <= #parts do
        local part, matching = parts[i], function() i, matched = i + 1, true end
        matched = false

        -- mws collection
        for _, mw in ipairs(node.mws) do
            if methodCheck(mw) then queue[#queue + 1] = mw end
        end

        -- if static (O1) else dynamic (0n)
        if node.static[part] then
            node = node.static[part]
            matching()
        else
            local remain = #parts - i
            local best = findBest(
                node.dynamic,
                -- pattern validation
                function(nd) return not nd.pattern or part:match(nd.pattern) end,
                -- enough segments left to match its branch
                function(nd) return remain >= (nd.score or 0) end,
                -- longer branch = more specific = better
                function(nd, best) return not best or (nd.score or 0) > (best.score or 0) end
            )
            if best then
                values[#values + 1] = part
                node = best
                matching()
            end
        end

        -- check for trailing wildcard middleware
        if not matched then
            for _, mw in ipairs(node.mws) do
                if methodCheck(mw) then
                    local key = mw.possibleKeys[#mw.possibleKeys]
                    if key == "*" then
                        local remaining = table.concat(parts, "/", i)
                        local params = {}
                        for j, k in ipairs(mw.possibleKeys) do
                            if k == "*" then
                                params[k] = remaining
                            else
                                params[k] = values[j]
                            end
                        end
                        mw.params = params
                        queue[#queue + 1] = mw
                        break
                    end
                end
            end
        end
        if not matched then break end
    end

    -- leaf mws collection
    if matched and node.leaf then
        for _, mw in ipairs(node.leaf) do
            if methodCheck(mw) then
                local params = {}
                for j, key in ipairs(mw.possibleKeys) do
                    params[key] = values[j]
                end
                mw.params = params
                queue[#queue + 1] = mw
            end
        end
    end

    -- sort by order
    local sorted = sort(queue, function(a, b)
        return a.order > b.order
    end)

    return sorted, sorted[#sorted] and sorted[#sorted].params or {}
end

return Trie
