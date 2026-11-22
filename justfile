set shell := ["bash", "-uc"]
set positional-arguments
default:
    just --list

# папки для собранных инструментов: компилятор с полки пишет только в готовую папку
_dirs:
    mkdir -p .cache/build/workbench .cache/build/qemu_virt

compile file="soul/canonical/main.saltic" output="/tmp/saltic.elf": (tarantul "get")
    bootstrap/saltic "$1" "$2" 536870912 rv32i

run file="soul/canonical/main.saltic" output="/tmp/saltic.elf" *args: (tarantul "get")
    bootstrap/saltic "$1" "$2" 536870912 rv32i
    nix --extra-experimental-features "nix-command flakes" develop --command qemu-riscv32 -B 0x100000000 "$2" "${@:3}"

native file="soul/canonical/main.saltic" output="/tmp/saltic-native" *args: (tarantul "get")
    bootstrap/saltic "$1" "$2" 536870912 x86_64
    "$2" "${@:3}"

qemu file="soul/toolchains/qemu_virt/checks/smoke.saltic": (tarantul "get")
    mkdir -p .cache/build/qemu_virt
    bootstrap/saltic "$1" .cache/build/qemu_virt/program.elf 536870912 rv32i

bootstrap-refresh source="soul/toolchains/saltic/main.saltic": _dirs
    bootstrap/saltic bootstrap/refresh.saltic .cache/build/workbench/refresh 536870912 x86_64
    .cache/build/workbench/refresh "$1"

global-check: _dirs (tarantul "get")
    bootstrap/saltic workbench/check/global-check.saltic .cache/build/workbench/global-check 536870912 x86_64
    .cache/build/workbench/global-check

# Чужие хосты под QEMU — тесты rv32i, rv64, arm64, платформы, самосборка RV64 и
# ARM64 — та же проверка, только эти ветки; гонять перед релизом.
hosts: _dirs (tarantul "get")
    bootstrap/saltic workbench/check/global-check.saltic .cache/build/workbench/global-check 536870912 x86_64
    SALTIC_FOREIGN=1 .cache/build/workbench/global-check

# Сервер MCP saltic_* для агента (.mcp.json): собирает lens и mcp с полки, потом
# говорит по stdio. Вывод сборки — в stderr: stdout принадлежит протоколу. Сборка —
# в .part и переименование: работающий сервер свой файл перезаписать не даст.
lens-serve: _dirs
    @bootstrap/saltic workbench/agent/lens/main.saltic .cache/build/workbench/lens.part 1073741824 x86_64 >&2 && mv .cache/build/workbench/lens.part .cache/build/workbench/lens
    @bootstrap/saltic workbench/agent/mcp/main.saltic .cache/build/workbench/mcp.part 268435456 x86_64 >&2 && mv .cache/build/workbench/mcp.part .cache/build/workbench/mcp
    @exec .cache/build/workbench/mcp

# Таблица лидеров по скорости: Saltic против языков, что есть на машине
# (docs/numbers/benchmarks), итог — .cache/build/workbench/bench.md.
bench: _dirs
    bootstrap/saltic workbench/bench.saltic .cache/build/workbench/bench-run 268435456 x86_64
    .cache/build/workbench/bench-run

# Реестр адаптеров (registry/adapters/adapters.txt): паспорт, код через lens,
# эффекты и идентификаторы против кода; индекс — registry/adapters/index.json.
# Реестр — свой репозиторий (git@github.com:zephyr-m/saltic-registry.git):
# сверяется его рабочая копия, по умолчанию ../saltic-registry.
registry folder="../saltic-registry": _dirs
    bootstrap/saltic workbench/agent/lens/main.saltic .cache/build/workbench/lens.part 1073741824 x86_64  && mv .cache/build/workbench/lens.part .cache/build/workbench/lens
    bootstrap/saltic workbench/registry.saltic .cache/build/workbench/registry 268435456 x86_64
    cd "$1" && SALTIC_HOME="{{justfile_directory()}}" "{{justfile_directory()}}/.cache/build/workbench/registry"

pace: _dirs
    bootstrap/saltic workbench/check/pace.saltic .cache/build/workbench/pace 536870912 x86_64
    .cache/build/workbench/pace

limits: _dirs
    bootstrap/saltic workbench/check/limits/main.saltic .cache/build/workbench/limits 536870912 x86_64
    .cache/build/workbench/limits

