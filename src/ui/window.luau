local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Theme = require("./theme")
local Util = require("../util")

local UI = {}
UI.__index = UI

local WINDOW_WIDTH = 390
local WINDOW_HEIGHT = 580

local function create(className, properties, parent)
    local instance = Instance.new(className)
    for key, value in pairs(properties or {}) do
        pcall(function()
            instance[key] = value
        end)
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end

local function withCorner(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = instance
    return corner
end

local function withStroke(instance, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0
    stroke.Parent = instance
    return stroke
end

local function withPadding(instance, top, right, bottom, left)
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, top)
    padding.PaddingRight = UDim.new(0, right)
    padding.PaddingBottom = UDim.new(0, bottom)
    padding.PaddingLeft = UDim.new(0, left)
    padding.Parent = instance
    return padding
end

local function findGuiParent(compat)
    local gethui = compat.Lookup("gethui")
    if type(gethui) == "function" then
        local ok, parent = pcall(gethui)
        if ok and parent then
            return parent
        end
    end
    local ok, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok and coreGui then
        return coreGui
    end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function splitFences(text)
    local parts = {}
    local position = 1
    while true do
        local startIndex, endIndex = text:find("```", position, true)
        if not startIndex then
            table.insert(parts, { code = false, text = text:sub(position) })
            break
        end
        if startIndex > position then
            table.insert(parts, { code = false, text = text:sub(position, startIndex - 1) })
        end
        local closing = text:find("```", endIndex + 1, true)
        if not closing then
            table.insert(parts, { code = true, text = text:sub(endIndex + 1) })
            break
        end
        local chunk = text:sub(endIndex + 1, closing - 1)
        chunk = chunk:gsub("^%s*[%a]*%s*\n", "", 1)
        table.insert(parts, { code = true, text = chunk })
        position = closing + 3
    end
    return parts
end

function UI.new(deps)
    local self = setmetatable({}, UI)
    self.config = deps.config
    self.compat = deps.compat
    self.callbacks = deps.callbacks or {}
    self.order = 0
    self.running = false
    self.pendingApproval = nil
    self:Build()
    return self
end

function UI:Build()
    local gui = create("ScreenGui", {
        Name = "WrenchAi",
        ResetOnSpawn = false,
        DisplayOrder = 999999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = false,
    })
    local parent = findGuiParent(self.compat)
    local attached = pcall(function()
        gui.Parent = parent
    end)
    if not attached then
        gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
    self.gui = gui

    self.fab = create("TextButton", {
        Name = "Fab",
        Size = UDim2.fromOffset(58, 58),
        Position = UDim2.new(1, -18, 1, -18),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = Theme.accent,
        BorderSizePixel = 0,
        Text = "AI",
        Font = Theme.fontBold,
        TextSize = 19,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        AutoButtonColor = false,
        Visible = false,
    }, gui)
    withCorner(self.fab, 29)
    withStroke(self.fab, Color3.fromRGB(160, 140, 255), 1, 0.4)
    self.fab.MouseButton1Click:Connect(function()
        self:Toggle()
    end)

    self.root = create("Frame", {
        Name = "Window",
        Size = UDim2.fromOffset(WINDOW_WIDTH, WINDOW_HEIGHT),
        Position = UDim2.new(1, -16, 1, -16),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = Theme.bg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, gui)
    withCorner(self.root, 18)
    withStroke(self.root, Theme.border, 1, 0.2)

    self.scale = Instance.new("UIScale")
    self.scale.Parent = self.root

    self:BuildHeader()
    self:BuildChat()
    self:BuildInput()
    self:BuildSettings()
    self:UpdateScale()

    local camera = workspace.CurrentCamera
    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            self:UpdateScale()
        end)
    end
end

function UI:UpdateScale()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local scale = math.min(
        1,
        (viewport.X - 24) / WINDOW_WIDTH,
        (viewport.Y - 24) / WINDOW_HEIGHT
    )
    self.scale.Scale = Util.Clamp(scale, 0.62, 1)
end

function UI:BuildHeader()
    local header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1,
    }, self.root)
    self.header = header

    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(1, -130, 1, 0),
        Font = Theme.fontBold,
        TextSize = 15,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "WrenchAi",
    }, header)

    local function headerButton(text, xOffset, width, callback)
        local button = create("TextButton", {
            Size = UDim2.fromOffset(width or 28, 28),
            Position = UDim2.new(1, xOffset, 0, 9),
            BackgroundColor3 = Theme.panelAlt,
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            Text = text,
            Font = Theme.fontBold,
            TextSize = 11,
            TextColor3 = Theme.text,
            AutoButtonColor = false,
        }, header)
        withCorner(button, 8)
        button.MouseButton1Click:Connect(function()
            if callback then
                pcall(callback)
            end
        end)
        return button
    end

    self.closeButton = headerButton("X", -38, 28, function()
        self.root.Visible = false
        self.fab.Visible = true
    end)
    headerButton("CFG", -70, 30, function()
        self:OpenSettings()
    end)
    self.newButton = headerButton("+", -104, 30, function()
        if self.callbacks.onNewChat then
            pcall(self.callbacks.onNewChat)
        end
    end)

    self.status = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 46),
        Size = UDim2.new(1, -70, 0, 18),
        Font = Theme.font,
        TextSize = 11,
        TextColor3 = Theme.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Ready",
    }, self.root)

    self.stopButton = create("TextButton", {
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -58, 0, 44),
        Size = UDim2.fromOffset(46, 20),
        Text = "STOP",
        Font = Theme.fontBold,
        TextSize = 10,
        TextColor3 = Theme.err,
        Visible = false,
        AutoButtonColor = false,
    }, self.root)
    self.stopButton.MouseButton1Click:Connect(function()
        if self.callbacks.onStop then
            pcall(self.callbacks.onStop)
        end
        self:SetStatus("Stopping...", Theme.warn)
    end)

    create("Frame", {
        BackgroundColor3 = Theme.border,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 12, 0, 66),
        Size = UDim2.new(1, -24, 0, 1),
    }, self.root)

    local dragging = false
    local dragStart = nil
    local startPosition = nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local targetOk, target = pcall(function()
            return input.Target
        end)
        if targetOk and target and target:IsA("TextButton") then
            return
        end
        dragging = true
        dragStart = input.Position
        startPosition = self.root.Position
    end)
    header.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local delta = input.Position - dragStart
        self.root.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end)
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

