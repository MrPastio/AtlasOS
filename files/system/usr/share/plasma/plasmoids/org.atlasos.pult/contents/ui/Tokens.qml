/*
 * Токены tokens.json для Пульта: QML пишет альфу первой (#aarrggbb).
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

QtObject {
    readonly property bool dark: Kirigami.Theme.textColor.hslLightness > 0.5

    readonly property color ink: dark ? "#f2f0eb" : "#1d1c1a"
    readonly property color inkSecondary: dark ? "#b3afa7" : "#55524b"
    readonly property color bgCanvas: dark ? "#1c1b1a" : "#ffffff"
    readonly property color control: dark ? "#1ff2f0eb" : "#ffffff"
    readonly property color fillPressed: dark ? "#21f2f0eb" : "#1a1d1c1a"
    readonly property color line: dark ? "#17f2f0eb" : "#171d1c1a"
    // shadow-card и shadow-control: кольцо 0.5px — на экране 1× линия в 1px с половинной альфой
    readonly property color cardRing: dark ? "#0af2f0eb" : "#0d1d1c1a"
    readonly property color controlRing: "#141d1c1a"
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color onAccent: Kirigami.Theme.highlightedTextColor

    readonly property int radiusTile: 10 // radius-md = radius-xl 18 − отступ 8
    readonly property int gap: 8
    readonly property int durMicro: 100
    readonly property int durShort: 160
    readonly property int durSpringSnappy: 280
}
