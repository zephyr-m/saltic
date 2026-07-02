skill std_str_lines_count(text) {
    out host.str.lines_count(text)
}

skill std_str_lines(text) {
    out host.str.lines(text)
}

skill std_str_len(text) {
    out host.str.len(text)
}

skill std_str_add(left, right) {
    out host.str.join(left, right)
}

skill std_str_eq(left, right) {
    out host.str.eq(left, right)
}

skill std_str_contains(text, needle) {
    out host.str.contains(text, needle)
}

skill std_str_trim(text) {
    out host.str.trim(text)
}

skill std_str_upper(text) {
    out host.str.upper(text)
}

skill std_str_lower(text) {
    out host.str.lower(text)
}

skill std_str_split(text, separator) {
    out host.str.split(text, separator)
}
