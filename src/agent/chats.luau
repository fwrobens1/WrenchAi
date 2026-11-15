local HttpService = game:GetService("HttpService")
local Compat = require("../compat")
local Util = require("../util")

local Chats = {}
local FOLDER = "WrenchAi"
local FILE = FOLDER .. "/history.json"

Chats.MaxChats = 30
Chats.MaxMessages = 160
Chats.MaxChars = 60000

function Chats.NewId()
    return tostring(os.time()) .. "-" .. tostring(math.random(1000, 9999))
end

function Chats.TitleOf(text)
    local title = Util.Truncate(Util.Trim(text or ""), 34)
    if title == "" then
        return "New chat"
    end
    return title
end

function Chats.PreviewOf(messages)
    for index = #messages, 1, -1 do
        local message = messages[index]
        if message.role == "assistant" then
            local text = Util.Trim(tostring(message.content or ""))
            if text ~= "" and not Chats.IsProtocolJson(text) then
                return Util.Truncate(text, 72)
            end
        end
    end
    return ""
end

function Chats.IsProtocolJson(text)
    local value = Util.Trim(tostring(text or ""))
    local fenced = value:match("^```[%w]*%s*(.-)%s*```$")
    if fenced then
        value = Util.Trim(fenced)
    end
    if value:sub(1, 1) ~= "{" or value:sub(-1) ~= "}" then
        return false
    end
    return value:find('"tool"', 1, true) ~= nil
end

local function isTurnStart(message)
    if message.role ~= "user" then
        return false
    end
    return tostring(message.content or ""):sub(1, 13) ~= "[TOOL RESULT:"
end

local function messageChars(message)
    return #tostring(message.content or "") + #tostring(message.reasoning_content or "")
end

function Chats.Trim(messages)
    local kept = {}
    for index = math.max(1, #messages - Chats.MaxMessages + 1), #messages do
        table.insert(kept, messages[index])
    end

    local total = 0
    for _, message in ipairs(kept) do
        total += messageChars(message)
    end
    while total > Chats.MaxChars and #kept > 1 do
        local cut = nil
        for index = 2, #kept do
            if isTurnStart(kept[index]) then
                cut = index
                break
            end
        end
        if not cut then
            break
        end
        for index = 1, cut - 1 do
            total -= messageChars(kept[index])
        end
        local rest = {}
        for index = cut, #kept do
            table.insert(rest, kept[index])
        end
        kept = rest
    end
    return kept
end

function Chats.Load()
    local chats = {}
    local readfile = Compat.Lookup("readfile")
    local isfile = Compat.Lookup("isfile")
    if type(readfile) == "function" and type(isfile) == "function" then
        local existsOk, exists = pcall(isfile, FILE)
        if existsOk and exists then
            local readOk, raw = pcall(readfile, FILE)
            if readOk and type(raw) == "string" and #raw > 0 then
                local ok, decoded = pcall(function()
                    return HttpService:JSONDecode(raw)
                end)
                if ok and type(decoded) == "table" then
                    for _, chat in ipairs(decoded) do
                        if type(chat) == "table" and type(chat.id) == "string"
                            and type(chat.messages) == "table" then
                            table.insert(chats, {
                                id = chat.id,
                                title = type(chat.title) == "string" and chat.title or "New chat",
                                createdAt = tonumber(chat.createdAt) or os.time(),
                                messages = chat.messages,
                            })
                        end
                    end
                end
            end
        end
    end
    return chats
end

function Chats.Save(chats)
    local writefile = Compat.Lookup("writefile")
    if type(writefile) ~= "function" then
        return false
    end
    local makefolder = Compat.Lookup("makefolder")
    if type(makefolder) == "function" then
        pcall(makefolder, FOLDER)
    end
    local trimmed = {}
    for index = 1, math.min(#chats, Chats.MaxChats) do
        local chat = chats[index]
        table.insert(trimmed, {
            id = chat.id,
            title = chat.title,
            createdAt = chat.createdAt,
            messages = Chats.Trim(chat.messages or {}),
        })
    end
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(trimmed)
    end)
    if not ok then
        return false
    end
    pcall(writefile, FILE, encoded)
    return true
end

return Chats
