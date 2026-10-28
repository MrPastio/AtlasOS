/*
 * Глиф «Атласа» из contents/icons (tools/gen_glyphs.py), перекрашенный как маска.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.kirigami as Kirigami

Kirigami.Icon {
    property string name
    implicitWidth: 16
    implicitHeight: 16
    source: Qt.resolvedUrl("../icons/" + name + ".svg")
    isMask: true
}
