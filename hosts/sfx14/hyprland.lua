-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
-- Your own gestures replace Omarchy's defaults.
omarchy_default_gestures = false

require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })
o.window("google-chrome", { focus_on_activate = false })

-- AQ_DRM_DEVICES (keep Hyprland off the NVIDIA nodes so the dGPU can reach
-- D3cold) is set in ~/.config/uwsm/env.d/50-aq-drm-devices.sh, not here:
-- aquamarine splits it on ':' and ',', which breaks the by-path symlink, and a
-- config env line would only clobber the corrected value.
