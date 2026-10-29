# Установка AtlasOS

Своего установочного образа пока нет: ставится официальный Bazzite, затем система
переключается (rebase) на образ AtlasOS. Файлы и настройки при переключении не трогаются,
прежняя версия остаётся в меню загрузки.

## Какой образ

| Видеокарта | Bazzite для установки | Образ AtlasOS |
| --- | --- | --- |
| NVIDIA RTX / GTX 16xx | Bazzite KDE, NVIDIA | `ghcr.io/mrpastio/atlasos-nvidia` |
| AMD / Intel | Bazzite KDE | `ghcr.io/mrpastio/atlasos` |

## Шаги

1. **Резервная копия.** Перед установкой рядом с Windows сохраните важное — разметка диска
   единственный шаг, где можно что-то потерять.
2. **Bazzite.** Скачайте ISO с bazzite.gg (KDE, нужный вариант видеокарты), запишите на флешку,
   установите. Рядом с Windows — выберите свободное место на диске, а не весь диск.
   Secure Boot: при первом запуске Bazzite попросит подтвердить свой ключ (MOK) — пароль
   `universalblue`.
3. **Переключение на AtlasOS.** Bazzite ещё не знает ключа подписи Атласа, поэтому первый раз
   без проверки подписи, второй — уже с ней (ключ приезжает вместе с образом):

   ```bash
   rpm-ostree rebase ostree-unverified-registry:ghcr.io/mrpastio/atlasos-nvidia:latest
   systemctl reboot
   ```

   ```bash
   rpm-ostree rebase ostree-image-signed:docker://ghcr.io/mrpastio/atlasos-nvidia:latest
   systemctl reboot
   ```

   Для AMD/Intel — то же с `atlasos` вместо `atlasos-nvidia`.
4. **Первый вход.** Откроется «Добро пожаловать»: оформление и приложения (Claude, Discord,
   Telegram, OBS…). Окно можно открыть снова из Компаса.

## Дальше

- Обновления ставятся сами раз в день; вручную и откат — «Обновление системы» в Компасе.
- Claude Desktop живёт в контейнере distrobox `claude` (официальная сборка только для Ubuntu/Debian):
  `atlas-claude install | update | status`.
- Если Claude показывает чёрное окно — он ждёт KDE Wallet: введите пароль в его запросе.

## Перенести работу

Код — на GitHub, память Claude Code — в приватном репозитории `claude-memory`
(в нём `restore.sh`: память кладётся под ключ нового пути проекта).

```bash
gh auth login
mkdir -p ~/Projects && cd ~/Projects
gh repo clone MrPastio/AtlasOS
gh repo clone MrPastio/claude-memory ~/claude-memory
~/claude-memory/restore.sh --global
~/claude-memory/restore.sh E--AtlasOS ~/Projects/AtlasOS
curl -fsSL https://claude.ai/install.sh | bash
```

Остальные проекты — так же: `gh repo clone …`, затем `restore.sh <ключ> <папка>`
(`restore.sh --list` покажет ключи). Claude Code запускается командой `claude` из папки проекта.
