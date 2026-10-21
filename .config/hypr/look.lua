-- ~/.config/hypr/look.lua
---- LOOK AND FEEL ----
local colors = { active = "rgba(FFFFFFFF)", inactive = "rgba(33333366)" }
local ok, c = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/colors.lua")
if ok and type(c) == "table" then colors = c end

hl.config({ render = { expand_undersized_textures = false}})
hl.config({
    general = {
        gaps_in = 4,
        gaps_out = {
            top = 5,
            right = 8,
            bottom = 8,
            left = 8,
        },
        border_size = 1,
        col = {
            active_border   = colors.active,
            inactive_border = colors.inactive,
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 8,
        blur = {
            enabled = true,
            size = 5,
            passes = 1,
            vibrancy = 0.2,
        },
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
        },
    },
    animations = {
        enabled = true,
    },
})

hl.curve("easeOut", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.0} } })

hl.animation({ leaf = "windows",    enabled = true, speed = 5, bezier = "easeOut" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "easeOut" })
hl.animation({ leaf = "border",     enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default", style = "slidefadevert" }) -- styles: "slide", "slidefade", "slidevert", "slidefadevert"

