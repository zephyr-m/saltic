# Время в начале каждой строки вывода наших скриптов. Подключается через source
# в самом начале скрипта: saltic_stamp_output "$0" "$@"
# Скрипт перезапускает себя, пропуская весь вывод через workbench/stamp.saltic
# (собирается родным x86-64 в .cache/build/workbench/stamp, когда новее
# исходник или компилятор полки). Если компилятор полки ещё без часов
# (core.time.now — NotSupported) или сборка не вышла — прежний цикл saltic_stamp.
# Вложенные вызовы видят SALTIC_STAMPED и время второй раз не ставят.

saltic_stamp() {
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        printf '[%(%H:%M:%S)T] %s\n' -1 "$line"
    done
}

saltic_stamp_program() {
    local root="$1"
    local program="$root/.cache/build/workbench/stamp"
    local failed="$program.failed"
    local compiler newest source
    compiler="$(cd "$root" && source bootstrap/names.sh && saltic_bootstrap_compiler 2>/dev/null)" || return 1
    newest="$program"
    [[ -f "$failed" ]] && newest="$failed"
    if [[ -x "$program" || -f "$failed" ]]; then
        for source in workbench/stamp.saltic soul/seed/io/clock.saltic soul/seed/core/time.saltic "$compiler"; do
            [[ "$root/$source" -nt "$newest" ]] && rm -f "$program" "$failed"
        done
    fi
    if [[ -f "$failed" ]]; then
        return 1
    fi
    if [[ ! -x "$program" ]]; then
        mkdir -p "$(dirname "$program")"
        if ! (cd "$root" && SALTIC_TARGET=x86_64 SALTIC_BUILD_DIR=.cache/build/workbench/stamp-build \
                bash bootstrap/build.sh workbench/stamp.saltic "$program" >/dev/null 2>&1) \
            || ! "$program" "echo проба" >/dev/null 2>&1; then
            rm -f "$program"
            touch "$failed"
            return 1
        fi
    fi
    echo "$program"
}

saltic_stamp_output() {
    if [[ -n "${SALTIC_STAMPED:-}" ]]; then
        return
    fi
    export SALTIC_STAMPED=1
    local root program
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    if program="$(saltic_stamp_program "$root")"; then
        exec "$program" "$(printf '%q ' bash "$@") 2>&1"
    fi
    set +e
    bash "$@" 2>&1 | saltic_stamp
    exit "${PIPESTATUS[0]}"
}
