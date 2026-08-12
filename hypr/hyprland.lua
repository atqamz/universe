hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")

local function scheme_colour(key, fallback)
    local f = io.open(os.getenv("HOME") .. "/.local/state/caelestia/scheme.json")
    if not f then return fallback end
    local data = f:read("a")
    f:close()
    return data:match('"' .. key .. '"%s*:%s*"(%x+)"') or fallback
end

hl.config({
    general = {
        gaps_in = 0,
        gaps_out = 0,
        border_size = 0,
        layout = "dwindle",
        col = {
            active_border = "rgba(" .. scheme_colour("primary", "c2c1ff") .. "ee)",
            inactive_border = "rgba(" .. scheme_colour("surfaceContainerHigh", "2a292e") .. "aa)",
        },
    },
    animations = {
        enabled = false,
    },
    misc = {
        disable_autoreload = true,
    },
    input = {
        kb_file = "/home/atqa/dotfiles/hypr/caps-ctrl.xkb",
        follow_mouse = 1,
        touchpad = { natural_scroll = true },
    },
})

hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default", style = "slidevert" })

hl.window_rule({ match = { float = true, xwayland = false }, center = true })

hl.gesture({ fingers = 3, direction = "vertical", action = "workspace" })

local mod = "SUPER"
local terminal = "foot"
local fileExplorer = "thunar"

hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + CTRL + Return", hl.dsp.exec_cmd("wezterm"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(fileExplorer))
hl.bind(mod .. " + C", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mod .. " + Space", hl.dsp.global("caelestia:launcher"))
hl.bind(mod .. " + L", hl.dsp.global("caelestia:session"))
hl.bind(mod .. " + SHIFT + L", hl.dsp.global("caelestia:lock"))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("caelestia clipboard"))
hl.bind(mod .. " + ALT + V", hl.dsp.exec_cmd([[sh -c 'cliphist wipe && notify-send Clipboard "History cleared" || true']]))
hl.bind(mod .. " + period", hl.dsp.exec_cmd("caelestia emoji --picker"))
hl.bind(mod .. " + ALT + P", hl.dsp.exec_cmd("passmenu"))
hl.bind(mod .. " + R", hl.dsp.exec_cmd("reading-mode"))

hl.bind(mod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mod .. " + Q", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + SHIFT + left", hl.dsp.window.swap({ direction = "l" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.swap({ direction = "u" }))
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.swap({ direction = "d" }))
hl.bind(mod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })
hl.bind(mod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true })

hl.bind(mod .. " + G", hl.dsp.group.toggle())
hl.bind(mod .. " + ALT + G", hl.dsp.window.move({ out_of_group = true }))
hl.bind(mod .. " + ALT + left", hl.dsp.window.move({ into_group = "l" }))
hl.bind(mod .. " + ALT + right", hl.dsp.window.move({ into_group = "r" }))
hl.bind(mod .. " + ALT + up", hl.dsp.window.move({ into_group = "u" }))
hl.bind(mod .. " + ALT + down", hl.dsp.window.move({ into_group = "d" }))
hl.bind(mod .. " + CTRL + left", hl.dsp.group.prev())
hl.bind(mod .. " + CTRL + right", hl.dsp.group.next())

hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" }))
hl.bind("CTRL + ALT + Tab", hl.dsp.focus({ monitor = "+1" }))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mod .. " + 1", hl.dsp.focus({ workspace = "1" }))
hl.bind(mod .. " + 2", hl.dsp.focus({ workspace = "2" }))
hl.bind(mod .. " + 3", hl.dsp.focus({ workspace = "3" }))
hl.bind(mod .. " + 4", hl.dsp.focus({ workspace = "4" }))
hl.bind(mod .. " + 5", hl.dsp.focus({ workspace = "5" }))
hl.bind(mod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = "1" }))
hl.bind(mod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = "2" }))
hl.bind(mod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = "3" }))
hl.bind(mod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = "4" }))
hl.bind(mod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = "5" }))

hl.bind("XF86AudioNext", hl.dsp.global("caelestia:mediaNext"))
hl.bind("XF86AudioPrev", hl.dsp.global("caelestia:mediaPrev"))
hl.bind("XF86AudioPlay", hl.dsp.global("caelestia:mediaToggle"))
hl.bind("Print", hl.dsp.global("caelestia:screenshotClip"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.global("caelestia:screenshot"))

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize())
hl.bind(mod .. " + SHIFT + mouse:272", hl.dsp.window.resize())

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.global("caelestia:brightnessUp"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.global("caelestia:brightnessDown"), { locked = true, repeating = true })

local function host_name()
    local h
    local f = io.open("/etc/hostname")
    if f then h = f:read("l"); f:close() end
    if not h or h == "" then h = os.getenv("HOSTNAME") end
    return h and h:match("^[^.%s]+") or nil
end

local host = host_name()
if host then
    local ok, err = pcall(require, "hosts." .. host)
    if not ok then
        print("hyprland.lua: host module 'hosts." .. host .. "' failed: " .. tostring(err))
    end
else
    print("hyprland.lua: could not resolve hostname; no per-host config loaded")
end
