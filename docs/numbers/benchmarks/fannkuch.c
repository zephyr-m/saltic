#include <stdio.h>
int main(void) {
    int n = 10, perm[16], perm1[16], count[16], r = n, checksum = 0, maxflips = 0, turn = 0;
    for (int i = 0; i < n; i++) perm1[i] = i;
    for (;;) {
        while (r != 1) { count[r - 1] = r; r--; }
        for (int i = 0; i < n; i++) perm[i] = perm1[i];
        int flips = 0, k;
        while ((k = perm[0]) != 0) { for (int i = 0, j = k; i < j; i++, j--) { int t = perm[i]; perm[i] = perm[j]; perm[j] = t; } flips++; }
        if (flips > maxflips) maxflips = flips;
        checksum += turn % 2 == 0 ? flips : -flips;
        for (;;) {
            if (r == n) { printf("%d\nPfannkuchen(%d) = %d\n", checksum, n, maxflips); return 0; }
            int first = perm1[0];
            for (int i = 0; i < r; i++) perm1[i] = perm1[i + 1];
            perm1[r] = first;
            if (--count[r] > 0) break;
            r++;
        }
        turn++;
    }
}
