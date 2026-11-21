#!/bin/bash
# SPDX-FileCopyrightText: 2026 Michal Kasík (MiPal)
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

if [[ $# -ne 1 || ! -f "$1" ]]; then
    printf 'Použití: bash tools/stage-rpm.sh /cesta/felis-probe-deps.tar.gz\n' >&2
    exit 2
fi

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
stage_dir=$(mktemp -d "$project_dir/build-felistermostat.XXXXXX")

# Copy only public source paths to the SDK work directory.
files=(
    src/main.cpp python/felis_thermostat.py python/felis_thermostat_protocol.py
    qml/harbour-felistermostat.qml qml/SettingsPage.qml qml/AboutPage.qml qml/StatusIcon.qml
    rpm/harbour-felistermostat.spec
    harbour-felistermostat.desktop harbour-felistermostat.pro LICENSE README.md THIRD_PARTY.md
    docs/Apache-2.0.txt docs/Native-Notices.txt
)
for size in 86 108 128 172; do
    files+=("icons/${size}x${size}/harbour-felistermostat.png")
done
for catalog in "$project_dir"/translations/harbour-felistermostat-*.ts; do
    files+=("translations/${catalog##*/}")
done
for source in "${files[@]}"; do
    install -D -m 0644 -- "$project_dir/$source" "$stage_dir/$source"
done
install -m 0644 -- "$1" "$stage_dir/vendor-site.tar.gz"
printf '%s\n' "$stage_dir"
