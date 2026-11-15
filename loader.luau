--!nocheck
-- WrenchAi loader.
-- One-line install:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/fwrobens1/WrenchAi/main/loader.luau"))()
-- Overrides:
--   1) getgenv().WrenchAiURL = "https://example.test/dist/WrenchAi.luau"
--   2) or place the bundle at WrenchAi/WrenchAi.luau in the executor workspace
--   3) or set getgenv().WrenchAiSource = "<bundle source>"
local environment = (type(getgenv) == "function" and getgenv()) or _G
local DEFAULT_URL = "https://raw.githubusercontent.com/fwrobens1/WrenchAi/main/dist/WrenchAi.luau"

local function cacheBust(url)
    local separator = url:find("?", 1, true) and "&" or "?"
    local timeOk, stamp = pcall(os.time)
    if not timeOk then
        return url
    end
    return url .. separator .. "t=" .. tostring(stamp)
end

local function readURL(url)
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(body) == "string" and #body > 0 then
        return body
    end

    local candidates = { environment.request, environment.http_request }
    local syn = environment.syn
    if type(syn) == "table" then
        table.insert(candidates, syn.request)
    end
    for _, request in ipairs(candidates) do
        if type(request) == "function" then
            local requestOk, response = pcall(request, { Url = url, Method = "GET" })
            if requestOk and type(response) == "table" then
                local responseBody = response.Body or response.body
                if type(responseBody) == "string" and #responseBody > 0 then
                    return responseBody
                end
            end
        end
    end
    return nil
end

local source = environment.WrenchAiSource
if type(source) ~= "string" or source == "" then
    local url = environment.WrenchAiURL
    if type(url) ~= "string" or url == "" then
        url = DEFAULT_URL
    end
    local bustOk, busted = pcall(cacheBust, url)
    source = readURL(bustOk and busted or url)
    if not source then
        warn("WrenchAi: could not download " .. url)
    end
end

if type(source) ~= "string" or source == "" then
    local readfileFunction = environment.readfile
    if type(readfileFunction) == "function" then
        local ok, body = pcall(readfileFunction, "WrenchAi/WrenchAi.luau")
        if ok and type(body) == "string" and #body > 0 then
            source = body
        end
    end
end

if type(source) ~= "string" or source == "" then
    error(
        "WrenchAi: no source. Set getgenv().WrenchAiURL, place the bundle at WrenchAi/WrenchAi.luau, or set getgenv().WrenchAiSource."
    )
end

local loadstringFunction = environment.loadstring or loadstring
if type(loadstringFunction) ~= "function" then
    error("WrenchAi: this executor has no loadstring.")
end

local chunk, compileError = loadstringFunction(source, "WrenchAi")
if not chunk then
    error("WrenchAi: compile error: " .. tostring(compileError))
end

return chunk()
