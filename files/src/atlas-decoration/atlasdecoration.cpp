/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#include "atlasdecoration.h"
#include "atlasshadow.h"
#include "atlassnap.h"

#include <KDecoration3/DecoratedWindow>
#include <KDecoration3/DecorationButtonGroup>
#include <KDecoration3/DecorationSettings>
#include <KDecoration3/DecorationShadow>
#include <KDecoration3/ScaleHelpers>
#include <KPluginFactory>

#include <QCursor>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QFile>
#include <QHoverEvent>
#include <QPainter>
#include <QPainterPath>
#include <QStandardPaths>

K_PLUGIN_FACTORY_WITH_JSON(AtlasDecorationFactory, "atlas.json", registerPlugin<Atlas::Decoration>(); registerPlugin<Atlas::Button>();)

namespace Atlas
{

using KDecoration3::ColorGroup;
using KDecoration3::ColorRole;
using KDecoration3::DecorationButtonType;

namespace
{

// 05-shape.md: радиус окна radius-lg, кнопка size-wc, зона клика size-hit-min.
// Заголовок 36: size-titlebar 52 рассчитан на единый заголовок с инструментами,
// а декорация несёт только кнопки и имя; 36 = size-control 28 + отступы 4.
constexpr qreal TitleBarHeight = 36;
constexpr qreal CornerRadius = 12;
constexpr qreal ButtonSize = 14;
constexpr qreal ButtonHit = 24; // 14 + 2 × 5: соседние зоны касаются, зазор кнопок 10
constexpr qreal TitleGap = 16; // от последней кнопки до имени окна
constexpr int GlyphDuration = 100; // dur-micro
constexpr int FocusDuration = 240; // dur-medium
constexpr int SnapDelay = 450; // delay-snap
constexpr int SnapLinger = 220; // как в WindowControls: попап живёт после ухода курсора
constexpr qreal SnapGap = 8; // space-8: зазор между окнами и до края
constexpr int ShadowSteps = 8; // промежуточные тени перехода фокуса

// CSS пишет альфу последней (#rrggbbaa), QColor ждёт её первой.
QColor rgba(QRgb rgb, int alpha)
{
    QColor c(rgb);
    c.setAlpha(alpha);
    return c;
}

const Tokens s_light = {
    QColor(0xee5a50), QColor(0xb2352d), QColor(0xf2b234), QColor(0xa8760d), QColor(0x3fb958), QColor(0x23843a),
    QColor(0xdcdad5), QColor(0x8a867f), rgba(0x1d1c1a, 0xa6),
    rgba(0x1d1c1a, 0x2e), rgba(0x1d1c1a, 0x24),
    QColor(Qt::transparent), QColor(Qt::transparent),
};

const Tokens s_dark = {
    QColor(0xf0625a), QColor(0xc9443c), QColor(0xf3b843), QColor(0xb9861a), QColor(0x46c260), QColor(0x2e9748),
    QColor(0x4a4845), QColor(0x7a766f), rgba(0x1d1c1a, 0xb3),
    rgba(0x000000, 0xe6), rgba(0x000000, 0xcc),
    rgba(0xffffff, 0x1f), rgba(0xffffff, 0x14),
};

// shadow-window и shadow-window-inactive без кольца 0.5px (его рисует обводка KWin).
const QList<BoxShadow> s_shadowLayers[2][2] = {
    {
        {{4, 10, 0, rgba(0x1d1c1a, 0x12)}, {14, 36, 0, rgba(0x1d1c1a, 0x1f)}},
        {{6, 16, 0, rgba(0x1d1c1a, 0x1a)}, {24, 64, 4, rgba(0x1d1c1a, 0x2e)}},
    },
    {
        {{6, 14, 0, rgba(0x000000, 0x4d)}, {16, 40, 0, rgba(0x000000, 0x73)}},
        {{8, 20, 0, rgba(0x000000, 0x66)}, {28, 72, 6, rgba(0x000000, 0xa6)}},
    },
};

int s_decorationCount = 0;
int s_snapCount = 0;
std::shared_ptr<KDecoration3::DecorationShadow> s_shadows[2][ShadowSteps + 1]; // [тёмная][шаг фокуса]

// Тень для доли фокуса: слои shadow-window-inactive → shadow-window попарно, как CSS-переход
std::shared_ptr<KDecoration3::DecorationShadow> shadowFor(bool dark, qreal focus)
{
    const int step = qBound(0, qRound(focus * ShadowSteps), ShadowSteps);
    auto &shadow = s_shadows[dark][step];
    if (!shadow) {
        QMarginsF padding;
        const auto layers = mixShadows(s_shadowLayers[dark][0], s_shadowLayers[dark][1], qreal(step) / ShadowSteps);
        const QImage image = renderBoxShadow(layers, CornerRadius, &padding);
        shadow = std::make_shared<KDecoration3::DecorationShadow>();
        shadow->setPadding(padding);
        shadow->setInnerShadowRect(QRectF(QRectF(image.rect()).center(), QSizeF(1, 1)));
        shadow->setShadow(image);
    }
    return shadow;
}

} // namespace

Decoration::Decoration(QObject *parent, const QVariantList &args)
    : KDecoration3::Decoration(parent, args)
    , m_glyphAnimation(new QVariantAnimation(this))
    , m_focusAnimation(new QVariantAnimation(this))
    , m_snapArm(new QTimer(this))
    , m_snapDisarm(new QTimer(this))
{
    s_decorationCount++;
}

Decoration::~Decoration()
{
    delete m_snapPopup;
    if (--s_decorationCount == 0) {
        for (auto &row : s_shadows) {
            for (auto &shadow : row) {
                shadow.reset();
            }
        }
    }
}

bool Decoration::init()
{
    m_glyphAnimation->setStartValue(0.0);
    m_glyphAnimation->setEndValue(1.0);
    m_glyphAnimation->setDuration(GlyphDuration);
    m_glyphAnimation->setEasingCurve(QEasingCurve::OutCubic);
    connect(m_glyphAnimation, &QVariantAnimation::valueChanged, this, [this](const QVariant &value) {
        m_glyphOpacity = value.toReal();
        update(m_leftButtons->geometry());
        update(m_rightButtons->geometry());
    });

    m_focus = window()->isActive() ? 1 : 0;
    m_focusAnimation->setDuration(FocusDuration);
    m_focusAnimation->setEasingCurve(QEasingCurve::OutCubic);
    connect(m_focusAnimation, &QVariantAnimation::valueChanged, this, [this](const QVariant &value) {
        m_focus = value.toReal();
        updateShadow();
        updateOutline();
    });

    m_snapArm->setSingleShot(true);
    m_snapArm->setInterval(SnapDelay);
    connect(m_snapArm, &QTimer::timeout, this, &Decoration::showSnap);
    m_snapDisarm->setSingleShot(true);
    m_snapDisarm->setInterval(SnapLinger);
    connect(m_snapDisarm, &QTimer::timeout, this, &Decoration::hideSnap);

    m_leftButtons = new KDecoration3::DecorationButtonGroup(KDecoration3::DecorationButtonGroup::Position::Left, this, &Button::create);
    m_rightButtons = new KDecoration3::DecorationButtonGroup(KDecoration3::DecorationButtonGroup::Position::Right, this, &Button::create);

    const auto w = window();
    const auto s = settings().get();
    connect(w, &KDecoration3::DecoratedWindow::activeChanged, this, [this]() {
        m_focusAnimation->stop();
        m_focusAnimation->setStartValue(m_focus);
        m_focusAnimation->setEndValue(window()->isActive() ? 1.0 : 0.0);
        m_focusAnimation->start();
        updateLayout();
    });
    connect(w, &KDecoration3::DecoratedWindow::paletteChanged, this, &Decoration::updateLayout);
    connect(w, &KDecoration3::DecoratedWindow::maximizedChanged, this, &Decoration::updateLayout);
    connect(w, &KDecoration3::DecoratedWindow::maximizedHorizontallyChanged, this, &Decoration::updateLayout);
    connect(w, &KDecoration3::DecoratedWindow::maximizedVerticallyChanged, this, &Decoration::updateLayout);
    connect(w, &KDecoration3::DecoratedWindow::shadedChanged, this, &Decoration::updateLayout);
    connect(w, &KDecoration3::DecoratedWindow::nextScaleChanged, this, &Decoration::updateLayout);
    connect(w, &KDecoration3::DecoratedWindow::widthChanged, this, &Decoration::updateLayout);
    connect(w, &KDecoration3::DecoratedWindow::captionChanged, this, [this]() {
        update(titleBar());
    });
    connect(s, &KDecoration3::DecorationSettings::fontChanged, this, &Decoration::updateLayout);
    connect(s, &KDecoration3::DecorationSettings::spacingChanged, this, &Decoration::updateLayout);
    connect(s, &KDecoration3::DecorationSettings::reconfigured, this, &Decoration::updateLayout);
    connect(s, &KDecoration3::DecorationSettings::decorationButtonsLeftChanged, this, &Decoration::updateLayout);
    connect(s, &KDecoration3::DecorationSettings::decorationButtonsRightChanged, this, &Decoration::updateLayout);

    updateLayout();
    return true;
}

bool Decoration::isDark() const
{
    return qGray(titleBarColor().rgb()) < 128;
}

const Tokens &Decoration::tokens() const
{
    return isDark() ? s_dark : s_light;
}

bool Decoration::isMaximized() const
{
    return window()->isMaximized();
}

QColor Decoration::titleBarColor() const
{
    return window()->color(window()->isActive() ? ColorGroup::Active : ColorGroup::Inactive, ColorRole::TitleBar);
}

qreal Decoration::cornerRadius() const
{
    return isMaximized() ? 0 : KDecoration3::snapToPixelGrid(CornerRadius, window()->nextScale());
}

void Decoration::updateLayout()
{
    const qreal scale = window()->nextScale();
    const qreal radius = cornerRadius();

    // Рамок нет: окно — заголовок и содержимое; тянуть можно за невидимые поля.
    // borderTop() отдаёт текущее состояние до следующего кадра, поэтому высота считается здесь.
    const qreal titleBar = KDecoration3::snapToPixelGrid(TitleBarHeight, scale);
    setBorders(QMarginsF(0, titleBar, 0, 0));
    const qreal grip = KDecoration3::snapToPixelGrid(settings()->largeSpacing(), scale);
    setResizeOnlyBorders(QMarginsF(window()->isMaximizedHorizontally() ? 0 : grip, 0, window()->isMaximizedHorizontally() ? 0 : grip,
                                   window()->isMaximizedVertically() ? 0 : grip));
    setTitleBar(QRectF(0, 0, window()->width(), titleBar));

    // Нижние углы содержимого скругляет KWin, верхние — заголовок.
    const qreal bottom = window()->isShaded() ? 0 : radius;
    setBorderRadius(KDecoration3::BorderRadius(0, 0, bottom, bottom));
    updateOutline();
    updateButtons(titleBar);
    updateShadow();
    update();
}

void Decoration::updateButtons(qreal titleBar)
{
    // Размер кнопки задан при создании; группа сама раскладывает их от своей позиции.
    const qreal inset = (titleBar - ButtonHit) / 2;
    m_leftButtons->setSpacing(0);
    m_rightButtons->setSpacing(0);
    m_leftButtons->setPos(QPointF(inset, inset));
    m_rightButtons->setPos(QPointF(window()->width() - m_rightButtons->geometry().width() - inset, inset));
}

void Decoration::updateShadow()
{
    setShadow(shadowFor(isDark(), m_focus));
}

void Decoration::updateOutline()
{
    if (isMaximized()) {
        setBorderOutline(KDecoration3::BorderOutline());
        return;
    }
    // Кольцо 0.5px: на экране 1× — 1px с половинной альфой; цвет переходит вместе с тенью.
    const qreal thickness = KDecoration3::pixelSize(window()->nextScale());
    const QColor from = tokens().ringInactive;
    QColor ring = tokens().ring;
    ring.setAlphaF((from.alphaF() + (ring.alphaF() - from.alphaF()) * m_focus) * std::min<qreal>(1.0, 0.5 / thickness));
    setBorderOutline(KDecoration3::BorderOutline(thickness, ring, KDecoration3::BorderRadius(cornerRadius())));
}

void Decoration::hoverEnterEvent(QHoverEvent *event)
{
    KDecoration3::Decoration::hoverEnterEvent(event);
    updateGroupHover(event->position());
}

void Decoration::hoverMoveEvent(QHoverEvent *event)
{
    KDecoration3::Decoration::hoverMoveEvent(event);
    updateGroupHover(event->position());
}

void Decoration::hoverLeaveEvent(QHoverEvent *event)
{
    KDecoration3::Decoration::hoverLeaveEvent(event);
    updateGroupHover(QPointF(-1, -1));
}

void Decoration::mousePressEvent(QMouseEvent *event)
{
    KDecoration3::Decoration::mousePressEvent(event);
    m_snapArm->stop();
    hideSnap();
}

KDecoration3::DecorationButton *Decoration::zoomButton() const
{
    for (auto group : {m_leftButtons, m_rightButtons}) {
        for (KDecoration3::DecorationButton *button : group->buttons()) {
            if (button->type() == DecorationButtonType::Maximize) {
                return button;
            }
        }
    }
    return nullptr;
}

void Decoration::updateGroupHover(const QPointF &pos)
{
    // Задержка на зелёной кнопке открывает раскладки; уход курсора закрывает их с запасом
    m_hoverPos = pos;
    const auto zoom = zoomButton();
    const bool zoomHovered = zoom && zoom->isEnabled() && window()->isResizeable() && zoom->geometry().contains(pos);
    if (zoomHovered != m_zoomHovered) {
        m_zoomHovered = zoomHovered;
        if (zoomHovered) {
            m_snapDisarm->stop();
            if (!m_snapPopup) {
                m_snapArm->start();
            }
        } else {
            m_snapArm->stop();
            if (m_snapPopup) {
                m_snapDisarm->start();
            }
        }
    }

    const bool hovered = (!m_leftButtons->buttons().isEmpty() && m_leftButtons->geometry().contains(pos))
        || (!m_rightButtons->buttons().isEmpty() && m_rightButtons->geometry().contains(pos));
    if (hovered == m_groupHovered) {
        return;
    }
    m_groupHovered = hovered;
    m_glyphAnimation->setDirection(hovered ? QAbstractAnimation::Forward : QAbstractAnimation::Backward);
    if (m_glyphAnimation->state() != QAbstractAnimation::Running) {
        m_glyphAnimation->start();
    }
    update(m_leftButtons->geometry());
    update(m_rightButtons->geometry());
}

void Decoration::showSnap()
{
    if (m_snapPopup || !m_zoomHovered) {
        return;
    }
    const bool dark = isDark();
    auto rgba = [](QRgb rgb, int a) {
        QColor c(rgb);
        c.setAlpha(a);
        return c;
    };
    SnapColors colors;
    colors.dark = dark;
    colors.background = dark ? QColor(0x33322f) : QColor(0xfcfbf9);
    colors.ring = dark ? rgba(0x000000, 0xcc) : rgba(0x1d1c1a, 0x24);
    colors.highlight = tokens().highlight;
    colors.title = dark ? QColor(0xb3afa7) : QColor(0x55524b);
    colors.layout = dark ? rgba(0xf2f0eb, 0x21) : rgba(0x1d1c1a, 0x1a);
    colors.zone = dark ? rgba(0xf2f0eb, 0x1f) : QColor(Qt::white);
    colors.zoneRing = dark ? rgba(0xffffff, 0x1a) : rgba(0x1d1c1a, 0x29);
    colors.accent = window()->palette().color(QPalette::Highlight);

    // Окно декорации на экране: курсор минус его место в декорации
    m_snapOrigin = QPointF(QCursor::pos()) - m_hoverPos;
    const QRectF group = m_leftButtons->buttons().isEmpty() ? m_rightButtons->geometry() : m_leftButtons->geometry();
    const qreal inset = (ButtonHit - ButtonSize) / 2;
    // .at-snap: на 10 левее группы кнопок и на 10 ниже кружков
    const QPointF anchor = m_snapOrigin + QPointF(group.left() + inset - 10, group.bottom() - inset + 10);

    m_snapPopup = new SnapPopup(colors, settings()->font());
    m_snapPopup->setPosition((anchor - m_snapPopup->panelOrigin()).toPoint());
    connect(m_snapPopup, &SnapPopup::entered, m_snapDisarm, &QTimer::stop);
    connect(m_snapPopup, &SnapPopup::left, m_snapDisarm, qOverload<>(&QTimer::start));
    connect(m_snapPopup, &SnapPopup::chosen, this, [this](int layout, int zone) {
        applySnap(layout, zone);
        hideSnap();
    });
    m_snapPopup->show();
}

void Decoration::hideSnap()
{
    m_snapDisarm->stop();
    if (m_snapPopup) {
        m_snapPopup->hide();
        m_snapPopup->deleteLater();
        m_snapPopup.clear();
    }
}

void Decoration::applySnap(int layout, int zone)
{
    // У декорации нет доступа к геометрии окна: скрипт KWin берёт верхнее окно под
    // зелёной кнопкой и ставит его в зону рабочей области с зазором space-8.
    const auto zoom = zoomButton();
    if (!zoom) {
        return;
    }
    const QPointF point = m_snapOrigin + zoom->geometry().center();
    const QRectF f = SnapPopup::zoneFraction(layout, zone);
    const QString script = QStringLiteral(
                               "(function () {\n"
                               "const p = {x: %1, y: %2}, f = {x: %3, y: %4, w: %5, h: %6}, g = %7;\n"
                               "const stack = workspace.stackingOrder;\n"
                               "for (let i = stack.length - 1; i >= 0; --i) {\n"
                               "    const w = stack[i];\n"
                               "    if (!w.normalWindow || w.minimized || !(w.onAllDesktops || w.desktops.indexOf(workspace.currentDesktop) >= 0)) {\n"
                               "        continue;\n"
                               "    }\n"
                               "    const r = w.frameGeometry;\n"
                               "    if (p.x < r.x || p.y < r.y || p.x >= r.x + r.width || p.y >= r.y + r.height) {\n"
                               "        continue;\n"
                               "    }\n"
                               "    w.setMaximize(false, false);\n"
                               "    const a = workspace.clientArea(KWin.MaximizeArea, w);\n"
                               "    const W = a.width - g, H = a.height - g;\n"
                               "    w.frameGeometry = {x: Math.round(a.x + g + f.x * W), y: Math.round(a.y + g + f.y * H),\n"
                               "                       width: Math.round(f.w * W - g), height: Math.round(f.h * H - g)};\n"
                               "    workspace.activeWindow = w;\n"
                               "    break;\n"
                               "}\n"
                               "})();\n")
                               .arg(point.x())
                               .arg(point.y())
                               .arg(f.x())
                               .arg(f.y())
                               .arg(f.width())
                               .arg(f.height())
                               .arg(SnapGap);

    const QString name = QStringLiteral("atlas-snap-%1").arg(++s_snapCount);
    const QString path = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation) + QLatin1Char('/') + name + QStringLiteral(".js");
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return;
    }
    file.write(script.toUtf8());
    file.close();

    // Свой же процесс по D-Bus — только асинхронно, иначе KWin ждал бы сам себя
    auto call = [](const QString &method, const QVariantList &args) {
        auto message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"),
                                                      QStringLiteral("/Scripting"),
                                                      QStringLiteral("org.kde.kwin.Scripting"),
                                                      method);
        message.setArguments(args);
        QDBusConnection::sessionBus().asyncCall(message);
    };
    call(QStringLiteral("loadScript"), {path, name});
    call(QStringLiteral("start"), {});
    QTimer::singleShot(2000, [call, name, path]() {
        call(QStringLiteral("unloadScript"), {name});
        QFile::remove(path);
    });
}

