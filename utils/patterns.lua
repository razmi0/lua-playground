local PATTERN_GROUPS = {
    dynamic = "(:?)",
    label = "([%w%-%_%*]+)",
    optionnal = "(%??)",
    pattern = "{?(.-)}?",
    complete = "^(:?)([%w%-%_%*]+)(%??){?(.-)}?$"
}

return PATTERN_GROUPS
