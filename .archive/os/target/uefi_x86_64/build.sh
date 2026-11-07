#!/usr/bin/env bash
source "$(dirname "$0")/../../../bootstrap/stamp.sh"
saltic_stamp_output "$0" "$@"
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root"

source="${1:-os/target/uefi_x86_64/programs/hello.saltic}"
work="${SALTIC_UEFI_DIR:-.cache/build/uefi_x86_64}"
image="$work/image"
mkdir -p "$image/EFI/BOOT"

echo "uefi: собираю $source"
SALTIC_TARGET="${SALTIC_TARGET:-x86_64-uefi}" SALTIC_BUILD_DIR="$work/build" SALTIC_HEAP_BYTES=67108864 \
    bash bootstrap/build.sh "$source" "$image/EFI/BOOT/BOOTX64.EFI"
echo "uefi: образ флешки — $image (скопируй его содержимое на FAT32-флешку)"