function UI:BuildChat()
    local scroll = create("ScrollingFrame", {
        Name = "Chat",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 8, 0, 72),
        Size = UDim2.new(1, -16, 1, -72 - 96),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.border,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ClipsDescendants = true,
    }, self.root)
    self.scroll = scroll

    create("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, scroll)
    withPadding(scroll, 0, 4, 8, 4)
end

function UI:BuildInput()
    local frame = create("Frame", {
        Name = "Input",
        Position = UDim2.new(0, 10, 1, -88),
        Size = UDim2.new(1, -20, 0, 78),
        BackgroundColor3 = Theme.panel,
        BorderSizePixel = 0,
    }, self.root)
    withCorner(frame, 12)
    withStroke(frame, Theme.border, 1, 0.3)

    self.input = create("TextBox", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 8),
        Size = UDim2.new(1, -84, 1, -16),
        Font = Theme.font,
        TextSize = 13,
        TextColor3 = Theme.text,
        PlaceholderText = "Ask about this game...",
        PlaceholderColor3 = Theme.muted,
        TextWrapped = true,
        MultiLine = true,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = "",
    }, frame)

    self.sendButton = create("TextButton", {
        Position = UDim2.new(1, -64, 0, 8),
        Size = UDim2.fromOffset(54, 62),
        BackgroundColor3 = Theme.accent,
        BorderSizePixel = 0,
        Text = "Send",
        Font = Theme.fontBold,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        AutoButtonColor = false,
    }, frame)
    withCorner(self.sendButton, 10)
    self.sendButton.MouseButton1Click:Connect(function()
        self:Submit()
    end)

    if UserInputService.TouchEnabled then
        self.input.Focused:Connect(function()
            self.preFocusPosition = self.root.Position
            local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
            local lift = math.clamp(viewport.Y * 0.42, 180, 340)
            self.root.Position = UDim2.new(
                self.preFocusPosition.X.Scale,
                self.preFocusPosition.X.Offset,
                self.preFocusPosition.Y.Scale,
                self.preFocusPosition.Y.Offset - lift
            )
        end)
    end

    self.input.FocusLost:Connect(function(enterPressed)
        if self.preFocusPosition then
            self.root.Position = self.preFocusPosition
            self.preFocusPosition = nil
        end
        if enterPressed and not UserInputService.TouchEnabled then
            self:Submit()
        end
    end)
