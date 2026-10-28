/*
 * Имя активного приложения жирным в строке меню «Атласа» (01-shell.md), меню окна по клику.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    toolTipMainText: ""
    toolTipSubText: ""

    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
    }

    readonly property bool hasActive: tasks.activeTask.valid
    readonly property string appName: {
        if (!hasActive) {
            return "Рабочий стол";
        }
        return tasks.data(tasks.activeTask, TaskManager.AbstractTasksModel.AppName)
            || tasks.data(tasks.activeTask, Qt.DisplayRole) || "";
    }

    fullRepresentation: MenuBarButton {
        id: button
        open: menu.status === PlasmaExtras.Menu.Open
        implicitContentWidth: Math.min(label.implicitWidth, Kirigami.Units.gridUnit * 14)
        onActivated: if (root.hasActive) menu.openRelative()

        PlasmaComponents3.Label {
            id: label
            anchors.centerIn: parent
            width: button.implicitContentWidth
            text: root.appName
            elide: Text.ElideRight
            font.weight: Font.Bold
            color: button.highlighted && root.hasActive ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
        }

        PlasmaExtras.Menu {
            id: menu
            visualParent: button
            placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup

            PlasmaExtras.MenuItem {
                text: "Свернуть"
                onClicked: tasks.requestToggleMinimized(tasks.activeTask)
            }
            PlasmaExtras.MenuItem {
                text: "Развернуть"
                onClicked: tasks.requestToggleMaximized(tasks.activeTask)
            }
            PlasmaExtras.MenuItem { separator: true }
            PlasmaExtras.MenuItem {
                text: "Закрыть окно"
                icon: "window-close-symbolic"
                onClicked: tasks.requestClose(tasks.activeTask)
            }
        }
    }
}
