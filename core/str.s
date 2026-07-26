skill core_str_lines_count(text) {
    @length = core_str_len(text)
    (length == 0) {
        out 0
    }

    @count = 0
    @index = 0

    drum (length) {
        (core_str_at(text, index) == "\n") {
            count = count + 1
        }
        index = index + 1
    }

    (core_str_at(text, length - 1) == "\n") {
        out count
    }

    out count + 1
}

skill core_str_lines(text) {
    out core_str_split(text, "\n")
}

skill core_str_len(text) {
    out host.str.len(text)
}

skill core_str_at(text, index) {
    out host.str.at(text, index)
}

skill core_str_slice(text, start, end) {
    out host.str.slice(text, start, end)
}

skill core_str_add(left, right) {
    out host.str.join(left, right)
}

skill core_str_eq(left, right) {
    out host.str.eq(left, right)
}

skill core_str_is_empty(text) {
    out core_str_len(text) == 0
}

skill core_str_starts_with(text, prefix) {
    @prefix_len = core_str_len(prefix)
    (prefix_len > core_str_len(text)) {
        out no
    }
    out core_str_eq(core_str_slice(text, 0, prefix_len), prefix)
}

skill core_str_ends_with(text, suffix) {
    @suffix_len = core_str_len(suffix)
    @text_len = core_str_len(text)
    (suffix_len > text_len) {
        out no
    }
    out core_str_eq(core_str_slice(text, text_len - suffix_len, text_len), suffix)
}

skill core_str_starts_at(text, needle, index) {
    @needle_len = core_str_len(needle)
    @end = index + needle_len
    (end > core_str_len(text)) {
        out no
    }
    out core_str_eq(core_str_slice(text, index, end), needle)
}

skill core_str_contains(text, needle) {
    @needle_len = core_str_len(needle)
    (needle_len == 0) {
        out yes
    }

    @text_len = core_str_len(text)
    (needle_len > text_len) {
        out no
    }

    @found = no
    @index = 0
    @limit = text_len - needle_len + 1

    drum (limit) {
        (found == no) {
            (core_str_starts_at(text, needle, index) == yes) {
                found = yes
            }
        }
        index = index + 1
    }

    out found
}

skill core_str_trim(text) {
    out host.str.trim(text)
}

skill core_str_upper(text) {
    out host.str.upper(text)
}

skill core_str_lower(text) {
    out host.str.lower(text)
}

skill core_str_split(text, separator) {
    @separator_len = core_str_len(separator)
    @text_len = core_str_len(text)
    @items = []

    (separator_len == 0) {
        (core_str_is_empty(text) == no) {
            items = core.group.append(items, text)
        }
        out items
    }

    @start = 0
    @index = 0

    drum (text_len) {
        @matched = no

        (core_str_starts_at(text, separator, index) == yes) {
            @part = core_str_slice(text, start, index)
            (core_str_is_empty(part) == no) {
                items = core.group.append(items, part)
            }
            index = index + separator_len
            start = index
            matched = yes
        }

        (matched == no) {
            index = index + 1
        }
    }

    @tail = core_str_slice(text, start, text_len)
    (core_str_is_empty(tail) == no) {
        items = core.group.append(items, tail)
    }

    out items
}
