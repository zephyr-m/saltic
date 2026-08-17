use core

Division = Box {
    quotient = 0
    remainder = 0
    valid = yes
}

skill add(left, right) {
    @result = left
    drum (right) {
        result = result + 1
    }
    out result
}

skill subtract(left, right) {
    @result = left
    drum (right) {
        (result > 0) {
            result = result - 1
        }
    }
    out result
}

skill multiply(left, right) {
    @result = 0
    drum (right) {
        drum (left) {
            result = result + 1
        }
    }
    out result
}

skill divide(dividend, divisor) {
    (divisor == 0) {
        out Division { quotient = 0 remainder = dividend valid = no }
    }

    @quotient = 0
    @remainder = dividend
    @running = yes

    drum (dividend + 1) {
        (running == yes) {
            (remainder < divisor) {
                running = no
            }
            (running == yes) {
                drum (divisor) {
                    remainder = remainder - 1
                }
                quotient = quotient + 1
            }
        }
    }

    out Division { quotient = quotient remainder = remainder valid = yes }
}

program() {
    @sum = add(12, 7)
    @difference = subtract(12, 7)
    @product = multiply(12, 7)
    @division = divide(12, 7)
    @division_by_zero = divide(12, 0)

    core.io.println("12 + 7 = ", sum)
    core.io.println("12 - 7 = ", difference)
    core.io.println("12 * 7 = ", product)
    core.io.println("12 / 7 = ", division.quotient, " remainder ", division.remainder)
    core.io.println("12 / 0 valid = ", division_by_zero.valid)
    out none
}
