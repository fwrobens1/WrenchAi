local Players = game:GetService("Players")
local Compat = require("./compat")
local Config = require("./config")
local UI = require("./ui/window")
local Tools = require("./tools/init")
local Loop = require("./agent/loop")
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
local loop = Loop.new({ ui = ui, tools = tools, config = config, compat = Compat })

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
    loop:Send(text)
end

ui.callbacks.onStop = function()
    loop:Cancel()
end

ui.callbacks.onNewChat = function()
    loop:Reset()
    ui:ClearMessages()
    ui:SetStatus("Ready")
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

local api = {
    ui = ui,
    loop = loop,
    tools = tools,
    config = ctx.config,
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
