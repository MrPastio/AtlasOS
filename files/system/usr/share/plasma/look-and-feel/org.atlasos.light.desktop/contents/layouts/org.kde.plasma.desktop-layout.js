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

bar.addWidget("org.atlasos.compass");
bar.addWidget("org.atlasos.appname");
bar.addWidget("org.kde.plasma.appmenu");
bar.addWidget("org.kde.plasma.panelspacer");
bar.addWidget("org.kde.plasma.systemtray");

// «Вт 27 окт. 22:41» стилем control: Onest 13px/500
var clock = bar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "ddd d MMM");
clock.writeConfig("dateDisplayFormat", 1); // рядом со временем
clock.writeConfig("use24hFormat", 2);
clock.writeConfig("autoFontAndSize", false);
clock.writeConfig("fontFamily", "Onest");
clock.writeConfig("fontWeight", 500);
clock.writeConfig("fontSize", 10);

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
