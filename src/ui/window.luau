local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Theme = require("./theme")
local Util = require("../util")

local UI = {}
UI.__index = UI

local DESIGN_WIDTH = 420
local DESIGN_HEIGHT = 700
local MIN_DESIGN_HEIGHT = 320
local WINDOW_MARGIN = 12
local HEADER_HEIGHT = 56
local STATUS_HEIGHT = 20
local CHAT_TOP = 78
local COMPOSER_HEIGHT = 74
local COMPOSER_BOTTOM = 16
local CHAT_BOTTOM = COMPOSER_BOTTOM + COMPOSER_HEIGHT + 6
local HERO_HEIGHT = 168

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

local function tween(instance, properties, duration, style, direction, repeatCount, reverses)
    local ok, animation = pcall(function()
        local info = TweenInfo.new(
            duration or 0.2,
            style or Enum.EasingStyle.Quad,
            direction or Enum.EasingDirection.Out,
            repeatCount or 0,
            reverses or false
        )
        local created = TweenService:Create(instance, info, properties)
        created:Play()
        return created
    end)
    if ok then
        return animation
    end
    return nil
end

local function withCorner(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = instance
    return corner
end

local function withStroke(instance, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Theme.line
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

local function withList(instance, padding, horizontal)
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, padding or 0)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    if horizontal then
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
    end
    layout.Parent = instance
    return layout
end

local function bar(parent, width, height, position, rotation, color)
    return create("Frame", {
        Size = UDim2.fromOffset(width, height),
        Position = position,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = color or Theme.text,
        BorderSizePixel = 0,
        Rotation = rotation or 0,
    }, parent)
end

local ICONS = {}

function ICONS.plus(parent, color)
    bar(parent, 11, 1.6, UDim2.fromScale(0.5, 0.5), 0, color)
    bar(parent, 1.6, 11, UDim2.fromScale(0.5, 0.5), 0, color)
end

function ICONS.minus(parent, color)
    bar(parent, 11, 1.6, UDim2.fromScale(0.5, 0.5), 0, color)
end

function ICONS.close(parent, color)
    bar(parent, 10, 1.6, UDim2.fromScale(0.5, 0.5), 45, color)
    bar(parent, 1.6, 10, UDim2.fromScale(0.5, 0.5), 45, color)
end

function ICONS.sliders(parent, color)
    bar(parent, 1.5, 11, UDim2.new(0.5, -3.5, 0.5, 0), 0, color)
    bar(parent, 1.5, 11, UDim2.new(0.5, 3.5, 0.5, 0), 0, color)
    bar(parent, 4, 4, UDim2.new(0.5, -3.5, 0.5, -2.5), 0, color)
    bar(parent, 4, 4, UDim2.new(0.5, 3.5, 0.5, 2), 0, color)
end

function ICONS.back(parent, color)
    bar(parent, 7.5, 1.6, UDim2.new(0.52, 0, 0.5, -3), 45, color)
    bar(parent, 7.5, 1.6, UDim2.new(0.52, 0, 0.5, 3), -45, color)
end

function ICONS.arrowUp(parent, color)
    bar(parent, 1.8, 13, UDim2.fromScale(0.5, 0.5), 0, color)
    bar(parent, 7, 1.8, UDim2.new(0.5, -2.2, 0.5, -4), 40, color)
    bar(parent, 7, 1.8, UDim2.new(0.5, 2.2, 0.5, -4), -40, color)
end

function ICONS.sparkle(parent, color)
    bar(parent, 11, 1.6, UDim2.fromScale(0.5, 0.5), 0, color)
    bar(parent, 1.6, 11, UDim2.fromScale(0.5, 0.5), 0, color)
    bar(parent, 8, 1.4, UDim2.fromScale(0.5, 0.5), 45, color)
    bar(parent, 8, 1.4, UDim2.fromScale(0.5, 0.5), -45, color)
end

function ICONS.clock(parent, color)
    bar(parent, 11, 1.5, UDim2.fromScale(0.5, 0.5), 0, color)
    bar(parent, 1.5, 11, UDim2.fromScale(0.5, 0.5), 0, color)
    bar(parent, 1.5, 5, UDim2.new(0.5, 0, 0.5, -2.5), 0, color)
    bar(parent, 5, 1.5, UDim2.new(0.5, 2.5, 0.5, 0), 0, color)
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

local function isInteractive(target)
    local current = target
    for _ = 1, 4 do
        if not current then
            return false
        end
        local ok, kind = pcall(function()
            return current.ClassName
        end)
        if ok and (kind == "TextButton" or kind == "ImageButton" or kind == "TextBox") then
            return true
        end
        local parentOk, parent = pcall(function()
            return current.Parent
        end)
        if not parentOk then
            return false
        end
        current = parent
    end
    return false
end

function UI.new(deps)
    local self = setmetatable({}, UI)
    self.config = deps.config
    self.compat = deps.compat
    self.callbacks = deps.callbacks or {}
    self.order = 0
    self.running = false
    self.pendingApproval = nil
    self.connections = {}
    self.destroyed = false
    self.thinkingCards = {}
    self.baseScale = 1
    self:Build()
    return self
end

function UI:Track(connection)
    if connection then
        table.insert(self.connections, connection)
    end
    return connection
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

    self.basePosition = UDim2.new(1, -WINDOW_MARGIN, 1, -WINDOW_MARGIN)

    self.root = create("Frame", {
        Name = "Window",
        Size = UDim2.fromOffset(DESIGN_WIDTH, DESIGN_HEIGHT),
        Position = self.basePosition,
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = Theme.bg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, gui)
    withCorner(self.root, Theme.radiusWindow)
    withStroke(self.root, Theme.line, 1, 0.25)
    local backdrop = Instance.new("UIGradient")
    backdrop.Color = ColorSequence.new(Color3.fromRGB(20, 20, 23), Theme.bg)
    backdrop.Rotation = 90
    backdrop.Parent = self.root

    create("Frame", {
        BackgroundColor3 = Theme.white,
        BackgroundTransparency = 0.94,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 14, 0, 1),
        Size = UDim2.new(1, -28, 0, 1),
    }, self.root)

    self.scale = Instance.new("UIScale")
    self.scale.Parent = self.root

    self:BuildHeader()
    self:BuildStatus()
    self:BuildChat()
    self:BuildComposer()
    self:BuildSettings()
    self:BuildSessions()
    self:BuildFab()
    self:BuildPill()

    self:UpdateScale()
    self:AnimateOpen()

    local camera = workspace.CurrentCamera
    if camera then
        self:Track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            self:UpdateScale()
        end))
    end
end

function UI:UpdateScale()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local availableWidth = math.max(viewport.X - WINDOW_MARGIN * 2, 260)
    local availableHeight = math.max(viewport.Y - WINDOW_MARGIN * 2, 280)

    -- Scale by width so text keeps its size; let the height shrink with the screen
    -- instead of shrinking a 700px design down to unreadable type on phones.
    local scale = math.min(availableWidth / DESIGN_WIDTH, 1)
    if availableHeight / scale < MIN_DESIGN_HEIGHT then
        scale = availableHeight / MIN_DESIGN_HEIGHT
    end

    self.baseScale = Util.Clamp(scale, 0.5, 1)
    self.designHeight = math.min(DESIGN_HEIGHT, availableHeight / self.baseScale)
    if self.root then
        self.root.Size = UDim2.fromOffset(DESIGN_WIDTH, self.designHeight)
    end
    if self.scale then
        self.scale.Scale = self.baseScale
    end
    self:ClampPosition()
