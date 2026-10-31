#!/usr/bin/env bash
source "$(dirname "$0")/../../../bootstrap/stamp.sh"
saltic_stamp_output "$0" "$@"
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root"

image="${SALTIC_UEFI_DIR:-.cache/build/uefi_x86_64}/image"
test -f "$image/EFI/BOOT/BOOTX64.EFI" || { echo "uefi: сначала bash os/target/uefi_x86_64/build.sh" >&2; exit 1; }
firmware="$(nix --extra-experimental-features "nix-command flakes" build --no-link --print-out-paths nixpkgs#OVMF.fd)/FV/OVMF.fd"
nix --extra-experimental-features "nix-command flakes" develop --command \
    qemu-system-x86_64 -machine q35 -m 512M -bios "$firmware" \
    -drive format=raw,file=fat:rw:"$image" -net none
