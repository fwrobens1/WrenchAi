local HttpService = game:GetService("HttpService")
local Compat = require("../compat")
local Util = require("../util")

local Client = {}
Client.__index = Client

local function trimBase(url)
    local text = Util.Trim(url)
    while #text > 0 and text:sub(-1) == "/" do
        text = text:sub(1, -2)
    end
    return text
end

local function parseErrorBody(raw)
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if ok and type(decoded) == "table" then
        local err = decoded.error
        if type(err) == "table" then
            return tostring(err.message or err.code or "API error")
        end
        if type(err) == "string" then
            return err
        end
        if decoded.message then
            return tostring(decoded.message)
        end
    end
    return Util.Truncate(raw or "", 400)
end

function Client.new(config)
    return setmetatable({ config = config }, Client)
end

function Client:Url()
    return trimBase(self.config.baseURL or "") .. "/chat/completions"
end

function Client:Chat(messages, tools, isCancelled)
    if type(self.config.apiKey) ~= "string" or Util.Trim(self.config.apiKey) == "" then
        return nil, {
            kind = "auth",
            message = "No API key configured. Open Settings (CFG) and paste your API key.",
            status = 0,
        }, 0
    end

    local body = {
        model = self.config.model,
        messages = messages,
        temperature = tonumber(self.config.temperature) or 0.7,
        max_tokens = tonumber(self.config.maxTokens) or 16000,
    }
    if tools and #tools > 0 then
        body.tools = tools
        body.tool_choice = "auto"
    end

    local encodeOk, encoded = pcall(function()
        return HttpService:JSONEncode(body)
    end)
    if not encodeOk then
        return nil, { kind = "encode", message = "Could not encode the request.", status = 0 }, 0
    end

    local headers = {
        ["Content-Type"] = "application/json",
        ["Accept"] = "application/json",
        ["Authorization"] = "Bearer " .. Util.Trim(self.config.apiKey),
    }

    local lastError = nil
    for attempt = 1, 3 do
        if isCancelled and isCancelled() then
            return nil, { kind = "cancelled", message = "Cancelled.", status = 0 }, 0
        end

        local started = os.clock()
        local response, requestError = Compat.Http({
            Url = self:Url(),
            Method = "POST",
            Headers = headers,
            Body = encoded,
        })

        if not response then
            lastError = { kind = "network", message = tostring(requestError), status = 0 }
        else
            local status = response.status
            local raw = response.body or ""
            if status == 200 or status == 0 then
                local decodeOk, decoded = pcall(function()
                    return HttpService:JSONDecode(raw)
                end)
                if decodeOk and type(decoded) == "table" then
                    return {
                        data = decoded,
                        elapsed = os.clock() - started,
                        attempts = attempt,
                    }, nil, status
                end
                -- Some gateways stream SSE even when stream=false. Use the last data frame.
                local lastFrame = nil
                for line in raw:gmatch("[^\r\n]+") do
                    local payload = line:match("^data:%s*(.+)$")
                    if payload and payload ~= "[DONE]" then
                        lastFrame = payload
                    end
                end
                if lastFrame then
                    local frameOk, frame = pcall(function()
                        return HttpService:JSONDecode(lastFrame)
                    end)
                    if frameOk and type(frame) == "table" then
                        return {
                            data = frame,
                            elapsed = os.clock() - started,
                            attempts = attempt,
                        }, nil, status
                    end
                end
                lastError = {
                    kind = "decode",
                    message = "Endpoint returned non-JSON content: " .. Util.Truncate(raw, 300),
                    status = status,
                    raw = raw,
                }
            else
                local message = parseErrorBody(raw)
                lastError = {
                    kind = "http",
                    message = "HTTP " .. tostring(status) .. ": " .. message,
                    status = status,
                    raw = raw,
                }
                if status ~= 429 and status < 500 then
                    return nil, lastError, status
                end
            end
        end

        if attempt < 3 then
            task.wait(2 ^ (attempt - 1))
        end
    end

    return nil, lastError, lastError and lastError.status or 0
end

return Client
