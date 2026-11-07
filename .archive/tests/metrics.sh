# Метрики проверок: время по часам, время процессора (user + sys) и пик
# памяти для каждой сборки и каждого запуска. Подключается из tests/run.sh.
# Нет GNU time — проверки идут как раньше, без метрик.
#
# measure <вид> <команда…> — выполнить и записать строку метрик
# metrics_begin <проверка> / metrics_end — границы проверки (время целиком)
# metrics_report — таблица по проверкам, итог, история, «было / стало»

metrics_time="$(type -P time || true)"
metrics_file="$work/metrics.tsv"
metrics_history="$work_root/metrics-history.tsv"
metrics_case="-"
metrics_started=""
: >"$metrics_file"

measure() {
    local kind="$1"
    shift
    if [[ -z "$metrics_time" ]]; then
        "$@"
        return
    fi
    "$metrics_time" -q -a -o "$metrics_file" \
        -f "$metrics_case	$kind	%e	%U	%S	%M" "$@"
}

metrics_begin() {
    metrics_case="$1"
    metrics_started=${EPOCHREALTIME/,/.}
}

metrics_end() {
    local finished=${EPOCHREALTIME/,/.}
    printf '%s\tall\t%s\t0\t0\t0\n' "$metrics_case" \
        "$(awk -v a="$metrics_started" -v b="$finished" 'BEGIN { printf "%.2f", b - a }')" \
        >>"$metrics_file"
}

metrics_report() {
    [[ -n "$metrics_time" ]] || return 0
    local key="$host $*"
    local stamp
    stamp="$(date '+%Y-%m-%d %H:%M')"
    awk -F'\t' -v key="$key" -v stamp="$stamp" -v history="$metrics_history" '
        function mb(kb) { return sprintf("%.0f", (kb + 0) / 1024) }
        NF != 6 { next }
        {
            name = $1
            if (!(name in seen)) { seen[name] = 1; order[++count] = name }
            if ($2 == "all") { wall[name] = $3; next }
            cpu[name] += $4 + $5
            if ($2 == "build") { build[name] += $3 } else { run[name] += $3 }
            if ($6 > peak[name]) { peak[name] = $6 }
        }
        END {
            printf "метрики: 📊 %-14s %8s %8s %9s %8s %9s\n", "проверка", "всего", "сборка", "запуск", "процессор", "память"
            for (i = 1; i <= count; i++) {
                n = order[i]
                w = wall[n] + 0; p = peak[n] + 0
                printf "метрики: %s %-14s %7.1fс %7.1fс %8.1fс %8.1fс %7s МБ\n", (w < 5 ? "⚡" : w < 30 ? "🔹" : "🐢"), n, w, build[n] + 0, run[n] + 0, cpu[n] + 0, mb(p)
                total_wall += w; total_cpu += cpu[n]
                if (p > total_peak) { total_peak = p }
                printf "%s\t%s\t%s\t%.2f\t%.2f\t%d\n", stamp, key, n, w, cpu[n] + 0, p >> history
            }
            printf "метрики: 🧮 %-14s %7.1fс %8s %9s %8.1fс %7s МБ\n", "всего", total_wall, "", "", total_cpu, mb(total_peak + 0)
            printf "%s\t%s\tвсего\t%.2f\t%.2f\t%d\n", stamp, key, total_wall, total_cpu, total_peak >> history
        }' "$metrics_file"
    awk -F'\t' -v key="$key" '
        function trend(was, is) { return is < was * 0.95 ? "🟢" : is > was * 1.05 ? "🔴" : "⚪" }
        function mood(b, n) { return n[4] < b[4] * 0.95 ? "🚀" : n[4] > b[4] * 1.05 ? "🐌" : "😌" }
        $2 == key && $3 == "всего" { before = now; now = $0 }
        END {
            if (before == "") { print "метрики: 🆕 прошлого прогона с таким набором нет — сравню в следующий раз"; exit }
            split(before, b, "\t"); split(now, n, "\t")
            printf "метрики: 🕰️ было %.1f с, процессор %.1f с, память %.0f МБ\n", b[4], b[5], b[6] / 1024
            printf "метрики: %s стало %.1f с %s, процессор %.1f с %s, память %.0f МБ %s\n", mood(b, n), n[4], trend(b[4], n[4]), n[5], trend(b[5], n[5]), n[6] / 1024, trend(b[6], n[6])
        }' "$metrics_history"
}
