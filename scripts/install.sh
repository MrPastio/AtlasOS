#!/usr/bin/env bash
# Установка AtlasOS на чистый Bazzite одной командой:
#
#   curl -fsSL https://raw.githubusercontent.com/MrPastio/AtlasOS/main/scripts/install.sh | bash
#
# Шаг определяется по загруженному образу, поэтому скрипт сам продолжает работу после
# перезагрузок (открывается в Konsole при входе) и его можно запускать повторно:
#   1. Bazzite            → образ AtlasOS без проверки подписи (ключа Атласа ещё нет), перезагрузка
#   2. образ без подписи  → тот же образ с проверкой подписи, перезагрузка
#   3. подписанный образ  → вход в GitHub, проекты в ~/Projects, память и навыки Claude Code
#                           из приватного claude-memory, сам Claude Code
#
# Видеокарта определяется сама: NVIDIA → atlasos-nvidia, иначе atlasos.
set -euo pipefail

OWNER=MrPastio
REGISTRY=ghcr.io/mrpastio
RAW=https://raw.githubusercontent.com/$OWNER/AtlasOS/main/scripts/install.sh
SELF="$HOME/.local/bin/atlas-install"
AUTOSTART="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/atlas-install.desktop"
PROJECTS="$HOME/Projects"
MEMORY="$HOME/claude-memory"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# Закрывшаяся Konsole унесла бы с собой текст ошибки
pause_on_error() {
  local rc=$?
  [ "$rc" -eq 0 ] && return
  echo
  echo "Установка остановилась (код $rc). Запустить снова: $SELF"
  read -rp "Enter — закрыть окно. " _ || true
}

wait_network() {
  local i
  # Wi-Fi с паролем в KDE Wallet подключается уже после входа
  for i in {1..60}; do
    curl -fsS --max-time 5 -o /dev/null https://github.com && return
    sleep 3
  done
  echo "Нет интернета" >&2
  return 1
}

continue_after_login() {
  mkdir -p "$(dirname "$AUTOSTART")"
  cat > "$AUTOSTART" <<EOF
[Desktop Entry]
Type=Application
Name=Установка AtlasOS
Exec=konsole -e "$SELF"
Icon=system-software-install
X-KDE-autostart-phase=2
EOF
}

reboot_now() {
  say "Перезагрузка через 10 секунд (Ctrl+C — отменить). После входа установка продолжится сама."
  sleep 10
  systemctl reboot || sudo systemctl reboot
}

image_for_hardware() {
  if lspci -nn | grep -E '\[03(00|02|80)\]' | grep -qi '\[10de:'; then
    echo atlasos-nvidia
  else
    echo atlasos
  fi
}

rebase() {
  sudo rpm-ostree rebase "$1"
  continue_after_login
  reboot_now
}

fetch_repo() {
  if [ -d "$2/.git" ]; then
    git -C "$2" pull --ff-only -q || echo "$2: не обновлён, есть свои изменения"
  else
    gh repo clone "$1" "$2" -- -q
  fi
}

move_work() {
  say "Шаг 3 из 3: проекты и память Claude Code"
  wait_network
  gh auth status >/dev/null 2>&1 || gh auth login --hostname github.com --git-protocol https --web
  gh auth setup-git
  git config --global user.name >/dev/null \
    || git config --global user.name "$(gh api user --jq .login)"
  git config --global user.email >/dev/null \
    || git config --global user.email "$(gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"')"

  mkdir -p "$PROJECTS"
  fetch_repo "$OWNER/claude-memory" "$MEMORY"
  bash "$MEMORY/restore.sh" --global

  # Ключи архива — пути старой машины (E--Monarch), папка здесь — ~/Projects/Monarch.
  # Где на GitHub нет репозитория с таким именем, ляжет только память: код перенести вручную.
  local key name keys missing=()
  mapfile -t keys < <(bash "$MEMORY/restore.sh" --list)
  for key in "${keys[@]}"; do
    name=${key#*--}
    if gh repo view "$OWNER/$name" >/dev/null 2>&1; then
      fetch_repo "$OWNER/$name" "$PROJECTS/$name"
    else
      missing+=("$name")
    fi
    bash "$MEMORY/restore.sh" "$key" "$PROJECTS/$name"
  done

  [ -x "$HOME/.local/bin/claude" ] || curl -fsSL https://claude.ai/install.sh | bash

  rm -f "$AUTOSTART"
  say "Готово. Проекты: $PROJECTS. Claude Code: claude из папки проекта."
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "Только память, кода на GitHub нет: ${missing[*]}"
  fi
  read -rp "Enter — закрыть окно. " _ || true
}

main() {
  command -v rpm-ostree >/dev/null || { echo "Это не Bazzite: нет rpm-ostree" >&2; exit 1; }

  local booted image
  booted=$(rpm-ostree status --booted | sed -n 's/^● //p')
  case "$booted" in
    "ostree-image-signed:docker://$REGISTRY/atlasos"*)
      move_work ;;
    *"$REGISTRY/atlasos"*)
      image=${booted##*/}
      image=${image%%:*}
      say "Шаг 2 из 3: включаю проверку подписи ($image)"
      wait_network
      rebase "ostree-image-signed:docker://$REGISTRY/$image:latest" ;;
    *)
      image=$(image_for_hardware)
      say "Шаг 1 из 3: переключаюсь на $image (система: $booted)"
      wait_network
      rebase "ostree-unverified-registry:$REGISTRY/$image:latest" ;;
  esac
}

# Через curl | bash скрипт читается из stdin: сохранить себя и перезапуститься с терминалом.
# Всё тело — в функциях: оборванная загрузка не выполнится наполовину.
if [ "${BASH_SOURCE[0]:-}" != "$SELF" ]; then
  mkdir -p "$(dirname "$SELF")"
  if [ -f "${BASH_SOURCE[0]:-}" ]; then
    install -m 755 "${BASH_SOURCE[0]}" "$SELF"
  else
    curl -fsSL "$RAW" -o "$SELF"
    chmod 755 "$SELF"
  fi
  exec "$SELF" "$@" </dev/tty
fi

trap pause_on_error EXIT
main "$@"
