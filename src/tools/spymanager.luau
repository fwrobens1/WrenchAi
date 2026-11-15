local Serialize = require("../serialize")
local Util = require("../util")

local SpyManager = {}
SpyManager.__index = SpyManager

local LOAD_TIMEOUT = 30

function SpyManager.new(ctx)
    return setmetatable({ ctx = ctx }, SpyManager)
end

function SpyManager:Wax()
    local environment = self.ctx.compat.Environment
    local ok, wax = pcall(function()
        return environment.Cobalt
    end)
    if ok and type(wax) == "table" then
        return wax
    end
    if type(_G) == "table" and _G ~= environment then
        local globalOk, globalWax = pcall(function()
            return _G.Cobalt
        end)
        if globalOk and type(globalWax) == "table" then
            return globalWax
        end
    end
    return nil
end

function SpyManager:Logs()
    local wax = self:Wax()
    if not wax or type(wax.shared) ~= "table" then
        return nil, nil
    end
    if type(wax.shared.Logs) ~= "table" then
        return nil, wax
    end
    return wax.shared.Logs, wax
end

function SpyManager:Loaded()
    local logs = self:Logs()
    return logs ~= nil
end

function SpyManager:EnsureLoaded()
    if self:Loaded() then
        return true, "Cobalt is already loaded."
    end

    local environment = self.ctx.compat.Environment
    local initialized = false
    pcall(function()
        initialized = environment.CobaltInitialized == true
    end)

    if not initialized then
        local source, downloadError = self.ctx.compat.HttpGet(self.ctx.config.cobaltURL)
        if not source then
            return false, "Could not download Cobalt: " .. tostring(downloadError)
        end
        local loadstringFunction = self.ctx.compat.Lookup("loadstring")
        if type(loadstringFunction) ~= "function" then
            return false, "This executor has no loadstring, so Cobalt cannot be loaded."
        end
        local chunk, compileError = loadstringFunction(source)
        if not chunk then
            return false, "Cobalt failed to compile: " .. tostring(compileError)
        end
        local ok, runError = pcall(chunk)
        if not ok then
            return false, "Cobalt failed to load: " .. tostring(runError)
        end
    end

    local deadline = os.clock() + LOAD_TIMEOUT
    while os.clock() < deadline do
        if self:Loaded() then
            task.wait(2)
            return true, "Cobalt loaded."
        end
        task.wait(0.25)
    end

    return false,
        "Cobalt did not publish its log table within "
            .. tostring(LOAD_TIMEOUT)
            .. "s. Check the Cobalt window for an executor compatibility error."
end

local function summarizeCall(call, includeArguments)
    local summary = {
        createdAt = call.CreationTime,
        line = call.Line,
        source = call.Source,
        isExecutor = call.IsExecutor,
        path = call.Path,
    }
    if includeArguments then
        local arguments = call.Arguments
        if type(arguments) == "table" and arguments.Data ~= nil then
            arguments = arguments.Data
        end
        summary.arguments = Serialize.Encode(arguments, 900)
        if call.OriginalInvokeArgs ~= nil then
            local original = call.OriginalInvokeArgs
            if type(original) == "table" and original.Data ~= nil then
                original = original.Data
            end
            summary.invokeArguments = Serialize.Encode(original, 500)
        end
    end
    local fn = call.Function
    if type(fn) == "table" then
        summary.functionName = fn.Name
        summary.functionAddress = fn.Address
    elseif type(fn) == "function" then
        pcall(function()
            summary.functionName = debug.info(fn, "n")
        end)
    end
    return summary
end