end

function UI:ClampPosition()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local width = DESIGN_WIDTH * self.baseScale
    local height = (self.designHeight or DESIGN_HEIGHT) * self.baseScale
    local position = self.root.Position
    local x = Util.Clamp(position.X.Offset, width + 8 - viewport.X, -8)
    local y = Util.Clamp(position.Y.Offset, height + 8 - viewport.Y, -8)
    self.root.Position = UDim2.new(1, x, 1, y)
    self.basePosition = self.root.Position
end

function UI:AnimateOpen()
    if not self.root or not self.root.Visible then
        return
    end
    local target = self.baseScale
    self.scale.Scale = target * 0.965
    self.root.Position = UDim2.new(
        self.basePosition.X.Scale,
        self.basePosition.X.Offset,
        self.basePosition.Y.Scale,
        self.basePosition.Y.Offset + 10
    )
    tween(self.scale, { Scale = target }, 0.24, Enum.EasingStyle.Quint)
    tween(self.root, { Position = self.basePosition }, 0.28, Enum.EasingStyle.Quint)
end

function UI:BuildHeader()
    local header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
        BackgroundTransparency = 1,
    }, self.root)
    self.header = header

    local logo = create("Frame", {
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.fromOffset(14, 13),
        BackgroundColor3 = Theme.accent,
        BorderSizePixel = 0,
    }, header)
    withCorner(logo, 10)
    withStroke(logo, Theme.white, 1, 0.82)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new(Theme.accent, Theme.accentDeep)
    gradient.Rotation = 45
    gradient.Parent = logo
    create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Theme.fontBold,
        TextSize = 14,
        TextColor3 = Theme.white,
        Text = "W",
    }, logo)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(52, 7),
        Size = UDim2.new(1, -210, 0, 19),
        Font = Theme.fontBold,
        TextSize = 16,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "WrenchAi",
    }, header)

    self.modelChip = create("TextButton", {
        Position = UDim2.fromOffset(52, 29),
        Size = UDim2.fromOffset(10, 16),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.surfaceAlt,
        BorderSizePixel = 0,
        Font = Theme.fontCode,
        TextSize = 10,
        TextColor3 = Theme.muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        Text = Util.Truncate(tostring(self.config.model or "model"), 22),
        AutoButtonColor = false,
    }, header)
    withCorner(self.modelChip, 6)
    withPadding(self.modelChip, 0, 7, 0, 7)
    self.modelChip.MouseButton1Click:Connect(function()
        self:OpenSettings()
    end)

    local function headerButton(offset, icon, callback)
        local button = create("TextButton", {
            Size = UDim2.fromOffset(32, 32),
            Position = UDim2.new(1, offset, 0, 12),
            AnchorPoint = Vector2.new(1, 0),
            BackgroundColor3 = Theme.surfaceAlt,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
        }, header)
        withCorner(button, 10)
        local holder = create("Frame", {
            Size = UDim2.fromOffset(15, 15),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
        }, button)
        ICONS[icon](holder, Theme.muted)
        button.MouseEnter:Connect(function()
            tween(button, { BackgroundTransparency = 0 }, 0.14)
        end)
        button.MouseLeave:Connect(function()
            tween(button, { BackgroundTransparency = 1 }, 0.14)
        end)
        button.MouseButton1Click:Connect(function()
            if callback then
                pcall(callback)
            end
        end)
        return button
    end

    self.closeButton = headerButton(-14, "close", function()
        self:Hide()
    end)
    self.minimizeButton = headerButton(-52, "minus", function()
        self:Minimize()
    end)
    headerButton(-90, "sliders", function()
        self:OpenSettings()
    end)
    self.newButton = headerButton(-128, "plus", function()
        if self.callbacks.onNewChat then
            pcall(self.callbacks.onNewChat)
        end
    end)
    self.historyButton = headerButton(-166, "clock", function()
        self:OpenSessions()
    end)

    create("Frame", {
        BackgroundColor3 = Theme.lineSoft,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, HEADER_HEIGHT - 1),
        Size = UDim2.new(1, 0, 0, 1),
    }, header)

    local dragging = false
    local dragStart = nil
    local startOffset = nil
    header.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local ok, target = pcall(function()
            return input.Target
        end)
        if ok and isInteractive(target) then
            return
        end
        dragging = true
        dragStart = input.Position
        startOffset = Vector2.new(self.root.Position.X.Offset, self.root.Position.Y.Offset)
    end)
    header.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local delta = (input.Position - dragStart) / self.baseScale
        self.root.Position = UDim2.new(
            1,
            startOffset.X + delta.X,
            1,
            startOffset.Y + delta.Y
        )
    end)
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                self:ClampPosition()
            end
        end
    end)
end

function UI:BuildStatus()
    self.statusDot = create("Frame", {
        Size = UDim2.fromOffset(6, 6),
        Position = UDim2.fromOffset(16, 63),
        BackgroundColor3 = Theme.faint,
        BorderSizePixel = 0,
    }, self.root)
    withCorner(self.statusDot, 3)

    self.status = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(27, 56),
        Size = UDim2.new(1, -110, 0, STATUS_HEIGHT),
        Font = Theme.font,
        TextSize = 10,
        TextColor3 = Theme.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Ready",
    }, self.root)

    self.stopButton = create("TextButton", {
        Size = UDim2.fromOffset(52, 18),
        Position = UDim2.new(1, -14, 0, 58),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = Theme.errFill,
        BorderSizePixel = 0,
        Text = "Stop",
        Font = Theme.fontBold,
        TextSize = 10,
        TextColor3 = Theme.err,
        AutoButtonColor = false,
        Visible = false,
    }, self.root)
    withCorner(self.stopButton, 9)
    self.stopButton.MouseButton1Click:Connect(function()
        if self.callbacks.onStop then
            pcall(self.callbacks.onStop)
        end
        self:SetStatus("Stopping", Theme.warn)
    end)

    create("Frame", {
        BackgroundColor3 = Theme.lineSoft,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, HEADER_HEIGHT + STATUS_HEIGHT),
        Size = UDim2.new(1, 0, 0, 1),
    }, self.root)
end

function UI:BuildChat()
    local scroll = create("ScrollingFrame", {
        Name = "Chat",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, CHAT_TOP),
        Size = UDim2.new(1, 0, 1, -CHAT_TOP - CHAT_BOTTOM),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.line,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ClipsDescendants = true,
    }, self.root)
    self.scroll = scroll
    withList(scroll, 14)
    withPadding(scroll, 8, 16, 12, 16)
    self:BuildHero()
end

