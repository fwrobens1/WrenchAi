-- Minimal Roblox/executor mock for headless smoke tests.
local G = {}

local Vector2 = {}
Vector2.__index = Vector2
local function newVector2(x, y)
    return setmetatable({ X = x or 0, Y = y or 0 }, Vector2)
end
Vector2.__add = function(a, b)
    return newVector2(a.X + b.X, a.Y + b.Y)
end
Vector2.__sub = function(a, b)
    return newVector2(a.X - b.X, a.Y - b.Y)
end
Vector2.__div = function(a, b)
    return newVector2(a.X / b, a.Y / b)
end
Vector2.__mul = function(a, b)
    return newVector2(a.X * b, a.Y * b)
end

local Vector3 = {}
Vector3.__index = Vector3
local function newVector3(x, y, z)
    return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
Vector3.__sub = function(a, b)
    return newVector3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end

local Color3 = {}
function Color3.fromRGB(r, g, b)
    return { R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 }
end

local UDim = {}
function UDim.new(scale, offset)
    return { Scale = scale or 0, Offset = offset or 0 }
end

local UDim2 = {}
function UDim2.new(xScale, xOffset, yScale, yOffset)
    return {
        X = { Scale = xScale or 0, Offset = xOffset or 0 },
        Y = { Scale = yScale or 0, Offset = yOffset or 0 },
    }
end
function UDim2.fromOffset(x, y)
    return UDim2.new(0, x or 0, 0, y or 0)
end
function UDim2.fromScale(x, y)
    return UDim2.new(x or 0, 0, y or 0, 0)
end

local ColorSequence = {}
function ColorSequence.new(first, second)
    return { first, second }
end

local enumCache = {}
local Enum = setmetatable({}, {
    __index = function(_, namespace)
        local items = {}
        local namespaceTable = setmetatable({}, {
            __index = function(_, key)
                local item = items[key]
                if not item then
                    item = { Name = key, Value = 0, namespace = namespace }
                    items[key] = item
                end
                return item
            end,
        })
        enumCache[namespace] = namespaceTable
        return namespaceTable
    end,
})

local Signal = {}
Signal.__index = Signal
function Signal.new()
    return setmetatable({ handlers = {} }, Signal)
end
function Signal:Connect(handler)
    table.insert(self.handlers, handler)
    return { Disconnect = function() end }
end
function Signal:Wait()
    return nil
end
function Signal:Fire(...)
    for _, handler in ipairs(self.handlers) do
        pcall(handler, ...)
    end
end

local SIGNAL_NAMES = {
    Activated = true,
    AnchorChanged = true,
    InputBegan = true,
    InputChanged = true,
    InputEnded = true,
    FocusLost = true,
    Focused = true,
    MouseButton1Click = true,
    MouseButton2Click = true,
    MouseButton1Down = true,
    MouseButton2Down = true,
    MouseEnter = true,
    MouseLeave = true,
    TextChanged = true,
}

local DEFAULTS = {
    Visible = true,
    Active = true,
    Text = "",
    AbsoluteSize = newVector2(0, 0),
    AbsolutePosition = newVector2(0, 0),
    AbsoluteCanvasSize = newVector2(0, 0),
    CanvasPosition = newVector2(0, 0),
}

local InstanceMock = {}
InstanceMock.__index = function(self, key)
    local props = rawget(self, "_props")
    local value = props[key]
    if value ~= nil then
        return value
    end
    if key == "Parent" then
        return nil
    end
    if SIGNAL_NAMES[key] then
        local signals = rawget(self, "_signals")
        local signal = signals[key]
        if not signal then
            signal = Signal.new()
            signals[key] = signal
        end
        return signal
    end
    local method = rawget(self, "_methods")[key]
    if method then
        return method
    end
    return DEFAULTS[key]
end

InstanceMock.__newindex = function(self, key, value)
    local props = rawget(self, "_props")
    if key == "Parent" then
        local previous = props.Parent
        if previous and previous._children then
            for index, child in ipairs(previous._children) do
                if child == self then
                    table.remove(previous._children, index)
                    break
                end
            end
        end
        props.Parent = value
        if value and value._children then
            table.insert(value._children, self)
        end
        return
    end
    props[key] = value
end

local function classNameOf(instance)
    return rawget(instance, "_props").ClassName or "Instance"
end

local METHODS = {}

function METHODS:IsA(query)
    local className = classNameOf(self)
    if query == "Instance" or query == className then
        return true
    end
    if query == "GuiObject" then
        return className:find("Gui") ~= nil
    end
    if query == "GuiButton" then
        return className == "TextButton" or className == "ImageButton"
    end
    if query == "LuaSourceContainer" then
        return className == "Script" or className == "LocalScript" or className == "ModuleScript"
    end
    return false
end

function METHODS:GetChildren()
    local result = {}
    for _, child in ipairs(rawget(self, "_children")) do
        table.insert(result, child)
    end
    return result
