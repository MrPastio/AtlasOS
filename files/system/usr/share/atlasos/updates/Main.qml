// «Обновление системы»: версия Атласа, проверка и установка обновлений, перезагрузка,
// возврат к прошлой версии и обновление приложений — без терминала.
// Запускается atlas-updates (ссылка на atlas-welcome); sys.run() — мост к процессам.
// Образ обновляется сам раз в день (uupd.timer), здесь — то же самое сейчас и с понятным статусом.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: win
    width: 640
    height: 600
    minimumWidth: 520
    minimumHeight: 480
    title: "Обновление системы"
    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.None

    readonly property bool dark: Kirigami.Theme.textColor.hslLightness > 0.5
    readonly property color inkSecondary: dark ? "#b3afa7" : "#55524b"
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color rim: dark ? "#3d3b37" : "#e2dfd8"
    readonly property color raised: dark ? "#2f2e2b" : "#fcfbf9"
    readonly property color sunken: dark ? "#1f1e1c" : "#efede8"

    property var booted: null
    property var staged: null
    property var previous: null
    // idle | checking | none | available | downloading | staged | rolling | error
    property string state: "idle"
    property string message: ""
    property string appsMessage: ""
    property bool appsBusy: false
    property bool confirmRollback: false

    function refresh() {
        sys.run("status", "rpm-ostree", ["status", "--json"]);
    }
    Component.onCompleted: refresh()

    function describe(d) {
        if (!d) return "";
        // d.version — версия базы Bazzite, у соседних сборок Атласа она одна; различает их время сборки
        const date = new Date(d.timestamp * 1000);
        return "Сборка от " + date.toLocaleString(Qt.locale("ru_RU"), "d MMMM yyyy, HH:mm");
    }
    function lastLine(out) {
        return out.trim().split("\n").pop() || "";
    }

    Connections {
        target: sys
        function onFinished(tag, code, output) {
            switch (tag) {
            case "status": {
                try {
                    const all = JSON.parse(output).deployments;
                    win.booted = all.find(d => d.booted) || null;
                    win.staged = all.find(d => d.staged) || null;
                    win.previous = all.find(d => !d.booted && !d.staged) || null;
                } catch (e) {
                    win.state = "error";
                    win.message = "Не удалось прочитать состояние системы.";
                }
                if (win.staged && win.state !== "rolling") win.state = "staged";
                break;
            }
            case "check":
                // rpm-ostree upgrade --check: 0 — есть обновление, 77 — нечего обновлять
                if (code === 0 && output.indexOf("AvailableUpdate") >= 0) {
                    win.state = "available";
                } else if (code === 77 || code === 0) {
                    win.state = "none";
                } else {
                    win.state = "error";
                    win.message = "Проверка не удалась: " + win.lastLine(output);
                }
                break;
            case "upgrade":
                // успех без новой версии — «No upgrade available», тогда staged не появится
                if (code === 0) {
                    win.state = "none";
                } else {
                    win.state = "error";
                    win.message = "Обновление не удалось: " + win.lastLine(output);
                }
                win.refresh();
                break;
            case "rollback":
                if (code === 0) {
                    win.state = "rolling";
                } else {
                    win.state = "error";
                    win.message = "Вернуться не удалось: " + win.lastLine(output);
                }
                win.refresh();
                break;
            case "apps":
                win.appsMessage = code === 0 ? "Приложения обновлены." : "Не удалось обновить: " + win.lastLine(output);
                win.appsBusy = false;
                break;
            }
        }
    }

    component Title: QQC2.Label {
        Layout.fillWidth: true
        font.family: "Onest"
        font.pixelSize: 28 // large-title
        font.weight: Font.Bold
    }
    component Heading: QQC2.Label {
        Layout.fillWidth: true
        Layout.topMargin: 8
        font.family: "Onest"
        font.pixelSize: 13
        font.weight: Font.DemiBold
        color: win.inkSecondary
    }
    component Line: QQC2.Label {
        Layout.fillWidth: true
        font.family: "Onest"
        font.pixelSize: 14 // body
        wrapMode: Text.WordWrap
    }
    component Note: QQC2.Label {
        Layout.fillWidth: true
        font.family: "Onest"
        font.pixelSize: 12
        color: win.inkSecondary
        wrapMode: Text.WordWrap
    }
    // Группа настроек: карточка bg-raised с краем, radius-md
    component Group: Rectangle {
        default property alias content: inner.data
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 32
        radius: 10
        color: win.raised
        border.width: 1
        border.color: win.rim
        ColumnLayout {
            id: inner
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 8
        }
    }

    pageStack.initialPage: Kirigami.ScrollablePage {
        padding: 32
        background: Rectangle { color: win.sunken }

        ColumnLayout {
            spacing: 12

            Title { text: "Обновление системы" }

            Heading { text: "Атлас" }
            Group {
                Line {
                    text: win.booted ? win.describe(win.booted) : "Читаю состояние системы…"
                    font.weight: Font.Medium
                }
                Line {
                    text: ({
                        idle: "Обновления ставятся сами раз в день. Можно проверить и сейчас.",
                        checking: "Проверяю…",
                        none: "Это последняя версия.",
                        available: "Есть новая версия.",
                        downloading: "Скачиваю и готовлю новую версию… Можно пользоваться компьютером.",
                        staged: "Новая версия готова. Она включится после перезагрузки.",
                        rolling: "Прошлая версия включится после перезагрузки.",
                        error: win.message
                    })[win.state]
                    color: win.state === "error" ? Kirigami.Theme.negativeTextColor : win.inkSecondary
                }
                QQC2.ProgressBar {
                    Layout.fillWidth: true
                    visible: win.state === "checking" || win.state === "downloading"
                    indeterminate: true
                }
                RowLayout {
                    Layout.topMargin: 4
                    spacing: 8
                    QQC2.Button {
                        visible: ["idle", "none", "error"].indexOf(win.state) >= 0
                        text: "Проверить сейчас"
                        onClicked: {
                            win.state = "checking";
                            sys.run("check", "rpm-ostree", ["upgrade", "--check"]);
                        }
                    }
                    QQC2.Button {
                        visible: win.state === "available"
                        highlighted: true
                        text: "Обновить"
                        onClicked: {
                            win.state = "downloading";
                            sys.run("upgrade", "rpm-ostree", ["upgrade"]);
                        }
                    }
                    QQC2.Button {
                        visible: win.state === "staged" || win.state === "rolling"
                        highlighted: true
                        text: "Перезагрузить"
                        onClicked: sys.run("reboot", "systemctl", ["reboot"])
                    }
                }
            }

            Heading { text: "Прошлая версия" }
            Group {
                Line {
                    text: win.previous ? win.describe(win.previous) : "Прошлой версии пока нет — она появится после первого обновления."
                }
                Note {
                    visible: !!win.previous
                    text: "Если после обновления что-то сломалось, можно вернуться к ней. Ваши файлы и настройки не меняются."
                }
                RowLayout {
                    visible: !!win.previous && win.state !== "rolling"
                    Layout.topMargin: 4
                    spacing: 8
                    QQC2.Button {
                        visible: !win.confirmRollback
                        text: "Вернуться к ней…"
                        enabled: win.state !== "downloading"
                        onClicked: win.confirmRollback = true
                    }
                    QQC2.Label {
                        visible: win.confirmRollback
                        text: "Вернуться к прошлой версии?"
                        font.family: "Onest"
                        font.pixelSize: 13
                    }
                    QQC2.Button {
                        visible: win.confirmRollback
                        text: "Отмена"
                        onClicked: win.confirmRollback = false
                    }
                    QQC2.Button {
                        visible: win.confirmRollback
                        highlighted: true
                        text: "Вернуться"
                        onClicked: {
                            win.confirmRollback = false;
                            sys.run("rollback", "rpm-ostree", ["rollback"]);
                        }
                    }
                }
            }

            Heading { text: "Приложения" }
            Group {
                Line { text: "Приложения из Flathub тоже обновляются сами." }
                Note {
                    visible: win.appsMessage.length > 0 || win.appsBusy
                    text: win.appsBusy ? "Обновляю приложения…" : win.appsMessage
                }
                QQC2.ProgressBar {
                    Layout.fillWidth: true
                    visible: win.appsBusy
                    indeterminate: true
                }
                QQC2.Button {
                    Layout.topMargin: 4
                    text: "Обновить приложения"
                    enabled: !win.appsBusy
                    onClicked: {
                        win.appsMessage = "";
                        win.appsBusy = true;
                        sys.run("apps", "flatpak", ["update", "-y", "--noninteractive"]);
                    }
                }
            }
        }
    }
}
