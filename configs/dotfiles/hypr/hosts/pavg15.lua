hl.monitor({ output = "eDP-1", mode = "1920x1080@144", position = "auto", scale = 1 })
require("workspace_grid").setup({
    { monitor = "eDP-1", first = 1 },
})
