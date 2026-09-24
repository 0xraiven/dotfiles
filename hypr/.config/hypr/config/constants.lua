local home = os.getenv("HOME") or ""

return {
    terminal = "kitty",
    launcher = "quickshell --no-duplicate -c launcher",
    file_manager = "nautilus",
    default_browser = "zen-browser",
    antigravity = home .. "/AntigravityIDE/'Antigravity IDE'/antigravity-ide",
    editor = "code",
    monitor = "eDP-1",
    monitor_scale = 1.0,
    cursor_size = "24",
}