end

function UI:BuildSettings()
    local frame = create("Frame", {
        Name = "Settings",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.bg,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 10,
    }, self.root)
    withCorner(frame, 18)
    self.settingsFrame = frame

    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(1, -60, 0, 46),
        Font = Theme.fontBold,
        TextSize = 15,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Settings",
        ZIndex = 11,
    }, frame)

    local closeButton = create("TextButton", {
        Position = UDim2.new(1, -38, 0, 9),
        Size = UDim2.fromOffset(28, 28),
        BackgroundColor3 = Theme.panelAlt,
        BorderSizePixel = 0,
        Text = "X",
        Font = Theme.fontBold,
        TextSize = 11,
        TextColor3 = Theme.text,
        AutoButtonColor = false,
        ZIndex = 11,
    }, frame)
    withCorner(closeButton, 8)
    closeButton.MouseButton1Click:Connect(function()
        frame.Visible = false
    end)

    local content = create("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 12, 0, 50),
        Size = UDim2.new(1, -24, 1, -112),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.border,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 11,
    }, frame)
    create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, content)
    withPadding(content, 0, 0, 70, 0)

    local order = 0
    local function nextOrder()
        order += 1
        return order
    end

    local function addField(titleText, value, placeholder, multiline)
        local height = multiline and 96 or 52
        local holder = create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -6, 0, height),
            LayoutOrder = nextOrder(),
            ZIndex = 11,
        }, content)
        create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            Font = Theme.fontMedium,
            TextSize = 11,
            TextColor3 = Theme.muted,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = titleText,
            ZIndex = 11,
        }, holder)
        local box = create("TextBox", {
            Position = UDim2.new(0, 0, 0, 18),
            Size = UDim2.new(1, 0, 0, multiline and 72 or 30),
            BackgroundColor3 = Theme.panelAlt,
            BorderSizePixel = 0,
            Font = Theme.font,
            TextSize = 12,
            TextColor3 = Theme.text,
            PlaceholderText = placeholder or "",
            PlaceholderColor3 = Theme.muted,
            TextWrapped = multiline,
            MultiLine = multiline,
            ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
            Text = value or "",
            ZIndex = 11,
        }, holder)
        withCorner(box, 6)
        withPadding(box, multiline and 6 or 0, 8, multiline and 6 or 0, 8)
        return box
    end

    self.settingBaseURL = addField("Base URL", self.config.baseURL, "https://api.refuseless.com/v1")
    self.settingModel = addField("Model", self.config.model, "glm-5.3-abliterated")
    self.settingKey = addField("API key (stored on this device only)", self.config.apiKey, "sk-...")
    self.settingTemperature = addField("Temperature", tostring(self.config.temperature), "0.7")
    self.settingSteps = addField("Max agent steps", tostring(self.config.maxSteps), "12")
    self.settingCobalt = addField("Cobalt URL", self.config.cobaltURL, "")
    self.settingDex = addField("Dex URL", self.config.dexURL, "")
    self.settingExtra = addField("Extra system prompt", self.config.extraSystemPrompt, "Optional", true)

    local toggleHolder = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -6, 0, 40),
        LayoutOrder = nextOrder(),
        ZIndex = 11,
    }, content)
    self.autoApproveButton = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = Theme.panelAlt,
        BorderSizePixel = 0,
        Font = Theme.fontMedium,
        TextSize = 11,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 11,
    }, toggleHolder)
    withCorner(self.autoApproveButton, 6)
    withPadding(self.autoApproveButton, 0, 10, 0, 10)
    self.pendingAutoApprove = self.config.autoApproveScripts == true
    self.autoApproveButton.MouseButton1Click:Connect(function()
        self.pendingAutoApprove = not self.pendingAutoApprove
        self:UpdateAutoApproveLabel()
    end)
    self:UpdateAutoApproveLabel()

    self.settingsStatus = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -6, 0, 34),
        LayoutOrder = nextOrder(),
        Font = Theme.font,
        TextSize = 10,
        TextColor3 = Theme.muted,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = "",
        ZIndex = 11,
    }, content)

    local saveButton = create("TextButton", {
        Position = UDim2.new(0, 12, 1, -52),
        Size = UDim2.new(1, -24, 0, 38),
        BackgroundColor3 = Theme.accent,
        BorderSizePixel = 0,
        Text = "Save settings",
        Font = Theme.fontBold,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        AutoButtonColor = false,
        ZIndex = 11,
    }, frame)
    withCorner(saveButton, 10)
    saveButton.MouseButton1Click:Connect(function()
        self:SaveSettings()
    end)
