"""generate — таблица команд RVA23 для Saltic из GNU-ассемблера.

Для каждой команды из instructions.py собирает её с базовыми операндами и с
каждым битом каждого операнда, перевёрнутым по одному; разница кодировок
говорит, в какие биты команды попадает бит операнда. Команды, которые
ассемблер не принял или разобрал под другим именем, выбрасываются и
перечисляются в отчёте. Пишет soul/seed/selfhost/compiler/backend/rv64/
machine/generated/rva23.saltic.

Запуск (нужен riscv32-none-elf-as из flake.nix):
  nix develop --command python3 workbench/check/rva23/generate.py
"""

import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(__file__))
import instructions  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "soul/seed/selfhost/compiler/backend/rv64/machine/generated/rva23.saltic")
MARCH = ("rv64gcv_zba_zbb_zbs_zicond_zfa_zcb_zimop_zcmop_zicbom_zicboz_zicbop_zawrs_"
         "zihintntl_zihintpause_zfhmin_zvfhmin_zvbb_zvkt_zacas")

FLI = ["-1.0", "min", "0x1p-16", "0x1p-15", "0x1p-8", "0x1p-7", "0.0625", "0.125", "0.25", "0.3125",
       "0.375", "0.4375", "0.5", "0.625", "0.75", "0.875", "1.0", "1.25", "1.5", "1.75", "2.0", "2.5",
       "3.0", "4.0", "8.0", "16.0", "128.0", "256.0", "32768.0", "65536.0", "inf", "nan"]


# подсказки (hint), которые objdump показывает как обычную команду-носитель
ALIASED = {"prefetch.i", "prefetch.r", "prefetch.w", "pause", "ntl.p1", "ntl.pall", "ntl.s1", "ntl.all",
           "c.ntl.p1", "c.ntl.pall", "c.ntl.s1", "c.ntl.all", "c.nop"}


def same_name(decoded, name):
    return decoded == name or name in ALIASED


def signed(bits, width):
    return bits - (1 << width) if bits & (1 << (width - 1)) else bits


def fence_text(v):
    return "".join(letter for bit, letter in [(8, "i"), (4, "o"), (2, "r"), (1, "w")] if v & bit)


# вид: (биты операнда, ширина со знаком или 0, базовые значения, как писать)
KINDS = {
    "x": (range(5), 0, [0, 5, 10], lambda v: f"x{v}"),
    "xnz": (range(5), 0, [3, 9], lambda v: f"x{v}"),
    "xlui": (range(5), 0, [5, 9], lambda v: f"x{v}"),
    "xc": (range(3), 0, [8, 11], lambda v: f"x{v}"),
    "f": (range(5), 0, [0, 5], lambda v: f"f{v}"),
    "fc": (range(3), 0, [8, 11], lambda v: f"f{v}"),
    "v": (range(5), 0, [8, 16, 24, 4, 12], lambda v: f"v{v}"),
    "vm": (range(1), 0, [0], lambda v: ", v0.t" if v else ""),
    "si12": (range(12), 12, [0], str),
    "si6": (range(6), 6, [0], str),
    "si5": (range(5), 5, [0], str),
    "nzsi6": (range(6), 6, [3], str),
    "ui20": (range(20), 0, [0], str),
    "ui12": (range(12), 0, [0, 3], str),
    "ui6": (range(6), 0, [0, 3], str),
    "ui5": (range(5), 0, [0, 3], str),
    "nzui6": (range(6), 0, [3], str),
    "boff": (range(1, 13), 13, [0], lambda v: f". + {v}"),
    "joff": (range(1, 21), 21, [0], lambda v: f". + {v}"),
    "cjoff": (range(1, 12), 12, [0], lambda v: f". + {v}"),
    "cboff": (range(1, 9), 9, [0], lambda v: f". + {v}"),
    "pre": (range(5, 12), 12, [0], str),
    "fence": (range(4), 0, [15], fence_text),
    "fli": (range(5), 0, [0, 16], lambda v: FLI[v]),
    "vtype": (range(8), 0, [0, 216, 24, 64], str),
    "clui": (range(6), 6, [3], lambda v: str(v if v > 0 else v & 0xfffff)),
    "sp16": (range(4, 10), 10, [48], str),
    "spn": (range(2, 10), 0, [12], str),
    "cw": (range(2, 7), 0, [0], str),
    "cd": (range(3, 8), 0, [0], str),
    "cwsp": (range(2, 8), 0, [0], str),
    "cdsp": (range(3, 9), 0, [0], str),
    "cb": (range(2), 0, [0], str),
    "ch": (range(1, 2), 0, [0], str),
}


def value_of(kind, bits):
    width = KINDS[kind][1]
    return signed(bits, width) if width else bits


