"""Plasma Style «Атлас» из tokens.json дизайн-системы.

Собирает две темы Plasma (desktoptheme): atlas (светлая) и atlas-dark. Каждая рамка —
SVG из девяти частей (FrameSvg) + маска размытия + тень:
  тело   — тонировка material-* (в translucent/) или непрозрачная замена (opaque/, solid/, корень);
  край   — material-rim (обводка 0.5px) и material-edge (блик 0.5px сверху);
  тень   — слои shadow-* без inset/обводки, гауссово размытие, растр 2x в PNG внутри SVG.
Без сторонних зависимостей.

    python tools/gen_plasma_style.py <tokens.json> files/system/usr/share/plasma/desktoptheme
"""
import base64, json, math, os, re, struct, sys, zlib

SCALE = 2  # тени рисуются в 2x и масштабируются Plasma

# рамка -> (материал, непрозрачная замена, радиус, отступ контента, тень)
FRAMES = {
    'dialogs/background': ('material-popover', 'bg-elevated', 'radius-md', 6, 'shadow-popover'),
    'widgets/tooltip': ('material-popover', 'bg-elevated', 'radius-md', 6, 'shadow-popover'),
    'widgets/panel-background': ('material-menubar', 'bg-window', 'radius-xl', 4, 'shadow-dock'),
}
THEMES = {
    'light': ('atlas', 'Атлас', 'Atlas'),
    'dark': ('atlas-dark', 'Атлас тёмная', 'Atlas Dark'),
}
MID = 16  # длина растягиваемых частей


def load(path):
    t = json.load(open(path, encoding='utf-8'))
    colors = {x['name']: x['value'] for x in t['color']['tokens']}
    radius = {x['name']: float(x['value'].rstrip('px')) for x in t['radius']['tokens']}
    shadow = {x['name']: x['value'] for x in t['shadow']['tokens']}
    return colors, radius, shadow


def color(colors, name, th):
    v = colors[name][th] if isinstance(colors[name], dict) else colors[name]
    return color(colors, v[1:-1], th) if v.startswith('{') else v


def rgba(hexstr):
    s = hexstr.lstrip('#')
    a = int(s[6:8], 16) / 255 if len(s) == 8 else 1.0
    return '#' + s[:6], a


def shadow_layers(value):
    """'0 2px 6px #rrggbbaa, inset …' -> [(x, y, blur, spread, alpha)] без inset и обводок."""
    out = []
    for part in value.split(','):
        part = part.strip()
        if part.startswith('inset'):
            continue
        nums = [float(n) for n in re.findall(r'-?[\d.]+(?=px|\s|$)', part.split('#')[0])]
        nums += [0] * (4 - len(nums))
        x, y, blur, spread = nums[:4]
        if blur == 0:
            continue  # обводка 0 0 0 0.5px — рисуется как rim
        out.append((x, y, blur, spread, rgba('#' + part.split('#')[1])[1]))
    return out


# --- растр ---------------------------------------------------------------

def rrect_cover(w, h, x0, y0, rw, rh, r, sub=4):
    """Покрытие скруглённого прямоугольника (в пикселях растра) с суперсэмплингом."""
    cov = [[0.0] * w for _ in range(h)]
    x1, y1 = x0 + rw, y0 + rh
    r = max(0.0, min(r, rw / 2, rh / 2))
    for j in range(h):
        for i in range(w):
            if i + 1 < x0 or i > x1 or j + 1 < y0 or j > y1:
                continue
            hit = 0
            for sj in range(sub):
                py = j + (sj + 0.5) / sub
                for si in range(sub):
                    px = i + (si + 0.5) / sub
                    if not (x0 <= px <= x1 and y0 <= py <= y1):
                        continue
                    cx = min(max(px, x0 + r), x1 - r)
                    cy = min(max(py, y0 + r), y1 - r)
                    if (px - cx) ** 2 + (py - cy) ** 2 <= r * r:
                        hit += 1
            cov[j][i] = hit / (sub * sub)
    return cov


