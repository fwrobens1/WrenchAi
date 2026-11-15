local Serialize = require("../serialize")
local Shared = require("./shared")
local Util = require("../util")

local CACHE_LIMIT = 48
local DECOMPILE_TIMEOUT = 8
local GREP_TIME_BUDGET = 25

local function decompileWithTimeout(script, ctx)
    local finished = false
    local source = nil
    local failure = nil
    task.spawn(function()
        local ok, result, err = pcall(function()
            return ctx.compat.Decompile(script)
        end)
        if ok then
            source = result
            failure = err
        else
            failure = result
        end
        finished = true
    end)
    local deadline = os.clock() + DECOMPILE_TIMEOUT
    while not finished and os.clock() < deadline do
        task.wait(0.05)
    end
    if not finished then
        return nil, "The decompiler did not finish within " .. tostring(DECOMPILE_TIMEOUT) .. "s."
    end
    if type(source) == "string" and #source > 0 then
        return source
    end
    return nil, failure or "The decompiler returned no source."
end

local function getSource(script, ctx)
    local debugId = nil
    pcall(function()
        debugId = script:GetDebugId()
    end)
    local key = debugId or tostring(script)
    local cache = ctx.scriptCache
    local cached = cache[key]
    if cached then
        return cached.source, cached.lines, cached.debugId
    end

    local source, errorMessage = decompileWithTimeout(script, ctx)
    if not source then
        return nil, errorMessage
    end
    source = Shared.StripBanner(source)
    local lines = Util.Lines(source)

    local count = 0
    local oldestKey = nil
    local oldestAt = math.huge
    for cacheKey, entry in pairs(cache) do
        count += 1
        if entry.at < oldestAt then
            oldestAt = entry.at
            oldestKey = cacheKey
        end
    end
    if count >= CACHE_LIMIT and oldestKey then
        cache[oldestKey] = nil
    end
    cache[key] = { source = source, lines = lines, at = os.clock(), debugId = debugId }
    return source, lines, debugId
end

local function indexScripts(ctx, scripts)
    local index = ctx.scriptIndex or { byDebugId = {}, scripts = {} }
    for _, script in ipairs(scripts) do
        local debugId = nil
        pcall(function()
            debugId = script:GetDebugId()
        end)
        if debugId and not index.byDebugId[debugId] then
            index.byDebugId[debugId] = script
        end
    end
    ctx.scriptIndex = index
end

