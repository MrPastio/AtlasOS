#!/usr/bin/env bash
# Темы значков «Атлас» и «Атлас тёмная».
# Значки приложений, типов файлов и категорий — из Papirus (полный охват, одна манера),
# папки — Papirus, перекрашенные в «Меридиан» двумя тонами одного цвета (07-iconography),
# остальное (действия, статусы, устройства, символы панели) — из Breeze: они следуют
# цветовой схеме, поэтому сами светлеют и темнеют вместе с темой.
#
# Каталоги Breeze кладутся в тему, а не только в Inherits: не найдя имя в теме,
# KIconLoader урезает его (go-previous → go) и находил бы чужой значок из Papirus.
set -euo pipefail

P=/usr/share/icons/Papirus
PAPIRUS_CONTEXTS='Applications|MimeTypes|Categories|Places'

# Цвета папки: лицевая часть, задник, символ на папке, бумага внутри.
FRONT='#14918a' BACK='#0e7a74' GLYPH='#063e3a' PAPER='#f6f5f2'

dirs=() sections=''

# take <тема-источник> <префикс в нашей теме> <grep -E по Context> <-v или пусто>
take() {
  local src=/usr/share/icons/$1 pre=$2 re=$3 inv=$4 d ctx sec
  for d in $(sed -n 's/^\(Scaled\)\{0,1\}Directories=//p' "$src/index.theme" | tr ',' ' '); do
    [ -d "$src/$d" ] || continue
    sec=$(awk -v d="[$d]" '$0==d{p=1;next} /^\[/{p=0} p&&NF' "$src/index.theme")
    ctx=$(sed -n 's/^Context=//p' <<<"$sec")
    grep -qE $inv "^($re)$" <<<"$ctx" || continue
    mkdir -p "$T/$pre$(dirname "$d")"
    if [ "$ctx" = Places ]; then
      cp -a "$src/$d" "$T/$pre$d" # копия: здесь перекрашиваем папки
    else
      ln -s "$src/$d" "$T/$pre$d"
    fi
    dirs+=("$pre$d")
    sections+="[$pre$d]"$'\n'"$sec"$'\n\n'
  done
}

build() {
  local name=$1 dir=$2 breeze=$3
  T=/usr/share/icons/$dir dirs=() sections=''
  mkdir -p "$T"
  take Papirus p/ "$PAPIRUS_CONTEXTS" ''
  take "$breeze" b/ "$PAPIRUS_CONTEXTS" -v

  # Как papirus-folders: ссылки на *-blue* (folder-blue, user-blue-home…) переводим на *-teal*,
  # затем перекрашиваем teal-файлы в «Меридиан».
  find "$T/p" -path '*/places/*' -type l -lname '*-blue*' | while read -r l; do
    local t nt; t=$(readlink "$l"); nt=${t/-blue/-teal}
    [ -e "$(dirname "$l")/$nt" ] && ln -sfn "$nt" "$l"
  done
  find "$T/p" -path '*/places/*' -type f -name '*-teal*' -exec sed -i \
    -e "s/#16a085/$FRONT/Ig" -e "s/#12806a/$BACK/Ig" -e "s/#08382e/$GLYPH/Ig" -e "s/#e4e4e4/$PAPER/Ig" {} +

  {
    echo "[Icon Theme]"
    echo "Name=$name"
    echo "Comment=AtlasOS: Papirus apps and Meridian folders, Breeze symbols"
    echo "Inherits=$breeze,hicolor"
    echo "Example=folder"
    echo "FollowsColorScheme=true"
    sed -n '/^DesktopDefault=/,/^DialogSizes=/p' "$P/index.theme"
    echo "Directories=$(IFS=,; echo "${dirs[*]}")"
    echo
    printf '%s' "$sections"
  } > "$T/index.theme"
  gtk-update-icon-cache -f -q "$T" || true
}

build "Атлас" Atlas breeze
build "Атлас тёмная" Atlas-Dark breeze-dark
