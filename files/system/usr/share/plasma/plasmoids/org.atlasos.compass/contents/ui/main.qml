/*
 * Компас в строке меню «Атласа»: символ compass и системное меню
 * (01-shell.md: «Об этом компьютере», «Настройки…», «Центр приложений»,
 * «Заблокировать», «Сон», «Перезагрузить…», «Выключить…»).
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.sessions as Sessions
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    toolTipMainText: ""
    toolTipSubText: ""

    Sessions.SessionManagement { id: session }

    // ❖ и Alt+F1: plasmashell активирует апплет, заявивший org.kde.plasma.launchermenu.
    // До своего Компаса (поиск и запуск, 01-shell.md) открывает KRunner.
    Connections {
        target: Plasmoid
        function onActivated() {
            executable.run("dbus-send --session --type=method_call --dest=org.kde.krunner /App org.kde.krunner.App.toggleDisplay");
        }
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        onNewData: source => disconnectSource(source)
        function run(cmd) { connectSource(cmd) }
    }

    fullRepresentation: MenuBarButton {
        id: button
        open: menu.status === PlasmaExtras.Menu.Open
        onActivated: menu.openRelative()

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: width
            source: Qt.resolvedUrl("../icons/compass.svg")
            isMask: true
            color: button.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
        }
        implicitContentWidth: Kirigami.Units.iconSizes.small

        PlasmaExtras.Menu {
            id: menu
            visualParent: button
            placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup

            PlasmaExtras.MenuItem {
                text: "Об этом компьютере"
                icon: "help-about-symbolic"
                onClicked: executable.run("kinfocenter")
            }
            PlasmaExtras.MenuItem { separator: true }
            PlasmaExtras.MenuItem {
                text: "Настройки…"
                icon: "configure-symbolic"
                onClicked: executable.run("systemsettings")
            }
            PlasmaExtras.MenuItem {
                text: "Центр приложений"
                icon: "view-app-grid-symbolic"
                onClicked: executable.run("gtk-launch io.github.kolunmi.Bazaar")
            }
            PlasmaExtras.MenuItem { separator: true }
            PlasmaExtras.MenuItem {
                text: "Заблокировать"
                icon: "system-lock-screen-symbolic"
                visible: session.canLock
                onClicked: session.lock()
            }
            PlasmaExtras.MenuItem {
                text: "Сон"
                visible: session.canSuspend
                onClicked: session.suspend()
            }
            PlasmaExtras.MenuItem {
                text: "Перезагрузить…"
                visible: session.canReboot
                onClicked: session.requestReboot()
            }
            PlasmaExtras.MenuItem {
                text: "Выключить…"
                icon: "system-shutdown-symbolic"
                visible: session.canShutdown
                onClicked: session.requestShutdown()
            }
        }
    }
}
