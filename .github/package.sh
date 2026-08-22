#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

version="$(tr -d '\r\n' < VERSION)"
dist="${SALTIC_DIST_DIR:-.cache/dist}"
archive="$dist/saltic-$version.tar.gz"
checksum="$archive.sha256"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "неверная версия Saltic: $version" >&2
    exit 1
fi

files=(
    CHANGELOG.md
    CristallOS.jpg
    LICENSE
    LICENSE.ru
    OS.md
    PRINCIPLES.md
    README.md
    VERSION
    flake.lock
    flake.nix
    justfile
    masscot.jpg
    .github
    .vscode
    editors
    os
    soul
    tests
)

for path in "${files[@]}"; do
    if [[ ! -e "$path" ]]; then
        echo "релизный файл не найден: $path" >&2
        exit 1
    fi
done

mkdir -p "$dist"
tar -czf "$archive" \
    --transform "s,^,saltic-$version/," \
    "${files[@]}"

hash="$(sha256sum "$archive" | awk '{ print $1 }')"
printf '%s  %s\n' "$hash" "$(basename "$archive")" >"$checksum"

echo "релизный пакет: $archive"
echo "контрольная сумма: $checksum"
