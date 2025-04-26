local Trie = require("trie-router")
local inspect = require("inspect")
local trie = Trie.new()

local baseTests = function(middlewares, from, to)
    local routes = {
        {
            route = { path = "*", handler = function() return "wildcard" end },
            requested = {
                { path = "/yooo", expectedResult = "wildcard" }
            }
        },
        {
            route = { path = "/", handler = function() return "Racine" end },
            requested = {
                { path = "/", expectedResult = "Racine" }
            }
        },
        {
            route = { path = "/data", handler = function() return "Données" end },
            requested = {
                { path = "/data", expectedResult = "Données" }
            }
        },
        {
            route = { path = "/info", handler = function() return "Informations" end },
            requested = {
                { path = "/info", expectedResult = "Informations" }
            }
        },
        {
            route = {
                path = "/users/:new{%a+}",
                handler = function(params)
                    return "Utilisateur: " ..
                        params.new
                end
            },
            requested = {
                {
                    path = "/users/alice", expectedResult = "Utilisateur: alice"
                }
            }
        },
        {
            route = {
                path = "/items/:id{%d+}", handler = function(params) return "Item ID: " .. params.id end
            },
            requested = {
                { path = "/items/123", expectedResult = "Item ID: 123" }
            }
        },
        {
            route = {
                path = "/products/:category?",
                handler = function(params)
                    if not next(params) then return "Tous les produits" end
                    return "Catégorie: " ..
                        params.category
                end
            },
            requested = {
                {

                    path = "/products/laptop",
                    expectedResult = "Catégorie: laptop"
                },
                {

                    path = "/products",
                    expectedResult = "Tous les produits"
                }
            }
        },
        {
            route = {

                path = "/articles/:page?{%d+}",
                handler = function(params)
                    if not next(params) then
                        return "Première page des articles"
                    end
                    return "Page: " .. params.page
                end
            },
            requested = {
                { path = "/articles",   expectedResult = "Première page des articles" },
                { path = "/articles/5", expectedResult = "Page: 5" }
            }
        },
        {
            route = {

                path = "/search/:query?/results",
                handler = function(params)
                    if not next(params) then
                        return "Résultats de la recherche"
                    end
                    return "Recherche: " ..
                        params.query .. ", Résultats"
                end
            },
            requested = {
                { path = "/search/results", expectedResult = "Résultats de la recherche" },
                {

                    path = "/search/lua/results",
                    expectedResult = "Recherche: lua, Résultats"
                }
            }
        },
        {
            route = {

                path = "/config/:type?/:key?",
                handler = function(params)
                    if not next(params) then
                        return "Pas de config"
                    end
                    return "Config " .. (params.type or "no-type") .. " and " .. (params.key or "no-key")
                end
            },
            requested = {
                { path = "/config",           expectedResult = "Pas de config" },
                { path = "/config/user",      expectedResult = "Config user and no-key" },
                { path = "/config/user/item", expectedResult = "Config user and item" }
            }
        },
        {
            route = {

                path = "/tables/:type?/row/:col?",
                handler = function(params)
                    if not next(params) then
                        return "Pas de tables"
                    end
                    return "Tables " .. (params.type or "no-type") .. " and " .. (params.col or "no-col")
                end
            },
            requested = {
                { path = "/tables/users/row/2", expectedResult = "Tables users and 2" },
                { path = "/tables/users/row",   expectedResult = "Tables users and no-col" },
            }
        },


    }
    local method = "GET"
    from = from or 0
    to = to or #routes
    for score, route in ipairs(routes) do
        if score < from or score > to then goto continue end
        local registered_route = route.route
        if middlewares then
            for _, mw in ipairs(middlewares) do
                if mw.score == score then
                    trie:insert("USE", registered_route.path, registered_route.handler)
                end
            end
        end
        trie:insert(method, registered_route.path, registered_route.handler)
        ::continue::
    end



    local results = {
        success = {},
        failed = {}

    }

    for score, route in ipairs(routes) do
        local requested_routes = route.requested
        local registered_route = route.route

        if score < from or score > to then goto continue end
        for _, requested in ipairs(requested_routes) do
            local actualResult = {}
            local handlers, params = trie:search(method, requested.path)
            if handlers then
                for _, h in ipairs(handlers) do
                    table.insert(actualResult, h(params))
                end
            end
            local success = (actualResult[#actualResult] == requested.expectedResult)
            table.insert(results[((success and "success") or "failed")], {
                req_path = requested.path or nil,
                route = registered_route.path or nil,
                expected = requested.expectedResult or false,
                actual = actualResult or nil,
                mw_attached = #actualResult - 1,
            })
        end
        ::continue::
    end

    if next(results.failed) then
        print("[ERROR] : BASE TEST")
        print(inspect(results.failed))
    end
end


baseTests()
