#!/usr/bin/env bash
# Проверка правки исходников без изменения смысла: каждая программа собирается
# одним и тем же компилятором из HEAD и из рабочего дерева, результаты обязаны
# совпасть побайтово. Компилятор — родной x86-64 из bootstrap/ (вывод тот же,
# что у загрузочного под QEMU, но в разы быстрее).
source "$(dirname "$0")/../bootstrap/stamp.sh"
saltic_stamp_output "$0" "$@"
cd "$(dirname "$0")/.." || exit 1
W=.cache/build/workbench/same-source
HEAP=67108864
# Как в build.sh: toolchain-у нужна большая куча, чтобы собрать os/main.
TOOLCHAIN_HEAP=536870912
mkdir -p "$W"
rm -rf "$W/head" "$W/out"
mkdir -p "$W/out"

source bootstrap/names.sh
native="$(saltic_native_compiler)" || exit 1
native="$(realpath "$native")"

git worktree remove --force "$W/head" > /dev/null 2>&1
git worktree add --detach "$W/head" HEAD > /dev/null 2>&1 || { echo "не удалось создать worktree HEAD"; exit 1; }
out="$(realpath "$W/out")"

# Что именно разошлось: размеры и первый отличающийся байт, а если одна сторона
# не собралась — последняя строка её журнала.
explain() {
    local base="$1" side
    for side in head work; do
        if [[ ! -s "$base.$side" ]]; then
            echo "    $side не собрался: $(grep -v '^warning' "$base.$side.log" | tail -1)"
            return
        fi
    done
    echo "    размер: head $(stat -c %s "$base.head"), work $(stat -c %s "$base.work") байт"
    echo "    первое расхождение: байт $(LC_ALL=C cmp "$base.head" "$base.work" | awk '{print $5}' | tr -d ,)"
}

entries=(soul/seed/selfhost/toolchain.saltic soul/canonical/main.saltic os/target/qemu_virt/toolchain.saltic)
entries+=(soul/seed/tests/*.saltic tests/*.saltic)
status=0
for source in "${entries[@]}"; do
    name="$(echo "${source%.saltic}" | tr '/' '_')"
    heap=$HEAP
    [[ "$source" == */toolchain.saltic ]] && heap=$TOOLCHAIN_HEAP
    (cd "$W/head" && "$native" "$source" "$out/$name.head" $heap rv32i > "$out/$name.head.log" 2>&1)
    "$native" "$source" "$out/$name.work" $heap rv32i > "$out/$name.work.log" 2>&1
    # Без права на запуск qemu-riscv32 молча завершается с кодом 1.
    chmod +x "$out/$name.head" "$out/$name.work" 2>/dev/null
    if [[ ! -s "$out/$name.head" && ! -s "$out/$name.work" ]]; then
        echo "не программа: $source"
    elif cmp -s "$out/$name.head" "$out/$name.work"; then
        echo "одинаково: $source"
    else
        echo "РАЗЛИЧАЕТСЯ: $source"
        explain "$out/$name"
        status=1
    fi
done

# Образ ОС собирает qemu-virt toolchain, поэтому он сравнивается его же сборками.
nix --extra-experimental-features "nix-command flakes" develop --command bash -c "
    (cd $W/head && qemu-riscv32 -B 0x100000000 $out/os_target_qemu_virt_toolchain.head os/main.saltic $out/os.head $HEAP > $out/os.head.log 2>&1)
    qemu-riscv32 -B 0x100000000 $out/os_target_qemu_virt_toolchain.work os/main.saltic $out/os.work $HEAP > $out/os.work.log 2>&1
" 2>/dev/null
if [[ -s "$out/os.head" ]] && cmp -s "$out/os.head" "$out/os.work"; then
    echo "одинаково: os/main.saltic"
else
    echo "РАЗЛИЧАЕТСЯ: os/main.saltic"
    explain "$out/os"
    status=1
fi

git worktree remove --force "$W/head" > /dev/null 2>&1
exit $status
