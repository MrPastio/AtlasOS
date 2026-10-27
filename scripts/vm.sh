#!/usr/bin/env bash
# Управление тестовой ВМ AtlasOS-Test с хоста (Git Bash на Windows).
# Нужен ssh-алиас `atlasvm` в ~/.ssh/config (127.0.0.1:2222, пользователь atlas).
#
#   scripts/vm.sh status            — какой образ загружен
#   scripts/vm.sh check             — проверки после загрузки (scripts/check.sh в ВМ)
#   scripts/vm.sh sync              — залить files/system в ВМ без сборки (до перезагрузки)
#   scripts/vm.sh try <ветка>       — переключить ВМ на сборку ветки из CI и перезагрузить
#   scripts/vm.sh main              — вернуть ВМ на :latest и перезагрузить
#   scripts/vm.sh upgrade           — подтянуть свежий образ текущего тега и перезагрузить
#   scripts/vm.sh reset             — откатить ВМ к снапшоту atlasos-stage1-signed
#   scripts/vm.sh start | stop | reboot | shot [файл.png]
set -euo pipefail

VM=AtlasOS-Test
IMAGE=ghcr.io/mrpastio/atlasos
SNAPSHOT=atlasos-stage1-signed
FEDORA=44
VBM="${VBM:-/e/New Folder/VBoxManage.exe}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

vm_ssh() { ssh -o ConnectTimeout=5 atlasvm "$@"; }

wait_ssh() {
  local t0=$SECONDS
  sleep 10
  until ssh -o ConnectTimeout=5 -o BatchMode=yes atlasvm true 2>/dev/null; do
    if (( SECONDS - t0 > 300 )); then echo "ВМ не вернулась за 5 минут" >&2; exit 1; fi
    sleep 5
  done
  echo "ВМ доступна через $((SECONDS - t0)) с"
}

reboot_vm() { vm_ssh 'sudo -n systemctl reboot' || true; wait_ssh; }

rebase_to() {
  vm_ssh "sudo -n rpm-ostree rebase ostree-image-signed:docker://$IMAGE:$1"
  reboot_vm
  vm_ssh 'rpm-ostree status --booted | sed -n 3,5p'
}

case "${1:-}" in
  status)  vm_ssh 'rpm-ostree status | head -12' ;;
  check)   vm_ssh 'bash -s' < "$ROOT/scripts/check.sh" ;;
  sync)
    # /usr в ostree только для чтения: usroverlay даёт временный слой до перезагрузки.
    # Файлы из files/system/etc пишутся прямо в /etc ВМ и переживают перезагрузку.
    vm_ssh 'sudo -n rpm-ostree usroverlay 2>/dev/null || true'
    tar -C "$ROOT/files/system" -cf - . | vm_ssh 'sudo -n tar -C / --no-same-owner --no-overwrite-dir -xf -'
    echo "files/system залит в ВМ" ;;
  try)
    branch="${2:?укажи ветку}"
    rebase_to "br-${branch//\//_}-$FEDORA" ;;
  main)    rebase_to latest ;;
  upgrade) vm_ssh 'sudo -n rpm-ostree upgrade'; reboot_vm ;;
  reboot)  reboot_vm ;;
  start)   "$VBM" startvm "$VM" --type gui; wait_ssh ;;
  stop)    vm_ssh 'sudo -n systemctl poweroff' || true ;;
  reset)
    "$VBM" controlvm "$VM" poweroff 2>/dev/null || true
    sleep 3
    "$VBM" snapshot "$VM" restore "$SNAPSHOT"
    echo "ВМ откачена к снапшоту $SNAPSHOT (запусти: scripts/vm.sh start)" ;;
  shot)    "$VBM" controlvm "$VM" screenshotpng "$(cygpath -w "${2:-$PWD/vm.png}")" && echo "${2:-vm.png}" ;;
  *)       sed -n '2,15p' "$0"; exit 1 ;;
esac