function UI:BuildHero()
    local hero = create("Frame", {
        Name = "Hero",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, HERO_HEIGHT),
        LayoutOrder = 0,
    }, self.scroll)
    self.hero = hero

    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 6),
        Size = UDim2.new(1, 0, 0, 22),
        Font = Theme.fontBold,
        TextSize = 17,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "How can I help?",
    }, hero)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 30),
        Size = UDim2.new(1, -20, 0, 16),
        Font = Theme.font,
        TextSize = 10,
        TextColor3 = Theme.faint,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Inspect the game, read scripts, drive GUIs, run Luau.",
    }, hero)

    local prompts = {
        "What game is this and what can you see?",
        "List the LocalScripts in this game",
        "Show me the remote events firing",
    }
    for index, prompt in ipairs(prompts) do
        local chip = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 34),
            Position = UDim2.new(0, 0, 0, 54 + (index - 1) * 38),
            BackgroundColor3 = Theme.surface,
            BorderSizePixel = 0,
            Text = prompt,
            Font = Theme.fontMedium,
            TextSize = 11,
            TextColor3 = Theme.muted,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
        }, hero)
        withCorner(chip, 11)
        withStroke(chip, Theme.lineSoft, 1, 0.3)
        withPadding(chip, 0, 12, 0, 12)
        chip.MouseEnter:Connect(function()
            tween(chip, { BackgroundColor3 = Theme.surfaceHi }, 0.14)
        end)
        chip.MouseLeave:Connect(function()
            tween(chip, { BackgroundColor3 = Theme.surface }, 0.14)
        end)
        chip.MouseButton1Click:Connect(function()
            self.input.Text = prompt
            self:Submit()
        end)
    end
end

function UI:HideHero()
    if self.hero and self.hero.Visible then
        self.hero.Visible = false
        self.hero.Size = UDim2.new(1, 0, 0, 0)
    end
end

function UI:BuildComposer()
    local frame = create("Frame", {
        Name = "Composer",
        Position = UDim2.new(0, 12, 1, -(COMPOSER_BOTTOM + COMPOSER_HEIGHT)),
        Size = UDim2.new(1, -24, 0, COMPOSER_HEIGHT),
        BackgroundColor3 = Theme.surfaceAlt,
        BorderSizePixel = 0,
    }, self.root)
    withCorner(frame, 18)
    self.composerStroke = withStroke(frame, Theme.line, 1, 0.35)
    self.composer = frame

    self.input = create("TextBox", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 8),
        Size = UDim2.new(1, -72, 0, 32),
        Font = Theme.font,
        TextSize = 13,
        TextColor3 = Theme.text,
        PlaceholderText = "Ask WrenchAi anything...",
        PlaceholderColor3 = Theme.faint,
        TextWrapped = true,
        MultiLine = true,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = "",
    }, frame)

    self.sendButton = create("TextButton", {
        Size = UDim2.fromOffset(36, 36),
        Position = UDim2.new(1, -12, 0, 7),
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = Theme.accent,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, frame)
    withCorner(self.sendButton, 18)

    self.sendIcon = create("Frame", {
        Size = UDim2.fromOffset(32, 32),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
    }, self.sendButton)
    ICONS.arrowUp(self.sendIcon, Theme.white)
    self.stopIcon = create("Frame", {
        Size = UDim2.fromOffset(9, 9),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.white,
        BorderSizePixel = 0,
        Visible = false,
    }, self.sendButton)
    withCorner(self.stopIcon, 2)

    self.sendButton.MouseEnter:Connect(function()
        tween(self.sendButton, { BackgroundColor3 = Theme.accentDeep }, 0.14)
    end)
    self.sendButton.MouseLeave:Connect(function()
        tween(self.sendButton, { BackgroundColor3 = Theme.accent }, 0.14)
    end)
    self.sendButton.MouseButton1Click:Connect(function()
        self:Submit()
    end)

    create("Frame", {
        BackgroundColor3 = Theme.lineSoft,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 16, 0, 48),
        Size = UDim2.new(1, -32, 0, 1),
    }, frame)

    self.composerModel = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 54),
        Size = UDim2.new(1, -150, 0, 14),
        Font = Theme.fontCode,
        TextSize = 9,
        TextColor3 = Theme.faint,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = Util.Truncate(tostring(self.config.model or "model"), 30),
    }, frame)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -16, 0, 54),
        Size = UDim2.fromOffset(134, 14),
        AnchorPoint = Vector2.new(1, 0),
        Font = Theme.font,
        TextSize = 9,
        TextColor3 = Theme.faint,
        TextXAlignment = Enum.TextXAlignment.Right,
        Text = UserInputService.TouchEnabled and "Tap send" or "Enter to send",
    }, frame)

    self.input.Focused:Connect(function()
        tween(self.composerStroke, { Color = Theme.accent, Transparency = 0.45 }, 0.16)
        if UserInputService.TouchEnabled then
            self.preFocusPosition = self.root.Position
            local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
                or Vector2.new(1280, 720)
            local lift = math.clamp(viewport.Y * 0.42, 180, 360)
            local position = self.preFocusPosition
            local target = UDim2.new(
                position.X.Scale,
                position.X.Offset,
                position.Y.Scale,
                position.Y.Offset - lift
            )
            tween(self.root, { Position = target }, 0.22, Enum.EasingStyle.Quint)
        end
    end)

    self.input.FocusLost:Connect(function(enterPressed)
        tween(self.composerStroke, { Color = Theme.line, Transparency = 0.25 }, 0.16)
        if self.preFocusPosition then
            tween(self.root, { Position = self.preFocusPosition }, 0.22, Enum.EasingStyle.Quint)
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
        ClipsDescendants = true,
    }, self.root)
    withCorner(frame, Theme.radiusWindow)
    self.settingsFrame = frame

    local back = create("TextButton", {
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.fromOffset(12, 12),
        BackgroundColor3 = Theme.surfaceAlt,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 12,
    }, frame)
    withCorner(back, 9)
    local backIcon = create("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
    }, back)
    ICONS.back(backIcon, Theme.muted)
    back.MouseEnter:Connect(function()
        tween(back, { BackgroundTransparency = 0 }, 0.14)
    end)
    back.MouseLeave:Connect(function()
        tween(back, { BackgroundTransparency = 1 }, 0.14)
    end)
    back.MouseButton1Click:Connect(function()
        frame.Visible = false
    end)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(52, 8),
        Size = UDim2.new(1, -70, 0, 20),
        Font = Theme.fontBold,
        TextSize = 15,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Settings",
        ZIndex = 12,
    }, frame)
    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(52, 28),
        Size = UDim2.new(1, -70, 0, 14),
        Font = Theme.font,
        TextSize = 9,
        TextColor3 = Theme.faint,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Connection, agent behaviour and tools",
        ZIndex = 12,
    }, frame)

    create("Frame", {
        BackgroundColor3 = Theme.lineSoft,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 12, 0, 54),
        Size = UDim2.new(1, -24, 0, 1),
        ZIndex = 12,
    }, frame)

    local content = create("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 60),
        Size = UDim2.new(1, 0, 1, -60 - 66),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.line,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 11,
    }, frame)
    withList(content, 8)
    withPadding(content, 4, 16, 18, 16)
    self.settingsContent = content

    local order = 0
    local function nextOrder()
        order += 1
        return order
    end

    local function section(titleText)
        create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            LayoutOrder = nextOrder(),
            Font = Theme.fontBold,
            TextSize = 9,
            TextColor3 = Theme.faint,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.upper(titleText),
            ZIndex = 11,
        }, content)
    end

    local function field(titleText, value, placeholder, multiline)
        local height = multiline and 96 or 56
        local holder = create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, height),
            LayoutOrder = nextOrder(),
            ZIndex = 11,
        }, content)
        create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            Font = Theme.fontMedium,
            TextSize = 10,
            TextColor3 = Theme.muted,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = titleText,
            ZIndex = 11,
        }, holder)
        local box = create("TextBox", {
            Position = UDim2.new(0, 0, 0, 16),
            Size = UDim2.new(1, 0, 0, multiline and 70 or 38),
            BackgroundColor3 = Theme.surfaceAlt,
            BorderSizePixel = 0,
            Font = Theme.font,
            TextSize = 12,
            TextColor3 = Theme.text,
            PlaceholderText = placeholder or "",
            PlaceholderColor3 = Theme.faint,
            TextWrapped = multiline,
            MultiLine = multiline,
            ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
            Text = value or "",
            ZIndex = 11,
        }, holder)
        withCorner(box, 10)
        local stroke = withStroke(box, Theme.lineSoft, 1, 0.25)
        withPadding(box, multiline and 8 or 0, 10, multiline and 8 or 0, 10)
        box.Focused:Connect(function()
            tween(stroke, { Color = Theme.accent, Transparency = 0.35 }, 0.16)
            tween(box, { BackgroundColor3 = Theme.surfaceHi }, 0.16)
        end)
        box.FocusLost:Connect(function()
            tween(stroke, { Color = Theme.lineSoft, Transparency = 0.25 }, 0.16)
            tween(box, { BackgroundColor3 = Theme.surfaceAlt }, 0.16)
        end)
        return box
    end

    section("Connection")
    self.settingBaseURL = field("Base URL", self.config.baseURL, "https://api.reflection.ai/openai/v1")
    self.settingModel = field("Model", self.config.model, "Beam-1.0-501B-A23B")
    self.settingKey = field("API key (stored on this device)", self.config.apiKey, "sk-...")

    section("Agent")
    self.settingTemperature = field("Temperature", tostring(self.config.temperature), "0.7")
    self.settingSteps = field("Max agent steps", tostring(self.config.maxSteps), "12")
    self.settingExtra = field("Extra system prompt", self.config.extraSystemPrompt, "Optional", true)

    section("Tools")
    self.settingCobalt = field("Cobalt URL", self.config.cobaltURL, "")
    self.settingDex = field("Dex URL", self.config.dexURL, "")

    section("Permissions")
    local toggleRow = create("Frame", {
        BackgroundColor3 = Theme.surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 50),
        LayoutOrder = nextOrder(),
        ZIndex = 11,
    }, content)
    withCorner(toggleRow, 12)
    withStroke(toggleRow, Theme.lineSoft, 1, 0.3)

    self.autoApproveButton = create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        AutoButtonColor = false,
        ZIndex = 12,
    }, toggleRow)

    self.autoApproveLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -72, 1, 0),
        Font = Theme.fontMedium,
        TextSize = 11,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Always allow run_luau",
        ZIndex = 12,
    }, toggleRow)

    self.switchTrack = create("Frame", {
        Size = UDim2.fromOffset(40, 22),
        Position = UDim2.new(1, -12, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Theme.surfaceHi,
        BorderSizePixel = 0,
        ZIndex = 12,
    }, toggleRow)
    withCorner(self.switchTrack, 11)
    self.switchKnob = create("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = Theme.muted,
        BorderSizePixel = 0,
        ZIndex = 13,
    }, self.switchTrack)
    withCorner(self.switchKnob, 8)

    self.pendingAutoApprove = self.config.autoApproveScripts == true
    self.autoApproveButton.MouseButton1Click:Connect(function()
        self.pendingAutoApprove = not self.pendingAutoApprove
        self:UpdateAutoApproveLabel()
    end)
    self:UpdateAutoApproveLabel()

    self.settingsStatus = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = nextOrder(),
        Font = Theme.font,
        TextSize = 9,
        TextColor3 = Theme.faint,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = "",
        ZIndex = 11,
    }, content)

    local saveButton = create("TextButton", {
        Position = UDim2.new(0, 14, 1, -54),
        Size = UDim2.new(1, -28, 0, 40),
        BackgroundColor3 = Theme.accent,
        BorderSizePixel = 0,
        Text = "Save settings",
        Font = Theme.fontBold,
        TextSize = 12,
        TextColor3 = Theme.white,
        AutoButtonColor = false,
        ZIndex = 12,
    }, frame)
    withCorner(saveButton, 13)
    saveButton.MouseEnter:Connect(function()
        tween(saveButton, { BackgroundColor3 = Theme.accentDeep }, 0.14)
    end)
    saveButton.MouseLeave:Connect(function()
        tween(saveButton, { BackgroundColor3 = Theme.accent }, 0.14)
    end)
    saveButton.MouseButton1Click:Connect(function()
        self:SaveSettings()
    end)
