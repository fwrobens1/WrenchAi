local SpyManager = require("./spymanager")
local Util = require("../util")

local Tools = {}
Tools.__index = Tools

function Tools.new(ctx)
    local self = setmetatable({ ctx = ctx, entries = {}, order = {} }, Tools)
    self.ctx.spy = SpyManager.new(self.ctx)

    local modules = {
        require("./inspect"),
        require("./scripts"),
        require("./run"),
        require("./gui"),
        require("./spy"),
        require("./dex"),
    }
    for _, definitions in ipairs(modules) do
        for _, entry in ipairs(definitions) do
            self:Register(entry)
        end
    end
    return self
end

function Tools:Register(entry)
    assert(type(entry.name) == "string" and entry.name ~= "", "tool name is required")
    assert(type(entry.run) == "function", "tool " .. entry.name .. " needs a run function")
    self.entries[entry.name] = entry
    table.insert(self.order, entry.name)
end

function Tools:Has(name)
    return self.entries[name] ~= nil
end

function Tools:Schemas()
    local schemas = {}
    for _, name in ipairs(self.order) do
        local entry = self.entries[name]
        table.insert(schemas, {
            type = "function",
            ["function"] = {
                name = name,
                description = entry.description,
                parameters = entry.parameters
                    or { type = "object", properties = {} },
            },
        })
    end
    return schemas
end

function Tools:PromptCatalog()
    local lines = { "Available tools. Call one at a time with a single JSON object." }
    for _, name in ipairs(self.order) do
        local entry = self.entries[name]
        local arguments = {}
        if entry.parameters and entry.parameters.properties then
            for key in pairs(entry.parameters.properties) do
                table.insert(arguments, key)
            end
            table.sort(arguments)
        end
        table.insert(lines, "- " .. name .. "(" .. table.concat(arguments, ", ") .. "): " .. entry.description)
    end
    return table.concat(lines, "\n")
end

function Tools:Call(name, args)
    local entry = self.entries[name]
    if not entry then
        return { ok = false, error = "Unknown tool: " .. tostring(name) }
    end
    if type(args) ~= "table" then
        args = {}
    end
    local ok, result = pcall(entry.run, args, self.ctx)
    if not ok then
        return { ok = false, error = Util.ErrorText(result) }
    end
    if type(result) ~= "table" then
        return { ok = true, data = result }
    end
    if result.ok == nil then
        return { ok = true, data = result }
    end
    return result
end

return Tools
