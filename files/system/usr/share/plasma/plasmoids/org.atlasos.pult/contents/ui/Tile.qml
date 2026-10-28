/*
 * Плитка Пульта: control поверх material-panel, radius-md, кольцо shadow-card.
 * pressable — сжимается при нажатии (плитки крупнее 40px).
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick

Rectangle {
    id: tile
    required property Tokens tokens
    property bool pressable: false
    property bool pressed: false
    default property alias content: inner.data
    property int padding: 10

    radius: tokens.radiusTile
    color: tokens.control
    border.width: 1
    border.color: tokens.cardRing
    scale: pressable && pressed ? 0.97 : 1
    Behavior on scale {
        NumberAnimation {
            duration: tile.pressed ? tile.tokens.durMicro : tile.tokens.durSpringSnappy
            easing.type: Easing.OutBack
        }
    }

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: tile.padding
    }
}