end

function UI:BuildSessions()
    local frame = create("Frame", {
        Name = "Sessions",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.bg,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 10,
        ClipsDescendants = true,
    }, self.root)
    withCorner(frame, Theme.radiusWindow)
    self.sessionsFrame = frame

    local back = create("TextButton", {
        Size = UDim2.fromOffset(30, 30),
        Position = UDim2.fromOffset(12, 12),
        BackgroundColor3 = Theme.surfaceAlt,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 12,
    }, frame)
    withCorner(back, 9)
    local backIcon = create("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
    }, back)
    ICONS.back(backIcon, Theme.muted)
    back.MouseEnter:Connect(function()
        tween(back, { BackgroundTransparency = 0 }, 0.14)
    end)
    back.MouseLeave:Connect(function()
        tween(back, { BackgroundTransparency = 1 }, 0.14)
    end)
    back.MouseButton1Click:Connect(function()
        self:CloseSessions()
    end)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(52, 8),
        Size = UDim2.new(1, -70, 0, 20),
        Font = Theme.fontBold,
        TextSize = 15,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Chats",
        ZIndex = 12,
    }, frame)
    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(52, 28),
        Size = UDim2.new(1, -70, 0, 14),
        Font = Theme.font,
        TextSize = 9,
        TextColor3 = Theme.faint,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Your conversations, saved on this device",
        ZIndex = 12,
    }, frame)

    local newChat = create("TextButton", {
        Position = UDim2.new(0, 14, 0, 54),
        Size = UDim2.new(1, -28, 0, 40),
        BackgroundColor3 = Theme.accent,
        BorderSizePixel = 0,
        Text = "New chat",
        Font = Theme.fontBold,
        TextSize = 12,
        TextColor3 = Theme.white,
        AutoButtonColor = false,
        ZIndex = 12,
    }, frame)
    withCorner(newChat, 13)
    newChat.MouseEnter:Connect(function()
        tween(newChat, { BackgroundColor3 = Theme.accentDeep }, 0.14)
    end)
    newChat.MouseLeave:Connect(function()
        tween(newChat, { BackgroundColor3 = Theme.accent }, 0.14)
    end)
    newChat.MouseButton1Click:Connect(function()
        if self.callbacks.onNewChat then
            pcall(self.callbacks.onNewChat)
        end
        self:CloseSessions()
    end)

    local scroll = create("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 104),
        Size = UDim2.new(1, 0, 1, -104 - 92),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.line,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 11,
    }, frame)
    withList(scroll, 6)
    withPadding(scroll, 2, 14, 10, 14)
    self.sessionsScroll = scroll

    local profile = create("Frame", {
        Position = UDim2.new(0, 14, 1, -84),
        Size = UDim2.new(1, -28, 0, 70),
        BackgroundColor3 = Theme.surface,
        BorderSizePixel = 0,
        ZIndex = 12,
    }, frame)
    withCorner(profile, 14)
    withStroke(profile, Theme.lineSoft, 1, 0.35)

    self.profileAvatar = create("Frame", {
        Size = UDim2.fromOffset(40, 40),
        Position = UDim2.fromOffset(12, 15),
        BackgroundColor3 = Theme.surfaceHi,
        BorderSizePixel = 0,
    }, profile)
    withCorner(self.profileAvatar, 20)
    self.profileImage = create("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        Visible = false,
    }, self.profileAvatar)
    withCorner(self.profileImage, 20)
    self.profileLetter = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Theme.fontBold,
        TextSize = 16,
        TextColor3 = Theme.white,
        Text = "?",
    }, self.profileAvatar)

    self.profileName = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(64, 10),
        Size = UDim2.new(1, -76, 0, 18),
        Font = Theme.fontBold,
        TextSize = 13,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "Player",
    }, profile)
    self.profileHandle = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(64, 29),
        Size = UDim2.new(1, -76, 0, 14),
        Font = Theme.font,
        TextSize = 10,
        TextColor3 = Theme.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "@player",
    }, profile)
    self.profileMeta = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(64, 45),
        Size = UDim2.new(1, -76, 0, 14),
        Font = Theme.fontCode,
        TextSize = 8,
        TextColor3 = Theme.faint,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "",
    }, profile)

    self:FillProfile()
