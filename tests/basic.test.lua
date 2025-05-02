local Trie = require("trie-router")
local Tx = require("tests.tx")


Tx.describe("basics", function()
    Tx.it("should match static route", function()
        local trie = Trie.new()
        trie:insert("GET", "/hello", function() return "ok" end)
        local x, p = trie:search("GET", "/hello")
        Tx.equal(x[1](), "ok")
        Tx.equal(p, {})
    end)

    Tx.it("should insert and search all methods", function()
        local methods = { "GET", "POST", "PUT", "PATCH", "HEAD", "OPTIONS", "DELETE" }
        local results = {}
        local x = {}
        local trie = Trie.new()
        for _, m in ipairs(methods) do
            trie:insert(m, "/hello", function() return m end)
        end
        for _, m in ipairs(methods) do
            local hs, _ = trie:search(m, "/hello")
            table.insert(x, hs[1])
        end
        for _, fn in ipairs(x) do
            table.insert(results, fn())
        end
        Tx.equal(results, methods)
    end)

    Tx.it("should insert and search all methods via ALL method", function()
        local methods = { "GET", "POST", "PUT", "PATCH", "HEAD", "OPTIONS", "DELETE" }
        local expected = { "hello", "hello", "hello", "hello", "hello", "hello", "hello" }
        local results = {}
        local x = {}
        local trie = Trie.new()
        trie:insert("ALL", "/hello", function() return "hello" end)
        for _, m in ipairs(methods) do
            local hs, _ = trie:search(m, "/hello")
            table.insert(x, hs[1])
        end
        for _, fn in ipairs(x) do
            table.insert(results, fn())
        end
        Tx.equal(results, expected)
    end)

    Tx.it("should not match unknown route", function()
        local trie = Trie.new()
        trie:insert("GET", "/known", function() return 1 end)
        local x, p = trie:search("GET", "/unknown")
        Tx.equal(x, nil)
        Tx.equal(p, nil)
    end)

    Tx.it("should match simple parameter", function()
        local trie = Trie.new()
        trie:insert("GET", "/user/:id", function() return 1 end)
        local x, p = trie:search("GET", "/user/42")
        Tx.equal(p["id"], "42")
    end)

    Tx.it("should match parameter in middle", function()
        local trie = Trie.new()
        trie:insert("GET", "/:lang/docs", function() return 1 end)
        local x, p = trie:search("GET", "/en/docs")
        Tx.equal(p["lang"], "en")
    end)

    Tx.it("should not match static instead of param", function()
        local trie = Trie.new()
        trie:insert("GET", "/static/path", function() return 1 end)
        local x, p = trie:search("GET", "/:type/path")
        Tx.equal(x, nil)
    end)

    Tx.it("should match parameter with pattern", function()
        local trie = Trie.new()
        trie:insert("GET", "/file/:id{%d+}", function() return "number" end)
        local x, p = trie:search("GET", "/file/123")
        Tx.equal(p["id"], "123")
    end)

    Tx.it("should not match pattern if invalid", function()
        local trie = Trie.new()
        trie:insert("GET", "/file/:id{%d+}", function() return "number" end)
        local x, p = trie:search("GET", "/file/abc")
        Tx.equal(x, nil)
        Tx.equal(p, nil)
    end)

    Tx.it("should match optional parameter present", function()
        local trie = Trie.new()
        trie:insert("GET", "/page/:id?", function() return "maybe" end)
        local x, p = trie:search("GET", "/page/42")
        Tx.equal(p["id"], "42")
    end)

    Tx.it("should match optional parameter missing", function()
        local trie = Trie.new()
        trie:insert("GET", "/page/:id?", function() return "maybe" end)
        local x, p = trie:search("GET", "/page")
        Tx.equal(p["id"], nil)
    end)

    Tx.it("should match optional parameter with validation", function()
        local trie = Trie.new()
        trie:insert("GET", "/doc/:slug?{%a+}", function() return "slug" end)
        local x, p = trie:search("GET", "/doc/hello")
        Tx.equal(p["slug"], "hello")
    end)

    Tx.it("should not match optional parameter if fails pattern", function()
        local trie = Trie.new()
        trie:insert("GET", "/doc/:slug?{%a+}", function() return "slug" end)
        local x, p = trie:search("GET", "/doc/123")
        Tx.equal(x, nil)
    end)

    Tx.it("should match multiple parameters", function()
        local trie = Trie.new()
        trie:insert("GET", "/:type/:id", function() return "ok" end)
        local x, p = trie:search("GET", "/user/99")
        Tx.equal(p["type"], "user")
        Tx.equal(p["id"], "99")
    end)

    Tx.it("should prefer static over param", function()
        local trie = Trie.new()
        trie:insert("GET", "/user/me", function() return "me" end)
        trie:insert("GET", "/user/:id", function() return "id" end)
        local x, _ = trie:search("GET", "/user/me")
        Tx.equal(x[1](), "me")
    end)

    Tx.it("should match route with trailing slash", function()
        local trie = Trie.new()
        trie:insert("GET", "/test", function() return "no slash" end)
        local x, _ = trie:search("GET", "/test/")
        Tx.equal(x[1](), "no slash")
    end)

    Tx.it("should match root route", function()
        local trie = Trie.new()
        trie:insert("GET", "/", function() return "root" end)
        local x, _ = trie:search("GET", "/")
        Tx.equal(x[1](), "root")
    end)

    Tx.it("should match wildcard segment", function()
        local trie = Trie.new()
        trie:insert("GET", "/path/*", function() return "wild" end)
        local x, p = trie:search("GET", "/path/anything/here")
        Tx.equal(x[1](), "wild")
        Tx.equal(p["*"], "anything/here")
    end)

    Tx.it("should not match empty wildcard segment", function()
        local trie = Trie.new()
        trie:insert("GET", "/path/*", function() return "wild" end)
        local x, p = trie:search("GET", "/path")
        Tx.equal(x, nil)
        Tx.equal(p, nil)
    end)

    Tx.it("should not match if wildcard is not at end", function()
        local trie = Trie.new()
        trie:insert("GET", "/path/*/edit", function() return "invalid" end)
        local x, p = trie:search("GET", "/path/something/edit")
        Tx.equal(x, nil)
    end)

    Tx.it("should prefer static over wildcard", function()
        local trie = Trie.new()
        trie:insert("GET", "/path/known", function() return "known" end)
        trie:insert("GET", "/path/*", function() return "wild" end)
        local x, p = trie:search("GET", "/path/known")
        Tx.equal(x[1](), "known")
    end)
end)
