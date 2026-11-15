local Util = require("../util")

local Shared = {}

local ALIASES = {
    workspace = "Workspace",
    players = "Players",
    lighting = "Lighting",
    replicatedstorage = "ReplicatedStorage",
    replicatedfirst = "ReplicatedFirst",
    startergui = "StarterGui",
    starterpack = "StarterPack",
    starterplayer = "StarterPlayer",
    serverscriptservice = "ServerScriptService",
    serverstorage = "ServerStorage",
    soundservice = "SoundService",
    chatservice = "Chat",
    textchatservice = "TextChatService",
    coregui = "CoreGui",
    runservice = "RunService",
    userinputservice = "UserInputService",
    httpservice = "HttpService",
}

function Shared.ResolvePath(expression)
    local text = Util.Trim(expression)
    if text == "" or text == "game" then
        return game
    end
    text = text:gsub("^game%s*%.%s*", "")
    local current = game

    for segment in text:gmatch("[^%.]+") do
        segment = Util.Trim(segment)
        if segment ~= "" then
            local nextInstance = nil
            if current == game then
                local ok, service = pcall(function()
                    return game:GetService(segment)
                end)
                if ok and service then
                    nextInstance = service
                end
                if not nextInstance then
                    local ok2, found = pcall(function()
                        return game:FindFirstChild(segment)
                    end)
                    if ok2 then
                        nextInstance = found
                    end
                end
                if not nextInstance then
                    local alias = ALIASES[string.lower(segment)]
                    if alias then
                        local ok3, service = pcall(function()
                            return game:GetService(alias)
                        end)
                        if ok3 then
                            nextInstance = service
                        end
                    end
                end
            else
                local ok, child = pcall(function()
                    return current:FindFirstChild(segment)
                end)
                if ok then
                    nextInstance = child
                end
            end

            if not nextInstance then
                local names = {}
                local childrenOk, children = pcall(function()
                    return current:GetChildren()
                end)
                if childrenOk then
                    for _, child in ipairs(children) do
                        table.insert(names, child.Name)
                        if #names >= 20 then
                            break
                        end
                    end
                end
                return nil,
                    "Could not find '"
                        .. segment
                        .. "' under "
                        .. (current and current:GetFullName() or "?")
                        .. ". Children: "
                        .. table.concat(names, ", ")
            end
            current = nextInstance
        end
    end

    return current
end

function Shared.Describe(instance)
    local description = { name = instance.Name, class = instance.ClassName }
    pcall(function()
        description.path = instance:GetFullName()
    end)
    pcall(function()
        description.debugId = instance:GetDebugId()
    end)
    return description
end

function Shared.GetScripts(root, includeDetached, compat)
    local scripts = {}
    local seen = {}
    local function add(instance)
        local ok, isSource = pcall(function()
            return instance:IsA("LuaSourceContainer")
        end)
        if not ok or not isSource or seen[instance] then
            return
        end
        seen[instance] = true
        table.insert(scripts, instance)
    end

    if root then
        local ok, descendants = pcall(function()
            return root:GetDescendants()
        end)
        if ok then
            for _, instance in ipairs(descendants) do
                add(instance)
            end
        end
        add(root)
    end

    if includeDetached and compat then
        local getNilInstances = compat.Lookup("getnilinstances")
        if type(getNilInstances) == "function" then
            local ok, instances = pcall(getNilInstances)
            if ok and type(instances) == "table" then
                for _, instance in ipairs(instances) do
                    add(instance)
                end
            end
        end
    end

    return scripts
end

function Shared.RebuildScriptIndex(ctx)
    local index = { byDebugId = {}, scripts = {} }
    for _, script in ipairs(Shared.GetScripts(game, true, ctx.compat)) do
        local debugId = nil
        pcall(function()
            debugId = script:GetDebugId()
        end)
        if debugId then
            index.byDebugId[debugId] = script
        end
        table.insert(index.scripts, script)
    end
    ctx.scriptIndex = index
    return index
end

function Shared.GetScriptIndex(ctx)
    return ctx.scriptIndex or Shared.RebuildScriptIndex(ctx)
end

function Shared.FindScript(ctx, args)
    if type(args.debugId) == "string" and args.debugId ~= "" then
        local index = Shared.GetScriptIndex(ctx)
        local script = index.byDebugId[args.debugId]
        if not script then
            index = Shared.RebuildScriptIndex(ctx)
            script = index.byDebugId[args.debugId]
        end
        if not script then
            return nil, "No loaded script has debugId '" .. args.debugId .. "'. Call list_scripts."
        end
        return script
    end
    if type(args.path) == "string" and args.path ~= "" then
        local instance, errorMessage = Shared.ResolvePath(args.path)
        if not instance then
            return nil, errorMessage
        end
        local ok, isSource = pcall(function()
            return instance:IsA("LuaSourceContainer")
        end)
        if not ok or not isSource then
            return nil, "That path is a " .. instance.ClassName .. ", not a script."
        end
        return instance
    end
    return nil, "Provide either path or debugId."
end

function Shared.StripBanner(source)
    if type(source) ~= "string" then
        return source
    end
    return (source:gsub("^%s*%-%-[^\n]*[Dd]ecompiled[^\n]*\n", "", 1))
end

function Shared.StringProperty(description, defaultValue)
    local property = { type = "string", description = description }
    if defaultValue ~= nil then
        property.default = defaultValue
    end
    return property
end

function Shared.IntProperty(description, defaultValue, minimum, maximum)
    local property = { type = "integer", description = description }
    if defaultValue ~= nil then
        property.default = defaultValue
    end
    if minimum ~= nil then
        property.minimum = minimum
    end
    if maximum ~= nil then
        property.maximum = maximum
    end
    return property
end

function Shared.BoolProperty(description, defaultValue)
    local property = { type = "boolean", description = description }
    if defaultValue ~= nil then
        property.default = defaultValue
    end
    return property
end

function Shared.ArrayProperty(description, itemType)
    return { type = "array", description = description, items = { type = itemType or "string" } }
end

return Shared
