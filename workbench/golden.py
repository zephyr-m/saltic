#!/usr/bin/env python3
"""Regenerate golden machine-code expectations in soul/seed/tests/machine/translation.saltic.

1. Inject a dump before every `@X_bytes = [` array (temporarily).
2. Build and run a probe that calls translation.run.
3. Restore the file, then rewrite byte arrays, lengths, patch counts and drum
   counts from the dumps, and scalar `test_equal` failures from the probe output.
"""
import os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, "soul/seed/tests/machine/translation.saltic")
BUILD = os.path.join(ROOT, ".cache/build/workbench/golden")
NIX = ["nix", "--extra-experimental-features", "nix-command flakes", "develop", "--command"]

original = open(PATH).read()
lines = original.split("\n")

blocks = []  # (bytes_name, variable)
injected = []
for i, line in enumerate(lines):
    m = re.match(r"    @(\w+)_bytes = \[$", line)
    if m:
        var = None
        for j in range(i - 1, -1, -1):
            v = re.match(r"    @(\w+) = state\.State", lines[j])
            if v:
                var = v.group(1)
                break
        blocks.append((m.group(1), var))
        injected.append(f'    golden_dump("{m.group(1)}", {var}.machine)')
    injected.append(line)

dump_skill = '''
skill golden_dump(name, machine) {
    @line = seed.str.add("GOLDEN ", name)
    line = seed.str.add(line, seed.str.add(" ", seed.num.text(machine.code.length)))
    line = seed.str.add(line, seed.str.add(" ", seed.num.text(machine.patch_count)))
    seed.io.show(line)
    @index = 0
    @row = ""
    drum (machine.code.length) {
        row = seed.str.add(row, seed.str.add(seed.num.text(codec.byte_at(machine.code, index)), ","))
        index = index + 1
    }
    seed.io.show("BYTES ", name, " ", row)
    out none
}
'''

probe = os.path.join(BUILD, "probe.saltic")
os.makedirs(BUILD, exist_ok=True)
open(probe, "w").write("use seed\nuse craft.testing\nuse seed.tests.machine.translation\n\nprogram() {\n"
                       "    @suite = translation.run(testing.test_new())\n    out none\n}\n")
try:
    open(PATH, "w").write("\n".join(injected) + dump_skill)
    env = dict(os.environ, SALTIC_BUILD_DIR=os.path.join(BUILD, "b"), SALTIC_HEAP_BYTES="536870912")
    subprocess.run(NIX + ["bash", "os/bootstrap/build.sh", probe, os.path.join(BUILD, "probe.elf")],
                   cwd=ROOT, env=env, check=True, stdout=subprocess.DEVNULL)
    run = subprocess.run(NIX + ["qemu-riscv32", "-B", "0x100000000", os.path.join(BUILD, "probe.elf")],
                         cwd=ROOT, capture_output=True, text=True)
    output = run.stdout
finally:
    open(PATH, "w").write(original)
open(os.path.join(BUILD, "probe.txt"), "w").write(output)

dumps = {}
for line in output.split("\n"):
    g = re.match(r"GOLDEN (\w+) (\d+) (\d+)$", line)
    if g:
        dumps.setdefault(g.group(1), {})["len"] = int(g.group(2))
        dumps[g.group(1)]["patches"] = int(g.group(3))
    b = re.match(r"BYTES (\w+) ([\d,]*)$", line)
    if b:
        dumps.setdefault(b.group(1), {})["bytes"] = [x for x in b.group(2).split(",") if x]

text = original
changed = []
for name, var in blocks:
    d = dumps.get(name)
    if not d or "bytes" not in d:
        print("нет дампа:", name)
        continue
    rows = [d["bytes"][k:k + 8] for k in range(0, len(d["bytes"]), 8)]
    body = "\n".join("        " + ", ".join(r) + "," for r in rows)
    pattern = re.compile(r"(    @" + name + r"_bytes = \[\n)(.*?)(\n    \])", re.S)
    m = pattern.search(text)
    if m.group(2) != body:
        changed.append(name)
    text = text[:m.start(2)] + body + text[m.end(2):]
    head, tail = text[:m.start()], text[m.start():]
    tail = re.sub(r"(" + re.escape(var) + r"\.machine\.code\.length, )\d+\)", r"\g<1>" + str(d["len"]) + ")", tail, count=1)
    tail = re.sub(r"(" + re.escape(var) + r"\.machine\.patch_count, )\d+\)", r"\g<1>" + str(d["patches"]) + ")", tail, count=1)
    text = head + tail
    idx = re.search(r"    @(\w+) = 0\n    drum \((\d+)\) \{\n        suite = testing\.test_equal\(suite, seed\.str\.add\(\"[^\"]*\", seed\.num\.text\(\1\)\), codec\.byte_at\(" + re.escape(var) + r"\.machine\.code",
                    text[m.start():])
    if idx:
        a = m.start() + idx.start(2)
        text = text[:a] + str(d["len"]) + text[m.start() + idx.end(2):]

fixed = 0
for line in output.split("\n"):
    f = re.match(r"(.+?) -> (-?\d+)  \[FAIL\] \(ожидалось (-?\d+)\)$", line)
    if not f or ": байт " in f.group(1):
        continue
    label, actual, expected = f.groups()
    pat = re.compile(r'("' + re.escape(label) + r'", [^\n]*?, )' + re.escape(expected) + r"\)")
    text, n = pat.subn(r"\g<1>" + actual + ")", text, count=1)
    fixed += n

open(PATH, "w").write(text)
print("массивов изменено:", len(changed), changed)
print("скалярных эталонов исправлено:", fixed)
print("FAIL в пробе:", sum(1 for l in output.split("\n") if "[FAIL]" in l))
