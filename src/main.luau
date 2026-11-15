local Compat = require("./compat")
local Config = require("./config")
local UI = require("./ui/window")
local Tools = require("./tools/init")
local Loop = require("./agent/loop")
local Util = require("./util")

local environment = Compat.Environment

local previous = environment.WrenchAi
if type(previous) == "table" then
    if previous.loop then
        pcall(function()
            previous.loop:Cancel()
        end)
    end
    if previous.ui and previous.ui.gui then
        pcall(function()
            previous.ui.gui:Destroy()
        end)
    end
end

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

environment.WrenchAi = api
if type(_G) == "table" and _G ~= environment then
    pcall(function()
        _G.WrenchAi = api
    end)
end

return api
