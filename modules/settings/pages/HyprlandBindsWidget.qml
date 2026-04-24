import qs
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF

/**
 * HyprlandBindsWidget
 * 
 * A comprehensive keybind editor for Hyprland.
 * Features:
 *   - View all keybinds in a searchable table
 *   - Add new keybinds with a dialog
 *   - Edit existing keybinds inline or in dialog
 *   - Delete keybinds
 *   - Search and filter by key/command/description
 *   - Apply changes and reload Hyprland
 */
ColumnLayout {
    id: root
    spacing: 16

    // ── Header ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        StyledText {
            text: Translation.tr("Keybind Manager")
            font {
                family: Appearance.font.family.title
                pixelSize: Appearance.font.pixelSize.title
            }
            color: Appearance.colors.colOnLayer0
        }

        Item { Layout.fillWidth: true }

        RippleButton {
            implicitHeight: 36
            implicitWidth: 36
            buttonRadius: Appearance.rounding.normal
            onClicked: addBindDialog.visible = true

            contentItem: RowLayout {
                spacing: 6
                anchors.centerIn: parent

                MaterialSymbol {
                    text: "add"
                    iconSize: 18
                    color: Appearance.colors.colOnPrimaryContainer
                }
            }

            background: Rectangle {
                color: Appearance.colors.colPrimaryContainer
                radius: parent.buttonRadius
            }
        }
    }

    // ── Search bar ──
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 40
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.colors.colOutline

        RowLayout {
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 8

            MaterialSymbol {
                text: "search"
                iconSize: 18
                color: Appearance.colors.colSubtext
            }

            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Search keybinds...")
                background: Rectangle { color: "transparent" }
                onTextChanged: updateFilteredBinds()
            }
        }
    }

    // ── Binds table ──
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 8

        // Table header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Layout.margins: 8

            StyledText {
                text: Translation.tr("Modifiers")
                Layout.preferredWidth: 120
                font.weight: Font.Medium
                color: Appearance.colors.colSubtext
            }

            StyledText {
                text: Translation.tr("Key")
                Layout.preferredWidth: 80
                font.weight: Font.Medium
                color: Appearance.colors.colSubtext
            }

            StyledText {
                text: Translation.tr("Dispatcher")
                Layout.preferredWidth: 100
                font.weight: Font.Medium
                color: Appearance.colors.colSubtext
            }

            StyledText {
                text: Translation.tr("Command")
                Layout.fillWidth: true
                font.weight: Font.Medium
                color: Appearance.colors.colSubtext
            }

            StyledText {
                text: Translation.tr("Actions")
                Layout.preferredWidth: 80
                font.weight: Font.Medium
                color: Appearance.colors.colSubtext
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Appearance.colors.colOutline
        }

        // Scrollable table rows
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: bindsList.implicitHeight
            clip: true

            ColumnLayout {
                id: bindsList
                width: parent.width
                spacing: 0

                Repeater {
                    model: root.filteredBinds
                    delegate: ColumnLayout {
                        id: bindRow
                        required property int index
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.margins: 8
                            spacing: 12

                            StyledText {
                                text: bindRow.modelData.modifiers
                                Layout.preferredWidth: 120
                                font.family: Appearance.font.family.mono
                                color: Appearance.colors.colOnLayer0
                            }

                            StyledText {
                                text: bindRow.modelData.key
                                Layout.preferredWidth: 80
                                font.family: Appearance.font.family.mono
                                font.weight: Font.Bold
                                color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                text: bindRow.modelData.dispatcher
                                Layout.preferredWidth: 100
                                font.family: Appearance.font.family.mono
                                color: Appearance.colors.colOnLayer0
                            }

                            StyledText {
                                text: bindRow.modelData.command
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                color: Appearance.colors.colOnLayer0
                            }

                            RowLayout {
                                Layout.preferredWidth: 80
                                spacing: 4

                                RippleButton {
                                    implicitHeight: 28
                                    implicitWidth: 28
                                    buttonRadius: Appearance.rounding.small
                                    onClicked: {
                                        editingIndex = bindRow.index
                                        editBindDialog.visible = true
                                    }

                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "edit"
                                        iconSize: 14
                                        color: Appearance.colors.colPrimary
                                    }
                                }

                                RippleButton {
                                    implicitHeight: 28
                                    implicitWidth: 28
                                    buttonRadius: Appearance.rounding.small
                                    onClicked: HyprlandConfigService.removeBind(bindRow.index)

                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "delete"
                                        iconSize: 14
                                        color: Appearance.colors.colError
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Appearance.colors.colOutlineVariant
                        }
                    }
                }

                // Empty state
                StyledText {
                    visible: bindsList.children.length === 1 // Only the Repeater, no delegates
                    text: Translation.tr("No keybinds found")
                    color: Appearance.colors.colSubtext
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 32
                }
            }
        }
    }

    // ── Apply button ──
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 12
        spacing: 12

        Item { Layout.fillWidth: true }

        RippleButton {
            implicitHeight: 36
            implicitWidth: 140
            buttonRadius: Appearance.rounding.normal
            onClicked: {
                if (HyprlandConfigService.applyConfigChanges()) {
                    showNotification("Keybinds applied and Hyprland reloaded")
                } else {
                    showNotification("Failed to apply keybinds", true)
                }
            }

            contentItem: RowLayout {
                anchors.centerIn: parent
                spacing: 6

                MaterialSymbol {
                    text: "check"
                    iconSize: 16
                    color: Appearance.colors.colOnPrimaryContainer
                }

                StyledText {
                    text: Translation.tr("Apply Changes")
                    color: Appearance.colors.colOnPrimaryContainer
                }
            }

            background: Rectangle {
                color: Appearance.colors.colPrimaryContainer
                radius: parent.buttonRadius
            }
        }
    }

    // ── Internal state ──
    property list<var> filteredBinds: []
    property int editingIndex: -1

    function updateFilteredBinds() {
        const query = searchField.text.toLowerCase().trim()
        const all = HyprlandConfigService.binds || []

        if (!query.length) {
            filteredBinds = all
            return
        }

        const filtered = all.filter(bind => {
            const modStr = (bind.modifiers || "").toLowerCase()
            const keyStr = (bind.key || "").toLowerCase()
            const dispStr = (bind.dispatcher || "").toLowerCase()
            const cmdStr = (bind.command || "").toLowerCase()
            const descStr = (bind.description || "").toLowerCase()

            return modStr.includes(query) ||
                   keyStr.includes(query) ||
                   dispStr.includes(query) ||
                   cmdStr.includes(query) ||
                   descStr.includes(query)
        })

        filteredBinds = filtered
    }

    function showNotification(message: string, isError: bool = false) {
        // TODO: integrate with shell notification system
        console.info("[HyprlandBindsWidget]", message)
    }

    // ── Add bind dialog ──
    Popup {
        id: addBindDialog
        anchors.centerIn: parent
        width: Math.min(500, root.width - 40)
        height: implicitHeight
        background: Rectangle {
            color: Appearance.colors.colLayer0
            border.width: 1
            border.color: Appearance.colors.colOutline
            radius: Appearance.rounding.normal
        }

        ColumnLayout {
            width: parent.width
            spacing: 16
            padding: 20

            StyledText {
                text: Translation.tr("Add New Keybind")
                font.weight: Font.Bold
                font.pixelSize: Appearance.font.pixelSize.title
                color: Appearance.colors.colOnLayer0
            }

            ColumnLayout {
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        text: Translation.tr("Modifiers:")
                        Layout.preferredWidth: 100
                    }

                    TextField {
                        id: addModifiers
                        Layout.fillWidth: true
                        placeholderText: "SUPER SHIFT"
                        background: Rectangle {
                            color: Appearance.colors.colLayer1
                            border.width: 1
                            border.color: Appearance.colors.colOutline
                            radius: Appearance.rounding.small
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        text: Translation.tr("Key:")
                        Layout.preferredWidth: 100
                    }

                    TextField {
                        id: addKey
                        Layout.fillWidth: true
                        placeholderText: "E"
                        background: Rectangle {
                            color: Appearance.colors.colLayer1
                            border.width: 1
                            border.color: Appearance.colors.colOutline
                            radius: Appearance.rounding.small
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        text: Translation.tr("Dispatcher:")
                        Layout.preferredWidth: 100
                    }

                    TextField {
                        id: addDispatcher
                        Layout.fillWidth: true
                        placeholderText: "exec"
                        background: Rectangle {
                            color: Appearance.colors.colLayer1
                            border.width: 1
                            border.color: Appearance.colors.colOutline
                            radius: Appearance.rounding.small
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        text: Translation.tr("Command:")
                        Layout.preferredWidth: 100
                    }

                    TextField {
                        id: addCommand
                        Layout.fillWidth: true
                        placeholderText: "kitty"
                        background: Rectangle {
                            color: Appearance.colors.colLayer1
                            border.width: 1
                            border.color: Appearance.colors.colOutline
                            radius: Appearance.rounding.small
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item { Layout.fillWidth: true }

                RippleButton {
                    implicitHeight: 36
                    implicitWidth: 100
                    text: Translation.tr("Cancel")
                    onClicked: addBindDialog.close()
                }

                RippleButton {
                    implicitHeight: 36
                    implicitWidth: 100
                    text: Translation.tr("Add")
                    onClicked: {
                        HyprlandConfigService.addBind(
                            addModifiers.text,
                            addKey.text,
                            addDispatcher.text,
                            addCommand.text
                        )
                        addBindDialog.close()
                        addModifiers.text = ""
                        addKey.text = ""
                        addDispatcher.text = ""
                        addCommand.text = ""
                        updateFilteredBinds()
                    }
                }
            }
        }
    }

    // ── Edit bind dialog (similar to add, but pre-fills) ──
    Popup {
        id: editBindDialog
        anchors.centerIn: parent
        width: Math.min(500, root.width - 40)
        height: implicitHeight
        background: Rectangle {
            color: Appearance.colors.colLayer0
            border.width: 1
            border.color: Appearance.colors.colOutline
            radius: Appearance.rounding.normal
        }

        ColumnLayout {
            width: parent.width
            spacing: 16
            padding: 20

            StyledText {
                text: Translation.tr("Edit Keybind")
                font.weight: Font.Bold
                font.pixelSize: Appearance.font.pixelSize.title
                color: Appearance.colors.colOnLayer0
            }

            ColumnLayout {
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        text: Translation.tr("Modifiers:")
                        Layout.preferredWidth: 100
                    }

                    TextField {
                        id: editModifiers
                        Layout.fillWidth: true
                        background: Rectangle {
                            color: Appearance.colors.colLayer1
                            border.width: 1
                            border.color: Appearance.colors.colOutline
                            radius: Appearance.rounding.small
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        text: Translation.tr("Key:")
                        Layout.preferredWidth: 100
                    }

                    TextField {
                        id: editKey
                        Layout.fillWidth: true
                        background: Rectangle {
                            color: Appearance.colors.colLayer1
                            border.width: 1
                            border.color: Appearance.colors.colOutline
                            radius: Appearance.rounding.small
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        text: Translation.tr("Dispatcher:")
                        Layout.preferredWidth: 100
                    }

                    TextField {
                        id: editDispatcher
                        Layout.fillWidth: true
                        background: Rectangle {
                            color: Appearance.colors.colLayer1
                            border.width: 1
                            border.color: Appearance.colors.colOutline
                            radius: Appearance.rounding.small
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        text: Translation.tr("Command:")
                        Layout.preferredWidth: 100
                    }

                    TextField {
                        id: editCommand
                        Layout.fillWidth: true
                        background: Rectangle {
                            color: Appearance.colors.colLayer1
                            border.width: 1
                            border.color: Appearance.colors.colOutline
                            radius: Appearance.rounding.small
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item { Layout.fillWidth: true }

                RippleButton {
                    implicitHeight: 36
                    implicitWidth: 100
                    text: Translation.tr("Cancel")
                    onClicked: editBindDialog.close()
                }

                RippleButton {
                    implicitHeight: 36
                    implicitWidth: 100
                    text: Translation.tr("Save")
                    onClicked: {
                        HyprlandConfigService.updateBind(editingIndex, {
                            modifiers: editModifiers.text,
                            key: editKey.text,
                            dispatcher: editDispatcher.text,
                            command: editCommand.text
                        })
                        editBindDialog.close()
                        updateFilteredBinds()
                    }
                }
            }
        }

        onOpened: {
            if (editingIndex >= 0 && editingIndex < HyprlandConfigService.binds.length) {
                const bind = HyprlandConfigService.binds[editingIndex]
                editModifiers.text = bind.modifiers
                editKey.text = bind.key
                editDispatcher.text = bind.dispatcher
                editCommand.text = bind.command
            }
        }
    }

    Component.onCompleted: {
        updateFilteredBinds()
        // Watch for external changes
        Connections {
            target: HyprlandConfigService
            function onBindsChanged() {
                updateFilteredBinds()
            }
        }
    }
}
