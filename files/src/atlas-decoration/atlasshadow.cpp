/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#include "atlasshadow.h"

#include <QPainter>
#include <QPainterPath>

#include <algorithm>
#include <cmath>
#include <vector>

namespace Atlas
{
namespace
{

// Гаусс приближён тремя проходами box blur (CSS: sigma = blur / 2).
std::vector<int> boxesForGauss(qreal sigma, int n)
{
    const qreal wIdeal = std::sqrt(12 * sigma * sigma / n + 1);
    int wl = int(std::floor(wIdeal));
    if (wl % 2 == 0) {
        wl--;
    }
    const int wu = wl + 2;
    const qreal mIdeal = (12 * sigma * sigma - n * wl * wl - 4 * n * wl - 3 * n) / (-4.0 * wl - 4);
    const int m = int(std::round(mIdeal));
    std::vector<int> sizes;
    for (int i = 0; i < n; ++i) {
        sizes.push_back(i < m ? wl : wu);
    }
    return sizes;
}

void boxBlurPass(const std::vector<float> &src, std::vector<float> &dst, int w, int h, int r, bool horizontal)
{
    const int len = horizontal ? w : h;
    const int lines = horizontal ? h : w;
    const float scale = 1.0f / (2 * r + 1);
    for (int line = 0; line < lines; ++line) {
        auto at = [&](int i) -> float {
            if (i < 0 || i >= len) {
                return 0.0f;
            }
            return horizontal ? src[line * w + i] : src[i * w + line];
        };
        float acc = 0;
        for (int i = -r; i <= r; ++i) {
            acc += at(i);
        }
        for (int i = 0; i < len; ++i) {
            const int idx = horizontal ? line * w + i : i * w + line;
            dst[idx] = acc * scale;
            acc += at(i + r + 1) - at(i - r);
        }
    }
}

void gaussianBlur(std::vector<float> &alpha, int w, int h, qreal sigma)
{
    if (sigma <= 0) {
        return;
    }
    std::vector<float> tmp(alpha.size());
    for (int size : boxesForGauss(sigma, 3)) {
        const int r = (size - 1) / 2;
        boxBlurPass(alpha, tmp, w, h, r, true);
        boxBlurPass(tmp, alpha, w, h, r, false);
    }
}

std::vector<float> roundedRectMask(const QSize &size, const QRectF &rect, qreal radius)
{
    QImage mask(size, QImage::Format_Alpha8);
    mask.fill(0);
    QPainter p(&mask);
    p.setRenderHint(QPainter::Antialiasing);
    p.setPen(Qt::NoPen);
    p.setBrush(Qt::black);
    p.drawRoundedRect(rect, radius, radius);
    p.end();
    std::vector<float> alpha(size.width() * size.height());
    for (int y = 0; y < size.height(); ++y) {
        const uchar *line = mask.constScanLine(y);
        for (int x = 0; x < size.width(); ++x) {
            alpha[y * size.width() + x] = line[x] / 255.0f;
        }
    }
    return alpha;
}

} // namespace

QImage renderBoxShadow(const QList<BoxShadow> &layers, qreal radius, QMarginsF *padding)
{
    return renderBoxShadow(layers, radius, QSize(), padding);
}

QList<BoxShadow> mixShadows(const QList<BoxShadow> &from, const QList<BoxShadow> &to, qreal t)
{
    QList<BoxShadow> out;
    for (int i = 0; i < std::min(from.size(), to.size()); ++i) {
        const BoxShadow &a = from[i];
        const BoxShadow &b = to[i];
        QColor c = b.color;
        c.setAlphaF(a.color.alphaF() + (b.color.alphaF() - a.color.alphaF()) * t);
        out.append({a.dy + (b.dy - a.dy) * t, a.blur + (b.blur - a.blur) * t, a.spread + (b.spread - a.spread) * t, c});
    }
    return out;
}

QImage renderBoxShadow(const QList<BoxShadow> &layers, qreal radius, const QSize &boxSize, QMarginsF *padding)
{
    // Тень гаусса заметна до 3 sigma = 1.5 blur.
    qreal extent = 0;
    qreal top = 0;
    qreal bottom = 0;
    qreal maxDy = 0;
    for (const BoxShadow &l : layers) {
        const qreal e = l.spread + 1.5 * l.blur;
        extent = std::max(extent, e);
        top = std::max(top, e - l.dy);
        bottom = std::max(bottom, e + l.dy);
        maxDy = std::max(maxDy, std::abs(l.dy));
    }
    const int side = int(std::ceil(extent));
    const int padTop = int(std::ceil(std::max<qreal>(top, 0)));
    const int padBottom = int(std::ceil(bottom));
    // Окно в картинке — квадрат, у которого углы тени сформированы полностью:
    // KWin растягивает только центральную строку и столбец.
    const int box = 2 * int(std::ceil(radius + extent + maxDy)) + 1;
    const QSize inner = boxSize.isValid() ? boxSize : QSize(box, box);
    const QSize size(inner.width() + 2 * side, inner.height() + padTop + padBottom);
    const QRectF boxRect(QPointF(side, padTop), inner);
    const int w = size.width();
    const int h = size.height();

    std::vector<float> rgba(w * h * 4, 0.0f); // premultiplied
    for (const BoxShadow &l : layers) {
        const QRectF shape = boxRect.translated(0, l.dy).adjusted(-l.spread, -l.spread, l.spread, l.spread);
        std::vector<float> alpha = roundedRectMask(size, shape, radius + l.spread);
        gaussianBlur(alpha, w, h, l.blur / 2);
        const float cr = l.color.redF(), cg = l.color.greenF(), cb = l.color.blueF(), ca = l.color.alphaF();
        for (int i = 0; i < w * h; ++i) {
            const float a = alpha[i] * ca;
            float *px = &rgba[i * 4];
            px[0] = cr * a + px[0] * (1 - a);
            px[1] = cg * a + px[1] * (1 - a);
            px[2] = cb * a + px[2] * (1 - a);
            px[3] = a + px[3] * (1 - a);
        }
    }

    // Под окном тени нет; вырез на 1px меньше окна, чтобы у края не было просвета.
    const std::vector<float> hole = roundedRectMask(size, boxRect.adjusted(1, 1, -1, -1), std::max<qreal>(radius - 1, 0));
    QImage image(size, QImage::Format_ARGB32_Premultiplied);
    for (int y = 0; y < h; ++y) {
        QRgb *line = reinterpret_cast<QRgb *>(image.scanLine(y));
        for (int x = 0; x < w; ++x) {
            const int i = y * w + x;
            const float keep = 1 - hole[i];
            const float *px = &rgba[i * 4];
            auto c = [&](float v) {
                return std::clamp(int(std::lround(v * keep * 255)), 0, 255);
            };
            line[x] = qRgba(c(px[0]), c(px[1]), c(px[2]), c(px[3]));
        }
    }

    *padding = QMarginsF(side, padTop, side, padBottom);
    return image;
}

} // namespace Atlas
