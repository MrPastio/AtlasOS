#!/usr/bin/env bash
# Сборка atlas-welcome в стадии образа: Qt той же версии, что в Bazzite.
set -euo pipefail
src="$(cd "$(dirname "$0")" && pwd)"
pin() { echo "$1-$(rpm -q --qf '%{VERSION}' "$2")"; }
dnf -y install --setopt=install_weak_deps=False cmake gcc-c++ \
    "$(pin qt6-qtbase-devel qt6-qtbase)" "$(pin qt6-qtdeclarative-devel qt6-qtdeclarative)"
cmake -S "$src" -B /tmp/atlas-welcome-build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build /tmp/atlas-welcome-build -j"$(nproc)"
DESTDIR=/out cmake --install /tmp/atlas-welcome-build
find /out -type f
