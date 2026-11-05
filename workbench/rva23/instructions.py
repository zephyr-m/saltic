"""instructions — список команд RVA23 для генератора: имя и шаблон операндов.

Операнд в шаблоне — {вид}. Виды описаны в generate.KINDS. Лишнее не страшно:
команду, которую ассемблер не принял или разобрал под другим именем,
генератор выбросит и назовёт в отчёте.
"""


def scalar():
    rows = []
    def add(names, template):
        for n in names.split():
            rows.append((n, template))
    # RV64I
    add("add sub sll slt sltu xor srl sra or and addw subw sllw srlw sraw", "{x}, {x}, {x}")
    add("addi slti sltiu xori ori andi addiw", "{x}, {x}, {si12}")
    add("slli srli srai", "{x}, {x}, {ui6}")
    add("slliw srliw sraiw", "{x}, {x}, {ui5}")
    add("lb lh lw ld lbu lhu lwu", "{x}, {si12}({x})")
    add("sb sh sw sd", "{x}, {si12}({x})")
    add("lui auipc", "{x}, {ui20}")
    add("beq bne blt bge bltu bgeu", "{x}, {x}, {boff}")
    add("jal", "{x}, {joff}")
    add("jalr", "{x}, {si12}({x})")
    add("ecall ebreak fence.tso pause fence.i", "")
    rows.append(("fence", "{fence}, {fence}"))
    # M
    add("mul mulh mulhsu mulhu div divu rem remu mulw divw divuw remw remuw", "{x}, {x}, {x}")
    # A
    for order in ["", ".aq", ".rl", ".aqrl"]:
        for width in ["w", "d"]:
            rows.append((f"lr.{width}{order}", "{x}, ({x})"))
            rows.append((f"sc.{width}{order}", "{x}, {x}, ({x})"))
            for op in "amoswap amoadd amoxor amoand amoor amomin amomax amominu amomaxu amocas".split():
                rows.append((f"{op}.{width}{order}", "{x}, {x}, ({x})"))
    # Zicsr, Zicntr
    add("csrrw csrrs csrrc", "{x}, {ui12}, {x}")
    add("csrrwi csrrsi csrrci", "{x}, {ui12}, {ui5}")
    # F, D, Zfhmin
    add("flw fld flh", "{f}, {si12}({x})")
    add("fsw fsd fsh", "{f}, {si12}({x})")
    for t in "sd":
        add(f"fadd.{t} fsub.{t} fmul.{t} fdiv.{t}", "{f}, {f}, {f}")
        add(f"fsgnj.{t} fsgnjn.{t} fsgnjx.{t} fmin.{t} fmax.{t} fminm.{t} fmaxm.{t}", "{f}, {f}, {f}")
        add(f"fsqrt.{t} fround.{t} froundnx.{t}", "{f}, {f}")
        add(f"fmadd.{t} fmsub.{t} fnmsub.{t} fnmadd.{t}", "{f}, {f}, {f}, {f}")
        add(f"feq.{t} flt.{t} fle.{t} fleq.{t} fltq.{t}", "{x}, {f}, {f}")
        add(f"fclass.{t}", "{x}, {f}")
        add(f"fcvt.w.{t} fcvt.wu.{t} fcvt.l.{t} fcvt.lu.{t}", "{x}, {f}")
        add(f"fcvt.{t}.w fcvt.{t}.wu fcvt.{t}.l fcvt.{t}.lu", "{f}, {x}")
        rows.append((f"fli.{t}", "{f}, {fli}"))
    add("fmv.x.w fmv.x.d fmv.x.h fmvh.x.d", "{x}, {f}")
    rows.append(("fcvtmod.w.d", "{x}, {f}, rtz"))
    add("fmv.w.x fmv.d.x fmv.h.x", "{f}, {x}")
    add("fmvp.d.x", "{f}, {x}, {x}")
    add("fcvt.s.d fcvt.d.s fcvt.s.h fcvt.h.s fcvt.d.h fcvt.h.d", "{f}, {f}")
    # Zba, Zbb, Zbs, Zicond
    add("sh1add sh2add sh3add add.uw sh1add.uw sh2add.uw sh3add.uw", "{x}, {x}, {x}")
    add("slli.uw", "{x}, {x}, {ui6}")
    add("andn orn xnor max maxu min minu rol ror rolw rorw bclr bext binv bset czero.eqz czero.nez", "{x}, {x}, {x}")
    add("clz ctz cpop clzw ctzw cpopw sext.b sext.h zext.h orc.b rev8", "{x}, {x}")
    add("rori bclri bexti binvi bseti", "{x}, {x}, {ui6}")
    add("roriw", "{x}, {x}, {ui5}")
    # Zicbom, Zicboz, Zicbop, Zawrs, Zihintntl, Zimop
    add("cbo.clean cbo.flush cbo.inval cbo.zero", "({x})")
    add("prefetch.i prefetch.r prefetch.w", "{pre}({x})")
    add("wrs.nto wrs.sto ntl.p1 ntl.pall ntl.s1 ntl.all", "")
    for n in range(32):
        rows.append((f"mop.r.{n}", "{x}, {x}"))
    for n in range(8):
        rows.append((f"mop.rr.{n}", "{x}, {x}, {x}"))
    return rows


