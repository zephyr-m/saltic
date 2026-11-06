const make = d => d ? [make(d - 1), make(d - 1)] : null;
const check = t => t ? 1 + check(t[0]) + check(t[1]) : 1;
const top = 16, low = 4;
console.log(`stretch tree of depth ${top + 1} check: ${check(make(top + 1))}`);
const lng = make(top);
for (let d = low; d <= top; d += 2) { const it = 1 << (top - d + low); let s = 0; for (let i = 0; i < it; i++) s += check(make(d)); console.log(`${it} trees of depth ${d} check: ${s}`); }
console.log(`long lived tree of depth ${top} check: ${check(lng)}`);
