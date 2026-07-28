# NexusUI v4

> Professional, executor-friendly UI library for Roblox. Single-file. PC-only (by design).

NexusUI v4 is a ground-up rewrite of v3 with proper architecture, leak-free input
handling, runtime theme switching, custom themes, search & command palettes,
resizable windows, modifier keybinds, mouse-button keybinds, range sliders,
steppers, progress bars, color picker with hex/RGB/alpha/recent colors,
two-layer shadows, acrylic blur, notification queue with action buttons,
per-game config storage, webhook helper, splash screen, and a built-in
settings tab.

```lua
local NexusUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Pablososkivich/NexusUI/main/NexusUI.lua"
))()

local Window = NexusUI:CreateWindow({
    Title       = "Demo",
    Subtitle    = "v4 showcase",
    Theme       = "Dark",
    Size        = UDim2.new(0, 620, 0, 460),
    KeyBind     = Enum.KeyCode.RightShift,
    ConfigFolder = "NexusUI",
    AutoLoad    = "default",
})

local Main = Window:CreateTab({ Name = "Main", IconText = "★" })
Main:CreateButton({ Name = "Click me", Callback = function() print("hi") end })
Main:CreateToggle({ Name = "Auto farm", Default = false, Flag = "autofarm",
    Callback = function(v) print("auto =", v) end })
```

---

## Contents

