# Разработка AtlasOS

## Что где
- Репозиторий: `E:\AtlasOS` (клон `github.com/MrPastio/AtlasOS`).
- Тестовая ВМ: VirtualBox `AtlasOS-Test`, файлы в `E:\AtlasOS-VM\`. VBoxManage: `E:\New Folder\VBoxManage.exe`.
- Вход в ВМ: пользователь `atlas`, пароль в `E:\AtlasOS-VM\test-credentials.txt`. С хоста: `ssh atlasvm` (ключ `~/.ssh/atlasos_vm`, порт 2222). Sudo в ВМ без пароля (`/etc/sudoers.d/90-atlas-test`) — только для тестовой ВМ.
- Снапшот `atlasos-stage1-signed`: чистая ВМ на подписанном `atlasos:latest` (этап 1).

## Как собирается образ
- `.github/workflows/build.yml` (BlueBuild) собирает `recipe.yml` → `ghcr.io/mrpastio/atlasos` и `recipe-nvidia.yml` → `atlasos-nvidia` на каждый push, PR, раз в день и по кнопке. Сборка ~4–5 минут.
- Теги: `latest` и дата — с `main`; `br-<ветка>-44` — с ветки (`/` заменяется на `_`); `pr-<N>-44` — с PR.
- Все сборки подписаны cosign (секрет `SIGNING_SECRET`, публичный ключ `cosign.pub`), поэтому ВМ ставит их через `ostree-image-signed`.
- Локально на Windows образ не собирается: только CI.

## Как собирается ISO
- `.github/workflows/build-iso.yml` собирает `atlasos-live-amd64.iso` и `atlasos-nvidia-live-amd64.iso` из опубликованных `:latest`, поэтому правки образа попадают в ISO только после слияния в main.
- Запуск: `gh workflow run iso` или push в ветку с изменениями в `installer/`. ISO лежит в артефактах запуска 7 дней: `gh run download <id> -n atlasos-nvidia-iso -D <папка>`.
- `installer/` — установщик Bazzite (Titanoboa + Anaconda) из `ublue-os/bazzite` с правками под Атлас. Живая среда всегда на `atlasos`, образ на диск задаёт `INSTALL_IMAGE_PAYLOAD`.
- Профиль Anaconda совпадает по `ID=bazzite`, поэтому в живой среде меняются только `NAME` и `PRETTY_NAME`.

## Цикл работы
1. **Быстро, без сборки** — для файлов из `files/system`: правка → `scripts/vm.sh sync` → смотреть в ВМ.
   `/usr` в ВМ становится временно записываемым и сбрасывается при перезагрузке; `/etc` пишется насовсем (откат — `scripts/vm.sh reset`).
   Настройки KDE удобно сначала подобрать руками в ВМ, потом перенести в `files/system`.
2. **Настоящий образ** — для пакетов, модулей рецепта и всего, что сборка меняет в `/usr`:
   ветка → push → дождаться CI (`gh run watch`) → `scripts/vm.sh try <ветка>` → `scripts/vm.sh check`.
3. **После слияния в main**: `scripts/vm.sh main` (или `upgrade`, если ВМ уже на `latest`).
4. Если ВМ сломалась: `scripts/vm.sh reset && scripts/vm.sh start`.

## Хост (Windows)
Чтобы VirtualBox работал быстро (AMD-V, а не через Hyper-V), на хосте выключены:
`bcdedit hypervisorlaunchtype off`, `DeviceGuard\EnableVirtualizationBasedSecurity=0`,
`DeviceGuard\Scenarios\WindowsHello\Enabled=0`. Пока так, не работают WSL2/Docker/Sandbox.
Вернуть: `bcdedit /set hypervisorlaunchtype auto`, оба ключа реестра в `1`, перезагрузка.

## Грабли
- Живой снапшот ВМ (`snapshot take --live`) с 8 ГБ ОЗУ зависает: снапшоты делать только на выключенной ВМ.
- В госте нет Guest Additions — управление только по SSH (или `VBoxManage controlvm … keyboardputstring`).
