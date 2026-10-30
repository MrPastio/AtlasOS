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

```bash
curl -fsSL https://raw.githubusercontent.com/MrPastio/AtlasOS/main/scripts/install.sh | bash
```

Образ под видеокарту выбирается сам. Подробности — в [docs/INSTALL.md](docs/INSTALL.md).

Откат: при загрузке выбрать предыдущую запись в меню, либо `rpm-ostree rollback`.
