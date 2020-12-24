-- store source path to this lua file 
local debugSource = debug.getinfo(1).source
--TODO merge this with original debug file

-- gets the same info as debug.getinfo(n) but with some addition details
function getinfo(level)
    if level == nil then level = 1 end
    -- Find the first calling function not in this source file
    local n = level + 1
    local info = nil
    while true do
        info = debug.getinfo(n)
        --LOG('info.source ' .. info.source)
        if info.source ~= debugSource then break end
        n = n + 1
    end
    local path = info.source
    if string.sub(path, 1, 1) == "@" then
        path = string.sub(path, 2) 
    end 
    info.sourceFile = DiskToLocal(path)
    info.sourceLine = info.sourceFile .. '(L'..info.currentline ..')'
    info.sourceName = info.sourceFile .. '(L'..info.currentline ..') '..info.name ..'()'
    --local keys = table.keys(info)
    ----table.print( keys, " keys")
    --for _, key in keys or {} do
    --    LOG(key..  ' = ' .. tostring(info[key]) )
    --end
    return info 
end
 
function thisFunction()
    return getinfo().sourceName
end
function thisFileName()
    return getinfo().sourceFile
end
function thisFileLine()
    return getinfo().sourceLine 
end

