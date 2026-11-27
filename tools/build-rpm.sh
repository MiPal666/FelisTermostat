#!/bin/bash
# SPDX-FileCopyrightText: 2026 Michal Kasík (MiPal)
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
    printf 'Použití: bash tools/build-rpm.sh /cesta/felis-probe-deps.tar.gz [sdk-cíl]\n' >&2
    exit 2
fi

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
target=${2:-SailfishOS-5.1.0.11-aarch64.default}
stage_dir=$(bash "$project_dir/tools/stage-rpm.sh" "$1")
(cd -- "$stage_dir" && sfdk -c "target=$target" -c no-fix-version build)

shopt -s globstar nullglob
packages=("$stage_dir"/RPMS/**/*.aarch64.rpm)
if [[ ${#packages[@]} -eq 0 ]]; then
    printf 'SDK nevytvořilo žádný aarch64 RPM v %s/RPMS.\n' "$stage_dir" >&2
    exit 1
fi

output_dir="$project_dir/RPMS"
mkdir -p -- "$output_dir"
temporary=
trap 'if [[ -n "$temporary" ]]; then rm -f -- "$temporary"; fi' EXIT
for package in "${packages[@]}"; do
    destination="$output_dir/${package##*/}"
    temporary=$(mktemp "$output_dir/.felistermostat-rpm.XXXXXX")
    install -m 0644 -- "$package" "$temporary"
    mv -fT -- "$temporary" "$destination"
    temporary=
    printf '%s\n' "$destination"
done
