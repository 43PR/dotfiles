-- ~/.config/hypr/rules.lua
-- Migrated from rules.conf
-- Docs: https://wiki.hypr.land/Configuring/Basics/Window-Rules/

local window_opacity = 0.7

hl.layer_rule({
    match = { namespace = "rofi" },
    blur = true,
    ignore_alpha = 0.15,
})

-- Opacity rule for your regular apps
hl.window_rule({
    name = "opacity-apps",
    match = {
        class = "^(kitty|xed|thunar|brave-browser|discord|codium|GeForceNOW|obsidian|Spotify|org.pulseaudio.pavucontrol|com.github.johnfactotum.Foliate)$",
    },
    opacity = window_opacity .. " override " .. window_opacity .. " override 1.0 override",
})

hl.window_rule({
    name = "float-pavucontrol",
    match = { class = "^(pavucontrol)$" },
    float = true,
})

hl.window_rule({
    name = "float-nm-connection-editor",
    match = { class = "^(nm-connection-editor)$" },
    float = true,
})

hl.window_rule({
    name = "float-blueman-manager",
    match = { class = "^(blueman-manager)$" },
    float = true,
})

hl.window_rule({
    name = "float-open-file",
    match = { title = "^(Open File)$" },
    float = true,
})

hl.window_rule({
    name = "float-save-file",
    match = { title = "^(Save File)$" },
    float = true,
})
