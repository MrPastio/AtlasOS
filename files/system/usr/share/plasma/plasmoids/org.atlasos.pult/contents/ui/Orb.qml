/*
 * Круглый символ плитки: выключен — fill-pressed, включён — заливка accent.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick

Rectangle {
    id: orb
    required property Tokens tokens
    property string glyph
    property bool on: false
    property bool pressed: false

    implicitWidth: 30
    implicitHeight: 30
    radius: width / 2
    color: on ? tokens.accent : tokens.fillPressed
    scale: pressed ? 0.9 : 1
    Behavior on color {
        ColorAnimation { duration: orb.tokens.durShort }
    }
    Behavior on scale {
        NumberAnimation {
            duration: orb.pressed ? orb.tokens.durMicro : orb.tokens.durSpringSnappy
            easing.type: Easing.OutBack
        }
    }

    Glyph {
        anchors.centerIn: parent
        name: orb.glyph
        color: orb.on ? orb.tokens.textOnAccent : orb.tokens.ink
    }
}
