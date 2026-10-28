/*
 * Разделитель Дока (компонент Dock: .at-dock-sep): линия 1px line-strong,
 * поля 3px по бокам, сверху 4, снизу 1 от значка — под ним зона индикатора задач.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property color line: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                          Kirigami.Theme.textColor.b, 0.16)

    fullRepresentation: Item {
        Layout.minimumWidth: root.vertical ? -1 : 7
        Layout.maximumWidth: root.vertical ? -1 : 7
        Layout.minimumHeight: root.vertical ? 7 : -1
        Layout.maximumHeight: root.vertical ? 7 : -1
        Layout.fillHeight: !root.vertical
        Layout.fillWidth: root.vertical

        Rectangle {
            color: root.line
            x: root.vertical ? 4 : 3
            y: root.vertical ? 3 : 4
            width: root.vertical ? parent.width - 4 - 7 : 1
            height: root.vertical ? 1 : parent.height - 4 - 7
        }
    }
}