def box_blur(img, rad):
    if rad < 1:
        return img
    h, w = len(img), len(img[0])
    def line(src):
        n = len(src); out = [0.0] * n; acc = 0.0; k = 2 * rad + 1
        for i in range(-rad, rad + 1):
            acc += src[min(max(i, 0), n - 1)] if 0 <= i < n else 0.0
        for i in range(n):
            out[i] = acc / k
            a, b = i + rad + 1, i - rad
            acc += (src[a] if a < n else 0.0) - (src[b] if b >= 0 else 0.0)
        return out
    img = [line(row) for row in img]
    cols = [line([img[j][i] for j in range(h)]) for i in range(w)]
    return [[cols[i][j] for i in range(w)] for j in range(h)]


def gauss(img, sigma):
    # три прохода box blur ≈ гауссиана
    n = 3
    wideal = math.sqrt(12 * sigma * sigma / n + 1)
    wl = int(wideal) - (int(wideal) % 2 == 0)
    wu = wl + 2
    m = round((12 * sigma * sigma - n * wl * wl - 4 * n * wl - 3 * n) / (-4 * wl - 4))
    for k in range(n):
        img = box_blur(img, ((wl if k < m else wu) - 1) // 2)
    return img


def png(alpha):
    h, w = len(alpha), len(alpha[0])
    raw = b''.join(b'\x00' + bytes(v for a in row for v in (0, 0, 0, max(0, min(255, round(a * 255))))) for row in alpha)
    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def shadow_raster(layers, R, S):
    W = 2 * R + MID
    T = W + 2 * S
    n = int(T * SCALE)
    acc = [[0.0] * n for _ in range(n)]
    for x, y, blur, spread, a in layers:
        cov = rrect_cover(n, n, (S + x - spread) * SCALE, (S + y - spread) * SCALE,
                          (W + 2 * spread) * SCALE, (W + 2 * spread) * SCALE, max(0, R + spread) * SCALE, sub=2)
        cov = gauss(cov, blur / 2 * SCALE)
        for j in range(n):
            for i in range(n):
                acc[j][i] = 1 - (1 - acc[j][i]) * (1 - cov[j][i] * a)
    body = rrect_cover(n, n, S * SCALE, S * SCALE, W * SCALE, W * SCALE, R * SCALE)
    # под полупрозрачным телом тени быть не должно, иначе материал темнеет
    return [[acc[j][i] * (1 - body[j][i]) for i in range(n)] for j in range(n)]


def crop(img, x, y, w, h):
    x, y, w, h = (int(round(v * SCALE)) for v in (x, y, w, h))
    return [row[x:x + w] for row in img[y:y + h]]


# --- SVG -----------------------------------------------------------------

def frame_svg(fill, alpha, rim, edge, R, margin, shadow_img, S):
    W = 2 * R + MID
    o = S  # рамка начинается после поля тени
    rim_c, rim_a = rgba(rim)
    edge_c, edge_a = rgba(edge)
    els = []

    def bbox(x, y, w, h):
        return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" style="fill:none;stroke:none"/>'

    def piece(eid, x, y, w, h, body, strokes=''):
        els.append(f'<g id="{eid}">{bbox(x, y, w, h)}{body}{strokes}</g>')

    corners = {
        # имя: (x, y, дуга тела, обводка, блик)
        'topleft': (o, o, f'M{o},{o+R} A{R},{R} 0 0 1 {o+R},{o} L{o+R},{o+R} Z',
                    f'M{o+.25},{o+R} A{R-.25},{R-.25} 0 0 1 {o+R},{o+.25}',
                    f'M{o+.75},{o+R} A{R-.75},{R-.75} 0 0 1 {o+R},{o+.75}'),
        'topright': (o + R + MID, o, f'M{o+R+MID},{o} A{R},{R} 0 0 1 {o+W},{o+R} L{o+R+MID},{o+R} Z',
                     f'M{o+R+MID},{o+.25} A{R-.25},{R-.25} 0 0 1 {o+W-.25},{o+R}',
                     f'M{o+R+MID},{o+.75} A{R-.75},{R-.75} 0 0 1 {o+W-.75},{o+R}'),
        'bottomright': (o + R + MID, o + R + MID, f'M{o+W},{o+R+MID} A{R},{R} 0 0 1 {o+R+MID},{o+W} L{o+R+MID},{o+R+MID} Z',
                        f'M{o+W-.25},{o+R+MID} A{R-.25},{R-.25} 0 0 1 {o+R+MID},{o+W-.25}', None),
        'bottomleft': (o, o + R + MID, f'M{o+R},{o+W} A{R},{R} 0 0 1 {o},{o+R+MID} L{o+R},{o+R+MID} Z',
                       f'M{o+R},{o+W-.25} A{R-.25},{R-.25} 0 0 1 {o+.25},{o+R+MID}', None),
    }
    sides = {
        'top': (o + R, o, MID, R, f'M{o+R},{o+.25} H{o+R+MID}', f'M{o+R},{o+.75} H{o+R+MID}'),
        'bottom': (o + R, o + R + MID, MID, R, f'M{o+R},{o+W-.25} H{o+R+MID}', None),
        'left': (o, o + R, R, MID, f'M{o+.25},{o+R} V{o+R+MID}', None),
        'right': (o + R + MID, o + R, R, MID, f'M{o+W-.25},{o+R} V{o+R+MID}', None),
    }
    fill_style = f'fill:{fill};fill-opacity:{alpha:.4f};stroke:none'

    def strokes(rimd, edged):
        s = f'<path d="{rimd}" style="fill:none;stroke:{rim_c};stroke-opacity:{rim_a:.4f};stroke-width:0.5"/>'
        if edged:
            s += f'<path d="{edged}" style="fill:none;stroke:{edge_c};stroke-opacity:{edge_a:.4f};stroke-width:0.5"/>'
        return s

    # Тело — один center на всю рамку, обрезанный маской (hint-compose-over-border):
    # кромки несут только обводку и блик. Иначе Plasma местами не рисует кромки
    # у крайних апплетов панели, и в подложке остаются дыры высотой в радиус.
    for name, (x, y, d, rimd, edged) in corners.items():
        piece(name, x, y, R, R, '', strokes(rimd, edged))
        piece('mask-' + name, x, y, R, R, f'<path d="{d}" style="fill:#000;stroke:none"/>')
    for name, (x, y, w, h, rimd, edged) in sides.items():
        piece(name, x, y, w, h, '', strokes(rimd, edged))
        piece('mask-' + name, x, y, w, h, f'<rect x="{x}" y="{y}" width="{w}" height="{h}" style="fill:#000;stroke:none"/>')
    for prefix, fs in (('', fill_style), ('mask-', 'fill:#000;stroke:none')):
        piece(prefix + 'center', o + R, o + R, MID, MID,
              f'<rect x="{o+R}" y="{o+R}" width="{MID}" height="{MID}" style="{fs}"/>')

    hx = o + W + S + 8  # подсказки — правее всего
    els.append(f'<rect id="hint-compose-over-border" x="{hx}" y="10" width="4" height="4" style="fill:none"/>')
    # растягивать, а не замащивать: на полупрозрачной заливке стыки плиток видны сеткой
    els.append(f'<rect id="hint-stretch-borders" x="{hx}" y="20" width="4" height="4" style="fill:none"/>')
    els.append(f'<rect id="mask-hint-stretch-borders" x="{hx}" y="30" width="4" height="4" style="fill:none"/>')
    for side in ('top', 'bottom', 'left', 'right'):
        w, h = (10, margin) if side in ('top', 'bottom') else (margin, 10)
        els.append(f'<rect id="hint-{side}-margin" x="{hx}" y="0" width="{w}" height="{h}" style="fill:none"/>')
        sw, sh = (10, S) if side in ('top', 'bottom') else (S, 10)
        els.append(f'<rect id="shadow-hint-{side}-margin" x="{hx+20}" y="0" width="{sw}" height="{sh}" style="fill:none"/>')
        # нулевые вставки, как у Breeze: без них Plasma считает −1 и подрезает фон крайних апплетов панели
        iw, ih = (4, 1e-8) if side in ('top', 'bottom') else (1e-8, 4)
        els.append(f'<rect id="hint-{side}-inset" x="{hx}" y="40" width="{iw}" height="{ih}" style="fill:none"/>')

    K = S + R
    T = W + 2 * S
    spieces = {
        'shadow-topleft': (0, 0, K, K), 'shadow-top': (K, 0, MID, S), 'shadow-topright': (K + MID, 0, K, K),
        'shadow-left': (0, K, S, MID), 'shadow-right': (T - S, K, S, MID),
        'shadow-bottomleft': (0, K + MID, K, K), 'shadow-bottom': (K, T - S, MID, S),
        'shadow-bottomright': (K + MID, K + MID, K, K),
    }
    for eid, (x, y, w, h) in spieces.items():
        data = base64.b64encode(png(crop(shadow_img, x, y, w, h))).decode()
        els.append(f'<g id="{eid}">{bbox(x, y, w, h)}<image x="{x}" y="{y}" width="{w}" height="{h}" '
                   f'preserveAspectRatio="none" xlink:href="data:image/png;base64,{data}"/></g>')

    total_w = hx + 40 + S
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<!-- Сгенерировано tools/gen_plasma_style.py из tokens.json «Атласа». Не править руками. -->\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
            f'width="{total_w}" height="{T}" viewBox="0 0 {total_w} {T}">\n' + '\n'.join(els) + '\n</svg>\n')


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'w', encoding='utf-8', newline='\n').write(text)


