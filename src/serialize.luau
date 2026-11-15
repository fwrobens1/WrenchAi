local HttpService = game:GetService("HttpService")
local Serialize = {}

local function safeText(value)
    local ok, text = pcall(tostring, value)
    return ok and text or "<unprintable>"
end

local function convert(value, depth, seen)
    if value == nil then
        return nil
    end
    local kind = typeof(value)
    if kind == "string" or kind == "boolean" then
        return value
    end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return tostring(value)
        end
        return value
    end
    if kind == "Instance" then
        local path, name, className
        pcall(function()
            path = value:GetFullName()
            name = value.Name
            className = value.ClassName
        end)
        return { __type = "Instance", path = path or name, name = name, class = className }
    end
    if kind == "Vector3" then
        return { __type = "Vector3", x = value.X, y = value.Y, z = value.Z }
    end
    if kind == "Vector2" then
        return { __type = "Vector2", x = value.X, y = value.Y }
    end
    if kind == "CFrame" then
        local position = value.Position
        return { __type = "CFrame", x = position.X, y = position.Y, z = position.Z }
    end
    if kind == "Color3" then
        return { __type = "Color3", r = value.R, g = value.G, b = value.B }
    end
    if kind == "BrickColor" then
        return { __type = "BrickColor", name = safeText(value.Name) }
    end
    if kind == "UDim2" then
        return {
            __type = "UDim2",
            x = { scale = value.X.Scale, offset = value.X.Offset },
            y = { scale = value.Y.Scale, offset = value.Y.Offset },
        }
    end
    if kind == "UDim" then
        return { __type = "UDim", scale = value.Scale, offset = value.Offset }
    end
    if kind == "EnumItem" then
        return { __type = "EnumItem", value = safeText(value) }
    end
    if kind == "NumberRange" then
        return { __type = "NumberRange", min = value.Min, max = value.Max }
    end
    if kind == "NumberSequence" or kind == "ColorSequence" or kind == "Rect" then
        return safeText(value)
    end
    if kind == "function" then
        return "<function>"
    end
    if kind == "table" then
        if depth <= 0 then
            return "<table>"
        end
        if seen[value] then
            return "<cycle>"
        end
        seen[value] = true
        local result = {}
        local count = 0
        local ok = pcall(function()
            for key, child in pairs(value) do
                count += 1
                if count > 200 then
                    result.__truncated = true
                    break
                end
                result[tostring(key)] = convert(child, depth - 1, seen)
            end
        end)
        seen[value] = nil
        if not ok then
            return safeText(value)
        end
        return result
    end
    return safeText(value)
end

function Serialize.Value(value, depth)
    local ok, result = pcall(convert, value, depth or 4, {})
    if ok then
        return result
    end
    return safeText(value)
end

function Serialize.Encode(value, maxChars)
    local converted = Serialize.Value(value)
    local ok, json = pcall(function()
        return HttpService:JSONEncode(converted)
    end)
    if not ok then
        json = safeText(converted)
    end
    if maxChars and #json > maxChars then
        local wrapOk, wrapped = pcall(function()
            return HttpService:JSONEncode({
                truncated = true,
                chars = #json,
                preview = json:sub(1, maxChars),
            })
        end)
        if wrapOk then
            return wrapped
        end
        return '{"truncated":true}'
    end
    return json
end

return Serialize
