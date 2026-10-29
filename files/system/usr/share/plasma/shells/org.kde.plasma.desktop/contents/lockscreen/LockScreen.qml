/*
 * Экран блокировки «Атласа» (01-shell.md «Экран блокировки», 06-motion.md «Разблокировка»).
 * kscreenlocker берёт lockscreen/LockScreen.qml из пакета оболочки org.kde.plasma.desktop —
 * этот файл заменяет штатный, остальные файлы каталога (MediaControls, LockOsd, PasswordSync)
 * остаются от Plasma. Если здесь будет ошибка, kscreenlocker загрузит встроенный запасной экран.
 *
 * В покое — обои, часы стилем clock и дата title-3. Движение мыши или ввод размывают обои
 * до blur-wallpaper, аватар и поле пароля поднимаются (spring-gentle); через 10 с без
 * действий всё уходит обратно. Разблокировка — экран растворяется и увеличивается до 1.04.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator
import org.kde.plasma.private.sessions
import org.kde.plasma.workspace.components as PW
import org.kde.breeze.components as Breeze

Item {
    id: root
    property bool debug: false
    property string notification
    signal clearPassword()
    signal notificationRepeated()

    // Эти свойства ищет kscreenlocker
    property bool viewVisible: false

    LayoutMirroring.enabled: Application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    implicitWidth: 800
    implicitHeight: 600

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary

    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    // Текст поверх обоев: светлый с мягкой тенью — читается и на светлых, и на тёмных обоях
    readonly property color inkOnWallpaper: "#fbfaf7"
    readonly property color inkOnWallpaperSecondary: "#d9fbfaf7"
    // Материал поля и кнопок поверх размытых обоев: плоская тонировка и край 1px
    readonly property color tint: "#33ffffff"
    readonly property color tintHover: "#47ffffff"
    readonly property color tintPressed: "#5cffffff"
    readonly property color rim: "#4dffffff"
    readonly property color accent: Kirigami.Theme.highlightColor

    // ease-out и ease-in-out из 06-motion.md
    readonly property var easeOut: [0.22, 1, 0.36, 1, 1, 1]
    readonly property var easeIn: [0.4, 0, 0.84, 0.36, 1, 1]
    readonly property var easeInOut: [0.65, 0, 0.35, 1, 1, 1]

    function handleMessage(msg) {
        if (!root.notification) {
            root.notification += msg;
        } else if (root.notification.includes(msg)) {
            root.notificationRepeated();
        } else {
            root.notification += "\n" + msg;
        }
    }

    function unlock() {
        unlockAnimation.start();
    }

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind != 0) { // неинтерактивные (отпечаток, смарт-карта) пишут сами
                return;
            }
            root.handleMessage("Неверный пароль. Попробуйте ещё раз.");
            graceLockTimer.restart();
            notificationRemoveTimer.restart();
            shake.restart();
        }
        function onSucceeded() {
            if (authenticator.hadPrompt) {
                root.unlock();
            } else {
                // без пароля (пустой пароль, отпечаток до ввода) — кнопка «Разблокировать»
                prompt.noPassword = true;
                lockScreenRoot.uiVisible = true;
                unlockButton.forceActiveFocus();
            }
        }
        function onInfoMessageChanged() {
            root.handleMessage(authenticator.infoMessage);
        }
        function onErrorMessageChanged() {
            root.handleMessage(authenticator.errorMessage);
        }
        function onPromptChanged(msg) {
            root.handleMessage(authenticator.prompt);
        }
        function onPromptForSecretChanged(msg) {
            passwordField.echoMode = TextInput.Password;
            passwordField.forceActiveFocus();
        }
    }

    SessionManagement {
        id: sessionManagement
    }

    Connections {
        target: sessionManagement
        function onAboutToSuspend() {
            root.clearPassword();
        }
    }

    KeyboardIndicator.KeyState {
        id: capsLockState
        key: Qt.Key_CapsLock
    }

    PW.KeyboardLayoutSwitcher {
        id: layoutSwitcher
        acceptedButtons: Qt.NoButton
    }

    // Разблокировка: растворение и увеличение до 1.04, dur-xlong, ease-in-out
    ParallelAnimation {
        id: unlockAnimation
        NumberAnimation { target: lockScreenRoot; property: "opacity"; to: 0; duration: 450; easing.type: Easing.BezierSpline; easing.bezierCurve: root.easeInOut }
        NumberAnimation { target: lockScreenRoot; property: "scale"; to: 1.04; duration: 450; easing.type: Easing.BezierSpline; easing.bezierCurve: root.easeInOut }
        onFinished: Qt.quit()
    }

    MouseArea {
        id: lockScreenRoot

        property bool uiVisible: false
        property bool seenPositionChange: false
        // Пока в поле что-то есть, интерфейс не прячется
        readonly property bool blockUI: passwordField.text.length > 0 || prompt.noPassword

        anchors.fill: parent
        transformOrigin: Item.Center
        hoverEnabled: true
        cursorShape: uiVisible ? Qt.ArrowCursor : Qt.BlankCursor
        drag.filterChildren: true

        onPressed: uiVisible = true
        onPositionChanged: {
            uiVisible = seenPositionChange;
            seenPositionChange = true;
        }
        onUiVisibleChanged: {
            if (uiVisible) {
                Window.window.requestActivate();
                passwordField.forceActiveFocus();
            }
            if (blockUI) {
                fadeoutTimer.running = false;
            } else if (uiVisible) {
                fadeoutTimer.restart();
            }
            authenticator.startAuthenticating();
        }
        onBlockUIChanged: {
            if (blockUI) {
                fadeoutTimer.running = false;
                uiVisible = true;
            } else {
                fadeoutTimer.restart();
            }
        }
        onExited: uiVisible = false

        Keys.onEscapePressed: {
            // Esc без открытого поля kscreenlocker понимает как «погасить экран»
            if (uiVisible) {
                uiVisible = false;
                root.clearPassword();
            }
        }
        Keys.onPressed: event => {
            uiVisible = true;
            event.accepted = false;
        }

        Timer {
            id: fadeoutTimer
            interval: 10000
            onTriggered: {
                if (!lockScreenRoot.blockUI) {
                    lockScreenRoot.uiVisible = false;
                }
            }
        }
        Timer {
            id: notificationRemoveTimer
            interval: 3000
            onTriggered: root.notification = ""
        }
        Timer {
            id: graceLockTimer
            interval: 3000
            onTriggered: {
                root.clearPassword();
                authenticator.startAuthenticating();
            }
        }

        // Появление экрана блокировки — проявление за dur-xlong
        opacity: 0
        Component.onCompleted: appear.start()
        NumberAnimation { id: appear; target: lockScreenRoot; property: "opacity"; from: 0; to: 1; duration: 450; easing.type: Easing.BezierSpline; easing.bezierCurve: root.easeOut }

        // 0 — покой, 1 — показан запрос пароля. Обои и запрос едут по одному числу
        property real factor: uiVisible ? 1 : 0
        Behavior on factor {
            NumberAnimation {
                duration: lockScreenRoot.uiVisible ? 420 : 320
                easing.type: Easing.BezierSpline
                easing.bezierCurve: lockScreenRoot.uiVisible ? root.easeOut : root.easeIn
            }
        }

        // Обои размываются до blur-wallpaper (MultiEffect даёт до 64px — ближайшее),
        // насыщенность +80% (backdrop-saturate) и лёгкое затемнение под светлый текст
        MultiEffect {
            anchors.fill: parent
            source: wallpaper
            visible: !root.softwareRendering && lockScreenRoot.factor > 0
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: lockScreenRoot.factor
            saturation: 0.3 * lockScreenRoot.factor
        }
        Rectangle {
            anchors.fill: parent
            color: "#1d1c1a"
            opacity: 0.22 * lockScreenRoot.factor
        }

        // Часы стилем clock (96/300, −0.035em) и дата title-3 под ними
        Column {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.12)
            spacing: 4
            visible: config.alwaysShowClock
            opacity: config.hideClockWhenIdle ? lockScreenRoot.factor : 1

            property date now: new Date()
            Timer {
                interval: 1000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: clock.now = new Date()
            }

            layer.enabled: !root.softwareRendering
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.28 * (1 - lockScreenRoot.factor)
                shadowBlur: 0.6
                shadowVerticalOffset: 1
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.now, Qt.locale(), Locale.ShortFormat)
                color: root.inkOnWallpaper
                font.family: "Onest"
                font.pixelSize: 96
                font.weight: Font.Light
                font.letterSpacing: -3.36
                font.features: { "tnum": 1 }
                renderType: Text.QtRendering
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    const s = Qt.locale().toString(clock.now, "dddd, d MMMM");
                    return s.charAt(0).toUpperCase() + s.slice(1);
                }
                color: root.inkOnWallpaper
                font.family: "Onest"
                font.pixelSize: 20
                font.weight: Font.DemiBold
                font.letterSpacing: -0.12
            }
        }

        // Аватар, имя и поле пароля; поднимаются на 24px вместе с factor
        ColumnLayout {
            id: prompt
            property bool noPassword: false

            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.5 - 60 + 24 * (1 - lockScreenRoot.factor))
            spacing: 0
            opacity: lockScreenRoot.factor
            visible: opacity > 0
            enabled: !graceLockTimer.running

            transform: Translate { id: shakeOffset; x: 0 }

            // Аватар 72px: картинка пользователя или первая буква имени на тонировке
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 72
                implicitHeight: 72

                Rectangle {
                    id: avatarCircle
                    anchors.fill: parent
                    radius: width / 2
                    color: root.tint
                    border.width: 1
                    border.color: root.rim

                    Text {
                        anchors.centerIn: parent
                        visible: avatarImage.status !== Image.Ready
                        text: kscreenlocker_userName.charAt(0).toUpperCase()
                        color: root.inkOnWallpaper
                        font.family: "Onest"
                        font.pixelSize: 30
                        font.weight: Font.DemiBold
                    }
                }
                Image {
                    id: avatarImage
                    anchors.fill: parent
                    source: kscreenlocker_userImage !== ""
                        ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/")
                        : ""
                    sourceSize: Qt.size(144, 144)
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: avatarImage
                    visible: avatarImage.status === Image.Ready
                    maskEnabled: true
                    maskSource: avatarMask
                }
                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: width / 2
                    layer.enabled: true
                    visible: false
                }
            }

            // Имя стилем title-2
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 12
                text: kscreenlocker_userName
                color: root.inkOnWallpaper
                font.family: "Onest"
                font.pixelSize: 17
                font.weight: Font.DemiBold
                font.letterSpacing: -0.17
            }

            // Поле пароля size-control-lg 36px, пилюля; стрелка входа появляется вместе с текстом
            QQC2.TextField {
                id: passwordField
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 16
                Layout.preferredWidth: 248
                Layout.preferredHeight: 36
                visible: !prompt.noPassword
                focus: true
                enabled: !authenticator.graceLocked

                echoMode: TextInput.Password
                passwordCharacter: "●"
                text: PasswordSync.password
                placeholderText: "Пароль"
                placeholderTextColor: root.inkOnWallpaperSecondary
                color: root.inkOnWallpaper
                selectionColor: root.accent
                font.family: "Onest"
                font.pixelSize: 14
                leftPadding: 16
                rightPadding: 40
                verticalAlignment: TextInput.AlignVCenter
                // фокус есть и у невидимого поля; без курсора — меньше перерисовок в покое
                cursorVisible: lockScreenRoot.uiVisible

                background: Rectangle {
                    radius: height / 2
                    color: passwordField.hovered ? root.tintHover : root.tint
                    border.width: 1
                    border.color: root.rim
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                onAccepted: {
                    if (lockScreenRoot.uiVisible && text.length > 0) {
                        authenticator.respond(text);
                    }
                }

                Connections {
                    target: root
                    function onClearPassword() {
                        passwordField.forceActiveFocus();
                        passwordField.text = "";
                        passwordField.text = Qt.binding(() => PasswordSync.password);
                    }
                    function onNotificationRepeated() {
                        shake.restart();
                    }
                }

                // Кнопка входа 28px внутри поля, справа
                Rectangle {
                    id: goButton
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 14
                    color: goArea.pressed ? Qt.darker(root.accent, 1.15) : root.accent
                    scale: passwordField.text.length > 0 ? 1 : 0.4
                    opacity: passwordField.text.length > 0 ? 1 : 0
                    visible: opacity > 0
                    Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    Behavior on opacity { NumberAnimation { duration: 100 } }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: LayoutMirroring.enabled ? "go-previous-symbolic" : "go-next-symbolic"
                        color: Kirigami.Theme.highlightedTextColor
                        isMask: true
                    }
                    MouseArea {
                        id: goArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: passwordField.accepted()
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: "Разблокировать"
                }
            }
            Binding {
                target: PasswordSync
                property: "password"
                value: passwordField.text
            }

            // Без пароля: одна кнопка
            QQC2.Button {
                id: unlockButton
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 16
                Layout.preferredHeight: 36
                visible: prompt.noPassword
                text: "Разблокировать"
                font.family: "Onest"
                font.pixelSize: 13
                font.weight: Font.Medium
                leftPadding: 20
                rightPadding: 20
                contentItem: Text {
                    text: unlockButton.text
                    font: unlockButton.font
                    color: root.inkOnWallpaper
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: height / 2
                    color: unlockButton.down ? root.tintPressed : unlockButton.hovered ? root.tintHover : root.tint
                    border.width: 1
                    border.color: root.rim
                }
                onClicked: root.unlock()
                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
            }

            // Сообщения: Caps Lock, неверный пароль, подсказки PAM (body-sm)
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 12
                Layout.maximumWidth: 360
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                text: {
                    const parts = [];
                    if (capsLockState.locked) {
                        parts.push("Включён Caps Lock");
                    }
                    if (root.notification) {
                        parts.push(root.notification);
                    }
                    if (parts.length === 0) {
                        if (authenticator.authenticatorTypes & ScreenLocker.Authenticator.Fingerprint) {
                            parts.push("Или приложите палец к сканеру");
                        } else if (authenticator.authenticatorTypes & ScreenLocker.Authenticator.Smartcard) {
                            parts.push("Или вставьте смарт-карту");
                        }
                    }
                    return parts.join(" · ");
                }
                color: root.inkOnWallpaper
                font.family: "Onest"
                font.pixelSize: 13
                // место под строку есть всегда — поле не прыгает
                Layout.preferredHeight: Math.max(implicitHeight, 18)
            }

            Loader {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 16
                Layout.preferredWidth: 360
                Layout.preferredHeight: item ? item.implicitHeight : 0
                active: config.showMediaControls
                source: "MediaControls.qml"
            }
        }

        // Неверный пароль: поле качается по горизонтали
        SequentialAnimation {
            id: shake
            NumberAnimation { target: shakeOffset; property: "x"; to: -10; duration: 50; easing.type: Easing.OutQuad }
            NumberAnimation { target: shakeOffset; property: "x"; to: 10; duration: 90; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeOffset; property: "x"; to: -6; duration: 80; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeOffset; property: "x"; to: 4; duration: 70; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 60; easing.type: Easing.OutQuad }
        }

        // Низ экрана: раскладка слева, сон и смена пользователя по центру, батарея справа
        component FooterButton: QQC2.AbstractButton {
            id: footerButton
            implicitHeight: 28
            implicitWidth: label.implicitWidth + 24
            focusPolicy: Qt.TabFocus
            contentItem: Text {
                id: label
                text: footerButton.text
                color: root.inkOnWallpaper
                font.family: "Onest"
                font.pixelSize: 13
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: height / 2
                color: footerButton.down ? root.tintPressed : footerButton.hovered || footerButton.visualFocus ? root.tint : "transparent"
                border.width: footerButton.visualFocus ? 2 : 0
                border.color: root.accent
                Behavior on color { ColorAnimation { duration: footerButton.hovered ? 100 : 200 } }
            }
        }

        Item {
            id: footer
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 16
            }
            height: 28
            opacity: lockScreenRoot.factor
            visible: opacity > 0

            FooterButton {
                anchors.left: parent.left
                visible: layoutSwitcher.hasMultipleKeyboardLayouts
                text: layoutSwitcher.layoutNames.shortName.toUpperCase()
                Accessible.description: "Сменить раскладку"
                onClicked: {
                    layoutSwitcher.keyboardLayout.switchToNextLayout();
                    passwordField.forceActiveFocus();
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 8
                FooterButton {
                    text: "Сон"
                    visible: sessionManagement.canSuspend
                    onClicked: sessionManagement.suspend()
                }
                FooterButton {
                    text: "Гибернация"
                    visible: sessionManagement.canHibernate
                    onClicked: sessionManagement.hibernate()
                }
                FooterButton {
                    text: "Сменить пользователя"
                    visible: sessionManagement.canSwitchUser
                    onClicked: sessionManagement.switchUser()
                }
            }

            Breeze.Battery {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // OSD громкости и яркости, пока экран заблокирован
        Loader {
            z: 2
            active: root.viewVisible
            source: "LockOsd.qml"
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 64
            }
        }
    }
}
