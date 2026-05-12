--[[
    NexusUI v4 — demo / showcase
    Press RightShift to toggle the window.
    Press Ctrl+F to search elements, Ctrl+K to run commands.
]]

local NexusUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Pablososkivich/NexusUI/main/NexusUI.lua"
))()

-- ░░░ Optional splash screen ░░░
local splash = NexusUI:Splash({
    Title    = "NexusUI Demo",
    Subtitle = "Loading components…",
    Duration = 1.5,
})

-- ░░░ Window ░░░
local Window = NexusUI:CreateWindow({
    Title        = "NexusUI",
    Subtitle     = "v4 — full showcase",
    Size         = UDim2.new(0, 720, 0, 520),
    Theme        = "Dark",
    KeyBind      = Enum.KeyCode.RightShift,
    ConfigFolder = "NexusUI",
    Acrylic      = false,
    Sounds       = false,
    Resizable    = true,
    SnapToEdges  = true,
    Watermark    = true,
    DPIScale     = 1,
})

-- ────────────────────────────────────────────────
-- Tab: Main  (button / toggle / slider / range)
-- ────────────────────────────────────────────────
local Main = Window:CreateTab({ Name = "Main", IconText = "★",
    Description = "Common controls" })

Main:CreateSection({ Name = "Buttons" })
Main:CreateButton({
    Name = "Notify",
    Description = "Triggers a Success notification",
    Callback = function()
        Window:Notify({
            Title = "Hello", Content = "Notifications support actions!",
            Type = "Success", Duration = 5,
            Actions = {
                { Text = "Cool",   Callback = function() print("Cool")   end },
                { Text = "Cancel", Callback = function() print("Cancel") end },
            },
        })
    end,
})
Main:CreateButton({
    Name = "Prompt",
    Callback = function()
        Window:Prompt({
            Title = "Delete?", Content = "Are you sure?",
            Yes = "Delete", No = "Cancel",
            Callback = function(ok) print("user said:", ok) end,
        })
    end,
})

Main:CreateSection({ Name = "Toggles" })
Main:CreateToggle({
    Name = "Auto-farm", Description = "Bound to Ctrl+B",
    Default = false, Flag = "autofarm",
    KeyBind = Enum.KeyCode.B, KeyBindModifiers = { "Ctrl" },
    KeyBindMode = "Toggle",
    Callback = function(v) print("auto-farm:", v) end,
})
Main:CreateToggle({
    Name = "ESP", Default = false, Flag = "esp",
    Callback = function(v) print("esp:", v) end,
})

Main:CreateSection({ Name = "Sliders" })
Main:CreateSlider({
    Name = "FOV", Min = 0, Max = 200, Default = 90, Increment = 1, Suffix = "°",
    Flag = "fov",
    Callback = function(v) print("FOV =", v) end,
})
Main:CreateRangeSlider({
    Name = "Spawn weight", Min = 0, Max = 100,
    DefaultMin = 20, DefaultMax = 80, Increment = 1,
    Callback = function(lo, hi) print(lo, "-", hi) end,
})
Main:CreateStepper({
    Name = "Multiplier", Min = 1, Max = 10, Step = 0.25, Default = 2.0, Decimals = 2,
    Callback = function(v) print("mul =", v) end,
})

local progress = Main:CreateProgressBar({ Name = "Loading", Default = 0 })
task.spawn(function()
    for i = 0, 100 do
        if not Window.Alive then return end
        progress:Set(i / 100)
        task.wait(0.04)
    end
end)

-- ────────────────────────────────────────────────
-- Tab: Inputs
-- ────────────────────────────────────────────────
local Inputs = Window:CreateTab({ Name = "Inputs", IconText = "✎" })

