"""Глифы «Атласа» (07-iconography.md, компонент Icon) — SVG для апплетов оболочки.

Контуры 20×20 из дизайн-системы: штрих 1.5, круглые концы, заливка только у помеченных «f».
Plasma перекрашивает их как маску (Kirigami.Icon isMask), поэтому цвет — чёрный.

    python tools/gen_glyphs.py <каталог> имя [имя ...]
"""
import os, sys

GLYPHS = {
    'wifi': [('p', 'M2.8 7.6a10.5 10.5 0 0 1 14.4 0'), ('p', 'M5.3 10.4a7 7 0 0 1 9.4 0'), ('p', 'M7.8 13.1a3.4 3.4 0 0 1 4.4 0'), ('c', 10, 15.7, 1, 'f')],
    'bluetooth': [('p', 'M6 6.5 14 13.5 10 17V3l4 3.5L6 13.5')],
    'volume': [('p', 'M3.5 7.75h2.75L10 4.5v11l-3.75-3.25H3.5z'), ('p', 'M13 7.5a3.5 3.5 0 0 1 0 5'), ('p', 'M15.25 5.25a6.75 6.75 0 0 1 0 9.5')],
    'volume-mute': [('p', 'M3.5 7.75h2.75L10 4.5v11l-3.75-3.25H3.5z'), ('p', 'M13.5 8 17 11.5M17 8l-3.5 3.5')],
    'battery': [('r', 2.5, 6, 13, 8, 2.2), ('p', 'M17.75 8.75v2.5')],
    'sun': [('c', 10, 10, 3.25), ('p', 'M10 2.5v1.5M10 16v1.5M2.5 10H4M16 10h1.5M4.7 4.7l1.06 1.06M14.24 14.24l1.06 1.06M4.7 15.3l1.06-1.06M14.24 5.76l1.06-1.06')],
    'moon': [('p', 'M15.5 12.2A6.25 6.25 0 0 1 7.8 4.5a6.25 6.25 0 1 0 7.7 7.7z')],
    'sunset': [('p', 'M3 14.5h14M6.25 14.5a3.75 3.75 0 0 1 7.5 0M10 5.5V7.5M4.9 8.4l1.2 1.2M15.1 8.4l-1.2 1.2M6.5 17h7')],
    'chevron-right': [('p', 'M8 5l5 5-5 5')],
    'phone': [('r', 6, 2.75, 8, 14.5, 2), ('p', 'M9 14.75h2')],
    'bolt': [('p', 'M11 2.75 4.75 11h4.5L8.5 17.25 15.25 9h-4.5z')],
    'music': [('p', 'M7.5 14.5V4.75l9-1.75v9.75'), ('c', 5.75, 14.5, 1.75), ('c', 14.75, 12.75, 1.75)],
    'play': [('p', 'M7 4.75v10.5l8.25-5.25z', 'f')],
    'pause': [('r', 5.5, 4.5, 3, 11, 1, 'f'), ('r', 11.5, 4.5, 3, 11, 1, 'f')],
    'forward': [('p', 'M3.5 5.5v9l6-4.5zM10 5.5v9l6-4.5z', 'f')],
    'globe': [('c', 10, 10, 7.25), ('p', 'M2.75 10h14.5'), ('p', 'M10 2.75c2.2 2 3.25 4.4 3.25 7.25S12.2 15.25 10 17.25C7.8 15.25 6.75 12.85 6.75 10S7.8 4.75 10 2.75z')],
    'search': [('c', 8.75, 8.75, 5.25), ('p', 'M12.6 12.6 16.5 16.5')],
    'folder': [('p', 'M2.75 6.25a1.5 1.5 0 0 1 1.5-1.5h3.4l1.6 1.75h6.5a1.5 1.5 0 0 1 1.5 1.5v6.75a1.5 1.5 0 0 1-1.5 1.5H4.25a1.5 1.5 0 0 1-1.5-1.5z'), ('p', 'M2.75 8.75h14.5')],
    'doc': [('p', 'M5.25 2.75h6l3.5 3.5v11H5.25z'), ('p', 'M11.25 2.75v3.5h3.5M7.75 10.5h4.5M7.75 13.5h4.5')],
    'terminal': [('r', 2.75, 3.75, 14.5, 12.5, 2.25), ('p', 'M6 8l2.5 2L6 12M10.5 12.5h3.5')],
    'plus': [('p', 'M10 4.5v11M4.5 10h11')],
}


def element(e):
    fill = e[-1] == 'f'
    paint = 'fill="#000" stroke="none"' if fill else 'fill="none"'
    if e[0] == 'c':
        return f'<circle cx="{e[1]}" cy="{e[2]}" r="{e[3]}" {paint}/>'
    if e[0] == 'r':
        return f'<rect x="{e[1]}" y="{e[2]}" width="{e[3]}" height="{e[4]}" rx="{e[5]}" {paint}/>'
    return f'<path d="{e[1]}" {paint}/>'


def svg(name):
    body = ''.join(element(e) for e in GLYPHS[name])
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20" '
            'stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'
            f'{body}</svg>\n')


def main(out, names):
    os.makedirs(out, exist_ok=True)
    for name in names:
        with open(os.path.join(out, name + '.svg'), 'w', encoding='utf-8', newline='\n') as f:
            f.write(svg(name))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2:])