def compressed():
    rows = []
    def add(names, template):
        for n in names.split():
            rows.append((n, template))
    add("c.addi", "{xnz}, {nzsi6}")
    add("c.addiw", "{xnz}, {si6}")
    add("c.li", "{xnz}, {si6}")
    add("c.lui", "{xlui}, {clui}")
    add("c.addi16sp", "x2, {sp16}")
    add("c.addi4spn", "{xc}, x2, {spn}")
    add("c.slli", "{xnz}, {nzui6}")
    add("c.srli c.srai", "{xc}, {nzui6}")
    add("c.andi", "{xc}, {si6}")
    add("c.mv c.add", "{xnz}, {xnz}")
    add("c.jr c.jalr", "{xnz}")
    add("c.sub c.xor c.or c.and c.subw c.addw c.mul", "{xc}, {xc}")
    add("c.j", "{cjoff}")
    add("c.beqz c.bnez", "{xc}, {cboff}")
    add("c.lw", "{xc}, {cw}({xc})")
    add("c.ld", "{xc}, {cd}({xc})")
    add("c.sw", "{xc}, {cw}({xc})")
    add("c.sd", "{xc}, {cd}({xc})")
    add("c.fld", "{fc}, {cd}({xc})")
    add("c.fsd", "{fc}, {cd}({xc})")
    add("c.lwsp", "{xnz}, {cwsp}(x2)")
    add("c.ldsp", "{xnz}, {cdsp}(x2)")
    add("c.fldsp", "{f}, {cdsp}(x2)")
    add("c.swsp", "{x}, {cwsp}(x2)")
    add("c.sdsp", "{x}, {cdsp}(x2)")
    add("c.fsdsp", "{f}, {cdsp}(x2)")
    add("c.nop c.ebreak c.ntl.p1 c.ntl.pall c.ntl.s1 c.ntl.all", "")
    for n in range(1, 16, 2):
        rows.append((f"c.mop.{n}", ""))
    add("c.lbu c.sb", "{xc}, {cb}({xc})")
    add("c.lhu c.lh c.sh", "{xc}, {ch}({xc})")
    add("c.zext.b c.sext.b c.zext.h c.sext.h c.zext.w c.not", "{xc}")
    return rows


