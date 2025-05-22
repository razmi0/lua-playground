local function split(path)
    if path == "/" or path == "" then
        return { "" }
    end
    local parts = {}
    for segment in string.gmatch(path, "[^/]+") do
        parts[#parts + 1] = segment
    end
    return parts
end


return split
