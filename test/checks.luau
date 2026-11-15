local api = __api

local checks = 0
local function check(condition, message)
    if not condition then
        error("FAIL: " .. message, 0)
    end
    checks += 1
end

check(type(api) == "table", "main returns a table")
check(G.WrenchAi == api, "getgenv().WrenchAi is exported")
check(api.ui ~= nil and api.loop ~= nil and api.tools ~= nil, "ui/loop/tools exist")
check(api.config.model == "Beam-1.0-501B-A23B", "default model")
check(api.config.baseURL == "https://api.reflection.ai/openai/v1", "default base URL")
check(api.ui.settingsFrame.Visible == true, "settings auto-open without an API key")
check(api.ui.root ~= nil, "window root exists")

api.config.apiKey = "test-key"
api.config.autoApproveScripts = true
api.ui.settingsFrame.Visible = false

local schemas = api.tools:Schemas()
check(#schemas == 17, "17 tools registered, got " .. tostring(#schemas))
check(#api.tools:PromptCatalog() > 100, "prompt catalog rendered")

local toolCallResponse = table.concat({
    '{"choices":[{"message":{"role":"assistant","content":null,',
    '"reasoning_content":"step one thinking",',
    '"tool_calls":[{"id":"call_1","type":"function","function":',
    '{"name":"run_luau","arguments":"{\\"code\\":\\"return 40 + 2\\",\\"description\\":\\"math\\"}"}}]}}]}',
})
G.pushResponse(toolCallResponse)
G.pushResponse(
    '{"choices":[{"message":{"role":"assistant","content":"The answer is 42.","reasoning_content":"final thinking"}}]}'
)

api.loop:Send("compute 40 + 2")
check(#api.loop.messages == 4, "4 messages after one tool round, got " .. tostring(#api.loop.messages))
check(api.loop.messages[1].role == "user", "first message is the user turn")
check(api.loop.messages[2].role == "assistant" and api.loop.messages[2].tool_calls ~= nil, "assistant tool_calls recorded")
check(api.loop.messages[2].reasoning_content == "step one thinking", "tool-call reasoning echoed for Beam")
check(api.loop.messages[3].role == "tool", "tool result recorded")
check(api.loop.messages[3].content:find("42", 1, true) ~= nil, "tool result carries the returned value")
check(api.loop.messages[4].content == "The answer is 42.", "final assistant text recorded")
check(api.loop.messages[4].reasoning_content == "final thinking", "final reasoning echoed for Beam")
local requestProbe = api.loop:BuildRequest()
check(requestProbe[#requestProbe].reasoning_content == "final thinking", "reasoning_content reaches the request")
check(api.loop.running == false, "loop is idle after the turn")

api.loop.toolsSupported = false
G.pushResponse(
    '{"choices":[{"message":{"role":"assistant","content":"{\\"tool\\":\\"get_game_info\\",\\"args\\":{}}"}}]}'
)
G.pushResponse('{"choices":[{"message":{"role":"assistant","content":"Place 7100000000."}}]}')
api.loop:Send("where am I")
check(api.loop.messages[#api.loop.messages].content == "Place 7100000000.", "JSON protocol fallback answered")

G.pushResponse(
    '{"choices":[{"message":{"role":"assistant","content":"{\\"tool\\":\\"get_game_info\\",\\"args\\":{}}</rfl:parameter>","reasoning_content":"planned call</rfl:parameter>"}}]}'
)
G.pushResponse('{"choices":[{"message":{"role":"assistant","content":"Clean answer.","reasoning_content":"done thinking"}}]}')
api.loop:Send("tagged tool call")
check(api.loop.messages[#api.loop.messages].content == "Clean answer.", "rfl tags stripped from the final answer")
check(
    api.loop.messages[#api.loop.messages - 1].content:find("TOOL RESULT", 1, true) ~= nil,
    "tagged JSON still executed as a tool call"
)
check(
    api.loop.messages[#api.loop.messages - 2].reasoning_content == "planned call",
    "rfl tags stripped from stored reasoning"
)

local info = api.tools:Call("get_game_info", {})
check(info.ok, "get_game_info ok: " .. tostring(info.error))
check(info.data.placeId == 7100000000, "game info placeId")
check(info.data.executor.environment == "getgenv", "compat detected getgenv")

local search = api.tools:Call("search_instances", { root = "game", selector = "Part", limit = 5 })
check(search.ok, "search_instances ok: " .. tostring(search.error))
check(search.data.fallback == true and search.data.returned >= 1, "search fallback finds parts")

local tree = api.tools:Call("get_descendants_tree", { root = "game", maxDepth = 2 })
check(tree.ok and tree.data.visited >= 1, "get_descendants_tree walks children")

local scripts = api.tools:Call("list_scripts", {})
check(scripts.ok and scripts.data.scanned == 0, "list_scripts scans the empty mock game")

local logsResult = api.tools:Call("get_console_logs", {})
check(logsResult.ok and logsResult.data.count == 0, "get_console_logs works")

local playerGui = game:GetService("Players").PlayerGui

local button = Instance.new("TextButton")
button.Name = "Go"
button.Parent = playerGui
G.firesignal = function()
    G.fireCount = (G.fireCount or 0) + 1
end
local clicked = api.tools:Call("click_button", { path = "Players.PlayerGui.Go" })
check(clicked.ok, "click_button ok: " .. tostring(clicked.error))
check(clicked.data.method == "firesignal", "click_button used firesignal")
check((G.fireCount or 0) > 0, "firesignal was invoked")

local textBox = Instance.new("TextBox")
textBox.Name = "Entry"
textBox.Text = ""
textBox.Parent = playerGui
local typed = api.tools:Call("type_text", { path = "Players.PlayerGui.Entry", text = "hello" })
check(typed.ok, "type_text ok: " .. tostring(typed.error))
check(textBox.Text == "hello", "type_text set the text")

local spyStatus = api.tools:Call("spy_status", {})
check(spyStatus.ok and spyStatus.data.loaded == false, "spy_status reports Cobalt not loaded")

local scriptResult = api.tools:Call("run_luau", { code = "print('hello from luau'); return { n = 1 }" })
check(scriptResult.ok, "run_luau ok: " .. tostring(scriptResult.error))
check(scriptResult.data.returned.n == 1, "run_luau returned a table")
check(type(scriptResult.data.logs) == "string", "run_luau reports a logs field")

api.config.autoApproveScripts = false
api.loop.cancelled = true
local denied = api.tools:Call("run_luau", { code = "return 1" })
check(denied.ok == false and tostring(denied.error):find("denied", 1, true) ~= nil, "run_luau honors denial")
api.loop.cancelled = false

api.ui:AddMessage("assistant", "Here:\n```lua\nprint(1)\n```\ndone")
local card = api.ui:AddToolCard("demo", "{}")
card:Finish(false, "boom", 0.2)
card:Finish(true, "fine", 0.1)
check(type(card.Expand) == "function", "tool card api exists")

local approvalAllowed, approvalAlways = api.ui:AskApproval({
    kind = "script",
    title = "Test",
    description = "Run this?",
    code = "return 1",
}, function()
    return true
end)
check(approvalAllowed == false and approvalAlways == false, "approval card denies on cancel")

api.ui:SetStatus("Testing")
api.ui:SetRunning(true)
check(api.ui.stopButton.Visible == true, "stop button visible while running")
api.ui:SetRunning(false)
check(api.ui.stopButton.Visible == false, "stop button hidden when idle")

api.ui:SetStatus("Ready")
api.ui:Toggle()
check(api.ui.root.Visible == false, "toggle hides the window")
api.ui:Toggle()
check(api.ui.root.Visible == true, "toggle shows the window")

api.ui.callbacks.onNewChat()
check(#api.loop.messages == 0, "new chat resets history")

api.config.apiKey = ""
api.ui.settingsFrame.Visible = false
api.ui.input.Text = "hello"
api.ui:Submit()
check(api.ui.settingsFrame.Visible == true, "missing key opens settings")
check(G.queuedResponses() == 0, "missing key sends no request")

api.config.apiKey = "test-key"
api.ui.settingsFrame.Visible = false
G.pushResponse('{"choices":[{"message":{"role":"assistant","content":"hi there"}}]}')
api.ui.input.Text = "hello"
api.ui:Submit()
check(api.loop.messages[#api.loop.messages].content == "hi there", "UI submit reaches the loop")

api.ui.callbacks.onSaveSettings({
    baseURL = "https://example.test/v1",
    model = "demo-model",
    apiKey = "next-key",
    temperature = 0.2,
    maxSteps = 5,
    cobaltURL = "https://example.test/Cobalt",
    dexURL = "https://example.test/Dex",
    extraSystemPrompt = "be brief",
    autoApproveScripts = true,
})
check(api.config.model == "demo-model" and api.config.apiKey == "next-key", "settings callback updates config")
check(api.config.maxSteps == 5 and api.config.extraSystemPrompt == "be brief", "settings callback copies all fields")

api.ui:OpenSettings()
api.ui.settingModel.Text = "ui-model"
api.ui.settingBaseURL.Text = "https://ui.test/v1"
api.ui.settingKey.Text = "ui-key"
api.ui:SaveSettings()
check(api.config.model == "ui-model" and api.config.apiKey == "ui-key", "settings UI saves through the callback")

print("smoke ok: " .. tostring(checks) .. " checks")
