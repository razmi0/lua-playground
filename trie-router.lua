--- A Trie (prefix tree) based router implementation for handling HTTP-like routes.
-- Supports static paths, dynamic segments with optional patterns (:param),
-- optional segments (:param?), wildcards (*), and middleware attachment.

---@alias Method "GET" | "ALL" | "POST" | "USE" | "PATCH" | "HEAD" | "PUT"
---@alias Path string
---@alias Handler fun(): any
---@alias Middleware fun():any
---@alias MatchResult Handler[] | Middleware[]

---@class Trie
---@field value table
---@field score number
---@field mwSet table
---@field hdlSet table
---@field isMwPopulated boolean
---@field new fun(self : Trie): self
---@field insert fun(self : Trie, method : Method, path : Path, handlers : Handler[]): self
---@field search fun(self : Trie, method : Method, path : Path)

local inspect = require("inspect")
local parse = require("utils.parse-path")
local PATTERN_GROUPS = require("utils.patterns")
local split = require("utils.split-path")

local score = 0
local mws = {}
local hds = {}
local isMwPopulated = false

local Trie = {}
Trie.__index = Trie

local function newNode()
    return {
        static   = {},  -- map<string, node>
        dynamic  = {},  -- list of { node = <node>, name = <string>, pattern = <regex?> }
        wildcard = nil, -- { node = <node>, name = <string> } or nil
        handlers = {},  -- map<method, handlerRecord>
    }
end


--- Trie Router
---@contructor
---@return Trie
function Trie.new()
    return setmetatable({
        root = newNode(),
    }, Trie)
end

---@private
function Trie:__call()
    return self.root
end

local getScore = function()
    score = score + 1
    return score
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

function DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[DeepCopy(orig_key)] = DeepCopy(orig_value)
        end
        setmetatable(copy, DeepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Recursively expand any “optional” part into two paths:
local function expandOptionals(parts, i, acc, out)
    if i > #parts then
        table.insert(out, DeepCopy(acc))
        return
    end

    local p = parts[i]
    if p:match("?") then
        -- strip the “?” and recurse both with and without
        local base = string.gsub(p, "?", "")
        -- without
        expandOptionals(parts, i + 1, acc, out)
        -- with
        table.insert(acc, base)
        expandOptionals(parts, i + 1, acc, out)
        table.remove(acc)
    else
        table.insert(acc, p)
        expandOptionals(parts, i + 1, acc, out)
        table.remove(acc)
    end
end

function Trie:insert(method, raw_path, ...)
    local handlers = { ... }
    if method == "USE" then
        mws[getScore()] = { path = raw_path, middlewares = handlers }
        return self
    end

    -- 1. split + expand optionals into concrete paths
    local baseParts = split(raw_path)
    local expanded = {}
    expandOptionals(baseParts, 1, {}, expanded)



    -- 2. for each concrete variant, walk/attach into the trie
    for _, parts in ipairs(expanded) do
        local node = self.root or newNode()
        self.root = node
        local paramNames = {}
        for _, part in ipairs(parts) do
            local seg, typ, data, label = parse(part)
            -- print(inspect(node))
            if typ == "static" then
                node.static[seg] = node.static[seg] or newNode()
                node = node.static[seg]
            elseif typ == "dynamic" then
                -- store both the node and its name+pattern
                local child = newNode()
                table.insert(node.dynamic, {
                    node    = child,
                    name    = label,
                    pattern = data.pattern
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
            rec = {
                handlers     = handlers,
                score        = s,
                possibleKeys = paramNames,
                path         = raw_path,
                method       = method
            }
            node[method] = rec
            hds[s] = rec
        else
            -- prepend if already exists
            for _, h in ipairs(handlers) do
                table.insert(rec.handlers, 1, h)
            end
        end
    end

    -- cleanup(self.root)
    return self
end

function Trie:attachMiddlewares()
    -- mw are added if :
    -- the path match (with dynamic, pattern and wildcard but not optionnal)
    -- the score of the concrete route > score of mw
    print("-----mws")
    print(inspect(mws))
    print("-----hds")
    print(inspect(hds))
    for scored_indexed, mwNode in pairs(mws) do
        -- minimum score to receive a middleware
        print("studiying the mw number : " .. tostring(scored_indexed))
        local i = scored_indexed
        while true do
            i = i + 1
            -- potential target
            local handlerNode = hds[i]
            local continue = mws[i]
            print("handlerNode is : " .. tostring(handlerNode))
            print("continue is : " .. tostring(continue))
            -- score handlers and score middleware make a linear (1,2, n .. n + 1) together
            -- if no handlerset AND no mw stored, gap in the linear sequence => all exploration of callbacks done
            local stop = not handlerNode and not continue
            print(stop)
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
    mws = nil
    hds = nil
end

function Trie:search(method, path)
    if not isMwPopulated then
        self:attachMiddlewares()
    end
    isMwPopulated = true
    local parts   = split(path)
    local node    = self.root
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
                for _, dyn in ipairs(node.dynamic) do
                    -- if no pattern or pattern matches
                    if (not dyn.pattern) or part:match(dyn.pattern) then
                        table.insert(values, part)
                        node = dyn.node
                        matched = true
                        break
                    end
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

    return rec.handlers[1], params
end

local routes = {
    USE = {
        "/static/*",
    },
    GET = {
        -- "/users/:new{%a+}",
        -- "/items/:id{%d+}",
        -- "/items/:slug",
        -- "/products/:category?",
        -- "/articles/:page?{%d+}",
        -- "/search/:query?/results",
        -- "/config/:type?/:key?",
        -- "/files/*",
        -- "/",
        -- "/data",
        -- "/data/:key",
        -- "/lookup/:id",
        -- "/static/:path",
        -- "/static/:path/*",
        "/static/path"
    },
}

local requested_routes = {
    GET = {
        -- "/users/popo",
        -- "/users/123",
        -- "/items/456",
        -- "/items/my-item",
        -- "/items/invalid",
        -- "/items/Invalid-Item",
        -- "/products/electronics",
        -- "/products",
        -- "/products/",
        -- "/articles/5",
        -- "/articles",
        -- "/articles/abc",
        -- "/search/lua-trie/results",
        -- "/search/results",
        -- "/config/user/theme",
        -- "/config/user",
        -- "/config",
        -- "/files/css/style.css",
        -- "/files/index.html",
        -- "/files/",
        -- "/files",
        -- "/",
        -- "/data",
        -- "/data/with%20space",
        -- "/lookup/a%2Fb",
        "/static/path",

    },
    POST = {
        -- "/api/v1/posts/123/publish",
        -- "/api/v1/users/456",
        -- "/api/v1/tags/abc",
        -- "/api/v1/posts/123",
        -- "/api/v1/posts/123/publish/now"
    }
}

local trie = Trie.new()
-- for method, paths in pairs(routes) do
--     for i, path in ipairs(paths) do
--         trie:insert(method, path, { function() return "FN " .. i end })
--     end
-- end

trie:insert("USE", "/x/*", { function() return "MW " .. "1" end })
trie:insert("GET", "/x/path", { function() return "FN " .. "2" end })
-- print(inspect(trie()))
trie:insert("GET", "/x/path/to", { function() return "FN " .. "2" end })
-- trie:insert("GET", "/static/path/to/yes", { function() return "FN " .. "2" end })

local results = {}
for method, paths in pairs(requested_routes) do
    for i, path in ipairs(paths) do
        local handlers, params = trie:search(method, path)
        local hres = {}
        if handlers then
            for j, h in ipairs(handlers) do
                table.insert(hres, h())
            end
        end
        local r = (next(hres) ~= nil and hres) or "NOT-FOUND"
        table.insert(results, {
            path = path,
            result = {
                handlerResult = r,
                params = params
            }
        })
    end
end

print("---handlers")
print(inspect(#results[1].result.handlerResult))
