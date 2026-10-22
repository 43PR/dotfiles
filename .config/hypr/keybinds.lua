-- ~/.config/hypr/keybinds.lua
-- Docs: https://wiki.hypr.land/Configuring/Basics/Binds/
--       https://wiki.hypr.land/Configuring/Basics/Dispatchers/

-- Defaults. Overrides come from state/binds.lua as kb_* (never reuse
-- terminal/browser — those globals are the program names from hyprland.lua).
local terminal_key      = "T"
local launcher_key      = "D"
local wheel_key         = "S"
local files_key         = "E"
local browser_key       = "B"
local close_key         = "Q"
local lock_key          = "Tab"
local power_key         = "GRAVE"
local settings_key      = "I"
local wallpapers_key    = "W"
local colorpicker_key   = "SHIFT + C"
local fullscreen_key    = "F"
local opacity_key       = "O"
local theme_key         = "period"
local notifications_key = "N"
local todo_key          = "C"
local bar_key           = "SHIFT + W"
local clipboard_key     = "V"
local layout_key        = "X"
local float_key         = "Space"
local record_key        = "R"
local shot_key          = "Delete"
local shot_area_key     = "SHIFT + Delete"

do
    local f = os.getenv("HOME") .. "/.config/quickshell/state/binds.lua"
    local fh = io.open(f, "r")
    if fh then
        fh:close()
        local ok, err = pcall(dofile, f)
        if not ok then
            print("state/binds.lua failed: " .. tostring(err))
        else
            if kb_terminal      then terminal_key      = kb_terminal end
            if kb_launcher      then launcher_key      = kb_launcher end
            if kb_wheel         then wheel_key         = kb_wheel end
            if kb_files         then files_key         = kb_files end
            if kb_browser       then browser_key       = kb_browser end
            if kb_close         then close_key         = kb_close end
            if kb_lock          then lock_key          = kb_lock end
            if kb_power         then power_key         = kb_power end
            if kb_settings      then settings_key      = kb_settings end
            if kb_wallpapers    then wallpapers_key    = kb_wallpapers end
            if kb_colorpicker   then colorpicker_key   = kb_colorpicker end
            if kb_fullscreen    then fullscreen_key    = kb_fullscreen end
            if kb_opacity       then opacity_key       = kb_opacity end
            if kb_theme         then theme_key         = kb_theme end
            if kb_notifications then notifications_key = kb_notifications end
            if kb_todo          then todo_key          = kb_todo end
            if kb_bar           then bar_key           = kb_bar end
            if kb_clipboard     then clipboard_key     = kb_clipboard end
            if kb_layout        then layout_key        = kb_layout end
            if kb_float         then float_key         = kb_float end
            if kb_record        then record_key        = kb_record end
            if kb_shot          then shot_key          = kb_shot end
            if kb_shot_area     then shot_area_key     = kb_shot_area end
        end
    end
end

-- Symbols are not valid Hyprland key names, so map them to their xkb keysym
-- names. The settings GUI can emit them (e.g. "." for the theme bind), and an
-- unparsable key string otherwise aborts the rest of this file.
local keysym_names = {
    ["."] = "period",
    [","] = "comma",
    ["/"] = "slash",
    ["-"] = "minus",
    ["="] = "equal",
    [";"] = "semicolon",
    ["'"] = "apostrophe",
    ["`"] = "GRAVE",
    ["["] = "bracketleft",
    ["]"] = "bracketright",
    ["\\"] = "backslash",
}

