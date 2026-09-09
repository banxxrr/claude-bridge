import QtQuick
import qs.Commons

// Sunburst mark: four bars through a common centre, forming 8 visible rays.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  implicitWidth: iconSize
  implicitHeight: iconSize

  Item {
    anchors.fill: parent

    Repeater {
      model: 4

      Rectangle {
        readonly property real ray: root.height
        readonly property real thickness: Math.max(1.5, root.height * 0.10)

        width: thickness
        height: ray
        radius: thickness / 2
        color: root.color
        antialiasing: true

        // Each ray is a bar through the centre, rotated about its own middle,
        // so twelve of them form a symmetric burst.
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        transformOrigin: Item.Center
        rotation: index * (180 / 4)
      }
    }
  }
}
