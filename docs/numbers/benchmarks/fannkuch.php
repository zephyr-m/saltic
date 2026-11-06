<?php
$n = 10; $perm1 = range(0, $n - 1); $count = array_fill(0, $n, 0); $r = $n; $checksum = 0; $maxflips = 0; $turn = 0;
while (true) {
    while ($r != 1) { $count[$r - 1] = $r; $r--; }
    $perm = $perm1; $flips = 0;
    while (($k = $perm[0]) != 0) { for ($i = 0, $j = $k; $i < $j; $i++, $j--) { $t = $perm[$i]; $perm[$i] = $perm[$j]; $perm[$j] = $t; } $flips++; }
    if ($flips > $maxflips) $maxflips = $flips;
    $checksum += $turn % 2 == 0 ? $flips : -$flips;
    while (true) {
        if ($r == $n) { echo "$checksum\nPfannkuchen($n) = $maxflips\n"; exit; }
        $first = $perm1[0];
        for ($i = 0; $i < $r; $i++) $perm1[$i] = $perm1[$i + 1];
        $perm1[$r] = $first;
        if (--$count[$r] > 0) break;
        $r++;
    }
    $turn++;
}
