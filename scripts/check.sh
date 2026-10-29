#!/usr/bin/env bash
# Проверки внутри ВМ после загрузки образа AtlasOS. Запуск с хоста: scripts/vm.sh check
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }

booted=$(rpm-ostree status --booted | sed -n 's/^● //p')
[[ $booted == ostree-image-signed:docker://ghcr.io/mrpastio/atlasos* ]] \
  && ok "образ: $booted" || bad "загружен не подписанный atlasos: $booted"

[ -f /usr/share/atlasos/release ] \
  && ok "release: $(tr '\n' ' ' < /usr/share/atlasos/release)" || bad "нет /usr/share/atlasos/release"

grep -q mrpastio /etc/containers/policy.json && ok "политика подписи mrpastio" || bad "нет политики mrpastio"
[ -f /etc/pki/containers/atlasos.pub ] && ok "ключ atlasos.pub" || bad "нет ключа atlasos.pub"

failed=$(systemctl --failed --no-legend | wc -l)
[ "$failed" -eq 0 ] && ok "упавших служб нет" || { bad "упавших служб: $failed"; systemctl --failed --no-legend; }

state=$(systemctl is-system-running)
[ "$state" = running ] && ok "система: $state" || bad "система: $state"

exit $fail
