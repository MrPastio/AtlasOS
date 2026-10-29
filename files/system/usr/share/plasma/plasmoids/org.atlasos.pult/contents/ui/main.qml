/*
 * Пульт «Атласа» (01-shell.md, components/ControlCenter): пилюля статуса в строке меню
 * (сеть, звук, батарея одной кнопкой) и быстрые настройки под ней. Бэкенды — те же модули,
 * что у штатных апплетов лотка. Окно — Dialog с SolidBackground: Plasma Style отдаёт ему
 * translucent/solid/dialogs/background (material-panel, radius-xl), меню остаются radius-md.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.bluezqt as BluezQt
import org.kde.kdeconnect as KDEConnect
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.brightnesscontrolplugin as Brightness
import org.kde.plasma.private.batterymonitor as Battery
import org.kde.plasma.private.battery as BatteryModel
import org.kde.plasma.private.volume as Volume
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    toolTipMainText: ""
    toolTipSubText: ""

    Tokens { id: atlas }

    function plural(n, one, few, many) {
        const m10 = n % 10, m100 = n % 100;
        if (m10 === 1 && m100 !== 11) {
            return one;
        }
        if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) {
            return few;
        }
        return many;
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        onNewData: source => disconnectSource(source)
        function run(cmd) { connectSource(cmd) }
    }

    // Сеть
    PlasmaNM.EnabledConnections { id: enabledConnections }
    PlasmaNM.AvailableDevices { id: availableDevices }
    PlasmaNM.NetworkStatus { id: networkStatus }
    PlasmaNM.Handler { id: nmHandler }
    readonly property bool hasWifi: availableDevices.wirelessDeviceAvailable
    // «Имя соединения: состояние» — первая строка, без состояния
    readonly property string connectionName: networkStatus.activeConnections.split("\n")[0].split(":")[0].trim()
    readonly property bool connected: networkStatus.connectivity >= 2

    // Bluetooth
    readonly property bool hasBluetooth: BluezQt.Manager.adapters.length > 0 || BluezQt.Manager.bluetoothBlocked
    function setBluetooth(enable) {
        BluezQt.Manager.bluetoothBlocked = !enable;
        BluezQt.Manager.adapters.forEach(adapter => {
            adapter.powered = enable;
        });
    }

    // Рядом: телефон через KDE Connect
    KDEConnect.DevicesModel {
        id: nearDevices
        displayFilter: KDEConnect.DevicesModel.Paired | KDEConnect.DevicesModel.Reachable
    }
    readonly property string nearName: nearDevices.count > 0 ? nearDevices.data(nearDevices.index(0, 0), Qt.DisplayRole) : ""

    // Фокус: «Не беспокоить» — как переключатель уведомлений («пока не выключат» = через год)
    NotificationManager.Settings {
        id: notificationSettings
        live: true
    }
    readonly property bool focusOn: {
        const until = notificationSettings.notificationsInhibitedUntil;
        return until !== undefined && !isNaN(until.getTime()) && Date.now() < until.getTime();
    }
    function toggleFocus() {
        if (focusOn) {
            notificationSettings.notificationsInhibitedUntil = undefined;
        } else {
            const d = new Date();
            d.setFullYear(d.getFullYear() + 1);
            notificationSettings.notificationsInhibitedUntil = d;
        }
        notificationSettings.save();
    }

    // Ночной свет
    DBus.Properties {
        id: nightLight
        busType: DBus.BusType.Session
        service: "org.kde.KWin.NightLight"
        path: "/org/kde/KWin/NightLight"
        iface: "org.kde.KWin.NightLight"
        readonly property bool enabled: Boolean(properties.enabled)
    }
    function toggleNightLight() {
        // --notify: KWin следит за kwinrc и сразу включает или выключает ночной свет
        executable.run("kwriteconfig6 --notify --file kwinrc --group NightColor --key Active " + !nightLight.enabled);
    }

    // Питание: Тихий · Баланс · Мощность
    Battery.PowerProfilesControl { id: powerProfiles }
    BatteryModel.BatteryControlModel { id: battery }
    readonly property var profileOrder: ["power-saver", "balanced", "performance"]
    readonly property var profileNames: ({ "power-saver": "Тихий", "balanced": "Баланс", "performance": "Мощность" })
    function nextProfile() {
        const available = profileOrder.filter(p => powerProfiles.profiles.includes(p));
        if (available.length > 0) {
            powerProfiles.setProfile(available[(available.indexOf(powerProfiles.activeProfile) + 1) % available.length]);
        }
    }

    // Дисплей
    Brightness.ScreenBrightnessControl { id: screenBrightness }

    // Звук
    Volume.SinkModel { id: sinks }
    readonly property var sink: Volume.PreferredDevice.sink
    readonly property real volume: sink ? sink.volume / Volume.PulseAudio.NormalVolume : 0
    readonly property bool muted: !sink || sink.muted || volume <= 0

    // Сейчас играет
    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer
    readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing

    function openSettings(kcm) {
        KCMUtils.KCMLauncher.openSystemSettings(kcm);
    }

    fullRepresentation: MouseArea {
        id: pill

        property double hiddenAt: 0
        function toggle() {
            // щелчок по пилюле сначала снимает фокус с открытого Пульта — не открывать заново
            if (!pult.visible && Date.now() - hiddenAt < 250) {
                return;
            }
            pult.visible = !pult.visible;
        }

        Layout.fillHeight: true
        Layout.minimumWidth: implicitWidth
        Layout.maximumWidth: implicitWidth
        implicitWidth: glyphs.implicitWidth + 16
        hoverEnabled: true
        onClicked: toggle()
        Accessible.role: Accessible.Button
        Accessible.name: "Пульт: сеть, звук, батарея"

        Connections {
            target: Plasmoid
            function onActivated() { pill.toggle() }
        }

        // menubar-pill: 22px, radius-full, при наведении и открытом Пульте — fill-pressed
        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: Math.min(parent.height, 22)
            radius: height / 2
            color: atlas.fillPressed
            visible: pill.containsMouse || pult.visible
        }

        RowLayout {
            id: glyphs
            anchors.centerIn: parent
            spacing: 8
            Glyph {
                name: "wifi"
                color: Kirigami.Theme.textColor
                visible: root.hasWifi
                opacity: enabledConnections.wirelessEnabled ? 1 : 0.4
            }
            Glyph {
                name: root.muted ? "volume-mute" : "volume"
                color: Kirigami.Theme.textColor
            }
            // Батарея — глиф battery в 18px: корпус, носик и уровень заряда
            Item {
                implicitWidth: 18
                implicitHeight: 18
                visible: battery.hasInternalBatteries
                readonly property real unit: 18 / 20
                Rectangle {
                    x: 2.5 * parent.unit
                    y: 6 * parent.unit
                    width: 13 * parent.unit
                    height: 8 * parent.unit
                    radius: 2.2 * parent.unit
                    color: "transparent"
                    border.width: 1.5 * parent.unit
                    border.color: Kirigami.Theme.textColor
                }
                Rectangle {
                    x: 17 * parent.unit
                    y: 8.75 * parent.unit
                    width: 1.5 * parent.unit
                    height: 2.5 * parent.unit
                    radius: width / 2
                    color: Kirigami.Theme.textColor
                }
                Rectangle {
                    x: 4.25 * parent.unit
                    y: 7.75 * parent.unit
                    width: 9.5 * parent.unit * Math.max(0.1, battery.percent / 100)
                    height: 4.5 * parent.unit
                    radius: parent.unit
                    color: Kirigami.Theme.textColor
                }
            }
        }

        PlasmaCore.Dialog {
            id: pult
            visualParent: pill
            location: Plasmoid.location
            type: PlasmaCore.Dialog.AppletPopup
            backgroundHints: PlasmaCore.Dialog.SolidBackground
            hideOnWindowDeactivate: true
            flags: Qt.WindowStaysOnTopHint
            onVisibleChanged: {
                if (visible) {
                    panel.forceActiveFocus();
                } else {
                    pill.hiddenAt = Date.now();
                }
            }

            mainItem: FocusScope {
                id: panel
                // 332 − поля подложки 2 × 8; четыре колонки через 8
                readonly property real column: (width - 3 * atlas.gap) / 4
                width: 316
                height: content.implicitHeight
                Keys.onEscapePressed: pult.visible = false
                Kirigami.Theme.inherit: true

                function launch(kcm) {
                    pult.visible = false;
                    root.openSettings(kcm);
                }

                ColumnLayout {
                    id: content
                    width: parent.width
                    spacing: atlas.gap

                    // Ряды плиток: Фокус 60, малые плитки 78 (символ 30 + 6 + две строки по 13 + поля 8)
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 60 + atlas.gap + 78

                        // Связь 2×2: Wi-Fi, Bluetooth, Рядом
                        Tile {
                            tokens: atlas
                            width: 2 * panel.column + atlas.gap
                            height: parent.height
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 0
                                ToggleRow {
                                    tokens: atlas
                                    Layout.fillHeight: true
                                    glyph: root.hasWifi ? "wifi" : "globe"
                                    title: root.hasWifi ? "Wi-Fi" : "Сеть"
                                    on: root.hasWifi ? enabledConnections.wirelessEnabled : root.connected
                                    status: root.hasWifi && !enabledConnections.wirelessEnabled ? "Выкл."
                                        : root.connectionName !== "" ? root.connectionName : "Не подключено"
                                    onClicked: root.hasWifi ? nmHandler.enableWireless(!enabledConnections.wirelessEnabled)
                                                            : panel.launch("kcm_networkmanagement")
                                }
                                ToggleRow {
                                    tokens: atlas
                                    Layout.fillHeight: true
                                    glyph: "bluetooth"
                                    title: "Bluetooth"
                                    on: BluezQt.Manager.bluetoothOperational
                                    status: {
                                        if (!root.hasBluetooth) {
                                            return "Нет адаптера";
                                        }
                                        if (!BluezQt.Manager.bluetoothOperational) {
                                            return "Выкл.";
                                        }
                                        const devices = BluezQt.Manager.connectedDevices;
                                        if (devices.length === 1) {
                                            return devices[0].name;
                                        }
                                        return devices.length === 0 ? "Вкл." : devices.length + " " + root.plural(devices.length, "устройство", "устройства", "устройств");
                                    }
                                    onClicked: root.hasBluetooth ? root.setBluetooth(!BluezQt.Manager.bluetoothOperational)
                                                                 : panel.launch("kcm_bluetooth")
                                }
                                ToggleRow {
                                    tokens: atlas
                                    Layout.fillHeight: true
                                    glyph: "phone"
                                    title: "Рядом"
                                    on: nearDevices.count > 0
                                    status: nearDevices.count > 0 ? root.nearName : "Нет устройств"
                                    onClicked: panel.launch("kcm_kdeconnect")
                                }
                            }
                        }

                        Tile {
                            tokens: atlas
                            x: 2 * (panel.column + atlas.gap)
                            width: 2 * panel.column + atlas.gap
                            height: 60
                            ToggleRow {
                                tokens: atlas
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                glyph: "moon"
                                title: "Фокус"
                                on: root.focusOn
                                status: root.focusOn ? "Не беспокоить" : "Выкл."
                                onClicked: root.toggleFocus()
                            }
                        }

                        SmallTile {
                            tokens: atlas
                            x: 2 * (panel.column + atlas.gap)
                            y: 60 + atlas.gap
                            width: panel.column
                            height: 78
                            glyph: "sunset"
                            label: "Ночной\nсвет"
                            on: nightLight.enabled
                            onClicked: root.toggleNightLight()
                        }

                        SmallTile {
                            tokens: atlas
                            x: 3 * (panel.column + atlas.gap)
                            y: 60 + atlas.gap
                            width: panel.column
                            height: 78
                            glyph: "bolt"
                            label: "Питание\n" + (root.profileNames[powerProfiles.activeProfile] ?? "—")
                            on: powerProfiles.activeProfile === "performance"
                            onClicked: root.nextProfile()
                        }
                    }

                    // Дисплей: только если яркостью можно управлять
                    Tile {
                        tokens: atlas
                        Layout.fillWidth: true
                        implicitHeight: displayColumn.implicitHeight + 20
                        visible: screenBrightness.isBrightnessAvailable
                        ColumnLayout {
                            id: displayColumn
                            width: parent.width
                            spacing: 6
                            PlasmaComponents3.Label {
                                text: "Дисплей"
                                color: atlas.ink
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                            Repeater {
                                model: screenBrightness.displays
                                PanelSlider {
                                    required property string displayName
                                    required property int brightness
                                    required property int maxBrightness
                                    tokens: atlas
                                    Layout.fillWidth: true
                                    glyph: "sun"
                                    value: maxBrightness > 0 ? brightness / maxBrightness : 0
                                    Accessible.name: "Яркость"
                                    onMoved: v => screenBrightness.setBrightness(displayName, Math.round(v * maxBrightness))
                                }
                            }
                        }
                    }

                    // Звук: громкость и выход; стрелка ведёт в Настройки
                    Tile {
                        tokens: atlas
                        Layout.fillWidth: true
                        implicitHeight: soundColumn.implicitHeight + 20
                        ColumnLayout {
                            id: soundColumn
                            width: parent.width
                            spacing: 6
                            RowLayout {
                                Layout.fillWidth: true
                                PlasmaComponents3.Label {
                                    text: "Звук"
                                    color: atlas.ink
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                                Item { Layout.fillWidth: true }
                                MouseArea {
                                    implicitWidth: output.implicitWidth
                                    implicitHeight: output.implicitHeight
                                    Layout.maximumWidth: panel.width * 0.6
                                    onClicked: panel.launch("kcm_pulseaudio")
                                    Accessible.role: Accessible.Button
                                    Accessible.name: "Выход звука"
                                    RowLayout {
                                        id: output
                                        width: parent.width
                                        spacing: 4
                                        PlasmaComponents3.Label {
                                            Layout.fillWidth: true
                                            text: root.sink ? (root.sink.description || root.sink.name) : "Нет выхода"
                                            color: atlas.inkSecondary
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }
                                        Glyph {
                                            name: "chevron-right"
                                            implicitWidth: 12
                                            implicitHeight: 12
                                            color: atlas.inkSecondary
                                        }
                                    }
                                }
                            }
                            PanelSlider {
                                tokens: atlas
                                Layout.fillWidth: true
                                glyph: root.muted ? "volume-mute" : "volume"
                                value: root.volume
                                Accessible.name: "Громкость"
                                onMoved: v => {
                                    if (!root.sink) {
                                        return;
                                    }
                                    root.sink.volume = Math.round(v * Volume.PulseAudio.NormalVolume);
                                    if (root.sink.muted && v > 0) {
                                        root.sink.muted = false;
                                    }
                                }
                            }
                        }
                    }

                    // Сейчас играет
                    Tile {
                        tokens: atlas
                        Layout.fillWidth: true
                        implicitHeight: 60
                        visible: !!root.player
                        RowLayout {
                            anchors.fill: parent
                            spacing: 10
                            Rectangle {
                                implicitWidth: 40
                                implicitHeight: 40
                                radius: 7
                                color: "#0e7a74" // accent-meridian
                                clip: true
                                Glyph {
                                    anchors.centerIn: parent
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    name: "music"
                                    color: "#d9ffffff"
                                    visible: art.status !== Image.Ready
                                }
                                Image {
                                    id: art
                                    anchors.fill: parent
                                    source: root.player?.artUrl ?? ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                PlasmaComponents3.Label {
                                    Layout.fillWidth: true
                                    text: root.player?.track || root.player?.identity || ""
                                    color: atlas.ink
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                PlasmaComponents3.Label {
                                    Layout.fillWidth: true
                                    text: root.player?.artist ?? ""
                                    visible: text !== ""
                                    color: atlas.inkSecondary
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                            Repeater {
                                model: [
                                    { glyph: root.playing ? "pause" : "play", name: root.playing ? "Пауза" : "Играть" },
                                    { glyph: "forward", name: "Следующий трек" },
                                ]
                                MouseArea {
                                    id: control
                                    required property var modelData
                                    required property int index
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    hoverEnabled: true
                                    Accessible.role: Accessible.Button
                                    Accessible.name: modelData.name
                                    onClicked: {
                                        if (index === 1) {
                                            root.player.Next();
                                        } else if (root.playing) {
                                            root.player.Pause();
                                        } else {
                                            root.player.Play();
                                        }
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 6 // radius-sm
                                        color: atlas.fillPressed
                                        visible: control.containsMouse
                                    }
                                    Glyph {
                                        anchors.centerIn: parent
                                        name: control.modelData.glyph
                                        color: atlas.ink
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
