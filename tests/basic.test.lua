Tx.mute = false

Tx.beforeEach = function()
    trie  = newNode()
    order = 0
end

Tx.describe("static", function()
    Tx.it("should match static route", function()
        insert("GET", "/hello", function() return "ok" end)
        local x, p, match = search("GET", "/hello")
        Tx.equal(x[1].handlers[1](), "ok")
        Tx.equal(#x[1].handlers, 1)
        Tx.equal(x[1].method, "GET")
        Tx.equal(x[1].order, 1)
        Tx.equal(p, {})
    end)

    Tx.it("should not match unknown route", function()
        insert("GET", "/known", function() return 1 end)
        local x, p = search("GET", "/unknown")
        Tx.equal(x, {})
        Tx.equal(p, {})
    end)

    Tx.it("should match route with trailing slash", function()
        insert("GET", "/test", function() return "no slash" end)
        local x, p = search("GET", "/test/")
        Tx.equal(x[1].handlers[1](), "no slash")
    end)

    Tx.it("should match root route", function()
        insert("GET", "/", function() return "root" end)
        local x, p = search("GET", "/")
        Tx.equal(x[1].handlers[1](), "root")
    end)
end)

Tx.describe("methods", function()
    Tx.it("system should filter by method and return empty", function()
        insert("GET", "/hello", function() return "hello" end)
        local x, p = search("POST", "/hello")
        Tx.equal(x, {})
        Tx.equal(p, {})
    end)

    Tx.it("should accept and find custom method route", function()
        insert("PURGE", "/cache", function() return "purge cache" end)
        local x, p = search("PURGE", "/cache")
        Tx.equal(x[1].handlers[1](), "purge cache")
    end)

    Tx.it("wildcard should not match different method", function()
        insert("POST", "/api/*", function() return "wild" end)
        local x, p = search("GET", "/api/whatever")
        Tx.equal(#x, 0)
    end)

    Tx.it("multiple wildcards with different methods should not interfere", function()
        insert("POST", "/submit/*", function() return "post-wild" end)
        insert("GET", "/submit/*", function() return "get-wild" end)

        local x1, p1 = search("POST", "/submit/file.csv")
        Tx.equal(x1[1].handlers[1](), "post-wild")
        Tx.equal(p1["*"], "file.csv")

        local x2, p2 = search("GET", "/submit/file.csv")
        Tx.equal(x2[1].handlers[1](), "get-wild")
        Tx.equal(p2["*"], "file.csv")
    end)
end)

Tx.describe("params", function()
    Tx.it("should match simple parameter", function()
        insert("GET", "/user/:id", function() return 1 end)
        local x, p = search("GET", "/user/42")
        Tx.equal(x[1].handlers[1](), 1)
        Tx.equal(p["id"], "42")
    end)

    Tx.it("should match parameter at start of path", function()
        insert("GET", "/:lang/docs", function() return 1 end)
        local x, p = search("GET", "/en/docs")
        Tx.equal(x[1].handlers[1](), 1)
        Tx.equal(p["lang"], "en")
    end)

    Tx.it("should match multiple parameters", function()
        insert("GET", "/:type/:id", function() return "ok" end)
        local x, p = search("GET", "/user/99")
        Tx.equal(x[1].handlers[1](), "ok")
        Tx.equal(p["type"], "user")
        Tx.equal(p["id"], "99")
    end)
end)

Tx.describe("patterns", function()
    Tx.it("should match parameter with pattern", function()
        insert("GET", "/file/:id{%d+}", function() return "number" end)
        local x, p = search("GET", "/file/123")
        Tx.equal(p["id"], "123")
    end)


    Tx.it("should not match pattern if invalid", function()
        insert("GET", "/file/:id{%d+}", function() return "number" end)
        local x, p = search("GET", "/file/abc")
        Tx.equal(x, {})
        Tx.equal(p, {})
    end)
end)

Tx.describe("optional", function()
    Tx.it("should match optional parameter present", function()
        insert("GET", "/page/:id?", function() return "maybe" end)
        local x, p = search("GET", "/page/42")
        Tx.equal(x[1].handlers[1](), "maybe")
        Tx.equal(p["id"], "42")
    end)

    Tx.it("should match optional parameter missing", function()
        insert("GET", "/page/:id?", function() return "maybe" end)
        local x, p = search("GET", "/page")
        Tx.equal(x[1].handlers[1](), "maybe")
        Tx.equal(p["id"], nil)
    end)

    Tx.it("should match optional parameter with validation", function()
        insert("GET", "/doc/:slug?{%a+}", function() return "slug" end)
        local x, p = search("GET", "/doc/hello")
        Tx.equal(x[1].handlers[1](), "slug")
        Tx.equal(p["slug"], "hello")
    end)

    Tx.it("should not match optional parameter if fails pattern", function()
        insert("GET", "/doc/:slug?{%a+}", function() return "slug" end)
        local x, p = search("GET", "/doc/123")
        Tx.equal(x, {})
        Tx.equal(x, {})
        Tx.equal(p, {})
    end)
end)

Tx.describe("wildcards", function()
    Tx.it("should find the middleware", function()
        insert("GET", "/path/*", function() return "wild" end)
        local x, p = search("GET", "/path/anything/here")
        Tx.equal(x[1].handlers[1](), "wild")
        Tx.equal(p["*"], "anything/here")
    end)

    Tx.it("should not match empty wildcard segment", function()
        insert("GET", "/path/*", function() return "wild" end)
        local x, p = search("GET", "/path")
        Tx.equal(x, {})
        Tx.equal(p, {})
    end)

    Tx.it("should find wilcard in the middle and associated param", function()
        insert("GET", "/path/*/edit", function() return "valid" end)
        local x, p = search("GET", "/path/something/edit")

        Tx.equal(x[1].handlers[1](), "valid")
        Tx.equal(p["*"], "something")
    end)
end)

Tx.describe("priority", function()
    Tx.it("should prefer static over param", function()
        insert("GET", "/user/me", function() return "me" end)
        insert("GET", "/user/:id", function() return "id" end)
        local x, p = search("GET", "/user/me")
        Tx.equal(x[1].handlers[1](), "me")
    end)

    Tx.it("should prefer static over wildcard", function()
        insert("GET", "/path/known", function() return "known" end)
        insert("GET", "/path/*", function() return "wild" end)
        local x, p = search("GET", "/path/known")
        Tx.equal(x[1].handlers[1](), "known")
    end)

    Tx.it("should choose best scored/specific route", function()
        insert("GET", "/user/:1", function() return 1 end)
        insert("GET", "/user/:1/:2", function() return 2 end)
        insert("GET", "/user/:1/:2/:3", function() return 3 end)
        local x, p = search("GET", "/user/p1/p2")
        Tx.equal(x[1].handlers[1](), 2)
        Tx.equal(p["2"], "p2")
    end)

    Tx.it("specific path should match before wildcard", function()
        insert("GET", "/api/v1/users", function() return "specific" end)
        insert("GET", "/api/*", function() return "wild" end)
        local x, p = search("GET", "/api/v1/users")
        Tx.equal(x[1].handlers[1](), "specific")
    end)

    Tx.it("should store * param and :type param", function()
        insert("GET", "/api/:type", function() return "param" end)
        insert("GET", "/api/:type/*", function() return "wild" end)
        local x2, p2 = search("GET", "/api/id")
        Tx.equal(x2[1].handlers[1](), "param")
        Tx.equal(p2["type"], "id")

        local x, p = search("GET", "/api/id/123")
        Tx.equal(x[1].handlers[1](), "wild")
        Tx.equal(p["type"], "id")
        Tx.equal(p["*"], "123")
    end)
end)

Tx.describe("chain", function()
    Tx.it("should execute all functions", function()
        local r = 0
        local fn = function() r = r + 1 end
        insert("GET", "/", fn, fn, fn)
        local x = search("GET", "/")
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
        insert("GET", "/", fn)
        insert("GET", "/", fn)
        insert("GET", "/", fn)
        local x = search("GET", "/")
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
        insert("USE", "/admin", function() called = true end)
        insert("GET", "/admin", function() return "ok" end)
        local x, p = search("GET", "/admin")
        for _, node in ipairs(x) do
            for _, h in ipairs(node.handlers) do
                h()
            end
        end
        Tx.equal(called, true)
    end)

    Tx.it("should not call exact-prefix middleware for deeper path", function()
        local called = false
        insert("USE", "/admin", function() called = true end)
        insert("GET", "/admin/dashboard", function() return "ok" end)

        local x, p = search("GET", "/admin/dashboard")
        for _, node in ipairs(x) do
            for _, h in ipairs(node.handlers) do
                h()
            end
        end
        Tx.equal(called, false)
    end)

    Tx.it("should match middleware on root path", function()
        local step = {}
        insert("USE", "*", function() table.insert(step, "mw") end)
        insert("GET", "/", function() table.insert(step, "handler") end)
        local x, p = search("GET", "/")
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
        insert("USE", "/admin/*", function() mw_called = true end)
        insert("GET", "/admin/dashboard", function() hdl_called = true end)
        local x, p = search("GET", "/admin/dashboard")
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
        insert("USE", "/blog/*", function() called = true end)
        insert("GET", "/blog", function() return 1 end)
        local x, p = search("GET", "/blog")
        for _, node in ipairs(x) do
            for _, h in ipairs(node.handlers) do
                h()
            end
        end
        Tx.equal(called, false)
    end)

    Tx.it("should find general method USE and ALL", function()
        insert("USE", "*", function() return "hello" end)
        insert("ALL", "*", function() return "hello" end)
        insert("GET", "/hello", function() return "hello" end)
        local x1 = search("METHOD", "/hello")
        local x2 = search("GET", "/hello")
        Tx.equal(#x1, 2)
        Tx.equal(#x2, 3)
    end)
end)
