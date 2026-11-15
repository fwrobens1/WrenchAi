local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local LogService = game:GetService("LogService")
local Serialize = require("../serialize")
local Shared = require("./shared")
local Util = require("../util")

local function matchSelector(instance, selector)
    local lowered = string.lower(selector)
    if lowered:sub(1, 1) == "#" then
        return string.lower(instance.Name) == lowered:sub(2)
    end
    if lowered:sub(1, 1) == "." then
        return string.lower(instance.ClassName) == lowered:sub(2)
    end
    if string.lower(instance.ClassName) == lowered or string.lower(instance.Name) == lowered then
        return true
    end
    return string.find(string.lower(instance.Name), lowered, 1, true) ~= nil
end

local function searchFallback(root, selector, limit)
    local results = {}
    local visited = 0
    local queue = { root }
    local head = 1
    while head <= #queue and #results < limit and visited < 6000 do
        local current = queue[head]
        head += 1
        local ok, children = pcall(function()
            return current:GetChildren()
        end)
        if ok then
            for _, child in ipairs(children) do
                visited += 1
                if matchSelector(child, selector) then
                    table.insert(results, child)
                    if #results >= limit then
                        break
                    end
                end
                table.insert(queue, child)
                if visited >= 6000 then
                    break
                end
            end
        end
    end
    return results, visited
end

local PROPERTY_GROUPS = {
    "Name", "ClassName", "Parent", "Archivable", "Attributes", "Tags",
    "Visible", "Enabled", "Text", "TextColor3", "TextSize", "Font", "PlaceholderText",
    "BackgroundColor3", "BackgroundTransparency", "Image", "ImageColor3", "ImageTransparency",
    "Size", "Position", "AnchorPoint", "ZIndex", "LayoutOrder", "AbsoluteSize", "AbsolutePosition",
    "Rotation", "BorderSizePixel", "TextWrapped", "TextScaled", "RichText", "AutoButtonColor",
    "Position", "Orientation", "CFrame", "Anchored", "CanCollide", "CanTouch", "CanQuery",
    "Transparency", "Color", "Material", "Massless", "AssemblyLinearVelocity", "AssemblyAngularVelocity",
    "Value", "Health", "MaxHealth", "WalkSpeed", "JumpPower", "JumpHeight", "HipHeight",
    "Brightness", "Range", "Shadows", "Volume", "SoundId", "Playing", "Looped",
    "Disabled", "RunContext", "MaxPlayers", "DisplayName", "UserId", "Character",
}

local function getPropertyList(instance, requested)
    if type(requested) == "table" and #requested > 0 then
        return requested
    end
    local names = {}
    local seen = {}
    for _, name in ipairs(PROPERTY_GROUPS) do
        if not seen[name] then
            seen[name] = true
            table.insert(names, name)
        end
    end
    return names
end

local function readProperties(instance, requested)
    local properties = {}
    local names = getPropertyList(instance, requested)
    local truncated = false
    if #names > 60 then
        truncated = true
        names = { table.unpack(names, 1, 60) }
    end
    for _, name in ipairs(names) do
        if name ~= "Source" then
            local ok, value = pcall(function()
                return instance[name]
            end)
            if ok and value ~= nil then
                properties[name] = Serialize.Value(value, 3)
            end
        end
    end
    local attributes = nil
    pcall(function()
        attributes = instance:GetAttributes()
    end)
    local tags = nil
    pcall(function()
        tags = instance:GetTags()
    end)
    return properties, attributes, tags, truncated
end