function SpyManager:FindLog(category, path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    for instance, log in pairs(category) do
        local fullName = nil
        pcall(function()
            fullName = instance:GetFullName()
        end)
        if fullName == path or instance.Name == path then
            return log, instance
        end
    end
    return nil
end

function SpyManager:AvailablePaths(category, limit)
    local paths = {}
    for instance, log in pairs(category) do
        if type(log.Calls) == "table" and #log.Calls > 0 then
            local fullName = nil
            pcall(function()
                fullName = instance:GetFullName()
            end)
            table.insert(paths, fullName or instance.Name)
            if #paths >= (limit or 12) then
                break
            end
        end
    end
    return paths
end

function SpyManager:GetCalls(direction, limit, filter, includeArguments, callsPerRemote)
    local logs, wax = self:Logs()
    if not logs then
        return { ok = false, error = "Cobalt is not loaded." }
    end
    local category = logs[direction]
    if type(category) ~= "table" then
        return { ok = false, error = "Cobalt has no " .. tostring(direction) .. " log category." }
    end

    local loweredFilter = string.lower(Util.Trim(filter or ""))
    local entries = {}
    for instance, log in pairs(category) do
        local calls = log.Calls
        if type(calls) == "table" and #calls > 0 then
            local path, className = nil, nil
            pcall(function()
                path = instance:GetFullName()
                className = instance.ClassName
            end)
            path = path or instance.Name
            if loweredFilter == "" or string.find(string.lower(path), loweredFilter, 1, true) then
                local latest = calls[#calls]
                local entry = {
                    path = path,
                    class = className,
                    method = log.Method,
                    type = log.Type or direction,
                    callCount = #calls,
                    blocked = log.Blocked == true,
                    ignored = log.Ignored == true,
                    sortTime = latest and latest.CreationTime or 0,
                }
                if callsPerRemote <= 1 then
                    entry.latest = summarizeCall(latest, includeArguments)
                else
                    entry.recent = {}
                    local first = math.max(1, #calls - callsPerRemote + 1)
                    for index = first, #calls do
                        table.insert(entry.recent, summarizeCall(calls[index], includeArguments))
                    end
                end
                table.insert(entries, entry)
            end
        end
    end

    table.sort(entries, function(left, right)
        return (left.sortTime or 0) > (right.sortTime or 0)
    end)

    local total = #entries
    while #entries > limit do
        table.remove(entries)
    end
    for _, entry in ipairs(entries) do
        entry.sortTime = nil
    end

    return {
        ok = true,
        data = {
            direction = direction,
            totalRemotes = total,
            returned = #entries,
            truncated = total > limit,
            calls = entries,
            hint = (total == 0 and "No calls captured yet. Interact with the game or confirm Cobalt's hooks are active." or nil),
        },
    }
end

function SpyManager:Clear(direction, filter)
    local logs, wax = self:Logs()
    if not logs then
        return { ok = false, error = "Cobalt is not loaded." }
    end
    local directions = { direction }
    if direction == "All" then
        directions = { "Outgoing", "Incoming" }
    end

    local instanceFilter = nil
    if type(filter) == "string" and filter ~= "" then
        for _, name in ipairs(directions) do
            local category = logs[name]
            if type(category) == "table" then
                local _, instance = self:FindLog(category, filter)
                if instance then
                    instanceFilter = instance
                    break
                end
            end
        end
        if not instanceFilter then
            return { ok = false, error = "No Cobalt log matches path '" .. tostring(filter) .. "'." }
        end
    end

    local clearedCalls = 0
    for _, name in ipairs(directions) do
        local category = logs[name]
        if type(category) == "table" then
            for instance, log in pairs(category) do
                if not instanceFilter or instance == instanceFilter then
                    if type(log.Calls) == "table" then
                        clearedCalls += #log.Calls
                    end
                end
            end
        end
    end

    local clearFunction = wax.shared.ClearLogs
    if type(clearFunction) ~= "function" then
        return { ok = false, error = "Cobalt's ClearLogs function is unavailable." }
    end
    local ok, errorMessage = pcall(clearFunction, instanceFilter, direction == "All" and nil or direction)
    if not ok then
        return { ok = false, error = "Cobalt could not clear logs: " .. tostring(errorMessage) }
    end
    return {
        ok = true,
        data = { direction = direction, filter = filter, clearedCalls = clearedCalls },
    }
end

function SpyManager:SetState(direction, path, block, ignore)
    local logs = self:Logs()
    if not logs then
        return { ok = false, error = "Cobalt is not loaded." }
    end
    local category = logs[direction]
    if type(category) ~= "table" then
        return { ok = false, error = "Cobalt has no " .. tostring(direction) .. " log category." }
    end

    local log, instance = self:FindLog(category, path)
    if not log then
        local paths = self:AvailablePaths(category, 12)
        return {
            ok = false,
            error = "No " .. direction .. " log for '" .. tostring(path) .. "'. Known remotes: " .. table.concat(paths, ", "),
        }
    end

    local changed = {}
    if type(block) == "boolean" and (log.Blocked == true) ~= block then
        local ok, errorMessage = pcall(function()
            log:Block()
        end)
        if not ok then
            return { ok = false, error = "Block failed: " .. tostring(errorMessage) }
        end
        changed.block = true
    end
    if type(ignore) == "boolean" and (log.Ignored == true) ~= ignore then
        local ok, errorMessage = pcall(function()
            log:Ignore()
        end)
        if not ok then
            return { ok = false, error = "Ignore failed: " .. tostring(errorMessage) }
        end
        changed.ignore = true
    end

    return {
        ok = true,
        data = {
            path = instance and instance:GetFullName() or path,
            direction = direction,
            blocked = log.Blocked == true,
            ignored = log.Ignored == true,
            changed = changed,
        },
    }
end

function SpyManager:Status()
    local logs, wax = self:Logs()
    if not logs then
        return { ok = true, data = { loaded = false, hint = "Call spy_open to load Cobalt." } }
    end

    local counts = {}
    for direction, category in pairs(logs) do
        local remotes = 0
        local calls = 0
        local blocked = 0
        local ignored = 0
        for _, log in pairs(category) do
            if type(log.Calls) == "table" and #log.Calls > 0 then
                remotes += 1
                calls += #log.Calls
            end
            if log.Blocked then
                blocked += 1
            end
            if log.Ignored then
                ignored += 1
            end
        end
        counts[direction] = { remotes = remotes, calls = calls, blocked = blocked, ignored = ignored }
    end

    local settings = {}
    local saveManager = wax.shared.SaveManager
    if saveManager and type(saveManager.GetState) == "function" then
        for _, name in ipairs({ "EnableLogging", "LogActors", "IgnorePlayerModule", "AutoIgnoreSpammyEvents", "LogBlockedRemotes" }) do
            local ok, value = pcall(function()
                return saveManager:GetState(name)
            end)
            if ok then
                settings[name] = value
            end
        end
    end

    return {
        ok = true,
        data = {
            loaded = true,
            executorName = wax.shared.ExecutorName,
            startedAt = wax.shared.CobaltStartTime,
            counts = counts,
            settings = settings,
        },
    }
end

return SpyManager
