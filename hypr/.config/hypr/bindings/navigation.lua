local function bind(key, dispatcher, opts)
    pcall(hl.unbind, key)
    if opts then
        hl.bind(key, dispatcher, opts)
    else
        hl.bind(key, dispatcher)
    end
end

bind("SUPER + Left", hl.dsp.focus({ direction = "l" }))
bind("SUPER + Right", hl.dsp.focus({ direction = "r" }))
bind("SUPER + Up", hl.dsp.focus({ direction = "u" }))
bind("SUPER + Down", hl.dsp.focus({ direction = "d" }))

bind("SUPER + SHIFT + Left", hl.dsp.window.move({ direction = "l" }))
bind("SUPER + SHIFT + Right", hl.dsp.window.move({ direction = "r" }))
bind("SUPER + SHIFT + Up", hl.dsp.window.move({ direction = "u" }))
bind("SUPER + SHIFT + Down", hl.dsp.window.move({ direction = "d" }))

bind("SUPER + CTRL + Left", hl.dsp.exec_cmd("hyprctl dispatch resizeactive -30 0"))
bind("SUPER + CTRL + Right", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 30 0"))
bind("SUPER + CTRL + Up", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -30"))
bind("SUPER + CTRL + Down", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 30"))

bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

for workspace = 1, 9 do
    bind("SUPER + " .. workspace, hl.dsp.focus({ workspace = tostring(workspace) }))
    bind("SUPER + SHIFT + " .. workspace, hl.dsp.focus({ workspace = tostring(workspace) }))
end

bind("SUPER + O", hl.dsp.focus({ workspace = "10" }))
bind("SUPER + SHIFT + 0", hl.dsp.window.move({ workspace = "10" }))
bind("SUPER + BracketLeft", hl.dsp.focus({ workspace = "e-1" }))
bind("SUPER + BracketRight", hl.dsp.focus({ workspace = "e+1" }))
bind("SUPER + S", hl.dsp.workspace.toggle_special("scratchpad"))
bind("SUPER + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratchpad" }))