1. [Installation](#installation)
2. [Window creation](#window-creation)
3. [Tabs](#tabs)
4. [Elements](#elements)
   - [Section](#section), [Label](#label), [Divider](#divider), [Paragraph](#paragraph)
   - [Button](#button), [Toggle](#toggle), [Slider](#slider), [RangeSlider](#rangeslider), [Stepper](#stepper)
   - [Dropdown](#dropdown) / [SearchableDropdown](#searchabledropdown)
   - [Input](#input), [TextArea](#textarea)
   - [Keybind](#keybind), [ColorPicker](#colorpicker)
   - [ProgressBar](#progressbar), [TagList](#taglist), [RadioGroup](#radiogroup), [Segmented](#segmented), [Image](#image)
5. [Notifications](#notifications)
6. [Themes](#themes)
7. [Search & Command palettes](#search--command-palettes)
8. [Watermark, FloatingWindow, BindsList, StatusWindow](#watermark--floating-windows)
9. [Config system](#config-system)
10. [Webhooks & update checker](#webhooks--update-checker)
11. [Splash screen](#splash-screen)
12. [Migration from v3](#migration-from-v3)

---

## Installation

```lua
local NexusUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Pablososkivich/NexusUI/main/NexusUI.lua"
))()
```

The library tries `gethui()` → `syn.protect_gui` → `get_hidden_gui` →
`CoreGui` → `PlayerGui` to find a safe parent.

## Window creation

```lua
local Window = NexusUI:CreateWindow({
    Title        = "NexusUI",     -- top bar title
    Subtitle     = "v4",          -- optional small line under title
    Size         = UDim2.new(0, 620, 0, 460),
    Theme        = "Dark",        -- or a custom theme table
    KeyBind      = Enum.KeyCode.RightShift,  -- press to toggle window
    ConfigFolder = "NexusUI",     -- saved configs go here (executor fs)
    Acrylic      = false,         -- Lighting.BlurEffect backdrop
    DPIScale     = 1,             -- multiplier for UIScale
    Sounds       = false,         -- click / toggle / notify sounds
    AutoLoad     = "default",     -- config name to auto-load on open
    AutoSave     = "default",     -- flag changes auto-save to this name
    Resizable    = true,          -- bottom-right resize handle
    SnapToEdges  = true,          -- snap window when dragged near edges
    Watermark    = true,          -- create default watermark
    ShowSettingsTab = true,       -- inject built-in Settings tab
})
```

### Window methods

| Method | Description |
|--|--|
| `Window:CreateTab(cfg)` | Add a tab. Returns a Tab object. |
| `Window:Toggle()` | Show/hide window. |
| `Window:SetVisible(bool)` | Force-show or hide. |
| `Window:Minimize()` / `Window:Restore()` | Collapse to top bar. |
| `Window:Destroy()` | Tear everything down (disconnects, removes GUI). |
| `Window:SetTheme(name, animated?)` | Live theme switch (animated by default). |
| `Window:SetDPIScale(n)` | Resize UI (0.6 – 1.4). |
| `Window:SetAcrylic(bool, size?)` | Toggle blur backdrop. |
| `Window:Notify(cfg)` | See [Notifications](#notifications). |
| `Window:Prompt(cfg)` | Modal yes/no dialog. |
| `Window:SaveConfig(name)` / `LoadConfig` / `ListConfigs` / `DeleteConfig` | See [Config system](#config-system). |
| `Window:ExportConfig(name)` | Copy config JSON to clipboard. |
| `Window:ImportConfig(name, json)` | Save a JSON string as a config. |
| `Window:SetFlag(name, value)` / `Window:GetFlag(name)` | Programmatically change flag values. |
| `Window:RegisterCommand(name, fn)` | Add an entry to the Ctrl+K palette. |
| `Window:CreateFloatingWindow(cfg)` | Small auxiliary window. |
| `Window:CreateBindsList(cfg)` | Floating window listing active keybinds. |
| `Window:CreateStatusWindow(cfg)` | Floating window for live status. |
| `Window:CreateWatermark(cfg)` | FPS / status watermark. |
| `Window:SendWebhook(url, payload)` | Discord webhook helper. |

### Window signals

| Signal | Args |
|--|--|
| `Window.Signals.ThemeChanged` | `(themeName, themeTable)` |
| `Window.Signals.FlagChanged`  | `(flagName, value)` |
| `Window.Signals.Closed`       | `()` |
| `Window.Signals.VisibleChanged` | `(isVisible)` |

```lua
Window.Signals.FlagChanged:Connect(function(flag, val)
    print(flag, "=", val)
end)
```

## Tabs

```lua
local Tab = Window:CreateTab({
    Name        = "Main",
    IconText    = "★",            -- text/unicode icon (or use Icon=rbxassetid://)
    Icon        = "rbxassetid://123",  -- optional image icon
    Description = "Main features", -- shown in tooltip
})
```

Tab methods:

```lua
Tab:Select()      -- make this tab active
Tab:SetIcon(text) -- change icon
Tab:SetName(name) -- rename
Tab:Destroy()     -- remove the tab and its content
```

## Elements

All elements return an object with a unified base API:

| Method | Description |
|--|--|
| `obj:Get()` | Current value (where applicable). |
| `obj:Set(v)` | Programmatically set value & fire callback. |
| `obj:SetSilent(v)` | Set without firing callback (toggle/slider). |
| `obj:SetName(name)` | Rename the element. |
| `obj:SetDescription(text)` | Update the description sub-label. |
| `obj:SetTooltip(text)` | Add a hover tooltip. |
| `obj:SetVisible(bool)` | Hide/show. |
| `obj:Destroy()` | Remove the element. |

### Section

```lua
Tab:CreateSection("Combat")
Tab:CreateSection({ Name = "Visuals", Collapsible = true })
```

### Label

```lua
local lbl = Tab:CreateLabel("Hello world")
lbl:Set("Goodbye")
```

### Divider

```lua
Tab:CreateDivider()
```

### Paragraph

```lua
Tab:CreateParagraph({
    Title   = "Info",
    Content = "This is wrapped text that fits the tab width.",
})
```

### Button

```lua
Tab:CreateButton({
    Name        = "Reset",
    Description = "Optional second line",
    Callback    = function() print("clicked") end,
})
```

### Toggle

```lua
local tog = Tab:CreateToggle({
    Name        = "ESP",
    Description = "Highlight players through walls",
    Default     = false,
    Flag        = "esp",         -- saved/loaded by config system
    KeyBind     = Enum.KeyCode.B, -- optional global keybind
    KeyBindMode = "Toggle",       -- "Toggle" | "Hold" | "OnRelease"
    Callback    = function(state) print(state) end,
})

tog:Set(true)
print(tog:Get())
```

### Slider

```lua
Tab:CreateSlider({
    Name      = "FOV",
    Min       = 0, Max = 200,
    Default   = 90, Increment = 1, Decimals = 0,
    Suffix    = "°",
    Flag      = "fov",
    Callback  = function(v) print(v) end,
})
```

### RangeSlider

```lua
Tab:CreateRangeSlider({
    Name = "Spawn range",
    Min  = 0, Max = 100,
    DefaultMin = 20, DefaultMax = 80,
    Callback = function(lo, hi) print(lo, hi) end,
})
```

### Stepper

```lua
Tab:CreateStepper({
    Name = "Multiplier",
    Min = 1, Max = 10, Step = 0.5, Default = 1,
    Callback = function(v) print(v) end,
})
```

### Dropdown

```lua
Tab:CreateDropdown({
    Name     = "Weapon",
    Options  = { "Sword", "Bow", "Staff" },
    Default  = "Sword",
    Multi    = false,            -- set true for multi-select
    Searchable = false,          -- adds a filter box
    Callback = function(v) print(v) end,
})
```

#### SearchableDropdown

Shortcut for `Dropdown` with `Searchable = true`.

### Input

```lua
Tab:CreateInput({
    Name        = "Username",
    Placeholder = "Enter username…",
    Default     = "",
    NumbersOnly = false,
    Password    = false,
    MaxLength   = 32,
    Callback    = function(text) print(text) end,
})
```

### TextArea

```lua
Tab:CreateTextArea({
    Name = "Notes",
    Rows = 6,
    Callback = function(text) print(text) end,
})
```

### Keybind

```lua
Tab:CreateKeybind({
    Name      = "Aimbot",
    Default   = Enum.KeyCode.E,
    Modifiers = { "Ctrl" },        -- optional modifier list
    Mode      = "Hold",            -- "Toggle" | "Hold" | "OnRelease"
    Callback  = function(state) print(state) end,
})
```

Mouse buttons are supported: `Enum.UserInputType.MouseButton1`,
`MouseButton2`, `MouseButton3` (and any `M4`/`M5` via UserInputType).

### ColorPicker

```lua
Tab:CreateColorPicker({
    Name     = "Accent",
    Default  = Color3.fromRGB(120, 80, 220),
    Alpha    = true,        -- include alpha slider
    Callback = function(color, alpha) print(color, alpha) end,
})
```

Features: HSV box, hue strip, alpha strip (optional), hex input, RGB inputs,
before/after preview, recent colors row.

### ProgressBar

```lua
local bar = Tab:CreateProgressBar({ Name = "Progress", Default = 0.0 })
bar:Set(0.5)
```

### TagList

```lua
Tab:CreateTagList({
    Name = "Status",
    Tags = {
        "Beta",
        { Text = "Premium", Color = Color3.fromRGB(255, 200, 70) },
    },
})
```

### RadioGroup

```lua
Tab:CreateRadioGroup({
    Name    = "Side",
    Options = { "Left", "Right" },
    Default = "Left",
    Callback = function(v) print(v) end,
})
```

### Segmented

```lua
Tab:CreateSegmented({
    Name    = "Speed",
    Options = { "1x", "2x", "4x" },
    Default = "1x",
    Callback = function(v) print(v) end,
})
```

### Image

```lua
Tab:CreateImage({ Image = "rbxassetid://123", Height = 120 })
```

## Notifications

```lua
Window:Notify({
    Title    = "Hello",
    Content  = "This is a notification.",
    Type     = "Info",          -- "Success" | "Error" | "Warning" | "Info"
    Duration = 5,
    Actions  = {
        { Text = "Confirm", Callback = function() print("confirmed") end },
        { Text = "Dismiss", Callback = function() end },
    },
})

NexusUI:Notify({ Title = "Quick", Content = "Forwards to last active window." })
```

Up to 6 notifications are shown at once; the rest queue.

## Themes

Built-in themes: `Dark`, `Light`, `Purple`, `Ocean`, `Blood`, `Midnight`, `Forest`.

```lua
NexusUI.GetThemes()    -- list of available names
Window:SetTheme("Ocean", true)   -- animated transition
```

### Custom themes

```lua
NexusUI.RegisterTheme("MyTheme", {
    Background = Color3.fromRGB(15, 20, 30),
    Secondary  = Color3.fromRGB(22, 28, 40),
    -- ...all 24+ keys; missing keys fall back to Dark
})
Window:SetTheme("MyTheme")
```

Or pass the table directly:

```lua
Window = NexusUI:CreateWindow({ Theme = { Background = Color3.new(0,0,0), ... } })
```

## Search & command palettes

- **Ctrl+F** opens search: type to filter tabs + elements + flag names. Click
  a result to jump to it.
- **Ctrl+K** opens commands: pick any registered command. Built-ins include
  *Toggle window*, *Minimize*, *Close*, *Reload theme*. Add your own:

```lua
Window:RegisterCommand("Set high-FPS preset", function()
    Window:GetFlag("fov"):set(120)
end)
```

## Watermark & floating windows

```lua
local wm = Window:CreateWatermark({ Text = "MyHub %fps fps" })
wm:SetText("custom")
wm:Destroy()

local fw = Window:CreateFloatingWindow({ Title = "Stats", Visible = true })
fw:AddLabel("Players: 0")
fw:AddStatus({ Name = "Online", Color = Color3.fromRGB(0, 255, 0) })
fw:AddButton({ Text = "Reset", Callback = function() end })

Window:CreateBindsList({ Title = "Binds" })       -- auto-updates active binds
Window:CreateStatusWindow({ Title = "Status" })   -- visible toggle markers
```

## Config system

Per-game subfolders are created under `ConfigFolder/<PlaceId>/`.

```lua
Window:SaveConfig("default")
Window:LoadConfig("default")
Window:ListConfigs()           -- { "default", "pvp", "raid" }
Window:DeleteConfig("pvp")
Window:ExportConfig("default") -- copies JSON to clipboard
Window:ImportConfig("imported", jsonString)
```

`AutoLoad` and `AutoSave` settings on the window automate this.

Flags supported: `toggle`, `slider`, `range`, `dropdown`, `multidropdown`,
`string`, `color`, `keybind`, `number`.

## Webhooks & update checker

```lua
Window:SendWebhook("https://discord.com/api/webhooks/...", {
    username = "NexusUI",
    content  = "Hello!",
})

local hasUpdate, latestVersion = NexusUI:CheckUpdate(
    "https://raw.githubusercontent.com/Pablososkivich/NexusUI/main/VERSION"
)
```

## Splash screen

```lua
local splash = NexusUI:Splash({
    Title    = "MyHub",
    Subtitle = "Loading…",
    Duration = 2.5,            -- auto-close after N seconds
})
splash:SetProgress(0.5)
splash:Close()
```

## Migration from v3

See [`CHANGELOG.md`](CHANGELOG.md) for breaking changes, but the short list:

- `CreateButton(text, callback)` → `CreateButton({ Name = …, Callback = … })`
- Every element now returns an object with `:Get()`, `:Set()`, `:Destroy()`.
- `NexusUI:Notify` now forwards to the active window's queue (no global `Theme` leak).
- Keybind reassignments are persisted in `Flags`.
- Theme can be switched at runtime; v3 required full reload.

## License

MIT. Use it, modify it, ship it. Attribution appreciated but not required.
