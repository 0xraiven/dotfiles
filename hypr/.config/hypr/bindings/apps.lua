local constants = require("config.constants")

local function bind(key, dispatcher, opts)
    pcall(hl.unbind, key)
    if opts then
        hl.bind(key, dispatcher, opts)
    else
        hl.bind(key, dispatcher)
    end
end

bind("SUPER + T", hl.dsp.exec_cmd(constants.terminal))
bind("SUPER + W", hl.dsp.exec_cmd(constants.default_browser))
bind("SUPER + SUPER_L", hl.dsp.exec_cmd("quickshell --no-duplicate -c launcher"), { release = true })
bind("SUPER + E", hl.dsp.exec_cmd(constants.file_manager))
bind("SUPER + C", hl.dsp.exec_cmd(constants.editor))
bind("SUPER + A", hl.dsp.exec_cmd(constants.antigravity))
bind("SUPER + V", hl.dsp.exec_cmd("env LAUNCHER_INITIAL_QUERY=: quickshell --no-duplicate -c launcher"))
bind("SUPER + Q", hl.dsp.window.close())
bind("SUPER + SHIFT + Q", hl.dsp.exit())
bind("SUPER + F", hl.dsp.window.fullscreen())
bind("SUPER + SPACE", hl.dsp.window.float({ action = "toggle" }))
bind("SUPER + TAB", hl.dsp.window.cycle_next())
bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))