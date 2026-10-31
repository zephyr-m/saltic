# Время в начале каждой строки вывода наших скриптов. Подключается через source
# в самом начале скрипта: saltic_stamp_output "$0" "$@"
# Скрипт перезапускает себя, пропуская весь вывод через saltic_stamp. Вложенные
# вызовы видят SALTIC_STAMPED и время второй раз не ставят.

saltic_stamp() {
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        printf '[%(%H:%M:%S)T] %s\n' -1 "$line"
    done
}

saltic_stamp_output() {
    if [[ -n "${SALTIC_STAMPED:-}" ]]; then
        return
    fi
    export SALTIC_STAMPED=1
    set +e
    bash "$@" 2>&1 | saltic_stamp
    exit "${PIPESTATUS[0]}"
}
