local function expand(parts, i, acc, out, skipped)
    if i > #parts then
        out[#out + 1] = { table.unpack(acc) }
        return
    end
    local p = parts[i]
    if p:match("?") then
        local base = p:gsub("?", "")
        if not skipped then
            acc[#acc + 1] = base
            expand(parts, i + 1, acc, out, false)
            acc[#acc] = nil
        end
        expand(parts, i + 1, acc, out, true)
    else
        acc[#acc + 1] = p
        expand(parts, i + 1, acc, out, skipped)
        acc[#acc] = nil
    end
end

return expand
