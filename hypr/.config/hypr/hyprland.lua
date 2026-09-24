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
    pcall(require, mod)
end