return {
    {
        name = "list_scripts",
        description = "List loaded LuaSourceContainer scripts with paths and debugIds. Use debugId with read_script.",
        parameters = {
            type = "object",
            properties = {
                root = Shared.StringProperty("Root path to scan.", "game"),
                query = Shared.StringProperty("Substring matched against path, name, and class.", ""),
                classFilter = Shared.StringProperty("Limit to LocalScript, ModuleScript, or Script.", ""),
                includeDetached = Shared.BoolProperty("Include scripts detached from the DataModel.", false),
                limit = Shared.IntProperty("Maximum scripts to return.", 80, 1, 200),
            },
        },
        run = function(args, ctx)
            local root, rootError = Shared.ResolvePath(args.root or "game")
            if not root then
                return { ok = false, error = rootError }
            end
            local query = string.lower(Util.Trim(args.query or ""))
            local classFilter = Util.Trim(args.classFilter or "")
            local limit = Util.Clamp(tonumber(args.limit) or 80, 1, 200)
            local scripts = Shared.GetScripts(root, args.includeDetached == true, ctx.compat)
            indexScripts(ctx, scripts)

            local entries = {}
            local matched = 0
            for _, script in ipairs(scripts) do
                local allowed = true
                if classFilter ~= "" then
                    local ok, isA = pcall(function()
                        return script:IsA(classFilter)
                    end)
                    allowed = ok and isA
                end
                if allowed then
                    local path = script:GetFullName()
                    if query == "" or string.find(string.lower(path), query, 1, true) then
                        matched += 1
                        if #entries < limit then
                            table.insert(entries, Shared.Describe(script))
                        end
                    end
                end
            end
            return {
                ok = true,
                data = {
                    root = root:GetFullName(),
                    scanned = #scripts,
                    matched = matched,
                    returned = #entries,
                    truncated = matched > #entries,
                    scripts = entries,
                    hint = (#entries == 0 and "Broaden the query or set includeDetached=true." or nil),
                },
            }
        end,
    },
    {
        name = "read_script",
        description = "Decompile a script and return a line range. Prefer a debugId from list_scripts; path also works.",
        parameters = {
            type = "object",
            properties = {
                debugId = Shared.StringProperty("Debug id from list_scripts.", nil),
                path = Shared.StringProperty("Full instance path of the script.", nil),
                startLine = Shared.IntProperty("First line to return.", 1, 1, nil),
                endLine = Shared.IntProperty("Last line to return.", nil, 1, nil),
                maxLines = Shared.IntProperty("Line cap for this response.", 200, 1, 800),
            },
        },
        run = function(args, ctx)
            local script, findError = Shared.FindScript(ctx, args)
            if not script then
                return { ok = false, error = findError }
            end
            local source, lines, debugId = getSource(script, ctx)
            if not source or type(lines) ~= "table" then
                return {
                    ok = false,
                    error = "Could not decompile " .. script:GetFullName() .. ": " .. tostring(lines or "unknown"),
                }
            end
            local totalLines = #lines
            local startLine = Util.Clamp(tonumber(args.startLine) or 1, 1, math.max(1, totalLines))
            local endLine = Util.Clamp(tonumber(args.endLine) or totalLines, startLine, math.max(1, totalLines))
            local maxLines = Util.Clamp(tonumber(args.maxLines) or 200, 1, 800)
            local cappedEnd = math.min(endLine, startLine + maxLines - 1)
            local slice = {}
            for index = startLine, cappedEnd do
                table.insert(slice, lines[index])
            end
            return {
                ok = true,
                data = {
                    path = script:GetFullName(),
                    debugId = debugId,
                    totalLines = totalLines,
                    startLine = startLine,
                    endLine = cappedEnd,
                    truncated = cappedEnd < endLine,
                    source = table.concat(slice, "\n"),
                },
            }
        end,
    },
    {
        name = "grep_scripts",
        description = "Search decompiled script sources for a substring or Lua pattern. Narrow with root/query first; decompiling is slow.",
        parameters = {
            type = "object",
            properties = {
                pattern = Shared.StringProperty("Text to find, or a Lua pattern when useLuaPatterns=true.", nil),
                useLuaPatterns = Shared.BoolProperty("Treat pattern as a Lua pattern.", false),
                root = Shared.StringProperty("Root path to scan.", "game"),
                query = Shared.StringProperty("Only scan scripts whose path contains this substring.", ""),
                includeDetached = Shared.BoolProperty("Include detached scripts.", false),
                maxResults = Shared.IntProperty("Stop after this many matches.", 40, 1, 100),
                maxScripts = Shared.IntProperty("Stop after decompiling this many scripts.", 60, 1, 300),
            },
            required = { "pattern" },
        },
        run = function(args, ctx)
            local pattern = tostring(args.pattern or "")
            if pattern == "" then
                return { ok = false, error = "pattern is required." }
            end
            local root, rootError = Shared.ResolvePath(args.root or "game")
            if not root then
                return { ok = false, error = rootError }
            end
            local usePatterns = args.useLuaPatterns == true
            local query = string.lower(Util.Trim(args.query or ""))
            local maxResults = Util.Clamp(tonumber(args.maxResults) or 40, 1, 100)
            local maxScripts = Util.Clamp(tonumber(args.maxScripts) or 60, 1, 300)
            local scripts = Shared.GetScripts(root, args.includeDetached == true, ctx.compat)
            indexScripts(ctx, scripts)

            local deadline = os.clock() + GREP_TIME_BUDGET
            local matches = {}
            local scanned = 0
            local timedOut = false
            local failures = 0
            local firstFailure = nil

            for _, script in ipairs(scripts) do
                if scanned >= maxScripts or #matches >= maxResults then
                    break
                end
                if os.clock() > deadline then
                    timedOut = true
                    break
                end
                local path = script:GetFullName()
                if query == "" or string.find(string.lower(path), query, 1, true) then
                    local source, lines, debugId = getSource(script, ctx)
                    scanned += 1
                    if source and type(lines) == "table" then
                        for lineNumber, line in ipairs(lines) do
                            local found = false
                            if usePatterns then
                                local ok, result = pcall(string.find, line, pattern)
                                if not ok then
                                    return {
                                        ok = false,
                                        error = "Invalid Lua pattern: " .. tostring(result),
                                    }
                                end
                                found = result ~= nil
                            else
                                found = string.find(line, pattern, 1, true) ~= nil
                            end
                            if found then
                                table.insert(matches, {
                                    path = path,
                                    debugId = debugId,
                                    line = lineNumber,
                                    text = Util.Truncate(Util.Trim(line), 240),
                                })
                                if #matches >= maxResults then
                                    break
                                end
                            end
                        end
                    else
                        failures += 1
                        firstFailure = firstFailure or (path .. ": " .. tostring(lines or "no source"))
                    end
                end
            end

            return {
                ok = true,
                data = {
                    pattern = pattern,
                    matches = matches,
                    returned = #matches,
                    scriptsScanned = scanned,
                    totalScripts = #scripts,
                    decompileFailures = failures,
                    firstFailure = firstFailure,
                    truncated = #matches >= maxResults or scanned >= maxScripts,
                    timedOut = timedOut,
                    hint = (#scripts > scanned and "Raise maxScripts or narrow query/root for more coverage." or nil),
                },
            }
        end,
    },
}