end

function UI:FillProfile()
    local player = Players.LocalPlayer
    local name = "Player"
    local displayName = "Player"
    local userId = 0
    pcall(function()
        name = tostring(player.Name)
        displayName = tostring(player.DisplayName)
        userId = tonumber(player.UserId) or 0
    end)
    if self.profileName then
        self.profileName.Text = displayName
    end
    if self.profileHandle then
        self.profileHandle.Text = "@" .. name
    end
    if self.profileMeta then
        self.profileMeta.Text = "User ID "
            .. tostring(userId)
            .. " · "
            .. tostring(self.compat.ExecutorName or "executor")
    end
    if self.profileLetter then
        self.profileLetter.Text = string.upper(string.sub(name, 1, 1))
    end
    task.spawn(function()
        local ok, url = pcall(function()
            return Players:GetUserThumbnailAsync(
                userId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size420x420
            )
        end)
        if ok and type(url) == "string" and #url > 0 and not self.destroyed and self.profileImage then
            self.profileImage.Image = url
            self.profileImage.Visible = true
            self.profileLetter.Visible = false
        end
    end)
end

function UI:RenderSessions(list, currentId)
    self.lastSessions = list or {}
    self.lastCurrentId = currentId
    if not self.sessionsScroll then
        return
    end
    for _, child in ipairs(self.sessionsScroll:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end

    if #self.lastSessions == 0 then
        create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 0,
            Font = Theme.font,
            TextSize = 10,
            TextColor3 = Theme.faint,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center,
            Text = "No chats yet. Tap New chat to start one.",
            ZIndex = 11,
        }, self.sessionsScroll)
        return
    end

    local order = 0
    for _, chat in ipairs(self.lastSessions) do
        order += 1
        local active = chat.id == currentId
        local row = create("Frame", {
            BackgroundColor3 = Theme.surface,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 56),
            LayoutOrder = order,
            ZIndex = 11,
        }, self.sessionsScroll)
        withCorner(row, 12)
        withStroke(row, active and Theme.accent or Theme.lineSoft, 1, active and 0.8 or 0.35)

        local main = create("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -36, 1, 0),
            Text = "",
            AutoButtonColor = false,
            ZIndex = 12,
        }, row)
        create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 8),
            Size = UDim2.new(1, -64, 0, 16),
            Font = Theme.fontBold,
            TextSize = 12,
            TextColor3 = active and Theme.accent or Theme.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = chat.title or "New chat",
            ZIndex = 12,
        }, row)
        create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 28),
            Size = UDim2.new(1, -64, 0, 14),
            Font = Theme.font,
            TextSize = 9,
            TextColor3 = Theme.faint,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = chat.preview or "",
            ZIndex = 12,
        }, row)
        local age = math.max(0, (os.time() or 0) - (tonumber(chat.createdAt) or 0))
        local ageText = "just now"
        if age >= 86400 then
            ageText = tostring(math.floor(age / 86400)) .. "d ago"
        elseif age >= 3600 then
            ageText = tostring(math.floor(age / 3600)) .. "h ago"
        elseif age >= 60 then
            ageText = tostring(math.floor(age / 60)) .. "m ago"
        end
        create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -42, 0, 9),
            Size = UDim2.fromOffset(34, 12),
            Font = Theme.font,
            TextSize = 8,
            TextColor3 = Theme.faint,
            TextXAlignment = Enum.TextXAlignment.Right,
            Text = ageText,
            ZIndex = 12,
        }, row)

        local del = create("TextButton", {
            Size = UDim2.fromOffset(26, 26),
            Position = UDim2.new(1, -5, 0, 15),
            BackgroundColor3 = Theme.surfaceHi,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 13,
        }, row)
        withCorner(del, 9)
        local delIcon = create("Frame", {
            Size = UDim2.fromOffset(10, 10),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
        }, del)
        ICONS.close(delIcon, Theme.faint)
        del.MouseEnter:Connect(function()
            tween(del, { BackgroundTransparency = 0 }, 0.12)
        end)
        del.MouseLeave:Connect(function()
            tween(del, { BackgroundTransparency = 1 }, 0.12)
        end)
        del.MouseButton1Click:Connect(function()
            if self.callbacks.onDeleteChat then
                pcall(self.callbacks.onDeleteChat, chat.id)
            end
        end)
        main.MouseButton1Click:Connect(function()
            if self.callbacks.onSwitchChat then
                pcall(self.callbacks.onSwitchChat, chat.id)
            end
        end)
    end
end

function UI:OpenSessions()
    if not self.root.Visible then
        self:Show()
    end
    if self.settingsFrame and self.settingsFrame.Visible then
        self.settingsFrame.Visible = false
    end
    self:RenderSessions(self.lastSessions or {}, self.lastCurrentId)
    self.sessionsFrame.Visible = true
    self.sessionsFrame.Position = UDim2.new(-1, -DESIGN_WIDTH, 0, 0)
    tween(self.sessionsFrame, { Position = UDim2.new(0, 0, 0, 0) }, 0.22, Enum.EasingStyle.Quint)
end

