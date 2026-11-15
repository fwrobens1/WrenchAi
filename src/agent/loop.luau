local HttpService = game:GetService("HttpService")
local Client = require("../llm/client")
local Prompt = require("./prompt")
local Serialize = require("../serialize")
local Util = require("../util")

local Loop = {}
Loop.__index = Loop

local MAX_CONTEXT_CHARS = 60000

local function messageChars(message)
    local size = #tostring(message.content or "")
    size += #tostring(message.reasoning_content or "")
    if type(message.tool_calls) == "table" then
        size += #message.tool_calls * 240
    end
    return size
end

local function isTurnStart(message)
    if message.role ~= "user" then
        return false
    end
    if type(message.content) == "string" and message.content:sub(1, 13) == "[TOOL RESULT:" then
        return false
    end
    return true
end

local function isConversationalMessage(text)
    if type(text) ~= "string" then
        return false
    end
    local clean = string.lower(Util.Trim(text))
    clean = clean:gsub("[%p%c]", "")
    clean = Util.Trim(clean)
    if clean == "hi" or clean == "hello" or clean == "hey" or clean == "sup" or clean == "yo"
        or clean == "who are you" or clean == "what can you do" or clean == "help"
        or clean == "what is this" or clean == "how are you" or clean == "test"
        or clean == "thanks" or clean == "thank you" then
        return true
    end
    return false
end

local function trimHistory(messages, budget)
    local total = 0
    for _, message in ipairs(messages) do
        total += messageChars(message)
    end
    if total <= budget then
        return messages
    end

    local keepFrom = 1
    while total > budget do
        local nextUser = nil
        for index = keepFrom + 1, #messages do
            if isTurnStart(messages[index]) then
                nextUser = index
                break
            end
        end
        if not nextUser then
            break
        end
        local laterUser = false
        for index = nextUser + 1, #messages do
            if isTurnStart(messages[index]) then
                laterUser = true
                break
            end
        end
        if not laterUser then
            break
        end
        for index = keepFrom, nextUser - 1 do
            total -= messageChars(messages[index])
        end
        keepFrom = nextUser
    end

    local trimmed = {}
    for index = keepFrom, #messages do
        table.insert(trimmed, messages[index])
    end
    return trimmed
end

local function normalizeContent(content)
    if content == nil then
        return nil
    end
    if type(content) == "string" then
        return content
    end
    if type(content) == "table" then
        if type(content.text) == "string" then
            return content.text
        end
        local parts = {}
        for _, part in ipairs(content) do
            if type(part) == "string" then
                table.insert(parts, part)
            elseif type(part) == "table" and type(part.text) == "string" then
                table.insert(parts, part.text)
            end
        end
        return table.concat(parts, "\n")
    end
    return tostring(content)
end

-- Reflection's API sometimes leaks its parameter-injection tags into
-- content and reasoning_content; they break JSON tool-call detection.
local function stripRflTags(text)
    if type(text) ~= "string" then
        return text
    end
    return (text:gsub("</?rfl:[^>]*>", ""))
end

local function sanitizeToolCalls(rawCalls)
    local calls = {}
    if type(rawCalls) ~= "table" then
        return calls
    end
    for index, raw in ipairs(rawCalls) do
        local fn = raw["function"] or {}
        local name = fn.name
        if type(name) == "string" and name ~= "" then
            local arguments = fn.arguments
            if type(arguments) ~= "string" then
                local ok, encoded = pcall(function()
                    return HttpService:JSONEncode(arguments or {})
                end)
                arguments = ok and encoded or "{}"
            end
            table.insert(calls, {
                id = tostring(raw.id or ("call_" .. tostring(index))),
                type = "function",
                ["function"] = { name = name, arguments = arguments },
            })
        end
    end
    return calls
end

local function parseArguments(raw)
    if type(raw) == "table" then
        return raw
    end
    if raw == nil or raw == "" then
        return {}
    end
    if type(raw) ~= "string" then
        return nil, "Tool arguments were not a JSON string."
    end
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if ok and type(decoded) == "table" then
        return decoded
    end
    return nil, "Tool arguments were not valid JSON: " .. Util.Truncate(raw, 200)
end