end

function UI:UpdateAutoApproveLabel()
    local state = self.pendingAutoApprove and "ON" or "OFF"
    self.autoApproveButton.Text = "Always allow run_luau without asking: " .. state
    self.autoApproveButton.TextColor3 = self.pendingAutoApprove and Theme.warn or Theme.text
end

function UI:DiagnosticsText()
    local info = self.compat.Diagnostics()
    local available = table.concat(info.available, ", ")
    return "Executor: "
        .. info.executor
        .. " "
        .. info.version
        .. " ("
        .. info.environment
        .. ")\nAvailable: "
        .. Util.Truncate(available, 420)
        .. "\nAPI key and settings are written to WrenchAi/config.json when writefile exists."
end

function UI:OpenSettings()
    self.settingBaseURL.Text = self.config.baseURL or ""
    self.settingModel.Text = self.config.model or ""
    self.settingKey.Text = self.config.apiKey or ""
    self.settingTemperature.Text = tostring(self.config.temperature or 0.7)
    self.settingSteps.Text = tostring(self.config.maxSteps or 12)
    self.settingCobalt.Text = self.config.cobaltURL or ""
    self.settingDex.Text = self.config.dexURL or ""
    self.settingExtra.Text = self.config.extraSystemPrompt or ""
    self.pendingAutoApprove = self.config.autoApproveScripts == true
    self:UpdateAutoApproveLabel()
    self.settingsStatus.Text = self:DiagnosticsText()
    self.settingsFrame.Visible = true
end

function UI:SaveSettings()
    local baseURL = Util.Trim(self.settingBaseURL.Text)
    local model = Util.Trim(self.settingModel.Text)
    if baseURL == "" or model == "" then
        self.settingsStatus.Text = "Base URL and model are required."
        self.settingsStatus.TextColor3 = Theme.err
        return
    end
    local newConfig = Util.Copy(self.config)
    newConfig.baseURL = baseURL
    newConfig.model = model
    newConfig.apiKey = Util.Trim(self.settingKey.Text)
    newConfig.temperature = tonumber(self.settingTemperature.Text) or self.config.temperature
    newConfig.maxSteps = math.floor(tonumber(self.settingSteps.Text) or self.config.maxSteps)
    newConfig.cobaltURL = Util.Trim(self.settingCobalt.Text)
    newConfig.dexURL = Util.Trim(self.settingDex.Text)
    newConfig.extraSystemPrompt = self.settingExtra.Text or ""
    newConfig.autoApproveScripts = self.pendingAutoApprove

    local ok = true
    local message = "Saved."
    if self.callbacks.onSaveSettings then
        local callOk, resultOk, resultMessage = pcall(self.callbacks.onSaveSettings, newConfig)
        if not callOk then
            ok = false
            message = tostring(resultOk)
        elseif resultOk == false then
            ok = false
            message = tostring(resultMessage or "Could not save settings.")
        elseif type(resultMessage) == "string" then
            message = resultMessage
        end
    end
    self.config = newConfig
    self.settingsStatus.Text = message
    self.settingsStatus.TextColor3 = ok and Theme.ok or Theme.err
end

function UI:SetStatus(text, color)
    self.status.Text = text or ""
    self.status.TextColor3 = color or Theme.muted
end

function UI:SetRunning(running)
    self.running = running
    self.sendButton.Active = not running
    self.sendButton.BackgroundTransparency = running and 0.55 or 0
    self.sendButton.Text = running and "..." or "Send"
    self.stopButton.Visible = running
    if self.newButton then
        self.newButton.Active = not running
        self.newButton.TextTransparency = running and 0.5 or 0
    end
end

