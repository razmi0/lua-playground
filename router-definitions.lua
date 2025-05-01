local Set = require("utils.set")

local STD_METHODS = { "GET", "POST", "PUT", "PATCH", "HEAD", "OPTIONS", "DELETE" }
local MW_METHOD = "USE"
local ALL_METHOD = "ALL"

return {
    methods = {
        STD_METHODS = Set.new():add(STD_METHODS),
        MW_METHOD = MW_METHOD,
        ALL_METHOD = ALL_METHOD,
        ALL_AVAILABLE_METHODS = Set.new():add(STD_METHODS):add(MW_METHOD):add(ALL_METHOD)
    },
}
