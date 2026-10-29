/*
 * Токены tokens.json для Сводки: QML пишет альфу первой (#aarrggbb).
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

QtObject {
    readonly property bool dark: Kirigami.Theme.textColor.hslLightness > 0.5

    readonly property color ink: dark ? "#f2f0eb" : "#1d1c1a"
    readonly property color inkSecondary: dark ? "#b3afa7" : "#55524b"
    readonly property color inkTertiary: dark ? "#9c988f" : "#6e6b64"
    readonly property color fillHover: dark ? "#12f2f0eb" : "#0d1d1c1a"
    readonly property color fillPressed: dark ? "#21f2f0eb" : "#1a1d1c1a"
    // Карточка поверх material-panel — как плитка Пульта
    readonly property color control: dark ? "#1ff2f0eb" : "#ffffff"
    readonly property color line: dark ? "#17f2f0eb" : "#171d1c1a"
    // shadow-card: кольцо 0.5px — на экране 1× линия в 1px с половинной альфой
    readonly property color cardRing: dark ? "#0af2f0eb" : "#0d1d1c1a"
    readonly property color controlRing: dark ? "#1af2f0eb" : "#141d1c1a"
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color accentInk: dark ? "#5fd0c6" : "#0b6b66"
    readonly property color textOnAccent: dark ? "#06201e" : "#ffffff"

    readonly property int radiusCard: 10 // radius-md = radius-xl 18 − отступ 8
    readonly property int gap: 8
    readonly property int durMicro: 100
    readonly property int durShort: 160
    readonly property int durHoverOut: 200
    readonly property int durMedium: 240
    readonly property int durSpringSnappy: 280
    readonly property int durSpringGentle: 420

    // ease-out, ease-in из 06-motion.md
    readonly property var easeOut: [0.22, 1, 0.36, 1, 1, 1]
    readonly property var easeIn: [0.4, 0, 0.84, 0.36, 1, 1]

    // «сейчас», «12 мин», «14:05», «27 окт.»
    function relativeTime(date) {
        if (!date || isNaN(date)) {
            return "";
        }
        const now = new Date();
        const minutes = Math.floor((now - date) / 60000);
        if (minutes < 1) {
            return "сейчас";
        }
        if (minutes < 60) {
            return minutes + " мин";
        }
        if (date.toDateString() === now.toDateString()) {
            return Qt.formatTime(date, "HH:mm");
        }
        return Qt.locale().toString(date, "d MMM");
    }
}
