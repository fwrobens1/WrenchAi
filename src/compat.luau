-- Executor capability detection.
-- The first-function-wins approach mirrors roblox-executor-mcp's MIT compat layer.
local Compat = {}

local function firstFunction(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "function" then
            return value
        end
    end
    return nil
end

local function resolveEnvironment()
    local ok, environment = pcall(function()
        return getgenv()
    end)
    if ok and type(environment) == "table" then
        return environment, "getgenv"
    end
    if type(_G) == "table" then
        return _G, "_G"
    end
    local fenvOk, fenv = pcall(function()
        return getfenv(0)
    end)
    if fenvOk and type(fenv) == "table" then
        return fenv, "getfenv"
    end
    return {}, "none"
end

local Environment, EnvironmentSource = resolveEnvironment()
Compat.Environment = Environment
Compat.EnvironmentSource = EnvironmentSource
Compat.Features = {}

local function lookup(name)
    local ok, value = pcall(function()
        return Environment[name]
    end)
    if ok and value ~= nil then
        return value
    end
    if type(_G) == "table" and _G ~= Environment then
        local globalOk, globalValue = pcall(function()
            return _G[name]
        end)
        if globalOk then
            return globalValue
        end
    end
    return nil
end

local function nested(namespace, name)
    local owner = lookup(namespace)
    if type(owner) ~= "table" then
        return nil
    end
    local ok, value = pcall(function()
        return owner[name]
    end)
    if ok then
        return value
    end
    return nil
end

Compat.Lookup = lookup

local function detect(name)
    return type(lookup(name)) == "function"
end

local DETECTED_FUNCTIONS = {
    "loadstring", "decompile", "getscriptbytecode", "getscripthash", "getscriptclosure",
    "getconnections", "firesignal", "fireclickdetector", "firetouchinterest", "fireproximityprompt",
    "hookmetamethod", "hookfunction", "restorefunction", "getnamecallmethod", "newcclosure",
    "checkcaller", "clonefunction", "getrawmetatable", "setreadonly", "islclosure", "iscclosure",
    "getcallingscript", "getthreadidentity", "setthreadidentity", "setidentity", "cloneref",
    "getnilinstances", "getinstances", "getscripts", "getloadedmodules", "getcustomasset",
    "identifyexecutor", "getexecutorname", "writefile", "readfile", "isfile", "makefolder",
    "isfolder", "delfile", "listfiles", "gethui", "protectgui", "setclipboard", "getclipboard",
    "isrenderobj", "getrenderproperty", "setrenderproperty", "getproperties", "getattributes",
    "getfunctionhash", "queue_on_teleport", "keypress", "keyrelease", "mouse1click",
    "mouse1press", "mouse1release", "mousemoverel", "mousemoveabs", "getgenv",
}

for _, name in ipairs(DETECTED_FUNCTIONS) do
    Compat.Features[name] = detect(name)
end

local requestFunction = firstFunction(
    lookup("request"),
    lookup("http_request"),
    nested("syn", "request"),
    nested("http", "request"),
    nested("fluxus", "request")
)
Compat.Features.request = requestFunction ~= nil

local setIdentity = firstFunction(
    lookup("setthreadidentity"),
    lookup("setidentity"),
    nested("syn", "set_thread_identity")
)
Compat.Features.setthreadidentity = Compat.Features.setthreadidentity or setIdentity ~= nil

local identify = firstFunction(lookup("identifyexecutor"), lookup("getexecutorname"))
Compat.ExecutorName = "Unknown"
Compat.ExecutorVersion = ""
if identify then
    local ok, name, version = pcall(identify)
    if ok then
        Compat.ExecutorName = tostring(name or "Unknown")
        Compat.ExecutorVersion = tostring(version or "")
    end
end

function Compat.Has(name)
    return Compat.Features[name] == true
end

function Compat.Http(options)
    if not requestFunction then
        return nil, "This executor exposes no HTTP function (request, http_request, syn.request or http.request)."
    end
    local payload = {
        Url = options.Url,
        Method = options.Method or "GET",
        Headers = options.Headers or {},
        Body = options.Body or "",
    }
    local ok, response = pcall(requestFunction, payload)
    if not ok then
        return nil, "HTTP request failed: " .. tostring(response)
    end
    if type(response) ~= "table" then
        return nil, "Executor HTTP function returned no response table."
    end
    local status = tonumber(
        response.StatusCode or response.Status or response.status_code or response.status
    ) or 0
    return {
        status = status,
        body = response.Body or response.body or "",
        headers = response.Headers or response.headers or {},
    }
end

function Compat.HttpGet(url)
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(body) == "string" and #body > 0 then
        return body
    end
    local response, errorMessage = Compat.Http({ Url = url, Method = "GET" })
    if not response then
        return nil, errorMessage
    end
    if response.status ~= 0 and response.status ~= 200 then
        return nil, "HTTP " .. tostring(response.status) .. " for " .. url
    end
    return response.body
end

function Compat.SetIdentity(identity)
    if not setIdentity then
        return false
    end
    local ok = pcall(setIdentity, identity or 8)
    return ok
end

function Compat.Decompile(script)
    local decompile = lookup("decompile")
    if type(decompile) == "function" then
        local ok, source = pcall(decompile, script)
        if ok and type(source) == "string" and #source > 0 then
            return source
        end
        return nil, tostring(source)
    end
    if Compat.Has("getscriptbytecode") then
        return nil, "This executor has getscriptbytecode but no decompile, so readable source is unavailable."
    end
    return nil, "This executor has no decompile function."
end

function Compat.Diagnostics()
    local available = {}
    for name, enabled in pairs(Compat.Features) do
        if enabled then
            table.insert(available, name)
        end
    end
    table.sort(available)
    return {
        executor = Compat.ExecutorName,
        version = Compat.ExecutorVersion,
        environment = EnvironmentSource,
        available = available,
    }
end

return Compat
