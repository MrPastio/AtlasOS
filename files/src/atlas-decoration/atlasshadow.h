/*
 * Тени окна из CSS-токенов shadow-window / shadow-window-inactive.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#pragma once

#include <QColor>
#include <QImage>
#include <QList>
#include <QMarginsF>

namespace Atlas
{

// Один слой box-shadow: смещение по вертикали, размытие и растяжение — как в CSS.
struct BoxShadow {
    qreal dy;
    qreal blur;
    qreal spread;
    QColor color;
};

// Рисует слои поверх друг друга вокруг прямоугольника с радиусом radius и вырезает
// сам прямоугольник: сквозь полупрозрачное окно тень не видна. padding — насколько
// тень выходит за край окна; окно занимает в картинке rect() - padding.
QImage renderBoxShadow(const QList<BoxShadow> &layers, qreal radius, QMarginsF *padding);

} // namespace Atlas
