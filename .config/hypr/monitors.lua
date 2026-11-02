-- monitors.lua (universal)
-- https://wiki.hypr.land/Configuring/Monitors/
-- Works on any laptop/desktop with no hardcoded output names.
-- Find your monitor names with:  hyprctl monitors

-- 1. Catch-all rule: every connected output (eDP-1, HDMI-A-1, DP-*, ...)
--    uses its preferred mode, is placed automatically, scale 1.
--    Hotplugged monitors are covered too.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- 2. Optional per-machine overrides written by the Quickshell display settings.
--    The file may define globals such as MONITOR1 / MONITOR2 and extra hl.monitor() rules.
--    It is optional: if missing or broken, the defaults above still apply.
local home = os.getenv("HOME")
if home then
    local path = home .. "/.config/quickshell/state/display.lua"
    local f = io.open(path, "r")
    if f then
        f:close()
        pcall(dofile, path)
    end
end

-- 3. Workspace rules.
--    MONITOR1 / MONITOR2 are only set if display.lua defined them. When they are
--    nil the "monitor" key is left out, so workspaces simply live on whichever
--    monitor is available (no invalid-monitor rules on single-screen setups).
local function ws_rule(id, monitor)
    local rule = { workspace = tostring(id), default = true, persistent = true }
    if monitor and monitor ~= "" then
        rule.monitor = monitor
    end
    hl.workspace_rule(rule)
end

for id = 1, 4 do
    ws_rule(id, MONITOR1)
end

-- Second-monitor workspaces: only created if a second monitor is configured.
if MONITOR2 and MONITOR2 ~= "" then
    for id = 5, 6 do
        ws_rule(id, MONITOR2)
    end
end

-- hl.workspace_rule({ workspace = "name:gaming", monitor = MONITOR1, default = true })