Inputs:CreateInput({
    Name = "Username", Placeholder = "Enter your username…",
    Callback = function(t) print("input:", t) end,
})
Inputs:CreateInput({
    Name = "Password", Placeholder = "••••••••",
    Password = true, MaxLength = 32,
    Callback = function(t) print("password length:", #t) end,
})
Inputs:CreateTextArea({
    Name = "Notes", Rows = 4,
    Callback = function(t) print("notes:", t) end,
})

Inputs:CreateSection({ Name = "Dropdowns" })
Inputs:CreateDropdown({
    Name = "Weapon", Options = { "Sword", "Bow", "Staff", "Hammer" },
    Default = "Sword",
    Callback = function(v) print("weapon:", v) end,
})
Inputs:CreateSearchableDropdown({
    Name = "Players", Options = { "Player1", "Player2", "Player3", "Player4" },
    Multi = true,
    Callback = function(list) print("selected:", table.concat(list, ", ")) end,
})

Inputs:CreateSection({ Name = "Selectors" })
Inputs:CreateRadioGroup({
    Name = "Side", Options = { "Left", "Right" }, Default = "Left",
    Callback = function(v) print("side:", v) end,
})
Inputs:CreateSegmented({
    Name = "Speed", Options = { "1x", "2x", "4x" }, Default = "1x",
    Callback = function(v) print("speed:", v) end,
})

-- ────────────────────────────────────────────────
-- Tab: Visuals
-- ────────────────────────────────────────────────
local Visuals = Window:CreateTab({ Name = "Visuals", IconText = "🎨" })

Visuals:CreateColorPicker({
    Name = "Accent", Default = Color3.fromRGB(120, 80, 220), Alpha = false,
    Callback = function(c) print("accent:", c) end,
})
Visuals:CreateColorPicker({
    Name = "Highlight (with alpha)",
    Default = Color3.fromRGB(255, 100, 100), Alpha = true,
    Callback = function(c, a) print("highlight:", c, "alpha:", a) end,
})

Visuals:CreateTagList({
    Name = "Status",
    Tags = {
        "Beta",
        { Text = "Premium", Color = Color3.fromRGB(255, 200, 70) },
        { Text = "Active",  Color = Color3.fromRGB(70, 200, 120) },
    },
})

Visuals:CreateSection({ Name = "Information", Collapsible = true })
Visuals:CreateParagraph({
    Title = "About NexusUI v4",
    Content = "A professional UI library for Roblox. Press Ctrl+F to search," ..
              " Ctrl+K for commands. Use the Settings tab to switch themes," ..
              " adjust the UI scale, or save your config.",
})

-- ────────────────────────────────────────────────
-- Tab: Keybinds
-- ────────────────────────────────────────────────
local Keys = Window:CreateTab({ Name = "Keys", IconText = "⌨" })
Keys:CreateKeybind({
    Name = "Aim assist", Default = Enum.KeyCode.E, Mode = "Hold",
    Callback = function(state) print("aim assist:", state) end,
})
Keys:CreateKeybind({
    Name = "Quick action", Default = Enum.KeyCode.F, Mode = "OnRelease",
    Callback = function() print("quick fired") end,
})

-- ────────────────────────────────────────────────
-- Register a custom command for Ctrl+K
-- ────────────────────────────────────────────────
Window:RegisterCommand("Demo: change to Ocean theme", function()
    Window:SetTheme("Ocean", true)
end)
Window:RegisterCommand("Demo: change to Dark theme", function()
    Window:SetTheme("Dark", true)
end)

-- ────────────────────────────────────────────────
-- Floating windows
-- ────────────────────────────────────────────────
local statusFW = Window:CreateFloatingWindow({
    Title = "Stats", Visible = true,
})
statusFW:AddLabel("Players online: 12")
statusFW:AddStatus({ Name = "Connected", Color = Color3.fromRGB(0, 220, 100) })
statusFW:AddButton({ Text = "Reset stats", Callback = function()
    Window:Notify({ Title = "Reset", Content = "Stats reset", Type = "Info" })
end })

Window:CreateBindsList({ Title = "Active keybinds" })

-- ────────────────────────────────────────────────
-- Welcome notification
-- ────────────────────────────────────────────────
task.delay(0.3, function()
    Window:Notify({
        Title = "Welcome", Content = "Try Ctrl+F or Ctrl+K.",
        Type = "Info", Duration = 6,
    })
end)
