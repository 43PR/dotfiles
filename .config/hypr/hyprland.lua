-- ~/.config/hypr/hyprland.lua
-- Docs: https://wiki.hypr.land/Configuring/Start/

---- MY PROGRAMS ----

mainMod    = "SUPER"
terminal   = "kitty"
menu       = "rofi -show drun"
fileManager = "thunar"
browser    = "brave"

-- Overrides written by Quickshell (Settings > Configs): mainMod, browser.
-- Must load before keybinds.lua, which reads these globals when binding.
do
    local f = os.getenv("HOME") .. "/.config/quickshell/state/prefs.lua"
    local fh = io.open(f, "r")
    if fh then
        fh:close()
        local ok, err = pcall(dofile, f)
        if not ok then print("state/prefs.lua failed: " .. tostring(err)) end
    end
end

---- AUTOSTART ----

hl.on("hyprland.start", function()
    -- hl.exec_cmd("dunst") replaced with quickshell
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")

    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("~/.config/hypr/scripts/wallpaper-restore.sh")
    hl.exec_cmd("sleep 2 && QSG_RENDER_LOOP=basic QS_ICON_THEME=Papirus qs")
end)

---- ENVIRONMENT VARIABLES ----

hl.env("XCURSOR_SIZE", "14")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")

---- INPUT ----

hl.config({
    input = {
        kb_layout = "us,latam",
        follow_mouse = 1,
        sensitivity = 0.5,
        touchpad = {
            natural_scroll = false,
            tap_to_click = true,
        },
    },
})

-- LAYOUT
hl.config({
    dwindle = { preserve_split = true },
})
hl.config({
    master = { new_status = "master" },
})

-- MISC
hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})

local f = os.getenv("HOME") .. "/.config/quickshell/state/devices.lua"
if io.open(f, "r") then dofile(f) end

---- SPLIT-OUT FILES ----

require("monitors")
require("keybinds")
require("look")
do
    local f = os.getenv("HOME") .. "/.config/quickshell/state/look.lua"
    local fh = io.open(f, "r")
    if fh then
        fh:close()
        local ok, err = pcall(dofile, f)
        if not ok then print("state/look.lua failed: " .. tostring(err)) end
    end
end
require("rules")

-- HyprMod managed settings
require("hyprland-gui")
