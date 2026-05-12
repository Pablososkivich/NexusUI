--!nocheck
-- ════════════════════════════════════════════════════════════════════════════
--  NexusUI v4.0.0
--  Professional UI library for Roblox (PC-focused, executor-friendly)
--  Author: Pablososkivich
--  License: MIT
--
--  Highlights vs v3:
--   * Runtime theme switching, custom themes, themed instance tracker
--   * No connection leaks (Draggable/Ripple/Shadow use signals + cleanup)
--   * Full element object API: :Set/:Get/:Destroy/:SetVisible/:SetDisabled
--     :OnChanged/:SetTooltip/:SetDescription/:SetName
--   * New elements: RangeSlider, Stepper, TextArea, ProgressBar, Tag, Radio,
--     Segmented, SearchableDropdown, collapsible Section, two-column rows
--   * Resizable window, snap-to-edges, search palette (Ctrl+F),
--     command palette (Ctrl+K), built-in Settings tab
--   * Notifications: actions, close button, queue with limit, sounds (opt-in)
--   * ColorPicker: hex/RGB inputs, alpha, recent colors, before/after preview
--   * Keybinds: modifier combos (Ctrl/Shift/Alt), mouse buttons, Hold/Toggle/OnRelease
--   * Config manager: auto-save, per-game (PlaceId), clipboard import/export,
--     UI for listing/loading/renaming/deleting profiles
--   * Acrylic blur backdrop (optional), 2-layer shadows, glow pulse,
--     animated accent gradient
--   * Update checker (HttpService GET → semver compare)
--   * Discord webhook helper
--   * Splash/loading screen with progress
-- ════════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════
-- SERVICES
-- ═══════════════════════════════
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local CoreGui           = game:GetService("CoreGui")
local GuiService        = game:GetService("GuiService")
local HttpService       = game:GetService("HttpService")
local TextService       = game:GetService("TextService")
local Lighting          = game:GetService("Lighting")
local SoundService      = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local GuiInset    = GuiService:GetGuiInset()

-- ═══════════════════════════════
-- VERSION
-- ═══════════════════════════════
local LIB_VERSION = "4.0.0"
local LIB_NAME    = "NexusUI"

-- ═══════════════════════════════
-- LIBRARY ROOT
-- ═══════════════════════════════
local NexusUI = {
    Version = LIB_VERSION,
    Name    = LIB_NAME,
    _windows = {},
    _activeWindow = nil,
}

-- ═══════════════════════════════
-- SIGNAL  (lightweight RBXScriptSignal-like)
-- ═══════════════════════════════
local Signal = {}
Signal.__index = Signal

function Signal.new()
    return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
    assert(type(fn) == "function", "Signal:Connect expects a function")
    local handler = { fn = fn, connected = true }
    table.insert(self._handlers, handler)
    local conn = {}
    function conn:Disconnect()
        handler.connected = false
        for i, h in ipairs(self._handlers) do
            if h == handler then table.remove(self._handlers, i); break end
        end
    end
    conn.Connected = true
    return conn
end

function Signal:Fire(...)
    for _, handler in ipairs(table.clone(self._handlers)) do
        if handler.connected then
            task.spawn(handler.fn, ...)
        end
    end
end

function Signal:Destroy()
    self._handlers = {}
end

-- ═══════════════════════════════
-- MAID  (connection / instance cleanup container)
-- ═══════════════════════════════
local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(item)
    table.insert(self._tasks, item)
    return item
end

function Maid:Clean()
    for _, item in ipairs(self._tasks) do
        if typeof(item) == "RBXScriptConnection" then
            pcall(function() item:Disconnect() end)
        elseif typeof(item) == "Instance" then
            pcall(function() item:Destroy() end)
        elseif type(item) == "function" then
            pcall(item)
        elseif type(item) == "table" and type(item.Destroy) == "function" then
            pcall(function() item:Destroy() end)
        elseif type(item) == "table" and type(item.Disconnect) == "function" then
            pcall(function() item:Disconnect() end)
        end
    end
    self._tasks = {}
end
Maid.Destroy = Maid.Clean

-- ═══════════════════════════════
-- ICONS  (Lucide-style unicode symbols + Roblox asset fallbacks)
-- ═══════════════════════════════
local Icons = {
    -- Text/unicode icons (work without assets)
    home     = "⌂",      house    = "⌂",
    user     = "👤",     person   = "👤",
    settings = "⚙",      gear     = "⚙",
    search   = "🔍",
    star     = "★",      heart    = "♥",
    check    = "✓",      cross    = "✕",     plus     = "+",   minus = "−",
    arrow_right = "→",   arrow_left = "←",   arrow_up = "↑",  arrow_down = "↓",
    chevron_down = "▾",  chevron_up = "▴",   chevron_right = "▸", chevron_left = "◂",
    info  = "ℹ",         warning = "⚠",      error_ = "✕",    success = "✓",
    bell  = "🔔",        clock  = "⏱",       fire = "🔥",     bolt = "⚡",
    eye   = "👁",        eye_off = "🚫",
    lock  = "🔒",        unlock = "🔓",
    folder = "📁",       file = "📄",        download = "⬇",  upload = "⬆",
    play  = "▶",         pause  = "⏸",       stop = "⏹",      reset = "⟳",
    pin   = "📌",        unpin = "📍",
    copy  = "⧉",         paste = "📋",       trash = "🗑",
    sun   = "☀",         moon = "☾",         palette = "🎨",
    keyboard = "⌨",      mouse = "🖱",       gamepad = "🎮",
    wifi  = "📶",        signal = "📡",
    bug   = "🐛",        wrench = "🔧",
    grid  = "▦",         list = "≡",         square = "□",    circle = "○",
    layer = "▤",         menu = "≡",
    add_user = "👥",     team = "👥",
    coffee = "☕",       gift = "🎁",
    -- Empty / blank fallback
    blank = "",
}

function NexusUI.GetIcon(name)
    return Icons[name] or name or ""
end

function NexusUI.RegisterIcon(name, glyph)
    Icons[name] = glyph
end

-- ═══════════════════════════════
-- THEMES  (default 7, plus :RegisterTheme())
-- ═══════════════════════════════
local Themes = {
    Dark = {
        Background    = Color3.fromRGB(18, 18, 22),
        Secondary     = Color3.fromRGB(24, 24, 30),
        Tertiary      = Color3.fromRGB(30, 30, 38),
        Card          = Color3.fromRGB(28, 28, 36),
        CardHover     = Color3.fromRGB(35, 35, 45),
        Accent        = Color3.fromRGB(88, 101, 242),
        AccentDark    = Color3.fromRGB(71, 82, 196),
        AccentLight   = Color3.fromRGB(114, 127, 255),
        AccentText    = Color3.fromRGB(255, 255, 255),
        Text          = Color3.fromRGB(240, 240, 245),
        SubText       = Color3.fromRGB(148, 148, 165),
        DimText       = Color3.fromRGB(95, 95, 115),
        Disabled      = Color3.fromRGB(60, 60, 75),
        Border        = Color3.fromRGB(42, 42, 55),
        BorderStrong  = Color3.fromRGB(60, 60, 80),
        Hover         = Color3.fromRGB(35, 35, 45),
        Pressed       = Color3.fromRGB(45, 45, 60),
        Success       = Color3.fromRGB(67, 181, 129),
        Error         = Color3.fromRGB(237, 66, 69),
        Warning       = Color3.fromRGB(250, 166, 26),
        Info          = Color3.fromRGB(88, 101, 242),
        ToggleOn      = Color3.fromRGB(67, 181, 129),
        ToggleOff     = Color3.fromRGB(65, 65, 80),
        SliderFill    = Color3.fromRGB(88, 101, 242),
        SliderBG      = Color3.fromRGB(40, 40, 52),
        Shadow        = Color3.fromRGB(0, 0, 0),
    },
    Light = {
        Background    = Color3.fromRGB(248, 248, 252),
        Secondary     = Color3.fromRGB(238, 238, 245),
        Tertiary      = Color3.fromRGB(228, 228, 238),
        Card          = Color3.fromRGB(255, 255, 255),
        CardHover     = Color3.fromRGB(244, 244, 250),
        Accent        = Color3.fromRGB(88, 101, 242),
        AccentDark    = Color3.fromRGB(71, 82, 196),
        AccentLight   = Color3.fromRGB(114, 127, 255),
        AccentText    = Color3.fromRGB(255, 255, 255),
        Text          = Color3.fromRGB(20, 20, 30),
        SubText       = Color3.fromRGB(80, 80, 100),
        DimText       = Color3.fromRGB(140, 140, 160),
        Disabled      = Color3.fromRGB(200, 200, 215),
        Border        = Color3.fromRGB(220, 220, 232),
        BorderStrong  = Color3.fromRGB(200, 200, 215),
        Hover         = Color3.fromRGB(240, 240, 248),
        Pressed       = Color3.fromRGB(228, 228, 240),
        Success       = Color3.fromRGB(40, 160, 100),
        Error         = Color3.fromRGB(220, 50, 55),
        Warning       = Color3.fromRGB(230, 140, 20),
        Info          = Color3.fromRGB(88, 101, 242),
        ToggleOn      = Color3.fromRGB(40, 160, 100),
        ToggleOff     = Color3.fromRGB(205, 205, 215),
        SliderFill    = Color3.fromRGB(88, 101, 242),
        SliderBG      = Color3.fromRGB(220, 220, 232),
        Shadow        = Color3.fromRGB(60, 60, 90),
    },
    Purple = {
        Background    = Color3.fromRGB(16, 12, 24),
        Secondary     = Color3.fromRGB(22, 16, 32),
        Tertiary      = Color3.fromRGB(28, 22, 40),
        Card          = Color3.fromRGB(26, 20, 38),
        CardHover     = Color3.fromRGB(35, 28, 48),
        Accent        = Color3.fromRGB(155, 89, 255),
        AccentDark    = Color3.fromRGB(128, 65, 217),
        AccentLight   = Color3.fromRGB(175, 120, 255),
        AccentText    = Color3.fromRGB(255, 255, 255),
        Text          = Color3.fromRGB(240, 235, 250),
        SubText       = Color3.fromRGB(155, 145, 175),
        DimText       = Color3.fromRGB(100, 90, 120),
        Disabled      = Color3.fromRGB(70, 60, 90),
        Border        = Color3.fromRGB(50, 38, 68),
        BorderStrong  = Color3.fromRGB(70, 55, 95),
        Hover         = Color3.fromRGB(35, 28, 48),
        Pressed       = Color3.fromRGB(45, 35, 60),
        Success       = Color3.fromRGB(67, 181, 129),
        Error         = Color3.fromRGB(237, 66, 69),
        Warning       = Color3.fromRGB(250, 166, 26),
        Info          = Color3.fromRGB(155, 89, 255),
        ToggleOn      = Color3.fromRGB(155, 89, 255),
        ToggleOff     = Color3.fromRGB(55, 45, 72),
        SliderFill    = Color3.fromRGB(155, 89, 255),
        SliderBG      = Color3.fromRGB(40, 32, 55),
        Shadow        = Color3.fromRGB(20, 0, 40),
    },
    Ocean = {
        Background    = Color3.fromRGB(12, 18, 24),
        Secondary     = Color3.fromRGB(16, 24, 32),
        Tertiary      = Color3.fromRGB(20, 30, 40),
        Card          = Color3.fromRGB(18, 28, 38),
        CardHover     = Color3.fromRGB(25, 38, 50),
        Accent        = Color3.fromRGB(0, 180, 216),
        AccentDark    = Color3.fromRGB(0, 150, 180),
        AccentLight   = Color3.fromRGB(50, 200, 235),
        AccentText    = Color3.fromRGB(255, 255, 255),
        Text          = Color3.fromRGB(230, 245, 250),
        SubText       = Color3.fromRGB(130, 165, 180),
        DimText       = Color3.fromRGB(80, 110, 125),
        Disabled      = Color3.fromRGB(50, 75, 90),
        Border        = Color3.fromRGB(30, 50, 65),
        BorderStrong  = Color3.fromRGB(50, 75, 95),
        Hover         = Color3.fromRGB(25, 38, 50),
        Pressed       = Color3.fromRGB(35, 50, 65),
        Success       = Color3.fromRGB(67, 181, 129),
        Error         = Color3.fromRGB(237, 66, 69),
        Warning       = Color3.fromRGB(250, 166, 26),
        Info          = Color3.fromRGB(0, 180, 216),
        ToggleOn      = Color3.fromRGB(0, 180, 216),
        ToggleOff     = Color3.fromRGB(35, 55, 68),
        SliderFill    = Color3.fromRGB(0, 180, 216),
        SliderBG      = Color3.fromRGB(25, 40, 52),
        Shadow        = Color3.fromRGB(0, 30, 50),
    },
    Blood = {
        Background    = Color3.fromRGB(20, 12, 14),
        Secondary     = Color3.fromRGB(28, 16, 18),
        Tertiary      = Color3.fromRGB(36, 22, 24),
        Card          = Color3.fromRGB(32, 18, 22),
        CardHover     = Color3.fromRGB(42, 25, 30),
        Accent        = Color3.fromRGB(220, 40, 60),
        AccentDark    = Color3.fromRGB(180, 30, 50),
        AccentLight   = Color3.fromRGB(245, 70, 90),
        AccentText    = Color3.fromRGB(255, 255, 255),
        Text          = Color3.fromRGB(250, 235, 238),
        SubText       = Color3.fromRGB(175, 140, 148),
        DimText       = Color3.fromRGB(120, 85, 95),
        Disabled      = Color3.fromRGB(85, 55, 60),
        Border        = Color3.fromRGB(60, 35, 40),
        BorderStrong  = Color3.fromRGB(85, 50, 60),
        Hover         = Color3.fromRGB(42, 25, 30),
        Pressed       = Color3.fromRGB(55, 30, 40),
        Success       = Color3.fromRGB(67, 181, 129),
        Error         = Color3.fromRGB(237, 66, 69),
        Warning       = Color3.fromRGB(250, 166, 26),
        Info          = Color3.fromRGB(220, 40, 60),
        ToggleOn      = Color3.fromRGB(220, 40, 60),
        ToggleOff     = Color3.fromRGB(60, 38, 42),
        SliderFill    = Color3.fromRGB(220, 40, 60),
        SliderBG      = Color3.fromRGB(45, 28, 32),
        Shadow        = Color3.fromRGB(40, 0, 10),
    },
    Midnight = {
        Background    = Color3.fromRGB(10, 10, 18),
        Secondary     = Color3.fromRGB(14, 14, 26),
        Tertiary      = Color3.fromRGB(20, 20, 35),
        Card          = Color3.fromRGB(16, 16, 30),
        CardHover     = Color3.fromRGB(22, 22, 40),
        Accent        = Color3.fromRGB(99, 140, 255),
        AccentDark    = Color3.fromRGB(75, 115, 220),
        AccentLight   = Color3.fromRGB(130, 165, 255),
        AccentText    = Color3.fromRGB(255, 255, 255),
        Text          = Color3.fromRGB(220, 225, 245),
        SubText       = Color3.fromRGB(120, 130, 165),
        DimText       = Color3.fromRGB(70, 75, 105),
        Disabled      = Color3.fromRGB(50, 55, 80),
        Border        = Color3.fromRGB(32, 32, 55),
        BorderStrong  = Color3.fromRGB(50, 55, 80),
        Hover         = Color3.fromRGB(22, 22, 40),
        Pressed       = Color3.fromRGB(30, 30, 50),
        Success       = Color3.fromRGB(67, 181, 129),
        Error         = Color3.fromRGB(237, 66, 69),
        Warning       = Color3.fromRGB(250, 166, 26),
        Info          = Color3.fromRGB(99, 140, 255),
        ToggleOn      = Color3.fromRGB(99, 140, 255),
        ToggleOff     = Color3.fromRGB(38, 38, 60),
        SliderFill    = Color3.fromRGB(99, 140, 255),
        SliderBG      = Color3.fromRGB(28, 28, 48),
        Shadow        = Color3.fromRGB(0, 0, 25),
    },
    Forest = {
        Background    = Color3.fromRGB(14, 22, 16),
        Secondary     = Color3.fromRGB(18, 28, 22),
        Tertiary      = Color3.fromRGB(24, 36, 28),
        Card          = Color3.fromRGB(22, 32, 26),
        CardHover     = Color3.fromRGB(30, 42, 34),
        Accent        = Color3.fromRGB(86, 200, 130),
        AccentDark    = Color3.fromRGB(60, 165, 100),
        AccentLight   = Color3.fromRGB(120, 225, 160),
        AccentText    = Color3.fromRGB(255, 255, 255),
        Text          = Color3.fromRGB(232, 245, 235),
        SubText       = Color3.fromRGB(140, 170, 150),
        DimText       = Color3.fromRGB(90, 115, 100),
        Disabled      = Color3.fromRGB(55, 75, 65),
        Border        = Color3.fromRGB(38, 55, 44),
        BorderStrong  = Color3.fromRGB(55, 80, 65),
        Hover         = Color3.fromRGB(30, 42, 34),
        Pressed       = Color3.fromRGB(38, 52, 42),
        Success       = Color3.fromRGB(86, 200, 130),
        Error         = Color3.fromRGB(237, 66, 69),
        Warning       = Color3.fromRGB(250, 166, 26),
        Info          = Color3.fromRGB(86, 200, 130),
        ToggleOn      = Color3.fromRGB(86, 200, 130),
        ToggleOff     = Color3.fromRGB(45, 60, 50),
        SliderFill    = Color3.fromRGB(86, 200, 130),
        SliderBG      = Color3.fromRGB(30, 44, 36),
        Shadow        = Color3.fromRGB(0, 25, 10),
    },
}

function NexusUI.GetTheme(name)
    return Themes[name]
end

function NexusUI.GetThemes()
    local list = {}
    for k in pairs(Themes) do table.insert(list, k) end
    table.sort(list)
    return list
end

function NexusUI.RegisterTheme(name, themeTable)
    assert(type(name) == "string", "RegisterTheme: name must be a string")
    assert(type(themeTable) == "table", "RegisterTheme: themeTable must be a table")
    -- Validate by copying from Dark for missing keys
    local merged = {}
    for k, v in pairs(Themes.Dark) do merged[k] = v end
    for k, v in pairs(themeTable) do merged[k] = v end
    Themes[name] = merged
end

-- ═══════════════════════════════
-- UTIL
-- ═══════════════════════════════
local Util = {}

local DEFAULT_TWEEN_INFO = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

function Util.Tween(object, properties, duration, easingStyle, easingDirection)
    if not object or not object.Parent then return end
    local info = TweenInfo.new(
        duration or 0.22,
        easingStyle or Enum.EasingStyle.Quart,
        easingDirection or Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(object, info, properties)
    tween:Play()
    return tween
end

function Util.Create(className, properties, children)
    local instance = Instance.new(className)
    if properties then
        local parent = properties.Parent
        properties.Parent = nil
        for key, value in pairs(properties) do
            instance[key] = value
        end
        if children then
            for _, child in ipairs(children) do child.Parent = instance end
        end
        if parent then instance.Parent = parent end
    end
    return instance
end

function Util.Corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

function Util.Stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.new(1, 1, 1)
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0.85
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

function Util.Padding(parent, top, bottom, left, right)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, top or 0)
    p.PaddingBottom = UDim.new(0, bottom or 0)
    p.PaddingLeft   = UDim.new(0, left or 0)
    p.PaddingRight  = UDim.new(0, right or 0)
    p.Parent = parent
    return p
end

function Util.ListLayout(parent, direction, padding, horizontalAlign, verticalAlign)
    local l = Instance.new("UIListLayout")
    l.FillDirection       = direction or Enum.FillDirection.Vertical
    l.Padding             = UDim.new(0, padding or 6)
    l.HorizontalAlignment = horizontalAlign or Enum.HorizontalAlignment.Left
    l.VerticalAlignment   = verticalAlign   or Enum.VerticalAlignment.Top
    l.SortOrder           = Enum.SortOrder.LayoutOrder
    l.Parent = parent
    return l
end

function Util.GridLayout(parent, cellSize, cellPadding)
    local g = Instance.new("UIGridLayout")
    g.CellSize    = cellSize    or UDim2.new(0, 100, 0, 30)
    g.CellPadding = cellPadding or UDim2.new(0, 6, 0, 6)
    g.SortOrder   = Enum.SortOrder.LayoutOrder
    g.Parent = parent
    return g
end

function Util.AspectRatio(parent, ratio)
    local r = Instance.new("UIAspectRatioConstraint")
    r.AspectRatio = ratio or 1
    r.Parent = parent
    return r
end

-- Hover binder with cleanup (returns a cleanup function)
function Util.BindHover(gui, onEnter, onLeave)
    local enterConn = gui.MouseEnter:Connect(onEnter or function() end)
    local leaveConn = gui.MouseLeave:Connect(onLeave or function() end)
    return function()
        enterConn:Disconnect()
        leaveConn:Disconnect()
    end
end

-- Color-fade hover helper (returns cleanup)
function Util.HoverFade(gui, normalColor, hoverColor, duration)
    duration = duration or 0.15
    local cleanup = Util.BindHover(
        gui,
        function() Util.Tween(gui, { BackgroundColor3 = hoverColor }, duration) end,
        function() Util.Tween(gui, { BackgroundColor3 = normalColor }, duration) end
    )
    return cleanup
end

-- Material-style ripple effect with cleanup
function Util.Ripple(button)
    button.ClipsDescendants = true
    local conn
    conn = button.InputBegan:Connect(function(input)
        if not (input.UserInputType == Enum.UserInputType.MouseButton1
             or input.UserInputType == Enum.UserInputType.Touch) then return end
        local ripple = Util.Create("Frame", {
            AnchorPoint           = Vector2.new(0.5, 0.5),
            Position              = UDim2.new(0, input.Position.X - button.AbsolutePosition.X,
                                              0, input.Position.Y - button.AbsolutePosition.Y),
            Size                  = UDim2.new(0, 0, 0, 0),
            BackgroundColor3      = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.82,
            BorderSizePixel       = 0,
            ZIndex                = (button.ZIndex or 1) + 1,
            Parent                = button,
        })
        Util.Corner(ripple, 999)
        local maxSize = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 2.5
        Util.Tween(ripple,
            { Size = UDim2.new(0, maxSize, 0, maxSize), BackgroundTransparency = 1 }, 0.55)
        task.delay(0.6, function()
            if ripple and ripple.Parent then ripple:Destroy() end
        end)
    end)
    return conn
end

-- Drag handler attached to `handle`, moves `frame`.  No leaks: returns a cleanup function.
function Util.MakeDraggable(frame, handle, onDragChanged)
    handle = handle or frame
    local dragging = false
    local dragStart, startPos
    local conns = {}

    local function release()
        dragging = false
        if onDragChanged then onDragChanged("end") end
    end

    table.insert(conns, handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
           and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging = true
        dragStart = input.Position
        startPos  = frame.Position
        if onDragChanged then onDragChanged("begin") end
    end))

    table.insert(conns, UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
           and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end))

    table.insert(conns, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then release() end
        end
    end))

    return function()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        conns = {}
    end
end

-- Two-layer shadow bound to a target frame.  Uses GetPropertyChangedSignal (no RenderStepped).
function Util.BindShadow(parent, target, shadowColor)
    shadowColor = shadowColor or Color3.new(0, 0, 0)

    local function makeLayer(offset, transparency, zOffset)
        return Util.Create("ImageLabel", {
            Name                  = "Shadow_" .. (target.Name or "x") .. "_" .. tostring(offset),
            AnchorPoint           = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image                 = "rbxassetid://6014261993",
            ImageColor3           = shadowColor,
            ImageTransparency     = transparency,
            ScaleType             = Enum.ScaleType.Slice,
            SliceCenter           = Rect.new(49, 49, 450, 450),
            ZIndex                = (target.ZIndex or 1) - 2 + zOffset,
            Parent                = parent,
        })
    end

    local ambient = makeLayer(20, 0.65, 0)
    local key     = makeLayer(40, 0.35, 1)

    local function update()
        if not target.Parent then return end
        local pos  = target.AbsolutePosition
        local size = target.AbsoluteSize
        local cx, cy = pos.X + size.X / 2, pos.Y + size.Y / 2 + GuiInset.Y
        ambient.Position = UDim2.new(0, cx, 0, cy + 6)
        ambient.Size     = UDim2.new(0, size.X + 30, 0, size.Y + 30)
        key.Position     = UDim2.new(0, cx, 0, cy + 14)
        key.Size         = UDim2.new(0, size.X + 60, 0, size.Y + 60)
        ambient.Visible  = target.Visible
        key.Visible      = target.Visible
    end

    local c1 = target:GetPropertyChangedSignal("AbsolutePosition"):Connect(update)
    local c2 = target:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
    local c3 = target:GetPropertyChangedSignal("Visible"):Connect(update)
    update()

    local function destroy()
        pcall(function() c1:Disconnect() end)
        pcall(function() c2:Disconnect() end)
        pcall(function() c3:Disconnect() end)
        if ambient.Parent then ambient:Destroy() end
        if key.Parent     then key:Destroy()     end
    end

    return {
        Layers  = { ambient = ambient, key = key },
        Update  = update,
        Destroy = destroy,
    }
end

-- Animated accent line: bright highlight that sweeps across (looped)
function Util.AnimatedAccent(parent, theme)
    local gradient = Util.Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,    theme.AccentDark),
            ColorSequenceKeypoint.new(0.5,  theme.AccentLight),
            ColorSequenceKeypoint.new(1,    theme.AccentDark),
        }),
        Rotation = 0,
        Parent   = parent,
    })
    local tween = TweenService:Create(
        gradient,
        TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true),
        { Offset = Vector2.new(1, 0) }
    )
    tween:Play()
    return gradient, tween
