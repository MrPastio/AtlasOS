/*
 * Малая плитка: символ по центру и подпись в две строки (Ночной свет, Питание).
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3

Tile {
    id: tile
    property string glyph
    property string label
    property bool on: false
    signal clicked()

    pressable: true
    pressed: area.pressed
    padding: 8

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width
        spacing: 6
        Orb {
            Layout.alignment: Qt.AlignHCenter
            tokens: tile.tokens
            glyph: tile.glyph
            on: tile.on
            pressed: area.pressed
        }
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: tile.label
            color: tile.tokens.inkSecondary
            font.pixelSize: 11
            font.weight: Font.Medium
            lineHeight: 13
            lineHeightMode: Text.FixedHeight
            wrapMode: Text.WordWrap
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        onClicked: tile.clicked()
        Accessible.role: Accessible.Button
        Accessible.name: tile.label
    }
}