local function looksLikeToolRejection(err)
    local raw = string.lower(tostring(err.raw or err.message or ""))
    return raw:find("tool", 1, true) ~= nil
end

local function looksLikeReasoningError(err)
    local raw = string.lower(tostring(err.raw or err.message or ""))
    return raw:find("reasoning", 1, true) ~= nil
end

local function keepLastUserTurn(messages)
    for index = #messages, 1, -1 do
        if isTurnStart(messages[index]) then
            return { messages[index] }
        end
    end
    return {}
end

local function extractProtocolCall(content, tools)
    if type(content) ~= "string" then
        return nil
    end
    local text = Util.Trim(content)
    local fenced = text:match("```[%w]*%s*(.-)%s*```")
    if fenced then
        text = Util.Trim(fenced)
    end
    if text:sub(1, 1) ~= "{" or text:sub(-1) ~= "}" then
        return nil
    end
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(text)
    end)
    if not ok or type(decoded) ~= "table" then
        return nil
    end
    local name = decoded.tool or decoded.name
    local args = decoded.args or decoded.arguments or {}
    if type(name) ~= "string" or not tools:Has(name) or type(args) ~= "table" then
        return nil
    end
    return { name = name, arguments = args }
end

function Loop.new(deps)
    local self = setmetatable({}, Loop)
    self.ui = deps.ui
    self.tools = deps.tools
    self.config = deps.config
    self.compat = deps.compat
    self.client = Client.new(deps.config)
    self.messages = {}
    self.running = false
    self.cancelled = false
    self.toolsSupported = true
    self.recoveredHistory = false
    self.onDone = deps.onDone
    return self
end

function Loop:GetMessages()
    return self.messages
end

function Loop:SetMessages(messages)
    self.messages = Util.Copy(messages or {})
    self.continueCount = 0
    self.recoveredHistory = false
end

function Loop:RefreshConfig(config)
    self.config = config
    self.client = Client.new(config)
end

function Loop:IsCancelled()
    return self.cancelled
end

function Loop:Cancel()
    self.cancelled = true
end

function Loop:Reset()
    self.messages = {}
    self.cancelled = false
    self.continueCount = 0
    self.recoveredHistory = false
end

function Loop:BuildSystem()
    local system = Prompt.Build(self.compat, self.config)
    local catalog = self.tools:PromptCatalog()
    if self.toolsSupported then
        return system
            .. "\n\n"
            .. catalog
            .. "\n\nWhen live game inspection or action is specifically requested, call the appropriate function tool. Otherwise, answer the user normally with plain text. If tools are unavailable, reply with ONLY a single JSON object:"
            .. ' {"tool":"tool_name","args":{...}}.'
    end
    return system
        .. "\n\n"
        .. catalog
        .. "\n\nThis endpoint has no native tool calling. When live game inspection is needed, reply with ONLY a single JSON object:"
        .. ' {"tool":"tool_name","args":{...}}.'
        .. " You will then receive a [TOOL RESULT] message. Otherwise answer the user directly in plain text."
end

function Loop:BuildRequest()
    local request = {
        { role = "system", content = self:BuildSystem() },
    }
    local history = trimHistory(self.messages, MAX_CONTEXT_CHARS)
    for _, message in ipairs(history) do
        table.insert(request, message)
    end
    return request
end

function Loop:RunTool(name, args, rawArguments)
    local card = self.ui:AddToolCard(name, Util.Truncate(rawArguments or "{}", 600))
    local started = os.clock()
    local result = self.tools:Call(name, args)
    local duration = os.clock() - started
    local json = Serialize.Encode(result, tonumber(self.config.maxToolChars) or 9000)
    card:Finish(result.ok ~= false, json, duration)
    return result, json
end

