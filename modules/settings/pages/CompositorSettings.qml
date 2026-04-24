import qs
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * CompositorSettings
 * 
 * Router page that loads compositor-specific settings based on detected compositor.
 * Currently routes to:
 *   - HyprlandSettings (if Hyprland detected)
 *   - NiriSettings (stub, for future support)
 * 
 * This page is integrated into the main settings overlay and appears as a tab.
 */
ColumnLayout {
    id: root
    spacing: 12
    padding: 16

    // ── Compositor detection banner ──
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 48
        radius: Appearance.rounding.normal
        color: Appearance.colors.colPrimaryContainer
        border.width: 1
        border.color: Appearance.colors.colOutline

        RowLayout {
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 12

            MaterialSymbol {
                text: CompositorService.isHyprland ? "stadia_controller" : "settings_input_svideo"
                iconSize: 20
                color: Appearance.colors.colOnPrimaryContainer
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    text: CompositorService.isHyprland ? "Hyprland Compositor" : CompositorService.isNiri ? "Niri Compositor" : "Unknown Compositor"
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnPrimaryContainer
                }

                StyledText {
                    text: CompositorService.isHyprland
                        ? "Configuring Hyprland keybinds and window management"
                        : "Compositor settings not available"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnPrimaryContainer
                }
            }
        }
    }

    // ── Compositor-specific content ──
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        sourceComponent: CompositorService.isHyprland ? hyprlandComponent : niriComponent
    }

    Component {
        id: hyprlandComponent

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            HyprlandBindsWidget {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }

    Component {
        id: niriComponent

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignCenter
                spacing: 16

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "info"
                    iconSize: 48
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Niri compositor settings"
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer0
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Configure Niri through its native config file"
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
