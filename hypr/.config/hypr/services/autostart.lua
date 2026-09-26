-- Desktop services autostart (all scripts use singleton locks for idempotency).
hl.on("hyprland.start", function()
    hl.exec_cmd("$HOME/.config/quickshell/scripts/system/waybar-start")
    hl.exec_cmd("$HOME/.config/quickshell/scripts/clipboard/clipboard-start")
    hl.exec_cmd("$HOME/.config/quickshell/scripts/wallpaper/hyprpaper-start")
    hl.exec_cmd("quickshell --no-duplicate -c rice")
end)
