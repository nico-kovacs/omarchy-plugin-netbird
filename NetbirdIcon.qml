import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Ui

Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property color badgeColor: Color.urgent
  property bool crossed: false
  property bool warning: false

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  // The mark was traced from the shipped netbird.png into a 24-wide viewbox.
  // It is wider than it is tall, so it gets centred in the square icon slot.
  readonly property real viewBox: 24.0
  readonly property real markHeight: 17.41
  readonly property real scale: root.iconSize / viewBox
  readonly property real offsetY: (root.iconSize - markHeight * scale) / 2

  Shape {
    id: mark
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    // Both wings, drawn as one silhouette in the full theme colour.
    ShapePath {
      fillColor: root.color
      strokeWidth: -1
      PathPolyline {
        path: [
          Qt.point(24.0 * root.scale, 0.0 * root.scale + root.offsetY),
          Qt.point(13.84 * root.scale, 17.41 * root.scale + root.offsetY),
          Qt.point(3.76 * root.scale, 17.41 * root.scale + root.offsetY),
          Qt.point(7.62 * root.scale, 10.64 * root.scale + root.offsetY),
          Qt.point(2.45 * root.scale, 5.36 * root.scale + root.offsetY),
          Qt.point(2.54 * root.scale, 5.18 * root.scale + root.offsetY),
          Qt.point(0.0 * root.scale, 2.73 * root.scale + root.offsetY),
          Qt.point(0.09 * root.scale, 2.54 * root.scale + root.offsetY),
          Qt.point(3.48 * root.scale, 1.98 * root.scale + root.offsetY),
          Qt.point(7.15 * root.scale, 1.98 * root.scale + root.offsetY),
          Qt.point(10.16 * root.scale, 2.54 * root.scale + root.offsetY),
          Qt.point(11.86 * root.scale, 3.29 * root.scale + root.offsetY),
          Qt.point(12.24 * root.scale, 2.45 * root.scale + root.offsetY),
          Qt.point(13.55 * root.scale, 1.13 * root.scale + root.offsetY),
          Qt.point(15.72 * root.scale, 0.09 * root.scale + root.offsetY),
          Qt.point(24.0 * root.scale, 0.0 * root.scale + root.offsetY)
        ]
      }
    }

    // Where the two wings cross. This sits on top of the wings, so a
    // translucent fill would just composite back to the wing colour — the
    // deeper tone has to be an explicitly darker colour. The factor matches
    // the logo's own ratio between its two oranges (luminance 122 / 149).
    ShapePath {
      fillColor: Qt.darker(root.color, 1.22)
      strokeWidth: -1
      PathPolyline {
        path: [
          Qt.point(13.93 * root.scale, 17.32 * root.scale + root.offsetY),
          Qt.point(7.53 * root.scale, 10.64 * root.scale + root.offsetY),
          Qt.point(11.76 * root.scale, 3.2 * root.scale + root.offsetY),
          Qt.point(12.61 * root.scale, 3.58 * root.scale + root.offsetY),
          Qt.point(13.93 * root.scale, 4.52 * root.scale + root.offsetY),
          Qt.point(15.53 * root.scale, 6.31 * root.scale + root.offsetY),
          Qt.point(16.66 * root.scale, 8.56 * root.scale + root.offsetY),
          Qt.point(17.22 * root.scale, 10.82 * root.scale + root.offsetY),
          Qt.point(17.22 * root.scale, 11.67 * root.scale + root.offsetY),
          Qt.point(13.93 * root.scale, 17.32 * root.scale + root.offsetY)
        ]
      }
    }
  }

  Rectangle {
    visible: root.crossed
    anchors.centerIn: parent
    width: parent.width * 1.22
    height: Math.max(2, parent.height * 0.14)
    radius: height / 2
    color: root.color
    rotation: -45
  }

  BorderSurface {
    visible: root.warning
    width: Math.max(7, parent.width * 0.42)
    height: width
    radius: width / 2
    color: root.badgeColor
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    borderSpec: Border.flat(Color.popups.background, 1)

    Text {
      anchors.centerIn: parent
      text: "!"
      color: Color.background
      font.family: Style.font.family
      font.pixelSize: Math.max(6, parent.height * 0.72)
      font.bold: true
    }
  }
}
