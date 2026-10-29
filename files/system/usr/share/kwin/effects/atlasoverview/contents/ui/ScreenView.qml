/*
 * Обзор на одном экране: размытые обои и scrim, лента столов сверху, окна текущего стола
 * без перекрытий (WindowHeap из KWin — та же раскладка и перетаскивание, что у штатного
 * Обзора), поиск по окнам — просто начать печатать. Клик по окну — фокус и выход, клик мимо
 * или Esc — выход. Окно можно перетащить на стол в ленте.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWinComponents
import org.kde.kwin.private.effects

FocusScope {
    id: container
    focus: true

    // WindowHeap и WindowHeapDelegate ищут effect и targetScreen по имени
    readonly property QtObject effect: KWinComponents.SceneView.effect
    readonly property QtObject targetScreen: KWinComponents.SceneView.screen
    readonly property real factor: effect.partialActivationFactor

    readonly property bool dark: Kirigami.Theme.textColor.hslLightness > 0.5
    readonly property color ink: dark ? "#f2f0eb" : "#1d1c1a"
    readonly property color inkSecondary: dark ? "#b3afa7" : "#55524b"
    readonly property color accent: Kirigami.Theme.highlightColor
    // material-popover / material-panel без размытия — над и так размытыми обоями
    readonly property color material: dark ? "#ea232220" : "#e0f3f2ee"
    readonly property color rim: dark ? "#b3000000" : "#241d1c1a"

    readonly property real screenAspect: targetScreen.geometry.height / Math.max(1, targetScreen.geometry.width)
    readonly property int tileWidth: 168
    readonly property int tileHeight: Math.round(tileWidth * screenAspect)

    // Раскладка окон включается сразу: ExpoCell сам ведёт окна от их мест к сетке по factor
    property bool organized: false
    Component.onCompleted: {
        organized = true;
        forceActiveFocus();
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            if (effect.searchText !== "") {
                effect.searchText = "";
            } else {
                effect.deactivate();
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Backspace) {
            effect.searchText = effect.searchText.slice(0, -1);
            event.accepted = true;
        } else if (event.text.length === 1 && event.text >= " " && !(event.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.AltModifier))) {
            effect.searchText += event.text;
            heap.resetSelected();
            heap.selectNextItem(WindowHeap.Direction.Down);
            event.accepted = true;
        }
    }
    Keys.priority: Keys.AfterItem
    Keys.forwardTo: [heap]

    KWinComponents.WindowModel {
        id: stackModel
    }

    // ── Обои: размытие до blur-wallpaper, насыщенность +80%, scrim ──
    KWinComponents.DesktopBackground {
        id: wallpaper
        anchors.fill: parent
        activity: KWinComponents.Workspace.currentActivity
        desktop: KWinComponents.Workspace.currentDesktop
        outputName: container.targetScreen.name
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: container.factor
        saturation: 0.3 * container.factor
    }
    Rectangle {
        anchors.fill: parent
        color: container.dark ? "#59000000" : "#381d1c1a"
        opacity: container.factor

        TapHandler {
            onTapped: container.effect.deactivate()
        }
    }

    // ── Лента столов сверху ─────────────────────────────────
    Row {
        id: strip
        anchors.horizontalCenter: parent.horizontalCenter
        y: 22 - (height + 22) * (1 - container.factor)
        opacity: container.factor
        spacing: 14

        Repeater {
            model: KWinComponents.VirtualDesktopModel {}

            delegate: Item {
                id: space
                required property QtObject desktop
                required property int index
                readonly property bool current: KWinComponents.Workspace.currentDesktop === desktop

                width: container.tileWidth
                height: container.tileHeight + 26

                // Миниатюра стола: обои и окна в масштабе, radius-md
                Item {
                    id: tile
                    width: container.tileWidth
                    height: container.tileHeight

                    Item {
                        id: miniature
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: tileMask
                        }

                        Item {
                            width: container.targetScreen.geometry.width
                            height: container.targetScreen.geometry.height
                            scale: container.tileWidth / width
                            transformOrigin: Item.TopLeft

                            KWinComponents.DesktopBackground {
                                anchors.fill: parent
                                activity: KWinComponents.Workspace.currentActivity
                                desktop: space.desktop
                                outputName: container.targetScreen.name
                            }
                            Repeater {
                                model: KWinComponents.WindowFilterModel {
                                    activity: KWinComponents.Workspace.currentActivity
                                    desktop: space.desktop
                                    screenName: container.targetScreen.name
                                    windowModel: stackModel
                                    windowType: ~KWinComponents.WindowFilterModel.Dock
                                                & ~KWinComponents.WindowFilterModel.Desktop
                                                & ~KWinComponents.WindowFilterModel.Notification
                                                & ~KWinComponents.WindowFilterModel.CriticalNotification
                                }
                                KWinComponents.WindowThumbnail {
                                    wId: model.window.internalId
                                    x: model.window.x - container.targetScreen.geometry.x
                                    y: model.window.y - container.targetScreen.geometry.y
                                    width: model.window.width
                                    height: model.window.height
                                    z: model.window.stackingOrder
                                    visible: !model.window.minimized
                                }
                            }
                        }
                    }
                    Rectangle {
                        id: tileMask
                        anchors.fill: parent
                        radius: 10
                        visible: false
                        layer.enabled: true
                    }

                    // Край тонкий; у текущего — кольцо фокуса: зазор 2px и 2.5px accent
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: space.current ? -4.5 : 0
                        radius: space.current ? 14.5 : 10
                        color: "transparent"
                        border.width: space.current ? 2.5 : 1
                        border.color: space.current ? container.accent : (tileDrop.containsDrag || tileHover.hovered ? container.accent : container.rim)
                    }

                    HoverHandler { id: tileHover }
                    TapHandler {
                        onTapped: KWinComponents.Workspace.currentDesktop = space.desktop
                    }

                    // Окно, брошенное на стол, переезжает на него
                    DropArea {
                        id: tileDrop
                        anchors.fill: parent
                        onDropped: drop => {
                            drop.accepted = true;
                            drop.source.desktops = [space.desktop];
                        }
                    }

                    // Убрать стол — крестик при наведении, если столов больше одного
                    Rectangle {
                        x: -6
                        y: -6
                        width: 20
                        height: 20
                        radius: 10
                        visible: tileHover.hovered && KWinComponents.Workspace.desktops.length > 1
                        color: container.dark ? "#3a3936" : "#fcfbf9"
                        border.width: 1
                        border.color: container.rim
                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: container.inkSecondary
                            font.family: "Onest"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        TapHandler {
                            onTapped: KWinComponents.Workspace.removeDesktop(space.desktop)
                        }
                    }
                }

                // Подпись стола — 12/500
                Text {
                    anchors.horizontalCenter: tile.horizontalCenter
                    anchors.top: tile.bottom
                    anchors.topMargin: 8
                    width: tile.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: space.desktop.name || ("Рабочий стол " + (space.index + 1))
                    color: container.ink
                    font.family: "Onest"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }
        }

        // Новый стол — плитка с плюсом
        Rectangle {
            width: container.tileHeight
            height: container.tileHeight
            radius: 10
            color: addHover.hovered ? Qt.lighter(container.material, 1.04) : container.material
            border.width: 1
            border.color: container.rim
            Text {
                anchors.centerIn: parent
                text: "+"
                color: container.ink
                font.family: "Onest"
                font.pixelSize: 28
                font.weight: Font.Light
            }
            HoverHandler { id: addHover }
            TapHandler {
                onTapped: KWinComponents.Workspace.createDesktop(KWinComponents.Workspace.desktops.length, "")
            }
            Accessible.role: Accessible.Button
            Accessible.name: "Новый рабочий стол"
        }
    }

    // ── Окна текущего стола ─────────────────────────────────
    WindowHeap {
        id: heap
        x: 48
        y: strip.y + strip.height + 32
        width: parent.width - 96
        height: parent.height - y - 48
        focus: true
        padding: 16
        organized: container.organized
        animationDuration: container.effect.animationDuration
        animationEnabled: container.organized
        model: KWinComponents.WindowFilterModel {
            activity: KWinComponents.Workspace.currentActivity
            desktop: KWinComponents.Workspace.currentDesktop
            screenName: container.targetScreen.name
            windowModel: stackModel
            filter: container.effect.searchText
            minimizedWindows: true
            windowType: ~KWinComponents.WindowFilterModel.Dock
                        & ~KWinComponents.WindowFilterModel.Desktop
                        & ~KWinComponents.WindowFilterModel.Notification
                        & ~KWinComponents.WindowFilterModel.CriticalNotification
        }
        onActivated: container.effect.deactivate()
    }

    // Пустой стол или ничего не найдено
    Text {
        anchors.centerIn: heap
        visible: heap.count === 0 && container.factor > 0.5
        opacity: container.factor
        text: container.effect.searchText !== ""
              ? "Ничего не найдено по запросу «" + container.effect.searchText + "»"
              : "На этом столе нет окон"
        color: container.inkSecondary
        font.family: "Onest"
        font.pixelSize: 15
    }

    // Строка поиска — появляется, когда начали печатать (пилюля material-popover)
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        visible: container.effect.searchText !== ""
        width: Math.max(200, searchText.implicitWidth + 48)
        height: 32
        radius: 16
        color: container.material
        border.width: 1
        border.color: container.rim
        Text {
            id: searchText
            anchors.centerIn: parent
            text: "Поиск: " + container.effect.searchText
            color: container.ink
            font.family: "Onest"
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }
}
