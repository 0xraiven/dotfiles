hl.bind("SUPER + Left", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + Right", hl.dsp.focus({ direction = "r" }))
hl.bind("SUPER + Up", hl.dsp.focus({ direction = "u" }))
hl.bind("SUPER + Down", hl.dsp.focus({ direction = "d" }))

hl.bind("SUPER + SHIFT + Left", hl.dsp.window.move({ direction = "l" }))
hl.bind("SUPER + SHIFT + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind("SUPER + SHIFT + Up", hl.dsp.window.move({ direction = "u" }))
hl.bind("SUPER + SHIFT + Down", hl.dsp.window.move({ direction = "d" }))

hl.bind("SUPER + CTRL + Left", hl.dsp.exec_cmd("hyprctl dispatch resizeactive -30 0"))
hl.bind("SUPER + CTRL + Right", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 30 0"))
hl.bind("SUPER + CTRL + Up", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -30"))
hl.bind("SUPER + CTRL + Down", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 30"))

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

for workspace = 1, 9 do
    hl.bind("SUPER + " .. workspace, hl.dsp.focus({ workspace = tostring(workspace) }))
    hl.bind("SUPER + SHIFT + " .. workspace, hl.dsp.focus({ workspace = tostring(workspace) }))
end

hl.bind("SUPER + O", hl.dsp.focus({ workspace = "10" }))
hl.bind("SUPER + SHIFT + 0", hl.dsp.window.move({ workspace = "10" }))
hl.bind("SUPER + BracketLeft", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + BracketRight", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("scratchpad"))
hl.bind("SUPER + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratchpad" }))
