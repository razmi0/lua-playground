local Trie = require("trie-router")
local inspect = require("inspect")
local trie = Trie.new()




local routes = {
    { method = "GET", path = "*",                handler = function() return "wildcard" end },
    { method = "GET", path = "/",                handler = function() return "Racine" end },
    { method = "GET", path = "/data",            handler = function() return "Données" end },
    { method = "GET", path = "/info",            handler = function() return "Informations" end },

    { method = "GET", path = "/users/:new{%a+}", handler = function(params) return "Utilisateur: " .. params.new end },
    { method = "GET", path = "/items/:id{%d+}",  handler = function(params) return "Item ID: " .. params.id end },
    {
        method = "GET",
        path = "/products/:category?",
        handler = function(params)
            if not next(params) then return "Tous les produits" end
            return "Catégorie: " ..
                params.category
        end
    },

    {
        method = "GET",
        path = "/articles/:page?{%d+}",
        handler = function(params)
            if not next(params) then
                return "Première page des articles"
            end
            return "Page: " .. params.page
        end
    },
    {
        method = "GET",
        path = "/search/:query?/results",
        handler = function(params)
            if not next(params) then
                return "Résultats de la recherche"
            end
            return "Recherche: " ..
                params.query .. ", Résultats"
        end
    },
    {
        method = "GET",
        path = "/config/:type?/:key?",
        handler = function(params)
            if not next(params) then
                return "Pas de config"
            end
            return "Config " .. (params.type or "no-type") .. " and " .. (params.key or "no-key")
        end
    }, {

    method = "GET",
    path = "/tables/:type?/row/:col?",
    handler = function(params)
        if not next(params) then
            return "Pas de tables"
        end
        return "Tables " .. (params.type or "no-type") .. " and " .. (params.col or "no-col")
    end
}

}

local requested_routes = {
    { method = "GET", path = "/",            expectedResult = "Racine" },
    { method = "GET", path = "/yooo",        expectedResult = "wilcard" },
    { method = "GET", path = "/data",        expectedResult = "Données" },
    { method = "GET", path = "/info",        expectedResult = "Informations" },

    { method = "GET", path = "/users/alice", expectedResult = "Utilisateur: alice" },
    { method = "GET", path = "/items/123",   expectedResult = "Item ID: 123" },
    {
        method = "GET",
        path = "/products/laptop",
        expectedResult = "Catégorie: laptop"
    },

    { method = "GET", path = "/articles/5",         expectedResult = "Page: 5" },
    {
        method = "GET",
        path = "/search/lua/results",
        expectedResult = "Recherche: lua, Résultats"
    },

    { method = "GET", path = "/products",           expectedResult = "Tous les produits" },
    { method = "GET", path = "/articles",           expectedResult = "Première page des articles" },
    { method = "GET", path = "/search/results",     expectedResult = "Résultats de la recherche" },

    { method = "GET", path = "/config",             expectedResult = "Pas de config" },
    { method = "GET", path = "/config/user",        expectedResult = "Config user and no-key" },
    { method = "GET", path = "/config/user/item",   expectedResult = "Config user and item" },
    { method = "GET", path = "/tables/users/row/2", expectedResult = "Tables users and 2" },
    { method = "GET", path = "/tables/users/row",   expectedResult = "Tables users and no-col" },

}



-- trie:insert("USE", "*", function() return "USE" .. " : " .. "1" end)

for _, route in ipairs(routes) do
    trie:insert(route.method, route.path, route.handler)
end

-- print(inspect(trie()))

local results = {
    success = {},
    failed = {}

}
for _, route in ipairs(requested_routes) do
    local handlers, params = trie:search(route.method, route.path)

    local actualResult = nil
    if handlers then
        actualResult = handlers(params)
    end

    local success = (actualResult == route.expectedResult)
    table.insert(results[((success and "success") or "failed")], {
        path = route.path or "nil",
        expected = route.expectedResult or "nil",
        actual = actualResult or "nil",
    })
end

print(inspect(results))
-- print(inspect(trie()))
-- /config/:1/:2 : /config/user => not found
