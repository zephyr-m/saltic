"""Упаковка команд и структур Intel Gen9 по описаниям genxml из Mesa."""
import struct as pystruct
import xml.etree.ElementTree as ET
from pathlib import Path


def load(path, excluded=frozenset()):
    defs = {}
    enums = {}
    root = ET.parse(path).getroot()
    for node in root:
        if node.tag == "import":
            skip = {e.get("name") for e in node.findall("exclude")}
            d, e = load(Path(path).parent / node.get("name"), skip)
            defs.update(d)
            enums.update(e)
    for node in root:
        if node.tag in ("struct", "instruction", "register"):
            name = node.get("name")
            if name not in excluded:
                defs[name] = node
        elif node.tag == "enum":
            enums[node.get("name")] = {v.get("name"): int(v.get("value"), 0) for v in node.findall("value")}
    for name in excluded:
        defs.pop(name, None)
    return defs, enums


class Packer:
    def __init__(self, path):
        self.defs, self.enums = load(path)

    def fields(self, node, base=0, prefix=""):
        out = []
        for child in node:
            if child.tag == "field":
                dword = int(child.get("dword", "0"))
                hi, lo = (int(x) for x in child.get("bits").split(":"))
                out.append((prefix + child.get("name"), base + dword * 32 + lo, base + dword * 32 + hi, child.get("type"), child.get("default")))
            elif child.tag == "group":
                count = int(child.get("count", "1") or 1)
                start = base + int(child.get("dword", "0")) * 32
                size = int(child.get("size", "0"))
                for i in range(count):
                    out += self.fields(child, start + i * size, f"{prefix}{i}_" if count > 1 else prefix)
        return out

    def length(self, name):
        node = self.defs[name]
        if node.get("length"):
            return int(node.get("length"))
        top = max(f[2] for f in self.fields(node))
        return top // 32 + 1

    def pack(self, name, **values):
        node = self.defs[name]
        words = self.length(name)
        bits = 0
        known = set()
        for fname, start, end, ftype, default in self.fields(node):
            key = "".join(ch for ch in fname if ch.isalnum() or ch == "_")
            width = end - start + 1
            value = None
            if ftype == "mbo":
                value = (1 << width) - 1
            if default is not None:
                value = int(default, 0)
            if key in values:
                value = values[key]
                known.add(key)
            if value is None:
                continue
            if ftype == "float":
                value = pystruct.unpack("<I", pystruct.pack("<f", float(value)))[0]
            elif ftype and ftype.startswith(("u", "s")) and ftype[1:].split(".")[0].isdigit() and "." in ftype:
                frac = int(ftype.split(".")[1])
                value = int(round(float(value) * (1 << frac)))
            if ftype in ("address", "offset"):
                value &= ((1 << (end + 1)) - 1) & ~((1 << (start % 32)) - 1) if False else (1 << 64) - 1
                lowbit = start % 32
                bits &= ~(((1 << width) - 1) << start)
                bits |= ((value >> lowbit) & ((1 << width) - 1)) << start
                continue
            value &= (1 << width) - 1
            bits |= value << start
        missing = set(values) - known
        if missing:
            raise KeyError(f"{name}: нет полей {sorted(missing)}")
        return [(bits >> (32 * i)) & 0xFFFFFFFF for i in range(words)]

    def names(self, name):
        return ["".join(ch for ch in f[0] if ch.isalnum() or ch == "_") for f in self.fields(self.defs[name])]
