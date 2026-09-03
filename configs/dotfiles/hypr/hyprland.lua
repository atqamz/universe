hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")

hl.config({
    general = {
        gaps_in = 0,
        gaps_out = 0,
        border_size = 0,
        layout = "dwindle",
        col = {
            active_border = "rgba(c2c1ffee)",
            inactive_border = "rgba(2a292eaa)",
        },
    },
    animations = {
        enabled = false,
    },
    misc = {
        disable_autoreload = true,
    },
    input = {
        kb_file = "/home/atqa/universe/configs/dotfiles/hypr/caps-ctrl.xkb",
        follow_mouse = 1,
        touchpad = { natural_scroll = true },
    },
})

hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default", style = "slidevert" })

hl.window_rule({ match = { float = true, xwayland = false }, center = true })

local mod = "SUPER"
local terminal = "foot"
local fileExplorer = "thunar"

hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + CTRL + Return", hl.dsp.exec_cmd("wezterm"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(fileExplorer))
hl.bind(mod .. " + C", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mod .. " + Space", hl.dsp.exec_cmd("omanixy-shell shell toggle omarchy.menu"))
hl.bind(mod .. " + SHIFT + L", hl.dsp.exec_cmd("omanixy-shell lock lock"))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("clipboard-picker"))
hl.bind(mod .. " + ALT + V", hl.dsp.exec_cmd("clipboard-wipe"))
hl.bind(mod .. " + period", hl.dsp.exec_cmd("emoji-picker"))
hl.bind(mod .. " + ALT + P", hl.dsp.exec_cmd("passmenu"))
hl.bind(mod .. " + R", hl.dsp.exec_cmd("reading-mode"))
hl.bind(mod .. " + ALT + D", hl.dsp.exec_cmd("hyprwhspr record toggle"))

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

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("media-next"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("media-previous"))
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("media-play-pause"))
hl.bind("Print", hl.dsp.exec_cmd("screenshot-clipboard"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("screenshot-region"))

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize())
hl.bind(mod .. " + SHIFT + mouse:272", hl.dsp.window.resize())

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightness-up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightness-down"), { locked = true, repeating = true })

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