function UI:CloseSessions()
    if not self.sessionsFrame or not self.sessionsFrame.Visible then
        return
    end
    tween(self.sessionsFrame, {
        Position = UDim2.new(-1, -DESIGN_WIDTH, 0, 0),
    }, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    task.delay(0.2, function()
        if not self.destroyed and self.sessionsFrame then
            self.sessionsFrame.Visible = false
        end
    end)
end

function UI:BuildFab()
    self.fab = create("TextButton", {
        Name = "Fab",
        Size = UDim2.fromOffset(58, 58),
        Position = UDim2.new(1, -18, 1, -18),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = Theme.accent,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Visible = false,
    }, self.gui)
    withCorner(self.fab, 29)
    withStroke(self.fab, Theme.white, 1, 0.8)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new(Theme.accent, Theme.accentDeep)
    gradient.Rotation = 45
    gradient.Parent = self.fab

    local ring = create("Frame", {
        Size = UDim2.fromOffset(58, 58),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 0,
    }, self.fab)
    withCorner(ring, 29)
    local ringStroke = withStroke(ring, Theme.accent, 1.5, 0.55)
    tween(ringStroke, { Transparency = 1 }, 1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

    local icon = create("Frame", {
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        ZIndex = 2,
    }, self.fab)
    ICONS.plus(icon, Theme.white)

    self.fab.MouseButton1Click:Connect(function()
        self:Show()
    end)
    self.fab.MouseEnter:Connect(function()
        tween(self.fab, { BackgroundColor3 = Theme.accentDeep }, 0.14)
    end)
    self.fab.MouseLeave:Connect(function()
        tween(self.fab, { BackgroundColor3 = Theme.accent }, 0.14)
    end)
end

function UI:BuildPill()
    local pill = create("TextButton", {
        Name = "Minimized",
        Size = UDim2.fromOffset(182, 44),
        Position = UDim2.new(1, -18, 1, -18),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundColor3 = Theme.surface,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Visible = false,
    }, self.gui)
    withCorner(pill, 22)
    withStroke(pill, Theme.line, 1, 0.3)
    self.pill = pill

    local logo = create("Frame", {
        Size = UDim2.fromOffset(24, 24),
        Position = UDim2.fromOffset(10, 10),
        BackgroundColor3 = Theme.accent,
        BorderSizePixel = 0,
    }, pill)
    withCorner(logo, 8)
    create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Theme.fontBold,
        TextSize = 11,
        TextColor3 = Theme.white,
        Text = "W",
    }, logo)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(42, 6),
        Size = UDim2.new(1, -52, 0, 16),
        Font = Theme.fontBold,
        TextSize = 11,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "WrenchAi",
    }, pill)

    self.pillStatusDot = create("Frame", {
        Size = UDim2.fromOffset(5, 5),
        Position = UDim2.fromOffset(43, 27),
        BackgroundColor3 = Theme.faint,
        BorderSizePixel = 0,
    }, pill)
    withCorner(self.pillStatusDot, 3)

    self.pillStatus = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(53, 20),
        Size = UDim2.new(1, -63, 0, 14),
        Font = Theme.font,
        TextSize = 9,
        TextColor3 = Theme.faint,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Ready",
    }, pill)

    pill.MouseButton1Click:Connect(function()
        self:Show()
    end)
end

function UI:UpdateAutoApproveLabel()
    local enabled = self.pendingAutoApprove == true
    if self.autoApproveLabel then
        self.autoApproveLabel.TextColor3 = enabled and Theme.text or Theme.muted
    end
    if self.switchTrack then
        tween(self.switchTrack, {
            BackgroundColor3 = enabled and Theme.accent or Theme.surfaceHi,
        }, 0.18)
    end
    if self.switchKnob then
        tween(self.switchKnob, {
            Position = UDim2.fromOffset(enabled and 21 or 3, 3),
            BackgroundColor3 = enabled and Theme.white or Theme.muted,
        }, 0.18, Enum.EasingStyle.Quint)
    end
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
        .. "\nSettings are written to WrenchAi/config.json when writefile exists."
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
    self.settingsStatus.TextColor3 = Theme.faint

    if not self.root.Visible then
        self:Show()
    end
    if self.sessionsFrame and self.sessionsFrame.Visible then
        self.sessionsFrame.Visible = false
    end
    self.settingsFrame.Visible = true
    self.settingsFrame.Position = UDim2.new(1, DESIGN_WIDTH, 0, 0)
    tween(self.settingsFrame, { Position = UDim2.new(0, 0, 0, 0) }, 0.22, Enum.EasingStyle.Quint)
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
    if self.modelChip then
        self.modelChip.Text = Util.Truncate(model, 22)
    end
    if self.composerModel then
        self.composerModel.Text = Util.Truncate(model, 30)
    end
    self.settingsStatus.Text = message
    self.settingsStatus.TextColor3 = ok and Theme.ok or Theme.err
end

function UI:SetStatus(text, color)
    if self.status then
        self.status.Text = text or ""
        self.status.TextColor3 = color or Theme.muted
    end
    if self.statusDot then
        self.statusDot.BackgroundColor3 = color or Theme.faint
    end
    if self.pillStatus then
        self.pillStatus.Text = text or "Ready"
        self.pillStatus.TextColor3 = color or Theme.faint
    end
    if self.pillStatusDot then
        self.pillStatusDot.BackgroundColor3 = color or Theme.faint
    end
end

