skill std_str_lines_count(text) {
    @length = std_str_len(text)
    (length == 0) {
        out 0
    }

    @count = 0
    @index = 0

    drum (length) {
        (std_str_at(text, index) == "\n") {
            count = count + 1
        }
        index = index + 1
    }

    (std_str_at(text, length - 1) == "\n") {
        out count
    }

    out count + 1
}

skill std_str_lines(text) {
    out host.str.lines(text)
}

skill std_str_len(text) {
    out host.str.len(text)
}

skill std_str_at(text, index) {
    out host.str.at(text, index)
}

skill std_str_slice(text, start, end) {
    out host.str.slice(text, start, end)
}

skill std_str_add(left, right) {
    out host.str.join(left, right)
}

skill std_str_eq(left, right) {
    out host.str.eq(left, right)
}

skill std_str_is_empty(text) {
    out std_str_len(text) == 0
}

skill std_str_starts_with(text, prefix) {
    @prefix_len = std_str_len(prefix)
    (prefix_len > std_str_len(text)) {
        out no
    }
    out std_str_eq(std_str_slice(text, 0, prefix_len), prefix)
}

skill std_str_ends_with(text, suffix) {
    @suffix_len = std_str_len(suffix)
    @text_len = std_str_len(text)
    (suffix_len > text_len) {
        out no
    }
    out std_str_eq(std_str_slice(text, text_len - suffix_len, text_len), suffix)
}

skill std_str_starts_at(text, needle, index) {
    @needle_len = std_str_len(needle)
    @end = index + needle_len
    (end > std_str_len(text)) {
        out no
    }
    out std_str_eq(std_str_slice(text, index, end), needle)
}

skill std_str_contains(text, needle) {
    @needle_len = std_str_len(needle)
    (needle_len == 0) {
        out yes
    }

    @text_len = std_str_len(text)
    (needle_len > text_len) {
        out no
    }

    @found = no
    @index = 0
    @limit = text_len - needle_len + 1

    drum (limit) {
        (found == no) {
            (std_str_starts_at(text, needle, index) == yes) {
                found = yes
            }
        }
        index = index + 1
    }

    out found
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
