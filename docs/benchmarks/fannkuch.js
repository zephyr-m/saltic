const n = 10; const perm1 = [...Array(n).keys()], count = new Array(n).fill(0); let perm, r = n, checksum = 0, maxflips = 0, turn = 0;
for (;;) {
  while (r !== 1) { count[r - 1] = r; r--; }
  perm = perm1.slice(); let flips = 0, k;
  while ((k = perm[0]) !== 0) { for (let i = 0, j = k; i < j; i++, j--) { const t = perm[i]; perm[i] = perm[j]; perm[j] = t; } flips++; }
  if (flips > maxflips) maxflips = flips;
  checksum += turn % 2 === 0 ? flips : -flips;
  for (;;) {
    if (r === n) { console.log(checksum); console.log(`Pfannkuchen(${n}) = ${maxflips}`); process.exit(0); }
    const first = perm1[0]; for (let i = 0; i < r; i++) perm1[i] = perm1[i + 1]; perm1[r] = first;
    if (--count[r] > 0) break; r++;
  }
  turn++;
}
