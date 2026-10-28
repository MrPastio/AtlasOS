/*
 * Обзор «Атласа» (01-shell.md «Временные слои», 06-motion.md «Обзор»): эффект KWin на QML.
 * Заменяет штатный Обзор KWin (он выключен в kwinrc). Вызов: ❖ Tab, горячий угол слева сверху,
 * три пальца вверх по тачпаду. Окна летят на места в сетке, столы выезжают лентой сверху,
 * обои размываются до blur-wallpaper; ease-in-out, dur-xlong. Жестом — 1:1 за пальцем.
 *
 * partialActivationFactor (0 — стол, 1 — Обзор) читают и WindowHeapDelegate из KWin,
 * и ScreenView: одно число ведёт всё движение.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kwin as KWinComponents

KWinComponents.SceneEffect {
    id: effect

    property bool activated: false
    readonly property int animationDuration: 450 // dur-xlong
    // ease-in-out из 06-motion.md
    readonly property var easeInOut: [0.65, 0, 0.35, 1, 1, 1]

    // Жест: пока палец на тачпаде, коэффициент — его прогресс, без сглаживания
    property bool gestureInProgress: false
    property real gestureProgress: 0
    property real partialActivationFactor: gestureInProgress ? gestureProgress : (activated ? 1 : 0)
    Behavior on partialActivationFactor {
        enabled: !effect.gestureInProgress
        NumberAnimation {
            duration: effect.animationDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: effect.easeInOut
        }
    }

    // Поиск по окнам: печатать прямо в Обзоре
    property string searchText: ""

    delegate: Qt.createComponent("ScreenView.qml")

    KWinComponents.ShortcutHandler {
        name: "Atlas Overview"
        text: "Обзор"
        sequence: "Meta+Tab"
        onActivated: effect.toggle()
    }

    KWinComponents.ScreenEdgeHandler {
        edge: KWinComponents.ScreenEdgeHandler.TopLeftEdge
        mode: KWinComponents.ScreenEdgeHandler.Pointer
        onActivated: effect.toggle()
    }

    // Три пальца вверх — открыть, вниз — закрыть; 1:1, после отпускания доводит анимация
    KWinComponents.SwipeGestureHandler {
        direction: KWinComponents.SwipeGestureHandler.Direction.Up
        fingerCount: 3
        deviceType: KWinComponents.SwipeGestureHandler.Device.Touchpad
        onProgressChanged: {
            if (effect.activated || progress <= 0) {
                return;
            }
            effect.visible = true;
            effect.gestureInProgress = true;
            effect.gestureProgress = progress;
        }
        onActivated: {
            effect.gestureInProgress = false;
            effect.activate();
        }
        onCancelled: {
            effect.gestureInProgress = false;
            effect.deactivate();
        }
    }
    KWinComponents.SwipeGestureHandler {
        direction: KWinComponents.SwipeGestureHandler.Direction.Down
        fingerCount: 3
        deviceType: KWinComponents.SwipeGestureHandler.Device.Touchpad
        onProgressChanged: {
            if (!effect.activated || progress <= 0) {
                return;
            }
            effect.gestureInProgress = true;
            effect.gestureProgress = 1 - progress;
        }
        onActivated: {
            effect.gestureInProgress = false;
            effect.deactivate();
        }
        onCancelled: effect.gestureInProgress = false
    }

    Timer {
        id: deactivateTimer
        interval: effect.animationDuration
        onTriggered: {
            effect.visible = false;
            effect.searchText = "";
        }
    }

    function toggle() {
        if (activated) {
            deactivate();
        } else {
            activate();
        }
    }

    function activate() {
        deactivateTimer.stop();
        visible = true;
        activated = true;
    }

    function deactivate() {
        activated = false;
        deactivateTimer.restart();
    }
}
