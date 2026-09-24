hl.on("hyprland.start", function()
	-- The wrapper makes config reloads and repeated installs idempotent.
	hl.exec_cmd("$HOME/.config/quickshell/r41n/scripts/.local/bin/waybar-start")
	hl.exec_cmd("$HOME/.config/quickshell/r41n/scripts/.local/bin/clipboard-start")
	hl.exec_cmd("$HOME/.config/quickshell/r41n/scripts/.local/bin/hyprpaper-start")
	hl.exec_cmd("quickshell --no-duplicate -c rice")
end)