void Decoration::paint(QPainter *painter, const QRectF &repaintArea)
{
    const QRectF bar(0, 0, size().width(), borderTop());
    const qreal radius = cornerRadius();
    const bool active = window()->isActive();

    if (bar.intersects(repaintArea)) {
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing);
        painter->setPen(Qt::NoPen);
        painter->setClipRect(bar, Qt::IntersectClip);
        QPainterPath shape;
        if (window()->isShaded()) {
            shape.addRoundedRect(bar, radius, radius);
        } else {
            shape.addRoundedRect(bar.adjusted(0, 0, 0, radius), radius, radius);
        }
        painter->fillPath(shape, titleBarColor());

        // Тёмная тема: блик inset 0 0.5px 0 по верхней кромке.
        const QColor highlight = active ? tokens().highlight : tokens().highlightInactive;
        if (highlight.alpha() > 0 && !isMaximized()) {
            painter->fillPath(shape.subtracted(shape.translated(0, 0.5)), highlight);
        }
        painter->restore();

        const qreal left = m_leftButtons->buttons().isEmpty() ? TitleGap : m_leftButtons->geometry().right() + TitleGap - (ButtonHit - ButtonSize) / 2;
        const qreal right = m_rightButtons->buttons().isEmpty() ? size().width() - TitleGap
                                                                 : m_rightButtons->geometry().left() - TitleGap + (ButtonHit - ButtonSize) / 2;
        const QRectF captionRect(left, 0, std::max<qreal>(0, right - left), borderTop());
        painter->setFont(settings()->font());
        painter->setPen(window()->color(active ? ColorGroup::Active : ColorGroup::Inactive, ColorRole::Foreground));
        const QString caption = painter->fontMetrics().elidedText(window()->caption(), Qt::ElideRight, captionRect.width());
        painter->drawText(captionRect, Qt::AlignVCenter | Qt::AlignLeft | Qt::TextSingleLine, caption);
    }

    m_leftButtons->paint(painter, repaintArea);
    m_rightButtons->paint(painter, repaintArea);
}

