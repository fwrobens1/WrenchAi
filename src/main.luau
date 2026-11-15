local Players = game:GetService("Players")
local Compat = require("./compat")
local Config = require("./config")
local UI = require("./ui/window")
local Tools = require("./tools/init")
local Loop = require("./agent/loop")
local Chats = require("./agent/chats")
local Util = require("./util")

local environment = Compat.Environment

local function guiParents()
    local parents = {}
    local function add(parent)
        if parent then
            table.insert(parents, parent)
        end
    end
    local gethui = Compat.Lookup("gethui")
    if type(gethui) == "function" then
        local ok, parent = pcall(gethui)
        if ok then
            add(parent)
        end
    end
    add(Players.LocalPlayer:FindFirstChild("PlayerGui"))
    local ok, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok then
        add(coreGui)
    end
    return parents
end

local function destroyLeftoverGuis()
    for _, parent in ipairs(guiParents()) do
        local ok, children = pcall(function()
            return parent:GetChildren()
        end)
        if ok and type(children) == "table" then
            for _, child in ipairs(children) do
                local nameOk, name = pcall(function()
                    return child.Name
                end)
                if nameOk and name == "WrenchAi" then
                    pcall(function()
                        child:Destroy()
                    end)
                end
            end
        end
    end
end

local function unloadPrevious()
    local previous = environment.WrenchAi
    if type(previous) == "table" then
        if type(previous.unload) == "function" then
            pcall(previous.unload)
        end
        if previous.loop and type(previous.loop.Cancel) == "function" then
            pcall(function()
                previous.loop:Cancel()
            end)
        end
        if previous.ui and type(previous.ui.Destroy) == "function" then
            pcall(function()
                previous.ui:Destroy()
            end)
        end
    end
    environment.WrenchAi = nil
    destroyLeftoverGuis()
end

unloadPrevious()

local config = Config.Load()
local ui = UI.new({ config = config, compat = Compat, callbacks = {} })

local ctx = {
    config = config,
    compat = Compat,
    ui = ui,
    scriptCache = {},
    scriptIndex = nil,
    dexSource = nil,
}

local tools = Tools.new(ctx)
local chats = Chats.Load()
local currentId = nil

local loop
loop = Loop.new({
    ui = ui,
    tools = tools,
    config = config,
    compat = Compat,
    onDone = function()
        local chat = nil
        for _, entry in ipairs(chats) do
            if entry.id == currentId then
                chat = entry
                break
            end
        end
        if chat then
            chat.messages = loop:GetMessages()
            chat.preview = Chats.PreviewOf(chat.messages)
            Chats.Save(chats)
            ui:RenderSessions(chats, currentId)
        end
    end,
})

local function persistChats()
    Chats.Save(chats)
    ui:RenderSessions(chats, currentId)
end

local function findChat(id)
    for _, entry in ipairs(chats) do
        if entry.id == id then
            return entry
        end
    end
    return nil
end

local function ensureChat(text)
    if currentId ~= nil then
        return
    end
    local chat = {
        id = Chats.NewId(),
        title = Chats.TitleOf(text),
        createdAt = os.time(),
        preview = "",
        messages = {},
    }
    table.insert(chats, 1, chat)
    while #chats > Chats.MaxChats do
        table.remove(chats)
    end
    currentId = chat.id
end

local function replayChat(messages)
    local start = math.max(1, #messages - 60)
    for index = start, #messages do
        local message = messages[index]
        if message.role == "user" then
            local text = tostring(message.content or "")
            if text:sub(1, 13) ~= "[TOOL RESULT:" then
                ui:AddMessage("user", text)
            end
        elseif message.role == "assistant" then
            local text = tostring(message.content or "")
            if Util.Trim(text) ~= "" and not Chats.IsProtocolJson(text) then
                ui:AddMessage("assistant", text)
            end
        end
    end
end

ctx.isCancelled = function()
    return loop:IsCancelled()
end

ctx.approve = function(spec)
    return ui:AskApproval(spec, ctx.isCancelled)
end

ctx.setAutoApprove = function(value)
    local enabled = value == true
    ctx.config.autoApproveScripts = enabled
    if ui.pendingAutoApprove ~= enabled then
        ui.pendingAutoApprove = enabled
        ui:UpdateAutoApproveLabel()
    end
    Config.Save(ctx.config)
end

ui.callbacks.onSend = function(text)
    if Util.Trim(ctx.config.apiKey or "") == "" then
        ui:AddError("No API key yet. Open Settings and paste the key for " .. tostring(ctx.config.baseURL) .. ".")
        ui:OpenSettings()
        return
    end
    ensureChat(text)
    loop:Send(text)
end

ui.callbacks.onStop = function()
    loop:Cancel()
end

ui.callbacks.onNewChat = function()
    if loop.running then
        return
    end
    loop:Reset()
    ui:ClearMessages()
    ui:SetStatus("Ready")
    currentId = nil
    ui:RenderSessions(chats, nil)
end

ui.callbacks.onSwitchChat = function(id)
    if loop.running or id == currentId then
        return
    end
    local target = findChat(id)
    if not target then
        return
    end
    local previous = findChat(currentId)
    if previous then
        previous.messages = loop:GetMessages()
        previous.preview = Chats.PreviewOf(previous.messages)
    end
    currentId = id
    loop:SetMessages(target.messages or {})
    ui:ClearMessages()
    replayChat(target.messages or {})
    ui:SetStatus("Ready")
    persistChats()
    ui:CloseSessions()
end

ui.callbacks.onDeleteChat = function(id)
    if loop.running then
        return
    end
    for index, entry in ipairs(chats) do
        if entry.id == id then
            table.remove(chats, index)
            break
        end
    end
    if currentId == id then
        currentId = nil
        loop:Reset()
        ui:ClearMessages()
        ui:SetStatus("Ready")
    end
    persistChats()
end

ui.callbacks.onSaveSettings = function(newConfig)
    for key, value in pairs(newConfig) do
        ctx.config[key] = value
    end
    loop:RefreshConfig(ctx.config)
    local saved, message = Config.Save(ctx.config)
    if saved then
        return true, "Saved."
    end
    return true, "Applied for this session. " .. tostring(message or "The executor could not write the settings file.")
end

ui:SetStatus("Ready")
ui:AddSystem(
    "WrenchAi is running in "
        .. tostring(Compat.ExecutorName)
        .. ". I can inspect the game, read scripts, drive the GUI, use Cobalt, and run Luau when you approve it."
)

if not Compat.Has("request") then
    ui:AddError("This executor exposes no HTTP function (request/http_request/syn.request), so the model cannot be reached.")
end

if Util.Trim(ctx.config.apiKey or "") == "" then
    ui:AddError("No API key configured. Settings is open; enter the key once and press Save settings.")
    ui:OpenSettings()
end

ui:RenderSessions(chats, nil)

local api = {
    ui = ui,
    loop = loop,
    tools = tools,
    config = ctx.config,
    chats = chats,
    toggle = function()
        ui:Toggle()
    end,
}

api.unload = function()
    pcall(function()
        loop:Cancel()
    end)
    if ui.Destroy then
        pcall(function()
            ui:Destroy()
        end)
    end
    if environment.WrenchAi == api then
        environment.WrenchAi = nil
    end
    if type(_G) == "table" and _G ~= environment and _G.WrenchAi == api then
        pcall(function()
            _G.WrenchAi = nil
        end)
    end
    destroyLeftoverGuis()
end

environment.WrenchAi = api
if type(_G) == "table" and _G ~= environment then
    pcall(function()
        _G.WrenchAi = api
    end)
end

return api
