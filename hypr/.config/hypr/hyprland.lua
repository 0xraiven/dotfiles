require("config.monitors")
require("config.look_and_feel")
require("config.environment")

require("input.gestures")

require("bindings.apps")
require("bindings.navigation")
require("bindings.utilities")

require("rules.windows")
require("services.autostart")

-- Hyprland is actively using the Lua config provider here, so start the status bar
-- and wallpaper service directly from the loaded Lua entrypoint for reliable startup.
hl.exec_cmd("waybar")
hl.exec_cmd("hyprpaper")
