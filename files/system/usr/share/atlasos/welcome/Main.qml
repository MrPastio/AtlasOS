// «Добро пожаловать в Атлас»: три шага первого входа — оформление, приложения, готово.
// Запускается atlas-welcome (files/src/atlas-welcome); sys.run() — мост к процессам.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: win
    width: 760
    height: 560
    minimumWidth: 640
    minimumHeight: 500
    title: "Добро пожаловать"
    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.None

    readonly property bool dark: Kirigami.Theme.textColor.hslLightness > 0.5
    readonly property color inkSecondary: dark ? "#b3afa7" : "#55524b"
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color rim: dark ? "#3d3b37" : "#e2dfd8"
    readonly property color raised: dark ? "#2f2e2b" : "#fcfbf9"

    property int step: 0 // 0 привет, 1 оформление, 2 приложения, 3 готово
    property string look: "light"
    property var installed: []
    property bool installing: false
    property string installError: ""

    // Приложения из Flathub, которые чаще всего ставят на Атлас; Steam уже в системе
    readonly property var apps: [
        { id: "org.mozilla.firefox", name: "Firefox", note: "Браузер" },
        { id: "com.discordapp.Discord", name: "Discord", note: "Голос и чаты" },
        { id: "org.telegram.desktop", name: "Telegram", note: "Мессенджер" },
        { id: "com.obsproject.Studio", name: "OBS Studio", note: "Запись и трансляции" },
        { id: "com.spotify.Client", name: "Spotify", note: "Музыка" },
        { id: "org.libreoffice.LibreOffice", name: "LibreOffice", note: "Документы и таблицы" }
    ]
    property var chosen: ({ "com.discordapp.Discord": true, "org.telegram.desktop": true, "com.obsproject.Studio": true })

    Component.onCompleted: sys.run("list", "flatpak", ["list", "--app", "--columns=application"])

    Connections {
        target: sys
        function onFinished(tag, code, output) {
            if (tag === "list") {
                win.installed = output.split("\n").map(s => s.trim()).filter(s => s.length);
            } else if (tag === "install") {
                win.installing = false;
                if (code === 0) {
                    win.step = 3;
                } else {
                    win.installError = "Не удалось установить: " + (output.trim().split("\n").pop() || "ошибка flatpak");
                }
                sys.run("list", "flatpak", ["list", "--app", "--columns=application"]);
            }
        }
    }

    function applyLook(which) {
        look = which;
        if (which === "auto") {
            sys.run("look", "kwriteconfig6", ["--file", "kdeglobals", "--group", "KDE", "--key", "AutomaticLookAndFeel", "true"]);
            return;
        }
        sys.run("look", "sh", ["-c", "kwriteconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel false && plasma-apply-lookandfeel -a org.atlasos." + which + ".desktop"]);
    }

    function toInstall() {
        return apps.filter(a => chosen[a.id] && installed.indexOf(a.id) < 0).map(a => a.id);
    }

    function install() {
        const ids = toInstall();
        if (ids.length === 0) {
            step = 3;
            return;
        }
        installError = "";
        installing = true;
        sys.run("install", "flatpak", ["install", "-y", "--noninteractive", "--system", "flathub"].concat(ids));
    }

    component Title: QQC2.Label {
        Layout.fillWidth: true
        font.family: "Onest"
        font.pixelSize: 28 // large-title
        font.weight: Font.Bold
        wrapMode: Text.WordWrap
    }
    component Lead: QQC2.Label {
        Layout.fillWidth: true
        color: win.inkSecondary
        font.family: "Onest"
        font.pixelSize: 14 // body
        wrapMode: Text.WordWrap
        lineHeight: 1.35
    }

    // Карточка выбора оформления: миниатюра окна в светлой или тёмной гамме
    component LookCard: Rectangle {
        id: card
        property string which
        property string label
        property color paper
        property color ink
        Layout.fillWidth: true
        Layout.preferredHeight: 168
        radius: 14
        color: win.raised
        border.width: win.look === which ? 2.5 : 1
        border.color: win.look === which ? win.accent : win.rim

        Rectangle {
            id: preview
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            height: 104
            radius: 8
            clip: true
            gradient: Gradient {
                GradientStop { position: 0; color: card.which === "auto" ? "#f6f5f2" : card.paper }
                GradientStop { position: 1; color: card.which === "auto" ? "#262523" : card.paper }
            }
            border.width: 1
            border.color: win.rim
            // Окно на миниатюре: заголовок с тремя кнопками и строки текста
            Rectangle {
                x: 16; y: 18; width: parent.width - 32; height: parent.height - 30
                radius: 6
                color: card.which === "dark" ? "#2f2e2b" : "#fcfbf9"
                border.width: 1
                border.color: card.which === "dark" ? "#45433f" : "#e2dfd8"
                Row {
                    x: 8; y: 7; spacing: 5
                    Repeater {
                        model: ["#ec6a5e", "#f4bf4f", "#61c554"]
                        Rectangle { width: 8; height: 8; radius: 4; color: modelData }
                    }
                }
                Column {
                    x: 10; y: 26; spacing: 6
                    Repeater {
                        model: [0.7, 0.5, 0.6]
                        Rectangle {
                            width: (preview.width - 52) * modelData
                            height: 5
                            radius: 2.5
                            color: index === 0 ? win.accent : (card.which === "dark" ? "#55524b" : "#d8d4cc")
                        }
                    }
                }
            }
        }
        QQC2.Label {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 14 }
            text: card.label
            font.family: "Onest"
            font.pixelSize: 13
            font.weight: Font.Medium
        }
        TapHandler { onTapped: win.applyLook(card.which) }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    pageStack.initialPage: Kirigami.Page {
        padding: 40
        bottomPadding: 24

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Шаг 0 — привет
            ColumnLayout {
                visible: win.step === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                Item { Layout.fillHeight: true }
                Kirigami.Icon {
                    Layout.alignment: Qt.AlignLeft
                    implicitWidth: 64
                    implicitHeight: 64
                    source: "compass"
                    fallback: "preferences-desktop-theme-global"
                    color: win.accent
                    isMask: true
                }
                Title { text: "Добро пожаловать в Атлас" }
                Lead {
                    text: "Пара шагов — и система готова: выберите оформление и поставьте приложения, которыми пользуетесь. Всё это можно поменять потом в Параметрах."
                }
                Item { Layout.fillHeight: true }
            }

            // Шаг 1 — оформление
            ColumnLayout {
                visible: win.step === 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                Title { text: "Оформление" }
                Lead { text: "Светлое, тёмное или по времени суток. Меняется сразу — можно примерить." }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    spacing: 16
                    LookCard { which: "light"; label: "Светлое"; paper: "#f6f5f2"; ink: "#1d1c1a" }
                    LookCard { which: "dark"; label: "Тёмное"; paper: "#262523"; ink: "#f2f0eb" }
                    LookCard { which: "auto"; label: "Автоматически"; paper: "#f6f5f2"; ink: "#1d1c1a" }
                }
                Item { Layout.fillHeight: true }
            }

            // Шаг 2 — приложения
            ColumnLayout {
                visible: win.step === 2
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                Title { text: "Приложения" }
                Lead { text: "Отметьте, что поставить из Flathub. Steam и игровые инструменты уже в системе." }
                QQC2.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: 4
                    ListView {
                        id: appList
                        model: win.apps
                        spacing: 0
                        clip: true
                        delegate: QQC2.ItemDelegate {
                            id: row
                            required property var modelData
                            readonly property bool have: win.installed.indexOf(modelData.id) >= 0
                            width: appList.width
                            enabled: !have && !win.installing
                            onClicked: {
                                const c = Object.assign({}, win.chosen);
                                c[modelData.id] = !c[modelData.id];
                                win.chosen = c;
                            }
                            contentItem: RowLayout {
                                spacing: 12
                                Kirigami.Icon {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    source: row.modelData.id
                                    fallback: "application-x-flatpak"
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    QQC2.Label { text: row.modelData.name; font.family: "Onest"; font.pixelSize: 13; font.weight: Font.Medium }
                                    QQC2.Label { text: row.have ? "Уже установлено" : row.modelData.note; color: win.inkSecondary; font.family: "Onest"; font.pixelSize: 12 }
                                }
                                QQC2.CheckBox {
                                    checked: row.have || !!win.chosen[row.modelData.id]
                                    enabled: row.enabled
                                    onToggled: row.clicked()
                                }
                            }
                        }
                    }
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    visible: win.installing || win.installError.length > 0
                    text: win.installing ? "Устанавливаю… Это может занять несколько минут." : win.installError
                    color: win.installing ? win.inkSecondary : Kirigami.Theme.negativeTextColor
                    font.family: "Onest"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
                QQC2.ProgressBar {
                    Layout.fillWidth: true
                    visible: win.installing
                    indeterminate: true
                }
            }

            // Шаг 3 — готово
            ColumnLayout {
                visible: win.step === 3
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12
                Item { Layout.fillHeight: true }
                Title { text: "Всё готово" }
                Lead {
                    text: "Компас — ❖ Пробел или значок слева в строке меню: поиск и запуск. Обзор всех окон — ❖ Tab или угол слева сверху. Быстрые настройки — Пульт, ❖ A; уведомления — Сводка, ❖ N."
                }
                Item { Layout.fillHeight: true }
            }

            // Низ: точки шагов и кнопки
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 16
                spacing: 8
                Row {
                    spacing: 6
                    Repeater {
                        model: 4
                        Rectangle {
                            width: index === win.step ? 18 : 6
                            height: 6
                            radius: 3
                            color: index === win.step ? win.accent : win.rim
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                QQC2.Button {
                    visible: win.step === 1 || win.step === 2
                    enabled: !win.installing
                    text: "Назад"
                    onClicked: win.step -= 1
                }
                QQC2.Button {
                    highlighted: true
                    enabled: !win.installing
                    text: win.step === 0 ? "Начать"
                        : win.step === 2 ? (win.toInstall().length ? "Установить" : "Дальше")
                        : win.step === 3 ? "Закрыть" : "Дальше"
                    onClicked: {
                        if (win.step === 2) {
                            win.install();
                        } else if (win.step === 3) {
                            sys.markDone();
                            Qt.quit();
                        } else {
                            win.step += 1;
                        }
                    }
                }
            }
        }
    }
}
