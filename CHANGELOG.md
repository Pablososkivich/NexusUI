# Changelog

All notable changes to **NexusUI** are documented in this file.

## [4.0.0] — 2025-XX-XX

A full rewrite. NexusUI v3 was a 2700-line single file with a number of
latent bugs (global state leaks, connection leaks, performance spikes during
slider drag, etc.) and was missing many features that modern Roblox UI
libraries provide. v4 addresses all of those and adds a long list of new
features.

### Bug fixes (P0)

- **No more global `Theme` leak.** `NexusUI:Notify` and every internal helper
  now receive their theme through a per-window `_tracker` (theme tracker)
  rather than referencing the most recently-created window's locals.
- **Leak-free `MakeDraggable`.** Returns a cleanup function that disconnects
  `InputBegan`, `InputChanged`, `InputEnded`. v3 left a global
  `UserInputService.InputChanged` listener attached forever per drag.
- **Leak-free `Ripple`.** Effect frames are cleaned up immediately after the
  fade animation; no dangling tweens.
- **`BindShadow` no longer uses `RenderStepped`.** Shadows update via
  `GetPropertyChangedSignal` on `AbsolutePosition`, `AbsoluteSize`, and
  `Visible`. v3 ran a 60 Hz update loop per shadowed element.
- **Slider/RangeSlider no longer spam Tween calls.** Direct assignment is used
  during drag, Tween only for animated initial reveal.
- **Toggle/Slider always fire callback with their initial value** on
  creation, so consumer-side state stays in sync.
- **Keybind reassignments are now saved** in the `Flags` table as
  `<name>_keybind` entries. v3 lost custom keybinds on save/load.
- **CoreGui fallback chain**: tries `gethui()` → `syn.protect_gui()` →
  `get_hidden_gui()` → `CoreGui` → `PlayerGui:WaitForChild("PlayerGui")`.
  v3 hardcoded `CoreGui` and crashed on executors without that permission.
- **Notification queue limit (6)** with a close button on each, and an
  internal pending list so notifications don't pile up indefinitely.

### Architecture (P1)

- All elements now return objects implementing a unified API:
  `:Get()`, `:Set()`, `:SetSilent()`, `:SetName()`, `:SetDescription()`,
  `:SetTooltip()`, `:SetVisible()`, `:Destroy()`, plus element-specific extras.
- All config tables are strictly named-key (`{ Name = ..., Callback = ... }`).
  v3 mixed positional and named-key APIs.
- Custom themes can be passed directly to `CreateWindow({ Theme = table })`
  or registered globally via `NexusUI.RegisterTheme(name, table)`.
- Runtime `Window:SetTheme(name, animated)` with an animated colour-tween
  across every tracked instance.
- Keybinds accept modifiers (`Ctrl`, `Shift`, `Alt`), mouse buttons
  (`MouseButton1/2/3`), and modes (`Toggle`, `Hold`, `OnRelease`).
- Per-game config storage. Saved files live under
  `<ConfigFolder>/<PlaceId>/<name>.json`.
- Clipboard import (`Window:ExportConfig`) / export (`Window:ImportConfig`).
- A built-in **Settings** tab with theme selector, UI scale slider,
  acrylic toggle, sound toggle, toggle keybind, config save/load/delete/copy,
  and an About paragraph.

### New elements (P2)

- `Tab:CreateRangeSlider(...)` — two-handle slider.
- `Tab:CreateStepper(...)` — number input with ± buttons and direct entry.
- `Tab:CreateTextArea(...)` — multi-line text input.
- `Tab:CreateProgressBar(...)` — animated bar with `:Set(0..1)`.
- `Tab:CreateTagList(...)` — chips/badges.
- `Tab:CreateRadioGroup(...)` — radio-style options.
- `Tab:CreateSegmented(...)` — segmented control.
- `Tab:CreateSearchableDropdown(...)` — dropdown with a search field.
- `Tab:CreateImage(...)` — image element.
- `Tab:CreateSection({ Name = ..., Collapsible = true })` — collapsible
  section headers.

### Major features (P3)

- **Resizable window** with bottom-right handle and per-axis clamping.
- **Snap-to-edges** when dragging the window near screen edges.
- **Search palette** (Ctrl+F): substring matching across tabs, elements, and
  flag names; results jump straight to the matching element.
- **Command palette** (Ctrl+K): registered commands via
  `Window:RegisterCommand(name, fn)` plus built-ins (toggle window,
  minimize, close, reload theme).
- **Notification queue** with per-notification action buttons.
- **ColorPicker** upgrade: HSV box, hue strip, optional alpha strip, hex
  input, RGB inputs, before/after preview, and recent colors row.
- **Update checker**: `NexusUI:CheckUpdate(versionUrl)`.
- **Webhook helper**: `Window:SendWebhook(url, payload)`.
- **Splash screen**: `NexusUI:Splash({ Title, Subtitle, Duration })`.

### Visual polish (P4)

- **Two-layer shadow** (ambient + key light) using
  `GetPropertyChangedSignal` instead of RenderStepped.
- **Acrylic blur** backdrop (uses `Lighting.BlurEffect`, togglable).
- **Glow pulse** animation on toggle activation.
- **Hint tooltip** appears above slider knob while dragging.
- **Animated accent gradient** line on the top bar.
- **Lucide-style unicode icons** (`NexusUI.GetIcon("home")`, etc.).
- **Sound effects** (opt-in via `Sounds = true`).

### Migration notes (breaking changes from v3 → v4)

| v3 API | v4 API |
|--|--|
| `CreateButton("Text", function() end)` | `CreateButton({ Name = "Text", Callback = function() end })` |
| `CreateToggle("Name", default, cb)` | `CreateToggle({ Name = "Name", Default = default, Callback = cb })` |
| `CreateSlider("Name", min, max, default, cb)` | `CreateSlider({ Name = "Name", Min = min, Max = max, Default = default, Callback = cb })` |
| `CreateDropdown("Name", options, default, cb)` | `CreateDropdown({ Name = "Name", Options = options, Default = default, Callback = cb })` |
| `CreateColorPicker("Name", default, cb)` | `CreateColorPicker({ Name = "Name", Default = default, Callback = cb })` |
| `obj.Value` field reads | `obj:Get()` method |
| `obj:Update(value)` | `obj:Set(value)` |

Old v3 scripts will not run unmodified; the rewrite was approved by the
maintainer as a hard break.

---

## [3.0.0] — earlier

Legacy library. See pastebin V3faRAng for the original code.