end

-- Find the safest parent for our ScreenGui
function Util.GetGuiParent()
    -- exploit-specific helpers first
    local hu
    pcall(function()
        if typeof(gethui) == "function" then hu = gethui() end
    end)
    if hu then return hu end
    pcall(function()
        if syn and syn.protect_gui then return end
    end)
    pcall(function()
        if get_hidden_gui then hu = get_hidden_gui() end
    end)
    if hu then return hu end
    if pcall(function() return CoreGui:GetChildren() end) then
        return CoreGui
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- Roblox-supplied font helper.  Returns one of Gotham variants given a "weight" hint.
function Util.Font(weight)
    if weight == "bold"     then return Enum.Font.GothamBold     end
    if weight == "semi"     then return Enum.Font.GothamSemibold end
    if weight == "medium"   then return Enum.Font.GothamMedium   end
    if weight == "regular"  then return Enum.Font.Gotham         end
    if weight == "black"    then return Enum.Font.GothamBlack    end
    return Enum.Font.Gotham
end

-- Format any value to safe display string
function Util.ToDisplay(v)
    if v == nil       then return "" end
    if type(v) == "string" then return v end
    return tostring(v)
end

-- Round number to N decimals
function Util.Round(value, decimals)
    decimals = decimals or 0
    local mult = 10 ^ decimals
    return math.floor(value * mult + 0.5) / mult
end

-- Clamp helper
function Util.Clamp(v, mn, mx) return math.max(mn, math.min(mx, v)) end

-- Lerp two Color3
function Util.LerpColor(c1, c2, t)
    return Color3.new(c1.R + (c2.R - c1.R) * t,
                      c1.G + (c2.G - c1.G) * t,
                      c1.B + (c2.B - c1.B) * t)
end

-- ═══════════════════════════════
-- THEME TRACKER
-- Maintains list of (instance, property, themeKey) so SetTheme can re-color.
-- ═══════════════════════════════
local function makeThemeTracker(getTheme)
    local entries = {}
    local listeners = {}

    local function register(instance, property, themeKey)
        if not instance or not property or not themeKey then return end
        table.insert(entries, { i = instance, p = property, k = themeKey })
        -- Initialize value
        local theme = getTheme()
        if theme[themeKey] then
            pcall(function() instance[property] = theme[themeKey] end)
        end
    end

    local function applyTheme(newTheme, animated)
        for _, e in ipairs(entries) do
            if e.i.Parent then
                local v = newTheme[e.k]
                if v then
                    if animated then
                        Util.Tween(e.i, { [e.p] = v }, 0.25)
                    else
                        pcall(function() e.i[e.p] = v end)
                    end
                end
            end
        end
        for _, fn in ipairs(listeners) do
            pcall(fn, newTheme)
        end
    end

    local function onThemeChanged(fn)
        table.insert(listeners, fn)
    end

    return {
        Register   = register,
        ApplyTheme = applyTheme,
        OnChanged  = onThemeChanged,
    }
end

