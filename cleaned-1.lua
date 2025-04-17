local a = require("inspect")
local b = require("utils.parse-path")
local c = require("utils.split-path")
local d = {}
d.__index = d; local function e(f, g)
    local h = c(f)
    local i = c(g)
    local j = function(k)
        local l, m, n, o = string.match(k, "^(:?)([%w%-%_*]+)(%??){?(.-)}?$")
        return (l or "") .. (m or "") .. (o or "")
    end; for p = 1, #h do
        if not i[p] then return false end; local q = j(i[p])
        local r = j(h[p])
        if r == "*" then goto s end; if r ~= q then return false end
        ::s::
    end; return true
end; function d.new() return setmetatable({ value = {}, score = 0, mwSet = {}, hdlSet = {} }, d) end; function d:__call() return
    self.value, self.mwSet, self.hdlSet end; function d:getScore()
    self.score = self.score + 1; return self.score
end; function d:insert(t, u, v)
    if t == "USE" then
        self.mwSet[self:getScore()] = { path = u, middlewares = v }
        return self
    end; local w = c(u)
    local x = self.value; if not x then
        self.value = {}
        x = self.value
    end; local y = {}
    for p, z in ipairs(w) do
        local A, B, C = b(z)
        if not x[A] then x[A] = {} end; if C then
            if B == "dynamic" then
                table.insert(y, A)
                x[A].pattern = C.pattern
            end; if not x[A].optionnal then x[A].optionnal = C.optionnal end
        end; x = x[A]
        if p == #w then if not x[t] then
                local D = self:getScore()
                local E = { handlers = v, score = D, possibleKeys = y, path = u, method = t }
                x[t] = E; self.hdlSet[D] = E
            else for F = #v, 1, -1 do table.insert(x[t].handlers, 1, v[F]) end end end
    end; return self
end; function d:attachMiddlewares() for G, H in pairs(self.mwSet) do
        local I = G; while true do
            I = I + 1; local J = self.hdlSet[I]
            local K = self.mwSet[I]
            if not J and not K then break end; if J then
                local L = e(H.path, J.path)
                if L then
                    local M = H.middlewares; local N = J.handlers; for p = #M, 1, -1 do table.insert(N, 1, M[p]) end
                end
            end
        end
    end end; function d:search(t, u)
    print("Search function not implemented.")
    return nil, nil
end; local O = function() print("im 2") end; local P = d.new()
P:insert("USE", "/order/id?/*",
    { function() print("MIDDLEWARE 1 (for /order/id?/*)") end, function() print("MIDDLEWARE 2 (for /order/id?/*)") end })
P:insert("GET", "/order/id?/:where",
    { function() print("GET ROUTE /order/id?/:where 1") end, function() print("GET ROUTE /order/id?/:where 2") end })
P:insert("GET", "/order/name/name/me/you", { O })
P:insert("USE", "/order", { function() print("MIDDLEWARE 3 (for /order)") end })
P:insert("GET", "/order/id/details", { function() print("GET ROUTE /order/id/details") end })
P:attachMiddlewares()
local Q, R, S = P()
print("--- Final Trie Structure ---")
print(a(Q))
print("\n--- Middleware Set (after attachment attempt, may be empty if cleared) ---")
print(a(R))
print("\n--- Handler Set (references, check handlers within Trie structure) ---")
print(a(S))
