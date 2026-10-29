/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#include "atlassnap.h"
#include "atlasshadow.h"

#include <QMouseEvent>
#include <QPainter>
#include <QPainterPath>

namespace Atlas
{
namespace
{

// components/WindowControls: .at-snap — поля 8, три колонки по 56 через 8,
// заголовок 11/14, миниатюры 36 с полем 2 и зазором 2, радиусы 10 / 5 / 3.
constexpr qreal Pad = 8;
constexpr qreal Cell = 56;
constexpr qreal CellHeight = 36;
constexpr qreal TitleHeight = 14;
constexpr qreal PanelWidth = Pad + 3 * Cell + 2 * Pad + Pad;
constexpr qreal PanelHeight = Pad + TitleHeight + Pad + CellHeight + Pad + CellHeight + Pad;
constexpr qreal PanelRadius = 10;

struct Layout {
    QList<qreal> columns; // доли ширины
    int rows;
    bool center;
};

const Layout s_layouts[] = {
    {{1, 1}, 1, false}, // половины
    {{2, 1}, 1, false}, // 2/3 + 1/3
    {{1, 1, 1}, 1, false}, // трети
    {{1, 1}, 2, false}, // четверти
    {{1, 2}, 1, false}, // 1/3 + 2/3
    {{1}, 1, true}, // по центру
};
constexpr int LayoutCount = 6;

// shadow-popover без кольца
QList<BoxShadow> popoverShadow(bool dark)
{
    auto rgba = [](QRgb rgb, int a) {
        QColor c(rgb);
        c.setAlpha(a);
        return c;
    };
    if (dark) {
        return {{12, 32, -4, rgba(0x000000, 0x99)}};
    }
    return {{2, 6, 0, rgba(0x1d1c1a, 0x14)}, {10, 28, -6, rgba(0x1d1c1a, 0x33)}};
}

} // namespace

SnapPopup::SnapPopup(const SnapColors &colors, const QFont &font)
    : m_colors(colors)
    , m_font(font)
{
    // Подсказка поверх всех окон, без фокуса: KWin держит её над окном и не активирует
    setFlags(Qt::ToolTip | Qt::FramelessWindowHint | Qt::WindowDoesNotAcceptFocus | Qt::WindowStaysOnTopHint);
    QSurfaceFormat format;
    format.setAlphaBufferSize(8);
    setFormat(format);

    m_shadow = renderBoxShadow(popoverShadow(colors.dark), PanelRadius, QSize(PanelWidth, PanelHeight), &m_padding);
    // Поле над панелью — 4px: иначе прозрачное окно накроет кнопки (попап на 10 ниже
    // кружков) и заберёт у них курсор. Сверху тень и так почти не видна — она смещена вниз.
    const qreal maxTop = 4;
    if (m_padding.top() > maxTop) {
        const int cut = int(m_padding.top() - maxTop);
        m_shadow = m_shadow.copy(0, cut, m_shadow.width(), m_shadow.height() - cut);
        m_padding.setTop(maxTop);
    }
    resize(m_shadow.size());
    m_font.setPixelSize(11);
    m_font.setWeight(QFont::DemiBold);
}

QPointF SnapPopup::panelOrigin() const
{
    return QPointF(m_padding.left(), m_padding.top());
}

int SnapPopup::zoneCount(int layout)
{
    return s_layouts[layout].columns.size() * s_layouts[layout].rows;
}

QRectF SnapPopup::zoneFraction(int layout, int zone)
{
    const Layout &l = s_layouts[layout];
    if (l.center) {
        return QRectF(0.2, 0.125, 0.6, 0.75);
    }
    qreal total = 0;
    for (qreal c : l.columns) {
        total += c;
    }
    const int column = zone % l.columns.size();
    const int row = zone / l.columns.size();
    qreal x = 0;
    for (int i = 0; i < column; ++i) {
        x += l.columns[i] / total;
    }
    return QRectF(x, qreal(row) / l.rows, l.columns[column] / total, 1.0 / l.rows);
}

QRectF SnapPopup::layoutRect(int layout) const
{
    const QPointF o = panelOrigin();
    const int column = layout % 3;
    const int row = layout / 3;
    return QRectF(o.x() + Pad + column * (Cell + Pad), o.y() + Pad + TitleHeight + Pad + row * (CellHeight + Pad), Cell, CellHeight);
}

QRectF SnapPopup::zoneRect(int layout, int zone) const
{
    const Layout &l = s_layouts[layout];
    // поле 2, у раскладки «по центру» — 5 сверху и снизу, 12 по бокам
    const QRectF inner = l.center ? layoutRect(layout).adjusted(12, 5, -12, -5) : layoutRect(layout).adjusted(2, 2, -2, -2);
    if (l.center) {
        return inner;
    }
    const int columns = l.columns.size();
    const qreal gap = 2;
    const QRectF f = zoneFraction(layout, zone);
    const qreal w = inner.width() - gap * (columns - 1);
    const qreal h = inner.height() - gap * (l.rows - 1);
    const int column = zone % columns;
    const int row = zone / columns;
    return QRectF(inner.x() + f.x() * w + column * gap, inner.y() + f.y() * h + row * gap, f.width() * w, f.height() * h);
}

std::pair<int, int> SnapPopup::zoneAt(const QPointF &pos) const
{
    for (int layout = 0; layout < LayoutCount; ++layout) {
        if (!layoutRect(layout).contains(pos)) {
            continue;
        }
        for (int zone = 0; zone < zoneCount(layout); ++zone) {
            if (zoneRect(layout, zone).adjusted(-1, -1, 1, 1).contains(pos)) {
                return {layout, zone};
            }
        }
    }
    return {-1, -1};
}

void SnapPopup::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.setCompositionMode(QPainter::CompositionMode_Source);
    p.fillRect(QRect(QPoint(), size()), Qt::transparent);
    p.setCompositionMode(QPainter::CompositionMode_SourceOver);
    p.drawImage(0, 0, m_shadow);
    p.setRenderHint(QPainter::Antialiasing);

