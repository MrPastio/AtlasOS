# AtlasOS

Собственная система в духе macOS поверх **Bazzite KDE** (Plasma 6), собираемая через [BlueBuild](https://blue-build.org).
«AtlasOS» — рабочее имя проекта, финальное название выберем позже.

## Как это устроено

- `recipes/common.yml` — всё, что входит в систему (общая часть для всех видеокарт).
- `recipes/recipe.yml` — образ `atlasos` для AMD / Intel и для виртуалки.
- `recipes/recipe-nvidia.yml` — образ `atlasos-nvidia` для NVIDIA (тип драйвера меняется одной строкой `base-image`).
- `files/system/` — файлы, которые кладутся в систему как есть.
- GitHub Actions собирает оба образа каждый день и после каждого изменения и публикует их в `ghcr.io/<владелец>/`.

## Перейти на свой образ (с установленного Bazzite)

AMD / Intel / виртуалка:

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/mrpastio/atlasos:latest
systemctl reboot
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/mrpastio/atlasos:latest
systemctl reboot
```

NVIDIA: то же самое, но `atlasos-nvidia` вместо `atlasos`.

Откат: при загрузке выбрать предыдущую запись в меню, либо `rpm-ostree rollback`.