# Быстрая проверка на родном x86-64 (global-check — редко): лимиты канона, случаи
# языка без машинных эталонов и чужих процессоров (links, rva23, rv64, arm64,
# machine — в just hosts) и весь набор ОС. Тестовые программы — x86-64 на этом ноутбуке.
quick: _dirs (tarantul "get")
    bootstrap/saltic workbench/check/limits/main.saltic .cache/build/workbench/limits 536870912 x86_64
    .cache/build/workbench/limits
    bootstrap/saltic tests/run/main.saltic .cache/build/workbench/tests 536870912 x86_64
    SALTIC_TEST_HOST=x86_64 nix --extra-experimental-features "nix-command flakes" develop --command .cache/build/workbench/tests "checker fixed-types fraction wide modules json-rpc diagnostics groups bytes edges always x86-encoder arm64-encoder xtensa-encoder dict crypto apk seed-contract abi memory platform process native jtml ttf events mrpc"

rv64: _dirs
    bootstrap/saltic bootstrap/refresh-qemu.saltic .cache/build/workbench/refresh-qemu 536870912 x86_64
    .cache/build/workbench/refresh-qemu rv64 ""

arm64: _dirs
    bootstrap/saltic bootstrap/refresh-qemu.saltic .cache/build/workbench/refresh-qemu 536870912 x86_64
    .cache/build/workbench/refresh-qemu arm64 ""

release-draft base="": _dirs
    bootstrap/saltic workbench/release-draft.saltic .cache/build/workbench/release-draft 536870912 x86_64
    .cache/build/workbench/release-draft "$1"

same-source: _dirs (tarantul "get")
    bootstrap/saltic workbench/check/same-source.saltic .cache/build/workbench/same-source-check 536870912 x86_64
    .cache/build/workbench/same-source-check

x86-golden mode="": _dirs
    bootstrap/saltic workbench/check/x86-encoder-golden.saltic .cache/build/workbench/x86-encoder-golden 536870912 x86_64
    .cache/build/workbench/x86-encoder-golden "$1"

# Пакеты проекта (tarantul.json, замок tarantul.lock) в tarantul/: `just tarantul` — привезти,
# `just tarantul update` — версии каталога, `just tarantul list` — что есть,
# `just tarantul check` — всё ли на месте
tarantul command="get": _dirs
    bootstrap/saltic workbench/tarantul/main.saltic .cache/build/workbench/tarantul 268435456 x86_64
    .cache/build/workbench/tarantul "$1"

esp32: _dirs (tarantul "get")
    bootstrap/saltic soul/toolchains/esp32/main.saltic .cache/build/workbench/esp32-toolchain 536870912 x86_64
    bootstrap/saltic workbench/check/esp32.saltic .cache/build/workbench/esp32 536870912 x86_64
    .cache/build/workbench/esp32

# Все входы проекта через lens (чекер без сборки), по 6 разом: печатает только
# упавшие с причиной. Lens — с полки, через .part (работающий сервер MCP держит
# свой файл).
entries: _dirs (tarantul "get")
    bootstrap/saltic workbench/agent/lens/main.saltic .cache/build/workbench/lens.part 1073741824 x86_64 && mv .cache/build/workbench/lens.part .cache/build/workbench/lens
    bootstrap/saltic workbench/check/entries.saltic .cache/build/workbench/entries-check 268435456 x86_64
    .cache/build/workbench/entries-check

arm64-golden mode="": _dirs
    bootstrap/saltic workbench/check/arm64-encoder-golden.saltic .cache/build/workbench/arm64-encoder-golden 536870912 x86_64
    .cache/build/workbench/arm64-encoder-golden "$1"

same *sources: _dirs
    bootstrap/saltic workbench/check/same.saltic .cache/build/workbench/same-check 536870912 x86_64
    .cache/build/workbench/same-check "$*"

test case="all" host="x86_64": _dirs (tarantul "get")
    bootstrap/saltic tests/run/main.saltic .cache/build/workbench/tests 536870912 x86_64
    SALTIC_TEST_HOST="$2" nix --extra-experimental-features "nix-command flakes" develop --command .cache/build/workbench/tests "$1"

package:
    bash .github/package.sh

clean:
    rm -rf -- .cache/build .cache/dist
