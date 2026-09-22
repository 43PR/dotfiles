-- To check names run: hyprctl monitors 

-- 1. First monitor
-- hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1 })
-- hl.monitor({ output = "HDMI-A-1", disabled = true })

-- 2. Second monitor
-- hl.monitor({ output = "eDP-1", disabled = true })
-- hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto", scale = 1 })

-- 3. Extend/Auto
hl.monitor({output = "", mode = "preferred", position = "auto", scale = "1"})

-- 4. Duplicate
--hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1 })
--hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "0x0", scale = 1 })
