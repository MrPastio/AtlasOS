/*
 * Компас «Атласа» (01-shell.md, components/Launcher): поиск и запуск всего по центру экрана
 * на ¼ высоты над scrim. Без запроса — закреплённые приложения и недавние файлы, с запросом —
 * «Лучшее совпадение» и группы KRunner (приложения, настройки, файлы, калькулятор…).
 * Два окна Dialog без подложки: scrim на весь экран и панель, которую Компас рисует сам —
 * radius-2xl, тень shadow-popover. Размыть фон под окном без подложки нельзя, поэтому
 * материал непрозрачный, как при «Уменьшить прозрачность» (bg-elevated); над scrim это
 * не заметно. DashboardWindow из Kicker не подходит — он размывает весь экран.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.private.kicker as Kicker
import org.kde.milou as Milou

Item {
    id: launcher

    // Экран строки меню; поле вокруг панели — для тени
    readonly property rect screen: Plasmoid.containment.screenGeometry
    readonly property int shadowPad: 48
    readonly property bool shown: panelWindow.visible

    readonly property bool dark: Kirigami.Theme.textColor.hslLightness > 0.5
    readonly property color ink: dark ? "#f2f0eb" : "#1d1c1a"
    readonly property color inkSecondary: dark ? "#b3afa7" : "#55524b"
    readonly property color inkTertiary: dark ? "#9c988f" : "#6e6b64"
    readonly property color fillHover: dark ? "#12f2f0eb" : "#0d1d1c1a"
    readonly property color fillPressed: dark ? "#21f2f0eb" : "#1a1d1c1a"
    readonly property color lineStrong: dark ? "#26f2f0eb" : "#291d1c1a"
    readonly property color accent: Kirigami.Theme.highlightColor
    // on-accent из токенов («onAccent» QML принял бы за обработчик сигнала)
    readonly property color textOnAccent: dark ? "#06201e" : "#ffffff"

    readonly property string query: searchField.text.trim()
    property int current: 0
    // Активный список: результаты поиска или недавние файлы
    readonly property var list: query !== "" ? results : recent

    function toggle() {
        if (shown) {
            close();
        } else {
            scrimWindow.visible = true;
            panelWindow.visible = true;
        }
    }

    function close() {
        panelWindow.visible = false;
        scrimWindow.visible = false;
    }

    function openRow(index) {
        if (query !== "") {
            if (results.count === 0) {
                Qt.openUrlExternally("https://duckduckgo.com/?q=" + encodeURIComponent(query));
            } else {
                resultsModel.run(resultsModel.index(index, 0));
            }
        } else if (index >= 0 && index < recentModel.count) {
            recentModel.trigger(index, "", null);
        }
        close();
    }

    readonly property Milou.ResultsModel resultsModel: Milou.ResultsModel {
        queryString: launcher.query
        limit: 15
        onQueryStringChanged: launcher.current = 0
    }

    readonly property Kicker.SimpleFavoritesModel pinnedModel: Kicker.SimpleFavoritesModel {
        favorites: [
            "org.kde.dolphin.desktop",
            "preferred://browser",
            "steam.desktop",
            "org.kde.konsole.desktop",
            "io.github.kolunmi.Bazaar.desktop",
            "systemsettings.desktop"
        ]
    }

    readonly property Kicker.RecentUsageModel recentModel: Kicker.RecentUsageModel {
        shownItems: Kicker.RecentUsageModel.OnlyDocs
    }

    // scrim под временным слоем; щелчок мимо панели закрывает Компас
    PlasmaCore.Dialog {
        id: scrimWindow
        type: PlasmaCore.Dialog.AppletPopup
        location: PlasmaCore.Types.Floating
        backgroundHints: PlasmaCore.Dialog.NoBackground
        flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
        x: launcher.screen.x
        y: launcher.screen.y
        mainItem: MouseArea {
            width: launcher.screen.width
            height: launcher.screen.height
            onClicked: launcher.close()
            Rectangle {
                anchors.fill: parent
                color: launcher.dark ? "#59000000" : "#381d1c1a"
            }
        }
    }

    PlasmaCore.Dialog {
        id: panelWindow
        type: PlasmaCore.Dialog.AppletPopup
        location: PlasmaCore.Types.Floating
        backgroundHints: PlasmaCore.Dialog.NoBackground
        flags: Qt.WindowStaysOnTopHint
        hideOnWindowDeactivate: true
        // по центру, на ¼ высоты экрана
        x: launcher.screen.x + Math.round((launcher.screen.width - panel.width) / 2) - launcher.shadowPad
        y: launcher.screen.y + Math.round(launcher.screen.height / 4) - launcher.shadowPad
        onVisibleChanged: {
            searchField.clear();
            launcher.current = 0;
            if (visible) {
                searchField.forceActiveFocus(Qt.OtherFocusReason);
                appear.restart();
            } else {
                scrimWindow.visible = false;
            }
        }

        mainItem: MouseArea {
            width: panel.width + 2 * launcher.shadowPad
            height: panel.height + 2 * launcher.shadowPad
            onClicked: launcher.close()

            // shadow-popover
            RectangularShadow {
                anchors.fill: panel
                radius: panel.radius
                offset.y: 2
                blur: 6
                color: launcher.dark ? "#00000000" : "#141d1c1a"
                opacity: column.opacity
            }
            RectangularShadow {
                anchors.fill: panel
                radius: panel.radius
                offset.y: launcher.dark ? 12 : 10
                blur: launcher.dark ? 32 : 28
                spread: launcher.dark ? -4 : -6
                color: launcher.dark ? "#99000000" : "#331d1c1a"
                opacity: column.opacity
            }

            Rectangle {
                id: panel
                x: launcher.shadowPad
                y: launcher.shadowPad
                width: 640
                height: column.implicitHeight
                radius: 24 // radius-2xl
                color: launcher.dark ? "#33322f" : "#fcfbf9" // bg-elevated
                border.width: 1
                border.color: launcher.dark ? "#66000000" : "#121d1c1a" // кольцо 0.5px
                clip: true

                MouseArea {
                    anchors.fill: parent // щелчок по панели не закрывает Компас
                }

                // открытие — spring-gentle: содержимое проявляется и чуть подрастает
                ParallelAnimation {
                    id: appear
                    NumberAnimation { target: column; property: "scale"; from: 0.98; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
                    NumberAnimation { target: column; property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
                }

                ColumnLayout {
                    id: column
                    width: parent.width
                    spacing: 0
                    transformOrigin: Item.Top

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        spacing: 12
                        Kirigami.Icon {
                            implicitWidth: 22
                            implicitHeight: 22
                            source: Qt.resolvedUrl("../icons/search.svg")
                            isMask: true
                            color: launcher.inkSecondary
                        }
                        PlasmaComponents3.TextField {
                            id: searchField
                            Layout.fillWidth: true
                            placeholderText: "Найти приложение, файл, настройку…"
                            font.pixelSize: 20
                            font.weight: Font.Normal
                            color: launcher.ink
                            background: null
                            Keys.onDownPressed: launcher.current = Math.min(launcher.list.count - 1, launcher.current + 1)
                            Keys.onUpPressed: launcher.current = Math.max(0, launcher.current - 1)
                            Keys.onReturnPressed: launcher.openRow(launcher.current)
                            Keys.onEnterPressed: launcher.openRow(launcher.current)
                        // Esc: очистить запрос, второй Esc — закрыть
                        Keys.onEscapePressed: text !== "" ? clear() : launcher.close()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: launcher.lineStrong
                    }

                    // Без запроса: закреплённые сеткой и недавние файлы
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.margins: 8
                        spacing: 0
                        visible: launcher.query === ""

                        SectionTitle { text: "Закреплённые" }
                        GridLayout {
                            Layout.fillWidth: true
                            Layout.margins: 4
                            Layout.bottomMargin: 8
                            columns: 6
                            columnSpacing: 8
                            rowSpacing: 8
                            Repeater {
                                model: pinnedModel
                                MouseArea {
                                    id: app
                                    required property int index
                                    required property string display
                                    required property var decoration
                                    Layout.fillWidth: true
                                    implicitHeight: 84
                                    hoverEnabled: true
                                    scale: pressed ? 0.94 : 1
                                    Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
                                    onClicked: {
                                        pinnedModel.trigger(index, "", null);
                                        launcher.close();
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 12
                                        color: launcher.fillHover
                                        visible: app.containsMouse
                                    }
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.topMargin: 10
                                        anchors.bottomMargin: 8
                                        spacing: 6
                                        Kirigami.Icon {
                                            Layout.alignment: Qt.AlignHCenter
                                            implicitWidth: 48
                                            implicitHeight: 48
                                            source: app.decoration
                                        }
                                        PlasmaComponents3.Label {
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter
                                            text: app.display
                                            color: launcher.ink
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }

                        SectionTitle {
                            text: "Недавние"
                            visible: recent.count > 0
                        }
                        ListView {
                            id: recent
                            Layout.fillWidth: true
                            implicitHeight: Math.min(count, 5) * 44
                            interactive: false
                            model: recentModel
                            delegate: ResultRow {
                                required property var model
                                required property int index
                                width: ListView.view.width
                                row: index
                                title: model.display ?? ""
                                subtitle: model.description ?? ""
                                icon: model.decoration
                            }
                        }
                    }

                    // С запросом: лучшее совпадение и группы KRunner
                    ListView {
                        id: results
                        Layout.fillWidth: true
                        Layout.margins: 8
                        implicitHeight: Math.min(contentHeight, 360)
                        visible: launcher.query !== "" && count > 0
                        clip: true
                        model: resultsModel
                        currentIndex: launcher.current
                        highlightMoveDuration: 0
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                        section.property: "category"
                        delegate: ColumnLayout {
                            id: entry
                            required property var model
                            required property int index
                            width: ListView.view.width
                            spacing: 0
                            SectionTitle {
                                text: entry.index === 0 ? "Лучшее совпадение" : entry.ListView.section
                                visible: entry.index <= 1 || entry.ListView.section !== entry.ListView.previousSection
                            }
                            ResultRow {
                                Layout.fillWidth: true
                                row: entry.index
                                title: entry.model.display ?? ""
                                subtitle: entry.model.subtext ?? ""
                                kind: entry.model.category ?? ""
                                icon: entry.model.decoration
                            }
                        }
                    }

                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        Layout.margins: 20
                        Layout.topMargin: 32
                        Layout.bottomMargin: 32
                        visible: launcher.query !== "" && results.count === 0 && !resultsModel.querying
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "Ничего не найдено по запросу «" + launcher.query + "».\nНажмите ↵, чтобы искать в интернете."
                        color: launcher.inkSecondary
                        font.pixelSize: 13
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: launcher.lineStrong
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        spacing: 16
                        Hint { key: "↵"; text: "Открыть" }
                        Hint { key: "↑↓"; text: "Выбрать" }
                        Item { Layout.fillWidth: true }
                        Hint { key: "Esc"; text: "Закрыть" }
                    }
                }
            }
        }
    }

    component SectionTitle: PlasmaComponents3.Label {
        Layout.fillWidth: true
        leftPadding: 8
        topPadding: 8
        bottomPadding: 4
        color: launcher.inkSecondary
        font.pixelSize: 11
        font.weight: Font.DemiBold
    }

    component Hint: RowLayout {
        property string key
        property string text
        spacing: 0
        Rectangle {
            implicitWidth: Math.max(18, keyLabel.implicitWidth + 8)
            implicitHeight: 18
            Layout.rightMargin: 6
            radius: 4
            color: launcher.fillPressed
            PlasmaComponents3.Label {
                id: keyLabel
                anchors.centerIn: parent
                text: parent.parent.key
                color: launcher.inkSecondary
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
        PlasmaComponents3.Label {
            text: parent.text
            color: launcher.inkSecondary
            font.pixelSize: 11
            font.weight: Font.Medium
        }
    }

    // Строка результата: значок 32, имя и подпись, тип справа; выбранная — заливка accent
    component ResultRow: MouseArea {
        id: resultRow
        property int row: -1
        property string title
        property string subtitle
        property string kind
        property var icon
        readonly property bool selected: row === launcher.current
        // Ответ важнее списка: вычисление — крупно, «= 87»
        readonly property bool calc: /calcul|калькул/i.test(kind)
        readonly property color fg: selected ? launcher.textOnAccent : launcher.ink
        readonly property color fgSecondary: selected ? launcher.textOnAccent : launcher.inkSecondary
        readonly property color fgTertiary: selected ? launcher.textOnAccent : launcher.inkTertiary

        implicitHeight: calc ? 56 : 44
        hoverEnabled: true
        onPositionChanged: launcher.current = row
        onClicked: launcher.openRow(row)

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: resultRow.selected ? launcher.accent : resultRow.containsMouse ? launcher.fillHover : "transparent"
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 12
            spacing: 12
            Kirigami.Icon {
                implicitWidth: 32
                implicitHeight: 32
                source: resultRow.icon
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: resultRow.calc ? "= " + resultRow.title : resultRow.title
                    textFormat: Text.PlainText
                    color: resultRow.fg
                    font.pixelSize: resultRow.calc ? 28 : 14
                    font.weight: resultRow.calc ? Font.Light : Font.Medium
                    font.features: resultRow.calc ? { "tnum": 1 } : {}
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: resultRow.subtitle
                    visible: text !== "" && text !== resultRow.title
                    color: resultRow.fgSecondary
                    font.pixelSize: 12
                    elide: Text.ElideMiddle
                }
            }
            Text {
                text: resultRow.kind
                visible: text !== ""
                color: resultRow.fgTertiary
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
    }
}
