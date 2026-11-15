local GuiService = game:GetService("GuiService")
local Shared = require("./shared")
local Util = require("../util")

local SIGNALS = {
    "Activated",
    "MouseButton1Down",
    "MouseButton2Down",
    "MouseButton1Click",
    "MouseButton2Click",
}

local function getVirtualInputManager()
    local ok, service = pcall(function()
        return game:GetService("VirtualInputManager")
    end)
    if ok and service then
        return service
    end
    local createOk, created = pcall(function()
        return Instance.new("VirtualInputManager")
    end)
    if createOk then
        return created
    end
    return nil
end

local function resolveGui(path)
    local instance, errorMessage = Shared.ResolvePath(path or "")
    if not instance then
        return nil, errorMessage
    end
    return instance
end

return {
    {
        name = "click_button",
        description = "Fire click signals on a GuiButton using firesignal, or a virtual mouse click when firesignal is unavailable.",
        parameters = {
            type = "object",
            properties = {
                path = Shared.StringProperty("Full path of the GuiButton.", nil),
                action = Shared.StringProperty("Optional signal: Activated, MouseButton1Click, MouseButton2Click, or a down signal.", nil),
            },
            required = { "path" },
        },
        run = function(args, ctx)
            local button, pathError = resolveGui(args.path)
            if not button then
                return { ok = false, error = pathError }
            end
            local classOk, isButton = pcall(function()
                return button:IsA("GuiButton")
            end)
            if not classOk or not isButton then
                return { ok = false, error = "That instance is a " .. button.ClassName .. ", not a GuiButton." }
            end
            local action = args.action
            if action and not table.find(SIGNALS, action) then
                return { ok = false, error = "action must be one of: " .. table.concat(SIGNALS, ", ") }
            end

            local firesignal = ctx.compat.Lookup("firesignal")
            if type(firesignal) == "function" then
                if action then
                    local ok, errorMessage = pcall(firesignal, button[action])
                    if not ok then
                        return { ok = false, error = "firesignal failed: " .. tostring(errorMessage) }
                    end
                else
                    local fired = 0
                    for _, name in ipairs(SIGNALS) do
                        local ok = pcall(firesignal, button[name])
                        if ok then
                            fired += 1
                        end
                    end
                    if fired == 0 then
                        return { ok = false, error = "firesignal failed for every button signal." }
                    end
                end
                return {
                    ok = true,
                    data = { path = button:GetFullName(), method = "firesignal", action = action or "all signals" },
                }
            end

            local virtualInput = getVirtualInputManager()
            if not virtualInput then
                return {
                    ok = false,
                    error = "This executor has neither firesignal nor a usable VirtualInputManager.",
                }
            end
            if not button.Visible or button.AbsoluteSize.X <= 0 or button.AbsoluteSize.Y <= 0 then
                return { ok = false, error = "Virtual mouse clicking needs a visible button with a nonzero size." }
            end
            if action and action ~= "Activated" and action ~= "MouseButton1Click" and action ~= "MouseButton2Click" then
                return { ok = false, error = "Down-only signals require firesignal." }
            end

            local center = button.AbsolutePosition + button.AbsoluteSize / 2
            local inset = GuiService:GetGuiInset()
            local x, y = center.X + inset.X, center.Y + inset.Y
            local mouseButton = action == "MouseButton2Click" and 1 or 0
            virtualInput:SendMouseMoveEvent(x, y, game)
            task.wait()
            virtualInput:SendMouseButtonEvent(x, y, mouseButton, true, game, 0)
            task.wait(0.05)
            virtualInput:SendMouseButtonEvent(x, y, mouseButton, false, game, 0)
            return {
                ok = true,
                data = {
                    path = button:GetFullName(),
                    method = "virtual-input",
                    note = "The button must be visible and unobstructed.",
                },
            }
        end,
    },
    {
        name = "type_text",
        description = "Set text on a TextBox and optionally focus/leave it. useKeyPress simulates typing when the executor supports it.",
        parameters = {
            type = "object",
            properties = {
                path = Shared.StringProperty("Full path of the TextBox.", nil),
                text = Shared.StringProperty("Text to enter.", nil),
                enter = Shared.BoolProperty("Release focus as if Enter was pressed.", false),
                useKeyPress = Shared.BoolProperty("Simulate per-character input instead of setting Text.", false),
            },
            required = { "path", "text" },
        },
        run = function(args, ctx)
            local textBox, pathError = resolveGui(args.path)
            if not textBox then
                return { ok = false, error = pathError }
            end
            local classOk, isTextBox = pcall(function()
                return textBox:IsA("TextBox")
            end)
            if not classOk or not isTextBox then
                return { ok = false, error = "That instance is a " .. textBox.ClassName .. ", not a TextBox." }
            end
            local text = tostring(args.text or "")
            textBox:CaptureFocus()
            task.wait(0.05)

            if args.useKeyPress then
                local virtualInput = getVirtualInputManager()
                local keypress = ctx.compat.Lookup("keypress")
                if virtualInput then
                    for index = 1, #text do
                        virtualInput:SendTextInput(text:sub(index, index), nil, game)
                        task.wait(0.01)
                    end
                elseif type(keypress) == "function" then
                    local keyrelease = ctx.compat.Lookup("keyrelease")
                    for index = 1, #text do
                        local byte = text:sub(index, index):upper():byte()
                        if byte then
                            keypress(byte)
                            task.wait(0.01)
                            if type(keyrelease) == "function" then
                                keyrelease(byte)
                            end
                        end
                    end
                else
                    textBox:ReleaseFocus(false)
                    return {
                        ok = false,
                        error = "This executor cannot simulate key input; call again with useKeyPress=false.",
                    }
                end
            else
                textBox.Text = text
            end

            textBox:ReleaseFocus(args.enter == true)
            return {
                ok = true,
                data = { path = textBox:GetFullName(), length = #text, method = args.useKeyPress and "keypress" or "direct" },
            }
        end,
    },
}
