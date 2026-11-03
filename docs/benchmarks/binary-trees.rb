def make(d) = d.zero? ? nil : [make(d - 1), make(d - 1)]
def check(t) = t ? 1 + check(t[0]) + check(t[1]) : 1
top, low = 16, 4
puts "stretch tree of depth #{top + 1} check: #{check(make(top + 1))}"
lng = make(top)
low.step(top, 2) { |d| it = 1 << (top - d + low); s = 0; it.times { s += check(make(d)) }; puts "#{it} trees of depth #{d} check: #{s}" }
puts "long lived tree of depth #{top} check: #{check(lng)}"
