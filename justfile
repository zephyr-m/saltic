set shell := ["bash", "-uc"]
set positional-arguments
default:
    just --list

# папки для собранных инструментов: компилятор с полки пишет только в готовую папку
_dirs:
    mkdir -p .cache/build/workbench .cache/build/qemu_virt

playground:
    node os/ui/playground/server.mjs

compile file="soul/canonical/main.saltic" output="/tmp/saltic.elf":
    bootstrap/saltic "$1" "$2" 536870912 rv32i

run file="soul/canonical/main.saltic" output="/tmp/saltic.elf" *args:
    bootstrap/saltic "$1" "$2" 536870912 rv32i
    nix --extra-experimental-features "nix-command flakes" develop --command qemu-riscv32 -B 0x100000000 "$2" "${@:3}"

native file="soul/canonical/main.saltic" output="/tmp/saltic-native" *args:
    bootstrap/saltic "$1" "$2" 536870912 x86_64
    "$2" "${@:3}"

qemu file="os/target/qemu_virt/smoke.saltic":
    mkdir -p .cache/build/qemu_virt
    bootstrap/saltic "$1" .cache/build/qemu_virt/program.elf 536870912 rv32i

qemu-graphics: _dirs
    bootstrap/saltic os/target/qemu_virt/build-graphics.saltic .cache/build/workbench/build-graphics 536870912 x86_64 >/dev/null
    nix --extra-experimental-features "nix-command flakes" develop --command bash -c '.cache/build/workbench/build-graphics "" && qemu-system-riscv32 -machine virt -global virtio-mmio.force-legacy=false -device ramfb -device virtio-keyboard-device -device virtio-tablet-device -audiodev pipewire,id=saltic_audio -device virtio-sound-device,audiodev=saltic_audio -display gtk -serial stdio -monitor none -bios none -kernel .cache/build/qemu-graphics/program.elf'

os port="46321": _dirs
    bootstrap/saltic os/target/qemu_virt/build-graphics.saltic .cache/build/workbench/build-graphics 536870912 x86_64 >/dev/null
    nix --extra-experimental-features "nix-command flakes" develop --command .cache/build/workbench/build-graphics ""

os-send command port="46321":
    #!/usr/bin/env bash
    set -euo pipefail
    exec 3<>/dev/tcp/127.0.0.1/"$2"
    printf '%s\n' "$1" >&3
    if ! IFS= read -r -t 5 response <&3; then
        echo "Saltic не ответил за 5 секунд" >&2
        exit 1
    fi
    printf '%s\n' "$response"

qemu-graphics-check: _dirs
    bootstrap/saltic os/target/qemu_virt/build-graphics.saltic .cache/build/workbench/build-graphics 536870912 x86_64 >/dev/null
    nix --extra-experimental-features "nix-command flakes" develop --command .cache/build/workbench/build-graphics --check

bootstrap-refresh source="soul/seed/selfhost/toolchain.saltic": _dirs
    bootstrap/saltic bootstrap/refresh.saltic .cache/build/workbench/refresh 536870912 x86_64 >/dev/null
    .cache/build/workbench/refresh "$1"

global-check: _dirs
    bootstrap/saltic workbench/check/global-check.saltic .cache/build/workbench/global-check 536870912 x86_64 >/dev/null
    .cache/build/workbench/global-check

# Сервер MCP saltic_* для агента (.mcp.json): собирает lens и mcp с полки, потом
# говорит по stdio. Вывод сборки — в stderr: stdout принадлежит протоколу. Сборка —
# в .part и переименование: работающий сервер свой файл перезаписать не даст.
lens-serve: _dirs
    @bootstrap/saltic workbench/agent/lens.saltic .cache/build/workbench/lens.part 1073741824 x86_64 >&2 && mv .cache/build/workbench/lens.part .cache/build/workbench/lens
    @bootstrap/saltic workbench/agent/mcp.saltic .cache/build/workbench/mcp.part 268435456 x86_64 >&2 && mv .cache/build/workbench/mcp.part .cache/build/workbench/mcp
    @exec .cache/build/workbench/mcp

# Таблица лидеров по скорости: Saltic против языков, что есть на машине
# (docs/numbers/benchmarks), итог — .cache/build/workbench/bench.md.
bench: _dirs
    bootstrap/saltic workbench/bench.saltic .cache/build/workbench/bench-run 268435456 x86_64 >/dev/null
    .cache/build/workbench/bench-run

# Реестр адаптеров (registry/adapters/adapters.txt): паспорт, код через lens,
# эффекты и идентификаторы против кода; индекс — registry/adapters/index.json.
registry: _dirs
    bootstrap/saltic workbench/agent/lens.saltic .cache/build/workbench/lens.part 1073741824 x86_64 >/dev/null && mv .cache/build/workbench/lens.part .cache/build/workbench/lens
    bootstrap/saltic workbench/registry.saltic .cache/build/workbench/registry 268435456 x86_64 >/dev/null
    .cache/build/workbench/registry

