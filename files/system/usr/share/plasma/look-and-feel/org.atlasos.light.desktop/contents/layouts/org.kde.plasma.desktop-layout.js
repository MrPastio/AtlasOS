// Раскладка «Атласа» (01-shell.md): строка меню сверху и Док снизу.
// Plasma запускает её для нового пользователя и при смене глобальной темы с раскладкой.
// Один и тот же файл лежит в светлой и тёмной глобальных темах.

var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++) {
    desktopsArray[j].wallpaperPlugin = "org.kde.image";
}

// Строка меню: size-menubar 28px во всю ширину, всегда видна. Режим «непрозрачная»
// берёт из Plasma Style вариант solid/, а в нём лежит material-menubar.
var bar = new Panel;
bar.location = "top";
bar.height = 28;
bar.floating = false;
bar.hiding = "none";
bar.lengthMode = "fill";
bar.opacity = "opaque";

// Компас: системное меню; ❖ (как «меню приложений») и ❖ Пробел — поиск и запуск
var compass = bar.addWidget("org.atlasos.compass");
compass.globalShortcut = "Meta+Space";
bar.addWidget("org.atlasos.appname");
bar.addWidget("org.kde.plasma.appmenu");
bar.addWidget("org.kde.plasma.panelspacer");

// Лоток — только значки фоновых приложений и редкие системные; сеть, звук, батарею,
// Bluetooth, яркость, музыку и телефон показывает Пульт, уведомления — Сводка. knownItems перечисляет и убранные,
// иначе лоток вернёт их как новые.
// В Plasma 6.7 лоток сам хранит список ([Applets][N][General]), отдельного контейнера нет.
var trayItems = bar.addWidget("org.kde.plasma.systemtray");
trayItems.currentConfigGroup = ["General"];
trayItems.writeConfig("extraItems", [
    "org.kde.plasma.keyboardlayout",
    "org.kde.plasma.keyboardindicator",
    "org.kde.plasma.devicenotifier",
    "org.kde.plasma.manage-inputmethod",
    "org.kde.plasma.cameraindicator",
    "org.kde.plasma.printmanager",
    "org.kde.plasma.clipboard",
    "org.kde.plasma.vault",
    "org.kde.kscreen"
]);
trayItems.writeConfig("hiddenItems", ["org.kde.plasma.clipboard", "org.kde.plasma.vault", "org.kde.kscreen", "org.kde.plasma.printmanager"]);
trayItems.writeConfig("knownItems", [
    "org.kde.kdeconnect", "org.kde.plasma.vault", "org.kde.kscreen", "org.kde.plasma.battery",
    "org.kde.plasma.bluetooth", "org.kde.plasma.brightness", "org.kde.plasma.cameraindicator",
    "org.kde.plasma.clipboard", "org.kde.plasma.devicenotifier", "org.kde.plasma.keyboardindicator",
    "org.kde.plasma.keyboardlayout", "org.kde.plasma.manage-inputmethod", "org.kde.plasma.mediacontroller",
    "org.kde.plasma.networkmanagement", "org.kde.plasma.notifications", "org.kde.plasma.printmanager",
    "org.kde.plasma.volume", "org.kde.plasma.weather"
]);

// Пилюля статуса открывает Пульт; ❖ A — тоже
var pult = bar.addWidget("org.atlasos.pult");
pult.globalShortcut = "Meta+A";

// Сводка: часы «Вт 27 окт. 22:41», щелчок или ❖ N — уведомления и календарь.
// Она же сервер уведомлений и баннеры, поэтому штатного апплета уведомлений в лотке нет.
var svodka = bar.addWidget("org.atlasos.svodka");
svodka.globalShortcut = "Meta+N";

// Док: снизу по центру по ширине содержимого, парит и уступает окнам.
// Толщина 63 = отступ 6 + значок 48 + 9 под индикатор. Панель задач округляет значок до 48
// (size-dock-icon 52 недостижим) и делает задачу квадратной — её ширину знает Plasma Style.
var dock = new Panel;
dock.location = "bottom";
dock.height = 63;
dock.floating = true;
dock.hiding = "dodgewindows";
dock.lengthMode = "fit";
dock.alignment = "center";
dock.opacity = "translucent";

// Закреплённые: Файлы, Браузер, Steam, Терминал, Центр приложений, Настройки.
// Скрипт Bazzite bazzite-pins.js не трогает непустой список.
var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.kde.dolphin.desktop",
    "preferred://browser",
    "applications:steam.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:io.github.kolunmi.Bazaar.desktop",
    "applications:systemsettings.desktop"
]);

dock.addWidget("org.atlasos.separator");

// Загрузки — папка со всплывающей сеткой (стопка), затем Корзина
var downloads = dock.addWidget("org.kde.plasma.folder");
downloads.currentConfigGroup = ["General"];
downloads.writeConfig("url", "file://" + userDataPath("downloads"));

dock.addWidget("org.kde.plasma.trash");