def main(tokens, out):
    colors, radius, shadows = load(tokens)
    for th, (tid, name, name_en) in THEMES.items():
        root = os.path.join(out, tid)
        rim, edge = color(colors, 'material-rim', th), color(colors, 'material-edge', th)
        for frame, (mat, opaque, rad, margin, sh) in FRAMES.items():
            R = radius[rad]
            R = int(R) if R == int(R) else R
            sv = shadows[sh][th] if isinstance(shadows[sh], dict) else shadows[sh]
            layers = shadow_layers(sv)
            S = max(1, math.ceil(max(b + sp + abs(y) for _, y, b, sp, _ in layers)))
            img = shadow_raster(layers, R, S)
            tint, ta = rgba(color(colors, mat, th))
            solid, _ = rgba(color(colors, opaque, th))
            write(os.path.join(root, 'translucent', frame + '.svg'), frame_svg(tint, ta, rim, edge, R, margin, img, S))
            for variant in ('opaque', 'solid', ''):
                write(os.path.join(root, variant, frame + '.svg'), frame_svg(solid, 1.0, rim, edge, R, margin, img, S))
        write(os.path.join(root, 'metadata.json'), json.dumps({
            'KPlugin': {'Authors': [{'Name': 'AtlasOS'}], 'Category': '',
                        'Description': 'Материалы дизайн-системы «Атлас»', 'Description[en]': 'Atlas design system materials',
                        'EnabledByDefault': True, 'Id': tid, 'License': 'LGPL-2.1-or-later',
                        'Name': name, 'Name[en]': name_en, 'Version': '1'},
            'X-Plasma-API': '5.0'}, ensure_ascii=False, indent=4) + '\n')
        write(os.path.join(root, 'plasmarc'), '\n'.join([
            '[Wallpaper]', 'defaultWallpaperTheme=Meridian', 'defaultFileSuffix=.webp',
            'defaultWidth=2560', 'defaultHeight=1600', '',
            '# Панель становится непрозрачной, когда окно развёрнуто', '[AdaptiveTransparency]', 'enabled=true', '',
            '# Насыщенность под материалами даёт эффект размытия KWin (Saturation в kwinrc);',
            '# эффект контраста Plasma отключён, чтобы не поднимать её дважды.',
            '[ContrastEffect]', 'enabled=false', '', '[BlurBehindEffect]', 'enabled=true', '']))


if __name__ == '__main__':
    main(*sys.argv[1:3])