-- ═══════════════════════════════
-- CREATE WINDOW
-- ═══════════════════════════════
function NexusUI:CreateWindow(config)
    config = config or {}
    local cfg = {
        Title       = config.Title       or "NexusUI",
        SubTitle    = config.SubTitle    or "v" .. LIB_VERSION,
        Theme       = config.Theme       or "Dark",
        Size        = config.Size        or UDim2.new(0, 620, 0, 460),
        MinSize     = config.MinSize     or Vector2.new(420, 320),
        MaxSize     = config.MaxSize     or Vector2.new(1100, 800),
        KeyBind     = config.KeyBind     or Enum.KeyCode.RightShift,
        Resizable   = (config.Resizable ~= false),
        Acrylic     = (config.Acrylic == true),
        AcrylicSize = config.AcrylicSize or 16,
        Sounds      = (config.Sounds == true),
        AutoSave    = config.AutoSave,    -- string: config name auto-saves on flag change
        AutoLoad    = config.AutoLoad,    -- string: config name auto-loads on open
        ConfigFolder = config.ConfigFolder or "NexusUI",
        DPIScale    = config.DPIScale or 1,
        BindKeybindsToInput = (config.BindKeybindsToInput ~= false), -- ignore keybinds while a TextBox is focused
        ShowSettingsTab = (config.ShowSettingsTab ~= false),
        Icon        = config.Icon,  -- override letter icon with rbxassetid://...
    }
    if type(cfg.Theme) == "table" then
        NexusUI.RegisterTheme("__user_" .. tostring(math.random(1, 1e6)), cfg.Theme)
        cfg.Theme = "__user_" .. tostring(math.random(1, 1e6))
    end
    local Theme = Themes[cfg.Theme] or Themes.Dark
    local themeName = cfg.Theme

    -- Cleanup previous instance with the same name
    pcall(function()
        local parent = Util.GetGuiParent()
        local existing = parent:FindFirstChild(LIB_NAME)
        if existing then existing:Destroy() end
    end)

    local trackerGetTheme = function() return Theme end
    local tracker = makeThemeTracker(trackerGetTheme)
    local mainMaid = Maid.new()

    -- ═══════════════════════════════
    -- WINDOW STATE
    -- ═══════════════════════════════
    local Window = {
        Tabs            = {},
        ActiveTab       = nil,
        Theme           = Theme,
        ThemeName       = themeName,
        Visible         = true,
        Minimized       = false,
        Alive           = true,
        Flags           = {},          -- [flagName] = { type, get, set, element }
        Elements        = {},          -- registered for global search palette
        Commands        = {},          -- name -> { description, callback }
        FloatingWindows = {},
        DefaultBindsList = nil,
        Config          = cfg,
        Signals = {
            ThemeChanged   = Signal.new(),
            FlagChanged    = Signal.new(),
            Closed         = Signal.new(),
            VisibleChanged = Signal.new(),
        },
        _connections    = {},
        _tracker        = tracker,
        _maid           = mainMaid,
    }
    table.insert(NexusUI._windows, Window)
    NexusUI._activeWindow = Window

    -- ═══════════════════════════════
    -- SCREENGUI
    -- ═══════════════════════════════
    local guiParent = Util.GetGuiParent()
    local ScreenGui = Util.Create("ScreenGui", {
        Name              = LIB_NAME,
        ZIndexBehavior    = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn      = false,
        IgnoreGuiInset    = true,
        DisplayOrder      = 100,
        Parent            = guiParent,
    })
    Window.ScreenGui = ScreenGui
    mainMaid:Give(ScreenGui)

    -- DPI scaling for entire UI
    local rootScale = Instance.new("UIScale")
    rootScale.Scale = cfg.DPIScale
    rootScale.Parent = ScreenGui
    Window.RootScale = rootScale

    function Window:SetDPIScale(scale)
        cfg.DPIScale = scale
        rootScale.Scale = scale
    end

    -- ═══════════════════════════════
    -- ACRYLIC BLUR
    -- ═══════════════════════════════
    local blurEffect
    local function ensureBlur()
        if not blurEffect then
            blurEffect = Instance.new("BlurEffect")
            blurEffect.Name = LIB_NAME .. "_Blur"
            blurEffect.Size = 0
            blurEffect.Parent = Lighting
            mainMaid:Give(blurEffect)
        end
        return blurEffect
    end
    function Window:SetAcrylic(enabled, size)
        cfg.Acrylic = enabled and true or false
        if cfg.Acrylic then
            ensureBlur()
            Util.Tween(blurEffect, { Size = size or cfg.AcrylicSize }, 0.3)
        elseif blurEffect then
            Util.Tween(blurEffect, { Size = 0 }, 0.25)
        end
    end
    if cfg.Acrylic then
        ensureBlur()
        blurEffect.Size = cfg.AcrylicSize
    end

    -- ═══════════════════════════════
    -- GLOBAL INPUT MANAGER (single listener for sliders/colorpickers/drag)
    -- ═══════════════════════════════
    local activeDragHandler = nil
    local keybindListening  = nil
    local registeredKeybinds = {}    -- key id -> list of { callback, mode, holdRelease, owner }
    local heldKeys = {}              -- currently held keys for "Hold" mode

    local function keyId(input)
        -- Build a unique id from KeyCode or UserInputType (mouse)
        if input.KeyCode ~= Enum.KeyCode.Unknown then return input.KeyCode end
        return input.UserInputType
    end

    local function keyDisplayName(id)
        if typeof(id) == "EnumItem" then
            if id.EnumType == Enum.KeyCode then return id.Name end
            if id.EnumType == Enum.UserInputType then
                local map = {
                    [Enum.UserInputType.MouseButton1] = "MB1",
                    [Enum.UserInputType.MouseButton2] = "MB2",
                    [Enum.UserInputType.MouseButton3] = "MB3",
                }
                return map[id] or id.Name
            end
        end
        return tostring(id)
    end

    local function modifiersMatch(required)
        if not required then return true end
        local m = {}
        m.Ctrl  = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
               or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
        m.Shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
               or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
        m.Alt   = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
               or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
        for _, mod in ipairs(required) do
            if not m[mod] then return false end
        end
        return true
    end

    local function registerKeybind(spec, callback)
        -- spec = { Key = KeyCode|UserInputType, Modifiers = {"Ctrl","Shift",...}, Mode = "Toggle"|"Hold"|"OnRelease" }
        local id = spec.Key
        registeredKeybinds[id] = registeredKeybinds[id] or {}
        local entry = {
            callback   = callback,
            mode       = spec.Mode or "Toggle",
            modifiers  = spec.Modifiers,
            held       = false,
        }
        table.insert(registeredKeybinds[id], entry)
        return function()
            if registeredKeybinds[id] then
                for i, e in ipairs(registeredKeybinds[id]) do
                    if e == entry then table.remove(registeredKeybinds[id], i); break end
                end
            end
        end
    end

    local function fireKeybindsForKey(id, beganOrEnded)
        local entries = registeredKeybinds[id]
        if not entries then return end
        for _, entry in ipairs(entries) do
            if modifiersMatch(entry.modifiers) then
                if beganOrEnded == "began" then
                    if entry.mode == "Hold" then
                        entry.held = true
                        entry.callback(true)
                    elseif entry.mode == "Toggle" then
                        entry.callback()
                    end
                elseif beganOrEnded == "ended" then
                    if entry.mode == "Hold" and entry.held then
                        entry.held = false
                        entry.callback(false)
                    elseif entry.mode == "OnRelease" then
                        entry.callback()
                    end
                end
            end
        end
    end

    -- Global move handler
    mainMaid:Give(UserInputService.InputChanged:Connect(function(input)
        if activeDragHandler and (input.UserInputType == Enum.UserInputType.MouseMovement
                              or input.UserInputType == Enum.UserInputType.Touch) then
            activeDragHandler.onMove(input.Position)
        end
    end))

    -- Global release handler
    mainMaid:Give(UserInputService.InputEnded:Connect(function(input)
        if activeDragHandler and (input.UserInputType == Enum.UserInputType.MouseButton1
                              or input.UserInputType == Enum.UserInputType.Touch) then
            if activeDragHandler.onRelease then activeDragHandler.onRelease() end
            activeDragHandler = nil
        end
        local id = keyId(input)
        if id then fireKeybindsForKey(id, "ended") end
    end))

    -- ═══════════════════════════════
    -- MAIN FRAME (with tracker registration for theme switch)
    -- ═══════════════════════════════
    local MainFrame = Util.Create("Frame", {
        Name             = "MainFrame",
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(0.5, 0, 0.5, 0),
        Size             = cfg.Size,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        ZIndex           = 10,
        Parent           = ScreenGui,
    })
    Util.Corner(MainFrame, 12)
    local mainStroke = Util.Stroke(MainFrame, Theme.Border, 1.5, 0.35)
    tracker.Register(MainFrame, "BackgroundColor3", "Background")
    tracker.Register(mainStroke, "Color", "Border")
    Window.MainFrame = MainFrame

    -- Two-layer shadow
    local shadow = Util.BindShadow(ScreenGui, MainFrame, Theme.Shadow)
    Window.Shadow = shadow
    mainMaid:Give({ Destroy = shadow.Destroy })
    tracker.OnChanged(function(t)
        shadow.Layers.ambient.ImageColor3 = t.Shadow
        shadow.Layers.key.ImageColor3     = t.Shadow
    end)

    -- Animated accent line
    local accentLine = Util.Create("Frame", {
        Size             = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel  = 0,
        ZIndex           = 11,
        Parent           = MainFrame,
    })
    Util.AnimatedAccent(accentLine, Theme)
    tracker.Register(accentLine, "BackgroundColor3", "Accent")
    tracker.OnChanged(function(t)
        for _, g in ipairs(accentLine:GetChildren()) do
            if g:IsA("UIGradient") then
                g.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0,   t.AccentDark),
                    ColorSequenceKeypoint.new(0.5, t.AccentLight),
                    ColorSequenceKeypoint.new(1,   t.AccentDark),
                })
            end
        end
    end)

    -- ═══════════════════════════════
    -- TOP BAR
    -- ═══════════════════════════════
    local TopBar = Util.Create("Frame", {
        Name             = "TopBar",
        Size             = UDim2.new(1, 0, 0, 50),
        Position         = UDim2.new(0, 0, 0, 2),
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel  = 0,
        ZIndex           = 12,
        Parent           = MainFrame,
    })
    tracker.Register(TopBar, "BackgroundColor3", "Secondary")
    local topBarLine = Util.Create("Frame", {
        Size             = UDim2.new(1, 0, 0, 1),
        Position         = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel  = 0,
        ZIndex           = 12,
        Parent           = TopBar,
    })
    tracker.Register(topBarLine, "BackgroundColor3", "Border")

    -- Title icon box
    local titleIconFrame = Util.Create("Frame", {
        Size             = UDim2.new(0, 32, 0, 32),
        Position         = UDim2.new(0, 16, 0.5, 0),
        AnchorPoint      = Vector2.new(0, 0.5),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel  = 0,
        ZIndex           = 13,
        Parent           = TopBar,
    })
    Util.Corner(titleIconFrame, 8)
    Util.Create("UIGradient", {
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(220, 220, 240)),
        Rotation = 45, Parent = titleIconFrame,
    })
    tracker.Register(titleIconFrame, "BackgroundColor3", "Accent")

    if cfg.Icon and string.sub(cfg.Icon, 1, 4) == "rbxa" then
        Util.Create("ImageLabel", {
            Size                  = UDim2.new(0.7, 0, 0.7, 0),
            Position              = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint           = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image                 = cfg.Icon,
            ImageColor3           = Color3.new(1, 1, 1),
            ZIndex                = 14,
            Parent                = titleIconFrame,
        })
    else
        Util.Create("TextLabel", {
            Size                  = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text                  = string.sub(cfg.Title, 1, 1),
            TextColor3            = Color3.new(1, 1, 1),
            TextSize              = 16,
            Font                  = Util.Font("bold"),
            ZIndex                = 14,
            Parent                = titleIconFrame,
        })
    end

    -- Title text
    local titleLabel = Util.Create("TextLabel", {
        Size                  = UDim2.new(0, 250, 0, 20),
        Position              = UDim2.new(0, 58, 0, 9),
        BackgroundTransparency = 1,
        Text                  = cfg.Title,
        TextColor3            = Theme.Text,
        TextSize              = 16,
        Font                  = Util.Font("bold"),
        TextXAlignment        = Enum.TextXAlignment.Left,
        TextTruncate          = Enum.TextTruncate.AtEnd,
        ZIndex                = 13,
        Parent                = TopBar,
    })
    tracker.Register(titleLabel, "TextColor3", "Text")
    local subTitleLabel = Util.Create("TextLabel", {
        Size                  = UDim2.new(0, 250, 0, 14),
        Position              = UDim2.new(0, 58, 0, 30),
        BackgroundTransparency = 1,
        Text                  = cfg.SubTitle,
        TextColor3            = Theme.DimText,
        TextSize              = 11,
        Font                  = Util.Font("regular"),
        TextXAlignment        = Enum.TextXAlignment.Left,
        TextTruncate          = Enum.TextTruncate.AtEnd,
        ZIndex                = 13,
        Parent                = TopBar,
    })
    tracker.Register(subTitleLabel, "TextColor3", "DimText")

    function Window:SetTitle(text)    titleLabel.Text = text  end
    function Window:SetSubTitle(text) subTitleLabel.Text = text end

    -- Top buttons holder (search / settings / minimize / close)
    local topButtonHolder = Util.Create("Frame", {
        Size             = UDim2.new(0, 0, 0, 30),
        AutomaticSize    = Enum.AutomaticSize.X,
        Position         = UDim2.new(1, -10, 0.5, 0),
        AnchorPoint      = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        ZIndex           = 13,
        Parent           = TopBar,
    })
    local btnHolderLayout = Util.ListLayout(topButtonHolder,
        Enum.FillDirection.Horizontal, 8,
        Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

    local function createTopBarButton(text, tooltip)
        local btn = Util.Create("TextButton", {
            Size                 = UDim2.new(0, 30, 0, 30),
            BackgroundColor3     = Theme.Tertiary,
            BorderSizePixel      = 0,
            Text                 = "",
            AutoButtonColor      = false,
            ZIndex               = 14,
            Parent               = topButtonHolder,
        })
        Util.Corner(btn, 8)
        tracker.Register(btn, "BackgroundColor3", "Tertiary")
        local lbl = Util.Create("TextLabel", {
            Size                 = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text                 = text,
            TextColor3           = Theme.SubText,
            TextSize             = 13,
            Font                 = Util.Font("bold"),
            ZIndex               = 15,
            Parent               = btn,
        })
        tracker.Register(lbl, "TextColor3", "SubText")
        btn.MouseEnter:Connect(function()
            Util.Tween(btn, { BackgroundColor3 = Theme.Hover }, 0.15)
            Util.Tween(lbl, { TextColor3       = Theme.Text  }, 0.15)
        end)
        btn.MouseLeave:Connect(function()
            Util.Tween(btn, { BackgroundColor3 = Theme.Tertiary }, 0.15)
            Util.Tween(lbl, { TextColor3       = Theme.SubText  }, 0.15)
        end)
        return btn, lbl
    end

    local searchBtn    = createTopBarButton(Icons.search,   "Search elements (Ctrl+F)")
    local cmdBtn       = createTopBarButton("⌘",            "Command palette (Ctrl+K)")
    local settingsBtn  = createTopBarButton(Icons.settings, "Settings")
    local minimizeBtn, minimizeLbl  = createTopBarButton("─", "Minimize")
    local closeBtn                  = createTopBarButton(Icons.cross, "Close")

    -- ═══════════════════════════════
    -- SIDEBAR
    -- ═══════════════════════════════
    local Sidebar = Util.Create("Frame", {
        Name             = "Sidebar",
        Size             = UDim2.new(0, 58, 1, -52),
        Position         = UDim2.new(0, 0, 0, 52),
        BackgroundColor3 = Theme.Secondary,
        BorderSizePixel  = 0,
        ZIndex           = 11,
        Parent           = MainFrame,
    })
    tracker.Register(Sidebar, "BackgroundColor3", "Secondary")
    local sidebarBorder = Util.Create("Frame", {
        Size             = UDim2.new(0, 1, 1, 0),
        Position         = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel  = 0,
        Parent           = Sidebar,
    })
    tracker.Register(sidebarBorder, "BackgroundColor3", "Border")

    local TabButtonScroll = Util.Create("ScrollingFrame", {
        Size                       = UDim2.new(1, 0, 1, -10),
        Position                   = UDim2.new(0, 0, 0, 5),
        BackgroundTransparency     = 1,
        ScrollBarThickness         = 0,
        CanvasSize                 = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize        = Enum.AutomaticSize.Y,
        ScrollingDirection         = Enum.ScrollingDirection.Y,
        ZIndex                     = 12,
        Parent                     = Sidebar,
    })
    Util.ListLayout(TabButtonScroll, Enum.FillDirection.Vertical, 6,
        Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
    Util.Padding(TabButtonScroll, 8, 8, 0, 0)

    -- ═══════════════════════════════
    -- CONTENT AREA
    -- ═══════════════════════════════
    local ContentArea = Util.Create("Frame", {
        Name             = "Content",
        Size             = UDim2.new(1, -59, 1, -52),
        Position         = UDim2.new(0, 59, 0, 52),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        ZIndex           = 11,
        Parent           = MainFrame,
    })
    tracker.Register(ContentArea, "BackgroundColor3", "Background")
    Window.ContentArea = ContentArea

    -- ═══════════════════════════════
    -- RESIZE HANDLE (bottom-right corner)
    -- ═══════════════════════════════
    if cfg.Resizable then
        local resizeHandle = Util.Create("ImageButton", {
            Name               = "ResizeHandle",
            Size               = UDim2.new(0, 14, 0, 14),
            Position           = UDim2.new(1, -4, 1, -4),
            AnchorPoint        = Vector2.new(1, 1),
            BackgroundTransparency = 1,
            Image              = "rbxasset://textures/ui/MapFrameMagnifier.png",
            ImageColor3        = Theme.SubText,
            ImageTransparency  = 0.5,
            AutoButtonColor    = false,
            ZIndex             = 30,
            Parent             = MainFrame,
        })
        -- 4 stripes graphic emulated with 4 frames (corner indicator)
        for i = 1, 3 do
            local stripe = Util.Create("Frame", {
                Size             = UDim2.new(0, 2, 0, 2 + (i - 1) * 3),
                Position         = UDim2.new(1, -3 - (i - 1) * 3, 1, -3),
                AnchorPoint      = Vector2.new(1, 1),
                BackgroundColor3 = Theme.SubText,
                BackgroundTransparency = 0.5,
                BorderSizePixel  = 0,
                ZIndex           = 31,
                Parent           = MainFrame,
            })
            tracker.Register(stripe, "BackgroundColor3", "SubText")
        end
        resizeHandle.Image = ""  -- hide default image, use stripes
        tracker.Register(resizeHandle, "ImageColor3", "SubText")

        local resizing = false
        local rsStart, rsBase
        resizeHandle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                resizing = true
                rsStart = input.Position
                rsBase  = MainFrame.AbsoluteSize
            end
        end)
        mainMaid:Give(UserInputService.InputChanged:Connect(function(input)
            if not resizing then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local delta = input.Position - rsStart
            local newX = Util.Clamp(rsBase.X + delta.X, cfg.MinSize.X, cfg.MaxSize.X)
            local newY = Util.Clamp(rsBase.Y + delta.Y, cfg.MinSize.Y, cfg.MaxSize.Y)
            MainFrame.Size = UDim2.new(0, newX, 0, newY)
            cfg.Size = MainFrame.Size
        end))
        mainMaid:Give(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                resizing = false
            end
        end))
    end

    -- ═══════════════════════════════
    -- WINDOW SNAP TO EDGES (drag near edge)
    -- ═══════════════════════════════
    local cleanupDrag = Util.MakeDraggable(MainFrame, TopBar, function(state)
        if state == "end" then
            local pos = MainFrame.AbsolutePosition
            local size = MainFrame.AbsoluteSize
            local screen = ScreenGui.AbsoluteSize
            local margin = 12
            local newX, newY = nil, nil
            if pos.X < margin then newX = 0 end
            if pos.X + size.X > screen.X - margin then newX = screen.X - size.X end
            if pos.Y < margin then newY = 0 end
            if pos.Y + size.Y > screen.Y - margin then newY = screen.Y - size.Y end
            if newX or newY then
                Util.Tween(MainFrame,
                    { Position = UDim2.new(0, newX or pos.X, 0, newY or pos.Y) },
                    0.2)
            end
        end
    end)
    mainMaid:Give(cleanupDrag)

    -- ═══════════════════════════════
    -- TOOLTIP (global)
    -- ═══════════════════════════════
    local TooltipLabel = Util.Create("TextLabel", {
        Size                  = UDim2.new(0, 0, 0, 26),
        AutomaticSize         = Enum.AutomaticSize.X,
        BackgroundColor3      = Theme.Tertiary,
        BackgroundTransparency = 1,
        Text                  = "",
        TextColor3            = Theme.Text,
        TextSize              = 11,
        Font                  = Util.Font("semi"),
        TextTransparency      = 1,
        Visible               = false,
        ZIndex                = 999,
        Parent                = ScreenGui,
    })
    Util.Corner(TooltipLabel, 6)
    Util.Stroke(TooltipLabel, Theme.Border, 1, 0.5)
    Util.Padding(TooltipLabel, 4, 4, 10, 10)
    tracker.Register(TooltipLabel, "BackgroundColor3", "Tertiary")
    tracker.Register(TooltipLabel, "TextColor3", "Text")

    local function showTooltip(text, position)
        TooltipLabel.Text = text
        TooltipLabel.Position = UDim2.new(0, position.X + 12, 0, position.Y + 24 + GuiInset.Y)
        TooltipLabel.Visible = true
        Util.Tween(TooltipLabel, { TextTransparency = 0, BackgroundTransparency = 0 }, 0.15)
    end

    local function hideTooltip()
        Util.Tween(TooltipLabel, { TextTransparency = 1, BackgroundTransparency = 1 }, 0.15)
        task.delay(0.15, function()
            if TooltipLabel.TextTransparency >= 1 then TooltipLabel.Visible = false end
        end)
    end

    function Window:BindTooltip(gui, text)
        local enterConn = gui.MouseEnter:Connect(function()
            local mouse = LocalPlayer:GetMouse()
            showTooltip(text, Vector2.new(mouse.X, mouse.Y))
        end)
        local leaveConn = gui.MouseLeave:Connect(hideTooltip)
        local cleanup = function()
            enterConn:Disconnect()
            leaveConn:Disconnect()
        end
        return cleanup
    end

    Window:BindTooltip(searchBtn,   "Search (Ctrl+F)")
    Window:BindTooltip(cmdBtn,      "Commands (Ctrl+K)")
    Window:BindTooltip(settingsBtn, "Settings")
    Window:BindTooltip(minimizeBtn, "Minimize")
    Window:BindTooltip(closeBtn,    "Close")

    -- ═══════════════════════════════
    -- NOTIFICATION CONTAINER
    -- ═══════════════════════════════
    local NotificationHolder = Util.Create("Frame", {
        Name                  = "Notifications",
        AnchorPoint           = Vector2.new(1, 0),
        Position              = UDim2.new(1, -20, 0, 40),
        Size                  = UDim2.new(0, 320, 1, -60),
        BackgroundTransparency = 1,
        ZIndex                = 200,
        Parent                = ScreenGui,
    })
    Util.ListLayout(NotificationHolder,
        Enum.FillDirection.Vertical, 8,
        Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top)
    Util.Padding(NotificationHolder, 10, 10, 0, 0)

    local NOTIFY_MAX = 6
    local notifyQueue = {}      -- active notification wrappers in order
    local notifyPending = {}    -- waiting to display

    -- ═══════════════════════════════
    -- MINIMIZE / CLOSE / TOGGLE
    -- ═══════════════════════════════
    local function setMinimized(state)
        Window.Minimized = state
        if state then
            Util.Tween(MainFrame,
                { Size = UDim2.new(0, MainFrame.AbsoluteSize.X, 0, 52) },
                0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            minimizeLbl.Text = "□"
        else
            Util.Tween(MainFrame, { Size = cfg.Size }, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            minimizeLbl.Text = "─"
        end
    end
    minimizeBtn.MouseButton1Click:Connect(function() setMinimized(not Window.Minimized) end)

    function Window:Minimize()  setMinimized(true)  end
    function Window:Restore()   setMinimized(false) end

    local function setVisibleAnim(visible)
        Window.Visible = visible
        if visible then
            MainFrame.Visible = true
            if shadow then
                Util.Tween(shadow.Layers.ambient, { ImageTransparency = 0.65 }, 0.3)
                Util.Tween(shadow.Layers.key,     { ImageTransparency = 0.35 }, 0.3)
            end
            local targetSize = Window.Minimized and UDim2.new(0, cfg.Size.X.Offset, 0, 52) or cfg.Size
            MainFrame.Size = UDim2.new(0, targetSize.X.Offset, 0, 0)
            Util.Tween(MainFrame, { Size = targetSize },
                0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            for _, fw in pairs(Window.FloatingWindows) do
                if not fw.Independent and fw._wasVisible then fw:Show() end
            end
        else
            for _, fw in pairs(Window.FloatingWindows) do
                if not fw.Independent then
                    fw._wasVisible = fw.Visible
                    if fw.Visible then fw:Hide() end
                end
            end
            Util.Tween(MainFrame,
                { Size = UDim2.new(0, MainFrame.AbsoluteSize.X, 0, 0) },
                0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
            if shadow then
                Util.Tween(shadow.Layers.ambient, { ImageTransparency = 1 }, 0.25)
                Util.Tween(shadow.Layers.key,     { ImageTransparency = 1 }, 0.25)
            end
            task.delay(0.35, function()
                if not Window.Visible then MainFrame.Visible = false end
            end)
        end
        Window.Signals.VisibleChanged:Fire(visible)
    end
    function Window:Toggle()
        setVisibleAnim(not Window.Visible)
    end
    function Window:Show() setVisibleAnim(true) end
    function Window:Hide() setVisibleAnim(false) end

    closeBtn.MouseButton1Click:Connect(function()
        Window:Destroy()
    end)

    function Window:Destroy()
        if not Window.Alive then return end
        Window.Alive = false
        Util.Tween(MainFrame, { Size = UDim2.new(0, 0, 0, 0) },
            0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        if shadow then
            Util.Tween(shadow.Layers.ambient, { ImageTransparency = 1 }, 0.35)
            Util.Tween(shadow.Layers.key,     { ImageTransparency = 1 }, 0.35)
        end
        for _, fw in pairs(Window.FloatingWindows) do
            if fw.Frame and fw.Frame.Parent then
                Util.Tween(fw.Frame, { Size = UDim2.new(0, 0, 0, 0) },
                    0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
            end
        end
        if blurEffect then
            Util.Tween(blurEffect, { Size = 0 }, 0.3)
        end
        task.wait(0.45)
        mainMaid:Clean()
        Window.Signals.Closed:Fire()
        for i, w in ipairs(NexusUI._windows) do
            if w == Window then table.remove(NexusUI._windows, i); break end
        end
        if NexusUI._activeWindow == Window then NexusUI._activeWindow = NexusUI._windows[1] end
    end

    -- ═══════════════════════════════
    -- GLOBAL KEY HANDLER (toggle, keybind listen, registered keybinds)
    -- ═══════════════════════════════
    mainMaid:Give(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not Window.Alive then return end
        if cfg.BindKeybindsToInput and gameProcessed then return end

        -- Keybind assignment listening
        if keybindListening then
            -- Capture mouse buttons + keyboard keys (skip modifier-only)
            local isMouse = (input.UserInputType == Enum.UserInputType.MouseButton1
                          or input.UserInputType == Enum.UserInputType.MouseButton2
                          or input.UserInputType == Enum.UserInputType.MouseButton3)
            local isKey   = (input.UserInputType == Enum.UserInputType.Keyboard
                          and input.KeyCode ~= Enum.KeyCode.Unknown
                          and input.KeyCode ~= Enum.KeyCode.LeftControl
                          and input.KeyCode ~= Enum.KeyCode.RightControl
                          and input.KeyCode ~= Enum.KeyCode.LeftShift
                          and input.KeyCode ~= Enum.KeyCode.RightShift
                          and input.KeyCode ~= Enum.KeyCode.LeftAlt
                          and input.KeyCode ~= Enum.KeyCode.RightAlt)
            if isMouse or isKey then
                local id = isMouse and input.UserInputType or input.KeyCode
                local mods = {}
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then table.insert(mods, "Ctrl") end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
                or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then table.insert(mods, "Shift") end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
                or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt) then table.insert(mods, "Alt") end
                keybindListening.resolve({ Key = id, Modifiers = mods })
                keybindListening = nil
            end
            return
        end

        -- Toggle main GUI
        if input.KeyCode == cfg.KeyBind then
            Window:Toggle()
            return
        end

        -- Open search palette (Ctrl+F)
        if input.KeyCode == Enum.KeyCode.F
           and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
             or UserInputService:IsKeyDown(Enum.KeyCode.RightControl))
           and Window.Visible then
            if Window._OpenSearch then Window:_OpenSearch() end
            return
        end

        -- Open command palette (Ctrl+K)
        if input.KeyCode == Enum.KeyCode.K
           and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
             or UserInputService:IsKeyDown(Enum.KeyCode.RightControl))
           and Window.Visible then
            if Window._OpenCommand then Window:_OpenCommand() end
            return
        end

        -- Registered keybinds
        local id = keyId(input)
        fireKeybindsForKey(id, "began")
    end))

    -- ═══════════════════════════════
    -- SOUND  (optional, opt-in via cfg.Sounds = true)
    -- ═══════════════════════════════
    local SOUND_IDS = {
        click  = "rbxassetid://6895079853",
        toggle = "rbxassetid://6895079853",
        notify = "rbxassetid://6518811702",
        open   = "rbxassetid://9119706284",
        close  = "rbxassetid://9119706284",
    }
    local function playSound(kind)
        if not cfg.Sounds then return end
        local id = SOUND_IDS[kind] or SOUND_IDS.click
        local s = Instance.new("Sound")
        s.SoundId = id
        s.Volume  = 0.4
        s.Parent  = SoundService
        s:Play()
        task.delay(2, function() if s and s.Parent then s:Destroy() end end)
    end
    Window._PlaySound = playSound

    -- ═══════════════════════════════
    -- SEARCH PALETTE (Ctrl+F)
    -- ═══════════════════════════════
    do
        local palette = Util.Create("Frame", {
            Name              = "SearchPalette",
            Size              = UDim2.new(0, 480, 0, 360),
            AnchorPoint       = Vector2.new(0.5, 0.5),
            Position          = UDim2.new(0.5, 0, 0.5, 0),
            BackgroundColor3  = Theme.Secondary,
            BorderSizePixel   = 0,
            Visible           = false,
            ZIndex            = 500,
            Parent            = ScreenGui,
        })
        Util.Corner(palette, 12)
        Util.Stroke(palette, Theme.BorderStrong, 1.5, 0.3)
        tracker.Register(palette, "BackgroundColor3", "Secondary")
        local pBlur = Util.Create("TextButton", {
            Name = "PaletteBlur", Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 1, AutoButtonColor = false, Text = "",
            ZIndex = 499, Visible = false, Parent = ScreenGui,
        })

        local input = Util.Create("TextBox", {
            Size = UDim2.new(1, -24, 0, 36),
            Position = UDim2.new(0, 12, 0, 10),
            BackgroundColor3 = Theme.Tertiary,
            BorderSizePixel  = 0,
            PlaceholderText  = "Search elements, tabs and flags…",
            PlaceholderColor3 = Theme.DimText,
            Text = "",
            TextColor3       = Theme.Text,
            TextSize         = 14,
            Font             = Util.Font("regular"),
            TextXAlignment   = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            ZIndex           = 501,
            Parent           = palette,
        })
        Util.Corner(input, 6)
        Util.Padding(input, 0, 0, 10, 10)
        tracker.Register(input, "BackgroundColor3", "Tertiary")
        tracker.Register(input, "TextColor3", "Text")

        local resultList = Util.Create("ScrollingFrame", {
            Size = UDim2.new(1, -16, 1, -58),
            Position = UDim2.new(0, 8, 0, 50),
            BackgroundTransparency = 1,
            CanvasSize             = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize    = Enum.AutomaticSize.Y,
            ScrollBarThickness     = 3,
            ScrollBarImageColor3   = Theme.Accent,
            ZIndex                 = 501,
            Parent                 = palette,
        })
        Util.ListLayout(resultList, Enum.FillDirection.Vertical, 4,
            Enum.HorizontalAlignment.Left)
        Util.Padding(resultList, 4, 4, 6, 6)

        local function clearResults()
            for _, c in ipairs(resultList:GetChildren()) do
                if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
                    c:Destroy()
                end
            end
        end

        local function makeResult(entry)
            local row = Util.Create("TextButton", {
                Size = UDim2.new(1, 0, 0, 36),
                BackgroundColor3 = Theme.Card,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 502,
                Parent = resultList,
            })
            Util.Corner(row, 6)
            tracker.Register(row, "BackgroundColor3", "Card")
            local title = Util.Create("TextLabel", {
                Size = UDim2.new(1, -24, 0, 16),
                Position = UDim2.new(0, 12, 0, 4),
                BackgroundTransparency = 1,
                Text = entry.label,
                TextColor3 = Theme.Text,
                TextSize = 13,
                Font = Util.Font("semi"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 503,
                Parent = row,
            })
            tracker.Register(title, "TextColor3", "Text")
            Util.Create("TextLabel", {
                Size = UDim2.new(1, -24, 0, 12),
                Position = UDim2.new(0, 12, 0, 20),
                BackgroundTransparency = 1,
                Text = entry.sub,
                TextColor3 = Theme.DimText,
                TextSize = 11,
                Font = Util.Font("regular"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 503,
                Parent = row,
            })
            row.MouseEnter:Connect(function() Util.Tween(row, { BackgroundColor3 = Theme.Hover }, 0.1) end)
            row.MouseLeave:Connect(function() Util.Tween(row, { BackgroundColor3 = Theme.Card  }, 0.1) end)
            row.MouseButton1Click:Connect(function()
                if entry.action then entry.action() end
                Window:_CloseSearch()
            end)
        end

        local function search(query)
            clearResults()
            query = string.lower(query or "")
            local hits = {}
            -- search tabs
            for _, tab in ipairs(Window.Tabs) do
                if query == "" or string.find(string.lower(tab.Name), query, 1, true) then
                    table.insert(hits, {
                        label = "Tab: " .. tab.Name,
                        sub   = "Switch to tab",
                        action = function() tab:Select() end,
                    })
                end
            end
            -- search elements
            for _, el in ipairs(Window.Elements) do
                if query == "" or string.find(string.lower(el.name or ""), query, 1, true)
                              or string.find(string.lower(el.tabName or ""), query, 1, true) then
                    table.insert(hits, {
                        label = el.name,
                        sub   = ("%s · %s"):format(el.tabName or "?", el.kind or "?"),
                        action = function()
                            if el.tab then el.tab:Select() end
                            if el.scrollIntoView then el.scrollIntoView() end
                        end,
                    })
                end
            end
            for _, hit in ipairs(hits) do makeResult(hit) end
        end

        input:GetPropertyChangedSignal("Text"):Connect(function() search(input.Text) end)

        function Window:_OpenSearch()
            search("")
            palette.Visible = true
            pBlur.Visible   = true
            palette.Size    = UDim2.new(0, 480, 0, 0)
            Util.Tween(palette, { Size = UDim2.new(0, 480, 0, 360) }, 0.3,
                Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            Util.Tween(pBlur, { BackgroundTransparency = 0.5 }, 0.2)
            input:CaptureFocus()
        end

        function Window:_CloseSearch()
            Util.Tween(palette, { Size = UDim2.new(0, 480, 0, 0) }, 0.25)
            Util.Tween(pBlur, { BackgroundTransparency = 1 }, 0.2)
            task.delay(0.3, function()
                palette.Visible = false
                pBlur.Visible   = false
                input.Text = ""
            end)
        end
        pBlur.MouseButton1Click:Connect(function() Window:_CloseSearch() end)
        searchBtn.MouseButton1Click:Connect(function() Window:_OpenSearch() end)
    end

    -- ═══════════════════════════════
    -- COMMAND PALETTE (Ctrl+K)
    -- ═══════════════════════════════
    do
        local palette = Util.Create("Frame", {
            Name              = "CommandPalette",
            Size              = UDim2.new(0, 480, 0, 360),
            AnchorPoint       = Vector2.new(0.5, 0.5),
            Position          = UDim2.new(0.5, 0, 0.5, 0),
            BackgroundColor3  = Theme.Secondary,
            BorderSizePixel   = 0,
            Visible           = false,
            ZIndex            = 500,
            Parent            = ScreenGui,
        })
        Util.Corner(palette, 12)
        Util.Stroke(palette, Theme.BorderStrong, 1.5, 0.3)
        tracker.Register(palette, "BackgroundColor3", "Secondary")
        local pBlur = Util.Create("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 1, AutoButtonColor = false, Text = "",
            ZIndex = 499, Visible = false, Parent = ScreenGui,
        })

        local input = Util.Create("TextBox", {
            Size = UDim2.new(1, -24, 0, 36),
            Position = UDim2.new(0, 12, 0, 10),
            BackgroundColor3 = Theme.Tertiary,
            BorderSizePixel  = 0,
            PlaceholderText  = "Type a command…",
            PlaceholderColor3 = Theme.DimText,
            Text = "",
            TextColor3       = Theme.Text,
            TextSize         = 14,
            Font             = Util.Font("regular"),
            TextXAlignment   = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            ZIndex           = 501,
            Parent           = palette,
        })
        Util.Corner(input, 6)
        Util.Padding(input, 0, 0, 10, 10)
        tracker.Register(input, "BackgroundColor3", "Tertiary")
        tracker.Register(input, "TextColor3", "Text")

        local list = Util.Create("ScrollingFrame", {
            Size = UDim2.new(1, -16, 1, -58),
            Position = UDim2.new(0, 8, 0, 50),
            BackgroundTransparency = 1,
            CanvasSize             = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize    = Enum.AutomaticSize.Y,
            ScrollBarThickness     = 3,
            ScrollBarImageColor3   = Theme.Accent,
            ZIndex                 = 501,
            Parent                 = palette,
        })
        Util.ListLayout(list, Enum.FillDirection.Vertical, 4)
        Util.Padding(list, 4, 4, 6, 6)

        local function clear()
            for _, c in ipairs(list:GetChildren()) do
                if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
            end
        end

        local function makeRow(name, desc, callback)
            local row = Util.Create("TextButton", {
                Size = UDim2.new(1, 0, 0, 36),
                BackgroundColor3 = Theme.Card,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 502,
                Parent = list,
            })
            Util.Corner(row, 6)
            tracker.Register(row, "BackgroundColor3", "Card")
            local title = Util.Create("TextLabel", {
                Size = UDim2.new(1, -24, 0, 16),
                Position = UDim2.new(0, 12, 0, 4),
                BackgroundTransparency = 1,
                Text = name,
                TextColor3 = Theme.Text,
                TextSize = 13,
                Font = Util.Font("semi"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 503,
                Parent = row,
            })
            tracker.Register(title, "TextColor3", "Text")
            Util.Create("TextLabel", {
                Size = UDim2.new(1, -24, 0, 12),
                Position = UDim2.new(0, 12, 0, 20),
                BackgroundTransparency = 1,
                Text = desc or "",
                TextColor3 = Theme.DimText,
                TextSize = 11,
                Font = Util.Font("regular"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 503,
                Parent = row,
            })
            row.MouseEnter:Connect(function() Util.Tween(row, { BackgroundColor3 = Theme.Hover }, 0.1) end)
            row.MouseLeave:Connect(function() Util.Tween(row, { BackgroundColor3 = Theme.Card  }, 0.1) end)
            row.MouseButton1Click:Connect(function()
                pcall(callback)
                Window:_CloseCommand()
            end)
        end

        local function rebuild(query)
            clear()
            query = string.lower(query or "")
            for name, cmd in pairs(Window.Commands) do
                if query == "" or string.find(string.lower(name), query, 1, true) then
                    makeRow(name, cmd.description, cmd.callback)
                end
            end
        end
        input:GetPropertyChangedSignal("Text"):Connect(function() rebuild(input.Text) end)

        function Window:_OpenCommand()
            rebuild("")
            palette.Visible = true
            pBlur.Visible   = true
            palette.Size    = UDim2.new(0, 480, 0, 0)
            Util.Tween(palette, { Size = UDim2.new(0, 480, 0, 360) }, 0.3,
                Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            Util.Tween(pBlur, { BackgroundTransparency = 0.5 }, 0.2)
            input:CaptureFocus()
        end
        function Window:_CloseCommand()
            Util.Tween(palette, { Size = UDim2.new(0, 480, 0, 0) }, 0.25)
            Util.Tween(pBlur, { BackgroundTransparency = 1 }, 0.2)
            task.delay(0.3, function()
                palette.Visible = false
                pBlur.Visible   = false
                input.Text = ""
            end)
        end
        pBlur.MouseButton1Click:Connect(function() Window:_CloseCommand() end)
        cmdBtn.MouseButton1Click:Connect(function() Window:_OpenCommand() end)
    end

    function Window:RegisterCommand(name, description, callback)
        Window.Commands[name] = { description = description, callback = callback }
    end

    -- Builtin commands
    Window:RegisterCommand("Reload theme", "Re-apply the current theme", function()
        Window:SetTheme(Window.ThemeName)
    end)
    Window:RegisterCommand("Toggle window", "Show / hide the main window", function()
        Window:Toggle()
    end)
    Window:RegisterCommand("Minimize / restore", "Collapse or restore the window", function()
        setMinimized(not Window.Minimized)
    end)
    Window:RegisterCommand("Close", "Destroy the window", function() Window:Destroy() end)

    -- ═══════════════════════════════
    -- PROMPT / CONFIRM DIALOG
    -- ═══════════════════════════════
    function Window:Prompt(promptCfg)
        promptCfg = promptCfg or {}
        local title    = promptCfg.Title    or "Confirm"
        local text     = promptCfg.Content  or "Are you sure?"
        local yesText  = promptCfg.Yes      or "Confirm"
        local noText   = promptCfg.No       or "Cancel"
        local callback = promptCfg.Callback or function() end

        local overlay = Util.Create("TextButton", {
            Size                 = UDim2.new(1, 0, 1, 0),
            BackgroundColor3     = Color3.new(0, 0, 0),
            BackgroundTransparency = 1,
            Text                 = "",
            AutoButtonColor      = false,
            ZIndex               = 800,
            Parent               = ScreenGui,
        })

        local dlg = Util.Create("Frame", {
            Size                 = UDim2.new(0, 360, 0, 0),
            AutomaticSize        = Enum.AutomaticSize.Y,
            AnchorPoint          = Vector2.new(0.5, 0.5),
            Position             = UDim2.new(0.5, 0, 0.5, 0),
            BackgroundColor3     = Theme.Background,
            BorderSizePixel      = 0,
            ZIndex               = 801,
            Parent               = ScreenGui,
        })
        Util.Corner(dlg, 12)
        Util.Stroke(dlg, Theme.BorderStrong, 1.5, 0.3)
        Util.Padding(dlg, 20, 20, 20, 20)
        Util.ListLayout(dlg, Enum.FillDirection.Vertical, 12,
            Enum.HorizontalAlignment.Left)
        tracker.Register(dlg, "BackgroundColor3", "Background")

        local titleLbl = Util.Create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            Text = title, TextColor3 = Theme.Text,
            TextSize = 16, Font = Util.Font("bold"),
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1, ZIndex = 802, Parent = dlg,
        })
        tracker.Register(titleLbl, "TextColor3", "Text")
        local contentLbl = Util.Create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text = text, TextColor3 = Theme.SubText,
            TextSize = 13, Font = Util.Font("regular"),
            TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
            LayoutOrder = 2, ZIndex = 802, Parent = dlg,
        })
        tracker.Register(contentLbl, "TextColor3", "SubText")

        local row = Util.Create("Frame", {
            Size = UDim2.new(1, 0, 0, 38),
            BackgroundTransparency = 1, LayoutOrder = 3,
            ZIndex = 802, Parent = dlg,
        })
        Util.ListLayout(row, Enum.FillDirection.Horizontal, 10,
            Enum.HorizontalAlignment.Right)

        local function makeBtn(t, color, txtCol, result, primary)
            local b = Util.Create("TextButton", {
                Size = UDim2.new(0, 120, 0, 38),
                BackgroundColor3 = color, BorderSizePixel = 0,
                Text = t, TextColor3 = txtCol,
                TextSize = 13, Font = Util.Font("bold"),
                AutoButtonColor = false, ZIndex = 803, Parent = row,
            })
            Util.Corner(b, 8)
            if primary then Util.Ripple(b) end
            b.MouseEnter:Connect(function() Util.Tween(b, { BackgroundTransparency = 0.15 }, 0.15) end)
            b.MouseLeave:Connect(function() Util.Tween(b, { BackgroundTransparency = 0 }, 0.15) end)
            b.MouseButton1Click:Connect(function()
                Util.Tween(dlg, { Size = UDim2.new(0, 360, 0, 0) },
                    0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)
                Util.Tween(overlay, { BackgroundTransparency = 1 }, 0.2)
                task.delay(0.3, function()
                    overlay:Destroy(); dlg:Destroy()
                end)
                pcall(callback, result)
            end)
        end
        makeBtn(noText,  Theme.Tertiary, Theme.Text, false, false)
        makeBtn(yesText, Theme.Accent,   Color3.new(1, 1, 1), true, true)
        overlay.MouseButton1Click:Connect(function()
            Util.Tween(dlg, { Size = UDim2.new(0, 360, 0, 0) }, 0.25)
            Util.Tween(overlay, { BackgroundTransparency = 1 }, 0.2)
            task.delay(0.3, function()
                overlay:Destroy(); dlg:Destroy()
            end)
            pcall(callback, false)
        end)
        Util.Tween(overlay, { BackgroundTransparency = 0.5 }, 0.25)
    end

    -- ═══════════════════════════════
    -- FLOATING WINDOWS
    -- ═══════════════════════════════
    function Window:CreateFloatingWindow(fwConfig)
        fwConfig = fwConfig or {}
        local fwTitle       = fwConfig.Title    or "Window"
        local fwSize        = fwConfig.Size     or UDim2.new(0, 240, 0, 320)
        local fwPosition    = fwConfig.Position or UDim2.new(0, 100, 0, 100)
        local fwVisible     = (fwConfig.Visible ~= false)
        local fwIndependent = (fwConfig.Independent ~= false)

        local FW = {
            Title       = fwTitle,
            Visible     = fwVisible,
            Independent = fwIndependent,
            _size       = fwSize,
            _wasVisible = fwVisible,
            _elementOrder = 0,
            _statusMap  = {},
        }

        local frame = Util.Create("Frame", {
            Name             = "FW_" .. fwTitle,
            Position         = fwPosition,
            Size             = fwSize,
            BackgroundColor3 = Theme.Background,
            BorderSizePixel  = 0,
            ClipsDescendants = true,
            Visible          = fwVisible,
            ZIndex           = 30,
            Parent           = ScreenGui,
        })
        Util.Corner(frame, 10)
        Util.Stroke(frame, Theme.Border, 1.5, 0.35)
        tracker.Register(frame, "BackgroundColor3", "Background")
        FW.Frame = frame

        local sh = Util.BindShadow(ScreenGui, frame, Theme.Shadow)
        mainMaid:Give({ Destroy = sh.Destroy })

        local accent = Util.Create("Frame", {
            Size = UDim2.new(1, 0, 0, 2),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0, ZIndex = 31, Parent = frame,
        })
        Util.AnimatedAccent(accent, Theme)
        tracker.Register(accent, "BackgroundColor3", "Accent")

        local header = Util.Create("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            Position = UDim2.new(0, 0, 0, 2),
            BackgroundColor3 = Theme.Secondary,
            BorderSizePixel = 0, ZIndex = 31, Parent = frame,
        })
        tracker.Register(header, "BackgroundColor3", "Secondary")
        Util.Create("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = Theme.Border,
            BorderSizePixel = 0, ZIndex = 31, Parent = header,
        })
        local titleLbl = Util.Create("TextLabel", {
            Size = UDim2.new(1, -40, 1, 0),
            Position = UDim2.new(0, 12, 0, 0),
            BackgroundTransparency = 1,
            Text = fwTitle,
            TextColor3 = Theme.Text,
            TextSize = 13, Font = Util.Font("bold"),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 32, Parent = header,
        })
        tracker.Register(titleLbl, "TextColor3", "Text")

        local cleanupFwDrag = Util.MakeDraggable(frame, header)
        mainMaid:Give(cleanupFwDrag)

        -- close btn
        local closeFw = Util.Create("TextButton", {
            Size = UDim2.new(0, 22, 0, 22),
            Position = UDim2.new(1, -28, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Theme.Tertiary,
            BorderSizePixel = 0,
            Text = "", AutoButtonColor = false, ZIndex = 32, Parent = header,
        })
        Util.Corner(closeFw, 5)
        tracker.Register(closeFw, "BackgroundColor3", "Tertiary")
        Util.Create("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
            Text = Icons.cross, TextColor3 = Theme.SubText,
            TextSize = 11, Font = Util.Font("bold"),
            ZIndex = 33, Parent = closeFw,
        })
        closeFw.MouseEnter:Connect(function() Util.Tween(closeFw, { BackgroundColor3 = Theme.Hover }, 0.15) end)
        closeFw.MouseLeave:Connect(function() Util.Tween(closeFw, { BackgroundColor3 = Theme.Tertiary }, 0.15) end)
        closeFw.MouseButton1Click:Connect(function() FW:Hide() end)

        local content = Util.Create("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, -36),
            Position = UDim2.new(0, 0, 0, 36),
            BackgroundTransparency = 1,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ZIndex = 31, Parent = frame,
        })
        Util.ListLayout(content, Enum.FillDirection.Vertical, 4)
        Util.Padding(content, 8, 8, 8, 8)
        FW.Content = content

        local function nextOrder()
            FW._elementOrder = FW._elementOrder + 1
            return FW._elementOrder
        end

        function FW:Show()
            self.Visible = true
            frame.Visible = true
            frame.Size = UDim2.new(0, fwSize.X.Offset, 0, 0)
            Util.Tween(frame, { Size = fwSize }, 0.35,
                Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        end
        function FW:Hide()
            self.Visible = false
            Util.Tween(frame, { Size = UDim2.new(0, fwSize.X.Offset, 0, 0) },
                0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
            task.delay(0.35, function()
                if not self.Visible then frame.Visible = false end
            end)
        end
        function FW:Toggle()
            if self.Visible then self:Hide() else self:Show() end
        end
        function FW:Destroy()
            sh.Destroy()
            frame:Destroy()
            self.Visible = false
        end
        function FW:SetTitle(t) titleLbl.Text = t end

        function FW:AddLabel(text)
            local lbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 22),
                BackgroundTransparency = 1,
                Text = text, TextColor3 = Theme.SubText,
                TextSize = 12, Font = Util.Font("regular"),
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = nextOrder(), ZIndex = 32, Parent = content,
            })
            tracker.Register(lbl, "TextColor3", "SubText")
            local obj = {}
            function obj:Set(t) lbl.Text = t end
            return obj
        end

        function FW:AddStatus(sCfg)
            sCfg = sCfg or {}
            local name = sCfg.Name or "Status"
            local active = sCfg.Default or false

            local row = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundColor3 = active and Theme.Tertiary or Theme.Card,
                BorderSizePixel = 0,
                LayoutOrder = nextOrder(), ZIndex = 32, Parent = content,
            })
            Util.Corner(row, 6)
            local dot = Util.Create("Frame", {
                Size = UDim2.new(0, 10, 0, 10),
                Position = UDim2.new(0, 10, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = active and Theme.ToggleOn or Theme.ToggleOff,
                BorderSizePixel = 0, ZIndex = 33, Parent = row,
            })
            Util.Corner(dot, 999)
            local glow = Util.Create("Frame", {
                Size = UDim2.new(0, 18, 0, 18),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Theme.ToggleOn,
                BackgroundTransparency = active and 0.6 or 1,
                BorderSizePixel = 0, ZIndex = 32, Parent = dot,
            })
            Util.Corner(glow, 999)
            local lbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, -30, 1, 0),
                Position = UDim2.new(0, 28, 0, 0),
                BackgroundTransparency = 1,
                Text = name,
                TextColor3 = active and Theme.Text or Theme.DimText,
                TextSize = 12, Font = Util.Font("semi"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 33, Parent = row,
            })

            local s = { active = active }
            function s:Set(state)
                self.active = state
                Util.Tween(dot,  { BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff }, 0.25)
                Util.Tween(glow, { BackgroundTransparency = state and 0.6 or 1 }, 0.25)
                Util.Tween(lbl,  { TextColor3 = state and Theme.Text or Theme.DimText }, 0.25)
                Util.Tween(row,  { BackgroundColor3 = state and Theme.Tertiary or Theme.Card }, 0.25)
            end
            function s:Get() return self.active end
            FW._statusMap[name] = s
            return s
        end
        FW.Track = function(self, name, default) return self:AddStatus({ Name = name, Default = default }) end

        function FW:AddButton(bCfg)
            bCfg = bCfg or {}
            local b = Util.Create("TextButton", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundColor3 = Theme.Card,
                BorderSizePixel = 0,
                Text = "", AutoButtonColor = false,
                LayoutOrder = nextOrder(), ZIndex = 32, Parent = content,
            })
            Util.Corner(b, 6)
            Util.Ripple(b)
            tracker.Register(b, "BackgroundColor3", "Card")
            local lbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, -20, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = bCfg.Name or "Button",
                TextColor3 = Theme.Text,
                TextSize = 12, Font = Util.Font("semi"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 33, Parent = b,
            })
            tracker.Register(lbl, "TextColor3", "Text")
            b.MouseEnter:Connect(function() Util.Tween(b, { BackgroundColor3 = Theme.Hover }, 0.15) end)
            b.MouseLeave:Connect(function() Util.Tween(b, { BackgroundColor3 = Theme.Card  }, 0.15) end)
            b.MouseButton1Click:Connect(bCfg.Callback or function() end)
        end

        function FW:AddSeparator()
            local s = Util.Create("Frame", {
                Size = UDim2.new(1, -10, 0, 1),
                BackgroundColor3 = Theme.Border,
                BorderSizePixel = 0,
                LayoutOrder = nextOrder(), ZIndex = 32, Parent = content,
            })
            tracker.Register(s, "BackgroundColor3", "Border")
        end

        if fwVisible then
            frame.Size = UDim2.new(0, fwSize.X.Offset, 0, 0)
            task.defer(function()
                Util.Tween(frame, { Size = fwSize }, 0.4,
                    Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            end)
        end

        table.insert(Window.FloatingWindows, FW)
        return FW
    end

    function Window:CreateBindsList(cfg2)
        cfg2 = cfg2 or {}
        local fw = Window:CreateFloatingWindow({
            Title       = cfg2.Title       or (Icons.bolt .. " Active"),
            Size        = cfg2.Size        or UDim2.new(0, 200, 0, 300),
            Position    = cfg2.Position    or UDim2.new(0, 20, 0, 100),
            Visible     = (cfg2.Visible ~= false),
            Independent = (cfg2.Independent ~= false),
        })
        Window.DefaultBindsList = fw
        return fw
    end

    function Window:CreateStatusWindow(cfg2)
        cfg2 = cfg2 or {}
        return Window:CreateFloatingWindow({
            Title       = cfg2.Title       or "Status",
            Size        = cfg2.Size        or UDim2.new(0, 200, 0, 250),
            Position    = cfg2.Position    or UDim2.new(0, 20, 0, 420),
            Visible     = (cfg2.Visible ~= false),
            Independent = (cfg2.Independent ~= false),
        })
    end

    -- ═══════════════════════════════
    -- WATERMARK (throttled, draggable)
    -- ═══════════════════════════════
    function Window:CreateWatermark(wmCfg)
        wmCfg = wmCfg or {}
        local wmText = wmCfg.Text or cfg.Title

        local wmFrame = Util.Create("Frame", {
            Name              = "Watermark",
            AnchorPoint       = Vector2.new(1, 0),
            Position          = wmCfg.Position or UDim2.new(1, -20, 0, 10),
            Size              = UDim2.new(0, 0, 0, 28),
            AutomaticSize     = Enum.AutomaticSize.X,
            BackgroundColor3  = Theme.Background,
            BorderSizePixel   = 0,
            ZIndex            = 100,
            Parent            = ScreenGui,
        })
        Util.Corner(wmFrame, 8)
        Util.Stroke(wmFrame, Theme.Border, 1, 0.5)
        Util.Padding(wmFrame, 0, 0, 12, 12)
        tracker.Register(wmFrame, "BackgroundColor3", "Background")

        local accent = Util.Create("Frame", {
            Size = UDim2.new(1, 0, 0, 2),
            Position = UDim2.new(0, 0, 1, -2),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            ZIndex = 101, Parent = wmFrame,
        })
        Util.AnimatedAccent(accent, Theme)
        tracker.Register(accent, "BackgroundColor3", "Accent")

        local lbl = Util.Create("TextLabel", {
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            Text = wmText .. " · FPS: 60 · 00:00:00",
            TextColor3 = Theme.Text,
            TextSize = 11, Font = Util.Font("semi"),
            ZIndex = 101, Parent = wmFrame,
        })
        tracker.Register(lbl, "TextColor3", "Text")

        mainMaid:Give(Util.MakeDraggable(wmFrame, wmFrame))

        -- Throttled FPS tracker (4 Hz instead of 60+ Hz)
        local sampleCount, sampleTotal = 0, 0
        local fps = 60
        local sampleConn = RunService.RenderStepped:Connect(function(dt)
            sampleCount += 1
            sampleTotal += 1 / math.max(dt, 1e-3)
        end)
        mainMaid:Give(sampleConn)

        local updTask = task.spawn(function()
            while Window.Alive do
                task.wait(0.25)
                if not wmFrame.Visible then continue end
                if sampleCount > 0 then
                    fps = math.floor(sampleTotal / sampleCount + 0.5)
                    sampleCount, sampleTotal = 0, 0
                end
                lbl.Text = string.format("%s · FPS: %d · %s",
                    wmText, fps, os.date("%H:%M:%S"))
            end
        end)
        mainMaid:Give(function()
            pcall(function() task.cancel(updTask) end)
        end)

        local obj = {}
        function obj:SetText(t) wmText = t end
        function obj:SetVisible(v) wmFrame.Visible = v end
        function obj:Destroy() wmFrame:Destroy() end
        return obj
    end

    -- ═══════════════════════════════
    -- SPLASH / LOADING SCREEN
    -- ═══════════════════════════════
    function NexusUI:Splash(splashCfg)
        splashCfg = splashCfg or {}
        local splashTitle = splashCfg.Title or "Loading…"
        local subtitle    = splashCfg.SubTitle or ""
        local duration    = splashCfg.Duration or 2
        local theme       = Themes[splashCfg.Theme or "Dark"] or Themes.Dark

        local parent = Util.GetGuiParent()
        local sg = Util.Create("ScreenGui", {
            Name = LIB_NAME .. "_Splash",
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            ResetOnSpawn = false, IgnoreGuiInset = true,
            DisplayOrder = 999, Parent = parent,
        })
        local dim = Util.Create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0, ZIndex = 1, Parent = sg,
        })
        local card = Util.Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, 360, 0, 140),
            BackgroundColor3 = theme.Background,
            BorderSizePixel = 0, ZIndex = 2, Parent = sg,
        })
        Util.Corner(card, 14)
        Util.Stroke(card, theme.BorderStrong, 1.5, 0.3)

        local accent = Util.Create("Frame", {
            Size = UDim2.new(1, 0, 0, 3),
            BackgroundColor3 = theme.Accent,
            BorderSizePixel = 0, ZIndex = 3, Parent = card,
        })
        Util.AnimatedAccent(accent, theme)

        Util.Create("TextLabel", {
            Size = UDim2.new(1, -40, 0, 24),
            Position = UDim2.new(0, 20, 0, 20),
            BackgroundTransparency = 1,
            Text = splashTitle, TextColor3 = theme.Text,
            TextSize = 18, Font = Util.Font("bold"),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 3, Parent = card,
        })
        Util.Create("TextLabel", {
            Size = UDim2.new(1, -40, 0, 16),
            Position = UDim2.new(0, 20, 0, 48),
            BackgroundTransparency = 1,
            Text = subtitle, TextColor3 = theme.DimText,
            TextSize = 12, Font = Util.Font("regular"),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 3, Parent = card,
        })

        local barBg = Util.Create("Frame", {
            Size = UDim2.new(1, -40, 0, 6),
            Position = UDim2.new(0, 20, 1, -26),
            BackgroundColor3 = theme.Tertiary,
            BorderSizePixel = 0, ZIndex = 3, Parent = card,
        })
        Util.Corner(barBg, 3)
        local bar = Util.Create("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = theme.Accent,
            BorderSizePixel = 0, ZIndex = 4, Parent = barBg,
        })
        Util.Corner(bar, 3)

        Util.Tween(bar, { Size = UDim2.new(1, 0, 1, 0) }, duration, Enum.EasingStyle.Linear)
        task.delay(duration + 0.2, function()
            Util.Tween(dim,  { BackgroundTransparency = 1 }, 0.3)
            Util.Tween(card, { Size = UDim2.new(0, 360, 0, 0) }, 0.3,
                Enum.EasingStyle.Back, Enum.EasingDirection.In)
            task.wait(0.35)
            sg:Destroy()
        end)

        local obj = {}
        function obj:SetProgress(p)
            bar:TweenSize(UDim2.new(math.clamp(p, 0, 1), 0, 1, 0),
                Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.2, true)
        end
        function obj:Close()
            Util.Tween(dim, { BackgroundTransparency = 1 }, 0.2)
            Util.Tween(card, { Size = UDim2.new(0, 360, 0, 0) }, 0.25)
            task.wait(0.3); sg:Destroy()
        end
        return obj
    end

    -- ═══════════════════════════════
    -- CONFIG SAVE / LOAD
    -- ═══════════════════════════════
    local function configPath(name)
        local folder = cfg.ConfigFolder
        local placeFolder = folder .. "/" .. tostring(game.PlaceId)
        return folder, placeFolder, placeFolder .. "/" .. name .. ".json"
    end

    local function ensureConfigDir()
        local folder, placeFolder = configPath("")
        pcall(function()
            if isfolder and not isfolder(folder) and makefolder then makefolder(folder) end
            if isfolder and not isfolder(placeFolder) and makefolder then makefolder(placeFolder) end
        end)
    end

    function Window:SaveConfig(name)
        if not (writefile and isfolder and makefolder) then
            self:Notify({ Title = "Save failed", Content = "Executor missing file API", Type = "Error" })
            return false
        end
        ensureConfigDir()
        local data = {}
        for flag, info in pairs(Window.Flags) do
            local value = info.get()
            if info.type == "color" then
                data[flag] = { math.floor(value.R * 255), math.floor(value.G * 255), math.floor(value.B * 255) }
            elseif info.type == "keybind" then
                local key = value.Key
                local kind = (typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode) and "key" or "input"
                data[flag] = { kind = kind, name = key.Name, modifiers = value.Modifiers, mode = value.Mode }
            else
                data[flag] = value
            end
        end
        local _, _, path = configPath(name)
        local ok = pcall(function()
            writefile(path, HttpService:JSONEncode(data))
        end)
        if ok then
            self:Notify({ Title = "Config saved", Content = name, Type = "Success", Duration = 3 })
        end
        return ok
    end

    function Window:LoadConfig(name)
        if not (readfile and isfile) then
            self:Notify({ Title = "Load failed", Content = "Executor missing file API", Type = "Error" })
            return false
        end
        local _, _, path = configPath(name)
        if not isfile(path) then
            self:Notify({ Title = "Not found", Content = name, Type = "Warning", Duration = 3 })
            return false
        end
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(path))
        end)
        if not ok then return false end
        for flag, value in pairs(data) do
            local info = Window.Flags[flag]
            if info then
                if info.type == "color" and type(value) == "table" then
                    info.set(Color3.fromRGB(value[1] or 255, value[2] or 0, value[3] or 0))
                elseif info.type == "keybind" and type(value) == "table" then
                    local key
                    if value.kind == "key" then key = Enum.KeyCode[value.name]
                    else key = Enum.UserInputType[value.name] end
                    info.set({ Key = key, Modifiers = value.modifiers, Mode = value.mode })
                else
                    info.set(value)
                end
            end
        end
        self:Notify({ Title = "Config loaded", Content = name, Type = "Success", Duration = 3 })
        return true
    end

    function Window:ListConfigs()
        local list = {}
        if not (listfiles and isfolder) then return list end
        local _, placeFolder = configPath("")
        if not isfolder(placeFolder) then return list end
        local files = listfiles(placeFolder)
        for _, p in ipairs(files) do
            local name = p:match("([^/\\]+)%.json$")
            if name then table.insert(list, name) end
        end
        table.sort(list)
        return list
    end

    function Window:DeleteConfig(name)
        if not delfile then return false end
        local _, _, path = configPath(name)
        local ok = pcall(function() delfile(path) end)
        return ok
    end

    function Window:ExportConfig(name)
        if not (readfile and isfile and setclipboard) then return false end
        local _, _, path = configPath(name)
        if not isfile(path) then return false end
        local ok, data = pcall(readfile, path)
        if not ok then return false end
        setclipboard(data)
        self:Notify({ Title = "Copied to clipboard", Content = name, Type = "Info", Duration = 2 })
        return true
    end

    function Window:ImportConfig(name, jsonString)
        if not (writefile and makefolder and isfolder) then return false end
        ensureConfigDir()
        -- validate first
        local ok = pcall(function() HttpService:JSONDecode(jsonString) end)
        if not ok then return false end
        local _, _, path = configPath(name)
        local ok2 = pcall(function() writefile(path, jsonString) end)
        return ok2
    end

    function Window:GetFlag(flagName)
        if Window.Flags[flagName] then return Window.Flags[flagName].get() end
        return nil
    end

    function Window:SetFlag(flagName, value)
        if Window.Flags[flagName] then Window.Flags[flagName].set(value) end
    end

    -- ═══════════════════════════════
    -- THEME RUNTIME SWITCH
    -- ═══════════════════════════════
    function Window:SetTheme(name, animated)
        local t = Themes[name]
        if not t then return false end
        Theme = t
        Window.Theme = t
        Window.ThemeName = name
        tracker.ApplyTheme(t, animated ~= false)
        Window.Signals.ThemeChanged:Fire(t, name)
        return true
    end

    -- ═══════════════════════════════
    -- WEBHOOK HELPER
    -- ═══════════════════════════════
    function Window:SendWebhook(url, payload)
        local http_request = (syn and syn.request) or (http and http.request) or http_request or request
        if not http_request then
            self:Notify({ Title = "Webhook failed", Content = "No http_request available",
                Type = "Error" })
            return false
        end
        local body = type(payload) == "string" and payload or HttpService:JSONEncode(payload)
        local ok = pcall(function()
            http_request({
                Url = url, Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body,
            })
        end)
        return ok
    end

    -- ═══════════════════════════════
    -- UPDATE CHECKER
    -- ═══════════════════════════════
    function NexusUI:CheckUpdate(versionUrl)
        local ok, response = pcall(function()
            return game:HttpGet(versionUrl)
        end)
        if not ok or type(response) ~= "string" then return false end
        local remote = response:match("(%d+%.%d+%.%d+)") or response
        if remote == LIB_VERSION then return false, remote end
        return remote ~= LIB_VERSION, remote
    end

    -- ═══════════════════════════════
    -- TAB
    -- ═══════════════════════════════
    function Window:CreateTab(tabCfg)
        tabCfg = tabCfg or {}
        local tName = type(tabCfg) == "string" and tabCfg or (tabCfg.Name or "Tab")
        local tIcon = (type(tabCfg) == "table" and tabCfg.Icon) or nil
        local tIconText = (type(tabCfg) == "table" and tabCfg.IconText) or nil

        local Tab = {
            Name        = tName,
            Window      = Window,
            _elements   = {},
            _elementOrder = 0,
            _columnsMode = 1,
        }

        -- Tab button (sidebar)
        local btn = Util.Create("TextButton", {
            Size                  = UDim2.new(0, 42, 0, 42),
            BackgroundColor3      = Theme.Tertiary,
            BackgroundTransparency = 1,
            BorderSizePixel       = 0,
            Text                  = "",
            AutoButtonColor       = false,
            ZIndex                = 13,
            Parent                = TabButtonScroll,
        })
        Util.Corner(btn, 8)

        local activeIndicator = Util.Create("Frame", {
            Size                  = UDim2.new(0, 3, 0, 18),
            Position              = UDim2.new(0, -8, 0.5, 0),
            AnchorPoint           = Vector2.new(0, 0.5),
            BackgroundColor3      = Theme.Accent,
            BorderSizePixel       = 0,
            Visible               = false,
            ZIndex                = 14,
            Parent                = btn,
        })
        Util.Corner(activeIndicator, 2)
        tracker.Register(activeIndicator, "BackgroundColor3", "Accent")

        if tIcon and string.sub(tIcon, 1, 4) == "rbxa" then
            Util.Create("ImageLabel", {
                Size                  = UDim2.new(0.6, 0, 0.6, 0),
                Position              = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint           = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Image                 = tIcon,
                ImageColor3           = Theme.SubText,
                ZIndex                = 14,
                Parent                = btn,
            })
        else
            local lbl = Util.Create("TextLabel", {
                Size                  = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text                  = tIconText or NexusUI.GetIcon(tIcon or "") or (tIcon or string.upper(string.sub(tName, 1, 1))),
                TextColor3            = Theme.SubText,
                TextSize              = 18,
                Font                  = Util.Font("bold"),
                ZIndex                = 14,
                Parent                = btn,
            })
            tracker.Register(lbl, "TextColor3", "SubText")
            Tab._iconLbl = lbl
        end

        Window:BindTooltip(btn, tName)

        -- Content page
        local page = Util.Create("ScrollingFrame", {
            Name                  = "TabPage_" .. tName,
            Size                  = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            ScrollBarThickness    = 3,
            ScrollBarImageColor3  = Theme.Accent,
            BorderSizePixel       = 0,
            CanvasSize            = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize   = Enum.AutomaticSize.Y,
            Visible               = false,
            ZIndex                = 12,
            Parent                = ContentArea,
        })
        Util.ListLayout(page, Enum.FillDirection.Vertical, 8,
            Enum.HorizontalAlignment.Left)
        Util.Padding(page, 16, 16, 16, 16)
        Tab.Page = page

        local function nextOrder()
            Tab._elementOrder = Tab._elementOrder + 1
            return Tab._elementOrder
        end
        Tab._nextOrder = nextOrder

        -- Hover effect for inactive tabs
        btn.MouseEnter:Connect(function()
            if Window.ActiveTab ~= Tab then
                Util.Tween(btn, { BackgroundTransparency = 0 }, 0.15)
            end
        end)
        btn.MouseLeave:Connect(function()
            if Window.ActiveTab ~= Tab then
                Util.Tween(btn, { BackgroundTransparency = 1 }, 0.15)
            end
        end)

        function Tab:Select()
            for _, t in ipairs(Window.Tabs) do
                if t ~= self then
                    t.Page.Visible = false
                    if t._iconLbl then
                        Util.Tween(t._iconLbl, { TextColor3 = Theme.SubText }, 0.2)
                    end
                    Util.Tween(t._btn, { BackgroundTransparency = 1 }, 0.2)
                    t._activeIndicator.Visible = false
                end
            end
            page.Visible = true
            if self._iconLbl then
                Util.Tween(self._iconLbl, { TextColor3 = Theme.Text }, 0.2)
            end
            Util.Tween(btn, { BackgroundColor3 = Theme.Card, BackgroundTransparency = 0 }, 0.2)
            activeIndicator.Visible = true
            Window.ActiveTab = self
        end
        function Tab:SetIcon(iconText)
            if Tab._iconLbl then Tab._iconLbl.Text = NexusUI.GetIcon(iconText) or iconText end
        end
        function Tab:SetName(name)
            Tab.Name = name
            Window:BindTooltip(btn, name)
        end
        Tab._btn = btn
        Tab._activeIndicator = activeIndicator
        btn.MouseButton1Click:Connect(function() Tab:Select() end)

        table.insert(Window.Tabs, Tab)
        if #Window.Tabs == 1 then Tab:Select() end

        -- ═══════════════════════════════
        -- ELEMENT HELPERS
        -- ═══════════════════════════════
        local function registerElement(name, kind, page_)
            local entry = {
                name     = name,
                tabName  = Tab.Name,
                tab      = Tab,
                kind     = kind,
                scrollIntoView = function()
                    -- scroll to element
                    if page_ then
                        local p = page_.AbsolutePosition.Y - Tab.Page.AbsolutePosition.Y
                        Tab.Page.CanvasPosition = Vector2.new(0, math.max(0, p - 20))
                    end
                end,
            }
            table.insert(Window.Elements, entry)
            return entry
        end

        local function attachBaseObject(obj, frame, elementRegistration)
            function obj:SetVisible(v)
                frame.Visible = v and true or false
            end
            function obj:SetTooltip(text)
                if self._tipCleanup then self._tipCleanup() end
                self._tipCleanup = Window:BindTooltip(frame, text)
            end
            function obj:Destroy()
                if self._tipCleanup then self._tipCleanup() end
                if frame and frame.Parent then frame:Destroy() end
                for i, el in ipairs(Window.Elements) do
                    if el == elementRegistration then table.remove(Window.Elements, i); break end
                end
                for i, e in ipairs(Tab._elements) do
                    if e == self then table.remove(Tab._elements, i); break end
                end
            end
            table.insert(Tab._elements, obj)
            return obj
        end

        local function makeName(cfg2)
            return (type(cfg2) == "table" and (cfg2.Name or cfg2.Title)) or tostring(cfg2 or "Element")
        end

        -- ═══════════════════════════════
        -- SECTION (collapsible)
        -- ═══════════════════════════════
        function Tab:CreateSection(secCfg)
            local secName = type(secCfg) == "string" and secCfg or (secCfg and secCfg.Name) or "Section"
            local collapsible = type(secCfg) == "table" and secCfg.Collapsible == true

            local container = Util.Create("Frame", {
                Size                  = UDim2.new(1, 0, 0, 0),
                AutomaticSize         = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                LayoutOrder           = nextOrder(),
                ZIndex                = 13,
                Parent                = page,
            })
            Util.ListLayout(container, Enum.FillDirection.Vertical, 6)

            local header = Util.Create("TextButton", {
                Size                  = UDim2.new(1, 0, 0, 26),
                BackgroundTransparency = 1,
                Text                  = "", AutoButtonColor = false,
                LayoutOrder           = 1,
                ZIndex                = 14,
                Parent                = container,
            })

            local chevron = Util.Create("TextLabel", {
                Size                  = UDim2.new(0, 14, 1, 0),
                Position              = UDim2.new(0, 0, 0, 0),
                BackgroundTransparency = 1,
                Text                  = collapsible and Icons.chevron_down or "",
                TextColor3            = Theme.SubText,
                TextSize              = 12,
                Font                  = Util.Font("bold"),
                ZIndex                = 15,
                Parent                = header,
            })
            tracker.Register(chevron, "TextColor3", "SubText")
            local label = Util.Create("TextLabel", {
                Size                  = UDim2.new(1, -20, 1, 0),
                Position              = UDim2.new(0, collapsible and 18 or 0, 0, 0),
                BackgroundTransparency = 1,
                Text                  = string.upper(secName),
                TextColor3            = Theme.AccentLight,
                TextSize              = 11,
                Font                  = Util.Font("bold"),
                TextXAlignment        = Enum.TextXAlignment.Left,
                ZIndex                = 15,
                Parent                = header,
            })
            tracker.Register(label, "TextColor3", "AccentLight")

            local line = Util.Create("Frame", {
                Size                  = UDim2.new(1, 0, 0, 1),
                BackgroundColor3      = Theme.Border,
                BorderSizePixel       = 0,
                LayoutOrder           = 2,
                ZIndex                = 14,
                Parent                = container,
            })
            tracker.Register(line, "BackgroundColor3", "Border")

            local body = Util.Create("Frame", {
                Size                  = UDim2.new(1, 0, 0, 0),
                AutomaticSize         = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                LayoutOrder           = 3,
                ZIndex                = 13,
                Parent                = container,
            })
            Util.ListLayout(body, Enum.FillDirection.Vertical, 6)

            local sec = {
                Kind     = "Section",
                _body    = body,
                _frame   = container,
                _open    = true,
                _label   = label,
            }
            local reg = registerElement(secName, "Section", container)
            attachBaseObject(sec, container, reg)

            function sec:SetName(name)
                label.Text = string.upper(name)
            end

            if collapsible then
                header.MouseButton1Click:Connect(function()
                    sec._open = not sec._open
                    body.Visible = sec._open
                    Util.Tween(chevron, { Rotation = sec._open and 0 or -90 }, 0.2)
                end)
            end

            -- Section acts as a parent for next elements via :Add* methods.
            return sec
        end

        function Tab:CreateLabel(text)
            local frame = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
                LayoutOrder = nextOrder(), ZIndex = 13, Parent = page,
            })
            local lbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
                Text = type(text) == "string" and text or (text and text.Text or ""),
                TextColor3 = Theme.SubText, TextSize = 12,
                Font = Util.Font("regular"), TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 14, Parent = frame,
            })
            tracker.Register(lbl, "TextColor3", "SubText")
            local reg = registerElement(lbl.Text, "Label", frame)
            local obj = { Kind = "Label" }
            attachBaseObject(obj, frame, reg)
            function obj:Set(t) lbl.Text = t end
            return obj
        end

        function Tab:CreateDivider()
            local d = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Border,
                BorderSizePixel = 0, LayoutOrder = nextOrder(),
                ZIndex = 13, Parent = page,
            })
            tracker.Register(d, "BackgroundColor3", "Border")
            local reg = registerElement("Divider", "Divider", d)
            local obj = { Kind = "Divider" }
            attachBaseObject(obj, d, reg)
            return obj
        end

        function Tab:CreateParagraph(pCfg)
            pCfg = pCfg or {}
            local title   = pCfg.Title or "Paragraph"
            local content = pCfg.Content or ""

            local frame = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
                LayoutOrder = nextOrder(), ZIndex = 13, Parent = page,
            })
            Util.Corner(frame, 8)
            Util.Stroke(frame, Theme.Border, 1, 0.5)
            Util.Padding(frame, 10, 10, 12, 12)
            Util.ListLayout(frame, Enum.FillDirection.Vertical, 4)
            tracker.Register(frame, "BackgroundColor3", "Card")

            local titleLbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1, Text = title,
                TextColor3 = Theme.Text, TextSize = 13, Font = Util.Font("bold"),
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1, ZIndex = 14, Parent = frame,
            })
            tracker.Register(titleLbl, "TextColor3", "Text")
            local contentLbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, Text = content,
                TextColor3 = Theme.SubText, TextSize = 12, Font = Util.Font("regular"),
                TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
                LayoutOrder = 2, ZIndex = 14, Parent = frame,
            })
            tracker.Register(contentLbl, "TextColor3", "SubText")

            local reg = registerElement(title, "Paragraph", frame)
            local obj = { Kind = "Paragraph" }
            attachBaseObject(obj, frame, reg)
            function obj:SetTitle(t)   titleLbl.Text = t end
            function obj:SetContent(t) contentLbl.Text = t end
            return obj
        end

        -- ═══════════════════════════════
        -- BUTTON
        -- ═══════════════════════════════
        function Tab:CreateButton(bCfg)
            bCfg = bCfg or {}
            local name        = bCfg.Name        or "Button"
            local description = bCfg.Description
            local callback    = bCfg.Callback    or function() end

            local frame = Util.Create("TextButton", {
                Size = UDim2.new(1, 0, 0, description and 50 or 38),
                BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
                Text = "", AutoButtonColor = false,
                LayoutOrder = nextOrder(), ZIndex = 13, Parent = page,
            })
            Util.Corner(frame, 8)
            Util.Stroke(frame, Theme.Border, 1, 0.6)
            Util.Ripple(frame)
            tracker.Register(frame, "BackgroundColor3", "Card")

            local labelHeight = description and 18 or 36
            local nameLbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, -28, 0, labelHeight),
                Position = UDim2.new(0, 14, 0, description and 8 or 1),
                BackgroundTransparency = 1, Text = name,
                TextColor3 = Theme.Text, TextSize = 13, Font = Util.Font("semi"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 14, Parent = frame,
            })
            tracker.Register(nameLbl, "TextColor3", "Text")
            local descLbl
            if description then
                descLbl = Util.Create("TextLabel", {
                    Size = UDim2.new(1, -28, 0, 16),
                    Position = UDim2.new(0, 14, 0, 26),
                    BackgroundTransparency = 1, Text = description,
                    TextColor3 = Theme.DimText, TextSize = 11, Font = Util.Font("regular"),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 14, Parent = frame,
                })
                tracker.Register(descLbl, "TextColor3", "DimText")
            end
            Util.Create("TextLabel", {
                Size = UDim2.new(0, 14, 0, 14),
                Position = UDim2.new(1, -18, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                Text = Icons.arrow_right, TextColor3 = Theme.SubText,
                TextSize = 14, Font = Util.Font("bold"),
                ZIndex = 14, Parent = frame,
            })

            local disabled = false
            frame.MouseEnter:Connect(function()
                if not disabled then Util.Tween(frame, { BackgroundColor3 = Theme.CardHover }, 0.15) end
            end)
            frame.MouseLeave:Connect(function()
                if not disabled then Util.Tween(frame, { BackgroundColor3 = Theme.Card }, 0.15) end
            end)
            frame.MouseButton1Click:Connect(function()
                if disabled then return end
                Window._PlaySound("click")
                pcall(callback)
            end)

            local reg = registerElement(name, "Button", frame)
            local obj = { Kind = "Button" }
            attachBaseObject(obj, frame, reg)
            function obj:SetName(t) nameLbl.Text = t end
            function obj:SetCallback(fn) callback = fn end
            function obj:SetDescription(t)
                if descLbl then descLbl.Text = t end
            end
            function obj:Fire() pcall(callback) end
            function obj:SetDisabled(d)
                disabled = d
                Util.Tween(frame, { BackgroundTransparency = d and 0.5 or 0 }, 0.2)
            end
            return obj
        end

        -- ═══════════════════════════════
        -- TOGGLE (with optional keybind via cfg.KeyBind / cfg.Modifiers / cfg.KeyBindMode)
        -- ═══════════════════════════════
        function Tab:CreateToggle(tCfg)
            tCfg = tCfg or {}
            local name        = tCfg.Name        or "Toggle"
            local description = tCfg.Description
            local default     = tCfg.Default     or false
            local callback    = tCfg.Callback    or function() end
            local flag        = tCfg.Flag

            local frame = Util.Create("TextButton", {
                Size = UDim2.new(1, 0, 0, description and 50 or 38),
                BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
                Text = "", AutoButtonColor = false,
                LayoutOrder = nextOrder(), ZIndex = 13, Parent = page,
            })
            Util.Corner(frame, 8)
            Util.Stroke(frame, Theme.Border, 1, 0.6)
            tracker.Register(frame, "BackgroundColor3", "Card")

            local nameLbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, -120, 0, description and 18 or 36),
                Position = UDim2.new(0, 14, 0, description and 8 or 1),
                BackgroundTransparency = 1, Text = name,
                TextColor3 = Theme.Text, TextSize = 13, Font = Util.Font("semi"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 14, Parent = frame,
            })
            tracker.Register(nameLbl, "TextColor3", "Text")
            local descLbl
            if description then
                descLbl = Util.Create("TextLabel", {
                    Size = UDim2.new(1, -120, 0, 16),
                    Position = UDim2.new(0, 14, 0, 26),
                    BackgroundTransparency = 1, Text = description,
                    TextColor3 = Theme.DimText, TextSize = 11, Font = Util.Font("regular"),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 14, Parent = frame,
                })
                tracker.Register(descLbl, "TextColor3", "DimText")
            end

            local switch = Util.Create("Frame", {
                Size = UDim2.new(0, 40, 0, 22),
                Position = UDim2.new(1, -54, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = Theme.ToggleOff,
                BorderSizePixel = 0, ZIndex = 14, Parent = frame,
            })
            Util.Corner(switch, 999)
            local knob = Util.Create("Frame", {
                Size = UDim2.new(0, 16, 0, 16),
                Position = UDim2.new(0, 3, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0, ZIndex = 15, Parent = switch,
            })
            Util.Corner(knob, 999)
            local glow = Util.Create("ImageLabel", {
                Size = UDim2.new(0, 30, 0, 30),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Image = "rbxassetid://6014261993",
                ImageColor3 = Theme.ToggleOn,
                ImageTransparency = 1,
                ScaleType = Enum.ScaleType.Slice,
                SliceCenter = Rect.new(49, 49, 450, 450),
                ZIndex = 14, Parent = switch,
            })

            -- Optional keybind badge (shows current key)
            local kbBadge, kbBadgeLbl
            if tCfg.KeyBind or tCfg.AllowKeybind then
                kbBadge = Util.Create("TextButton", {
                    Size = UDim2.new(0, 50, 0, 20),
                    Position = UDim2.new(1, -106, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
                    Text = "", AutoButtonColor = false,
                    ZIndex = 14, Parent = frame,
                })
                Util.Corner(kbBadge, 4)
                tracker.Register(kbBadge, "BackgroundColor3", "Tertiary")
                kbBadgeLbl = Util.Create("TextLabel", {
                    Size = UDim2.new(1, -4, 1, 0), Position = UDim2.new(0, 2, 0, 0),
                    BackgroundTransparency = 1,
                    Text = tCfg.KeyBind and keyDisplayName(tCfg.KeyBind) or "[+]",
                    TextColor3 = Theme.SubText,
                    TextSize = 10, Font = Util.Font("bold"),
                    ZIndex = 15, Parent = kbBadge,
                })
                tracker.Register(kbBadgeLbl, "TextColor3", "SubText")
            end

            local state = default
            local function apply(animated)
                local d = animated == false and 0 or 0.18
                if state then
                    Util.Tween(switch, { BackgroundColor3 = Theme.ToggleOn }, d)
                    Util.Tween(knob,   { Position = UDim2.new(1, -19, 0.5, 0) }, d)
                    Util.Tween(glow,   { ImageTransparency = 0.55, Size = UDim2.new(0, 46, 0, 46) }, d)
                else
                    Util.Tween(switch, { BackgroundColor3 = Theme.ToggleOff }, d)
                    Util.Tween(knob,   { Position = UDim2.new(0, 3, 0.5, 0) }, d)
                    Util.Tween(glow,   { ImageTransparency = 1, Size = UDim2.new(0, 30, 0, 30) }, d)
                end
            end
            apply(false)

            local function setState(newState, fireCallback)
                if newState == state then return end
                state = newState
                apply(true)
                if fireCallback ~= false then
                    pcall(callback, state)
                    if flag then Window.Signals.FlagChanged:Fire(flag, state) end
                end
                if cfg.AutoSave then pcall(function() Window:SaveConfig(cfg.AutoSave) end) end
            end

            frame.MouseButton1Click:Connect(function()
                Window._PlaySound("toggle")
                setState(not state, true)
            end)
            frame.MouseEnter:Connect(function() Util.Tween(frame, { BackgroundColor3 = Theme.CardHover }, 0.15) end)
            frame.MouseLeave:Connect(function() Util.Tween(frame, { BackgroundColor3 = Theme.Card }, 0.15) end)

            -- Keybind handling
            local currentKey, currentMods, currentMode
            local unbindKey
            local function rebindKey(spec)
                if unbindKey then unbindKey(); unbindKey = nil end
                if not spec or not spec.Key then return end
                currentKey, currentMods, currentMode = spec.Key, spec.Modifiers, spec.Mode or "Toggle"
                unbindKey = registerKeybind(spec, function(held)
                    if currentMode == "Hold" then
                        setState(held == true, true)
                    else
                        setState(not state, true)
                    end
                end)
                if kbBadgeLbl then
                    local label = keyDisplayName(spec.Key)
                    if spec.Modifiers and #spec.Modifiers > 0 then
                        label = table.concat(spec.Modifiers, "+") .. "+" .. label
                    end
                    kbBadgeLbl.Text = label
                end
            end
            if tCfg.KeyBind then
                rebindKey({ Key = tCfg.KeyBind, Modifiers = tCfg.KeyBindModifiers, Mode = tCfg.KeyBindMode })
            end
            if kbBadge then
                kbBadge.MouseButton1Click:Connect(function()
                    kbBadgeLbl.Text = "..."
                    keybindListening = { resolve = function(spec)
                        rebindKey(spec)
                        if flag and Window.Flags[flag .. "_keybind"] then
                            Window.Signals.FlagChanged:Fire(flag .. "_keybind", spec)
                        end
                    end }
                end)
            end

            -- Tooltip: ensure description is shown if no tooltip set
            local reg = registerElement(name, "Toggle", frame)
            local obj = { Kind = "Toggle" }
            attachBaseObject(obj, frame, reg)

            function obj:Set(v)
                setState(v == true, true)
                if self._onChanged then pcall(self._onChanged, state) end
            end
            function obj:Get() return state end
            function obj:SetSilent(v) setState(v == true, false) end
            function obj:SetName(n) nameLbl.Text = n end
            function obj:SetDescription(t) if descLbl then descLbl.Text = t end end
            function obj:OnChanged(fn) self._onChanged = fn end
            function obj:SetKeybind(spec) rebindKey(spec) end

            if flag then
                Window.Flags[flag] = {
                    type = "toggle",
                    get = function() return state end,
                    set = function(v) setState(v == true, true) end,
                    element = obj,
                }
                if kbBadge then
                    Window.Flags[flag .. "_keybind"] = {
                        type = "keybind",
                        get = function() return { Key = currentKey, Modifiers = currentMods, Mode = currentMode } end,
                        set = function(spec) rebindKey(spec) end,
                        element = obj,
                    }
                end
            end

            if default then pcall(callback, true) end
            return obj
        end

        -- ═══════════════════════════════
        -- SLIDER  (single value)
        -- ═══════════════════════════════
        function Tab:CreateSlider(sCfg)
            sCfg = sCfg or {}
            local name        = sCfg.Name        or "Slider"
            local description = sCfg.Description
            local mn          = sCfg.Min         or 0
            local mx          = sCfg.Max         or 100
            local default     = Util.Clamp(sCfg.Default or mn, mn, mx)
            local increment   = sCfg.Increment   or 1
            local decimals    = sCfg.Decimals    or 0
            local suffix      = sCfg.Suffix      or ""
            local callback    = sCfg.Callback    or function() end
            local flag        = sCfg.Flag

            local frame = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, description and 70 or 58),
                BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
                LayoutOrder = nextOrder(), ZIndex = 13, Parent = page,
            })
            Util.Corner(frame, 8)
            Util.Stroke(frame, Theme.Border, 1, 0.6)
            tracker.Register(frame, "BackgroundColor3", "Card")

            local nameLbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, -100, 0, 18),
                Position = UDim2.new(0, 14, 0, 8),
                BackgroundTransparency = 1, Text = name,
                TextColor3 = Theme.Text, TextSize = 13, Font = Util.Font("semi"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 14, Parent = frame,
            })
            tracker.Register(nameLbl, "TextColor3", "Text")
            local descLbl
            if description then
                descLbl = Util.Create("TextLabel", {
                    Size = UDim2.new(1, -100, 0, 14),
                    Position = UDim2.new(0, 14, 0, 26),
                    BackgroundTransparency = 1, Text = description,
                    TextColor3 = Theme.DimText, TextSize = 11, Font = Util.Font("regular"),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 14, Parent = frame,
                })
                tracker.Register(descLbl, "TextColor3", "DimText")
            end

            local valueLbl = Util.Create("TextLabel", {
                Size = UDim2.new(0, 84, 0, 20),
                Position = UDim2.new(1, -14, 0, 8),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
                Text = tostring(default) .. suffix,
                TextColor3 = Theme.Accent, TextSize = 12, Font = Util.Font("bold"),
                ZIndex = 14, Parent = frame,
            })
            Util.Corner(valueLbl, 4)
            tracker.Register(valueLbl, "BackgroundColor3", "Tertiary")
            tracker.Register(valueLbl, "TextColor3", "Accent")

            local trackY = description and 56 or 42
            local barBG = Util.Create("Frame", {
                Size = UDim2.new(1, -28, 0, 5),
                Position = UDim2.new(0, 14, 0, trackY),
                BackgroundColor3 = Theme.SliderBG,
                BorderSizePixel = 0, ZIndex = 14, Parent = frame,
            })
            Util.Corner(barBG, 999)
            tracker.Register(barBG, "BackgroundColor3", "SliderBG")
            local fill = Util.Create("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = Theme.SliderFill, BorderSizePixel = 0,
                ZIndex = 15, Parent = barBG,
            })
            Util.Corner(fill, 999)
            tracker.Register(fill, "BackgroundColor3", "SliderFill")
            local knob = Util.Create("Frame", {
                Size = UDim2.new(0, 14, 0, 14),
                Position = UDim2.new(0, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Theme.AccentLight, BorderSizePixel = 0,
                ZIndex = 16, Parent = barBG,
            })
            Util.Corner(knob, 999)
            Util.Stroke(knob, Theme.Background, 2, 0)
            tracker.Register(knob, "BackgroundColor3", "AccentLight")

            -- floating hint over knob during drag
            local hint = Util.Create("TextLabel", {
                Size = UDim2.new(0, 60, 0, 22),
                Position = UDim2.new(0, 0, 0, -28),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Theme.Tertiary,
                BackgroundTransparency = 1,
                Text = "", TextColor3 = Theme.Text,
                TextSize = 11, Font = Util.Font("bold"),
                TextTransparency = 1,
                ZIndex = 17, Parent = knob,
            })
            Util.Corner(hint, 4)
            Util.Padding(hint, 2, 2, 4, 4)
            tracker.Register(hint, "BackgroundColor3", "Tertiary")
            tracker.Register(hint, "TextColor3", "Text")

            local function formatValue(v) return string.format("%." .. decimals .. "f", v) .. suffix end

            local value = default
            local function applyVisual(animated)
                local pct = (value - mn) / (mx - mn)
                if pct ~= pct then pct = 0 end
                pct = Util.Clamp(pct, 0, 1)
                if animated then
                    Util.Tween(fill, { Size = UDim2.new(pct, 0, 1, 0) }, 0.18)
                    Util.Tween(knob, { Position = UDim2.new(pct, 0, 0.5, 0) }, 0.18)
                else
                    fill.Size = UDim2.new(pct, 0, 1, 0)
                    knob.Position = UDim2.new(pct, 0, 0.5, 0)
                end
                valueLbl.Text = formatValue(value)
                hint.Text = formatValue(value)
            end
            applyVisual(false)

            local function setValue(v, fire)
                v = Util.Round(Util.Clamp(v, mn, mx) / increment) * increment
                v = Util.Round(v, decimals)
                if v == value then return end
                value = v
                applyVisual(false)
                if fire ~= false then pcall(callback, v) end
                if cfg.AutoSave then pcall(function() Window:SaveConfig(cfg.AutoSave) end) end
            end

            barBG.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
                Util.Tween(hint, { TextTransparency = 0, BackgroundTransparency = 0 }, 0.15)
                activeDragHandler = {
                    onMove = function(pos)
                        local rel = (pos.X - barBG.AbsolutePosition.X) / barBG.AbsoluteSize.X
                        rel = Util.Clamp(rel, 0, 1)
                        setValue(mn + (mx - mn) * rel, true)
                    end,
                    onRelease = function()
                        Util.Tween(hint, { TextTransparency = 1, BackgroundTransparency = 1 }, 0.15)
                    end,
                }
                -- Update immediately for click without drag
                local rel = (input.Position.X - barBG.AbsolutePosition.X) / barBG.AbsoluteSize.X
                rel = Util.Clamp(rel, 0, 1)
                setValue(mn + (mx - mn) * rel, true)
            end)

            local reg = registerElement(name, "Slider", frame)
            local obj = { Kind = "Slider" }
            attachBaseObject(obj, frame, reg)

            function obj:Set(v) setValue(v, true) end
            function obj:SetSilent(v) setValue(v, false) end
            function obj:Get() return value end
            function obj:SetMin(m) mn = m; applyVisual(false) end
            function obj:SetMax(m) mx = m; applyVisual(false) end
            function obj:SetName(n) nameLbl.Text = n end

            if flag then
                Window.Flags[flag] = {
                    type = "slider",
                    get = function() return value end,
                    set = function(v) setValue(v, true) end,
                    element = obj,
                }
            end

            pcall(callback, default)  -- always fire initial value
            return obj
        end

        -- ═══════════════════════════════
        -- RANGE SLIDER (two handles)
        -- ═══════════════════════════════
        function Tab:CreateRangeSlider(sCfg)
            sCfg = sCfg or {}
            local name        = sCfg.Name        or "Range"
            local description = sCfg.Description
            local mn          = sCfg.Min         or 0
            local mx          = sCfg.Max         or 100
            local defLow      = sCfg.DefaultMin  or mn
            local defHigh     = sCfg.DefaultMax  or mx
            local increment   = sCfg.Increment   or 1
            local decimals    = sCfg.Decimals    or 0
            local suffix      = sCfg.Suffix      or ""
            local callback    = sCfg.Callback    or function() end
            local flag        = sCfg.Flag

            local frame = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, description and 70 or 58),
                BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
                LayoutOrder = nextOrder(), ZIndex = 13, Parent = page,
            })
            Util.Corner(frame, 8)
            Util.Stroke(frame, Theme.Border, 1, 0.6)
            tracker.Register(frame, "BackgroundColor3", "Card")

            local nameLbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, -150, 0, 18),
                Position = UDim2.new(0, 14, 0, 8),
                BackgroundTransparency = 1, Text = name,
                TextColor3 = Theme.Text, TextSize = 13, Font = Util.Font("semi"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 14, Parent = frame,
            })
            tracker.Register(nameLbl, "TextColor3", "Text")
            if description then
                local descLbl = Util.Create("TextLabel", {
                    Size = UDim2.new(1, -150, 0, 14),
                    Position = UDim2.new(0, 14, 0, 26),
                    BackgroundTransparency = 1, Text = description,
                    TextColor3 = Theme.DimText, TextSize = 11, Font = Util.Font("regular"),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 14, Parent = frame,
                })
                tracker.Register(descLbl, "TextColor3", "DimText")
            end
            local valueLbl = Util.Create("TextLabel", {
                Size = UDim2.new(0, 134, 0, 20),
                Position = UDim2.new(1, -14, 0, 8),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
                Text = string.format("%d - %d%s", defLow, defHigh, suffix),
                TextColor3 = Theme.Accent, TextSize = 12, Font = Util.Font("bold"),
                ZIndex = 14, Parent = frame,
            })
            Util.Corner(valueLbl, 4)
            tracker.Register(valueLbl, "BackgroundColor3", "Tertiary")
            tracker.Register(valueLbl, "TextColor3", "Accent")

            local trackY = description and 56 or 42
            local barBG = Util.Create("Frame", {
                Size = UDim2.new(1, -28, 0, 5),
                Position = UDim2.new(0, 14, 0, trackY),
                BackgroundColor3 = Theme.SliderBG,
                BorderSizePixel = 0, ZIndex = 14, Parent = frame,
            })
            Util.Corner(barBG, 999)
            tracker.Register(barBG, "BackgroundColor3", "SliderBG")
            local fill = Util.Create("Frame", {
                BackgroundColor3 = Theme.SliderFill, BorderSizePixel = 0,
                ZIndex = 15, Parent = barBG,
            })
            Util.Corner(fill, 999)
            tracker.Register(fill, "BackgroundColor3", "SliderFill")

            local function makeKnob()
                local k = Util.Create("Frame", {
                    Size = UDim2.new(0, 14, 0, 14),
                    Position = UDim2.new(0, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Theme.AccentLight, BorderSizePixel = 0,
                    ZIndex = 16, Parent = barBG,
                })
                Util.Corner(k, 999)
                Util.Stroke(k, Theme.Background, 2, 0)
                tracker.Register(k, "BackgroundColor3", "AccentLight")
                return k
            end
            local lowKnob  = makeKnob()
            local highKnob = makeKnob()

            local low, high = defLow, defHigh

            local function format(v) return string.format("%." .. decimals .. "f", v) end
            local function apply()
                local pl = (low - mn) / (mx - mn)
                local ph = (high - mn) / (mx - mn)
                pl = Util.Clamp(pl, 0, 1); ph = Util.Clamp(ph, 0, 1)
                lowKnob.Position  = UDim2.new(pl, 0, 0.5, 0)
                highKnob.Position = UDim2.new(ph, 0, 0.5, 0)
                fill.Position = UDim2.new(pl, 0, 0, 0)
                fill.Size     = UDim2.new(ph - pl, 0, 1, 0)
                valueLbl.Text = format(low) .. " - " .. format(high) .. suffix
            end
            apply()

            local function setRange(l, h, fire)
                l = Util.Round(Util.Clamp(l, mn, mx) / increment) * increment
                h = Util.Round(Util.Clamp(h, mn, mx) / increment) * increment
                if l > h then l, h = h, l end
                if l == low and h == high then return end
                low, high = l, h
                apply()
                if fire ~= false then pcall(callback, low, high) end
            end

            local function startDrag(which)
                activeDragHandler = {
                    onMove = function(pos)
                        local rel = (pos.X - barBG.AbsolutePosition.X) / barBG.AbsoluteSize.X
                        rel = Util.Clamp(rel, 0, 1)
                        local v = mn + (mx - mn) * rel
                        if which == "low" then
                            setRange(v, high, true)
                        else
                            setRange(low, v, true)
                        end
                    end,
                }
            end
            lowKnob.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then startDrag("low") end
            end)
            highKnob.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then startDrag("high") end
            end)
            -- Also allow clicking on the bar (closest knob wins)
            barBG.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
                local rel = (input.Position.X - barBG.AbsolutePosition.X) / barBG.AbsoluteSize.X
                rel = Util.Clamp(rel, 0, 1)
                local v = mn + (mx - mn) * rel
                if math.abs(v - low) < math.abs(v - high) then
                    setRange(v, high, true); startDrag("low")
                else
                    setRange(low, v, true);  startDrag("high")
                end
            end)

            local reg = registerElement(name, "RangeSlider", frame)
            local obj = { Kind = "RangeSlider" }
            attachBaseObject(obj, frame, reg)
            function obj:Set(l, h) setRange(l, h, true) end
            function obj:Get() return low, high end
            function obj:SetName(n) nameLbl.Text = n end

            if flag then
                Window.Flags[flag] = {
                    type = "range",
                    get = function() return { low, high } end,
                    set = function(v) setRange(v[1] or mn, v[2] or mx, true) end,
                    element = obj,
                }
            end
            pcall(callback, defLow, defHigh)
            return obj
        end

        -- ═══════════════════════════════
        -- STEPPER (number with +/- buttons)
        -- ═══════════════════════════════
        function Tab:CreateStepper(sCfg)
            sCfg = sCfg or {}
            local name        = sCfg.Name        or "Stepper"
            local description = sCfg.Description
            local mn          = sCfg.Min         or 0
            local mx          = sCfg.Max         or 100
            local step        = sCfg.Step        or 1
            local decimals    = sCfg.Decimals    or 0
            local default     = Util.Clamp(sCfg.Default or mn, mn, mx)
            local callback    = sCfg.Callback    or function() end
            local flag        = sCfg.Flag

            local frame = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, description and 50 or 38),
                BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
                LayoutOrder = nextOrder(), ZIndex = 13, Parent = page,
            })
            Util.Corner(frame, 8)
            Util.Stroke(frame, Theme.Border, 1, 0.6)
            tracker.Register(frame, "BackgroundColor3", "Card")

            local nameLbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, -140, 0, description and 18 or 36),
                Position = UDim2.new(0, 14, 0, description and 8 or 1),
                BackgroundTransparency = 1, Text = name,
                TextColor3 = Theme.Text, TextSize = 13, Font = Util.Font("semi"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 14, Parent = frame,
            })
            tracker.Register(nameLbl, "TextColor3", "Text")
            if description then
                local d = Util.Create("TextLabel", {
                    Size = UDim2.new(1, -140, 0, 16),
                    Position = UDim2.new(0, 14, 0, 26),
                    BackgroundTransparency = 1, Text = description,
                    TextColor3 = Theme.DimText, TextSize = 11, Font = Util.Font("regular"),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 14, Parent = frame,
                })
                tracker.Register(d, "TextColor3", "DimText")
            end

            local value = default
            local function format(v) return string.format("%." .. decimals .. "f", v) end

            local valueBox = Util.Create("TextBox", {
                Size = UDim2.new(0, 60, 0, 24),
                Position = UDim2.new(1, -50, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
                Text = format(value), TextColor3 = Theme.Text,
                TextSize = 12, Font = Util.Font("bold"),
                ClearTextOnFocus = false,
                ZIndex = 14, Parent = frame,
            })
            Util.Corner(valueBox, 4)
            tracker.Register(valueBox, "BackgroundColor3", "Tertiary")
            tracker.Register(valueBox, "TextColor3", "Text")

            local function makeButton(text, posX)
                local b = Util.Create("TextButton", {
                    Size = UDim2.new(0, 24, 0, 24),
                    Position = UDim2.new(1, posX, 0.5, 0),
                    AnchorPoint = Vector2.new(1, 0.5),
                    BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
                    Text = text, TextColor3 = Theme.Text,
                    TextSize = 14, Font = Util.Font("bold"),
                    AutoButtonColor = false,
                    ZIndex = 14, Parent = frame,
                })
                Util.Corner(b, 4)
                tracker.Register(b, "BackgroundColor3", "Tertiary")
                tracker.Register(b, "TextColor3", "Text")
                b.MouseEnter:Connect(function() Util.Tween(b, { BackgroundColor3 = Theme.Hover }, 0.15) end)
                b.MouseLeave:Connect(function() Util.Tween(b, { BackgroundColor3 = Theme.Tertiary }, 0.15) end)
                return b
            end
            local btnMinus = makeButton(Icons.minus, -114)
            local btnPlus  = makeButton(Icons.plus,  -16)

            local function setValue(v, fire)
                v = Util.Clamp(v, mn, mx)
                v = Util.Round(v / step) * step
                v = Util.Round(v, decimals)
                if v == value then return end
                value = v
                valueBox.Text = format(value)
                if fire ~= false then pcall(callback, value) end
            end

            btnMinus.MouseButton1Click:Connect(function() setValue(value - step, true) end)
            btnPlus.MouseButton1Click :Connect(function() setValue(value + step, true) end)
            valueBox.FocusLost:Connect(function()
                local num = tonumber(valueBox.Text)
                if num then setValue(num, true) else valueBox.Text = format(value) end
            end)

            local reg = registerElement(name, "Stepper", frame)
            local obj = { Kind = "Stepper" }
            attachBaseObject(obj, frame, reg)
            function obj:Set(v) setValue(v, true) end
            function obj:Get() return value end
            function obj:SetName(n) nameLbl.Text = n end
            if flag then
                Window.Flags[flag] = { type = "number",
                    get = function() return value end,
                    set = function(v) setValue(v, true) end, element = obj }
            end
            pcall(callback, default)
            return obj
        end

        -- ═══════════════════════════════
        -- PROGRESS BAR
        -- ═══════════════════════════════
        function Tab:CreateProgressBar(pCfg)
            pCfg = pCfg or {}
            local name = pCfg.Name or "Progress"
            local default = Util.Clamp(pCfg.Default or 0, 0, 1)

            local frame = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 44),
                BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
                LayoutOrder = nextOrder(), ZIndex = 13, Parent = page,
            })
            Util.Corner(frame, 8)
            Util.Stroke(frame, Theme.Border, 1, 0.6)
            tracker.Register(frame, "BackgroundColor3", "Card")

            local nameLbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, -70, 0, 18),
                Position = UDim2.new(0, 14, 0, 6),
                BackgroundTransparency = 1, Text = name,
                TextColor3 = Theme.Text, TextSize = 12, Font = Util.Font("semi"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 14, Parent = frame,
            })
            tracker.Register(nameLbl, "TextColor3", "Text")
            local pctLbl = Util.Create("TextLabel", {
                Size = UDim2.new(0, 60, 0, 18),
                Position = UDim2.new(1, -14, 0, 6),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundTransparency = 1,
                Text = math.floor(default * 100) .. "%",
                TextColor3 = Theme.Accent, TextSize = 12, Font = Util.Font("bold"),
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 14, Parent = frame,
            })
            tracker.Register(pctLbl, "TextColor3", "Accent")

            local barBG = Util.Create("Frame", {
                Size = UDim2.new(1, -28, 0, 8),
                Position = UDim2.new(0, 14, 1, -16),
                BackgroundColor3 = Theme.SliderBG, BorderSizePixel = 0,
                ZIndex = 14, Parent = frame,
            })
            Util.Corner(barBG, 999)
            tracker.Register(barBG, "BackgroundColor3", "SliderBG")
            local fill = Util.Create("Frame", {
                Size = UDim2.new(default, 0, 1, 0),
                BackgroundColor3 = Theme.SliderFill, BorderSizePixel = 0,
                ZIndex = 15, Parent = barBG,
            })
            Util.Corner(fill, 999)
            tracker.Register(fill, "BackgroundColor3", "SliderFill")

            local progress = default
            local reg = registerElement(name, "ProgressBar", frame)
            local obj = { Kind = "ProgressBar" }
            attachBaseObject(obj, frame, reg)
            function obj:Set(p)
                progress = Util.Clamp(p, 0, 1)
                Util.Tween(fill, { Size = UDim2.new(progress, 0, 1, 0) }, 0.3)
                pctLbl.Text = math.floor(progress * 100) .. "%"
            end
            function obj:Get() return progress end
            function obj:SetName(n) nameLbl.Text = n end
            return obj
        end

        -- ═══════════════════════════════
        -- TAG ROW (small chips/badges)
        -- ═══════════════════════════════
        function Tab:CreateTagList(tCfg)
            tCfg = tCfg or {}
            local name = tCfg.Name or "Tags"
            local tags = tCfg.Tags or {}

            local frame = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
                LayoutOrder = nextOrder(), ZIndex = 13, Parent = page,
            })
            Util.Corner(frame, 8)
            Util.Stroke(frame, Theme.Border, 1, 0.6)
            Util.Padding(frame, 8, 8, 12, 12)
            Util.ListLayout(frame, Enum.FillDirection.Vertical, 6)
            tracker.Register(frame, "BackgroundColor3", "Card")

            Util.Create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1, Text = name,
                TextColor3 = Theme.SubText, TextSize = 11, Font = Util.Font("bold"),
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1, ZIndex = 14, Parent = frame,
            })

            local row = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                LayoutOrder = 2, ZIndex = 14, Parent = frame,
            })
            local rowLayout = Instance.new("UIListLayout")
            rowLayout.FillDirection = Enum.FillDirection.Horizontal
            rowLayout.Padding = UDim.new(0, 4)
            rowLayout.Wraps = true
            rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
            rowLayout.Parent = row
            local rowSizer = Instance.new("UISizeConstraint")
            rowSizer.Parent = row

            local function addTag(tagText, color)
                local t = Util.Create("Frame", {
                    Size = UDim2.new(0, 0, 0, 22),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundColor3 = color or Theme.Tertiary, BorderSizePixel = 0,
                    ZIndex = 15, Parent = row,
                })
                Util.Corner(t, 4)
                Util.Padding(t, 0, 0, 8, 8)
                Util.Create("TextLabel", {
                    Size = UDim2.new(0, 0, 1, 0),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundTransparency = 1,
                    Text = tagText, TextColor3 = Theme.Text,
                    TextSize = 11, Font = Util.Font("semi"),
                    ZIndex = 16, Parent = t,
                })
            end
            for _, t in ipairs(tags) do
                if type(t) == "string" then addTag(t)
                elseif type(t) == "table" then addTag(t.Text, t.Color) end
            end

            local reg = registerElement(name, "TagList", frame)
            local obj = { Kind = "TagList" }
            attachBaseObject(obj, frame, reg)
            function obj:AddTag(text, color) addTag(text, color) end
            function obj:Clear()
                for _, c in ipairs(row:GetChildren()) do
                    if c:IsA("Frame") then c:Destroy() end
                end
            end
            return obj
        end

        -- ═══════════════════════════════
        -- RADIO GROUP / SEGMENTED
        -- ═══════════════════════════════
        function Tab:CreateRadioGroup(rCfg)
            rCfg = rCfg or {}
            local name        = rCfg.Name        or "Choose"
            local description = rCfg.Description
            local options     = rCfg.Options     or {}
            local default     = rCfg.Default     or options[1]
            local callback    = rCfg.Callback    or function() end
            local flag        = rCfg.Flag

            local frame = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
                LayoutOrder = nextOrder(), ZIndex = 13, Parent = page,
            })
            Util.Corner(frame, 8)
            Util.Stroke(frame, Theme.Border, 1, 0.6)
            Util.Padding(frame, 10, 10, 14, 14)
            Util.ListLayout(frame, Enum.FillDirection.Vertical, 6)
            tracker.Register(frame, "BackgroundColor3", "Card")

            local nameLbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1, Text = name,
                TextColor3 = Theme.Text, TextSize = 13, Font = Util.Font("semi"),
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1, ZIndex = 14, Parent = frame,
            })
            tracker.Register(nameLbl, "TextColor3", "Text")
            if description then
                local d = Util.Create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 14),
                    BackgroundTransparency = 1, Text = description,
                    TextColor3 = Theme.DimText, TextSize = 11, Font = Util.Font("regular"),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    LayoutOrder = 2, ZIndex = 14, Parent = frame,
                })
                tracker.Register(d, "TextColor3", "DimText")
            end

            local optionFrames = {}
            local current = default
            local function applySelection()
                for opt, parts in pairs(optionFrames) do
                    if opt == current then
                        Util.Tween(parts.outer, { BackgroundColor3 = Theme.Accent }, 0.15)
                        Util.Tween(parts.inner, { BackgroundTransparency = 0 }, 0.15)
                    else
                        Util.Tween(parts.outer, { BackgroundColor3 = Theme.ToggleOff }, 0.15)
                        Util.Tween(parts.inner, { BackgroundTransparency = 1 }, 0.15)
                    end
                end
            end

            for i, opt in ipairs(options) do
                local row = Util.Create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundTransparency = 1, BorderSizePixel = 0,
                    Text = "", AutoButtonColor = false,
                    LayoutOrder = 10 + i, ZIndex = 14, Parent = frame,
                })
                local outer = Util.Create("Frame", {
                    Size = UDim2.new(0, 16, 0, 16),
                    Position = UDim2.new(0, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0, 0.5),
                    BackgroundColor3 = Theme.ToggleOff, BorderSizePixel = 0,
                    ZIndex = 15, Parent = row,
                })
                Util.Corner(outer, 999)
                local inner = Util.Create("Frame", {
                    Size = UDim2.new(0, 8, 0, 8),
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
                    BackgroundTransparency = 1, ZIndex = 16, Parent = outer,
                })
                Util.Corner(inner, 999)
                local lbl = Util.Create("TextLabel", {
                    Size = UDim2.new(1, -28, 1, 0),
                    Position = UDim2.new(0, 24, 0, 0),
                    BackgroundTransparency = 1, Text = tostring(opt),
                    TextColor3 = Theme.Text, TextSize = 12, Font = Util.Font("regular"),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 15, Parent = row,
                })
                tracker.Register(lbl, "TextColor3", "Text")
                optionFrames[opt] = { outer = outer, inner = inner, label = lbl }
                row.MouseButton1Click:Connect(function()
                    if current == opt then return end
                    current = opt
                    applySelection()
                    pcall(callback, opt)
                end)
            end
            applySelection()

            local reg = registerElement(name, "RadioGroup", frame)
            local obj = { Kind = "RadioGroup" }
            attachBaseObject(obj, frame, reg)
            function obj:Set(v) if optionFrames[v] then current = v; applySelection(); pcall(callback, v) end end
            function obj:Get() return current end
            function obj:SetName(n) nameLbl.Text = n end
            if flag then
                Window.Flags[flag] = { type = "string",
                    get = function() return current end,
                    set = function(v) if optionFrames[v] then current = v; applySelection(); pcall(callback, v) end end,
                    element = obj }
            end
            if default then pcall(callback, default) end
            return obj
        end

        function Tab:CreateSegmented(sCfg)
            sCfg = sCfg or {}
            local name = sCfg.Name or "Segmented"
            local options = sCfg.Options or {}
            local default = sCfg.Default or options[1]
            local callback = sCfg.Callback or function() end
            local flag = sCfg.Flag

            local frame = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 50),
                BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
                LayoutOrder = nextOrder(), ZIndex = 13, Parent = page,
            })
            Util.Corner(frame, 8)
            Util.Stroke(frame, Theme.Border, 1, 0.6)
            tracker.Register(frame, "BackgroundColor3", "Card")

            local nameLbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, -14, 0, 14),
                Position = UDim2.new(0, 14, 0, 6),
                BackgroundTransparency = 1, Text = name,
                TextColor3 = Theme.SubText, TextSize = 11, Font = Util.Font("bold"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 14, Parent = frame,
            })
            tracker.Register(nameLbl, "TextColor3", "SubText")

            local row = Util.Create("Frame", {
                Size = UDim2.new(1, -28, 0, 26),
                Position = UDim2.new(0, 14, 0, 22),
                BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
                ZIndex = 14, Parent = frame,
            })
            Util.Corner(row, 6)
            tracker.Register(row, "BackgroundColor3", "Tertiary")

            local segLayout = Util.ListLayout(row, Enum.FillDirection.Horizontal, 0,
                Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

            local current = default
            local buttons = {}
            local function refresh()
                for opt, b in pairs(buttons) do
                    if opt == current then
                        Util.Tween(b.bg, { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0 }, 0.15)
                        Util.Tween(b.lbl, { TextColor3 = Color3.new(1, 1, 1) }, 0.15)
                    else
                        Util.Tween(b.bg, { BackgroundColor3 = Theme.Tertiary, BackgroundTransparency = 1 }, 0.15)
                        Util.Tween(b.lbl, { TextColor3 = Theme.SubText }, 0.15)
                    end
                end
            end

            for i, opt in ipairs(options) do
                local b = Util.Create("TextButton", {
                    Size = UDim2.new(1 / #options, 0, 1, 0),
                    BackgroundColor3 = Theme.Tertiary, BackgroundTransparency = 1,
                    BorderSizePixel = 0, Text = "", AutoButtonColor = false,
                    LayoutOrder = i, ZIndex = 15, Parent = row,
                })
                Util.Corner(b, 5)
                local lbl = Util.Create("TextLabel", {
                    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
                    Text = tostring(opt), TextColor3 = Theme.SubText,
                    TextSize = 12, Font = Util.Font("semi"),
                    ZIndex = 16, Parent = b,
                })
                buttons[opt] = { bg = b, lbl = lbl }
                b.MouseButton1Click:Connect(function()
                    if current == opt then return end
                    current = opt
                    refresh()
                    pcall(callback, opt)
                end)
            end
            refresh()

            local reg = registerElement(name, "Segmented", frame)
            local obj = { Kind = "Segmented" }
            attachBaseObject(obj, frame, reg)
            function obj:Set(v) if buttons[v] then current = v; refresh(); pcall(callback, v) end end
            function obj:Get() return current end
            function obj:SetName(n) nameLbl.Text = n end
            if flag then
                Window.Flags[flag] = { type = "string",
                    get = function() return current end,
                    set = function(v) obj:Set(v) end, element = obj }
            end
            if default then pcall(callback, default) end
            return obj
        end

        -- ═══════════════════════════════
        -- DROPDOWN  (single + multi + searchable)
        -- ═══════════════════════════════
        function Tab:CreateDropdown(dCfg)
            dCfg = dCfg or {}
            local closeMenu  -- forward decl for inner closures
            local name        = dCfg.Name        or "Dropdown"
            local description = dCfg.Description
            local options     = dCfg.Options     or {}
            local default     = dCfg.Default
            local multi       = dCfg.Multi       == true
            local searchable  = dCfg.Searchable  == true
            local callback    = dCfg.Callback    or function() end
            local flag        = dCfg.Flag

            local frame = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, description and 50 or 38),
                BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
                ClipsDescendants = false,
                LayoutOrder = nextOrder(), ZIndex = 13, Parent = page,
            })
            Util.Corner(frame, 8)
            Util.Stroke(frame, Theme.Border, 1, 0.6)
            tracker.Register(frame, "BackgroundColor3", "Card")

            local nameLbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, -160, 0, description and 18 or 36),
                Position = UDim2.new(0, 14, 0, description and 8 or 1),
                BackgroundTransparency = 1, Text = name,
                TextColor3 = Theme.Text, TextSize = 13, Font = Util.Font("semi"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 14, Parent = frame,
            })
            tracker.Register(nameLbl, "TextColor3", "Text")
            if description then
                local d = Util.Create("TextLabel", {
                    Size = UDim2.new(1, -160, 0, 16),
                    Position = UDim2.new(0, 14, 0, 26),
                    BackgroundTransparency = 1, Text = description,
                    TextColor3 = Theme.DimText, TextSize = 11, Font = Util.Font("regular"),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 14, Parent = frame,
                })
                tracker.Register(d, "TextColor3", "DimText")
            end

            local trigger = Util.Create("TextButton", {
                Size = UDim2.new(0, 140, 0, 26),
                Position = UDim2.new(1, -14, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
                Text = "", AutoButtonColor = false,
                ZIndex = 14, Parent = frame,
            })
            Util.Corner(trigger, 5)
            tracker.Register(trigger, "BackgroundColor3", "Tertiary")
            local valueLbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, -22, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1, Text = "—",
                TextColor3 = Theme.Text, TextSize = 11, Font = Util.Font("semi"),
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 15, Parent = trigger,
            })
            tracker.Register(valueLbl, "TextColor3", "Text")
            local arrowLbl = Util.Create("TextLabel", {
                Size = UDim2.new(0, 14, 0, 14),
                Position = UDim2.new(1, -6, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundTransparency = 1, Text = Icons.chevron_down,
                TextColor3 = Theme.SubText, TextSize = 12, Font = Util.Font("bold"),
                ZIndex = 15, Parent = trigger,
            })
            tracker.Register(arrowLbl, "TextColor3", "SubText")

            -- Dropdown menu (floating overlay)
            local menu = Util.Create("Frame", {
                Size = UDim2.new(0, 200, 0, 0),
                BackgroundColor3 = Theme.Secondary, BorderSizePixel = 0,
                ClipsDescendants = true, Visible = false,
                ZIndex = 700, Parent = ScreenGui,
            })
            Util.Corner(menu, 6)
            Util.Stroke(menu, Theme.BorderStrong, 1, 0.4)
            tracker.Register(menu, "BackgroundColor3", "Secondary")

            local searchBox
            if searchable then
                searchBox = Util.Create("TextBox", {
                    Size = UDim2.new(1, -16, 0, 24),
                    Position = UDim2.new(0, 8, 0, 8),
                    BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
                    PlaceholderText = "Search…", PlaceholderColor3 = Theme.DimText,
                    Text = "", TextColor3 = Theme.Text,
                    TextSize = 12, Font = Util.Font("regular"),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ClearTextOnFocus = false,
                    ZIndex = 701, Parent = menu,
                })
                Util.Corner(searchBox, 4)
                Util.Padding(searchBox, 0, 0, 8, 8)
                tracker.Register(searchBox, "BackgroundColor3", "Tertiary")
                tracker.Register(searchBox, "TextColor3", "Text")
            end

            local optScroll = Util.Create("ScrollingFrame", {
                Size = UDim2.new(1, -8, 1, searchable and -42 or -10),
                Position = UDim2.new(0, 4, 0, searchable and 38 or 6),
                BackgroundTransparency = 1,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = Theme.Accent,
                ZIndex = 701, Parent = menu,
            })
            Util.ListLayout(optScroll, Enum.FillDirection.Vertical, 2)
            Util.Padding(optScroll, 2, 2, 4, 4)

            local selectedSet = {}
            if default then
                if multi and type(default) == "table" then
                    for _, v in ipairs(default) do selectedSet[v] = true end
                else
                    selectedSet[default] = true
                end
            end

            local optionButtons = {}

            local function updateTriggerText()
                if multi then
                    local sels = {}
                    for k in pairs(selectedSet) do table.insert(sels, tostring(k)) end
                    if #sels == 0 then
                        valueLbl.Text = "—"
                    elseif #sels <= 2 then
                        valueLbl.Text = table.concat(sels, ", ")
                    else
                        valueLbl.Text = string.format("%d selected", #sels)
                    end
                else
                    for k in pairs(selectedSet) do
                        valueLbl.Text = tostring(k); return
                    end
                    valueLbl.Text = "—"
                end
            end
            updateTriggerText()

            local function fireCallback()
                if multi then
                    local arr = {}
                    for k in pairs(selectedSet) do table.insert(arr, k) end
                    pcall(callback, arr)
                else
                    for k in pairs(selectedSet) do pcall(callback, k); return end
                    pcall(callback, nil)
                end
            end

            local function refreshSelectedStyle()
                for opt, parts in pairs(optionButtons) do
                    if selectedSet[opt] then
                        Util.Tween(parts.row, { BackgroundColor3 = Theme.AccentDark }, 0.1)
                        parts.check.Visible = true
                    else
                        Util.Tween(parts.row, { BackgroundColor3 = Theme.Card }, 0.1)
                        parts.check.Visible = false
                    end
                end
            end

            local function rebuildOptionList(filter)
                filter = string.lower(filter or "")
                for _, c in ipairs(optScroll:GetChildren()) do
                    if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
                end
                optionButtons = {}
                for i, opt in ipairs(options) do
                    local optStr = tostring(opt)
                    if filter == "" or string.find(string.lower(optStr), filter, 1, true) then
                        local row = Util.Create("TextButton", {
                            Size = UDim2.new(1, 0, 0, 26),
                            BackgroundColor3 = selectedSet[opt] and Theme.AccentDark or Theme.Card,
                            BorderSizePixel = 0, Text = "", AutoButtonColor = false,
                            LayoutOrder = i, ZIndex = 702, Parent = optScroll,
                        })
                        Util.Corner(row, 4)
                        tracker.Register(row, "BackgroundColor3", "Card")
                        local lbl = Util.Create("TextLabel", {
                            Size = UDim2.new(1, -28, 1, 0),
                            Position = UDim2.new(0, 8, 0, 0),
                            BackgroundTransparency = 1, Text = optStr,
                            TextColor3 = Theme.Text, TextSize = 12, Font = Util.Font("regular"),
                            TextXAlignment = Enum.TextXAlignment.Left,
                            ZIndex = 703, Parent = row,
                        })
                        tracker.Register(lbl, "TextColor3", "Text")
                        local check = Util.Create("TextLabel", {
                            Size = UDim2.new(0, 16, 0, 16),
                            Position = UDim2.new(1, -22, 0.5, 0),
                            AnchorPoint = Vector2.new(0, 0.5),
                            BackgroundTransparency = 1, Text = Icons.check,
                            TextColor3 = Color3.new(1, 1, 1), TextSize = 13, Font = Util.Font("bold"),
                            Visible = selectedSet[opt] == true,
                            ZIndex = 703, Parent = row,
                        })
                        optionButtons[opt] = { row = row, check = check, label = lbl }
                        row.MouseEnter:Connect(function()
                            if not selectedSet[opt] then Util.Tween(row, { BackgroundColor3 = Theme.Hover }, 0.1) end
                        end)
                        row.MouseLeave:Connect(function()
                            if not selectedSet[opt] then Util.Tween(row, { BackgroundColor3 = Theme.Card }, 0.1) end
                        end)
                        row.MouseButton1Click:Connect(function()
                            if multi then
                                selectedSet[opt] = not selectedSet[opt]
                                if not selectedSet[opt] then selectedSet[opt] = nil end
                            else
                                selectedSet = { [opt] = true }
                            end
                            updateTriggerText()
                            refreshSelectedStyle()
                            fireCallback()
                            if not multi then closeMenu() end
                        end)
                    end
                end
                refreshSelectedStyle()
            end

            local menuOpen = false
            closeMenu = function()
                if not menuOpen then return end
                menuOpen = false
                Util.Tween(arrowLbl, { Rotation = 0 }, 0.18)
                Util.Tween(menu, { Size = UDim2.new(0, menu.Size.X.Offset, 0, 0) }, 0.18,
                    Enum.EasingStyle.Back, Enum.EasingDirection.In)
                task.delay(0.2, function()
                    if not menuOpen then menu.Visible = false end
                end)
            end
            local function openMenu()
                rebuildOptionList(searchBox and searchBox.Text or "")
                menu.Visible = true
                menuOpen = true
                local fp = frame.AbsolutePosition
                local fs = frame.AbsoluteSize
                local screen = ScreenGui.AbsoluteSize
                local menuW = math.max(200, fs.X * 0.6)
                local desiredHeight = math.min(240, 30 + (searchable and 32 or 0) + (#options * 28))
                local belowSpace = screen.Y - (fp.Y + fs.Y) - GuiInset.Y - 12
                local aboveSpace = fp.Y - 12
                local placeAbove = (belowSpace < desiredHeight and aboveSpace > belowSpace)
                menu.Size = UDim2.new(0, menuW, 0, 0)
                menu.Position = placeAbove
                    and UDim2.new(0, fp.X + fs.X - menuW, 0, fp.Y - desiredHeight - 4 + GuiInset.Y)
                    or  UDim2.new(0, fp.X + fs.X - menuW, 0, fp.Y + fs.Y + 4 + GuiInset.Y)
                Util.Tween(menu, { Size = UDim2.new(0, menuW, 0, desiredHeight) }, 0.22,
                    Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                Util.Tween(arrowLbl, { Rotation = 180 }, 0.18)
                if searchBox then searchBox:CaptureFocus() end
            end

            trigger.MouseButton1Click:Connect(function()
                if menuOpen then closeMenu() else openMenu() end
            end)
            if searchBox then
                searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                    rebuildOptionList(searchBox.Text)
                end)
            end

            -- click outside to close
            mainMaid:Give(UserInputService.InputBegan:Connect(function(input)
                if not menuOpen then return end
                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
                local mp = Vector2.new(input.Position.X, input.Position.Y)
                local mpos = menu.AbsolutePosition
                local msize = menu.AbsoluteSize
                local tpos = trigger.AbsolutePosition
                local tsize = trigger.AbsoluteSize
                if (mp.X >= mpos.X and mp.X <= mpos.X + msize.X
                  and mp.Y >= mpos.Y and mp.Y <= mpos.Y + msize.Y)
                or (mp.X >= tpos.X and mp.X <= tpos.X + tsize.X
                  and mp.Y >= tpos.Y and mp.Y <= tpos.Y + tsize.Y) then
                    return
                end
                closeMenu()
            end))

            local reg = registerElement(name, "Dropdown", frame)
            local obj = { Kind = "Dropdown" }
            attachBaseObject(obj, frame, reg)
            function obj:Set(v)
                selectedSet = {}
                if multi and type(v) == "table" then
                    for _, item in ipairs(v) do selectedSet[item] = true end
                elseif v ~= nil then
                    selectedSet[v] = true
                end
                updateTriggerText()
                fireCallback()
            end
            function obj:Get()
                if multi then
                    local arr = {}; for k in pairs(selectedSet) do table.insert(arr, k) end
                    return arr
                end
                for k in pairs(selectedSet) do return k end
                return nil
            end
            function obj:SetOptions(newOptions)
                options = newOptions or {}
                -- prune selections that no longer exist
                local set = {}
                for _, o in ipairs(options) do set[o] = true end
                for k in pairs(selectedSet) do if not set[k] then selectedSet[k] = nil end end
                updateTriggerText()
                if menuOpen then rebuildOptionList(searchBox and searchBox.Text or "") end
            end
            function obj:AddOption(opt)  table.insert(options, opt) end
            function obj:RemoveOption(opt)
                for i, o in ipairs(options) do if o == opt then table.remove(options, i); break end end
                selectedSet[opt] = nil
            end
            function obj:SetName(n) nameLbl.Text = n end

            if flag then
                Window.Flags[flag] = {
                    type = multi and "multidropdown" or "dropdown",
                    get = function() return obj:Get() end,
                    set = function(v) obj:Set(v) end,
                    element = obj,
                }
            end

            if default ~= nil then pcall(fireCallback) end
            return obj
        end

        function Tab:CreateSearchableDropdown(dCfg)
            dCfg = dCfg or {}
            dCfg.Searchable = true
            return Tab:CreateDropdown(dCfg)
        end

        -- ═══════════════════════════════
        -- INPUT (single-line TextBox)
        -- ═══════════════════════════════
        function Tab:CreateInput(iCfg)
            iCfg = iCfg or {}
            local name        = iCfg.Name        or "Input"
            local description = iCfg.Description
            local placeholder = iCfg.Placeholder or "Enter text…"
            local default     = iCfg.Default     or ""
            local numbersOnly = iCfg.NumbersOnly == true
            local clearOnFocus= iCfg.ClearOnFocus == true
            local maxLength   = iCfg.MaxLength
            local password    = iCfg.Password    == true
            local callback    = iCfg.Callback    or function() end
            local flag        = iCfg.Flag

            local frame = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, description and 60 or 48),
                BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
                LayoutOrder = nextOrder(), ZIndex = 13, Parent = page,
            })
            Util.Corner(frame, 8)
            Util.Stroke(frame, Theme.Border, 1, 0.6)
            tracker.Register(frame, "BackgroundColor3", "Card")

            local nameLbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, -28, 0, 14),
                Position = UDim2.new(0, 14, 0, 6),
                BackgroundTransparency = 1, Text = name,
                TextColor3 = Theme.SubText, TextSize = 11, Font = Util.Font("bold"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 14, Parent = frame,
            })
            tracker.Register(nameLbl, "TextColor3", "SubText")
            if description then
                local d = Util.Create("TextLabel", {
                    Size = UDim2.new(1, -28, 0, 14),
                    Position = UDim2.new(0, 14, 0, 20),
                    BackgroundTransparency = 1, Text = description,
                    TextColor3 = Theme.DimText, TextSize = 10, Font = Util.Font("regular"),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 14, Parent = frame,
                })
                tracker.Register(d, "TextColor3", "DimText")
            end

            local boxY = description and 36 or 22
            local tb = Util.Create("TextBox", {
                Size = UDim2.new(1, -28, 0, 24),
                Position = UDim2.new(0, 14, 0, boxY),
                BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
                Text = default, PlaceholderText = placeholder, PlaceholderColor3 = Theme.DimText,
                TextColor3 = Theme.Text, TextSize = 12, Font = Util.Font("regular"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ClearTextOnFocus = clearOnFocus,
                ZIndex = 14, Parent = frame,
            })
            Util.Corner(tb, 4)
            Util.Padding(tb, 0, 0, 8, 8)
            local stroke = Util.Stroke(tb, Theme.Border, 1, 0.6)
            tracker.Register(tb, "BackgroundColor3", "Tertiary")
            tracker.Register(tb, "TextColor3", "Text")
            tracker.Register(stroke, "Color", "Border")

            tb.Focused:Connect(function() Util.Tween(stroke, { Color = Theme.Accent, Transparency = 0 }, 0.18) end)
            tb.FocusLost:Connect(function()
                Util.Tween(stroke, { Color = Theme.Border, Transparency = 0.6 }, 0.18)
                local text = tb.Text
                if maxLength and #text > maxLength then text = string.sub(text, 1, maxLength); tb.Text = text end
                if numbersOnly then
                    local n = tonumber(text)
                    if not n then text = ""; tb.Text = "" else text = tostring(n) end
                end
                pcall(callback, text)
                if cfg.AutoSave then pcall(function() Window:SaveConfig(cfg.AutoSave) end) end
            end)
            -- enforce maxLength live
            if maxLength then
                tb:GetPropertyChangedSignal("Text"):Connect(function()
                    if #tb.Text > maxLength then tb.Text = string.sub(tb.Text, 1, maxLength) end
                end)
            end
            if password then
                -- mask via formatted display through a label overlay (since TextBox cannot mask natively)
                tb.TextTransparency = 1
                local maskLbl = Util.Create("TextLabel", {
                    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
                    Text = "", TextColor3 = Theme.Text,
                    TextSize = 12, Font = Util.Font("regular"),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 15, Parent = tb,
                })
                tb:GetPropertyChangedSignal("Text"):Connect(function()
                    maskLbl.Text = string.rep("•", #tb.Text)
                end)
                maskLbl.Text = string.rep("•", #tb.Text)
            end

            local reg = registerElement(name, "Input", frame)
            local obj = { Kind = "Input" }
            attachBaseObject(obj, frame, reg)
            function obj:Set(v) tb.Text = tostring(v); pcall(callback, tb.Text) end
            function obj:Get() return tb.Text end
            function obj:SetName(n) nameLbl.Text = n end
            function obj:SetPlaceholder(p) tb.PlaceholderText = p end
            if flag then
                Window.Flags[flag] = { type = "string",
                    get = function() return tb.Text end,
                    set = function(v) tb.Text = tostring(v) end, element = obj }
            end
            return obj
        end

        -- ═══════════════════════════════
        -- TEXTAREA (multi-line)
        -- ═══════════════════════════════
        function Tab:CreateTextArea(iCfg)
            iCfg = iCfg or {}
            local name        = iCfg.Name        or "Text"
            local placeholder = iCfg.Placeholder or "Type here…"
            local default     = iCfg.Default     or ""
            local rows        = iCfg.Rows        or 4
            local callback    = iCfg.Callback    or function() end
            local flag        = iCfg.Flag

            local frame = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 28 + rows * 18),
                BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
                LayoutOrder = nextOrder(), ZIndex = 13, Parent = page,
            })
            Util.Corner(frame, 8)
            Util.Stroke(frame, Theme.Border, 1, 0.6)
            tracker.Register(frame, "BackgroundColor3", "Card")

            local nameLbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, -28, 0, 14),
                Position = UDim2.new(0, 14, 0, 6),
                BackgroundTransparency = 1, Text = name,
                TextColor3 = Theme.SubText, TextSize = 11, Font = Util.Font("bold"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 14, Parent = frame,
            })
            tracker.Register(nameLbl, "TextColor3", "SubText")
            local tb = Util.Create("TextBox", {
                Size = UDim2.new(1, -28, 1, -28),
                Position = UDim2.new(0, 14, 0, 22),
                BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
                Text = default, PlaceholderText = placeholder,
                PlaceholderColor3 = Theme.DimText,
                TextColor3 = Theme.Text, TextSize = 12, Font = Util.Font("regular"),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true, MultiLine = true,
                ClearTextOnFocus = false,
                ZIndex = 14, Parent = frame,
            })
            Util.Corner(tb, 6)
            Util.Padding(tb, 6, 6, 8, 8)
            tracker.Register(tb, "BackgroundColor3", "Tertiary")
            tracker.Register(tb, "TextColor3", "Text")

            tb.FocusLost:Connect(function() pcall(callback, tb.Text) end)

            local reg = registerElement(name, "TextArea", frame)
            local obj = { Kind = "TextArea" }
            attachBaseObject(obj, frame, reg)
            function obj:Set(v) tb.Text = tostring(v); pcall(callback, tb.Text) end
            function obj:Get() return tb.Text end
            function obj:SetName(n) nameLbl.Text = n end
            if flag then
                Window.Flags[flag] = { type = "string",
                    get = function() return tb.Text end,
                    set = function(v) tb.Text = tostring(v) end, element = obj }
            end
            return obj
        end

        -- ═══════════════════════════════
        -- KEYBIND  (with modifiers, mouse buttons, Hold / Toggle / OnRelease)
        -- ═══════════════════════════════
        function Tab:CreateKeybind(kCfg)
            kCfg = kCfg or {}
            local name        = kCfg.Name        or "Keybind"
            local description = kCfg.Description
            local defaultKey  = kCfg.Default     or Enum.KeyCode.RightControl
            local defaultMods = kCfg.Modifiers
            local defaultMode = kCfg.Mode        or "Toggle"
            local callback    = kCfg.Callback    or function() end
            local flag        = kCfg.Flag

            local frame = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, description and 50 or 38),
                BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
                LayoutOrder = nextOrder(), ZIndex = 13, Parent = page,
            })
            Util.Corner(frame, 8)
            Util.Stroke(frame, Theme.Border, 1, 0.6)
            tracker.Register(frame, "BackgroundColor3", "Card")

            local nameLbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, -160, 0, description and 18 or 36),
                Position = UDim2.new(0, 14, 0, description and 8 or 1),
                BackgroundTransparency = 1, Text = name,
                TextColor3 = Theme.Text, TextSize = 13, Font = Util.Font("semi"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 14, Parent = frame,
            })
            tracker.Register(nameLbl, "TextColor3", "Text")
            if description then
                local d = Util.Create("TextLabel", {
                    Size = UDim2.new(1, -160, 0, 16),
                    Position = UDim2.new(0, 14, 0, 26),
                    BackgroundTransparency = 1, Text = description,
                    TextColor3 = Theme.DimText, TextSize = 11, Font = Util.Font("regular"),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 14, Parent = frame,
                })
                tracker.Register(d, "TextColor3", "DimText")
            end

            local trigger = Util.Create("TextButton", {
                Size = UDim2.new(0, 110, 0, 24),
                Position = UDim2.new(1, -52, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
                Text = "", AutoButtonColor = false,
                ZIndex = 14, Parent = frame,
            })
            Util.Corner(trigger, 4)
            tracker.Register(trigger, "BackgroundColor3", "Tertiary")
            local triggerLbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, -4, 1, 0), Position = UDim2.new(0, 2, 0, 0),
                BackgroundTransparency = 1, Text = "...",
                TextColor3 = Theme.Text, TextSize = 11, Font = Util.Font("bold"),
                ZIndex = 15, Parent = trigger,
            })
            tracker.Register(triggerLbl, "TextColor3", "Text")

            -- Mode selector (small)
            local modeBtn = Util.Create("TextButton", {
                Size = UDim2.new(0, 36, 0, 24),
                Position = UDim2.new(1, -14, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
                Text = "", AutoButtonColor = false,
                ZIndex = 14, Parent = frame,
            })
            Util.Corner(modeBtn, 4)
            tracker.Register(modeBtn, "BackgroundColor3", "Tertiary")
            local modeLbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
                Text = defaultMode, TextColor3 = Theme.AccentLight,
                TextSize = 10, Font = Util.Font("bold"),
                ZIndex = 15, Parent = modeBtn,
            })
            tracker.Register(modeLbl, "TextColor3", "AccentLight")
            Window:BindTooltip(modeBtn, "Toggle mode (click to cycle): Toggle → Hold → OnRelease")

            local currentSpec = { Key = defaultKey, Modifiers = defaultMods, Mode = defaultMode }
            local unbind
            local function makeLabel(spec)
                local parts = {}
                if spec.Modifiers then for _, m in ipairs(spec.Modifiers) do table.insert(parts, m) end end
                table.insert(parts, keyDisplayName(spec.Key))
                return table.concat(parts, "+")
            end
            local function rebind()
                if unbind then unbind() end
                unbind = registerKeybind(currentSpec, function(state)
                    pcall(callback, state)
                end)
                triggerLbl.Text = makeLabel(currentSpec)
            end
            rebind()

            trigger.MouseButton1Click:Connect(function()
                triggerLbl.Text = "..."
                keybindListening = { resolve = function(spec)
                    currentSpec = { Key = spec.Key, Modifiers = spec.Modifiers, Mode = currentSpec.Mode }
                    rebind()
                end }
            end)
            local modeCycle = { Toggle = "Hold", Hold = "OnRelease", OnRelease = "Toggle" }
            modeBtn.MouseButton1Click:Connect(function()
                currentSpec.Mode = modeCycle[currentSpec.Mode] or "Toggle"
                modeLbl.Text = currentSpec.Mode
                rebind()
            end)

            local reg = registerElement(name, "Keybind", frame)
            local obj = { Kind = "Keybind" }
            attachBaseObject(obj, frame, reg)
            function obj:Set(spec)
                currentSpec = spec or currentSpec
                modeLbl.Text = currentSpec.Mode
                rebind()
            end
            function obj:Get() return currentSpec end
            function obj:SetName(n) nameLbl.Text = n end
            if flag then
                Window.Flags[flag] = { type = "keybind",
                    get = function() return currentSpec end,
                    set = function(v) obj:Set(v) end, element = obj }
            end
            return obj
        end

        -- ═══════════════════════════════
        -- COLORPICKER  (HSV + RGB + Hex + Alpha + Recents)
        -- ═══════════════════════════════
        function Tab:CreateColorPicker(cCfg)
            cCfg = cCfg or {}
            local obj  -- forward decl so inner closures see the local
            local name        = cCfg.Name        or "Color"
            local description = cCfg.Description
            local default     = cCfg.Default     or Color3.fromRGB(88, 101, 242)
            local allowAlpha  = cCfg.Alpha       == true
            local defaultA    = cCfg.DefaultAlpha or 1
            local callback    = cCfg.Callback    or function() end
            local flag        = cCfg.Flag

            local recentList = cCfg.Recents or {}

            local frame = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, description and 50 or 38),
                BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
                LayoutOrder = nextOrder(), ZIndex = 13, Parent = page,
            })
            Util.Corner(frame, 8)
            Util.Stroke(frame, Theme.Border, 1, 0.6)
            tracker.Register(frame, "BackgroundColor3", "Card")

            local nameLbl = Util.Create("TextLabel", {
                Size = UDim2.new(1, -60, 0, description and 18 or 36),
                Position = UDim2.new(0, 14, 0, description and 8 or 1),
                BackgroundTransparency = 1, Text = name,
                TextColor3 = Theme.Text, TextSize = 13, Font = Util.Font("semi"),
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 14, Parent = frame,
            })
            tracker.Register(nameLbl, "TextColor3", "Text")
            if description then
                local d = Util.Create("TextLabel", {
                    Size = UDim2.new(1, -60, 0, 16),
                    Position = UDim2.new(0, 14, 0, 26),
                    BackgroundTransparency = 1, Text = description,
                    TextColor3 = Theme.DimText, TextSize = 11, Font = Util.Font("regular"),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 14, Parent = frame,
                })
                tracker.Register(d, "TextColor3", "DimText")
            end

            local preview = Util.Create("TextButton", {
                Size = UDim2.new(0, 32, 0, 22),
                Position = UDim2.new(1, -14, 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = default, BorderSizePixel = 0,
                Text = "", AutoButtonColor = false,
                ZIndex = 14, Parent = frame,
            })
            Util.Corner(preview, 4)
            Util.Stroke(preview, Color3.new(1, 1, 1), 1, 0.4)

            -- ═════════════ Popup ═════════════
            local popup = Util.Create("Frame", {
                Size = UDim2.new(0, 240, 0, 0),
                BackgroundColor3 = Theme.Secondary, BorderSizePixel = 0,
                ClipsDescendants = true, Visible = false,
                ZIndex = 750, Parent = ScreenGui,
            })
            Util.Corner(popup, 8)
            Util.Stroke(popup, Theme.BorderStrong, 1, 0.4)
            tracker.Register(popup, "BackgroundColor3", "Secondary")

            -- SV (saturation/value) box
            local svBox = Util.Create("ImageLabel", {
                Size = UDim2.new(1, -16, 0, 120),
                Position = UDim2.new(0, 8, 0, 8),
                BackgroundColor3 = Color3.fromRGB(255, 0, 0),
                BorderSizePixel = 0,
                Image = "rbxassetid://4155801252",  -- white→transparent vertical
                ImageColor3 = Color3.new(1, 1, 1),
                ZIndex = 751, Parent = popup,
            })
            Util.Corner(svBox, 6)
            Util.Create("UIGradient", {
                Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 0, 0)),
                Parent = svBox,
            })
            local svBlack = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
                ZIndex = 752, Parent = svBox,
            })
            Util.Corner(svBlack, 6)
            Util.Create("UIGradient", {
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(1, 0),
                }),
                Rotation = 90,
                Parent = svBlack,
            })
            local svCursor = Util.Create("Frame", {
                Size = UDim2.new(0, 12, 0, 12),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1, BorderSizePixel = 0,
                ZIndex = 754, Parent = svBox,
            })
            Util.Stroke(svCursor, Color3.new(1, 1, 1), 2, 0)
            Util.Corner(svCursor, 999)

            -- Hue bar
            local hueBar = Util.Create("Frame", {
                Size = UDim2.new(1, -16, 0, 14),
                Position = UDim2.new(0, 8, 0, 134),
                BorderSizePixel = 0, ZIndex = 751, Parent = popup,
            })
            Util.Corner(hueBar, 4)
            Util.Create("UIGradient", {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0/6,   Color3.fromRGB(255, 0, 0)),
                    ColorSequenceKeypoint.new(1/6,   Color3.fromRGB(255, 255, 0)),
                    ColorSequenceKeypoint.new(2/6,   Color3.fromRGB(0, 255, 0)),
                    ColorSequenceKeypoint.new(3/6,   Color3.fromRGB(0, 255, 255)),
                    ColorSequenceKeypoint.new(4/6,   Color3.fromRGB(0, 0, 255)),
                    ColorSequenceKeypoint.new(5/6,   Color3.fromRGB(255, 0, 255)),
                    ColorSequenceKeypoint.new(1,     Color3.fromRGB(255, 0, 0)),
                }),
                Parent = hueBar,
            })
            local hueCursor = Util.Create("Frame", {
                Size = UDim2.new(0, 4, 1, 4),
                Position = UDim2.new(0, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
                ZIndex = 752, Parent = hueBar,
            })
            Util.Corner(hueCursor, 999)

            -- Alpha bar (optional)
            local alphaBar, alphaCursor
            if allowAlpha then
                alphaBar = Util.Create("Frame", {
                    Size = UDim2.new(1, -16, 0, 12),
                    Position = UDim2.new(0, 8, 0, 154),
                    BackgroundColor3 = Color3.fromRGB(255, 0, 0),
                    BorderSizePixel = 0, ZIndex = 751, Parent = popup,
                })
                Util.Corner(alphaBar, 4)
                Util.Create("UIGradient", {
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1),
                        NumberSequenceKeypoint.new(1, 0),
                    }),
                    Parent = alphaBar,
                })
                alphaCursor = Util.Create("Frame", {
                    Size = UDim2.new(0, 4, 1, 4),
                    Position = UDim2.new(1, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
                    ZIndex = 752, Parent = alphaBar,
                })
                Util.Corner(alphaCursor, 999)
            end

            local inputsY = allowAlpha and 174 or 158

            -- Before/After preview
            local oldSwatch = Util.Create("Frame", {
                Size = UDim2.new(0, 28, 0, 24),
                Position = UDim2.new(0, 8, 0, inputsY),
                BackgroundColor3 = default, BorderSizePixel = 0,
                ZIndex = 751, Parent = popup,
            })
            Util.Corner(oldSwatch, 4); Util.Stroke(oldSwatch, Theme.Border, 1, 0.4)
            local newSwatch = Util.Create("Frame", {
                Size = UDim2.new(0, 28, 0, 24),
                Position = UDim2.new(0, 38, 0, inputsY),
                BackgroundColor3 = default, BorderSizePixel = 0,
                ZIndex = 751, Parent = popup,
            })
            Util.Corner(newSwatch, 4); Util.Stroke(newSwatch, Theme.Border, 1, 0.4)

            -- Hex / RGB inputs
            local hexBox = Util.Create("TextBox", {
                Size = UDim2.new(0, 80, 0, 22),
                Position = UDim2.new(0, 76, 0, inputsY + 1),
                BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
                Text = "#FFFFFF", TextColor3 = Theme.Text,
                TextSize = 11, Font = Util.Font("bold"),
                ClearTextOnFocus = false,
                ZIndex = 751, Parent = popup,
            })
            Util.Corner(hexBox, 4); Util.Padding(hexBox, 0, 0, 6, 6)
            tracker.Register(hexBox, "BackgroundColor3", "Tertiary")
            tracker.Register(hexBox, "TextColor3", "Text")

            local function rgbInput(posX, placeholder)
                local b = Util.Create("TextBox", {
                    Size = UDim2.new(0, 26, 0, 22),
                    Position = UDim2.new(0, posX, 0, inputsY + 1),
                    BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
                    Text = "", PlaceholderText = placeholder,
                    PlaceholderColor3 = Theme.DimText,
                    TextColor3 = Theme.Text, TextSize = 10, Font = Util.Font("bold"),
                    ClearTextOnFocus = false,
                    ZIndex = 751, Parent = popup,
                })
                Util.Corner(b, 4); Util.Padding(b, 0, 0, 4, 4)
                tracker.Register(b, "BackgroundColor3", "Tertiary")
                tracker.Register(b, "TextColor3", "Text")
                return b
            end
            local rBox = rgbInput(160, "R")
            local gBox = rgbInput(188, "G")
            local bBox = rgbInput(216, "B")

            -- Recent colors row
            local recentsY = inputsY + 30
            local recentRow = Util.Create("Frame", {
                Size = UDim2.new(1, -16, 0, 20),
                Position = UDim2.new(0, 8, 0, recentsY),
                BackgroundTransparency = 1,
                ZIndex = 751, Parent = popup,
            })
            Util.ListLayout(recentRow, Enum.FillDirection.Horizontal, 4)

            local function refreshRecents()
                for _, c in ipairs(recentRow:GetChildren()) do
                    if c:IsA("TextButton") then c:Destroy() end
                end
                for i, col in ipairs(recentList) do
                    if i > 8 then break end
                    local sw = Util.Create("TextButton", {
                        Size = UDim2.new(0, 18, 0, 18),
                        BackgroundColor3 = col, BorderSizePixel = 0,
                        Text = "", AutoButtonColor = false,
                        LayoutOrder = i, ZIndex = 752, Parent = recentRow,
                    })
                    Util.Corner(sw, 4); Util.Stroke(sw, Theme.Border, 1, 0.4)
                    sw.MouseButton1Click:Connect(function() obj:Set(col) end)
                end
            end

            -- State
            local h, s, v = 0, 0, 1
            local alpha = defaultA
            local color = default

            local function color3FromHSV()
                color = Color3.fromHSV(h, s, v)
                return color
            end

            local function applyVisuals()
                svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
                hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
                if alphaBar then
                    alphaBar.BackgroundColor3 = color3FromHSV()
                    alphaCursor.Position = UDim2.new(alpha, 0, 0.5, 0)
                end
                newSwatch.BackgroundColor3 = color3FromHSV()
                preview.BackgroundColor3 = newSwatch.BackgroundColor3
                local r, g, b = math.floor(color.R * 255 + 0.5),
                                math.floor(color.G * 255 + 0.5),
                                math.floor(color.B * 255 + 0.5)
                rBox.Text = tostring(r); gBox.Text = tostring(g); bBox.Text = tostring(b)
                hexBox.Text = string.format("#%02X%02X%02X", r, g, b)
            end

            -- Initialise hsv from default
            do
                local hh, ss, vv = Color3.toHSV(default)
                h, s, v = hh, ss, vv
                applyVisuals()
            end

            local function fireCallback(commit)
                pcall(callback, color3FromHSV(), alpha)
                if commit then
                    table.insert(recentList, 1, color3FromHSV())
                    -- dedupe
                    local seen, uniq = {}, {}
                    for _, c in ipairs(recentList) do
                        local k = string.format("%02X%02X%02X",
                            math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
                        if not seen[k] then table.insert(uniq, c); seen[k] = true end
                    end
                    recentList = uniq
                    refreshRecents()
                end
            end

            -- SV interaction
            svBox.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
                activeDragHandler = { onMove = function(pos)
                    local rx = (pos.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X
                    local ry = (pos.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y
                    s = Util.Clamp(rx, 0, 1)
                    v = Util.Clamp(1 - ry, 0, 1)
                    applyVisuals(); fireCallback(false)
                end, onRelease = function() fireCallback(true) end }
                local rx = (input.Position.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X
                local ry = (input.Position.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y
                s = Util.Clamp(rx, 0, 1); v = Util.Clamp(1 - ry, 0, 1)
                applyVisuals(); fireCallback(false)
            end)

            -- Hue interaction
            hueBar.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
                activeDragHandler = { onMove = function(pos)
                    local rx = (pos.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X
                    h = Util.Clamp(rx, 0, 0.9999)
                    applyVisuals(); fireCallback(false)
                end, onRelease = function() fireCallback(true) end }
                local rx = (input.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X
                h = Util.Clamp(rx, 0, 0.9999); applyVisuals(); fireCallback(false)
            end)

            -- Alpha interaction
            if alphaBar then
                alphaBar.InputBegan:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1
                    and input.UserInputType ~= Enum.UserInputType.Touch then return end
                    activeDragHandler = { onMove = function(pos)
                        local rx = (pos.X - alphaBar.AbsolutePosition.X) / alphaBar.AbsoluteSize.X
                        alpha = Util.Clamp(rx, 0, 1)
                        applyVisuals(); fireCallback(false)
                    end, onRelease = function() fireCallback(true) end }
                    local rx = (input.Position.X - alphaBar.AbsolutePosition.X) / alphaBar.AbsoluteSize.X
                    alpha = Util.Clamp(rx, 0, 1); applyVisuals(); fireCallback(false)
                end)
            end

            -- Hex input
            hexBox.FocusLost:Connect(function()
                local hex = hexBox.Text:gsub("#", ""):upper()
                if #hex == 6 then
                    local r = tonumber(hex:sub(1, 2), 16)
                    local g = tonumber(hex:sub(3, 4), 16)
                    local b = tonumber(hex:sub(5, 6), 16)
                    if r and g and b then
                        local hh, ss, vv = Color3.toHSV(Color3.fromRGB(r, g, b))
                        h, s, v = hh, ss, vv
                        applyVisuals(); fireCallback(true); return
                    end
                end
                applyVisuals()  -- reset display
            end)

            -- RGB inputs
            local function applyRGB()
                local r = tonumber(rBox.Text); local g = tonumber(gBox.Text); local b = tonumber(bBox.Text)
                if r and g and b then
                    r = Util.Clamp(r, 0, 255); g = Util.Clamp(g, 0, 255); b = Util.Clamp(b, 0, 255)
                    local hh, ss, vv = Color3.toHSV(Color3.fromRGB(r, g, b))
                    h, s, v = hh, ss, vv
                    applyVisuals(); fireCallback(true)
                else applyVisuals() end
            end
            rBox.FocusLost:Connect(applyRGB)
            gBox.FocusLost:Connect(applyRGB)
            bBox.FocusLost:Connect(applyRGB)

            local popupOpen = false
            local function close()
                if not popupOpen then return end
                popupOpen = false
                Util.Tween(popup, { Size = UDim2.new(0, 240, 0, 0) }, 0.2)
                task.delay(0.22, function() if not popupOpen then popup.Visible = false end end)
            end
            local function open()
                refreshRecents()
                oldSwatch.BackgroundColor3 = color3FromHSV()
                local height = recentsY + 30
                popup.Visible = true
                popupOpen = true
                local fp = preview.AbsolutePosition
                local fs = preview.AbsoluteSize
                local screen = ScreenGui.AbsoluteSize
                local placeAbove = (screen.Y - (fp.Y + fs.Y) - GuiInset.Y < height + 12)
                popup.Size = UDim2.new(0, 240, 0, 0)
                popup.Position = placeAbove
                    and UDim2.new(0, fp.X + fs.X - 240, 0, fp.Y - height - 4 + GuiInset.Y)
                    or  UDim2.new(0, fp.X + fs.X - 240, 0, fp.Y + fs.Y + 4 + GuiInset.Y)
                Util.Tween(popup, { Size = UDim2.new(0, 240, 0, height) }, 0.25,
                    Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            end
            preview.MouseButton1Click:Connect(function()
                if popupOpen then close() else open() end
            end)
            mainMaid:Give(UserInputService.InputBegan:Connect(function(input)
                if not popupOpen then return end
                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then return end
                local mp = Vector2.new(input.Position.X, input.Position.Y)
                local pp, ps = popup.AbsolutePosition, popup.AbsoluteSize
                local prp, prs = preview.AbsolutePosition, preview.AbsoluteSize
                if (mp.X >= pp.X and mp.X <= pp.X + ps.X
                  and mp.Y >= pp.Y and mp.Y <= pp.Y + ps.Y)
                or (mp.X >= prp.X and mp.X <= prp.X + prs.X
                  and mp.Y >= prp.Y and mp.Y <= prp.Y + prs.Y) then return end
                close()
            end))

            local reg = registerElement(name, "ColorPicker", frame)
            obj = { Kind = "ColorPicker" }
            attachBaseObject(obj, frame, reg)

            function obj:Set(c, a)
                if typeof(c) == "Color3" then
                    local hh, ss, vv = Color3.toHSV(c)
                    h, s, v = hh, ss, vv
                end
                if a then alpha = a end
                applyVisuals(); fireCallback(true)
            end
            function obj:Get() return color3FromHSV(), alpha end
            function obj:SetName(n) nameLbl.Text = n end
            if flag then
                Window.Flags[flag] = { type = "color",
                    get = function() return color3FromHSV() end,
                    set = function(c) obj:Set(c) end, element = obj }
            end
            return obj
        end

        -- ═══════════════════════════════
        -- IMAGE
        -- ═══════════════════════════════
        function Tab:CreateImage(iCfg)
            iCfg = iCfg or {}
            local imageId = iCfg.Image or "rbxassetid://0"
            local height  = iCfg.Height or 120
            local rounded = iCfg.Rounded ~= false

            local frame = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, height),
                BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
                LayoutOrder = nextOrder(), ZIndex = 13, Parent = page,
            })
            if rounded then Util.Corner(frame, 8) end
            Util.Stroke(frame, Theme.Border, 1, 0.6)
            tracker.Register(frame, "BackgroundColor3", "Card")
            local img = Util.Create("ImageLabel", {
                Size = UDim2.new(1, -4, 1, -4),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Image = imageId, ScaleType = Enum.ScaleType.Fit,
                ZIndex = 14, Parent = frame,
            })
            if rounded then Util.Corner(img, 6) end
            local reg = registerElement(iCfg.Name or "Image", "Image", frame)
            local obj = { Kind = "Image" }
            attachBaseObject(obj, frame, reg)
            function obj:SetImage(id) img.Image = id end
            return obj
        end

        return Tab
    end  -- CreateTab

    -- ═══════════════════════════════
    -- BUILTIN SETTINGS TAB
    -- ═══════════════════════════════
    local function buildSettingsTab()
        local tab = Window:CreateTab({ Name = "Settings", IconText = Icons.settings })
        tab:CreateSection({ Name = "Appearance" })

        local themeList = NexusUI.GetThemes()
        tab:CreateDropdown({
            Name        = "Theme",
            Description = "Switch the active color palette",
            Options     = themeList,
            Default     = cfg.Theme,
            Searchable  = true,
            Callback    = function(v) Window:SetTheme(v, true) end,
        })
        tab:CreateSlider({
            Name        = "UI scale",
            Description = "Resize the entire interface",
            Min = 0.6, Max = 1.4, Default = cfg.DPIScale, Increment = 0.05, Decimals = 2,
            Callback    = function(v) Window:SetDPIScale(v) end,
        })
        tab:CreateToggle({
            Name        = "Acrylic blur",
            Description = "Background blur (uses Lighting.BlurEffect)",
            Default     = cfg.Acrylic,
            Callback    = function(v) Window:SetAcrylic(v) end,
        })
        tab:CreateToggle({
            Name        = "Interaction sounds",
            Default     = cfg.Sounds,
            Callback    = function(v) cfg.Sounds = v end,
        })

        tab:CreateSection({ Name = "Behavior" })
        tab:CreateKeybind({
            Name        = "Toggle UI",
            Description = "Press to show/hide the window",
            Default     = cfg.KeyBind,
            Mode        = "Toggle",
            Callback    = function() Window:Toggle() end,
        })

        tab:CreateSection({ Name = "Configurations" })
        local configsDropdown
        local function refreshList()
            local list = Window:ListConfigs()
            table.insert(list, "(new)")
            if configsDropdown then configsDropdown:SetOptions(list) end
        end
        local nameInput = tab:CreateInput({
            Name        = "Config name",
            Placeholder = "Profile name",
            Default     = "default",
        })
        configsDropdown = tab:CreateDropdown({
            Name        = "Existing configs",
            Options     = Window:ListConfigs(),
            Callback    = function(v) if v then nameInput:Set(v) end end,
        })
        tab:CreateButton({
            Name = "Save current",
            Callback = function() Window:SaveConfig(nameInput:Get()); refreshList() end,
        })
        tab:CreateButton({
            Name = "Load",
            Callback = function() Window:LoadConfig(nameInput:Get()) end,
        })
        tab:CreateButton({
            Name = "Delete",
            Callback = function()
                Window:Prompt({
                    Title = "Delete config",
                    Content = "Are you sure you want to delete '" .. nameInput:Get() .. "'?",
                    Yes = "Delete", No = "Cancel",
                    Callback = function(ok)
                        if ok then Window:DeleteConfig(nameInput:Get()); refreshList() end
                    end,
                })
            end,
        })
        tab:CreateButton({
            Name = "Copy to clipboard",
            Callback = function() Window:ExportConfig(nameInput:Get()) end,
        })

        tab:CreateSection({ Name = "About" })
        tab:CreateParagraph({
            Title = LIB_NAME .. " v" .. LIB_VERSION,
            Content = "Professional UI library for Roblox. Press " .. tostring(cfg.KeyBind) ..
                " to toggle this window. Use Ctrl+F to search elements, Ctrl+K for commands.",
        })
        refreshList()
        return tab
    end

    -- ═══════════════════════════════
    -- NOTIFY  (per-window, queued, action buttons, close button)
    -- ═══════════════════════════════
    function Window:Notify(notifConfig)
        notifConfig = notifConfig or {}
        local title    = notifConfig.Title    or "Notification"
        local content  = notifConfig.Content  or ""
        local notifType = notifConfig.Type    or "Info"
        local duration = notifConfig.Duration or 5
        local actions  = notifConfig.Actions  or {}  -- list of { Text, Callback }

        if #notifyQueue >= NOTIFY_MAX then
            table.insert(notifyPending, notifConfig)
            return
        end

        local typeColors = {
            Success = Theme.Success, Error = Theme.Error,
            Warning = Theme.Warning, Info  = Theme.Info,
        }
        local typeIcons = {
            Success = Icons.success, Error = Icons.cross,
            Warning = Icons.warning, Info  = Icons.info,
        }
        local accent = typeColors[notifType] or Theme.Info
        local icon   = typeIcons[notifType]  or Icons.info

        local wrapper = Util.Create("Frame", {
            Size                  = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            ZIndex                = 201, Parent = NotificationHolder,
        })

        local notif = Util.Create("Frame", {
            Size              = UDim2.new(1, 0, 0, 0),
            AutomaticSize     = Enum.AutomaticSize.Y,
            BackgroundColor3  = Theme.Secondary,
            BorderSizePixel   = 0,
            ClipsDescendants  = true,
            ZIndex            = 202, Parent = wrapper,
        })
        Util.Corner(notif, 8)
        Util.Stroke(notif, Theme.Border, 1, 0.5)
        tracker.Register(notif, "BackgroundColor3", "Secondary")

        local accentStripe = Util.Create("Frame", {
            Size = UDim2.new(0, 3, 1, 0),
            BackgroundColor3 = accent, BorderSizePixel = 0,
            ZIndex = 203, Parent = notif,
        })
        Util.Corner(accentStripe, 2)

        local contentFrame = Util.Create("Frame", {
            Size = UDim2.new(1, -16, 0, 0),
            Position = UDim2.new(0, 10, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            ZIndex = 203, Parent = notif,
        })
        Util.ListLayout(contentFrame, Enum.FillDirection.Vertical, 4)
        Util.Padding(contentFrame, 10, 10, 4, 4)

        local header = Util.Create("Frame", {
            Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
            LayoutOrder = 1, ZIndex = 203, Parent = contentFrame,
        })
        Util.Create("TextLabel", {
            Size = UDim2.new(0, 18, 0, 18), BackgroundTransparency = 1,
            Text = icon, TextColor3 = accent,
            TextSize = 13, Font = Util.Font("bold"),
            ZIndex = 204, Parent = header,
        })
        local titleLbl = Util.Create("TextLabel", {
            Size = UDim2.new(1, -42, 0, 18),
            Position = UDim2.new(0, 22, 0, 0),
            BackgroundTransparency = 1,
            Text = title, TextColor3 = Theme.Text,
            TextSize = 13, Font = Util.Font("bold"),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 204, Parent = header,
        })
        tracker.Register(titleLbl, "TextColor3", "Text")

        -- Close button
        local closeBtn2 = Util.Create("TextButton", {
            Size = UDim2.new(0, 16, 0, 16),
            Position = UDim2.new(1, -16, 0, 1),
            BackgroundTransparency = 1,
            Text = Icons.cross, TextColor3 = Theme.SubText,
            TextSize = 12, Font = Util.Font("bold"),
            AutoButtonColor = false,
            ZIndex = 205, Parent = header,
        })
        tracker.Register(closeBtn2, "TextColor3", "SubText")
        closeBtn2.MouseEnter:Connect(function() Util.Tween(closeBtn2, { TextColor3 = Theme.Text }, 0.1) end)
        closeBtn2.MouseLeave:Connect(function() Util.Tween(closeBtn2, { TextColor3 = Theme.SubText }, 0.1) end)

        Util.Create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text = content, TextColor3 = Theme.SubText,
            TextSize = 12, Font = Util.Font("regular"),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            LayoutOrder = 2, ZIndex = 203, Parent = contentFrame,
        })

        -- Action buttons row
        if #actions > 0 then
            local rowA = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
                LayoutOrder = 3, ZIndex = 203, Parent = contentFrame,
            })
            Util.ListLayout(rowA, Enum.FillDirection.Horizontal, 6,
                Enum.HorizontalAlignment.Right)
            for _, action in ipairs(actions) do
                local ab = Util.Create("TextButton", {
                    Size = UDim2.new(0, 0, 1, 0),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundColor3 = Theme.Tertiary, BorderSizePixel = 0,
                    Text = " " .. action.Text .. " ",
                    TextColor3 = Theme.Text,
                    TextSize = 11, Font = Util.Font("semi"),
                    AutoButtonColor = false,
                    ZIndex = 204, Parent = rowA,
                })
                Util.Corner(ab, 4); Util.Padding(ab, 0, 0, 6, 6)
                tracker.Register(ab, "BackgroundColor3", "Tertiary")
                tracker.Register(ab, "TextColor3", "Text")
                ab.MouseEnter:Connect(function() Util.Tween(ab, { BackgroundColor3 = Theme.Hover }, 0.1) end)
                ab.MouseLeave:Connect(function() Util.Tween(ab, { BackgroundColor3 = Theme.Tertiary }, 0.1) end)
                ab.MouseButton1Click:Connect(function()
                    pcall(action.Callback or function() end)
                    closeBtn2.MouseButton1Click:Wait()  -- noop guard
                end)
            end
        end

        -- Progress bar
        local progressBG = Util.Create("Frame", {
            Size = UDim2.new(1, 0, 0, 2),
            BackgroundColor3 = Theme.Tertiary,
            LayoutOrder = 4, ZIndex = 203, Parent = contentFrame,
        })
        Util.Corner(progressBG, 1)
        tracker.Register(progressBG, "BackgroundColor3", "Tertiary")
        local progressFill = Util.Create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = accent, BorderSizePixel = 0,
            ZIndex = 204, Parent = progressBG,
        })
        Util.Corner(progressFill, 1)

        Window._PlaySound("notify")
        table.insert(notifyQueue, wrapper)

        local closed = false
        local function close()
            if closed then return end
            closed = true
            Util.Tween(wrapper, { Size = UDim2.new(1, 0, 0, 0) },
                0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
            task.wait(0.32)
            for i, w in ipairs(notifyQueue) do
                if w == wrapper then table.remove(notifyQueue, i); break end
            end
            if wrapper and wrapper.Parent then wrapper:Destroy() end
            -- Push pending
            if #notifyPending > 0 then
                local next = table.remove(notifyPending, 1)
                Window:Notify(next)
            end
        end
        closeBtn2.MouseButton1Click:Connect(close)

        task.defer(function()
            task.wait()
            local targetHeight = notif.AbsoluteSize.Y + 4
            Util.Tween(wrapper, { Size = UDim2.new(1, 0, 0, targetHeight) },
                0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            Util.Tween(progressFill, { Size = UDim2.new(0, 0, 1, 0) }, duration, Enum.EasingStyle.Linear)
            task.delay(duration, close)
        end)
    end

    -- ═══════════════════════════════
    -- INTRO ANIMATION
    -- ═══════════════════════════════
    MainFrame.BackgroundTransparency = 1
    local targetSize = cfg.Size
    MainFrame.Size = UDim2.new(0, targetSize.X.Offset, 0, 0)
    task.wait(0.05)
    Util.Tween(MainFrame, { Size = targetSize, BackgroundTransparency = 0 },
        0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    -- Build the settings tab last so user tabs come first.
    Window._BuildSettingsTab = buildSettingsTab
    if cfg.ShowSettingsTab then
        task.delay(0.1, function()
            if Window.Alive and #Window.Tabs == 0 then return end
            -- Build settings tab only after user tabs exist; defer to next frame
            task.wait()
            buildSettingsTab()
        end)
    end

    -- Re-select active tab so the settings tab insertion doesn't replace it
    if cfg.AutoLoad then
        task.defer(function() Window:LoadConfig(cfg.AutoLoad) end)
    end

    return Window
end  -- CreateWindow

-- ═══════════════════════════════
-- TOP-LEVEL NOTIFY (forwards to last active window)
-- ═══════════════════════════════
function NexusUI:Notify(notifConfig)
    local w = self._activeWindow or self._windows[#self._windows]
    if w and w.Alive then
        w:Notify(notifConfig)
    end
end

-- ═══════════════════════════════
-- DESTROY ALL
-- ═══════════════════════════════
function NexusUI:Destroy()
    for _, w in ipairs(table.clone(self._windows)) do
        pcall(function() w:Destroy() end)
    end
    self._windows = {}
    self._activeWindow = nil
end

return NexusUI
