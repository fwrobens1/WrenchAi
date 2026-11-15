return {
    {
        name = "open_dex",
        description = "Launch the Dex Recontinued explorer UI. Useful for manual inspection; the agent's own tools stay available.",
        parameters = {
            type = "object",
            properties = {},
        },
        run = function(args, ctx)
            local source = ctx.dexSource
            if not source then
                local downloaded, downloadError = ctx.compat.HttpGet(ctx.config.dexURL)
                if not downloaded then
                    return { ok = false, error = "Could not download Dex: " .. tostring(downloadError) }
                end
                source = downloaded
                ctx.dexSource = source
            end

            local loadstringFunction = ctx.compat.Lookup("loadstring")
            if type(loadstringFunction) ~= "function" then
                return { ok = false, error = "This executor has no loadstring." }
            end
            local chunk, compileError = loadstringFunction(source)
            if not chunk then
                return { ok = false, error = "Dex failed to compile: " .. tostring(compileError) }
            end
            local ok, runError = pcall(chunk)
            if not ok then
                return { ok = false, error = "Dex failed to launch: " .. tostring(runError) }
            end
            return {
                ok = true,
                data = { message = "Dex launched. It has its own draggable window." },
            }
        end,
    },
}