end

function METHODS:GetDescendants()
    local result = {}
    local function walk(instance)
        for _, child in ipairs(rawget(instance, "_children")) do
            table.insert(result, child)
            walk(child)
        end
    end
    walk(self)
    return result
end

function METHODS:FindFirstChild(name)
    for _, child in ipairs(rawget(self, "_children")) do
        if child.Name == name then
            return child
        end
    end
    return nil
end

function METHODS:FindFirstChildWhichIsA(query)
    for _, child in ipairs(rawget(self, "_children")) do
        if child:IsA(query) then
            return child
        end
    end
    return nil
end

function METHODS:WaitForChild(name)
    return self:FindFirstChild(name) or self
end

function METHODS:GetFullName()
    local props = rawget(self, "_props")
    local name = props.Name or "?"
    local parent = props.Parent
    if parent and parent.GetFullName then
        return parent:GetFullName() .. "." .. name
    end
    return name
end

function METHODS:GetDebugId()
    return "debug_" .. tostring(self):gsub("table: ", "")
end

function METHODS:GetAttributes()
    return {}
end

function METHODS:GetTags()
    return {}
end

function METHODS:GetPropertyChangedSignal()
    return Signal.new()
end

function METHODS:QueryDescendants()
    return {}
end

function METHODS:Clone()
    return Instance.new(classNameOf(self))
end

function METHODS:Destroy()
    self.Parent = nil
    rawset(self, "_destroyed", true)
end

function METHODS:CaptureFocus() end
function METHODS:ReleaseFocus() end
function METHODS:SendMouseMoveEvent() end
function METHODS:SendMouseButtonEvent() end
function METHODS:SendTextInput() end
function METHODS:SendKeyEvent() end
function METHODS:SendMouseWheelEvent() end

local Instance = {}
function Instance.new(className, parent)
    local instance = setmetatable({
        _props = { ClassName = className, Name = className },
        _signals = {},
        _children = {},
        _methods = METHODS,
    }, InstanceMock)
    if parent then
        instance.Parent = parent
    end
    return instance
end

local function quote(text)
    local escapes = {
        ['"'] = '\\"',
        ["\\"] = "\\\\",
        ["\n"] = "\\n",
        ["\r"] = "\\r",
        ["\t"] = "\\t",
        ["\b"] = "\\b",
        ["\f"] = "\\f",
    }
    local parts = {}
    for index = 1, #text do
        local char = text:sub(index, index)
        local escaped = escapes[char]
        if escaped then
            table.insert(parts, escaped)
        elseif char:byte() < 32 then
            table.insert(parts, string.format("\\u%04x", char:byte()))
        else
            table.insert(parts, char)
        end
    end
    return '"' .. table.concat(parts) .. '"'
end

local function encode(value)
    if value == nil then
        return "null"
    end
    local kind = typeof(value)
    if kind == "boolean" then
        return value and "true" or "false"
    end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return "null"
        end
        return tostring(value)
    end
    if kind == "string" then
        return quote(value)
    end
    if kind == "table" then
        local count = 0
        local maxIndex = 0
        for key in pairs(value) do
            count += 1
            if type(key) == "number" and key > maxIndex then
                maxIndex = key
            end
        end
        if count > 0 and maxIndex == count then
            local parts = {}
            for index = 1, count do
                parts[index] = encode(value[index])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local parts = {}
        for key, child in pairs(value) do
            table.insert(parts, quote(tostring(key)) .. ":" .. encode(child))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end

local function decode(text)
    local position = 1

    local function skip()
        while position <= #text do
            local char = text:sub(position, position)
            if char == " " or char == "\n" or char == "\r" or char == "\t" then
                position += 1
            else
                break
            end
        end
    end

    local parseValue

    local function parseString()
        position += 1
        local parts = {}
        while position <= #text do
            local char = text:sub(position, position)
            if char == '"' then
                position += 1
                return table.concat(parts)
            end
            if char == "\\" then
                local nextChar = text:sub(position + 1, position + 1)
                if nextChar == "n" then
                    table.insert(parts, "\n")
                    position += 2
                elseif nextChar == "t" then
                    table.insert(parts, "\t")
                    position += 2
                elseif nextChar == "r" then
                    table.insert(parts, "\r")
                    position += 2
                elseif nextChar == "b" then
                    table.insert(parts, "\b")
                    position += 2
                elseif nextChar == "f" then
                    table.insert(parts, "\f")
                    position += 2
                elseif nextChar == "u" then
                    local code = tonumber(text:sub(position + 2, position + 5), 16) or 63
                    table.insert(parts, utf8.char(code))
                    position += 6
                else
                    table.insert(parts, nextChar)
                    position += 2
                end
            else
                table.insert(parts, char)
                position += 1
            end
        end
        error("unterminated string")
    end

    function parseValue()
        skip()
        local char = text:sub(position, position)
        if char == '"' then
            return parseString()
        end
        if char == "{" then
            position += 1
            local object = {}
            skip()
            if text:sub(position, position) == "}" then
                position += 1
                return object
            end
            while true do
                skip()
                local key = parseString()
                skip()
                position += 1
                object[key] = parseValue()
                skip()
                local separator = text:sub(position, position)
                position += 1
                if separator == "}" then
                    break
                end
            end
            return object
        end
        if char == "[" then
            position += 1
            local array = {}
            skip()
            if text:sub(position, position) == "]" then
                position += 1
                return array
            end
            while true do
                table.insert(array, parseValue())
                skip()
                local separator = text:sub(position, position)
                position += 1
                if separator == "]" then
                    break
                end
            end
            return array
        end
        if text:sub(position, position + 3) == "true" then
            position += 4
            return true
        end
        if text:sub(position, position + 4) == "false" then
            position += 5
            return false
        end
        if text:sub(position, position + 3) == "null" then
            position += 4
            return nil
        end
        local number = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", position)
        if number then
            position += #number
            return tonumber(number)
        end
        error("unexpected JSON token at " .. position)
    end

    return parseValue()