# Поставить программу Saltic на ноут: бинарник в ~/.local/bin, иконка, визитка
# в меню приложений и ярлык на рабочем столе (workbench/install.saltic).
install name: _dirs
    bootstrap/saltic workbench/install.saltic .cache/build/workbench/install 268435456 x86_64 >/dev/null
    .cache/build/workbench/install "$1"

limits: _dirs
    bootstrap/saltic workbench/check/limits.saltic .cache/build/workbench/limits 536870912 x86_64
    .cache/build/workbench/limits

rv64: _dirs
    bootstrap/saltic bootstrap/refresh-qemu.saltic .cache/build/workbench/refresh-qemu 536870912 x86_64 >/dev/null
    .cache/build/workbench/refresh-qemu rv64 ""

arm64: _dirs
    bootstrap/saltic bootstrap/refresh-qemu.saltic .cache/build/workbench/refresh-qemu 536870912 x86_64 >/dev/null
    .cache/build/workbench/refresh-qemu arm64 ""

release-draft base="": _dirs
    bootstrap/saltic workbench/release-draft.saltic .cache/build/workbench/release-draft 536870912 x86_64 >/dev/null
    .cache/build/workbench/release-draft "$1"

same-source: _dirs
    bootstrap/saltic workbench/check/same-source.saltic .cache/build/workbench/same-source-check 536870912 x86_64 >/dev/null
    .cache/build/workbench/same-source-check

x86-golden mode="": _dirs
    bootstrap/saltic workbench/check/x86-encoder-golden.saltic .cache/build/workbench/x86-encoder-golden 536870912 x86_64 >/dev/null
    .cache/build/workbench/x86-encoder-golden "$1"

esp32: _dirs
    bootstrap/saltic os/target/esp32/toolchain.saltic .cache/build/workbench/esp32-toolchain 536870912 x86_64 >/dev/null
    bootstrap/saltic workbench/check/esp32.saltic .cache/build/workbench/esp32 536870912 x86_64 >/dev/null
    .cache/build/workbench/esp32

# Залить программу из os/target/esp32 на плату: `just esp32-flash` — куб,
# `just esp32-flash oled` — любая другая по имени файла
esp32-flash name="cube": _dirs
    bootstrap/saltic os/target/esp32/toolchain.saltic .cache/build/workbench/esp32-toolchain 536870912 x86_64 >/dev/null
    .cache/build/workbench/esp32-toolchain os/target/esp32/{{name}}.saltic .cache/build/workbench/esp32-{{name}}.bin 65536
    nix-shell -p esptool --run "esptool --chip esp32 --port /dev/ttyUSB0 --no-stub write-flash 0x1000 .cache/build/workbench/esp32-{{name}}.bin"

# APK для телефона: `just android` — os/target/android/hello.saltic, `just android
# имя` — другая программа оттуда. Ключ подписи — один раз в .cache/build/android
# (openssl, EC P-256), подпись и проверка — apksigner. Готовый APK —
# .cache/build/android/<имя>.apk: скинуть на телефон и поставить.
android name="hello": _dirs
    mkdir -p .cache/build/android
    bootstrap/saltic os/target/android/toolchain.saltic .cache/build/workbench/android-toolchain 1073741824 x86_64 >/dev/null
    .cache/build/workbench/android-toolchain os/target/android/{{name}}.saltic .cache/build/android/{{name}}-unsigned.apk 67108864
    test -f .cache/build/android/key.pk8 || (openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out .cache/build/android/key.pem && openssl pkcs8 -topk8 -nocrypt -outform DER -in .cache/build/android/key.pem -out .cache/build/android/key.pk8 && openssl req -new -x509 -key .cache/build/android/key.pem -days 10000 -subj "/CN=Saltic" -out .cache/build/android/cert.pem)
    nix-shell -p apksigner --run "apksigner sign --key .cache/build/android/key.pk8 --cert .cache/build/android/cert.pem --min-sdk-version 24 --out .cache/build/android/{{name}}.apk .cache/build/android/{{name}}-unsigned.apk && apksigner verify --verbose .cache/build/android/{{name}}.apk"

arm64-golden mode="": _dirs
    bootstrap/saltic workbench/check/arm64-encoder-golden.saltic .cache/build/workbench/arm64-encoder-golden 536870912 x86_64 >/dev/null
    .cache/build/workbench/arm64-encoder-golden "$1"

same *sources: _dirs
    bootstrap/saltic workbench/check/same.saltic .cache/build/workbench/same-check 536870912 x86_64 >/dev/null
    .cache/build/workbench/same-check "$*"

test case="all": _dirs
    bootstrap/saltic tests/run.saltic .cache/build/workbench/tests 536870912 x86_64 >/dev/null
    nix --extra-experimental-features "nix-command flakes" develop --command .cache/build/workbench/tests "$1"

package:
    bash .github/package.sh

clean:
    rm -rf -- .cache/build .cache/dist