function Loop:Execute()
    local maxSteps = Util.Clamp(tonumber(self.config.maxSteps) or 12, 1, 30)
    local step = 1
    local finished = false
    local toolCallHistory = {}
    local totalToolsCalled = 0
    local forceFinalAnswer = false

    -- Check if initiating user message is purely conversational (greeting / simple question)
    local lastUserMessage = nil
    for i = #self.messages, 1, -1 do
        if self.messages[i].role == "user" and isTurnStart(self.messages[i]) then
            lastUserMessage = self.messages[i].content
            break
        end
    end
    local isConversational = isConversationalMessage(lastUserMessage)

    while step <= maxSteps do
        if self.cancelled then
            break
        end
        self.ui:SetStatus("Thinking - step " .. tostring(step) .. "/" .. tostring(maxSteps))

        -- If conversational greeting on step 1, or forced final answer, or on final step, omit schemas
        -- so the model is forced to reply with direct text instead of looping tools blindly.
        local allowTools = self.toolsSupported
            and not forceFinalAnswer
            and not (step == 1 and isConversational)
            and (step < maxSteps)

        local schemas = allowTools and self.tools:Schemas() or nil
        local request = self:BuildRequest()
        local response, err = self.client:Chat(request, schemas, function()
            return self.cancelled
        end)

        if self.cancelled then
            break
        end

        if err then
            if self.toolsSupported and err.kind == "http" and looksLikeToolRejection(err) then
                self.toolsSupported = false
                self.ui:AddSystem("This endpoint rejected native tool calling; switched to the JSON tool protocol.")
                continue
            end
            -- Beam requires reasoning_content to be echoed on every earlier
            -- assistant message. If history from an older session lacks it,
            -- restart this turn with a fresh context instead of failing.
            if err.kind == "http" and looksLikeReasoningError(err) and not self.recoveredHistory then
                self.recoveredHistory = true
                self.messages = keepLastUserTurn(self.messages)
                self.ui:AddSystem("The model needed reasoning history that isn't available; restarted this turn with a fresh context.")
                continue
            end
            self.ui:AddError(err.message or "The API request failed.")
            if err.kind == "auth" then
                self.ui:OpenSettings()
            end
            break
        end

        local choice = nil
        if type(response.data.choices) == "table" then
            choice = response.data.choices[1]
        end
        if not choice then
            self.ui:AddError("The API response contained no choices.")
            break
        end

        local message = choice.message or {}
        local content = stripRflTags(normalizeContent(message.content))
        local reasoning = stripRflTags(normalizeContent(message.reasoning_content))
        local calls = sanitizeToolCalls(message.tool_calls)
        -- Beam demands the reasoning of every earlier assistant message be
        -- sent back with it; cap it so history does not blow the budget.
        local storedReasoning = Util.Truncate(reasoning or "", 4000)

        -- Reasoning models think in a separate field; surface it as a
        -- collapsible trace so long invisible pauses become visible progress.
        if Util.Trim(reasoning or "") ~= "" then
            self.ui:AddThinking(reasoning)
        end

        if #calls > 0 then
            table.insert(self.messages, {
                role = "assistant",
                content = content or "",
                reasoning_content = storedReasoning,
                tool_calls = calls,
            })
            if content and Util.Trim(content) ~= "" then
                self.ui:AddMessage("assistant", content)
            end

            local limit = math.min(#calls, 6)
            for index = 1, limit do
                if self.cancelled then
                    break
                end
                local call = calls[index]
                local name = call["function"].name
                local rawArgs = call["function"].arguments or "{}"
                local callSig = name .. ":" .. tostring(rawArgs)

                toolCallHistory[callSig] = (toolCallHistory[callSig] or 0) + 1
                totalToolsCalled += 1

                local json
                if toolCallHistory[callSig] > 1 then
                    -- Repetitive call detected: break the loop!
                    json = Serialize.Encode({
                        ok = false,
                        error = "LOOP DETECTED: You already called " .. name .. " with these arguments in this session. Do NOT repeat tool calls. Summarize your findings and answer the user directly now."
                    }, 500)
                    self.ui:AddToolCard(name, "loop blocked"):Finish(false, json, 0)
                    forceFinalAnswer = true
                else
                    local args, argumentError = parseArguments(call["function"].arguments)
                    if args then
                        local _, resultJson = self:RunTool(name, args, call["function"].arguments)
                        json = resultJson
                    else
                        json = Serialize.Encode(
                            { ok = false, error = argumentError },
                            tonumber(self.config.maxToolChars) or 9000
                        )
                        self.ui:AddToolCard(name, "invalid arguments"):Finish(false, json, 0)
                    end
                end

                table.insert(self.messages, {
                    role = "tool",
                    tool_call_id = call.id,
                    content = json,
                })
            end
            for index = limit + 1, #calls do
                table.insert(self.messages, {
                    role = "tool",
                    tool_call_id = calls[index].id,
                    content = '{"ok":false,"error":"Skipped: per-step tool call limit reached."}',
                })
            end
            step += 1
        else
            local text = content or ""
            local protocolCall = extractProtocolCall(text, self.tools)
            if protocolCall then
                table.insert(self.messages, {
                    role = "assistant",
                    content = text,
                    reasoning_content = storedReasoning,
                })
                local argsJson = Serialize.Encode(protocolCall.arguments, 600)
                local _, resultJson = self:RunTool(protocolCall.name, protocolCall.arguments, argsJson)
                table.insert(self.messages, {
                    role = "user",
                    content = "[TOOL RESULT: "
                        .. protocolCall.name
                        .. "]\n"
                        .. resultJson
                        .. "\n\nContinue: summarize findings or answer the user in plain text.",
                })
                step += 1
            elseif Util.Trim(text) == "" and Util.Trim(reasoning or "") ~= "" then
                -- Beam sometimes stops right after its internal reasoning
                -- without emitting content. Ask it to finish the thought.
                table.insert(self.messages, {
                    role = "assistant",
                    content = "",
                    reasoning_content = storedReasoning,
                })
                self.continueCount = (self.continueCount or 0) + 1
                if self.continueCount > 3 then
                    self.ui:AddError("The model kept thinking without answering. Try sending the message again.")
                    finished = true
                    break
                end
                local nudge = "Continue now. Output your final answer to the user in plain text."
                table.insert(self.messages, { role = "user", content = nudge })
                forceFinalAnswer = true
                step += 1
            else
                if Util.Trim(text) == "" then
                    text = "(The model returned no text.)"
                end
                self.ui:AddMessage("assistant", text)
                table.insert(self.messages, {
                    role = "assistant",
                    content = text,
                    reasoning_content = storedReasoning,
                })
                finished = true
                break
            end
        end
    end

    if self.cancelled then
        self.ui:AddSystem("Stopped.")
    elseif not finished then
        if totalToolsCalled > 0 then
            -- Attempt one final text synthesis without tools so the user gets an actual answer
            self.ui:SetStatus("Finalizing answer...")
            local finalRequest = self:BuildRequest()
            table.insert(finalRequest, {
                role = "user",
                content = "Please summarize your findings and provide your final response to the user now in plain text.",
            })
            local finalResp = self.client:Chat(finalRequest, nil, function()
                return self.cancelled
            end)
            if finalResp and finalResp.data and finalResp.data.choices and finalResp.data.choices[1] then
                local finalMsg = finalResp.data.choices[1].message or {}
                local finalText = stripRflTags(normalizeContent(finalMsg.content))
                if finalText and Util.Trim(finalText) ~= "" then
                    self.ui:AddMessage("assistant", finalText)
                    table.insert(self.messages, {
                        role = "assistant",
                        content = finalText,
                    })
                    finished = true
                end
            end
        end
        if not finished then
            self.ui:AddSystem("Reached the step limit (" .. tostring(maxSteps) .. "). Send another message to continue.")
        end
    end
end

function Loop:Send(text)
    if self.running then
        return
    end
    local clean = Util.Trim(text)
    if clean == "" then
        return
    end

    self.running = true
    self.cancelled = false
    self.continueCount = 0
    self.recoveredHistory = false
    table.insert(self.messages, { role = "user", content = clean })
    self.ui:SetRunning(true)
    self.ui:SetStatus("Thinking...")

    task.spawn(function()
        local ok, err = pcall(function()
            self:Execute()
        end)
        if not ok then
            self.ui:AddError("Agent error: " .. Util.ErrorText(err))
        end
        self.running = false
        self.ui:SetRunning(false)
        if self.cancelled then
            self.ui:SetStatus("Stopped")
        else
            self.ui:SetStatus("Ready")
        end
        if self.onDone then
            pcall(self.onDone)
        end
    end)
end

return Loop