def render(template, kinds, values):
    parts = re.split(r"\{[a-z0-9]+\}", template)
    out = parts[0]
    for i, kind in enumerate(kinds):
        text = KINDS[kind][3](value_of(kind, values[i]))
        if kind == "vm":
            out = out.rstrip()
        out += text + parts[i + 1]
    return out


def candidates(kinds):
    """Наборы базовых значений: по каждому виду перебираем его базы со сдвигом."""
    sets = []
    for shift in range(5):
        values = []
        used = {}
        for kind in kinds:
            bases = KINDS[kind][2]
            n = used.get(kind, 0)
            used[kind] = n + 1
            values.append(bases[(n + shift) % len(bases)])
        if values not in sets:
            sets.append(values)
    return sets


def plan():
    """Все строки для ассемблера: (номер команды, база, операнд, бит) -> текст."""
    jobs = []
    rows = []
    seen = set()
    for size, (name, template) in instructions.all_rows():
        kinds = re.findall(r"\{([a-z0-9]+)\}", template)
        key = (name, template)
        if key in seen:
            continue
        seen.add(key)
        index = len(rows)
        rows.append((size, name, template, kinds))
        for b, base in enumerate(candidates(kinds)):
            jobs.append(((index, b, None, None), size, f"{name} {render(template, kinds, base)}".strip(), base))
            for i, kind in enumerate(kinds):
                for bit in KINDS[kind][0]:
                    probe = list(base)
                    probe[i] ^= 1 << bit
                    if kind in ("xnz", "xlui") and probe[i] in (0, 2) and kind == "xlui":
                        continue
                    if kind == "xnz" and probe[i] == 0:
                        continue
                    if kind in ("nzsi6", "nzui6", "sp16", "spn", "clui") and probe[i] == 0:
                        continue
                    if kind == "xc" and not 8 <= probe[i] <= 15:
                        continue
                    if kind == "fc" and not 8 <= probe[i] <= 15:
                        continue
                    jobs.append(((index, b, i, bit), size, f"{name} {render(template, kinds, probe)}".strip(), probe))
    return rows, jobs


