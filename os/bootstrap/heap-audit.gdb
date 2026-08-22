set pagination off
set confirm off
set print address off
set architecture riscv:rv32

python
import gdb
import os

locations = {}
map_path = os.environ.get("SALTIC_HEAP_SOURCE_MAP", "")
if map_path:
    with open(map_path, "r", encoding="utf-8") as source_map:
        for raw in source_map:
            symbol, separator, location = raw.strip().partition("|")
            if separator:
                locations[symbol] = location

heap_base = int(gdb.parse_and_eval("&saltic_heap"))
heap_end = int(gdb.parse_and_eval("&saltic_heap_end"))
heap_limit = heap_end - heap_base
last_used = 0

def symbol_at(address):
    description = gdb.execute(
        "info symbol 0x%x" % address,
        to_string=True,
    ).strip()
    if description.startswith("No symbol"):
        return "0x%08x" % address, "строка неизвестна"
    symbol = description.split(" + ", 1)[0].split(" in section", 1)[0]
    return symbol, locations.get(symbol, "строка неизвестна")

def show_address(prefix, address):
    symbol, location = symbol_at(address)
    gdb.write("%s%s — %s\n" % (prefix, symbol, location))

def heap_used():
    return int(gdb.parse_and_eval("$s1")) - heap_base

def show_heap(name):
    global last_used
    used = heap_used()
    delta = used - last_used
    percent = used * 100.0 / heap_limit
    gdb.write(
        "[heap] %-24s %7.2f MiB  +%7.2f MiB  %5.1f%%\n"
        % (name, used / 1048576.0, delta / 1048576.0, percent)
    )
    last_used = used

def read_word(address):
    memory = gdb.selected_inferior().read_memory(address, 4)
    return int.from_bytes(bytes(memory), byteorder="little", signed=False)

def show_stack():
    frame = int(gdb.parse_and_eval("$s0"))
    depth = 0
    while frame and depth < 24:
        try:
            return_address = read_word(frame - 4)
            previous = read_word(frame - 8)
        except gdb.MemoryError:
            gdb.write("  стек оборван: недоступна память 0x%08x\n" % frame)
            return
        if return_address == 0:
            return
        show_address("  #%02d " % depth, return_address)
        if previous == 0 or previous <= frame:
            return
        frame = previous
        depth += 1

class PhaseBreakpoint(gdb.Breakpoint):
    def __init__(self, symbol, title):
        super().__init__(symbol, internal=True)
        self.title = title

    def stop(self):
        show_heap(self.title)
        show_address("       ", int(gdb.parse_and_eval("$pc")))
        return False

class OutOfMemoryBreakpoint(gdb.Breakpoint):
    def stop(self):
        gdb.write("\n")
        show_heap("КУЧА ИСЧЕРПАНА")
        gdb.write("       лимит: %.2f MiB\n" % (heap_limit / 1048576.0))
        show_address(
            "       непосредственный вызов: ",
            int(gdb.parse_and_eval("$ra")),
        )
        gdb.write("       стек Saltic:\n")
        show_stack()
        return True

phases = [
    ("saltic_seed_parser_load_modules", "загрузка модулей"),
    ("saltic_seed_checker_check", "проверка"),
    ("saltic_seed_compiler_compile", "компиляция"),
    ("saltic_seed_compiler_state_collect_top_level", "таблицы верхнего уровня"),
    ("saltic_seed_compiler_state_header", "заголовок assembly"),
    ("saltic_seed_compiler_state_start", "точка входа"),
    ("saltic_seed_compiler_codegen_compile_functions", "генерация функций"),
    ("saltic_seed_runtime_runtime_assembly", "подключение runtime"),
    ("saltic_seed_compiler_state_finish_data", "секция данных"),
    ("saltic_seed_compiler_state_render_lines", "сборка assembly"),
]

for phase_symbol, phase_title in phases:
    PhaseBreakpoint(phase_symbol, phase_title)

OutOfMemoryBreakpoint("rt_out_of_memory", internal=True)
gdb.execute("continue")
end

quit
