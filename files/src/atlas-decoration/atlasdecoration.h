/*
 * Декорация окон «Атласа» (01-shell.md «Окна», components/WindowControls).
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#pragma once

#include <KDecoration3/Decoration>
#include <KDecoration3/DecorationButton>

#include <QColor>
#include <QVariantAnimation>

namespace KDecoration3
{
class DecorationButtonGroup;
}

namespace Atlas
{

// Токены tokens.json для одной темы: кнопки окна (wc-*), обводка и блик окна.
struct Tokens {
    QColor close, closeRim;
    QColor minimize, minimizeRim;
    QColor zoom, zoomRim;
    QColor inactive, inactiveRim;
    QColor glyph;
    QColor ring, ringInactive; // shadow-window: 0 0 0 0.5px
    QColor highlight, highlightInactive; // shadow-window (тёмная): inset 0 0.5px 0
};

class Decoration : public KDecoration3::Decoration
{
    Q_OBJECT

public:
    explicit Decoration(QObject *parent = nullptr, const QVariantList &args = QVariantList());
    ~Decoration() override;

    bool init() override;
    void paint(QPainter *painter, const QRectF &repaintArea) override;

    bool isDark() const;
    const Tokens &tokens() const;
    // Наведение на группу кнопок: глифы на всех трёх сразу, у неактивного окна возвращается цвет.
    bool isGroupHovered() const
    {
        return m_groupHovered;
    }
    qreal glyphOpacity() const
    {
        return m_glyphOpacity;
    }

protected:
    void hoverEnterEvent(QHoverEvent *event) override;
    void hoverMoveEvent(QHoverEvent *event) override;
    void hoverLeaveEvent(QHoverEvent *event) override;

private:
    void updateLayout();
    void updateButtons(qreal titleBar);
    void updateShadow();
    void updateGroupHover(const QPointF &pos);
    bool isMaximized() const;
    QColor titleBarColor() const;
    qreal cornerRadius() const;

    KDecoration3::DecorationButtonGroup *m_leftButtons = nullptr;
    KDecoration3::DecorationButtonGroup *m_rightButtons = nullptr;
    QVariantAnimation *m_glyphAnimation = nullptr;
    qreal m_glyphOpacity = 0;
    bool m_groupHovered = false;
};

class Button : public KDecoration3::DecorationButton
{
    Q_OBJECT

public:
    explicit Button(QObject *parent, const QVariantList &args);
    Button(KDecoration3::DecorationButtonType type, Decoration *decoration, QObject *parent = nullptr);

    static KDecoration3::DecorationButton *create(KDecoration3::DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent);
    void paint(QPainter *painter, const QRectF &repaintArea) override;
};

} // namespace Atlas
