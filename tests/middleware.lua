local Trie = require("trie-router")
local Tx = require("tests.tx")

Tx.describe("middlewares", function()
    Tx.it("should call middleware with wildcard", function()
        local trie = Trie.new()
        local called = false
        trie:insert("USE", "/admin/*", function() called = true end)
        trie:insert("GET", "/admin/dashboard", function() return "ok" end)
        local x, _ = trie:search("GET", "/admin/dashboard")
        x[1]() -- middleware
        x[2]() -- handler
        Tx.equal(called, true)
    end)

    Tx.it("should call multiple middlewares in order", function()
        local trie = Trie.new()
        local log = {}
        trie:insert("USE", "/a/*", function() table.insert(log, "A") end)
        trie:insert("USE", "/a/b/*", function() table.insert(log, "B") end)
        trie:insert("GET", "/a/b/c", function() return "done" end)
        local x, _ = trie:search("GET", "/a/b/c")
        for _, fn in ipairs(x) do fn() end
        Tx.equal(log, { "A", "B" })
    end)

    Tx.it("should not call unrelated middleware", function()
        local trie = Trie.new()
        local called = false
        trie:insert("USE", "/public/*", function() called = true end)
        trie:insert("GET", "/private/zone", function() return "ok" end)
        local x, _ = trie:search("GET", "/private/zone")
        for _, fn in ipairs(x) do fn() end
        Tx.equal(called, false)
    end)

    Tx.it("should match middleware on root path", function() --
        local trie = Trie.new()
        local step = {}
        trie:insert("USE", "*", function() table.insert(step, "mw") end)
        trie:insert("GET", "/", function() table.insert(step, "handler") end)
        local x, _ = trie:search("GET", "/")
        for _, fn in ipairs(x) do fn() end
        Tx.equal(step, { "mw", "handler" })
    end)

    Tx.it("should allow method-specific middleware", function()
        local trie = Trie.new()
        local method_called = false
        trie:insert("USE", "/x/*", function() method_called = "USE" end)
        trie:insert("POST", "/x/test", function() method_called = "POST" end)
        local x, _ = trie:search("POST", "/x/test")
        for _, fn in ipairs(x) do fn() end
        Tx.equal(method_called, "POST") -- USE should not override POST
    end)

    Tx.it("should accumulate middleware from parent paths", function()
        local trie = Trie.new()
        local list = {}
        trie:insert("USE", "/api/*", function() table.insert(list, "api") end)
        trie:insert("USE", "/api/users/*", function() table.insert(list, "users") end)
        trie:insert("GET", "/api/users/42", function() table.insert(list, "handler") end)
        local x, _ = trie:search("GET", "/api/users/42")
        for _, fn in ipairs(x) do fn() end
        Tx.equal(list, { "api", "users", "handler" })
    end)

    Tx.it("should run wildcard middleware even without trailing path", function()
        local trie = Trie.new()
        local called = false
        trie:insert("USE", "/blog/*", function() called = true end)
        trie:insert("GET", "/blog", function() return 1 end)
        local x, _ = trie:search("GET", "/blog")
        for _, fn in ipairs(x) do fn() end
        Tx.equal(called, true)
    end)

    Tx.it("should skip middleware if path doesn't match prefix", function()
        local trie = Trie.new()
        local log = {}
        trie:insert("USE", "/admin/*", function() table.insert(log, "mw") end)
        trie:insert("GET", "/blog/post", function() table.insert(log, "handler") end)
        local x, _ = trie:search("GET", "/blog/post")
        for _, fn in ipairs(x) do fn() end
        Tx.equal(log, { "handler" })
    end)

    Tx.it("should call middleware only for GET method", function()
        local trie = Trie.new()
        local called = false
        trie:insert("GET", "/secure/*", function() called = true end)
        trie:insert("POST", "/secure/data", function() return "no-mw" end)

        local x, _ = trie:search("POST", "/secure/data")
        for _, fn in ipairs(x) do fn() end

        Tx.equal(called, false)
    end)

    Tx.it("should call GET-specific middleware before GET handler", function()
        local trie = Trie.new()
        local log = {}
        trie:insert("GET", "/api/*", function() table.insert(log, "mw") end)
        trie:insert("GET", "/api/endpoint", function() table.insert(log, "handler") end)

        local x, _ = trie:search("GET", "/api/endpoint")
        for _, fn in ipairs(x) do fn() end

        Tx.equal(log, { "mw", "handler" })
    end)

    Tx.it("should call duplicated middleware twice", function()
        local trie = Trie.new()
        local count = 0
        local mw = function() count = count + 1 end

        trie:insert("USE", "/multi/*", mw)
        trie:insert("USE", "/multi/*", mw)
        trie:insert("GET", "/multi/hit", function() return "end" end)

        local x, _ = trie:search("GET", "/multi/hit")
        for _, fn in ipairs(x) do fn() end

        Tx.equal(count, 2)
    end)

    Tx.it("should handle duplicate GET middleware independently", function()
        local trie = Trie.new()
        local record = {}
        trie:insert("GET", "/dup/*", function() table.insert(record, "first") end)
        trie:insert("GET", "/dup/*", function() table.insert(record, "second") end)
        trie:insert("GET", "/dup/here", function() table.insert(record, "handler") end)

        local x, _ = trie:search("GET", "/dup/here")
        for _, fn in ipairs(x) do fn() end

        Tx.equal(record, { "first", "second", "handler" })
    end)
end)
