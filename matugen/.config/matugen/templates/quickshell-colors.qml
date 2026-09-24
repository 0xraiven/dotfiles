import QtQuick

QtObject {
    readonly property color background: "{{colors.surface.default.hex}}"
    readonly property color surface: "{{colors.surface_container.default.hex}}"
    readonly property color surfaceVariant: "{{colors.surface_variant.default.hex}}"
    readonly property color foreground: "{{colors.on_surface.default.hex}}"
    readonly property color muted: "{{colors.on_surface_variant.default.hex}}"
    readonly property color primary: "{{colors.primary.default.hex}}"
    readonly property color onPrimary: "{{colors.on_primary.default.hex}}"
    readonly property color secondary: "{{colors.secondary.default.hex}}"
    readonly property color tertiary: "{{colors.tertiary.default.hex}}"
    readonly property color error: "{{colors.error.default.hex}}"
    readonly property color outline: "{{colors.outline.default.hex}}"
}
