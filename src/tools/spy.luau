local Shared = require("./shared")
local Util = require("../util")

local function directionArg(description)
    return Shared.StringProperty(description .. " Outgoing or Incoming.", "Outgoing")
end

return {
    {
        name = "spy_open",
        description = "Load Cobalt (the required remote spy) and wait until its log table is ready.",
        parameters = {
            type = "object",
            properties = {},
        },
        run = function(args, ctx)
            local ok, message = ctx.spy:EnsureLoaded()
            if not ok then
                return { ok = false, error = message }
            end
            return { ok = true, data = { message = message, loaded = true } }
        end,
    },
    {
        name = "spy_status",
        description = "Report whether Cobalt is loaded, how many remotes/calls it has captured, and its settings.",
        parameters = {
            type = "object",
            properties = {},
        },
        run = function(args, ctx)
            return ctx.spy:Status()
        end,
    },
    {
        name = "spy_calls",
        description = "Read captured remote calls from Cobalt, newest first. Auto-loads Cobalt unless autoStart=false.",
        parameters = {
            type = "object",
            properties = {
                direction = directionArg("Capture direction."),
                limit = Shared.IntProperty("Maximum remotes to return.", 20, 1, 100),
                filter = Shared.StringProperty("Only remotes whose path contains this text.", ""),
                includeArguments = Shared.BoolProperty("Include serialized call arguments.", true),
                callsPerRemote = Shared.IntProperty("How many recent calls per remote to include.", 1, 1, 5),
                autoStart = Shared.BoolProperty("Load Cobalt automatically when it is not running.", true),
            },
        },
        run = function(args, ctx)
            local direction = args.direction == "Incoming" and "Incoming" or "Outgoing"
            if not ctx.spy:Loaded() and args.autoStart ~= false then
                local ok, message = ctx.spy:EnsureLoaded()
                if not ok then
                    return { ok = false, error = message }
                end
            end
            if not ctx.spy:Loaded() then
                return { ok = false, error = "Cobalt is not loaded. Call spy_open first." }
            end
            return ctx.spy:GetCalls(
                direction,
                Util.Clamp(tonumber(args.limit) or 20, 1, 100),
                args.filter or "",
                args.includeArguments ~= false,
                Util.Clamp(tonumber(args.callsPerRemote) or 1, 1, 5)
            )
        end,
    },
    {
        name = "spy_clear",
        description = "Clear Cobalt's captured calls, optionally for one direction or one remote path.",
        parameters = {
            type = "object",
            properties = {
                direction = Shared.StringProperty("Outgoing, Incoming, or All.", "All"),
                filter = Shared.StringProperty("Optional remote path to clear only that remote.", ""),
            },
        },
        run = function(args, ctx)
            local direction = args.direction
            if direction ~= "Incoming" and direction ~= "Outgoing" and direction ~= "All" then
                direction = "All"
            end
            return ctx.spy:Clear(direction, args.filter or "")
        end,
    },
    {
        name = "spy_set",
        description = "Block or ignore one remote in Cobalt. Blocking outgoing calls drops them; state is reported back.",
        parameters = {
            type = "object",
            properties = {
                path = Shared.StringProperty("Remote instance path as shown by spy_calls.", nil),
                direction = directionArg("Log direction."),
                block = Shared.BoolProperty("Desired blocked state.", nil),
                ignore = Shared.BoolProperty("Desired ignored state.", nil),
            },
            required = { "path" },
        },
        run = function(args, ctx)
            local direction = args.direction == "Incoming" and "Incoming" or "Outgoing"
            if args.block == nil and args.ignore == nil then
                return { ok = false, error = "Provide block and/or ignore." }
            end
            return ctx.spy:SetState(direction, args.path, args.block, args.ignore)
        end,
    },
}