function UI:SetRunning(running)
    self.running = running
    self.sendButton.Active = not running
    self.sendButton.BackgroundTransparency = running and 0.35 or 0
    self.sendIcon.Visible = not running
    self.stopIcon.Visible = running
    self.stopButton.Visible = running
    if self.newButton then
        self.newButton.Active = not running
        self.newButton.TextTransparency = running and 0.5 or 0
    end
    if self.statusPulse then
        pcall(function()
            self.statusPulse:Cancel()
        end)
        self.statusPulse = nil
    end
    if self.statusDot then
        self.statusDot.BackgroundTransparency = 0
        if running then
            self.statusPulse = tween(self.statusDot, { BackgroundTransparency = 0.65 }, 0.7,
                Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
        end
    end
    if not running then
        self:SettleThinking()
    end
end

function UI:Show()
    self.root.Visible = true
    self.fab.Visible = false
    self.pill.Visible = false
    self:AnimateOpen()
end

function UI:Hide()
    self.root.Visible = false
    self.fab.Visible = true
    self.fab.Size = UDim2.fromOffset(40, 40)
    tween(self.fab, { Size = UDim2.fromOffset(58, 58) }, 0.24, Enum.EasingStyle.Back)
end

function UI:Minimize()
    if not self.root.Visible then
        return
    end
    local position = self.root.Position
    tween(self.scale, { Scale = self.baseScale * 0.9 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    tween(self.root, {
        Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + 26),
    }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    task.delay(0.18, function()
        if self.destroyed then
            return
        end
        self.root.Visible = false
        self.scale.Scale = self.baseScale
        self.root.Position = self.basePosition
        self.pill.Visible = true
        self.pill.Size = UDim2.fromOffset(150, 40)
        tween(self.pill, { Size = UDim2.fromOffset(182, 44) }, 0.22, Enum.EasingStyle.Back)
    end)
end

function UI:Toggle()
    if self.root.Visible then
        self:Hide()
    else
        self:Show()
    end
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
        if child ~= self.hero and not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
    self.order = 0
    self.thinkingCards = {}
    if self.hero then
        self.hero.Visible = true
        self.hero.Size = UDim2.new(1, 0, 0, HERO_HEIGHT)
    end
end

function UI:ScrollToBottom()
    task.defer(function()
        task.wait()
        if self.destroyed then
            return
        end
        local ok, canvas = pcall(function()
            return self.scroll.AbsoluteCanvasSize
        end)
        if ok and canvas then
            tween(self.scroll, { CanvasPosition = Vector2.new(0, math.max(0, canvas.Y)) }, 0.18)
        end
    end)
end

function UI:NewRow()
    self.order += 1
    self:HideHero()
    return create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self.order,
    }, self.scroll)
end

function UI:AddMessage(role, text)
    local row = self:NewRow()
    local isUser = role == "user"

    if isUser then
        local holder = create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
        }, row)
        local bubble = create("Frame", {
            BackgroundColor3 = Theme.user,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(1, 0, 0, 0),
            AnchorPoint = Vector2.new(1, 0),
            AutomaticSize = Enum.AutomaticSize.XY,
        }, holder)
        withCorner(bubble, 16)
        withPadding(bubble, 10, 14, 10, 14)

        local label = create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.XY,
            Font = Theme.font,
            TextSize = 13,
            TextColor3 = Theme.text,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            LineHeight = 1.25,
            Text = text or "",
        }, bubble)
        -- Auto-size hugs the text but caps how wide a bubble can grow, so a one
        -- word message stays a small pill instead of stretching the whole row.
        local limit = Instance.new("UISizeConstraint")
        limit.MaxSize = Vector2.new(300, 4000)
        limit.Parent = label

        self:ScrollToBottom()
        return
    end

    -- Assistant replies are plain text, like a coding agent transcript: no
    -- bubble, no repeated name, just the answer with code blocks.
    local content = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, row)
    withList(content, 8)
    local copySource = text or ""

    for _, part in ipairs(splitFences(text or "")) do
        if part.code then
            local block = create("Frame", {
                BackgroundColor3 = Theme.code,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
            }, content)
            withCorner(block, 12)
            withStroke(block, Theme.lineSoft, 1, 0.4)
            withPadding(block, 9, 12, 10, 12)
            create("UIListLayout", {
                Padding = UDim.new(0, 5),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }, block)
            create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 10),
                Font = Theme.fontMedium,
                TextSize = 8,
                TextColor3 = Theme.faint,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = "CODE",
            }, block)
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
                LineHeight = 1.15,
                Text = (part.text ~= "" and part.text or " "),
            }, block)
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
                LineHeight = 1.3,
                Text = part.text,
            }, content)
        end
    end

    if Util.Trim(copySource) ~= "" then
        local copyHolder = create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 22),
        }, content)
        local copy = create("TextButton", {
            Size = UDim2.fromOffset(52, 22),
            Position = UDim2.new(1, 0, 0, 0),
            AnchorPoint = Vector2.new(1, 0),
            BackgroundColor3 = Theme.surface,
            BorderSizePixel = 0,
            Text = "Copy",
            Font = Theme.fontMedium,
            TextSize = 9,
            TextColor3 = Theme.muted,
            AutoButtonColor = false,
        }, copyHolder)
        withCorner(copy, 11)
        withStroke(copy, Theme.lineSoft, 1, 0.35)
        local clipboard = self.compat.Lookup("setclipboard") or self.compat.Lookup("writeclipboard")
        copy.MouseEnter:Connect(function()
            tween(copy, { BackgroundColor3 = Theme.surfaceHi }, 0.12)
        end)
        copy.MouseLeave:Connect(function()
            tween(copy, { BackgroundColor3 = Theme.surface }, 0.12)
        end)
        copy.MouseButton1Click:Connect(function()
            local ok = false
            if type(clipboard) == "function" then
                ok = pcall(clipboard, copySource)
            end
            copy.Text = ok and "Copied" or "No clipboard"
            copy.TextColor3 = ok and Theme.ok or Theme.err
            task.delay(1.5, function()
                if self.destroyed or not copy.Parent then
                    return
                end
                copy.Text = "Copy"
                copy.TextColor3 = Theme.muted
            end)
        end)
    end
    self:ScrollToBottom()
end

function UI:AddSystem(text)
    self.order += 1
    local row = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = self.order,
    }, self.scroll)
    create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -16, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Theme.font,
        TextSize = 9,
        TextColor3 = Theme.faint,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Center,
        Text = text,
    }, row)
    self:ScrollToBottom()
end

function UI:AddError(text)
    local row = self:NewRow()
    local frame = create("Frame", {
        BackgroundColor3 = Theme.errFill,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, row)
    withCorner(frame, 12)
    withStroke(frame, Theme.err, 1, 0.55)
    withPadding(frame, 10, 12, 10, 12)

    local dot = create("Frame", {
        Size = UDim2.fromOffset(6, 6),
        Position = UDim2.fromOffset(0, 5),
        BackgroundColor3 = Theme.err,
        BorderSizePixel = 0,
    }, frame)
    withCorner(dot, 3)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -14, 0, 0),
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

function UI:AddThinking(text)
    self:HideHero()
    self.order += 1
    local card = create("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 26),
        LayoutOrder = self.order,
        ClipsDescendants = true,
    }, self.scroll)

    -- Flat trace like beautifului.dev's thinking component: sparkle icon,
    -- shimmering "Thinking" label and an expandable prose body with a rule
    -- line. No bubble background, so it can't be mistaken for a message.
    local header = create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 26),
        Text = "",
        AutoButtonColor = false,
    }, card)

    local hover = create("Frame", {
        BackgroundColor3 = Theme.surfaceHi,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 1, 0),
    }, header)
    withCorner(hover, 6)

    local sparkle = create("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromOffset(2, 5),
        BackgroundTransparency = 1,
    }, header)
    ICONS.sparkle(sparkle, Theme.muted)

    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(24, 0),
        Size = UDim2.new(1, -66, 1, 0),
        Font = Theme.fontMedium,
        TextSize = 12,
        TextColor3 = Theme.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Thinking",
    }, header)

    local shimmer = tween(label, { TextTransparency = 0.55 }, 0.9,
        Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

    local chevron = create("Frame", {
        Size = UDim2.fromOffset(12, 12),
        Position = UDim2.new(1, -2, 0, 7),
        BackgroundTransparency = 1,
    }, header)
    bar(chevron, 6, 1.4, UDim2.new(0.5, -1.5, 0.5, -1.5), 45, Theme.faint)
    bar(chevron, 6, 1.4, UDim2.new(0.5, -1.5, 0.5, 1.5), -45, Theme.faint)

    local bodyHolder = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 28),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, card)
    local rule = create("Frame", {
        BackgroundColor3 = Theme.line,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(7, 0),
        Size = UDim2.new(0, 1, 0, 0),
    }, bodyHolder)
    local body = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, -16, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Theme.font,
        TextSize = 12,
        TextColor3 = Theme.muted,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        LineHeight = 1.35,
        Text = Util.Truncate(text or "", 1200),
    }, bodyHolder)

    local expanded = false
    local function setExpanded(value)
        expanded = value
        bodyHolder.Visible = value
        tween(chevron, { Rotation = value and 180 or 0 }, 0.22, Enum.EasingStyle.Quint)
        if value then
            task.defer(function()
                task.wait()
                if self.destroyed then
                    return
                end
                local bodyHeight = body.AbsoluteSize.Y
                rule.Size = UDim2.new(0, 1, 0, math.max(0, bodyHeight - 2))
                tween(card, {
                    Size = UDim2.new(1, 0, 0, 30 + bodyHeight),
                }, 0.2, Enum.EasingStyle.Quint)
                self:ScrollToBottom()
            end)
        else
            tween(card, { Size = UDim2.new(1, 0, 0, 26) }, 0.16, Enum.EasingStyle.Quint)
        end
    end
    header.MouseButton1Click:Connect(function()
        setExpanded(not expanded)
    end)
    header.MouseEnter:Connect(function()
        tween(hover, { BackgroundTransparency = 0.55 }, 0.12)
    end)
    header.MouseLeave:Connect(function()
        tween(hover, { BackgroundTransparency = 1 }, 0.12)
    end)

    table.insert(self.thinkingCards, {
        settle = function()
            if shimmer then
                pcall(function()
                    shimmer:Cancel()
                end)
            end
            label.Text = "Thought"
            label.TextTransparency = 0.3
            label.TextColor3 = Theme.faint
        end,
    })

    self:ScrollToBottom()
