pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property bool isRecording: false

    function refreshStatus() {
        if (!checkProcess.running)
            checkProcess.running = true
    }

    // Poll slightly less frequently - recording status doesn't need sub-second updates
    Timer {
        id: pollTimer
        interval: 1000
        running: Config.ready
        repeat: true
        onTriggered: root.refreshStatus()
    }

    Component.onCompleted: Qt.callLater(root.refreshStatus)
    onIsRecordingChanged: Qt.callLater(root.refreshStatus)

    Process {
        id: checkProcess
        command: ["/usr/bin/pgrep", "-x", "wf-recorder"]
        onExited: (exitCode, exitStatus) => {
            // pgrep returns 0 if process found, 1 if not found
            root.isRecording = (exitCode === 0)
        }
    }
}
