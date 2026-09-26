local home = os.getenv("HOME") or ""
local hypr_dir = home .. "/.config/hypr"
if not package.path:find(hypr_dir, 1, true) then
    package.path = hypr_dir .. "/?.lua;" .. hypr_dir .. "/?/init.lua;" .. package.path
end

local modules = {
    "config.monitors",
    "config.look_and_feel",
    "config.environment",
    "input.gestures",
    "bindings.apps",
    "bindings.navigation",
    "bindings.utilities",
    "rules.windows",
    "services.autostart",
}

for _, mod in ipairs(modules) do
    package.loaded[mod] = nil
    local ok, err = pcall(require, mod)
    if not ok then
        io.stderr:write(string.format("[hyprland.lua] Error loading module '%s': %s\n", mod, tostring(err)))
    end
end
