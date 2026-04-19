pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Scope {
    id: root

    // Orientation: determined by snap zone after drag
    property bool isVertical: false
    // Collapsed state (mini mode: indicator + stop + minimize)
    property bool collapsed: false
    // Camera overlay toggle (local state, no hardware control yet)
    property bool cameraEnabled: false

    // Save path for recordings (same pattern as Recorder.qml)
    readonly property string effectiveSavePath: {
        const configPath = Config.options?.screenRecord?.savePath ?? ""
        if (configPath && configPath.length > 0) return configPath
        const videosDir = FileUtils.trimFileProtocol(Directories.videos)
        return videosDir || `${FileUtils.trimFileProtocol(Directories.home)}/Videos`
    }

    function formatTime(totalSeconds: int): string {
        const hours = Math.floor(totalSeconds / 3600)
        const minutes = Math.floor((totalSeconds % 3600) / 60)
        const seconds = totalSeconds % 60
        const pad = (n) => n < 10 ? "0" + n : "" + n
        if (hours > 0) return pad(hours) + ":" + pad(minutes) + ":" + pad(seconds)
        return pad(minutes) + ":" + pad(seconds)
    }

    // Stop current recording, then restart with fullscreen + sound
    function resetRecording(): void {
        restartWatcher.pendingRestart = true
        Quickshell.execDetached(["/usr/bin/pkill", "-SIGINT", "wf-recorder"])
    }

    Connections {
        target: RecorderStatus
        function onIsRecordingChanged(): void {
            if (RecorderStatus.isRecording) {
                root.collapsed = false
                root.isVertical = false
            } else if (restartWatcher.pendingRestart) {
                restartWatcher.running = true
            }
        }
    }

    // Delayed restart after stop — gives wf-recorder time to finalize
    Timer {
        id: restartWatcher
        property bool pendingRestart: false
        interval: 500
        repeat: false
        onTriggered: {
            pendingRestart = false
            Quickshell.execDetached([Directories.recordScriptPath, "--fullscreen", "--sound"])
        }
    }

    Loader {
        id: osdLoader
        active: RecorderStatus.isRecording

        sourceComponent: PanelWindow {
            id: osdWindow
            visible: osdLoader.active && !GlobalStates.screenLocked
            screen: GlobalStates.primaryScreen

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:recordingOsd"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"

            mask: Region { item: pill }

            readonly property real edgeMargin: Appearance.sizes.elevationMargin
            readonly property real magnetThreshold: 80

            // Snap to nearest edge with magnetic behavior
            function snapToNearestEdge(): void {
                const margin = edgeMargin
                const pw = osdWindow.width
                const ph = osdWindow.height
                const pillW = pill.width
                const pillH = pill.height
                const cx = pill.x + pillW / 2
                const cy = pill.y + pillH / 2

                // Distance from each edge
                const distLeft = pill.x
                const distRight = pw - (pill.x + pillW)
                const distTop = pill.y
                const distBottom = ph - (pill.y + pillH)

                // Find the closest edge
                const minDist = Math.min(distLeft, distRight, distTop, distBottom)

                // Determine orientation: snapping to left/right edge means vertical
                const wasVertical = root.isVertical
                const snapsToSide = (minDist === distLeft || minDist === distRight)
                root.isVertical = snapsToSide

                // Compute snap position based on closest edge
                let targetX, targetY

                if (snapsToSide) {
                    // Left or right edge — pin horizontally, keep vertical position clamped
                    targetX = (minDist === distLeft) ? margin : pw - pillW - margin
                    targetY = Math.max(margin, Math.min(ph - pillH - margin, pill.y))
                } else {
                    // Top or bottom edge — pin vertically, keep horizontal position clamped
                    targetY = (minDist === distTop) ? margin : ph - pillH - margin
                    targetX = Math.max(margin, Math.min(pw - pillW - margin, pill.x))
                }

                // After orientation change, defer position calc since pill size changes
                if (root.isVertical !== wasVertical) {
                    Qt.callLater(() => {
                        const newPillW = pill.width
                        const newPillH = pill.height

                        let newX, newY
                        if (snapsToSide) {
                            newX = (minDist === distLeft) ? margin : pw - newPillW - margin
                            newY = Math.max(margin, Math.min(ph - newPillH - margin, cy - newPillH / 2))
                        } else {
                            newY = (minDist === distTop) ? margin : ph - newPillH - margin
                            newX = Math.max(margin, Math.min(pw - newPillW - margin, cx - newPillW / 2))
                        }

                        pill.animatePosition = true
                        pill.x = newX
                        pill.y = newY
                    })
                    return
                }

                pill.animatePosition = true
                pill.x = targetX
                pill.y = targetY
            }

            // Shadow behind pill
            StyledRectangularShadow { target: pill }

            Rectangle {
                id: pill
                property bool animatePosition: false
                property real contentPadding: 6

                // Size driven by active layout's implicit size
                width: root.isVertical
                    ? verticalContent.implicitWidth + contentPadding * 2
                    : horizontalContent.implicitWidth + contentPadding * 2
                height: root.isVertical
                    ? verticalContent.implicitHeight + contentPadding * 2
                    : horizontalContent.implicitHeight + contentPadding * 2

                // Initial position: top center
                x: parent ? (parent.width - width) / 2 : 0
                y: parent ? Appearance.sizes.elevationMargin : 0

                // Style-aware background
                color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                     : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                     : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                     : Appearance.colors.colLayer2
                radius: Appearance.rounding.large
                border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
                border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                            : Appearance.inirEverywhere ? Appearance.inir.colBorder
                            : Appearance.colors.colOutlineVariant

                // Entry animation
                property real initScale: 0.9
                scale: initScale
                opacity: initScale < 0.95 ? 0 : 1
                transformOrigin: Item.Center

                Component.onCompleted: {
                    Qt.callLater(() => { pill.initScale = 1.0 })
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveEnter.duration
                        easing.type: Appearance.animation.elementMoveEnter.type
                        easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveEnter.duration
                        easing.type: Appearance.animation.elementMoveEnter.type
                        easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                    }
                }
                Behavior on x {
                    enabled: pill.animatePosition
                    NumberAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                        onRunningChanged: if (!running) pill.animatePosition = false
                    }
                }
                Behavior on y {
                    enabled: pill.animatePosition
                    NumberAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                }
                Behavior on width {
                    enabled: pill.animatePosition
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }
                Behavior on height {
                    enabled: pill.animatePosition
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }

                // Horizontal layout (default, snaps to top/bottom)
                RowLayout {
                    id: horizontalContent
                    visible: !root.isVertical
                    anchors.centerIn: parent
                    spacing: 2

                    OsdDragHandle { isVertical: false }

                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: "screenshot_monitor"
                        onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "region", "recordWithSound"])
                        tooltip: Translation.tr("Select recording region")
                    }

                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                        dimmed: Audio.sink?.audio?.muted ?? false
                        onClicked: Audio.toggleMute()
                        tooltip: Audio.sink?.audio?.muted
                            ? Translation.tr("Unmute audio") : Translation.tr("Mute audio")
                    }
                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: Audio.micMuted ? "mic_off" : "mic"
                        dimmed: Audio.micMuted
                        onClicked: Audio.toggleMicMute()
                        tooltip: Audio.micMuted
                            ? Translation.tr("Unmute mic") : Translation.tr("Mute mic")
                    }
                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: root.cameraEnabled ? "videocam" : "videocam_off"
                        dimmed: !root.cameraEnabled
                        onClicked: root.cameraEnabled = !root.cameraEnabled
                        tooltip: root.cameraEnabled
                            ? Translation.tr("Disable camera") : Translation.tr("Enable camera")
                    }

                    OsdSeparator {
                        visible: !root.collapsed
                        isVertical: false
                    }

                    RecordingIndicator { isVertical: false }

                    OsdPillButton {
                        iconName: "stop"
                        filled: true
                        iconColor: Appearance.colors.colError
                        onClicked: Quickshell.execDetached(["/usr/bin/pkill", "-SIGINT", "wf-recorder"])
                        tooltip: Translation.tr("Stop recording")
                    }

                    OsdSeparator {
                        visible: !root.collapsed
                        isVertical: false
                    }

                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: "restart_alt"
                        onClicked: root.resetRecording()
                        tooltip: Translation.tr("Restart recording")
                    }
                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: "photo_camera"
                        onClicked: Quickshell.execDetached(["/usr/bin/bash", "-c", "/usr/bin/grim - | /usr/bin/wl-copy"])
                        tooltip: Translation.tr("Screenshot to clipboard")
                    }
                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: "folder_open"
                        onClicked: Qt.openUrlExternally(`file://${root.effectiveSavePath}`)
                        tooltip: Translation.tr("Open recordings folder")
                    }

                    OsdPillButton {
                        iconName: root.collapsed ? "open_in_full" : "close_fullscreen"
                        onClicked: { root.collapsed = !root.collapsed }
                        tooltip: root.collapsed
                            ? Translation.tr("Expand controls") : Translation.tr("Minimize")
                    }
                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: "close"
                        onClicked: Quickshell.execDetached(["/usr/bin/pkill", "-SIGINT", "wf-recorder"])
                        tooltip: Translation.tr("Stop and close")
                    }
                }

                // Vertical layout (snaps to left/right edges)
                ColumnLayout {
                    id: verticalContent
                    visible: root.isVertical
                    anchors.centerIn: parent
                    spacing: 2

                    OsdDragHandle { isVertical: true }

                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: "screenshot_monitor"
                        onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "region", "recordWithSound"])
                        tooltip: Translation.tr("Select recording region")
                    }

                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                        dimmed: Audio.sink?.audio?.muted ?? false
                        onClicked: Audio.toggleMute()
                        tooltip: Audio.sink?.audio?.muted
                            ? Translation.tr("Unmute audio") : Translation.tr("Mute audio")
                    }
                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: Audio.micMuted ? "mic_off" : "mic"
                        dimmed: Audio.micMuted
                        onClicked: Audio.toggleMicMute()
                        tooltip: Audio.micMuted
                            ? Translation.tr("Unmute mic") : Translation.tr("Mute mic")
                    }
                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: root.cameraEnabled ? "videocam" : "videocam_off"
                        dimmed: !root.cameraEnabled
                        onClicked: root.cameraEnabled = !root.cameraEnabled
                        tooltip: root.cameraEnabled
                            ? Translation.tr("Disable camera") : Translation.tr("Enable camera")
                    }

                    OsdSeparator {
                        visible: !root.collapsed
                        isVertical: true
                    }

                    RecordingIndicator { isVertical: true }

                    OsdPillButton {
                        iconName: "stop"
                        filled: true
                        iconColor: Appearance.colors.colError
                        onClicked: Quickshell.execDetached(["/usr/bin/pkill", "-SIGINT", "wf-recorder"])
                        tooltip: Translation.tr("Stop recording")
                    }

                    OsdSeparator {
                        visible: !root.collapsed
                        isVertical: true
                    }

                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: "restart_alt"
                        onClicked: root.resetRecording()
                        tooltip: Translation.tr("Restart recording")
                    }
                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: "photo_camera"
                        onClicked: Quickshell.execDetached(["/usr/bin/bash", "-c", "/usr/bin/grim - | /usr/bin/wl-copy"])
                        tooltip: Translation.tr("Screenshot to clipboard")
                    }
                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: "folder_open"
                        onClicked: Qt.openUrlExternally(`file://${root.effectiveSavePath}`)
                        tooltip: Translation.tr("Open recordings folder")
                    }

                    OsdPillButton {
                        iconName: root.collapsed ? "open_in_full" : "close_fullscreen"
                        onClicked: { root.collapsed = !root.collapsed }
                        tooltip: root.collapsed
                            ? Translation.tr("Expand controls") : Translation.tr("Minimize")
                    }
                    OsdPillButton {
                        visible: !root.collapsed
                        iconName: "close"
                        onClicked: Quickshell.execDetached(["/usr/bin/pkill", "-SIGINT", "wf-recorder"])
                        tooltip: Translation.tr("Stop and close")
                    }
                }
            }
        }
    }

    // Drag handle with hover feedback and cursor change
    component OsdDragHandle: Item {
        id: dragHandle
        required property bool isVertical

        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        Layout.alignment: Qt.AlignCenter

        opacity: dragHover.hovered || dragHandler.active ? 0.8 : 0.4

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        // Hover background
        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.full
            color: dragHandler.active
                ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
                    : Appearance.colors.colLayer2Active ?? Appearance.colors.colLayer1Active)
                : dragHover.hovered
                    ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                        : Appearance.colors.colLayer2Hover ?? Appearance.colors.colLayer1Hover)
                    : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "drag_indicator"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnLayer2
        }

        HoverHandler {
            id: dragHover
            cursorShape: dragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }

        DragHandler {
            id: dragHandler
            target: pill
            xAxis.minimum: 0
            xAxis.maximum: osdLoader.item ? osdLoader.item.width - pill.width : 0
            yAxis.minimum: 0
            yAxis.maximum: osdLoader.item ? osdLoader.item.height - pill.height : 0
            onActiveChanged: {
                if (active) pill.animatePosition = false
                else if (osdLoader.item) osdLoader.item.snapToNearestEdge()
            }
        }
    }

    // Separator line — adapts to orientation
    component OsdSeparator: Rectangle {
        required property bool isVertical

        Layout.preferredWidth: isVertical ? 22 : 1
        Layout.preferredHeight: isVertical ? 1 : 22
        Layout.alignment: Qt.AlignCenter
        color: Appearance.colors.colOutlineVariant
        opacity: 0.3
    }

    // Recording dot + timer display — adapts layout to orientation
    // Horizontal: [● 00:02]  Vertical: stacked [●] [00] [:] [02]
    component RecordingIndicator: Item {
        id: indicator
        required property bool isVertical

        readonly property string timeString: root.formatTime(RecorderStatus.elapsedSeconds)
        // Split "MM:SS" into ["MM", ":", "SS"] or "HH:MM:SS" into ["HH", ":", "MM", ":", "SS"]
        readonly property var timeParts: timeString.split(/([:])/)

        Layout.alignment: Qt.AlignCenter
        implicitWidth: isVertical ? verticalIndicator.implicitWidth : horizontalIndicator.implicitWidth
        implicitHeight: isVertical ? verticalIndicator.implicitHeight : horizontalIndicator.implicitHeight

        // Horizontal: dot + single timer string in a row
        RowLayout {
            id: horizontalIndicator
            visible: !indicator.isVertical
            spacing: 4
            anchors.centerIn: parent

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 8; height: 8; radius: 4
                color: Appearance.colors.colError
                SequentialAnimation on opacity {
                    running: osdLoader.active
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                }
            }

            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: hTimerMetrics.width
                implicitHeight: hTimerText.implicitHeight

                TextMetrics {
                    id: hTimerMetrics
                    text: RecorderStatus.elapsedSeconds >= 3600 ? "00:00:00" : "00:00"
                    font: hTimerText.font
                }

                Text {
                    id: hTimerText
                    anchors.centerIn: parent
                    text: indicator.timeString
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        // Vertical: dot on top, then each segment stacked (digits readable, not rotated)
        ColumnLayout {
            id: verticalIndicator
            visible: indicator.isVertical
            spacing: 1
            anchors.centerIn: parent

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 8; height: 8; radius: 4
                color: Appearance.colors.colError
                SequentialAnimation on opacity {
                    running: osdLoader.active
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                }
            }

            Repeater {
                model: indicator.timeParts

                Text {
                    required property string modelData
                    Layout.alignment: Qt.AlignHCenter
                    text: modelData
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: modelData === ":" ? Appearance.font.pixelSize.smaller : Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer2
                    opacity: modelData === ":" ? 0.5 : 1.0
                }
            }
        }
    }

    // Reusable icon button — transparent bg with hover reveal
    component OsdPillButton: RippleButton {
        id: btn
        required property string iconName
        property string tooltip: ""
        property bool dimmed: false
        property bool filled: false
        property color iconColor: Appearance.colors.colOnLayer2

        Layout.preferredWidth: 30
        Layout.preferredHeight: 30
        Layout.alignment: Qt.AlignCenter
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
            : Appearance.colors.colLayer2Hover ?? Appearance.colors.colLayer1Hover
        colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
            : Appearance.colors.colLayer2Active ?? Appearance.colors.colLayer1Active

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: btn.iconName
            iconSize: Appearance.font.pixelSize.larger
            fill: btn.filled ? 1 : 0
            color: btn.iconColor
            opacity: btn.dimmed ? 0.4 : 1.0
        }

        StyledToolTip {
            text: btn.tooltip
            visible: btn.tooltip && btn.buttonHovered
        }
    }

    IpcHandler {
        target: "recordingOsd"

        function toggle(): void {
            if (RecorderStatus.isRecording)
                Quickshell.execDetached(["/usr/bin/pkill", "-SIGINT", "wf-recorder"])
        }

        function show(): void {
            root.collapsed = false
        }

        function hide(): void {
            root.collapsed = true
        }
    }
}
