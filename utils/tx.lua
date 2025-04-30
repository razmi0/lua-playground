local inspect = require("inspect")

local Tx = {}

local fails_count = 0
local tests_count = 0
local name = ""

local function c(color, str)
    local colors = {
        red = "\27[31m",
        green = "\27[32m",
        reset = "\27[0m",
    }
    local code = colors[color] or colors.reset
    return code .. str .. colors.reset
end



local function deep_contains(container, value)
    if type(container) == "string" then
        return container:find(value, 1, true) ~= nil
    elseif type(container) == "table" then
        for _, v in pairs(container) do
            if v == value then
                return true
            end
            if type(v) == "table" and deep_contains(v, value) then
                return true
            end
        end
    end
    return false
end


function Tx.describe(xname, fn)
    fails_count = 0
    tests_count = 0
    name = xname
    print("\n" .. name)
    fn()
    if fails_count == 0 then
        print(c("green", " ok"))
    else
        print(c("reset", "Failed ") .. c("red", tostring(fails_count)) .. "/" .. tostring(tests_count))
    end
end

function Tx.it(msg, func)
    if Tx.beforeEach then
        Tx.afterEach()
    end
    tests_count = tests_count + 1
    local success, internal_err_msg = pcall(func)
    if not success then
        fails_count = fails_count + 1
        io.write(c("red", "+ "))
        print(c("red", "\n" .. msg), c("red", internal_err_msg))
    else
        io.write(c("green", "+"))
    end
    if Tx.afterEach then
        Tx.afterEach()
    end
end

function Tx.equal(actual, expected)
    local function deep_equal(a, b)
        if type(a) ~= type(b) then
            return false
        end
        if type(a) ~= "table" then
            return a == b
        end

        local checked_keys = {}

        for k, v in pairs(a) do
            if not deep_equal(v, b[k]) then
                return false
            end
            checked_keys[k] = true
        end

        for k in pairs(b) do
            if not checked_keys[k] then
                return false
            end
        end

        return true
    end

    if not deep_equal(actual, expected) then
        error(c("red", inspect(actual) .. " ~= " .. inspect(expected)))
    end
end

function Tx.include(container, value)
    if not deep_contains(container, value) then
        error(c("red", "Did not expect to find " .. tostring(value)))
    end
end

function Tx.not_include(container, value)
    if deep_contains(container, value) then
        error(c("red", "Did not expect to find " .. tostring(value)))
    end
end

function Tx.contain(string_val, substring)
    if not string.find(string_val, substring, 1, true) then
        error(c("red", ("'" .. string_val .. "' !~ '" .. substring .. "'")))
    end
end

function Tx.throws(fn)
    local ok, _ = pcall(fn)
    if ok then
        error(c('red', "Expected error to be thrown, but none was"))
    end
end

function Tx.fail(msg)
    error(msg or "Forced failure")
end

return Tx