Button::Button(DecorationButtonType type, Decoration *decoration, QObject *parent)
    : KDecoration3::DecorationButton(type, decoration, parent)
{
    auto repaint = [this]() {
        update();
    };
    connect(this, &KDecoration3::DecorationButton::hoveredChanged, this, repaint);
    connect(this, &KDecoration3::DecorationButton::pressedChanged, this, repaint);
    connect(this, &KDecoration3::DecorationButton::enabledChanged, this, repaint);
    connect(this, &KDecoration3::DecorationButton::checkedChanged, this, repaint);
    connect(decoration->window(), &KDecoration3::DecoratedWindow::activeChanged, this, repaint);
    setGeometry(QRectF(0, 0, ButtonHit, ButtonHit));
}

Button::Button(QObject *parent, const QVariantList &args)
    : Button(args.at(0).value<DecorationButtonType>(), args.at(1).value<Decoration *>(), parent)
{
}

KDecoration3::DecorationButton *Button::create(DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent)
{
    // Только три кнопки «Атласа»; меню окна — правый щелчок по заголовку.
    switch (type) {
    case DecorationButtonType::Close:
    case DecorationButtonType::Minimize:
    case DecorationButtonType::Maximize:
        break;
    default:
        return nullptr;
    }
    if (auto d = qobject_cast<Decoration *>(decoration)) {
        return new Button(type, d, parent);
    }
    return nullptr;
}

