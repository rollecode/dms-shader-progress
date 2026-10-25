import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "shaderProgress"

    StyledText {
        width: parent.width
        text: "Shader Progress"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Steam's background Vulkan shader processing and in-game DXVK shader compiling. The pill hides while nothing is compiling."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    ToggleSetting {
        settingKey: "showLabel"
        label: "Show label"
        description: "Display a text label next to the icon"
        defaultValue: true
    }

    StringSetting {
        settingKey: "labelText"
        label: "Label text"
        description: "The label shown next to the icon"
        placeholder: "Shaders"
        defaultValue: "Shaders"
    }

    SliderSetting {
        settingKey: "pollSeconds"
        label: "Update interval"
        description: "Seconds between reads"
        defaultValue: 2
        minimum: 1
        maximum: 10
        unit: "s"
    }
}
