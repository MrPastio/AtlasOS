/*
 * Карточка уведомления «Атласа» (components/Notification): значок 36px, строка «Приложение ·
 * ещё N · время», заголовок, текст до трёх строк, до двух действий. Крестик закрытия — слева
 * сверху, при наведении. Одна и та же карточка — в баннере и в Сводке; в Сводке у неё своя
 * подложка (filled), в баннере подложку даёт окно.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: card

    property string appName
    property string appIcon
    property var image
    property string iconName
    property string summary
    property string body
    property date time
    property var actionNames: []
    property var actionLabels: []
    property bool showApp: true
    property int stackCount: 0
    property bool closable: true
    property bool filled: false
    // Задание (копирование файлов): вместо текста — ход и «Отменить»
    property bool isJob: false
    property int percentage: 0
    property bool killable: false

    signal clicked()
    signal closeClicked()
    signal actionInvoked(string actionName)
    signal killClicked()

    readonly property alias hovered: hover.hovered

    implicitWidth: 352
    implicitHeight: content.implicitHeight + 24

    Tokens { id: atlas }

    HoverHandler { id: hover }

    TapHandler {
        id: tap
        onTapped: card.clicked()
    }

    Rectangle {
        anchors.fill: parent
        visible: card.filled
        radius: atlas.radiusCard
        color: tap.pressed ? Qt.darker(atlas.control, 1.04) : atlas.control
        border.width: 1
        border.color: atlas.cardRing
    }

    RowLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 12
            rightMargin: 14
            topMargin: 12
        }
        spacing: 10

        // Значок 36px: картинка уведомления (аватар, снимок; QImage) или значок приложения
        Kirigami.Icon {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 36
            implicitHeight: 36
            source: card.image || card.iconName || card.appIcon || "preferences-desktop-notification-bell"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            // Мета: приложение · ещё N · время (11/500, ink-secondary)
            RowLayout {
                Layout.fillWidth: true
                visible: card.showApp
                spacing: 6
                Text {
                    text: card.appName + (card.stackCount > 0 ? " · ещё " + card.stackCount : "")
                    color: atlas.inkSecondary
                    font.family: "Onest"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.letterSpacing: 0.13
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                TimeLabel {}
            }

            // Заголовок: кто или что (13/600); в группе Сводки время — в этой строке
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: card.showApp ? 2 : 0
                visible: card.summary.length > 0 || !card.showApp
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: card.summary
                    textFormat: Text.PlainText
                    color: atlas.ink
                    font.family: "Onest"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    lineHeight: 18
                    lineHeightMode: Text.FixedHeight
                    elide: Text.ElideRight
                }
                TimeLabel { visible: !card.showApp }
            }

            // Текст: суть, до трёх строк (13/400)
            Text {
                Layout.fillWidth: true
                visible: !card.isJob && text.length > 0
                text: card.body
                textFormat: Text.StyledText
                color: atlas.ink
                linkColor: atlas.accentInk
                font.family: "Onest"
                font.pixelSize: 13
                lineHeight: 18
                lineHeightMode: Text.FixedHeight
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            // Задание: полоска хода и «Отменить»
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: card.isJob
                spacing: 8
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 4
                    radius: 2
                    color: atlas.line
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, card.percentage)) / 100
                        height: parent.height
                        radius: parent.radius
                        color: atlas.accent
                        Behavior on width { NumberAnimation { duration: atlas.durMedium; easing.type: Easing.BezierSpline; easing.bezierCurve: atlas.easeOut } }
                    }
                }
                Text {
                    text: card.percentage + "%"
                    color: atlas.inkSecondary
                    font.family: "Onest"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
            }

            // Действия — не больше двух, во всю ширину поровну; последнее — главное
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                visible: card.isJob ? card.killable : card.actionNames.length > 0
                spacing: atlas.gap

                Repeater {
                    model: card.isJob ? 0 : Math.min(2, card.actionNames.length)
                    delegate: CardButton {
                        required property int index
                        Layout.fillWidth: true
                        text: card.actionLabels[index] || ""
                        primary: index === Math.min(2, card.actionNames.length) - 1 && card.actionNames.length > 1
                        onClicked: card.actionInvoked(card.actionNames[index])
                    }
                }
                CardButton {
                    visible: card.isJob
                    Layout.fillWidth: true
                    text: "Отменить"
                    onClicked: card.killClicked()
                }
            }
        }
    }

    // Крестик закрытия — слева сверху, при наведении (20px, круглый)
    Rectangle {
        id: closeButton
        x: 2
        y: 2
        width: 20
        height: 20
        radius: 10
        visible: card.closable
        color: closeArea.pressed ? atlas.fillPressed : (atlas.dark ? "#3a3936" : "#fcfbf9")
        border.width: 1
        border.color: atlas.controlRing
        opacity: card.hovered ? 1 : 0
        scale: card.hovered ? 1 : 0.7
        Behavior on opacity { NumberAnimation { duration: atlas.durMicro } }
        Behavior on scale { NumberAnimation { duration: atlas.durMicro } }

        Text {
            anchors.centerIn: parent
            text: "×"
            color: atlas.inkSecondary
            font.family: "Onest"
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        MouseArea {
            id: closeArea
            anchors.fill: parent
            enabled: card.hovered
            onClicked: card.closeClicked()
        }
        Accessible.role: Accessible.Button
        Accessible.name: "Закрыть уведомление"
    }

    component TimeLabel: Text {
        text: atlas.relativeTime(card.time)
        color: atlas.inkSecondary
        font.family: "Onest"
        font.pixelSize: 11
        font.weight: Font.Medium
        font.features: { "tnum": 1 }
    }

    component CardButton: QQC2.AbstractButton {
        id: button
        property bool primary: false
        implicitHeight: 28
        implicitWidth: label.implicitWidth + 20
        contentItem: Text {
            id: label
            text: button.text
            color: button.primary ? atlas.textOnAccent : atlas.ink
            font.family: "Onest"
            font.pixelSize: 13
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: 6
            color: button.primary
                ? (button.down ? Qt.darker(atlas.accent, 1.15) : button.hovered ? Qt.darker(atlas.accent, 1.07) : atlas.accent)
                : (button.down ? atlas.fillPressed : button.hovered ? atlas.fillHover : atlas.control)
            border.width: button.primary ? 0 : 1
            border.color: atlas.controlRing
        }
    }
}
