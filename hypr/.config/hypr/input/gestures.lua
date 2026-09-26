-- Touchpad gestures
-- Register horizontal workspace swipe (both 3-finger and 4-finger supported)
pcall(hl.gesture, { fingers = 3, direction = "horizontal", action = "workspace" })
pcall(hl.gesture, { fingers = 4, direction = "horizontal", action = "workspace" })
pcall(hl.gesture, { fingers = 3, direction = "vertical", action = "special" })
