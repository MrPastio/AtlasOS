#!/usr/bin/bash
# Проверки перед установкой в живой сессии ISO и окно с кнопкой «Установить».
# Заменяет on_gui_login.sh из Bazzite: он сверяет видеокарту по именам образов Bazzite.

warn() { yad --image=dialog-warning --button=Понятно:0 --buttons-layout=center --title="$1" --text="$2"; }

power_off() {
    yad --undecorated --on-top --timeout=0 --button=Выключить:0 --text="$1" || true
    systemctl poweroff
}

check_uefi() {
    [[ -d /sys/firmware/efi ]] || power_off "AtlasOS не поддерживает загрузку CSM/Legacy.
Включите UEFI в настройках BIOS и перезагрузитесь."
}

check_memory() {
    local kb
    kb=$(awk '/^MemTotal/{print $2}' /proc/meminfo)
    [[ $kb -ge 5000000 ]] || power_off "Для установки нужно хотя бы <b>8 ГБ</b> оперативной памяти.
Сейчас: $((kb / 1024)) МБ."
}

check_gpu() {
    local image nvidia=0
    image=$(cat /usr/share/atlasos/live-image)
    lspci -nn | grep -E '\[03(00|02|80)\]' | grep -qi '\[10de:' && nvidia=1
    if [[ $nvidia == 1 && $image != *-nvidia* ]]; then
        warn "Другой образ" "В компьютере видеокарта NVIDIA, а этот ISO — для AMD/Intel.
Нужен ISO <b>atlasos-nvidia</b>."
    elif [[ $nvidia == 0 && $image == *-nvidia* ]]; then
        warn "Другой образ" "Видеокарты NVIDIA нет, а этот ISO — для NVIDIA.
Нужен ISO <b>atlasos</b>."
    fi
}

# Чужой GRUB в EFI-разделе ломает установку на этапе grub2-mkconfig
check_esp() {
    local dev found
    for dev in $(lsblk -o PATH -nQ 'PARTTYPE=="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"' 2>/dev/null); do
        found=$(sudo unshare -m sh -c "
            mount -o ro '$dev' /mnt 2>/dev/null || exit 0
            find /mnt/EFI -mindepth 2 -maxdepth 2 -iname 'grub*.efi' 2>/dev/null \
                | grep -iv -e '/EFI/fedora/' -e '/EFI/BOOT/'
        ") || true
        [[ -n $found ]] || continue
        warn "Найден чужой загрузчик" "В EFI-разделе <b>$dev</b> есть GRUB другого Linux:
$found

Установка в этот раздел не сработает. Создайте для AtlasOS <b>новый</b> EFI-раздел
(1 ГБ, /boot/efi) или ставьте на другой диск. Загрузчик Windows при этом не меняется."
    done
}

welcome() {
    yad --no-escape --on-top --text-align=center --buttons-layout=center --title="AtlasOS" \
        --text="<big>Добро пожаловать в AtlasOS</big>

Это среда для установки: драйверов и игр здесь нет,
настоящая система будет быстрее." \
        --button="Установить AtlasOS:10" \
        --button="Восстановить загрузчик:20" \
        --button="Закрыть:0"
    case $? in
    10) liveinst & disown ;;
    20) /usr/bin/bootloader_restore & disown ;;
    esac
}

check_uefi
check_memory
check_gpu
check_esp
welcome
