local function bind(key, dispatcher, opts)
    pcall(hl.unbind, key)
    if opts then
        hl.bind(key, dispatcher, opts)
    else
        hl.bind(key, dispatcher)
    end
end

bind("PRINT", hl.dsp.exec_cmd("$HOME/.config/quickshell/scripts/system/screenshot region"))
bind("SHIFT + PRINT", hl.dsp.exec_cmd("$HOME/.config/quickshell/scripts/system/screenshot full"))
bind("SUPER + L", hl.dsp.exec_cmd("loginctl lock-session"))
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"))
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"))
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"))
