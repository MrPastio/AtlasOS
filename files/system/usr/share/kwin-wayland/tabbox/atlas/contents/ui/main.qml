/*
 Переключатель окон «Атласа» (Alt+Tab).
 Ряд миниатюр по центру экрана на материале панели, у каждой внизу значок приложения;
 выбранное окно — в кольце accent, под рядом его заголовок. Окон больше, чем влезает, —
 ряд прокручивается за выбором.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin

KWin.TabBoxSwitcher {
    id: tabBox

    readonly property bool dark: Kirigami.Theme.textColor.hslLightness > 0.5
    readonly property color ink: dark ? "#f2f0eb" : "#1d1c1a"
    readonly property color inkSecondary: dark ? "#b3afa7" : "#55524b"
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color rim: dark ? "#b3000000" : "#241d1c1a"

    readonly property real screenAspect: screenGeometry.height / Math.max(1, screenGeometry.width)
    readonly property int thumbWidth: 208
    readonly property int thumbHeight: Math.round(thumbWidth * screenAspect)
    readonly property int iconSize: 48
    readonly property int pad: 12 // space-3: от кольца до края карточки
    readonly property int cellWidth: thumbWidth + pad * 2
    readonly property int cellHeight: thumbHeight + iconSize / 2 + pad * 2

    Instantiator {
        active: tabBox.visible
        delegate: PlasmaCore.Dialog {
            location: PlasmaCore.Types.Floating
            visible: true
            flags: Qt.Popup | Qt.X11BypassWindowManagerHint
            x: tabBox.screenGeometry.x + Math.round((tabBox.screenGeometry.width - mainItem.width) / 2)
            y: tabBox.screenGeometry.y + Math.round((tabBox.screenGeometry.height - mainItem.height) / 2)

            mainItem: FocusScope {
                id: root
                focus: true
                width: Math.max(tabBox.cellWidth * 2, Math.min(row.count * tabBox.cellWidth, tabBox.screenGeometry.width * 0.9))
                height: tabBox.cellHeight + caption.height + 8

                ListView {
                    id: row
                    width: parent.width
                    height: tabBox.cellHeight
                    orientation: ListView.Horizontal
                    focus: true
                    model: tabBox.model
                    currentIndex: tabBox.currentIndex
                    keyNavigationWraps: true
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    // перемещение на месте — ease-in-out, dur-short
                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: 160
                    highlightMoveVelocity: -1
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: tabBox.cellWidth
                    preferredHighlightEnd: width - tabBox.cellWidth

                    // Кольцо фокуса: заливка accent 14% и край 2.5px, радиус radius-lg
                    highlight: Rectangle {
                        width: tabBox.cellWidth
                        height: tabBox.cellHeight
                        radius: 14
                        color: Qt.alpha(tabBox.accent, 0.14)
                        border.width: 2.5
                        border.color: tabBox.accent
                    }

                    delegate: Item {
                        id: cell
                        required property int index
                        required property var model
                        width: tabBox.cellWidth
                        height: tabBox.cellHeight

                        Accessible.name: model.caption
                        Accessible.role: Accessible.ListItem

                        Item {
                            id: shot
                            x: tabBox.pad
                            y: tabBox.pad
                            width: tabBox.thumbWidth
                            height: tabBox.thumbHeight

                            KWin.WindowThumbnail {
                                anchors.fill: parent
                                wId: cell.model.windowId
                            }
                        }

                        Kirigami.Icon {
                            anchors.horizontalCenter: shot.horizontalCenter
                            anchors.verticalCenter: shot.bottom
                            width: tabBox.iconSize
                            height: tabBox.iconSize
                            source: cell.model.icon
                        }

                        TapHandler {
                            onTapped: tabBox.model.activate(cell.index)
                        }
                        HoverHandler {
                            onHoveredChanged: if (hovered) row.currentIndex = cell.index
                        }
                    }

                    onCurrentIndexChanged: tabBox.currentIndex = currentIndex
                }

                Text {
                    id: caption
                    anchors.top: row.bottom
                    anchors.topMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, parent.width - 24)
                    text: row.currentItem ? row.currentItem.model.caption : ""
                    textFormat: Text.PlainText
                    elide: Text.ElideMiddle
                    color: tabBox.ink
                    font.family: "Onest"
                    font.pixelSize: 13 // control
                    font.weight: Font.Medium
                }

                Text {
                    anchors.centerIn: row
                    visible: row.count === 0
                    text: i18ndc("kwin", "@info:placeholder no entries in the task switcher", "No open windows")
                    color: tabBox.inkSecondary
                    font.family: "Onest"
                    font.pixelSize: 13
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left) {
                        row.decrementCurrentIndex();
                    } else if (event.key === Qt.Key_Right) {
                        row.incrementCurrentIndex();
                    }
                }
            }

            onSceneGraphError: () => {
                // пусто намеренно: иначе QtQuick падает в qFatal при сбросе графики
            }
        }
    }
}