    const QRectF panel(panelOrigin(), QSizeF(PanelWidth, PanelHeight));
    p.setPen(Qt::NoPen);
    p.setBrush(m_colors.ring);
    p.drawRoundedRect(panel.adjusted(-0.5, -0.5, 0.5, 0.5), PanelRadius + 0.5, PanelRadius + 0.5);
    p.setBrush(m_colors.background);
    p.drawRoundedRect(panel, PanelRadius, PanelRadius);
    if (m_colors.highlight.alpha() > 0) {
        QPainterPath shape;
        shape.addRoundedRect(panel, PanelRadius, PanelRadius);
        p.fillPath(shape.subtracted(shape.translated(0, 0.5)), m_colors.highlight);
    }

    p.setFont(m_font);
    p.setPen(m_colors.title);
    p.drawText(QRectF(panel.x() + Pad + 2, panel.y() + Pad, PanelWidth, TitleHeight), Qt::AlignLeft | Qt::AlignVCenter, QStringLiteral("Разместить окно"));

    p.setPen(Qt::NoPen);
    for (int layout = 0; layout < LayoutCount; ++layout) {
        p.setBrush(m_colors.layout);
        p.drawRoundedRect(layoutRect(layout), 5, 5);
        for (int zone = 0; zone < zoneCount(layout); ++zone) {
            const QRectF r = zoneRect(layout, zone);
            const bool hovered = m_hover == std::pair{layout, zone};
            p.setBrush(m_colors.zoneRing);
            p.drawRoundedRect(r.adjusted(-0.5, -0.5, 0.5, 0.5), 3.5, 3.5);
            p.setBrush(hovered ? m_colors.accent : m_colors.zone);
            p.drawRoundedRect(r, 3, 3);
        }
    }
}

void SnapPopup::mouseMoveEvent(QMouseEvent *event)
{
    const auto hover = zoneAt(event->position());
    if (hover != m_hover) {
        m_hover = hover;
        update();
    }
}

void SnapPopup::mouseReleaseEvent(QMouseEvent *event)
{
    const auto [layout, zone] = zoneAt(event->position());
    if (layout >= 0) {
        Q_EMIT chosen(layout, zone);
    }
}

bool SnapPopup::event(QEvent *event)
{
    switch (event->type()) {
    case QEvent::Enter:
        Q_EMIT entered();
        break;
    case QEvent::Leave:
        m_hover = {-1, -1};
        update();
        Q_EMIT left();
        break;
    default:
        break;
    }
    return QRasterWindow::event(event);
}

} // namespace Atlas