def assemble(jobs, workdir):
    """Собирает строки; те, что ассемблер отверг, выкидывает и собирает снова."""
    alive = list(range(len(jobs)))
    for _ in range(6):
        source = [".option norvc"]
        lines = {}
        current = "32"
        for j in alive:
            size = jobs[j][1]
            if size != current:
                source.append(".option rvc" if size == "16" else ".option norvc")
                current = size
            source.append(jobs[j][2])
            lines[len(source)] = j
        path = os.path.join(workdir, "probe.s")
        with open(path, "w") as f:
            f.write("\n".join(source) + "\n")
        done = subprocess.run(["env", "LC_ALL=C", "riscv32-none-elf-as", f"-march={MARCH}", "-mabi=lp64d", path, "-o",
                               os.path.join(workdir, "probe.o")], capture_output=True, text=True)
        bad = {lines[int(m.group(1))] for m in re.finditer(r"probe\.s:(\d+): Error", done.stderr) if int(m.group(1)) in lines}
        if done.returncode == 0 and not bad:
            break
        if not bad:
            sys.exit("ассемблер упал без номеров строк:\n" + done.stderr[:2000])
        alive = [j for j in alive if j not in bad]
    dump = subprocess.run(["env", "LC_ALL=C", "riscv32-none-elf-objdump", "-d", "-M", "no-aliases", os.path.join(workdir, "probe.o")],
                          capture_output=True, text=True).stdout
    decoded = []
    for line in dump.splitlines():
        m = re.match(r"\s*[0-9a-f]+:\s+([0-9a-f]{4,8})\s+(\S+)", line)
        if m:
            decoded.append((int(m.group(1), 16), m.group(2), len(m.group(1)) // 2))
    if len(decoded) != len(alive):
        sys.exit(f"разбор objdump: {len(decoded)} команд на {len(alive)} строк")
    return {j: decoded[n] for n, j in enumerate(alive)}


def build():
    rows, jobs = plan()
    with tempfile.TemporaryDirectory() as workdir:
        result = assemble(jobs, workdir)
    found = {}
    for n, job in enumerate(jobs):
        if n in result:
            found[job[0]] = (result[n], job[3])
    table, dropped = [], []
    for index, (size, name, template, kinds) in enumerate(rows):
        bases = [b for b in range(5) if (index, b, None, None) in found and same_name(found[(index, b, None, None)][0][1], name)]
        if not bases:
            dropped.append(f"{name} {template}")
            continue
        maps = []
        ok = True
        for i, kind in enumerate(kinds):
            bits = []
            for bit in KINDS[kind][0]:
                mask = None
                for b in bases:
                    probe = found.get((index, b, i, bit))
                    if probe and same_name(probe[0][1], name):
                        mask = probe[0][0] ^ found[(index, b, None, None)][0][0]
                        break
                if mask is None or mask == 0:
                    ok = False
                    break
                bits.append([bit] + [p for p in range(32) if mask >> p & 1])
            if not ok:
                break
            maps.append(bits)
        if not ok:
            dropped.append(f"{name} {template} (не все биты)")
            continue
        base = bases[0]
        encoding, base_values = found[(index, base, None, None)][0][0], found[(index, base, None, None)][1]
        table.append((name, template, kinds, base_values, encoding, found[(index, base, None, None)][0][2], maps))
    return table, dropped


def saltic_text(text):
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("{", "\\{").replace("}", "\\}")


FORBIDDEN = {"xnz": [0], "xlui": [0, 2], "nzsi6": [0], "nzui6": [0], "sp16": [0], "spn": [0], "clui": [0]}
STYLE = {"x": "x", "xnz": "x", "xlui": "x", "xc": "x", "f": "f", "fc": "f", "v": "v", "vm": "vm",
         "boff": "offset", "joff": "offset", "cjoff": "offset", "cboff": "offset",
         "fli": "fli", "fence": "fence", "clui": "clui"}


def write(table, dropped):
    kind_names = list(KINDS)
    forms, form_index, names, shapes, rows, seen = [], {}, [], [], [], set()
    for name, template, kinds, base_values, encoding, size, maps in table:
        if name in seen:
            continue
        seen.add(name)
        key = repr((kinds, base_values, maps))
        if key not in form_index:
            form_index[key] = len(forms)
            forms.append((kinds, base_values, maps))
        names.append(f'"{name}"')
        shapes.append('"' + saltic_text(re.sub(r"[{][a-z0-9]+[}]", "%", template)) + '"')
        b = [encoding >> shift & 255 for shift in (0, 8, 16, 24)]
        rows.append(f"    [{size}, {b[0]}, {b[1]}, {b[2]}, {b[3]}, {form_index[key]}]")
    form_lines = []
    for kinds, base_values, maps in forms:
        operands = [f"[{kind_names.index(k)}, {base}, {bits}]" for k, base, bits in zip(kinds, base_values, maps)]
        form_lines.append("    [" + ", ".join(operands) + "]")
    limits, styles, forbidden = [], [], []
    for name, (bits, width, bases, _render) in KINDS.items():
        low, high = min(bits), max(bits)
        step = 1 << low
        if name in ("xc", "fc"):
            least, most = 8, 15
        elif width:
            least, most = -(1 << (width - 1)), (1 << (width - 1)) - step
        else:
            least, most = 0, (1 << (high + 1)) - step
        limits.append(f"    [{least}, {most}, {step}]")
        styles.append('"' + STYLE.get(name, "number") + '"')
        forbidden.append(str(FORBIDDEN.get(name, [])))

    def lines(items, per_line):
        return ",\n".join("    " + ", ".join(items[i:i + per_line]) for i in range(0, len(items), per_line))

    head = [
        "-- rva23 — сгенерировано workbench/check/rva23/generate.py из GNU-ассемблера, руками не править.",
        f"-- Команд {len(names)}, форм операндов {len(forms)}; отброшено кандидатов {len(dropped)}.",
        "-- NAMES / SHAPES — имя и шаблон команды (% — операнд); ROWS — [байт в команде,",
        "--     b0, b1, b2, b3 — кодировка при базовых операндах, номер формы]. FORMS: на",
        "--     форму — операнды [номер вида, базовое значение, [[бит операнда, биты",
        "--     команды…]…]]: бит операнда, отличный от базового, переворачивает",
        "--     перечисленные биты команды. Виды: KIND_NAMES, KIND_LIMITS [наименьшее,",
        "--     наибольшее, шаг], KIND_STYLES (как писать), KIND_FORBIDDEN; FLI —",
        "--     константы fli.s / fli.d по номеру.",
        "",
        "NAMES = [", lines(names, 8), "]", "",
        "SHAPES = [", lines(shapes, 8), "]", "",
        "ROWS = [", ",\n".join(rows), "]", "",
        "FORMS = [", ",\n".join(form_lines), "]", "",
        "KIND_NAMES = [" + ", ".join('"' + k + '"' for k in kind_names) + "]", "",
        "KIND_LIMITS = [", ",\n".join(limits), "]", "",
        "KIND_STYLES = [" + ", ".join(styles) + "]", "",
        "KIND_FORBIDDEN = [" + ", ".join(forbidden) + "]", "",
        "FLI = [" + ", ".join('"' + t + '"' for t in FLI) + "]", "",
    ]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        f.write("\n".join(head))
    return len(forms), len(names)


if __name__ == "__main__":
    table, dropped = build()
    forms, count = write(table, dropped)
    print(f"rva23: команд {count}, форм {forms}, отброшено кандидатов {len(dropped)}")
    with open(os.path.join(tempfile.gettempdir(), "rva23-dropped.txt"), "w") as f:
        f.write("\n".join(dropped) + "\n")
    print("  список отброшенного:", os.path.join(tempfile.gettempdir(), "rva23-dropped.txt"))
