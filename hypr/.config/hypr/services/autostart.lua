hl.on("hyprland.start", function()
	-- The wrapper makes config reloads and repeated installs idempotent.
	hl.exec_cmd("$HOME/.local/bin/waybar-start")
	hl.exec_cmd("$HOME/.local/bin/clipboard-start")
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("quickshell --no-duplicate -c rice")
end)
