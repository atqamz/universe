local mod = "SUPER"

hl.monitor({ output = "eDP-1", mode = "2160x1350@120", position = "0x0", scale = 1 })
hl.monitor({ output = "DP-1", mode = "2160x1350@60", position = "-2160x0", scale = 1 })

hl.config({ input = { touchdevice = { output = "DP-1" }, tablet = { output = "DP-1" } } })

hl.device({ name = "ilitek-ilitek-tp", output = "DP-1" })
hl.device({ name = "ilitek-ilitek-tp-mouse", output = "DP-1", enabled = true })
hl.device({ name = "syna7db5:00-06cb:ceb1-touchpad", accel_profile = "custom 0.5 0.0 1.0 2.0 3.0" })

hl.bind(mod .. " + SHIFT + comma", hl.dsp.exec_cmd([[hyprctl eval 'hl.monitor({output="DP-1", mode="2160x1350@60", position="-2160x0", scale=1})']]))
hl.bind(mod .. " + SHIFT + period", hl.dsp.exec_cmd([[hyprctl eval 'hl.monitor({output="DP-1", mode="2160x1350@60", position="2160x0", scale=1})']]))
