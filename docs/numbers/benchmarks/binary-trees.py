def make(d):
    return (make(d - 1), make(d - 1)) if d else None
def check(t):
    return 1 + check(t[0]) + check(t[1]) if t else 1
top, low = 16, 4
print(f"stretch tree of depth {top + 1} check: {check(make(top + 1))}")
lng = make(top)
for d in range(low, top + 1, 2):
    it = 1 << (top - d + low)
    print(f"{it} trees of depth {d} check: {sum(check(make(d)) for _ in range(it))}")
print(f"long lived tree of depth {top} check: {check(lng)}")
