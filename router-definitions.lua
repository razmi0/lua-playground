local Set = require("utils.set")
local inspect = require("inspect")

local STD_METHODS = { "GET", "POST", "PUT", "PATCH", "HEAD", "OPTIONS", "DELETE" }
local MW_METHOD = "USE"
local ALL_METHOD = "ALL"

local STD_SET = Set.new():add(STD_METHODS)
local SET_ALL_AVAILABLE_METHODS = Set.new():add(STD_METHODS):add(MW_METHOD):add(ALL_METHOD)

return {
    methods = {
        STD_METHODS = STD_SET,
        MW_METHOD = MW_METHOD,
        ALL_METHOD = ALL_METHOD,
        ALL_AVAILABLE_METHODS = SET_ALL_AVAILABLE_METHODS
    },
}
