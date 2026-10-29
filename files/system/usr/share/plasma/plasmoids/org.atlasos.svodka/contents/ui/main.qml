/*
 * Сводка «Атласа» (01-shell.md, components/Notification): часы в строке меню, уведомления
 * и виджеты. Сводка — сервер уведомлений: модель NotificationManager поднимает его сама,
 * поэтому штатный апплет уведомлений в лотке убран (иначе баннеры пришли бы дважды).
 *
 * - Часы «Вт 27 окт. 22:41» стилем control; щелчок или ❖ N открывают Сводку.
 * - Сводка — окно справа на всю высоту под строкой меню: уведомления по приложениям,
 *   ниже календарь. Окно — Dialog с SolidBackground, как Пульт (material-panel, radius-xl).
 * - Баннеры — справа сверху под строкой меню, 352px, висят 5 с, наведение держит таймер.
 *   Каждый баннер — своё окно Dialog без подложки: карточку radius-xl с краем и тенью
 *   shadow-dock рисует сам, как Компас. Размыть фон под таким окном нельзя, поэтому
 *   материал непрозрачный (bg-elevated), как при «Уменьшить прозрачность».
 * - Фокус из Пульта (notificationsInhibitedUntil) глушит баннеры, но не Сводку.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    toolTipMainText: ""
    toolTipSubText: ""

    Tokens { id: atlas }

    readonly property rect screen: Plasmoid.containment.screenGeometry
    // под строкой меню size-menubar 28 + отступ space-8
    readonly property int topInset: 28 + atlas.gap
    // поле вокруг карточки баннера — под тень
    readonly property int shadowPad: 32

    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // ── Фокус ──────────────────────────────────────────────
    NotificationManager.Settings {
        id: notificationSettings
    }

    readonly property bool inhibited: {
        root.now; // пересчитывать, когда истечёт срок Фокуса
        if (!NotificationManager.Server.valid) {
            return false;
        }
        const until = notificationSettings.notificationsInhibitedUntil;
        if (!isNaN(until.getTime()) && Date.now() < until.getTime()) {
            return true;
        }
        if (notificationSettings.notificationsInhibitedByApplication) {
            return true;
        }
        if (notificationSettings.inhibitNotificationsWhenFullscreen && notificationSettings.fullscreenFocused) {
            return true;
        }
        return false;
    }
    onInhibitedChanged: NotificationManager.Server.inhibited = inhibited
    Component.onCompleted: NotificationManager.Server.inhibited = inhibited

    // ── Модели ─────────────────────────────────────────────
    // Баннеры: новые сверху, не больше четырёх
    NotificationManager.Notifications {
        id: popupModel
        limit: 4
        showExpired: false
        showDismissed: false
        showAddedDuringInhibition: false
        showJobs: notificationSettings.jobsInNotifications
        blacklistedDesktopEntries: notificationSettings.popupBlacklistedApplications
        blacklistedNotifyRcNames: notificationSettings.popupBlacklistedServices
        whitelistedDesktopEntries: root.inhibited ? notificationSettings.doNotDisturbPopupWhitelistedApplications : []
        whitelistedNotifyRcNames: root.inhibited ? notificationSettings.doNotDisturbPopupWhitelistedServices : []
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        groupMode: NotificationManager.Notifications.GroupDisabled
        urgencies: {
            let u = 0;
            if (!root.inhibited || notificationSettings.criticalPopupsInDoNotDisturbMode) {
                u |= NotificationManager.Notifications.CriticalUrgency;
            }
            if (!root.inhibited) {
                u |= NotificationManager.Notifications.NormalUrgency;
                if (notificationSettings.lowPriorityPopups) {
                    u |= NotificationManager.Notifications.LowUrgency;
                }
            }
            return u;
        }
    }

    // Сводка: по приложениям, у группы видны две последних, остальные — «Ещё N»
    NotificationManager.Notifications {
        id: historyModel
        showExpired: true
        showDismissed: true
        showJobs: notificationSettings.jobsInNotifications
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        groupMode: NotificationManager.Notifications.GroupApplicationsFlat
        groupLimit: 2
        expandUnread: true
        ignoreBlacklistDuringInhibition: true
        blacklistedDesktopEntries: notificationSettings.historyBlacklistedApplications
        blacklistedNotifyRcNames: notificationSettings.historyBlacklistedServices
        urgencies: NotificationManager.Notifications.CriticalUrgency
                   | NotificationManager.Notifications.NormalUrgency
                   | (notificationSettings.lowPriorityHistory ? NotificationManager.Notifications.LowUrgency : 0)
    }

    function clearAll() {
        historyModel.clear(NotificationManager.Notifications.ClearExpired);
        // Ещё висящие (не истёкшие) закрываем по одному; задания не трогаем
        for (let i = historyModel.count - 1; i >= 0; --i) {
            const idx = historyModel.index(i, 0);
            if (historyModel.data(idx, NotificationManager.Notifications.TypeRole) === NotificationManager.Notifications.NotificationType
                    && !historyModel.data(idx, NotificationManager.Notifications.IsGroupRole)) {
                historyModel.close(idx);
            }
        }
    }

    // ── Часы в строке меню ─────────────────────────────────
    fullRepresentation: MouseArea {
        id: clock

        property double hiddenAt: 0
        function toggle() {
            // щелчок по часам сначала снимает фокус с открытой Сводки — не открывать заново
            if (!summary.visible && Date.now() - hiddenAt < 250) {
                return;
            }
            summary.visible = !summary.visible;
        }

        Layout.fillHeight: true
        Layout.minimumWidth: implicitWidth
        Layout.maximumWidth: implicitWidth
        implicitWidth: clockText.implicitWidth + 16
        hoverEnabled: true
        onClicked: toggle()
        Accessible.role: Accessible.Button
        Accessible.name: "Сводка: уведомления и календарь"

        Connections {
            target: Plasmoid
            function onActivated() { clock.toggle() }
        }

        // как пилюля Пульта: 22px, radius-full, при наведении и открытой Сводке — fill-pressed
        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: Math.min(parent.height, 22)
            radius: height / 2
            color: atlas.fillPressed
            visible: clock.containsMouse || summary.visible
        }

        // «Вт 27 окт. 22:41» — control 13/500, только ink
        Text {
            id: clockText
            anchors.centerIn: parent
            text: Qt.locale().toString(root.now, "ddd d MMM") + "  " + Qt.formatTime(root.now, "HH:mm")
            color: Kirigami.Theme.textColor
            font.family: "Onest"
            font.pixelSize: 13
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }

        // ── Сводка ─────────────────────────────────────────
        PlasmaCore.Dialog {
            id: summary
            visualParent: clock
            location: Plasmoid.location
            type: PlasmaCore.Dialog.AppletPopup
            backgroundHints: PlasmaCore.Dialog.SolidBackground
            hideOnWindowDeactivate: true
            flags: Qt.WindowStaysOnTopHint
            onVisibleChanged: {
                if (visible) {
                    panel.forceActiveFocus();
                    historyModel.collapseAllGroups();
                } else {
                    clock.hiddenAt = Date.now();
                }
            }

            mainItem: FocusScope {
                id: panel
                width: 360
                // на всю высоту под строкой меню, с отступом space-8 снизу (минус поля окна)
                height: root.screen.height - root.topInset - atlas.gap - summary.margins.top - summary.margins.bottom
                Keys.onEscapePressed: summary.visible = false

                ColumnLayout {
                    anchors.fill: parent
                    spacing: atlas.gap

                    // Заголовок: «Уведомления» title-2 и «Очистить»
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        Layout.topMargin: 4
                        Text {
                            Layout.fillWidth: true
                            text: "Уведомления"
                            color: atlas.ink
                            font.family: "Onest"
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            font.letterSpacing: -0.17
                        }
                        QQC2.AbstractButton {
                            id: clearButton
                            visible: historyModel.count > 0
                            implicitHeight: 24
                            implicitWidth: clearLabel.implicitWidth + 16
                            contentItem: Text {
                                id: clearLabel
                                text: "Очистить"
                                color: atlas.accentInk
                                font.family: "Onest"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                radius: 6
                                color: clearButton.down ? atlas.fillPressed : clearButton.hovered ? atlas.fillHover : "transparent"
                            }
                            onClicked: root.clearAll()
                        }
                    }

                    // Уведомления
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.centerIn: parent
                            visible: historyModel.count === 0
                            text: "Новых уведомлений нет"
                            color: atlas.inkSecondary
                            font.family: "Onest"
                            font.pixelSize: 13
                        }

                        ListView {
                            id: list
                            anchors.fill: parent
                            clip: true
                            spacing: 6
                            model: historyModel
                            boundsBehavior: Flickable.StopAtBounds
                            QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }

                            add: Transition {
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: atlas.durMedium }
                            }
                            remove: Transition {
                                NumberAnimation { property: "opacity"; to: 0; duration: atlas.durMicro }
                            }
                            displaced: Transition {
                                NumberAnimation { property: "y"; duration: atlas.durMedium; easing.type: Easing.BezierSpline; easing.bezierCurve: atlas.easeOut }
                            }

                            delegate: Loader {
                                id: row
                                required property int index
                                required property var model
                                width: ListView.view.width
                                sourceComponent: model.isGroup ? groupHeader : notificationCard

                                Component {
                                    id: groupHeader
                                    // Заголовок группы: значок и имя приложения, «Ещё N», крестик
                                    RowLayout {
                                        spacing: 6
                                        Kirigami.Icon {
                                            Layout.leftMargin: 4
                                            implicitWidth: 16
                                            implicitHeight: 16
                                            source: row.model.applicationIconName || "preferences-desktop-notification-bell"
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            Layout.topMargin: row.index > 0 ? 8 : 0
                                            Layout.preferredHeight: 24
                                            verticalAlignment: Text.AlignVCenter
                                            text: row.model.applicationName
                                            color: atlas.inkSecondary
                                            font.family: "Onest"
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }
                                        SmallButton {
                                            readonly property int hidden: row.model.groupChildrenCount - row.model.expandedGroupChildrenCount
                                            visible: hidden > 0 && !row.model.isGroupExpanded
                                            text: "Ещё " + hidden
                                            onClicked: row.model.isGroupExpanded = true
                                        }
                                        SmallButton {
                                            visible: row.model.isGroupExpanded
                                            text: "Свернуть"
                                            onClicked: row.model.isGroupExpanded = false
                                        }
                                        SmallButton {
                                            text: "×"
                                            Accessible.name: "Закрыть уведомления приложения"
                                            onClicked: historyModel.close(historyModel.index(row.index, 0))
                                        }
                                    }
                                }

                                Component {
                                    id: notificationCard
                                    Card {
                                        filled: true
                                        showApp: !row.model.isInGroup
                                        appName: row.model.applicationName
                                        appIcon: row.model.applicationIconName
                                        image: row.model.image
                                        iconName: row.model.iconName
                                        summary: row.model.summary
                                        body: row.model.body
                                        time: isNaN(row.model.updated) ? row.model.created : row.model.updated
                                        actionNames: row.model.expired ? [] : row.model.actionNames
                                        actionLabels: row.model.actionLabels
                                        closable: row.model.closable
                                        isJob: row.model.type === NotificationManager.Notifications.JobType
                                        percentage: row.model.percentage || 0
                                        killable: !!row.model.killable
                                        onClicked: {
                                            if (row.model.hasDefaultAction && !row.model.expired) {
                                                historyModel.invokeDefaultAction(historyModel.index(row.index, 0), NotificationManager.Notifications.Close);
                                                summary.visible = false;
                                            }
                                        }
                                        onCloseClicked: historyModel.close(historyModel.index(row.index, 0))
                                        onActionInvoked: name => historyModel.invokeAction(historyModel.index(row.index, 0), name, NotificationManager.Notifications.Close)
                                        onKillClicked: historyModel.killJob(historyModel.index(row.index, 0))
                                    }
                                }
                            }
                        }
                    }

                    // Виджеты: календарь
                    CalendarCard {
                        Layout.fillWidth: true
                        now: root.now
                    }
                }
            }
        }
    }

    component SmallButton: QQC2.AbstractButton {
        id: small
        implicitHeight: 24
        implicitWidth: Math.max(24, smallLabel.implicitWidth + 12)
        contentItem: Text {
            id: smallLabel
            text: small.text
            color: atlas.inkSecondary
            font.family: "Onest"
            font.pixelSize: small.text === "×" ? 15 : 12
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: height / 2
            color: small.down ? atlas.fillPressed : small.hovered ? atlas.fillHover : "transparent"
        }
    }

    // ── Баннеры ────────────────────────────────────────────
    function positionBanners() {
        let y = root.screen.y + root.topInset;
        for (let i = 0; i < banners.count; ++i) {
            const b = banners.objectAt(i);
            if (!b) {
                continue;
            }
            b.y = y - root.shadowPad;
            y += b.height - 2 * root.shadowPad + atlas.gap;
        }
    }

    Instantiator {
        id: banners
        model: popupModel

        delegate: PlasmaCore.Dialog {
            id: banner

            required property int index
            required property var model

            readonly property bool hasSomeActions: model.hasDefaultAction || model.actionNames.length > 0
            // −1 — «на усмотрение сервера» (5 с, со ссылкой на файл — 10 с), 0 — висит, пока не закроют
            readonly property int timeoutMs: model.timeout === -1
                ? 5000 + (model.urls && model.urls.length > 0 ? 5000 : 0)
                : model.timeout
            property bool leaving: false
            // после удаления строки модели её роли уже не прочитать
            property var notificationIdCopy

            type: PlasmaCore.Dialog.Notification
            location: PlasmaCore.Types.Floating
            backgroundHints: PlasmaCore.Dialog.NoBackground
            flags: Qt.WindowDoesNotAcceptFocus | Qt.WindowStaysOnTopHint
            hideOnWindowDeactivate: false
            visible: false
            // правый край карточки — в space-8 от края экрана
            x: root.screen.x + root.screen.width - width + root.shadowPad - atlas.gap
            onHeightChanged: root.positionBanners()

            function leave(after) {
                if (leaving) {
                    return;
                }
                leaving = true;
                leaveAnimation.done = after;
                leaveAnimation.start();
            }

            function expire() {
                if (model.resident || (hasSomeActions && !model.transient)) {
                    // остаётся в Сводке живым: действия ещё можно вызвать
                    model.expired = true;
                } else {
                    popupModel.expire(popupModel.index(index, 0));
                }
            }

            mainItem: Item {
                width: 352 + 2 * root.shadowPad
                height: bannerCard.implicitHeight + 2 * root.shadowPad

                // material-hud без размытия: bg-elevated, край material-rim, тень shadow-dock
                Item {
                    id: bannerBody
                    x: root.shadowPad
                    y: root.shadowPad
                    width: 352
                    height: bannerCard.implicitHeight
                    opacity: 0
                    transform: Translate { id: slide; x: 48 }

                    RectangularShadow {
                        anchors.fill: parent
                        radius: 18
                        offset.y: 8
                        blur: 24
                        color: atlas.dark ? "#80000000" : "#1f1d1c1a"
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 18
                        color: atlas.dark ? "#33322f" : "#fcfbf9"
                        border.width: 1
                        border.color: atlas.dark ? "#b3000000" : "#241d1c1a"
                    }

                    Card {
                        id: bannerCard
                        width: parent.width
                        appName: banner.model.applicationName
                        appIcon: banner.model.applicationIconName
                        image: banner.model.image
                        iconName: banner.model.iconName
                        summary: banner.model.summary
                        body: banner.model.body
                        time: isNaN(banner.model.updated) ? banner.model.created : banner.model.updated
                        actionNames: banner.model.actionNames
                        actionLabels: banner.model.actionLabels
                        closable: banner.model.closable
                        isJob: banner.model.type === NotificationManager.Notifications.JobType
                        percentage: banner.model.percentage || 0
                        killable: !!banner.model.killable

                        onHoveredChanged: {
                            if (hovered) {
                                banner.model.read = true;
                            }
                        }
                        onClicked: {
                            if (banner.model.hasDefaultAction) {
                                const behavior = banner.model.resident ? NotificationManager.Notifications.None : NotificationManager.Notifications.Close;
                                banner.leave(() => popupModel.invokeDefaultAction(popupModel.index(banner.index, 0), behavior));
                            } else {
                                banner.leave(() => banner.expire());
                            }
                        }
                        onCloseClicked: banner.leave(() => popupModel.close(popupModel.index(banner.index, 0)))
                        onActionInvoked: name => {
                            const behavior = banner.model.resident ? NotificationManager.Notifications.None : NotificationManager.Notifications.Close;
                            banner.leave(() => popupModel.invokeAction(popupModel.index(banner.index, 0), name, behavior));
                        }
                        onKillClicked: popupModel.killJob(popupModel.index(banner.index, 0))
                    }
                }

                // Въезжает справа: смещение и проявление за первые 30% (spring-gentle ≈ ease-out 420 мс)
                ParallelAnimation {
                    id: enterAnimation
                    NumberAnimation { target: slide; property: "x"; from: 48; to: 0; duration: atlas.durSpringGentle; easing.type: Easing.BezierSpline; easing.bezierCurve: atlas.easeOut }
                    NumberAnimation { target: bannerBody; property: "opacity"; from: 0; to: 1; duration: atlas.durSpringGentle * 0.3 }
                }
                // Уходит вправо: ease-in, dur-medium
                ParallelAnimation {
                    id: leaveAnimation
                    property var done
                    NumberAnimation { target: slide; property: "x"; to: 48; duration: atlas.durMedium; easing.type: Easing.BezierSpline; easing.bezierCurve: atlas.easeIn }
                    NumberAnimation { target: bannerBody; property: "opacity"; to: 0; duration: atlas.durMedium; easing.type: Easing.BezierSpline; easing.bezierCurve: atlas.easeIn }
                    onFinished: {
                        banner.visible = false;
                        if (done) {
                            done();
                        }
                    }
                }

                Timer {
                    interval: banner.timeoutMs
                    running: banner.visible && !banner.leaving && interval > 0 && !bannerCard.hovered
                    onTriggered: banner.leave(() => banner.expire())
                }

                Component.onCompleted: enterAnimation.start()
            }

            Component.onCompleted: {
                notificationIdCopy = model.notificationId;
                if (root.inhibited) {
                    model.wasAddedDuringInhibition = false; // уже показан — в «пропущенные» не считать
                }
                // таймаут ведём сами
                popupModel.stopTimeout(popupModel.index(index, 0));
            }
        }

        onObjectAdded: (index, object) => {
            root.positionBanners();
            object.visible = true;
            popupModel.playSoundHint(popupModel.index(index, 0));
        }
        onObjectRemoved: (index, object) => {
            // окно могло исчезнуть из-за смены фильтра — пусть модель снова сама ведёт таймаут
            popupModel.startTimeout(object.notificationIdCopy);
            Qt.callLater(root.positionBanners);
        }
    }
}
