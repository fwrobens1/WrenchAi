local HttpService = game:GetService("HttpService")
local Compat = require("./compat")
local Util = require("./util")

local Config = {}
local FOLDER = "WrenchAi"
local FILE = FOLDER .. "/config.json"

Config.Defaults = {
    baseURL = "https://api.refuseless.com/v1",
    model = "glm-5.3-abliterated",
    apiKey = "",
    temperature = 0.7,
    maxTokens = 2048,
    maxSteps = 12,
    maxToolChars = 9000,
    autoApproveScripts = false,
    cobaltURL = "https://raw.githubusercontent.com/Wortexios/CobaltSpy/refs/heads/main/Cobalt",
    dexURL = "https://github.com/Tesker-103/DexRecontinued/releases/latest/download/out.lua",
    extraSystemPrompt = "",
}

function Config.Path()
    return FILE
end

function Config.CanPersist()
    return Compat.Has("writefile")
end

local function merge(target, source)
    for key, value in pairs(source) do
        local default = target[key]
        if default ~= nil and type(default) == type(value) then
            target[key] = value
        end
    end
end

function Config.Load()
    local config = Util.Copy(Config.Defaults)

    local override = Compat.Environment.WrenchAiConfig
    if type(override) == "table" then
        merge(config, override)
    end

    local readfile = Compat.Lookup("readfile")
    local isfile = Compat.Lookup("isfile")
    if type(readfile) == "function" and type(isfile) == "function" then
        local existsOk, exists = pcall(isfile, FILE)
        if existsOk and exists then
            local readOk, raw = pcall(readfile, FILE)
            if readOk and type(raw) == "string" and #raw > 0 then
                local decodeOk, decoded = pcall(function()
                    return HttpService:JSONDecode(raw)
                end)
                if decodeOk and type(decoded) == "table" then
                    merge(config, decoded)
                end
            end
        end
    end

    return config
end

function Config.Save(config)
    local writefile = Compat.Lookup("writefile")
    if type(writefile) ~= "function" then
        return false, "This executor has no writefile; settings stay for this session only."
    end
    local makefolder = Compat.Lookup("makefolder")
    if type(makefolder) == "function" then
        pcall(makefolder, FOLDER)
    end
    local encodeOk, encoded = pcall(function()
        return HttpService:JSONEncode(config)
    end)
    if not encodeOk then
        return false, "Could not encode settings."
    end
    local saved, errorMessage = pcall(writefile, FILE, encoded)
    if not saved then
        return false, tostring(errorMessage)
    end
    return true
end

return Config