local function normalize_key(value)
    local text = tostring(value or "")
    local whole = text:match("^%s*(.-)%s*$")
    if keysym_names[whole] then
        return keysym_names[whole]
    end

    local parts = {}
    for token in text:gmatch("[^+]+") do
        local trimmed = token:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
            parts[#parts + 1] = keysym_names[trimmed] or trimmed
        end
    end
    if #parts == 0 then
        return whole
    end
    return table.concat(parts, " + ")
end

terminal_key      = normalize_key(terminal_key)
launcher_key      = normalize_key(launcher_key)
wheel_key         = normalize_key(wheel_key)
files_key         = normalize_key(files_key)
browser_key       = normalize_key(browser_key)
close_key         = normalize_key(close_key)
lock_key          = normalize_key(lock_key)
power_key         = normalize_key(power_key)
settings_key      = normalize_key(settings_key)
wallpapers_key    = normalize_key(wallpapers_key)
colorpicker_key   = normalize_key(colorpicker_key)
fullscreen_key    = normalize_key(fullscreen_key)
opacity_key       = normalize_key(opacity_key)
theme_key         = normalize_key(theme_key)
notifications_key = normalize_key(notifications_key)
todo_key          = normalize_key(todo_key)
bar_key           = normalize_key(bar_key)
clipboard_key     = normalize_key(clipboard_key)
layout_key        = normalize_key(layout_key)
float_key         = normalize_key(float_key)
record_key        = normalize_key(record_key)
shot_key          = normalize_key(shot_key)
shot_area_key     = normalize_key(shot_area_key)

-- A single bad key string must not take the rest of the config down with it.
local function bind(keys, ...)
    local ok, err = pcall(hl.bind, keys, ...)
    if not ok then
        print("keybinds.lua: skipped bind '" .. tostring(keys) .. "': " .. tostring(err))
    end
end

local home = os.getenv("HOME")
local menu = "rofi -show drun"

bind(mainMod .. " + " .. terminal_key,      hl.dsp.exec_cmd(terminal))
bind(mainMod .. " + " .. launcher_key,      hl.dsp.exec_cmd("pgrep -x rofi >/dev/null && pkill -x rofi || " .. menu))
bind(mainMod .. " + " .. wheel_key,         hl.dsp.exec_cmd("qs ipc call wheel toggle"))
bind(mainMod .. " + " .. files_key,         hl.dsp.exec_cmd(fileManager))
bind(mainMod .. " + " .. browser_key,       hl.dsp.exec_cmd(browser))
bind(mainMod .. " + " .. close_key,         hl.dsp.window.close())
bind(mainMod .. " + " .. lock_key,          hl.dsp.exec_cmd("hyprlock"))
bind(mainMod .. " + " .. power_key,         hl.dsp.exec_cmd("qs ipc call powermenu toggle"))
bind(mainMod .. " + " .. settings_key,      hl.dsp.exec_cmd("qs ipc call settings toggle"))
bind(mainMod .. " + " .. wallpapers_key,    hl.dsp.exec_cmd("qs -n -p ~/.config/quickshell/hyprquickpaper"))
bind(mainMod .. " + " .. colorpicker_key,   hl.dsp.exec_cmd("qs -n -p ~/.config/quickshell/colorpicker"))
bind(mainMod .. " + " .. fullscreen_key,    hl.dsp.window.fullscreen({ mode = 0 }))
bind(mainMod .. " + " .. opacity_key,       hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/opacity.sh"))
bind(mainMod .. " + " .. theme_key,         hl.dsp.exec_cmd("python3 " .. home .. "/.config/43pr/bin/theme.py toggle"))
bind(mainMod .. " + " .. notifications_key, hl.dsp.exec_cmd("qs ipc call notifications toggle"))
bind(mainMod .. " + " .. todo_key,          hl.dsp.exec_cmd("qs ipc call todo toggle"))

bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

bind(mainMod .. " + " .. bar_key, hl.dsp.exec_cmd("qs ipc call bar toggle"))
bind(mainMod .. " + " .. clipboard_key, hl.dsp.exec_cmd("pgrep -x rofi >/dev/null && pkill -x rofi || cliphist list | rofi -dmenu -p '' | cliphist decode | wl-copy"))

bind(shot_key, hl.dsp.exec_cmd("sh -c 'file=" .. home .. "/Pictures/$(date +%s).png; grim \"$file\"; wl-copy < \"$file\"; qs ipc call screenshot notify \"$file\"'"))
bind(shot_area_key, hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/screenshot-area.sh"))

bind(mainMod .. " + " .. layout_key, hl.dsp.exec_cmd("hyprctl switchxkblayout current next"))

bind(mainMod .. " + " .. float_key, function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    local w = hl.get_active_window()
    if w ~= nil and w.floating then
        local mon = hl.get_active_monitor()
        if mon ~= nil then
            local target_w = math.floor(mon.width * 0.7)
            local target_h = math.floor(mon.height * 0.7)
            hl.dispatch(hl.dsp.window.resize({ x = target_w, y = target_h, relative = false }))
            local mon_x = mon.x or 0
            local mon_y = mon.y or 0
            local target_x = mon_x + math.floor((mon.width - target_w) / 2)
            local target_y = mon_y + math.floor((mon.height - target_h) / 2)
            hl.dispatch(hl.dsp.window.move({ x = target_x, y = target_y, relative = false }))
        end
    end
end)

bind(mainMod .. " + " .. record_key, hl.dsp.exec_cmd([==[bash -c '
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/gsr.pid"
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    kill -INT "$(cat "$PIDFILE")"
    rm -f "$PIDFILE"
else
    DIR="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")"
    mkdir -p "$DIR"
    MON="$(hyprctl monitors | awk "/^Monitor/{n=\$2} /focused: yes/{print n}")"
    gpu-screen-recorder -w "${MON:-screen}" -f 60 -a default_output -o "$DIR/$(date +%Y-%m-%d_%H-%M-%S).mp4" &
    echo $! > "$PIDFILE"
fi
']==]))

local function zoomfunction(value)
    local zoomvalue = hl.get_config("cursor:zoom_factor")
    if (zoomvalue + value) > 1.5 then
        hl.config({ cursor = { zoom_factor = 1.5 } })
    elseif (zoomvalue + value) < 1.0 then
        hl.config({ cursor = { zoom_factor = 1.0 } })
    else
        hl.config({ cursor = { zoom_factor = zoomvalue + value } })
    end
end
bind(mainMod .. " + mouse_down", function() zoomfunction(-0.5) end, { repeating = true })
bind(mainMod .. " + mouse_up", function() zoomfunction(0.5) end, { repeating = true })
bind(mainMod .. " + code:82", function() zoomfunction(-0.3) end, { repeating = true })
bind(mainMod .. " + code:86", function() zoomfunction(0.3) end, { repeating = true })

bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })

for i = 1, 10 do
    local key = i % 10
    bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

bind(mainMod .. " + SHIFT + E", hl.dsp.exit())

bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))

bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))

bind(mainMod .. " + CTRL + H", hl.dsp.window.resize({ x = -40, y = 0 }), { repeating = true })
bind(mainMod .. " + CTRL + L", hl.dsp.window.resize({ x = 40, y = 0 }), { repeating = true })
bind(mainMod .. " + CTRL + K", hl.dsp.window.resize({ x = 0, y = -40 }), { repeating = true })
bind(mainMod .. " + CTRL + J", hl.dsp.window.resize({ x = 0, y = 40 }), { repeating = true })

bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
