local Router = require("router")
local Tx = require("tests.tx")

Tx.describe("middlewares", function()
    Tx.it("should call explicit chained middlewares", function()
        local router = Router.new()
        local count = 0
        router:add("GET", "/count",
            function() count = count + 1 end,
            function() count = count + 2 end,
            function() count = count + 3 end
        )
        local x, _ = router:match("GET", "/count")
        for _, fn in ipairs(x) do fn() end
        Tx.equal(count, 6)
    end)

    Tx.it("should call middleware with wildcard", function()
        local router = Router.new()
        local called = false
        router:add("USE", "/admin/*", function() called = true end)
        router:add("GET", "/admin/dashboard", function() return "ok" end)
        local x, _ = router:match("GET", "/admin/dashboard")
        x[1]() -- middleware
        x[2]() -- handler
        Tx.equal(called, true)
    end)

    Tx.it("should call multiple middlewares in order", function()
        local router = Router.new()
        local log = {}
        router:add("USE", "/a/*", function() table.insert(log, "A") end)
        router:add("USE", "/a/b/*", function() table.insert(log, "B") end)
        router:add("GET", "/a/b/c", function() return "done" end)
        local x, _ = router:match("GET", "/a/b/c")
        for _, fn in ipairs(x) do fn() end
        Tx.equal(log, { "A", "B" })
    end)

    Tx.it("should not call unrelated middleware", function()
        local router = Router.new()
        local called = false
        router:add("USE", "/public/*", function() called = true end)
        router:add("GET", "/private/zone", function() return "ok" end)
        local x, _ = router:match("GET", "/private/zone")
        for _, fn in ipairs(x) do fn() end
        Tx.equal(called, false)
    end)

    Tx.it("should match middleware on root path", function() --
        local router = Router.new()
        local step = {}
        router:add("USE", "*", function() table.insert(step, "mw") end)
        router:add("GET", "/", function() table.insert(step, "handler") end)
        local x, _ = router:match("GET", "/")
        for _, fn in ipairs(x) do fn() end
        Tx.equal(step, { "mw", "handler" })
    end)

    Tx.it("should allow method-specific middleware", function()
        local router = Router.new()
        local method_called = nil
        router:add("USE", "/x/*", function() method_called = "USE" end)
        router:add("POST", "/x/test", function() method_called = "POST" end)
        local x, _ = router:match("POST", "/x/test")
        for _, fn in ipairs(x) do fn() end
        Tx.equal(method_called, "POST") -- USE should not override POST
    end)

    Tx.it("should accumulate middleware from parent paths", function()
        local router = Router.new()
        local list = {}
        router:add("USE", "/api/*", function() table.insert(list, "api") end)
        router:add("USE", "/api/users/*", function() table.insert(list, "users") end)
        router:add("GET", "/api/users/42", function() table.insert(list, "handler") end)
        local x, _ = router:match("GET", "/api/users/42")
        for _, fn in ipairs(x) do fn() end
        Tx.equal(list, { "api", "users", "handler" })
    end)

    Tx.it("should run wildcard middleware even without trailing path", function()
        local router = Router.new()
        local called = false
        router:add("USE", "/blog/*", function() called = true end)
        router:add("GET", "/blog", function() return 1 end)
        local x, _ = router:match("GET", "/blog")
        for _, fn in ipairs(x) do fn() end
        Tx.equal(called, true)
    end)

    Tx.it("should skip middleware if path doesn't match prefix", function()
        local router = Router.new()
        local log = {}
        router:add("USE", "/admin/*", function() table.insert(log, "mw") end)
        router:add("GET", "/blog/post", function() table.insert(log, "handler") end)
        local x, _ = router:match("GET", "/blog/post")
        for _, fn in ipairs(x) do fn() end
        Tx.equal(log, { "handler" })
    end)

    Tx.it("should call middleware only for GET method", function()
        local router = Router.new()
        local called = false
        router:add("GET", "/secure/*", function() called = true end)
        router:add("POST", "/secure/data", function() return "no-mw" end)

        local x, _ = router:match("POST", "/secure/data")
        for _, fn in ipairs(x) do fn() end

        Tx.equal(called, false)
    end)

    Tx.it("should call GET-specific middleware before GET handler", function()
        local router = Router.new()
        local log = {}
        router:add("GET", "/api/*", function() table.insert(log, "mw") end)
        router:add("GET", "/api/endpoint", function() table.insert(log, "handler") end)

        local x, _ = router:match("GET", "/api/endpoint")
        for _, fn in ipairs(x) do fn() end

        Tx.equal(log, { "mw", "handler" })
    end)

    Tx.it("should call duplicated middleware twice", function()
        local router = Router.new()
        local count = 0
        local mw = function() count = count + 1 end

        router:add("USE", "/multi/*", mw)
        router:add("USE", "/multi/*", mw)
        router:add("GET", "/multi/hit", function() return "end" end)

        local x, _ = router:match("GET", "/multi/hit")
        for _, fn in ipairs(x) do fn() end

        Tx.equal(count, 2)
    end)

    Tx.it("should handle duplicate GET middleware independently", function()
        local router = Router.new()
        local record = {}
        router:add("GET", "/dup/*", function() table.insert(record, "first") end)
        router:add("GET", "/dup/*", function() table.insert(record, "second") end)
        router:add("GET", "/dup/here", function() table.insert(record, "handler") end)

        local x, _ = router:match("GET", "/dup/here")
        for _, fn in ipairs(x) do fn() end

        Tx.equal(record, { "first", "second", "handler" })
    end)
end)
