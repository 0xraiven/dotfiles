local colors = require("config.colors")

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 4,
        border_size = 2,
        layout = "dwindle",
        resize_on_border = true,
        allow_tearing = false,
        col = {
            active_border = "0xff" .. colors.primary:sub(2) .. "ff",
            inactive_border = "0xff" .. colors.surface_variant:sub(2) .. "ff",
        },
    },

    decoration = {
        rounding = 10,
        blur = {
            enabled = true,
            size = 4,
            passes = 2,
            new_optimizations = true,
            ignore_opacity = true,
            xray = false,
        },
        shadow = {
            enabled = true,
            range = 8,
            render_power = 2,
            color = "0x66000000",
        },
        active_opacity = 1.0,
        inactive_opacity = 0.94,
        fullscreen_opacity = 1.0,
    },

    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,
        repeat_rate = 50,
        repeat_delay = 300,
        numlock_by_default = true,
        natural_scroll = false,
        touchpad = {
            disable_while_typing = true,
            natural_scroll = true,
            tap_to_click = true,
        },
    },

    cursor = {
        hide_on_key_press = false,
        hide_on_touch = true,
        enable_hyprcursor = true,
    },

    gestures = {
        workspace_swipe_distance = 300,
        workspace_swipe_cancel_ratio = 0.2,
        workspace_swipe_min_speed_to_force = 10,
        workspace_swipe_create_new = true,
        workspace_swipe_forever = true,
        workspace_swipe_direction_lock = true,
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        disable_autoreload = true,
        animate_manual_resizes = true,
        animate_mouse_windowdragging = true,
    },

    xwayland = {
        force_zero_scaling = true,
    },

    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
})

hl.curve("easeOut", {
    type = "bezier",
    points = {
        { 0.65, 0.0 },
        { 0.3, 1.0 },
    },
})

hl.curve("gamingEase", {
    type = "bezier",
    points = {
        { 0.1, 1.0 },
        { 0.2, 1.0 },
    },
})

hl.curve("gamingSpring", {
    type = "spring",
    mass = 0.7,
    stiffness = 300,
    dampening = 20,
})

hl.animation({
    leaf = "global",
    enabled = true,
    speed = 10,
    bezier = "gamingEase",
})

hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 7,
    spring = "gamingSpring",
})

hl.animation({
    leaf = "windowsIn",
    enabled = true,
    speed = 7,
    spring = "gamingSpring",
    style = "popin 92%",
})

hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 6,
    spring = "gamingSpring",
    style = "popin 92%",
})

hl.animation({
    leaf = "windowsMove",
    enabled = true,
    speed = 8,
    spring = "gamingSpring",
})

hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 7,
    spring = "gamingSpring",
    style = "slidefade 18%",
})

hl.animation({
    leaf = "workspacesIn",
    enabled = true,
    speed = 7,
    spring = "gamingSpring",
    style = "slidefade 18%",
})

hl.animation({
    leaf = "workspacesOut",
    enabled = true,
    speed = 6,
    spring = "gamingSpring",
    style = "slidefade 18%",
})

hl.animation({
    leaf = "fadeIn",
    enabled = true,
    speed = 8,
    bezier = "gamingEase",
})

hl.animation({
    leaf = "fadeOut",
    enabled = true,
    speed = 7,
    bezier = "gamingEase",
})

hl.animation({
    leaf = "fade",
    enabled = true,
    speed = 8,
    bezier = "gamingEase",
})
