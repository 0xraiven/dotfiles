local constants = require("config.constants")

hl.monitor({
    output = constants.monitor,
    mode = "preferred",
    position = "auto",
    scale = constants.monitor_scale,
})
