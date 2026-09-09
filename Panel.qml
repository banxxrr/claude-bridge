import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar entry for Claude Bridge. The icon alone answers "can my phone reach this
// machine right now"; clicking opens a menu with the actions that change it.
Panel {
  id: root
  moduleName: "banxxrr.claude-bridge"
  ipcTarget: "banxxrr.claude-bridge"
  manageIpc: false

  // The base Panel is a bare Item, so the bar has nothing to lay out unless we
  // publish the button's implicit size.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Anthropic's brand orange. Only ever shown when dispatch is actually live,
  // so colour on the bar always means "this machine is reachable".
  readonly property color anthropicOrange: "#D97757"
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color barIconColor: claude.active ? anthropicOrange : foreground

  readonly property var actions: claude.running
    ? [
        { id: "toggle", label: "Show / hide window" },
        { id: "quit", label: "Quit Claude Desktop" },
        { id: "refresh", label: "Refresh status" }
      ]
    : [
        { id: "launch", label: "Launch Claude Desktop" },
        { id: "refresh", label: "Refresh status" }
      ]

  function runAction(id) {
    if (id === "toggle") claude.toggleWindow()
    else if (id === "quit") claude.quit()
    else if (id === "launch") claude.launch()
    else if (id === "refresh") claude.refresh()
    if (id !== "refresh") root.close()
  }

  Service {
    id: claude
    settings: root.settings || ({})
  }

  IpcHandler {
    target: "banxxrr.claude-bridge.control"
    function refresh(): string { claude.refresh(); return "ok" }
    function toggle(): string { claude.toggleWindow(); return "ok" }
    function launch(): string { claude.launch(); return "ok" }
    function quit(): string { claude.quit(); return "ok" }
    function status(): string { return claude.statusText }
    function environment(): string { return claude.environmentId }
    function lastcmd(): string { return claude.lastCommand }
    function menu(): string { root.toggle(); return "ok" }
    function isopen(): string { return root.opened ? "open" : "closed" }
  }

  BarIconButton {
    id: button
    bar: root.bar
    tooltipText: claude.statusText
    iconComponent: Component {
      Item {
        ClaudeIcon {
          anchors.fill: parent
          color: root.barIconColor
          // Orange at full strength when dispatch is live; plain bar colour
          // when the app is up but the bridge is not; faded when it is down.
          opacity: claude.active ? 1.0 : (claude.degraded ? 1.0 : 0.4)
        }
      }
    }
    onPressed: function(buttonCode) {
      // Menu on left click; the quick actions stay on the other buttons.
      if (buttonCode === Qt.MiddleButton) claude.quit()
      else if (buttonCode === Qt.RightButton) claude.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

    Column {
      id: column
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.space(12)

      // Header: the mark, the name, and the online state in words.
      Item {
        width: parent.width
        implicitHeight: Math.max(heroIcon.height, heroLabels.implicitHeight)

        Item {
          id: heroIcon
          width: Style.font.display
          height: Style.font.display
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter

          ClaudeIcon {
            anchors.fill: parent
            color: root.barIconColor
            opacity: claude.active ? 1.0 : (claude.degraded ? 1.0 : 0.4)
          }
        }

        Column {
          id: heroLabels
          anchors.left: heroIcon.right
          anchors.leftMargin: Style.space(12)
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(3)

          Text {
            text: "Claude Bridge"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Row {
            spacing: Style.space(6)

            // The state light: orange when dispatch is live, hollow when not.
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(8)
              height: Style.space(8)
              radius: width / 2
              color: claude.active ? root.anthropicOrange : "transparent"
              border.width: claude.active ? 0 : 1
              border.color: root.dim
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: claude.active ? "Online" : (claude.degraded ? "Bridge off" : "Offline")
              color: claude.active ? root.anthropicOrange : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }

      // Full status sentence, so the menu explains the icon.
      Text {
        width: parent.width
        text: claude.statusText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      Column {
        width: parent.width
        spacing: Style.space(2)

        Repeater {
          model: root.actions

          Rectangle {
            required property var modelData
            width: parent.width
            height: Style.space(32)
            radius: Style.space(6)
            color: hover.containsMouse
              ? (bar ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent")
              : "transparent"

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.label
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            MouseArea {
              id: hover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.runAction(modelData.id)
            }
          }
        }
      }
    }
    }
  }
}
