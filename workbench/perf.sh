#!/usr/bin/env bash
# usage: saltic-perf.sh compiler.elf source.saltic
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .cache/build/workbench
out=.cache/build/workbench/perf; mkdir -p $out
q=$(nix --extra-experimental-features "nix-command flakes" develop --command bash -c 'readlink -f $(which qemu-riscv32)' 2>/dev/null | tail -1)
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#perf --command bash -c "
perf record -q -F 1000 -e cpu-clock -o $out/perf.data $q -perfmap -B 0x100000000 $1 $2 $out/out.elf 536870912 >/dev/null 2>&1
perf report -i $out/perf.data --stdio --sort sym --percent-limit 0 2>/dev/null | grep -v '^#' | grep . > $out/report.txt"
nix --extra-experimental-features "nix-command flakes" develop --command riscv32-none-elf-readelf -sW $1 2>/dev/null > $out/syms.txt
python3 - $out <<'PY'
import sys,re,bisect,collections
d=sys.argv[1]
syms=[]
for l in open(f'{d}/syms.txt'):
    p=l.split()
    if len(p)>=8 and p[0].rstrip(':').isdigit() and not p[7].startswith(('.L','$')):
        syms.append((int(p[1],16),p[7]))
syms.sort(); addrs=[a for a,_ in syms]
own=collections.Counter(); qemu=0.0; total=0.0
for l in open(f'{d}/report.txt'):
    m=re.match(r'\s*([\d.]+)%\s+\[\.\]\s+(\S+)',l)
    if not m: continue
    pct=float(m.group(1)); name=m.group(2); total+=pct
    g=re.match(r'guest-0x([0-9a-f]+)',name)
    if g:
        i=bisect.bisect_right(addrs,int(g.group(1),16))-1
        own[syms[i][1] if i>=0 else '?']+=pct
    else: qemu+=pct
print(f"накладные расходы QEMU: {qemu:.1f}%   код Saltic: {total-qemu:.1f}%")
for n,p in own.most_common(30): print(f"{p:6.2f}%  {n}")
PY