void Button::paint(QPainter *painter, const QRectF &repaintArea)
{
    auto d = qobject_cast<Decoration *>(decoration());
    if (!d || !geometry().intersects(repaintArea)) {
        return;
    }
    const Tokens &t = d->tokens();
    QColor fill, rim;
    switch (type()) {
    case DecorationButtonType::Close:
        fill = t.close, rim = t.closeRim;
        break;
    case DecorationButtonType::Minimize:
        fill = t.minimize, rim = t.minimizeRim;
        break;
    default:
        fill = t.zoom, rim = t.zoomRim;
        break;
    }
    // Неактивное окно — серые кнопки, цвет возвращается при наведении на группу.
    // Недоступная кнопка (диалог без «развернуть») остаётся на месте серой.
    if (!isEnabled() || (!d->window()->isActive() && !d->isGroupHovered())) {
        fill = t.inactive, rim = t.inactiveRim;
    }
    if (isPressed()) {
        fill = fill.darker(116); // brightness(.86)
        rim = rim.darker(116);
    }

    const QRectF circle(geometry().center() - QPointF(ButtonSize / 2, ButtonSize / 2), QSizeF(ButtonSize, ButtonSize));
    painter->save();
    painter->setRenderHint(QPainter::Antialiasing);
    painter->setPen(Qt::NoPen);
    painter->setBrush(rim);
    painter->drawEllipse(circle);
    painter->setBrush(fill);
    painter->drawEllipse(circle.adjusted(0.5, 0.5, -0.5, -0.5));

    // Глифы ×, −, ⤢ в поле 9×9 (WindowControls): штрих 1.6, круглые концы.
    if (isEnabled() && d->glyphOpacity() > 0) {
        QColor glyph = t.glyph;
        glyph.setAlphaF(glyph.alphaF() * d->glyphOpacity());
        painter->translate(circle.center() - QPointF(4.5, 4.5));
        switch (type()) {
        case DecorationButtonType::Close:
            painter->setPen(QPen(glyph, 1.6, Qt::SolidLine, Qt::RoundCap));
            painter->drawLine(QPointF(2.2, 2.2), QPointF(6.8, 6.8));
            painter->drawLine(QPointF(6.8, 2.2), QPointF(2.2, 6.8));
            break;
        case DecorationButtonType::Minimize:
            painter->setPen(QPen(glyph, 1.6, Qt::SolidLine, Qt::RoundCap));
            painter->drawLine(QPointF(1.8, 4.5), QPointF(7.2, 4.5));
            break;
        default: {
            QPainterPath arrows;
            arrows.addPolygon(QPolygonF({QPointF(2, 7), QPointF(2, 3.4), QPointF(5.6, 7)}));
            arrows.closeSubpath();
            arrows.addPolygon(QPolygonF({QPointF(7, 2), QPointF(7, 5.6), QPointF(3.4, 2)}));
            arrows.closeSubpath();
            painter->fillPath(arrows, glyph);
            break;
        }
        }
    }
    painter->restore();
}

} // namespace Atlas

#include "atlasdecoration.moc"
