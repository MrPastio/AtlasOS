/*
 * Виджет «Календарь» в Сводке: месяц сеткой, сегодня — заливка accent, стрелки листают
 * месяцы, щелчок по заголовку возвращает к текущему. Неделя — по локали.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

Rectangle {
    id: calendar

    property date now: new Date()
    // Показанный месяц: смещение от текущего
    property int offset: 0
    readonly property date shown: new Date(now.getFullYear(), now.getMonth() + offset, 1)
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7 // 0 — воскресенье

    Tokens { id: atlas }

    implicitHeight: column.implicitHeight + 24
    radius: atlas.radiusCard
    color: atlas.control
    border.width: 1
    border.color: atlas.cardRing

    ColumnLayout {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            // «Октябрь 2026» — headline 13/600
            Text {
                Layout.fillWidth: true
                text: {
                    const s = Qt.locale().standaloneMonthName(calendar.shown.getMonth(), Locale.LongFormat);
                    return s.charAt(0).toUpperCase() + s.slice(1) + " " + calendar.shown.getFullYear();
                }
                color: calendar.offset === 0 ? atlas.ink : atlas.accentInk
                font.family: "Onest"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                TapHandler { onTapped: calendar.offset = 0 }
            }
            NavButton { text: "‹"; onClicked: calendar.offset -= 1; Accessible.name: "Предыдущий месяц" }
            NavButton { text: "›"; onClicked: calendar.offset += 1; Accessible.name: "Следующий месяц" }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 2
            columnSpacing: 0

            // Дни недели — caption 11/500, ink-tertiary
            Repeater {
                model: 7
                delegate: Text {
                    required property int index
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().dayName((calendar.firstDay + index) % 7, Locale.ShortFormat)
                    color: atlas.inkTertiary
                    font.family: "Onest"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }

            // 6 недель по 7 дней, начиная с недели первого числа
            Repeater {
                model: 42
                delegate: Item {
                    id: day
                    required property int index
                    readonly property int lead: (calendar.shown.getDay() - calendar.firstDay + 7) % 7
                    readonly property date date: new Date(calendar.shown.getFullYear(), calendar.shown.getMonth(), 1 - lead + index)
                    readonly property bool inMonth: date.getMonth() === calendar.shown.getMonth()
                    readonly property bool today: date.toDateString() === calendar.now.toDateString()

                    Layout.fillWidth: true
                    implicitHeight: 28

                    Rectangle {
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        radius: 13
                        color: atlas.accent
                        visible: day.today
                    }
                    Text {
                        anchors.centerIn: parent
                        text: day.date.getDate()
                        color: day.today ? atlas.textOnAccent : day.inMonth ? atlas.ink : atlas.inkTertiary
                        opacity: day.inMonth || day.today ? 1 : 0.6
                        font.family: "Onest"
                        font.pixelSize: 12
                        font.weight: day.today ? Font.DemiBold : Font.Normal
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }
    }

    component NavButton: QQC2.AbstractButton {
        id: nav
        implicitWidth: 24
        implicitHeight: 24
        contentItem: Text {
            text: nav.text
            color: atlas.inkSecondary
            font.family: "Onest"
            font.pixelSize: 17
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: height / 2
            color: nav.down ? atlas.fillPressed : nav.hovered ? atlas.fillHover : "transparent"
        }
    }
}
