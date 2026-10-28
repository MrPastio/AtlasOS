/*
 * Строка плитки связи и Фокуса: круглый символ, имя, состояние.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3

MouseArea {
    id: row
    required property Tokens tokens
    property string glyph
    property string title
    property string status
    property bool on: false

    implicitHeight: 30
    Layout.fillWidth: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: title
    Accessible.checked: on

    RowLayout {
        anchors.fill: parent
        spacing: 10
        Orb {
            tokens: row.tokens
            glyph: row.glyph
            on: row.on
            pressed: row.pressed
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: row.title
                color: row.tokens.ink
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: row.status
                visible: text !== ""
                color: row.tokens.inkSecondary
                font.pixelSize: 11
                font.weight: Font.Normal
                elide: Text.ElideRight
            }
        }
    }
}
