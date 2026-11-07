#!/usr/bin/env bash
source "$(dirname "$0")/../../../bootstrap/stamp.sh"
saltic_stamp_output "$0" "$@"
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root"

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    exec env -u LD_LIBRARY_PATH nix --extra-experimental-features "nix-command flakes" \
        develop "$root" --command bash "$root/os/target/uefi_x86_64/run.sh" "$@"
fi

image="${SALTIC_UEFI_DIR:-.cache/build/uefi_x86_64}/image"
test -f "$image/EFI/BOOT/BOOTX64.EFI" || { echo "uefi: сначала собери образ (os/target/uefi_x86_64/build.saltic)" >&2; exit 1; }
firmware="$(nix --extra-experimental-features "nix-command flakes" build --no-link --print-out-paths nixpkgs#OVMF.fd)/FV/OVMF.fd"
machine=(qemu-system-x86_64 -machine q35 -m 512M -bios "$firmware" -drive format=raw,file=fat:rw:"$image" -net none)

if [[ "${1:-}" != "--check" ]]; then
    exec env -u LD_LIBRARY_PATH "${machine[@]}"
fi

coproc QEMU { exec env -u LD_LIBRARY_PATH "${machine[@]}" -nographic -no-reboot 2>&1; }
deadline=$((SECONDS + 60))
seen=""
while (( SECONDS < deadline )) && IFS= read -r -t 30 line <&"${QEMU[0]}"; do
    case "$line" in
        *"Press any key."*) printf 'k' >&"${QEMU[1]}" ;;
        *"Pressed: k. Bye!"*) seen=yes; break ;;
    esac
done
kill "$QEMU_PID" 2>/dev/null || true
if [[ -z "$seen" ]]; then
    echo "uefi: образ не дошёл до «Pressed: k. Bye!» в QEMU+OVMF" >&2
    exit 1
fi
echo "uefi: образ грузится прошивкой, пишет на экран и читает клавишу"
