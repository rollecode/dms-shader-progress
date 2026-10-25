import QtQuick
import Quickshell
import Quickshell.Io

import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property bool showLabel: pluginData.showLabel !== false
    property string labelText: pluginData.labelText || "Shaders"
    property int pollSeconds: pluginData.pollSeconds || 2

    // Steam background replay, from shader_log.txt.
    property bool replaying: false
    property string gameName: ""
    property int steamPercent: 0
    property real replayDone: 0
    property real replayCount: 0
    property int logAge: 0

    // In-game DXVK compiling, from compiler thread CPU time between polls.
    property real lastTicks: -1
    property real lastSampleMs: 0
    property real compileCpu: 0
    property int compileThreads: 0

    // Steam logs progress every 10 s; a minute of silence means the replay is gone.
    readonly property int staleSeconds: 60
    // Below half a core the compiler threads are idle chatter, not a compile.
    readonly property real compileThreshold: 50

    readonly property bool compiling: compileCpu >= compileThreshold
    readonly property bool active: replaying || compiling

    readonly property real pillFont: Theme.barTextSize(barThickness, barConfig ? barConfig.fontScale : undefined, barConfig ? barConfig.maximizeWidgetText : undefined)

    onActiveChanged: setVisibilityOverride(active)
    Component.onCompleted: setVisibilityOverride(active)

    TextMetrics {
        id: pctMetrics
        font.pixelSize: root.pillFont
        text: "100%"
    }

    function fmtCount(n) {
        return Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, " ")
    }

    Timer {
        interval: root.pollSeconds * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: collectProcess.running = true
    }

    Process {
        id: collectProcess
        command: ["sh", Qt.resolvedUrl("collect.sh").toString().replace("file://", "")]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    function parse(text) {
        let replay = null
        let ticks = 0, hz = 100, threads = 0
        for (const line of text.trim().split("\n")) {
            const f = line.split("\t")
            if (f[0] === "R" && f.length >= 7) replay = f
            if (f[0] === "C" && f.length >= 4) {
                ticks = parseInt(f[1])
                hz = parseInt(f[2]) || 100
                threads = parseInt(f[3])
            }
        }

        root.replaying = replay !== null && parseInt(replay[5]) < root.staleSeconds
        if (replay) {
            root.steamPercent = parseInt(replay[2])
            root.replayDone = parseFloat(replay[3])
            root.replayCount = parseFloat(replay[4])
            root.logAge = parseInt(replay[5])
            root.gameName = replay[6]
        }

        const now = Date.now()
        const dt = (now - root.lastSampleMs) / 1000
        // Threads exiting make the sum drop; that sample has no usable delta.
        if (root.lastTicks >= 0 && ticks >= root.lastTicks && dt > 0)
            root.compileCpu = (ticks - root.lastTicks) / hz / dt * 100
        else
            root.compileCpu = 0
        root.lastTicks = ticks
        root.lastSampleMs = now
        root.compileThreads = threads
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            DankIcon {
                name: "texture"
                size: root.iconSizeLarge
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.showLabel
                text: root.labelText
                font.pixelSize: root.pillFont
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                visible: root.replaying
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: Math.round(root.pillFont * 3.7)
                    height: Math.max(4, Math.round(root.pillFont / 2))
                    radius: height / 2
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.25)
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: parent.width * Math.min(root.steamPercent, 100) / 100
                        height: parent.height
                        radius: parent.radius
                        color: Theme.primary
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                }

                StyledText {
                    width: pctMetrics.width
                    horizontalAlignment: Text.AlignLeft
                    text: `${root.steamPercent}%`
                    font.pixelSize: root.pillFont
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                visible: !root.replaying && root.compiling
                text: `compiling ${Math.round(root.compileCpu)}%`
                font.pixelSize: root.pillFont
                color: Theme.warning
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    popoutWidth: 340

    popoutContent: Component {
        PopoutComponent {
            Item {
                width: parent.width
                implicitHeight: info.implicitHeight + Theme.spacingM * 2

                Column {
                    id: info
                    x: Theme.spacingM
                    y: Theme.spacingM
                    width: parent.width - Theme.spacingM * 2
                    spacing: Theme.spacingXS

                    StyledText {
                        visible: root.replaying
                        width: parent.width
                        text: `Steam is processing shaders for ${root.gameName}`
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        visible: root.replaying
                        width: parent.width
                        text: `Steam reports ${root.steamPercent}%, ${root.fmtCount(root.replayDone)} / ${root.fmtCount(root.replayCount)}, updated ${root.logAge} s ago`
                        font.pixelSize: Theme.fontSizeSmall - 1
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        visible: root.compiling
                        width: parent.width
                        text: `A running game is compiling shaders: ${root.compileThreads} DXVK threads using ${Math.round(root.compileCpu)}% CPU`
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        visible: !root.active
                        width: parent.width
                        text: "No shader work right now"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }
            }
        }
    }
}