function UI:Toggle()
    self.root.Visible = not self.root.Visible
    self.fab.Visible = not self.root.Visible
end

function UI:Submit()
    if self.running then
        return
    end
    local text = Util.Trim(self.input.Text)
    if text == "" then
        return
    end
    self.input.Text = ""
    self:AddMessage("user", text)
    self:ScrollToBottom()
    if self.callbacks.onSend then
        pcall(self.callbacks.onSend, text)
    end
end

function UI:ClearMessages()
    for _, child in ipairs(self.scroll:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
    self.order = 0
end

function UI:ScrollToBottom()
    task.defer(function()
        task.wait()
        local ok, canvas = pcall(function()
            return self.scroll.AbsoluteCanvasSize
        end)
        if ok and canvas then
            self.scroll.CanvasPosition = Vector2.new(0, math.max(0, canvas.Y))
        end
    end)
end

function UI:NewRow()
    self.order += 1
    return create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -6, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self.order,
    }, self.scroll)
end

function UI:AddMessage(role, text)
    local row = self:NewRow()
    local isUser = role == "user"
    local bubble = create("Frame", {
        BackgroundColor3 = isUser and Theme.user or Theme.panel,
        BackgroundTransparency = isUser and 0 or 0.15,
        BorderSizePixel = 0,
        Size = UDim2.new(isUser and 0.9 or 0.98, 0, 0, 0),
        Position = isUser and UDim2.new(1, 0, 0, 0) or UDim2.new(0, 0, 0, 0),
        AnchorPoint = isUser and Vector2.new(1, 0) or Vector2.new(0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, row)
    withCorner(bubble, 10)
    withStroke(bubble, isUser and Theme.border or Theme.panelAlt, 1, 0.5)
    withPadding(bubble, 9, 12, 9, 12)
    create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, bubble)

    if not isUser then
        create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 12),
            Font = Theme.fontBold,
            TextSize = 9,
            TextColor3 = Theme.accent,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "WrenchAi",
        }, bubble)
    end

    for _, part in ipairs(splitFences(text or "")) do
        if part.code then
            local codeFrame = create("Frame", {
                BackgroundColor3 = Theme.code,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
            }, bubble)
            withCorner(codeFrame, 6)
            withPadding(codeFrame, 8, 10, 8, 10)
            create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Font = Theme.fontCode,
                TextSize = 12,
                TextColor3 = Theme.text,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                Text = (part.text ~= "" and part.text or " "),
            }, codeFrame)
        elseif Util.Trim(part.text) ~= "" then
            create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Font = Theme.font,
                TextSize = 13,
                TextColor3 = Theme.text,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                Text = part.text,
            }, bubble)
        end
    end
    self:ScrollToBottom()
end

function UI:AddSystem(text)
    local row = self:NewRow()
    create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -16, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Theme.font,
        TextSize = 10,
        TextColor3 = Theme.muted,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Center,
        Text = text,
    }, row)
    self:ScrollToBottom()
end

function UI:AddError(text)
    local row = self:NewRow()
    local frame = create("Frame", {
        BackgroundColor3 = Theme.err,
        BackgroundTransparency = 0.88,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -6, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, row)
    withCorner(frame, 8)
    withStroke(frame, Theme.err, 1, 0.4)
    withPadding(frame, 8, 10, 8, 10)
    create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Theme.fontMedium,
        TextSize = 11,
        TextColor3 = Theme.err,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = text,
    }, frame)
    self:ScrollToBottom()
end

