/*
 * Кнопка строки меню: та же рамка widgets/menubaritem, что у глобального меню Plasma,
 * чтобы Компас, имя приложения и меню приложения подсвечивались одинаково.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.ksvg as KSvg

MouseArea {
    id: button

    property bool open: false
    readonly property bool highlighted: open || containsMouse
    property real implicitContentWidth: 0
    signal activated()

    hoverEnabled: true
    Layout.fillHeight: true
    Layout.minimumWidth: implicitContentWidth + frame.margins.left + frame.margins.right
    Layout.preferredWidth: Layout.minimumWidth
    Layout.maximumWidth: Layout.minimumWidth
    onPressed: activated()

    KSvg.FrameSvgItem {
        id: frame
        anchors.fill: parent
        z: -1
        imagePath: "widgets/menubaritem"
        prefix: button.open ? "pressed" : (button.containsMouse ? "hover" : "normal")
    }
}
