/*
 * Толстый ползунок Пульта (Slider variant="panel"): полоса 28px, символ внутри.
 * Перетаскивание идёт за курсором 1:1, щелчок и стрелки доводят значение пружиной.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick

Item {
    id: slider
    required property Tokens tokens
    property string glyph
    property real value: 0 // 0..1, источник истины снаружи
    property real shown: value
    signal moved(real value)

    implicitHeight: 28
    activeFocusOnTab: true
    Accessible.role: Accessible.Slider

    Binding on shown {
        value: slider.value
        when: !area.pressed
        restoreMode: Binding.RestoreNone
    }
    Behavior on shown {
        enabled: !area.dragged
        NumberAnimation {
            duration: slider.tokens.durSpringSnappy
            easing.type: Easing.OutBack
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: slider.tokens.fillPressed
        border.width: 1
        border.color: slider.tokens.line
    }
    Rectangle {
        height: parent.height
        width: Math.max(height, Math.min(1, slider.shown) * slider.width)
        radius: height / 2
        color: slider.tokens.dark ? slider.tokens.ink : slider.tokens.control
        border.width: slider.tokens.dark ? 0 : 1
        border.color: slider.tokens.controlRing
    }
    Glyph {
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        name: slider.glyph
        color: slider.tokens.dark ? slider.tokens.bgCanvas : slider.tokens.inkSecondary
    }

    MouseArea {
        id: area
        property bool dragged: false
        anchors.fill: parent
        function valueAt(x) {
            return Math.max(0, Math.min(1, x / width));
        }
        onPressed: mouse => {
            dragged = false;
            slider.shown = valueAt(mouse.x);
            slider.moved(valueAt(mouse.x));
        }
        onPositionChanged: mouse => {
            dragged = true;
            slider.shown = valueAt(mouse.x);
            slider.moved(slider.shown);
        }
        onReleased: dragged = false
        onWheel: wheel => slider.moved(Math.max(0, Math.min(1, slider.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }

    Keys.onLeftPressed: slider.moved(Math.max(0, slider.value - 0.05))
    Keys.onRightPressed: slider.moved(Math.min(1, slider.value + 0.05))
}
