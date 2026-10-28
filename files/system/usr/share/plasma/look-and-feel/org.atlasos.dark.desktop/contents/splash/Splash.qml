/*
 * Заставка «Атласа» между входом и рабочим столом (KSplash). Продолжает экран входа:
 * те же обои «Меридиан», размытые до blur-wallpaper и чуть затемнённые, по центру —
 * символ Компаса и тонкая полоска хода загрузки. Когда стол готов, размытие уходит,
 * символ и полоска растворяются (dur-xlong, ease-in-out) — под ними уже резкие обои стола.
 * Один и тот же файл лежит в светлой и тёмной глобальных темах.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

Rectangle {
    id: root
    // bg-window: виден, пока обои не загрузились
    color: dark ? "#262523" : "#f6f5f2"

    // ksplashqml выставляет stage от 1 до 6; на 5-м рабочий стол уже нарисован
    property int stage

    readonly property bool dark: Kirigami.Theme.backgroundColor.hslLightness < 0.5
    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software
    readonly property var easeOut: [0.22, 1, 0.36, 1, 1, 1]
    readonly property var easeInOut: [0.65, 0, 0.35, 1, 1, 1]

    // 1 — заставка, 0 — рабочий стол
    property real factor: stage >= 5 ? 0 : 1
    Behavior on factor {
        NumberAnimation { duration: 450; easing.type: Easing.BezierSpline; easing.bezierCurve: root.easeInOut }
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: root.dark
            ? "file:///usr/share/wallpapers/Meridian/contents/images_dark/2560x1600.webp"
            : "file:///usr/share/wallpapers/Meridian/contents/images/2560x1600.webp"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: root.softwareRendering
    }
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: !root.softwareRendering
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: root.factor
        saturation: 0.3 * root.factor
    }
    Rectangle {
        anchors.fill: parent
        color: "#1d1c1a"
        opacity: 0.22 * root.factor
    }

    Item {
        id: content
        anchors.fill: parent
        // Проявляется на первой стадии (ease-out), растворяется вместе с размытием
        opacity: root.stage >= 1 && root.stage < 5 ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 320
                easing.type: Easing.BezierSpline
                easing.bezierCurve: content.opacity < 0.5 ? root.easeOut : root.easeInOut
            }
        }

        // Символ Компаса 56px — на месте аватара экрана блокировки
        Image {
            id: mark
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.5 - 60)
            width: 56
            height: 56
            source: "images/compass.svg"
            sourceSize: Qt.size(112, 112)
            smooth: true
        }

        // Ход загрузки: трек 120×4, заливка растёт со стадиями
        Rectangle {
            id: track
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: mark.bottom
            anchors.topMargin: 40
            width: 120
            height: 4
            radius: 2
            color: "#40ffffff"

            Rectangle {
                height: parent.height
                radius: parent.radius
                color: "#fbfaf7"
                width: Math.max(height, parent.width * Math.min(root.stage, 6) / 6)
                Behavior on width {
                    NumberAnimation { duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: root.easeOut }
                }
            }
        }
    }
}