function UI:AddToolCard(name, argsText)
    self.order += 1
    local card = create("Frame", {
        BackgroundColor3 = Theme.panelAlt,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -6, 0, 32),
        LayoutOrder = self.order,
        ClipsDescendants = true,
    }, self.scroll)
    withCorner(card, 8)
    withStroke(card, Theme.border, 1, 0.3)

    local header = create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 32),
        Text = "",
        AutoButtonColor = false,
    }, card)
    local title = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -20, 1, 0),
        Font = Theme.fontCode,
        TextSize = 11,
        TextColor3 = Theme.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "[..] " .. name .. " - running",
    }, header)

    local bodyHolder = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 32),
        Size = UDim2.new(1, -20, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, card)
    local body = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Theme.fontCode,
        TextSize = 10,
        TextColor3 = Theme.muted,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = argsText,
    }, bodyHolder)

    local expanded = false
    local function setExpanded(value)
        expanded = value
        bodyHolder.Visible = value
        if value then
            task.defer(function()
                task.wait()
                card.Size = UDim2.new(1, -6, 0, 34 + bodyHolder.AbsoluteSize.Y + 8)
            end)
        else
            card.Size = UDim2.new(1, -6, 0, 32)
        end
    end
    header.MouseButton1Click:Connect(function()
        setExpanded(not expanded)
        self:ScrollToBottom()
    end)

    local cardApi = {}
    local ui = self
    function cardApi:Finish(ok, resultText, seconds)
        local status = ok and "ok" or "error"
        title.Text = "["
            .. (ok and "OK" or "ERR")
            .. "] "
            .. name
            .. " - "
            .. status
            .. " - "
            .. Util.FormatSeconds(seconds or 0)
        title.TextColor3 = ok and Theme.ok or Theme.err
        body.Text = "args:\n"
            .. Util.Truncate(argsText or "{}", 800)
            .. "\n\nresult:\n"
            .. Util.Truncate(resultText or "", 3000)
        if not ok then
            setExpanded(true)
        end
        ui:ScrollToBottom()
    end
    function cardApi:Expand()
        setExpanded(true)
    end

    self:ScrollToBottom()
    return cardApi
end

function UI:AskApproval(spec, isCancelled)
    local state = { done = false, allow = false, always = false }
    self.pendingApproval = state

    if not self.root.Visible then
        self.root.Visible = true
        self.fab.Visible = false
    end

    local row = self:NewRow()
    local card = create("Frame", {
        BackgroundColor3 = Theme.panel,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -6, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, row)
    withCorner(card, 10)
    withStroke(card, Theme.warn, 1, 0.4)
    withPadding(card, 10, 12, 10, 12)
    create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, card)

    local title = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        Font = Theme.fontBold,
        TextSize = 12,
        TextColor3 = Theme.warn,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Permission - " .. tostring(spec.title or "Run code"),
    }, card)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Theme.font,
        TextSize = 11,
        TextColor3 = Theme.text,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = tostring(spec.description or ""),
    }, card)

    local codeScroll = create("ScrollingFrame", {
        BackgroundColor3 = Theme.code,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 140),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.border,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, card)
    withCorner(codeScroll, 6)
    withPadding(codeScroll, 6, 8, 6, 8)
    create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Theme.fontCode,
        TextSize = 11,
        TextColor3 = Theme.text,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = tostring(spec.code or ""),
    }, codeScroll)

    local buttons = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 34),
    }, card)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, buttons)

    local function decisionButton(text, color, order, callback)
        local button = create("TextButton", {
            Size = UDim2.new(0.32, -4, 1, 0),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Text = text,
            Font = Theme.fontBold,
            TextSize = 11,
            TextColor3 = Theme.text,
            AutoButtonColor = false,
            LayoutOrder = order,
        }, buttons)
        withCorner(button, 8)
        button.MouseButton1Click:Connect(function()
            if not state.done then
                callback()
            end
        end)
        return button
    end

    local function finish(allow, always)
        if state.done then
            return
        end
        state.done = true
        state.allow = allow
        state.always = always
        title.Text = allow and "Approved - Run code" or "Denied - Run code"
        title.TextColor3 = allow and Theme.ok or Theme.err
        for _, child in ipairs(buttons:GetChildren()) do
            if child:IsA("TextButton") then
                child.Active = false
                child.TextTransparency = 0.5
            end
        end
        self:SetStatus(allow and "Approved" or "Denied", allow and Theme.ok or Theme.err)
        self:ScrollToBottom()
    end

    decisionButton("Run", Theme.accent, 1, function()
        finish(true, false)
    end)
    decisionButton("Always", Theme.panelAlt, 2, function()
        finish(true, true)
    end)
    decisionButton("Deny", Color3.fromRGB(92, 34, 40), 3, function()
        finish(false, false)
    end)

    self:SetStatus("Waiting for approval", Theme.warn)
    self:ScrollToBottom()

    while not state.done do
        if isCancelled and isCancelled() then
            finish(false, false)
        end
        task.wait(0.1)
    end

    self.pendingApproval = nil
    return state.allow, state.always
end

return UI
