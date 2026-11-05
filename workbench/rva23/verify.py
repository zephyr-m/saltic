"""verify — сверяет вывод tests/rva23.saltic с GNU-ассемблером.

Каждая строка: «текст ассемблера<TAB>байты hex» от кодировщика Saltic.
Собирает все тексты, сравнивает байты. Строки, которые ассемблер отверг
(ограничения вроде перекрытия векторных регистров при случайных
операндах), пропускаются; у каждой команды должна сойтись хотя бы одна.

Запуск: nix develop --command python3 workbench/rva23/verify.py вывод.txt
"""

import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(__file__))
from generate import MARCH  # noqa: E402

lines = [l.rstrip("\n").split("\t") for l in open(sys.argv[1]) if "\t" in l]
alive = list(range(len(lines)))
with tempfile.TemporaryDirectory() as work:
    for _ in range(6):
        source, where = [], {}
        for n in alive:
            text, code = lines[n]
            source.append(".option rvc" if len(code) == 4 else ".option norvc")
            source.append(text)
            where[len(source)] = n
        path = os.path.join(work, "check.s")
        open(path, "w").write("\n".join(source) + "\n")
        done = subprocess.run(["env", "LC_ALL=C", "riscv32-none-elf-as", f"-march={MARCH}", "-mabi=lp64d", path,
                               "-o", os.path.join(work, "check.o")], capture_output=True, text=True)
        bad = {where[int(m.group(1))] for m in re.finditer(r"check\.s:(\d+): Error", done.stderr) if int(m.group(1)) in where}
        if done.returncode == 0 and not bad:
            break
        alive = [n for n in alive if n not in bad]
    dump = subprocess.run(["env", "LC_ALL=C", "riscv32-none-elf-objdump", "-d", os.path.join(work, "check.o")],
                          capture_output=True, text=True).stdout
codes = [m.group(1) for m in (re.match(r"\s*[0-9a-f]+:\s+([0-9a-f]{4,8})\s", l) for l in dump.splitlines()) if m]
if len(codes) != len(alive):
    sys.exit(f"verify: разбор objdump — {len(codes)} команд на {len(alive)} строк")
wrong, verified = [], set()
for n, code in zip(alive, codes):
    text, mine = lines[n]
    name = text.split()[0]
    if code != mine:
        wrong.append(f"{text}: Saltic {mine}, ассемблер {code}")
    else:
        verified.add(name)
names = {l[0].split()[0] for l in lines}
unchecked = sorted(names - verified - {w.split()[0] for w in wrong})
print(f"verify: строк {len(lines)}, собрано {len(alive)}, совпало {len(alive) - len(wrong)}, "
      f"расхождений {len(wrong)}; команд {len(names)}, без проверки {len(unchecked)}")
for w in wrong[:30]:
    print("  расходится:", w)
for u in unchecked[:30]:
    print("  не проверено:", u)
sys.exit(1 if wrong or unchecked else 0)
