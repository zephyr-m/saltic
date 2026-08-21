use core

skill std_str_is_empty(text) {
    out core.str.len(text) == 0
}

skill std_str_starts_at(text, needle, index) {
    @needle_length = core.str.len(needle)
    @end = index + needle_length

    (end > core.str.len(text)) {
        out no
    }

    out core.str.slice(text, index, end) == needle
}

skill std_str_starts_with(text, prefix) {
    out std_str_starts_at(text, prefix, 0)
}

skill std_str_ends_with(text, suffix) {
    @suffix_length = core.str.len(suffix)
    @text_length = core.str.len(text)

    (suffix_length > text_length) {
        out no
    }

    out core.str.slice(text, text_length - suffix_length, text_length) == suffix
}

skill std_str_contains(text, needle) {
    @needle_length = core.str.len(needle)
    (needle_length == 0) {
        out yes
    }

    @text_length = core.str.len(text)
    (needle_length > text_length) {
        out no
    }

    @found = no
    @index = 0
    @limit = text_length - needle_length + 1
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

skill std_str_line_count(text) {
    @length = core.str.len(text)
    (length == 0) {
        out 0
    }

    @count = 0
    @index = 0
    drum (length) {
        (core.str.at(text, index) == "\n") {
            count = count + 1
        }
        index = index + 1
    }

    (core.str.at(text, length - 1) == "\n") {
        out count
    }

    out count + 1
}

skill std_str_lines(text) {
    out std_str_split(text, "\n")
}

skill std_str_split(text, separator) {
    @separator_length = core.str.len(separator)
    @text_length = core.str.len(text)
    @items = []

    (separator_length == 0) {
        (std_str_is_empty(text) == no) {
            items = core.group.add(items, text)
        }
        out items
    }

    @start = 0
    @index = 0
    drum (text_length) {
        @matched = no

        (std_str_starts_at(text, separator, index) == yes) {
            @part = core.str.slice(text, start, index)
            (std_str_is_empty(part) == no) {
                items = core.group.add(items, part)
            }
            index = index + separator_length
            start = index
            matched = yes
        }

        (matched == no) {
            index = index + 1
        }
    }

    @tail = core.str.slice(text, start, text_length)
    (std_str_is_empty(tail) == no) {
        items = core.group.add(items, tail)
    }

    out items
}