def vector():
    rows = []
    def add(names, template):
        for n in names.split():
            rows.append((n, template))
    rows.append(("vsetvli", "{x}, {x}, {vtype}"))
    rows.append(("vsetivli", "{x}, {ui5}, {vtype}"))
    rows.append(("vsetvl", "{x}, {x}, {x}"))
    # загрузки и сохранения
    for eew in [8, 16, 32, 64]:
        rows.append((f"vle{eew}.v", "{v}, ({x}){vm}"))
        rows.append((f"vse{eew}.v", "{v}, ({x}){vm}"))
        rows.append((f"vle{eew}ff.v", "{v}, ({x}){vm}"))
        rows.append((f"vlse{eew}.v", "{v}, ({x}), {x}{vm}"))
        rows.append((f"vsse{eew}.v", "{v}, ({x}), {x}{vm}"))
        for kind in ["vluxei", "vloxei", "vsuxei", "vsoxei"]:
            rows.append((f"{kind}{eew}.v", "{v}, ({x}), {v}{vm}"))
        for nf in range(2, 9):
            rows.append((f"vlseg{nf}e{eew}.v", "{v}, ({x}){vm}"))
            rows.append((f"vsseg{nf}e{eew}.v", "{v}, ({x}){vm}"))
            rows.append((f"vlseg{nf}e{eew}ff.v", "{v}, ({x}){vm}"))
            rows.append((f"vlsseg{nf}e{eew}.v", "{v}, ({x}), {x}{vm}"))
            rows.append((f"vssseg{nf}e{eew}.v", "{v}, ({x}), {x}{vm}"))
            for kind in ["vluxseg", "vloxseg", "vsuxseg", "vsoxseg"]:
                rows.append((f"{kind}{nf}ei{eew}.v", "{v}, ({x}), {v}{vm}"))
        for nf in [1, 2, 4, 8]:
            rows.append((f"vl{nf}re{eew}.v", "{v}, ({x})"))
    for nf in [1, 2, 4, 8]:
        rows.append((f"vs{nf}r.v", "{v}, ({x})"))
    add("vlm.v vsm.v", "{v}, ({x})")
    # целочисленная арифметика: какие формы бывают — пробуем все, ассемблер отсеет
    integer = ("vadd vsub vrsub vminu vmin vmaxu vmax vand vor vxor vrgather vslideup vslidedown "
               "vadc vmadc vsbc vmsbc vmerge vmseq vmsne vmsltu vmslt vmsleu vmsle vmsgtu vmsgt "
               "vsaddu vsadd vssubu vssub vsll vsmul vsrl vsra vssrl vssra vnsrl vnsra vnclipu vnclip "
               "vwredsumu vwredsum vandn vrol vror vwsll "
               "vredsum vredand vredor vredxor vredminu vredmin vredmaxu vredmax "
               "vaaddu vaadd vasubu vasub vslide1up vslide1down vdivu vdiv vremu vrem "
               "vmulhu vmul vmulhsu vmulh vmadd vnmsub vmacc vnmsac "
               "vwaddu vwadd vwsubu vwsub vwmulu vwmulsu vwmul vwmaccu vwmacc vwmaccus vwmaccsu "
               "vrgatherei16 vcompress vmandn vmand vmor vmxor vmorn vmnand vmnor vmxnor")
    floating = ("vfadd vfredusum vfsub vfredosum vfmin vfredmin vfmax vfredmax vfsgnj vfsgnjn vfsgnjx "
                "vfslide1up vfslide1down vfmerge vmfeq vmfle vmflt vmfne vmfgt vmfge vfdiv vfrdiv vfmul vfrsub "
                "vfmadd vfnmadd vfmsub vfnmsub vfmacc vfnmacc vfmsac vfnmsac vfwadd vfwredusum vfwsub "
                "vfwredosum vfwmul vfwmacc vfwnmacc vfwmsac vfwnmsac")
    for op in integer.split():
        rows.append((f"{op}.vv", "{v}, {v}, {v}{vm}"))
        rows.append((f"{op}.vx", "{v}, {v}, {x}{vm}"))
        rows.append((f"{op}.vi", "{v}, {v}, {si5}{vm}"))
        rows.append((f"{op}.vi", "{v}, {v}, {ui5}{vm}"))
        rows.append((f"{op}.vs", "{v}, {v}, {v}{vm}"))
        rows.append((f"{op}.vm", "{v}, {v}, {v}"))
        rows.append((f"{op}.mm", "{v}, {v}, {v}"))
        rows.append((f"{op}.vvm", "{v}, {v}, {v}, v0"))
        rows.append((f"{op}.vxm", "{v}, {v}, {x}, v0"))
        rows.append((f"{op}.vim", "{v}, {v}, {si5}, v0"))
        rows.append((f"{op}.wv", "{v}, {v}, {v}{vm}"))
        rows.append((f"{op}.wx", "{v}, {v}, {x}{vm}"))
        rows.append((f"{op}.wi", "{v}, {v}, {ui5}{vm}"))
        rows.append((f"{op}.vx", "{v}, {x}, {v}{vm}"))
        rows.append((f"{op}.vv", "{v}, {v}, {v}"))
        rows.append((f"{op}.vx", "{v}, {v}, {x}"))
        rows.append((f"{op}.vi", "{v}, {v}, {si5}"))
    for op in floating.split():
        rows.append((f"{op}.vv", "{v}, {v}, {v}{vm}"))
        rows.append((f"{op}.vf", "{v}, {v}, {f}{vm}"))
        rows.append((f"{op}.vf", "{v}, {f}, {v}{vm}"))
        rows.append((f"{op}.vs", "{v}, {v}, {v}{vm}"))
        rows.append((f"{op}.vfm", "{v}, {v}, {f}, v0"))
        rows.append((f"{op}.wv", "{v}, {v}, {v}{vm}"))
        rows.append((f"{op}.wf", "{v}, {v}, {f}{vm}"))
    # одноместные и особые
    add("vmv.v.v", "{v}, {v}")
    add("vmv.v.x", "{v}, {x}")
    add("vmv.v.i", "{v}, {si5}")
    add("vfmv.v.f", "{v}, {f}")
    add("vmv.x.s", "{x}, {v}")
    add("vmv.s.x", "{v}, {x}")
    add("vfmv.f.s", "{f}, {v}")
    add("vfmv.s.f", "{v}, {f}")
    add("vmv1r.v vmv2r.v vmv4r.v vmv8r.v", "{v}, {v}")
    add("vcpop.m vfirst.m", "{x}, {v}{vm}")
    add("vmsbf.m vmsif.m vmsof.m viota.m", "{v}, {v}{vm}")
    add("vid.v", "{v}{vm}")
    add("vzext.vf2 vsext.vf2 vzext.vf4 vsext.vf4 vzext.vf8 vsext.vf8", "{v}, {v}{vm}")
    add("vbrev.v vbrev8.v vrev8.v vclz.v vctz.v vcpop.v", "{v}, {v}{vm}")
    add("vfsqrt.v vfrsqrt7.v vfrec7.v vfclass.v", "{v}, {v}{vm}")
    for prefix in ["vfcvt", "vfwcvt", "vfncvt"]:
        for conv in ["xu.f", "x.f", "f.xu", "f.x", "rtz.xu.f", "rtz.x.f", "f.f", "rod.f.f"]:
            for shape in ["v", "w"]:
                rows.append((f"{prefix}.{conv}.{shape}", "{v}, {v}{vm}"))
    return rows


def all_rows():
    return [("32", r) for r in scalar()] + [("16", r) for r in compressed()] + [("32", r) for r in vector()]
