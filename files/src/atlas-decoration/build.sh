#!/usr/bin/env bash
# Сборка декорации в стадии образа: заголовки той же версии, что и KDecoration в Bazzite.
set -euo pipefail
src="$(cd "$(dirname "$0")" && pwd)"
pin() { echo "$1-$(rpm -q --qf '%{VERSION}' "$2")"; }
dnf -y install --setopt=install_weak_deps=False cmake gcc-c++ extra-cmake-modules \
    "$(pin kdecoration-devel kdecoration)" "$(pin qt6-qtbase-devel qt6-qtbase)" "$(pin kf6-kcoreaddons-devel kf6-kcoreaddons)"
cmake -S "$src" -B /tmp/atlas-decoration-build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build /tmp/atlas-decoration-build -j"$(nproc)"
DESTDIR=/out cmake --install /tmp/atlas-decoration-build
find /out -type f