end

local responses = {}

local HttpService = {
    JSONEncode = function(_, value)
        return encode(value)
    end,
    JSONDecode = function(_, text)
        return decode(text)
    end,
}

local playerGui = Instance.new("PlayerGui")
playerGui.Name = "PlayerGui"

local player = {
    Name = "Tester",
    DisplayName = "Tester",
    UserId = 12345,
    Character = nil,
    FindFirstChild = function(_, name)
        if name == "PlayerGui" then
            return playerGui
        end
        return nil
    end,
}

local players = {
    LocalPlayer = player,
    MaxPlayers = 10,
    PlayerGui = playerGui,
    GetPlayers = function()
        return { player }
    end,
    FindFirstChild = function(_, name)
        if name == "PlayerGui" then
            return playerGui
        end
        return nil
    end,
}

local coreGui = Instance.new("CoreGui")
coreGui.Name = "CoreGui"

local camera = {
    ViewportSize = newVector2(390, 844),
    GetPropertyChangedSignal = function()
        return Signal.new()
    end,
}
local workspaceMock = { CurrentCamera = camera }

local services = {
    Players = players,
    CoreGui = coreGui,
    HttpService = HttpService,
    TweenService = {
        Create = function(_, _, _, _)
            return {
                Play = function() end,
                Cancel = function() end,
                Pause = function() end,
            }
        end,
    },
    LogService = {
        GetLogHistory = function()
            return {}
        end,
    },
    MarketplaceService = {
        GetProductInfo = function()
            return { Name = "Test Place", Creator = { Name = "Tester" } }
        end,
    },
    GuiService = {
        GetGuiInset = function()
            return newVector2(0, 36), newVector2(0, 0)
        end,
    },
    RunService = {
        IsStudio = function()
            return false
        end,
        IsClient = function()
            return true
        end,
    },
    UserInputService = {
        TouchEnabled = true,
        KeyboardEnabled = false,
        InputEnded = Signal.new(),
    },
}

local gameMock = {
    PlaceId = 7100000000,
    GameId = 7100000000,
    JobId = "job-smoke",
    PlaceVersion = 1,
}

function gameMock:GetService(name)
    local service = services[name]
    if service then
        return service
    end
    service = Instance.new("Folder")
    service.Name = name
    services[name] = service
    return service
end

function gameMock:HttpGet()
    return nil
end

function gameMock:FindFirstChild()
    return nil
end

function gameMock:GetChildren()
    return { Instance.new("Part") }
end

function gameMock:GetFullName()
    return "game"
end

G.request = function(options)
    G.lastRequest = options
    local response = table.remove(responses, 1)
    if not response then
        return {
            StatusCode = 500,
            Body = '{"error":{"message":"no canned response left"}}',
        }
    end
    return response
end

G.isfile = nil
G.readfile = nil
G.writefile = nil

function G.pushResponse(body, status)
    table.insert(responses, { StatusCode = status or 200, Body = body })
end

function G.queuedResponses()
    return #responses
end

function getgenv()
    return G
end

getfenv = function()
    return _G
end

game = gameMock
workspace = workspaceMock
Instance = Instance
Color3 = Color3
ColorSequence = ColorSequence
UDim = UDim
UDim2 = UDim2
Vector2 = { new = newVector2 }
Vector3 = { new = newVector3 }
Enum = Enum
TweenInfo = {
    new = function(...)
        return { ... }
    end,
}

task = {
    wait = function()
        return 0
    end,
    spawn = function(fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then
            error(err, 0)
        end
    end,
    defer = function(fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then
            error(err, 0)
        end
    end,
    delay = function()
        return nil
    end,
    cancel = function() end,
}

-- G stays local; the smoke builder appends the bundle and checks below this file.
