local Tx = require("tests.tx")
local Router = require("router")

Tx.mute = false

local router = Router.new()
Tx.beforeEach = function()
    router = Router.new()
end

Tx.describe("static", function()
    Tx.it("should match static route", function()
        router:add("GET", "/hello", function() return "ok" end)
        local x, p, match = router:match("GET", "/hello")
        Tx.equal(x[1].handlers[1](), "ok")
        Tx.equal(#x[1].handlers, 1)
        Tx.equal(x[1].method, "GET")
        Tx.equal(x[1].order, 1)
        Tx.equal(p, {})
    end)

    Tx.it("should not match unknown route", function()
        router:add("GET", "/known", function() return 1 end)
        local x, p = router:match("GET", "/unknown")
        Tx.equal(x, {})
        Tx.equal(p, {})
    end)

    Tx.it("should match route with trailing slash", function()
        router:add("GET", "/test", function() return "no slash" end)
        local x, p = router:match("GET", "/test/")
        Tx.equal(x[1].handlers[1](), "no slash")
    end)

    Tx.it("should match root route", function()
        router:add("GET", "/", function() return "root" end)
        local x, p = router:match("GET", "/")
        Tx.equal(x[1].handlers[1](), "root")
    end)
end)

Tx.describe("methods", function()
    Tx.it("system should filter by method and return empty", function()
        router:add("GET", "/hello", function() return "hello" end)
        local x, p = router:match("POST", "/hello")
        Tx.equal(x, {})
        Tx.equal(p, {})
    end)

    Tx.it("should accept and find custom method route", function()
        router:add("PURGE", "/cache", function() return "purge cache" end)
        local x, p = router:match("PURGE", "/cache")
        Tx.equal(x[1].handlers[1](), "purge cache")
    end)

    Tx.it("wildcard should not match different method", function()
        router:add("POST", "/api/*", function() return "wild" end)
        local x, p = router:match("GET", "/api/whatever")
        Tx.equal(#x, 0)
    end)

    Tx.it("multiple wildcards with different methods should not interfere", function()
        router:add("POST", "/submit/*", function() return "post-wild" end)
        router:add("GET", "/submit/*", function() return "get-wild" end)

        local x1, p1 = router:match("POST", "/submit/file.csv")
        Tx.equal(x1[1].handlers[1](), "post-wild")
        Tx.equal(p1["*"], "file.csv")

        local x2, p2 = router:match("GET", "/submit/file.csv")
        Tx.equal(x2[1].handlers[1](), "get-wild")
        Tx.equal(p2["*"], "file.csv")
    end)
end)

Tx.describe("params", function()
    Tx.it("should match simple parameter", function()
        router:add("GET", "/user/:id", function() return 1 end)
        local x, p = router:match("GET", "/user/42")
        Tx.equal(x[1].handlers[1](), 1)
        Tx.equal(p["id"], "42")
    end)

    Tx.it("should match parameter at start of path", function()
        router:add("GET", "/:lang/docs", function() return 1 end)
        local x, p = router:match("GET", "/en/docs")
        Tx.equal(x[1].handlers[1](), 1)
        Tx.equal(p["lang"], "en")
    end)

    Tx.it("should match multiple parameters", function()
        router:add("GET", "/:type/:id", function() return "ok" end)
        local x, p = router:match("GET", "/user/99")
        Tx.equal(x[1].handlers[1](), "ok")
        Tx.equal(p["type"], "user")
        Tx.equal(p["id"], "99")
    end)
end)

Tx.describe("patterns", function()
    Tx.it("should match parameter with pattern", function()
        router:add("GET", "/file/:id{%d+}", function() return "number" end)
        local x, p = router:match("GET", "/file/123")
        Tx.equal(p["id"], "123")
    end)


    Tx.it("should not match pattern if invalid", function()
        router:add("GET", "/file/:id{%d+}", function() return "number" end)
        local x, p = router:match("GET", "/file/abc")
        Tx.equal(x, {})
        Tx.equal(p, {})
    end)
end)

Tx.describe("optional", function()
    Tx.it("should match optional parameter present", function()
        router:add("GET", "/page/:id?", function() return "maybe" end)
        local x, p = router:match("GET", "/page/42")
        Tx.equal(x[1].handlers[1](), "maybe")
        Tx.equal(p["id"], "42")
    end)

    Tx.it("should match optional parameter missing", function()
        router:add("GET", "/page/:id?", function() return "maybe" end)
        local x, p = router:match("GET", "/page")
        Tx.equal(x[1].handlers[1](), "maybe")
        Tx.equal(p["id"], nil)
    end)

    Tx.it("should match optional parameter with validation", function()
        router:add("GET", "/doc/:slug?{%a+}", function() return "slug" end)
        local x, p = router:match("GET", "/doc/hello")
        Tx.equal(x[1].handlers[1](), "slug")
        Tx.equal(p["slug"], "hello")
    end)

    Tx.it("should not match optional parameter if fails pattern", function()
        router:add("GET", "/doc/:slug?{%a+}", function() return "slug" end)
        local x, p = router:match("GET", "/doc/123")
        Tx.equal(x, {})
        Tx.equal(x, {})
        Tx.equal(p, {})
    end)
end)

Tx.describe("wildcards", function()
    Tx.it("should find the middleware", function()
        router:add("GET", "/path/*", function() return "wild" end)
        local x, p = router:match("GET", "/path/anything/here")
        Tx.equal(x[1].handlers[1](), "wild")
        Tx.equal(p["*"], "anything/here")
    end)

    Tx.it("should not match empty wildcard segment", function()
        router:add("GET", "/path/*", function() return "wild" end)
        local x, p = router:match("GET", "/path")
        Tx.equal(x, {})
        Tx.equal(p, {})
    end)

    Tx.it("should find wilcard in the middle and associated param", function()
        router:add("GET", "/path/*/edit", function() return "valid" end)
        local x, p = router:match("GET", "/path/something/edit")

        Tx.equal(x[1].handlers[1](), "valid")
        Tx.equal(p["*"], "something")
    end)
end)

Tx.describe("priority", function()
    Tx.it("should prefer static over param", function()
        router:add("GET", "/user/me", function() return "me" end)
        router:add("GET", "/user/:id", function() return "id" end)
        local x, p = router:match("GET", "/user/me")
        Tx.equal(x[1].handlers[1](), "me")
    end)

    Tx.it("should prefer static over wildcard", function()
        router:add("GET", "/path/known", function() return "known" end)
        router:add("GET", "/path/*", function() return "wild" end)
        local x, p = router:match("GET", "/path/known")
        Tx.equal(x[1].handlers[1](), "known")
    end)

    Tx.it("should choose best scored/specific route", function()
        router:add("GET", "/user/:1", function() return 1 end)
        router:add("GET", "/user/:1/:2", function() return 2 end)
        router:add("GET", "/user/:1/:2/:3", function() return 3 end)
        local x, p = router:match("GET", "/user/p1/p2")
        Tx.equal(x[1].handlers[1](), 2)
        Tx.equal(p["2"], "p2")
    end)

    Tx.it("specific path should match before wildcard", function()
        router:add("GET", "/api/v1/users", function() return "specific" end)
        router:add("GET", "/api/*", function() return "wild" end)
        local x, p = router:match("GET", "/api/v1/users")
        Tx.equal(x[1].handlers[1](), "specific")
    end)

    Tx.it("should store * param and :type param", function()
        router:add("GET", "/api/:type", function() return "param" end)
        router:add("GET", "/api/:type/*", function() return "wild" end)
        local x2, p2 = router:match("GET", "/api/id")
        Tx.equal(x2[1].handlers[1](), "param")
        Tx.equal(p2["type"], "id")

        local x, p = router:match("GET", "/api/id/123")
        Tx.equal(x[1].handlers[1](), "wild")
        Tx.equal(p["type"], "id")
        Tx.equal(p["*"], "123")
    end)
end)

Tx.describe("chain", function()
    Tx.it("should execute all functions", function()
        local r = 0
        local fn = function() r = r + 1 end
        router:add("GET", "/", fn, fn, fn)
        local x = router:match("GET", "/")
        for _, node in ipairs(x) do
            for _, h in ipairs(node.handlers) do
                h()
            end
        end
        Tx.equal(r, 3)
    end)

    Tx.it("should add all routes node to same leaf", function()
        local r = 0
        local fn = function() r = r + 1 end
        router:add("GET", "/", fn)
        router:add("GET", "/", fn)
        router:add("GET", "/", fn)
        local x = router:match("GET", "/")
        for _, node in ipairs(x) do
            for _, h in ipairs(node.handlers) do
                h()
            end
        end
        Tx.equal(r, 3)
    end)
end)

Tx.describe("mw-basics", function()
    Tx.it("should call exact-prefix middleware for exact path", function()
        local called = false
        router:add("USE", "/admin", function() called = true end)
        router:add("GET", "/admin", function() return "ok" end)
        local x, p = router:match("GET", "/admin")
        for _, node in ipairs(x) do
            for _, h in ipairs(node.handlers) do
                h()
            end
        end
        Tx.equal(called, true)
    end)

    Tx.it("should not call exact-prefix middleware for deeper path", function()
        local called = false
        router:add("USE", "/admin", function() called = true end)
        router:add("GET", "/admin/dashboard", function() return "ok" end)

        local x, p = router:match("GET", "/admin/dashboard")
        for _, node in ipairs(x) do
            for _, h in ipairs(node.handlers) do
                h()
            end
        end
        Tx.equal(called, false)
    end)

    Tx.it("should match middleware on root path", function()
        local step = {}
        router:add("USE", "*", function() table.insert(step, "mw") end)
        router:add("GET", "/", function() table.insert(step, "handler") end)
        local x, p = router:match("GET", "/")
        for _, node in ipairs(x) do
            for _, h in ipairs(node.handlers) do
                h()
            end
        end
        Tx.equal(step, { "mw", "handler" })
    end)

    Tx.it("should call middleware with wildcard", function()
        local mw_called = false
        local hdl_called = false
        router:add("USE", "/admin/*", function() mw_called = true end)
        router:add("GET", "/admin/dashboard", function() hdl_called = true end)
        local x, p = router:match("GET", "/admin/dashboard")
        for _, node in ipairs(x) do
            for _, h in ipairs(node.handlers) do
                h()
            end
        end
        Tx.equal(mw_called, true)
        Tx.equal(hdl_called, true)
    end)

    Tx.it("should run wildcard middleware even without trailing path", function()
        local called = false
        router:add("USE", "/blog/*", function() called = true end)
        router:add("GET", "/blog", function() return 1 end)
        local x, p = router:match("GET", "/blog")
        for _, node in ipairs(x) do
            for _, h in ipairs(node.handlers) do
                h()
            end
        end
        Tx.equal(called, false)
    end)

    Tx.it("should find general method USE and ALL", function()
        router:add("USE", "*", function() return "hello" end)
        router:add("ALL", "*", function() return "hello" end)
        router:add("GET", "/hello", function() return "hello" end)
        local x1 = router:match("METHOD", "/hello")
        local x2 = router:match("GET", "/hello")
        Tx.equal(#x1, 2)
        Tx.equal(#x2, 3)
    end)
end)
