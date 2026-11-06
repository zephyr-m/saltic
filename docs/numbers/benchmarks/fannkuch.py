n = 10
perm1 = list(range(n)); count = [0] * n; r = n; checksum = 0; maxflips = 0; turn = 0
while True:
    while r != 1:
        count[r - 1] = r; r -= 1
    perm = perm1[:]; flips = 0
    k = perm[0]
    while k:
        i, j = 0, k
        while i < j:
            perm[i], perm[j] = perm[j], perm[i]; i += 1; j -= 1
        flips += 1; k = perm[0]
    maxflips = max(maxflips, flips)
    checksum += flips if turn % 2 == 0 else -flips
    while True:
        if r == n:
            print(checksum); print(f"Pfannkuchen({n}) = {maxflips}"); raise SystemExit
        first = perm1[0]
        for i in range(r): perm1[i] = perm1[i + 1]
        perm1[r] = first
        count[r] -= 1
        if count[r] > 0: break
        r += 1
    turn += 1
