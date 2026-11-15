local Util = {}

function Util.Trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function Util.Clamp(value, low, high)
    if value < low then
        return low
    end
    if value > high then
        return high
    end
    return value
end

function Util.Truncate(value, maxChars)
    local text = tostring(value)
    if #text <= maxChars then
        return text
    end
    return text:sub(1, maxChars) .. "\n... [truncated " .. tostring(#text - maxChars) .. " chars]"
end

function Util.FormatSeconds(seconds)
    if seconds < 1 then
        return string.format("%dms", math.floor(seconds * 1000 + 0.5))
    end
    return string.format("%.1fs", seconds)
end

function Util.Copy(source)
    local target = {}
    for key, value in pairs(source) do
        target[key] = value
    end
    return target
end

function Util.Count(source)
    local count = 0
    for _ in pairs(source) do
        count += 1
    end
    return count
end

function Util.Lines(text)
    local lines = {}
    local position = 1
    text = tostring(text or "")
    while position <= #text do
        local newline = text:find("\n", position, true)
        if newline then
            table.insert(lines, text:sub(position, newline - 1))
            position = newline + 1
        else
            table.insert(lines, text:sub(position))
            break
        end
    end
    if #lines == 0 then
        table.insert(lines, "")
    end
    return lines
end

function Util.SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return false, "not a function"
    end
    local results = table.pack(pcall(fn, ...))
    if not results[1] then
        return false, results[2]
    end
    return true, table.unpack(results, 2, results.n)
end

function Util.RunWithTimeout(seconds, fn)
    local finished = false
    local succeeded = false
    local result = nil
    task.spawn(function()
        succeeded, result = pcall(fn)
        finished = true
    end)
    local deadline = os.clock() + seconds
    while not finished and os.clock() < deadline do
        task.wait(0.05)
    end
    if not finished then
        return false, "timed out after " .. tostring(seconds) .. "s"
    end
    if not succeeded then
        return false, tostring(result)
    end
    return true, result
end

function Util.ErrorText(err)
    if type(err) == "string" then
        return err
    end
    local ok, text = pcall(tostring, err)
    return ok and text or "unknown error"
end

return Util
