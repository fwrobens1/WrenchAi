local Serialize = require("../serialize")
local Shared = require("./shared")
local Util = require("../util")

return {
    {
        name = "run_luau",
        description = "Execute Luau in the executor. The user approves each script unless always-allow is on. Return a compact value; print output is captured.",
        parameters = {
            type = "object",
            properties = {
                code = Shared.StringProperty("Luau source to execute.", nil),
                description = Shared.StringProperty("Short explanation shown in the approval prompt.", ""),
            },
            required = { "code" },
        },
        run = function(args, ctx)
            local code = args.code
            if type(code) ~= "string" or Util.Trim(code) == "" then
                return { ok = false, error = "code is required." }
            end

            if not ctx.config.autoApproveScripts then
                if type(ctx.approve) ~= "function" then
                    return { ok = false, error = "No approval handler is available, so script execution was refused." }
                end
                local allowed, always = ctx.approve({
                    kind = "script",
                    title = "Run Luau",
                    description = args.description or "The agent wants to execute this code in your client.",
                    code = code,
                })
                if not allowed then
                    return { ok = false, error = "The user denied this script." }
                end
                if always and type(ctx.setAutoApprove) == "function" then
                    ctx.setAutoApprove(true)
                end
            end

            local loadstringFunction = ctx.compat.Lookup("loadstring")
            if type(loadstringFunction) ~= "function" then
                return { ok = false, error = "This executor has no loadstring." }
            end
            local chunk, compileError = loadstringFunction(code)
            if not chunk then
                return { ok = false, error = "Compile error: " .. tostring(compileError) }
            end

            ctx.compat.SetIdentity(8)
            local environment = ctx.compat.Environment
            local environmentPrint = environment.print
            local globalPrint = type(_G) == "table" and _G.print or nil
            local logs = {}
            local capturedPrint = function(...)
                local parts = {}
                for index = 1, select("#", ...) do
                    parts[#parts + 1] = tostring(select(index, ...))
                end
                if #logs < 200 then
                    table.insert(logs, table.concat(parts, " "))
                end
                if type(environmentPrint) == "function" then
                    pcall(environmentPrint, ...)
                elseif type(globalPrint) == "function" then
                    pcall(globalPrint, ...)
                end
            end

            pcall(function()
                environment.print = capturedPrint
            end)
            if type(_G) == "table" and _G ~= environment then
                pcall(function()
                    _G.print = capturedPrint
                end)
            end

            local started = os.clock()
            local succeeded, result = xpcall(chunk, function(err)
                local traceOk, trace = pcall(debug.traceback, tostring(err), 2)
                return traceOk and trace or tostring(err)
            end)
            local duration = os.clock() - started

            pcall(function()
                environment.print = environmentPrint
            end)
            if type(_G) == "table" and _G ~= environment then
                pcall(function()
                    _G.print = globalPrint
                end)
            end

            local data = {
                duration = duration,
                logs = Util.Truncate(table.concat(logs, "\n"), 6000),
            }

            if succeeded then
                if result ~= nil then
                    data.returned = Serialize.Value(result, 4)
                elseif #logs == 0 then
                    data.note = "The chunk returned no value and printed nothing. Return a value when you need results."
                end
                return { ok = true, data = data }
            end

            data.error = Util.Truncate(tostring(result), 4000)
            return { ok = false, error = data.error, data = data }
        end,
    },
}
