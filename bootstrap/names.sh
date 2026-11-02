# Имена компиляторов в bootstrap/ и их паспорта. Подключается через source.
# Формат имени: saltic-<версия>-compiler-<процессор>-<платформа>[.расширение],
# где процессор — тот, на котором компилятор запускается. Хэши — только в паспорте.
# Версия — счёт Football Versioning: в VERSION «58:12», в именах «58-12».

saltic_version() {
    tr -d '\r\n' < VERSION | tr ':' '-'
}

# saltic_compiler_path <процессор> <платформа> [расширение]
saltic_compiler_path() {
    echo "bootstrap/saltic-$(saltic_version)-compiler-$1-$2${3:-}"
}

# Загрузочный компилятор из git. После смены VERSION на релизе и до самосборки
# он ещё носит прежнюю версию, поэтому при отсутствии текущей берётся единственный.
saltic_bootstrap_compiler() {
    local current
    current="$(saltic_compiler_path rv32i linux .elf)"
    if [[ -f "$current" ]]; then
        echo "$current"
        return
    fi
    local found=(bootstrap/saltic-*-compiler-rv32i-linux.elf)
    if [[ ${#found[@]} -ne 1 || ! -f "${found[0]}" ]]; then
        echo "bootstrap: нужен ровно один saltic-*-compiler-rv32i-linux.elf" >&2
        return 1
    fi
    echo "${found[0]}"
}

# Хэш исходников, из которых собираются компиляторы.
saltic_source_hash() {
    find soul os/target -name '*.saltic' -type f | LC_ALL=C sort \
        | xargs sha256sum | sha256sum | cut -c1-16
}

# saltic_seconds_since <EPOCHREALTIME начала> — прошедшие секунды с одной цифрой после точки
saltic_seconds_since() {
    LC_ALL=C awk "BEGIN { printf \"%.1f\", ${EPOCHREALTIME/,/.} - ${1/,/.} }"
}

# Объём исходников компилятора: «файлов, строк» по soul/seed/core и selfhost.
saltic_source_volume() {
    local files lines
    files="$(find soul/seed/core soul/seed/selfhost -name '*.saltic' -type f | wc -l)"
    lines="$(find soul/seed/core soul/seed/selfhost -name '*.saltic' -type f -print0 | xargs -0 cat | wc -l)"
    echo "файлов $files, строк $lines (soul/seed/core, selfhost)"
}

# saltic_write_passport <бинарник> <запускается на> <выдаёт код для> <собран чем> <куча> <самосборка> [секунды] [что заняло время: самосборки | сборки] [замер GNU time: «%M %U %S»]
saltic_write_passport() {
    local binary="$1"
    local parent_sum
    parent_sum="$(sha256sum "$4" | cut -c1-16)"
    cat > "${binary%.elf}.txt" <<EOF
программа:        компилятор Saltic
версия:           $(saltic_version)
запускается на:   $2
выдаёт код для:   $3
исходники:        $(saltic_source_hash)
собран чем:       $(basename "$4") (sha256 $parent_sum)
самосборка:       $6
куча:             $5 байт
sha256 файла:     $(sha256sum "$binary" | cut -c1-16)
размер:           $(stat -c %s "$binary") байт
объём исходников: $(saltic_source_volume)
дата:             $(date +%Y-%m-%d)
EOF
    if [[ -f "${9:-}" ]]; then
        local peak_kb user_seconds system_seconds
        read -r peak_kb user_seconds system_seconds <"$9"
        echo "пик памяти:       $((peak_kb / 1024)) МБ" >> "${binary%.elf}.txt"
        echo "процессор:        $(LC_ALL=C awk -v u="$user_seconds" -v s="$system_seconds" 'BEGIN { printf "%.1f", u + s }') с (user + sys)" >> "${binary%.elf}.txt"
    fi
    if [[ -n "${7:-}" ]]; then
        local cpu
        cpu="$(grep -m1 '^model name' /proc/cpuinfo | sed 's/^[^:]*: *//')"
        echo "время ${8:-самосборки}: $7 с, $cpu" >> "${binary%.elf}.txt"
    fi
}

# Родной x86-64 компилятор свежий, если его паспорт ссылается на текущий
# загрузочный по sha256. Иначе он переведён из старого и его надо пересобрать.
saltic_native_fresh() {
    local native compiler
    native="$(saltic_compiler_path x86_64 linux)"
    compiler="$(saltic_bootstrap_compiler)" || return 1
    [[ -x "$native" && -f "$native.txt" ]] || return 1
    grep -q "sha256 $(sha256sum "$compiler" | cut -c1-16))" "$native.txt"
}

# Путь к свежему родному компилятору; при необходимости переводит его заново.
saltic_native_compiler() {
    local native compiler
    native="$(saltic_compiler_path x86_64 linux)"
    if ! saltic_native_fresh; then
        compiler="$(saltic_bootstrap_compiler)" || return 1
        echo "bootstrap: перевожу $(basename "$compiler") в x86-64" >&2
        for old in bootstrap/saltic-*-compiler-x86_64-linux; do
            if [[ -f "$old" && "$old" != "$native" ]]; then rm -f "$old" "$old.txt"; fi
        done
        mkdir -p .cache/build
        local started=$EPOCHREALTIME
        SALTIC_BOOTSTRAP_COMPILER="$compiler" \
        SALTIC_BUILD_DIR=.cache/build/bootstrap-native \
        SALTIC_HEAP_BYTES=4026531840 \
        SALTIC_TARGET=x86_64 \
        SALTIC_NATIVE=0 \
        bash bootstrap/build.sh soul/seed/selfhost/toolchain.saltic "$native" > .cache/build/bootstrap-native.log 2>&1 || {
            grep -v "^warning" .cache/build/bootstrap-native.log | tail -5 >&2
            return 1
        }
        saltic_write_passport "$native" "x86_64, linux" "rv32i, x86_64" \
            "$compiler" 4026531840 "переведён из $(basename "$compiler")" "$(saltic_seconds_since "$started")" сборки
    fi
    echo "$native"
}

# Toolchain, который запускается там же (rv32i, linux), но выдаёт код для голого
# железа qemu-virt. Зависит и от компилятора, и от os/target, поэтому свежесть
# проверяется по sha родителя и по хэшу исходников из паспорта.
saltic_qemu_virt_compiler() {
    local native toolchain passport
    native="$(saltic_native_compiler)" || return 1
    toolchain="$(saltic_compiler_path rv32i linux-for-qemu_virt .elf)"
    passport="${toolchain%.elf}.txt"
    if [[ -x "$toolchain" && -f "$passport" ]] \
        && grep -q "sha256 $(sha256sum "$native" | cut -c1-16))" "$passport" \
        && grep -q "исходники: *$(saltic_source_hash)$" "$passport"; then
        echo "$toolchain"
        return
    fi
    echo "bootstrap: собираю $(basename "$toolchain")" >&2
    for old in bootstrap/saltic-*-compiler-rv32i-linux-for-qemu_virt.elf; do
        if [[ -f "$old" && "$old" != "$toolchain" ]]; then rm -f "$old" "${old%.elf}.txt"; fi
    done
    mkdir -p .cache/build
    local started=$EPOCHREALTIME
    "$native" os/target/qemu_virt/toolchain.saltic "$toolchain" 536870912 rv32i \
        > .cache/build/bootstrap-qemu_virt.log 2>&1 || {
        grep -v "^warning" .cache/build/bootstrap-qemu_virt.log | tail -5 >&2
        return 1
    }
    chmod +x "$toolchain"
    saltic_write_passport "$toolchain" "rv32i, linux (qemu-riscv32 -B 0x100000000)" \
        "rv32i, qemu-virt (голое железо)" "$native" 536870912 "собран родным компилятором" "$(saltic_seconds_since "$started")" сборки
    echo "$toolchain"
}
