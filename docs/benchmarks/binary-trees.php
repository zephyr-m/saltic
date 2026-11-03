<?php
function make($d) { return $d ? [make($d - 1), make($d - 1)] : null; }
function check($t) { return $t ? 1 + check($t[0]) + check($t[1]) : 1; }
$top = 16; $low = 4;
echo "stretch tree of depth ", $top + 1, " check: ", check(make($top + 1)), "\n";
$lng = make($top);
for ($d = $low; $d <= $top; $d += 2) { $it = 1 << ($top - $d + $low); $s = 0; for ($i = 0; $i < $it; $i++) $s += check(make($d)); echo "$it trees of depth $d check: $s\n"; }
echo "long lived tree of depth $top check: ", check($lng), "\n";