end

function UI:SettleThinking()
    for _, card in ipairs(self.thinkingCards or {}) do
        pcall(card.settle)
    end
    self.thinkingCards = {}
end

function UI:AddToolCard(name, argsText)
    self:HideHero()
    self.order += 1
    local card = create("Frame", {
        BackgroundColor3 = Theme.surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 32),
        LayoutOrder = self.order,
        ClipsDescendants = true,
    }, self.scroll)
    withCorner(card, 10)
    withStroke(card, Theme.lineSoft, 1, 0.35)

    local header = create("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 32),
        Text = "",
        AutoButtonColor = false,
    }, card)

    local dot = create("Frame", {
        Size = UDim2.fromOffset(6, 6),
        Position = UDim2.fromOffset(12, 13),
        BackgroundColor3 = Theme.warn,
        BorderSizePixel = 0,
    }, header)
    withCorner(dot, 3)

    local title = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(25, 0),
        Size = UDim2.new(1, -110, 1, 0),
        Font = Theme.fontCode,
        TextSize = 11,
        TextColor3 = Theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = name,
    }, header)

    local statusLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -78, 0, 0),
        Size = UDim2.fromOffset(58, 32),
        Font = Theme.font,
        TextSize = 9,
        TextColor3 = Theme.faint,
        TextXAlignment = Enum.TextXAlignment.Right,
        Text = "running",
    }, header)

    local chevron = create("Frame", {
        Size = UDim2.fromOffset(10, 10),
        Position = UDim2.new(1, -14, 0, 16),
        BackgroundTransparency = 1,
    }, header)
    bar(chevron, 6, 1.4, UDim2.new(0.5, -1.5, 0.5, -1.5), 45, Theme.faint)
    bar(chevron, 6, 1.4, UDim2.new(0.5, -1.5, 0.5, 1.5), -45, Theme.faint)

    local bodyHolder = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 36),
        Size = UDim2.new(1, -24, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
    }, card)
    local body = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Theme.fontCode,
        TextSize = 9,
        TextColor3 = Theme.faint,
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
                if self.destroyed then
                    return
                end
                tween(card, {
                    Size = UDim2.new(1, 0, 0, 44 + bodyHolder.AbsoluteSize.Y),
                }, 0.18, Enum.EasingStyle.Quint)
                self:ScrollToBottom()
            end)
        else
            tween(card, { Size = UDim2.new(1, 0, 0, 32) }, 0.16, Enum.EasingStyle.Quint)
        end
    end
    header.MouseButton1Click:Connect(function()
        setExpanded(not expanded)
    end)

    local cardApi = {}
    local ui = self
    function cardApi:Finish(ok, resultText, seconds)
        dot.BackgroundColor3 = ok and Theme.ok or Theme.err
        statusLabel.Text = (ok and "done " or "failed ") .. Util.FormatSeconds(seconds or 0)
        statusLabel.TextColor3 = ok and Theme.faint or Theme.err
        title.TextColor3 = ok and Theme.muted or Theme.text
        body.Text = "args\n"
            .. Util.Truncate(argsText or "{}", 800)
            .. "\n\nresult\n"
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
        self:Show()
    end

    local row = self:NewRow()
    local card = create("Frame", {
        BackgroundColor3 = Theme.surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, row)
    withCorner(card, 14)
    withStroke(card, Theme.warn, 1, 0.5)
    withPadding(card, 12, 14, 12, 14)
    withList(card, 8)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 12),
        Font = Theme.fontBold,
        TextSize = 8,
        TextColor3 = Theme.warn,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "PERMISSION REQUIRED",
    }, card)

    local title = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Theme.fontMedium,
        TextSize = 13,
        TextColor3 = Theme.text,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        LineHeight = 1.25,
        Text = tostring(spec.description or spec.title or "Run this code?"),
    }, card)

    local codeScroll = create("ScrollingFrame", {
        BackgroundColor3 = Theme.code,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 132),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.line,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, card)
    withCorner(codeScroll, 10)
    withPadding(codeScroll, 8, 10, 8, 10)
    create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Font = Theme.fontCode,
        TextSize = 10,
        TextColor3 = Theme.text,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        LineHeight = 1.1,
        Text = tostring(spec.code or ""),
    }, codeScroll)

    local buttons = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 34),
    }, card)
    withList(buttons, 6, true)

    local function decisionButton(text, color, textColor, width, order, callback)
        local button = create("TextButton", {
            Size = UDim2.new(width, -4, 1, 0),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Text = text,
            Font = Theme.fontBold,
            TextSize = 11,
            TextColor3 = textColor,
            AutoButtonColor = false,
            LayoutOrder = order,
        }, buttons)
        withCorner(button, 11)
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
        title.Text = allow and "Approved. Running the code now." or "Denied. Nothing was executed."
        title.TextColor3 = allow and Theme.ok or Theme.err
        for _, child in ipairs(buttons:GetChildren()) do
            if child:IsA("TextButton") then
                child.Active = false
                child.TextTransparency = 0.45
                child.BackgroundTransparency = 0.45
            end
        end
        self:SetStatus(allow and "Approved" or "Denied", allow and Theme.ok or Theme.err)
        self:ScrollToBottom()
    end

    decisionButton("Deny", Theme.surfaceHi, Theme.text, 0.24, 1, function()
        finish(false, false)
    end)
    decisionButton("Always allow", Theme.surfaceHi, Theme.text, 0.42, 2, function()
        finish(true, true)
    end)
    decisionButton("Run", Theme.accent, Theme.white, 0.32, 3, function()
        finish(true, false)
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

function UI:Destroy()
    if self.destroyed then
        return
    end
    self.destroyed = true
    for _, connection in ipairs(self.connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    self.connections = {}
    if self.gui then
        pcall(function()
            self.gui:Destroy()
        end)
        self.gui = nil
    end
    self.root = nil
end

return UI
