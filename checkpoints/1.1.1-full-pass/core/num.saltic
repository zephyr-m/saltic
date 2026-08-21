skill core_num_parse(text) {
    out host.math.parse(text)
}

skill core_num_abs(value) {
    out host.math.abs(value)
}

skill core_num_round(value) {
    out host.math.round(value)
}

skill core_num_text(value) {
    (value == 0) {
        out "0"
    }

    @digits = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
    @parts = []
    @current = value
    @active = yes

    drum (20) {
        (active == yes) {
            @quotient = 0
            @remainder = current
            drum (current) {
                (remainder > 9) {
                    remainder = remainder - 10
                    quotient = quotient + 1
                }
            }
            parts = core.group.add(parts, core.group.item(digits, remainder))
            current = quotient
            (current == 0) {
                active = no
            }
        }
    }

    @result = ""
    @index = core.group.count(parts) - 1
    @reverse_active = yes
    drum (20) {
        (reverse_active == yes) {
            result = core.str.add(result, core.group.item(parts, index))
            (index == 0) {
                reverse_active = no
            }
            (index > 0) {
                index = index - 1
            }
        }
    }
    out result
}

skill core_num_add(left, right) {
    out left + right
}

skill core_num_sub(left, right) {
    out left - right
}

skill core_num_mul(left, right) {
    out left * right
}

skill core_num_div(left, right) {
    out left / right
}
