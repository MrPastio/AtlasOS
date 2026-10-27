import json, sys, os
src, out = sys.argv[1], sys.argv[2]
T = {t['name']: t['value'] for t in json.load(open(src, encoding='utf-8'))['color']['tokens']}
def hx(s):
    s = s.lstrip('#'); a = int(s[6:8], 16) / 255 if len(s) == 8 else 1.0
    return [int(s[i:i+2], 16) for i in (0, 2, 4)], a
def get(name, th):
    v = T[name][th] if isinstance(T[name], dict) else T[name]
    if v.startswith('{'): return get(v[1:-1], th)
    return v
def c(name, th, base=None):
    rgb, a = hx(get(name, th))
    if a < 1:
        b, _ = hx(get(base, th))
        rgb = [round(x * a + y * (1 - a)) for x, y in zip(rgb, b)]
    return ','.join(map(str, rgb))
def scheme(th, title, sid):
    fg = lambda bg: dict(
        ForegroundNormal=c('ink', th), ForegroundInactive=c('ink-secondary', th),
        ForegroundActive=c('accent-ink', th), ForegroundLink=c('accent-ink', th),
        ForegroundVisited=c('accent-ink', th), ForegroundNegative=c('danger-ink', th),
        ForegroundNeutral=c('warning-ink', th), ForegroundPositive=c('success-ink', th),
        DecorationFocus=c('focus', th), DecorationHover=c('accent', th))
    g = {}
    g['Colors:Window'] = dict(BackgroundNormal=c('bg-window', th), BackgroundAlternate=c('bg-sunken', th), **fg(0))
    g['Colors:View'] = dict(BackgroundNormal=c('bg-canvas', th), BackgroundAlternate=c('fill-hover', th, 'bg-canvas'), **fg(0))
    g['Colors:Button'] = dict(BackgroundNormal=c('control', th, 'bg-window'), BackgroundAlternate=c('control-off', th, 'bg-window'), **fg(0))
    g['Colors:Header'] = dict(BackgroundNormal=c('bg-window', th), BackgroundAlternate=c('bg-sunken', th), **fg(0))
    g['Colors:Header][Inactive'] = dict(g['Colors:Header'], ForegroundNormal=c('ink-secondary', th))
    g['Colors:Tooltip'] = dict(BackgroundNormal=c('bg-elevated', th), BackgroundAlternate=c('bg-raised', th), **fg(0))
    sel = dict(fg(0), ForegroundNormal=c('on-accent', th), ForegroundInactive=c('on-accent', th), ForegroundActive=c('on-accent', th),
               ForegroundLink=c('on-accent', th), ForegroundVisited=c('on-accent', th))
    g['Colors:Selection'] = dict(sel, BackgroundNormal=c('accent', th), BackgroundAlternate=c('accent-hover', th))
    d = 'dark'  # Complementary = тёмные служебные слои (экран блокировки, OSD Breeze) в обеих темах
    g['Colors:Complementary'] = dict(BackgroundNormal=c('bg-window', d), BackgroundAlternate=c('bg-sunken', d), **{k: v for k, v in scheme_fg(d).items()})
    g['WM'] = dict(activeBackground=c('bg-window', th), activeForeground=c('ink', th), activeBlend=c('ink', th),
                   inactiveBackground=c('bg-window', th), inactiveForeground=c('ink-tertiary', th), inactiveBlend=c('ink-tertiary', th))
    lines = ['# Сгенерировано из tokens.json дизайн-системы «Атлас» (tools/gen_colors.py).',
             '[ColorEffects:Disabled]', 'Color=%s' % c('bg-window', th), 'ColorAmount=0', 'ColorEffect=0',
             'ContrastAmount=0.65', 'ContrastEffect=1', 'IntensityAmount=0.1', 'IntensityEffect=2', '',
             '[ColorEffects:Inactive]', 'ChangeSelectionColor=true', 'Color=%s' % c('bg-window', th), 'ColorAmount=0.025',
             'ColorEffect=2', 'ContrastAmount=0.1', 'ContrastEffect=2', 'Enable=false', 'IntensityAmount=0', 'IntensityEffect=0', '']
    for k, v in g.items():
        lines.append('[%s]' % k); lines += ['%s=%s' % kv for kv in sorted(v.items())]; lines.append('')
    lines += ['[General]', 'ColorScheme=%s' % sid, 'Name=%s' % title, 'shadeSortColumn=true', '', '[KDE]', 'contrast=4', '']
    open(os.path.join(out, sid + '.colors'), 'w', encoding='utf-8', newline='\n').write('\n'.join(lines))
def scheme_fg(th):
    return dict(ForegroundNormal=c('ink', th), ForegroundInactive=c('ink-secondary', th), ForegroundActive=c('accent-ink', th),
                ForegroundLink=c('accent-ink', th), ForegroundVisited=c('accent-ink', th), ForegroundNegative=c('danger-ink', th),
                ForegroundNeutral=c('warning-ink', th), ForegroundPositive=c('success-ink', th),
                DecorationFocus=c('focus', th), DecorationHover=c('accent', th))
os.makedirs(out, exist_ok=True)
scheme('light', 'Atlas Light', 'AtlasLight'); scheme('dark', 'Atlas Dark', 'AtlasDark')
