/*
 * Раскладки окна (01-shell.md «Окна», components/WindowControls): задержка курсора на
 * зелёной кнопке открывает шесть раскладок — половины, 2/3 + 1/3, трети, четверти,
 * 1/3 + 2/3, по центру. Попап — окно внутри KWin, окно ставит скрипт KWin.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#pragma once

#include <QColor>
#include <QFont>
#include <QImage>
#include <QList>
#include <QMarginsF>
#include <QRasterWindow>
#include <QRectF>

namespace Atlas
{

struct SnapColors {
    QColor background; // bg-elevated: размыть фон под окном KWin нельзя
    QColor ring; // shadow-popover: кольцо 0.5px
    QColor highlight; // тёмная: inset 0.5px сверху
    QColor title; // ink-secondary
    QColor layout; // fill-pressed
    QColor zone; // control
    QColor zoneRing; // shadow-control
    QColor accent;
    bool dark = false;
};

class SnapPopup : public QRasterWindow
{
    Q_OBJECT

public:
    SnapPopup(const SnapColors &colors, const QFont &font);

    // Доля экрана для зоны: x, y, ширина, высота в долях рабочей области
    static QRectF zoneFraction(int layout, int zone);
    static int zoneCount(int layout);
    // Где начинается сама панель внутри окна (вокруг — поле под тень)
    QPointF panelOrigin() const;

Q_SIGNALS:
    void entered();
    void left();
    void chosen(int layout, int zone);

protected:
    void paintEvent(QPaintEvent *event) override;
    void mouseMoveEvent(QMouseEvent *event) override;
    void mouseReleaseEvent(QMouseEvent *event) override;
    bool event(QEvent *event) override;

private:
    QRectF layoutRect(int layout) const;
    QRectF zoneRect(int layout, int zone) const;
    std::pair<int, int> zoneAt(const QPointF &pos) const;

    SnapColors m_colors;
    QFont m_font;
    QImage m_shadow;
    QMarginsF m_padding;
    std::pair<int, int> m_hover{-1, -1};
};

} // namespace Atlas