return {
    {
        name = "get_game_info",
        description = "Return place, job, player, platform, executor name/version, and available executor capabilities.",
        parameters = {
            type = "object",
            properties = {
                includePlaceName = Shared.BoolProperty("Fetch the place name and creator from MarketplaceService.", false),
            },
        },
        run = function(args, ctx)
            local localPlayer = Players.LocalPlayer
            local player = nil
            if localPlayer then
                player = {
                    name = localPlayer.Name,
                    displayName = localPlayer.DisplayName,
                    userId = localPlayer.UserId,
                    character = localPlayer.Character and localPlayer.Character:GetFullName() or nil,
                }
            end
            local info = {
                placeId = game.PlaceId,
                gameId = game.GameId,
                jobId = game.JobId,
                placeVersion = game.PlaceVersion,
                player = player,
                platform = UserInputService.TouchEnabled and "mobile" or "desktop",
                studio = RunService:IsStudio(),
                maxPlayers = Players.MaxPlayers,
                executor = ctx.compat.Diagnostics(),
            }
            if args.includePlaceName then
                local ok, product = pcall(function()
                    return MarketplaceService:GetProductInfo(game.PlaceId)
                end)
                if ok and type(product) == "table" then
                    info.placeName = product.Name
                    info.creator = product.Creator and product.Creator.Name or nil
                    info.creatorType = product.Creator and tostring(product.Creator.CreatorType) or nil
                end
            end
            return { ok = true, data = info }
        end,
    },
    {
        name = "search_instances",
        description = "Find instances under a root using a Roblox selector (ClassName, #Name, .ClassName) or a name/class substring.",
        parameters = {
            type = "object",
            properties = {
                root = Shared.StringProperty("Root path, for example game.Workspace or Players.LocalPlayer.PlayerGui.", "game"),
                selector = Shared.StringProperty("Selector or name/class substring.", nil),
                limit = Shared.IntProperty("Maximum results.", 30, 1, 100),
            },
            required = { "selector" },
        },
        run = function(args, ctx)
            local selector = Util.Trim(args.selector or "")
            if selector == "" then
                return { ok = false, error = "selector is required." }
            end
            local root, rootError = Shared.ResolvePath(args.root or "game")
            if not root then
                return { ok = false, error = rootError }
            end
            local limit = Util.Clamp(tonumber(args.limit) or 30, 1, 100)
            local matches = nil
            local usedFallback = false
            if type(root.QueryDescendants) == "function" then
                local ok, result = pcall(function()
                    return root:QueryDescendants(selector)
                end)
                if ok and type(result) == "table" and #result > 0 then
                    matches = result
                end
            end
            if not matches then
                usedFallback = true
                matches = searchFallback(root, selector, limit)
            end

            local results = {}
            for index = 1, math.min(#matches, limit) do
                table.insert(results, Shared.Describe(matches[index]))
            end
            return {
                ok = true,
                data = {
                    root = root:GetFullName(),
                    selector = selector,
                    count = #matches,
                    returned = #results,
                    truncated = #matches > limit,
                    fallback = usedFallback,
                    results = results,
                },
            }
        end,
    },
    {
        name = "get_descendants_tree",
        description = "Return a bounded hierarchy under a root with depth and children limits. Use summaryOnly for class counts.",
        parameters = {
            type = "object",
            properties = {
                root = Shared.StringProperty("Root path.", "game"),
                maxDepth = Shared.IntProperty("How many levels below the root to visit.", 2, 0, 5),
                maxChildren = Shared.IntProperty("Maximum children per instance.", 20, 1, 40),
                classFilter = Shared.StringProperty("Only report instances that IsA this class.", ""),
                summaryOnly = Shared.BoolProperty("Return only class counts.", false),
            },
        },
        run = function(args, ctx)
            local root, rootError = Shared.ResolvePath(args.root or "game")
            if not root then
                return { ok = false, error = rootError }
            end
            local maxDepth = Util.Clamp(tonumber(args.maxDepth) or 2, 0, 5)
            local maxChildren = Util.Clamp(tonumber(args.maxChildren) or 20, 1, 40)
            local classFilter = Util.Trim(args.classFilter or "")
            local summaryOnly = args.summaryOnly == true
            local budget = 300
            local visited = 0
            local truncated = false
            local nodes = {}
            local classCounts = {}

            if classFilter ~= "" then
                local ok, isA = pcall(function()
                    return root:IsA(classFilter)
                end)
                if not ok then
                    return { ok = false, error = "Invalid classFilter: " .. classFilter }
                end
            end

            local function walk(instance, depth)
                if depth > maxDepth or visited >= budget then
                    return
                end
                local ok, children = pcall(function()
                    return instance:GetChildren()
                end)
                if not ok then
                    return
                end
                for index, child in ipairs(children) do
                    if index > maxChildren then
                        truncated = true
                        break
                    end
                    local matches = true
                    if classFilter ~= "" then
                        local matchOk, isA = pcall(function()
                            return child:IsA(classFilter)
                        end)
                        matches = matchOk and isA
                    end
                    if matches then
                        visited += 1
                        if visited > budget then
                            truncated = true
                            return
                        end
                        classCounts[child.ClassName] = (classCounts[child.ClassName] or 0) + 1
                        if not summaryOnly then
                            table.insert(nodes, {
                                path = child:GetFullName(),
                                class = child.ClassName,
                                depth = depth,
                            })
                        end
                    end
                    if depth < maxDepth then
                        walk(child, depth + 1)
                    end
                    if visited >= budget then
                        truncated = true
                        return
                    end
                end
            end

            walk(root, 1)
            local data = {
                root = root:GetFullName(),
                visited = visited,
                truncated = truncated,
                classCounts = classCounts,
            }
            if not summaryOnly then
                data.nodes = nodes
            end
            return { ok = true, data = data }
        end,
    },
    {
        name = "get_properties",
        description = "Read serializable properties, attributes, and tags from one instance. Use read_script for script source.",
        parameters = {
            type = "object",
            properties = {
                path = Shared.StringProperty("Instance path.", nil),
                properties = Shared.ArrayProperty("Optional list of property names to read.", "string"),
            },
            required = { "path" },
        },
        run = function(args, ctx)
            local instance, pathError = Shared.ResolvePath(args.path or "")
            if not instance then
                return { ok = false, error = pathError }
            end
            local properties, attributes, tags, truncated = readProperties(instance, args.properties)
            return {
                ok = true,
                data = {
                    path = instance:GetFullName(),
                    class = instance.ClassName,
                    properties = properties,
                    attributes = attributes,
                    tags = tags,
                    truncated = truncated,
                },
            }
        end,
    },
    {
        name = "get_console_logs",
        description = "Return recent Roblox client console log lines, optionally filtered by a substring.",
        parameters = {
            type = "object",
            properties = {
                limit = Shared.IntProperty("Number of lines to return.", 40, 1, 200),
                filter = Shared.StringProperty("Only return lines containing this substring.", ""),
            },
        },
        run = function(args, ctx)
            local limit = Util.Clamp(tonumber(args.limit) or 40, 1, 200)
            local filter = Util.Trim(args.filter or "")
            local ok, history = pcall(function()
                return LogService:GetLogHistory()
            end)
            if not ok or type(history) ~= "table" then
                return { ok = false, error = "LogService:GetLogHistory is unavailable on this executor." }
            end
            local entries = {}
            for index = #history, 1, -1 do
                local entry = history[index]
                local message = tostring(entry.message or "")
                if filter == "" or string.find(string.lower(message), string.lower(filter), 1, true) then
                    table.insert(entries, {
                        message = Util.Truncate(message, 500),
                        kind = tostring(entry.messageType),
                        timestamp = entry.timestamp,
                    })
                    if #entries >= limit then
                        break
                    end
                end
            end
            return {
                ok = true,
                data = {
                    count = #entries,
                    totalHistory = #history,
                    filter = filter,
                    entries = entries,
                },
            }
        end,
    },
}
