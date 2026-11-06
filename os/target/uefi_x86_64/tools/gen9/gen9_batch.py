"""Порция команд Gen9 «прямоугольник с текстурой» по igt rendercopy_gen9.c.

Запуск: python3 tools/gen9/gen9_batch.py <папка>/gen90.xml >
drivers/intel_gpu/generated/rect.saltic, где в папке — описания Mesa
src/intel/genxml: gen90.xml и всё, что он подключает (gen80, gen75, gen70,
gen60, gen50, gen45, gen40). Шейдер — ps_kernel_gen9 из igt (выборка из
текстуры). MOCS везде 0: таблицу MOCS без i915 никто не заполнял.

Выход — заготовка Saltic: BATCH (слова), RELOCS ([слово, вид]: 1 — адрес
порции, 2 — адрес цели, 3 — адрес текстуры; к слову прибавить адрес),
VERTICES (слово начала вершин), смещения состояния.
"""
import struct
import sys
import genxml

XML = sys.argv[1]
p = genxml.Packer(XML)

BATCH_BYTES = 8192
SPLIT = 2048
B8G8R8A8_UNORM = 0x0C0
R16G16_SSCALED = 0x0F6
R32G32_FLOAT = 0x085
R32G32B32A32_FLOAT = 0x000
BATCH, TARGET, TEXTURE = 1, 2, 3

words = [0] * (BATCH_BYTES // 4)
relocs = []
state_at = SPLIT
cmd_at = 0


def align_state(n):
    global state_at
    state_at = (state_at + n - 1) // n * n


def put_state(ws, align=4):
    global state_at
    align_state(align)
    at = state_at
    for i, w in enumerate(ws):
        words[at // 4 + i] = w
    state_at += len(ws) * 4
    return at


def emit(ws, reloc=()):
    global cmd_at
    for i, w in enumerate(ws):
        words[cmd_at // 4 + i] = w
    for index, kind in reloc:
        relocs.append((cmd_at // 4 + index, kind))
    cmd_at += len(ws) * 4


def f32(x):
    return struct.unpack("<I", struct.pack("<f", x))[0]


# Состояние (как gen8_bind_surfaces … gen6_create_scissor_rect)
align_state(32)
binding_at = state_at
state_at += 32
surface_common = dict(SurfaceType=1, SurfaceFormat=B8G8R8A8_UNORM, SurfaceVerticalAlignment=1, SurfaceHorizontalAlignment=1,
                      RenderCacheReadWriteMode=1, MipTailStartLOD=1, MOCS=0, TileMode=0,
                      ShaderChannelSelectRed=4, ShaderChannelSelectGreen=5, ShaderChannelSelectBlue=6, ShaderChannelSelectAlpha=7)
SURFACE_WORDS = p.length("RENDER_SURFACE_STATE")
dst_ss = put_state([0] * SURFACE_WORDS, 64)
src_ss = put_state([0] * SURFACE_WORDS, 64)
words[binding_at // 4] = dst_ss
words[binding_at // 4 + 1] = src_ss
sampler = put_state(p.pack("SAMPLER_STATE", MinModeFilter=0, MagModeFilter=0, TCXAddressControlMode=2, TCYAddressControlMode=2, TCZAddressControlMode=2), 64)
KERNEL = [0x0080005a, 0x2f403ae8, 0x3a0000c0, 0x008d0040,
          0x0080005a, 0x2f803ae8, 0x3a0000d0, 0x008d0040,
          0x02800031, 0x2e203a48, 0x0e8d0f40, 0x08840001,
          0x05800031, 0x20003a40, 0x0e8d0e20, 0x90031000]
kernel = put_state(KERNEL, 64)
vertices = put_state([0] * 9, 8)
cc_state = put_state(p.pack("COLOR_CALC_STATE"), 64)
blend = [0] * p.length("BLEND_STATE")
for i in range(16):
    blend += p.pack("BLEND_STATE_ENTRY", DestinationBlendFactor=17, SourceBlendFactor=1, ColorBlendFunction=0, PreBlendColorClampEnable=1)
blend_state = put_state(blend, 64)
cc_viewport = put_state(p.pack("CC_VIEWPORT", MinimumDepth=-1e35, MaximumDepth=1e35), 32)
sf_clip = put_state(p.pack("SF_CLIP_VIEWPORT", XMinClipGuardband=0.0, XMaxClipGuardband=1.0, YMinClipGuardband=0.0, YMaxClipGuardband=1.0), 64)
scissor = put_state(p.pack("SCISSOR_RECT"), 64)

# Команды (порядок _gen9_render_op)
emit(p.pack("PIPELINE_SELECT", PipelineSelection=0, MaskBits=3))
emit(p.pack("STATE_SIP"))
for stage in ("VS", "HS", "DS", "GS", "PS"):
    emit(p.pack(f"3DSTATE_PUSH_CONSTANT_ALLOC_{stage}"))
sba = p.pack("STATE_BASE_ADDRESS", GeneralStateBaseAddressModifyEnable=1, SurfaceStateBaseAddressModifyEnable=1,
             DynamicStateBaseAddressModifyEnable=1, InstructionBaseAddressModifyEnable=1,
             GeneralStateBufferSizeModifyEnable=1, GeneralStateBufferSize=0xfffff,
             DynamicStateBufferSizeModifyEnable=1, DynamicStateBufferSize=1,
             IndirectObjectBufferSizeModifyEnable=1, IndirectObjectBufferSize=0xfffff,
             InstructionBuffersizeModifyEnable=1, InstructionBufferSize=1)
names = p.fields(p.defs["STATE_BASE_ADDRESS"])
def word_of(struct_name, field):
    for fname, start, end, ftype, default in p.fields(p.defs[struct_name]):
        if "".join(ch for ch in fname if ch.isalnum() or ch == "_") == field:
            return start // 32
    raise KeyError(field)
emit(sba, [(word_of("STATE_BASE_ADDRESS", f), BATCH) for f in ("SurfaceStateBaseAddress", "DynamicStateBaseAddress", "InstructionBaseAddress")])
emit(p.pack("3DSTATE_VIEWPORT_STATE_POINTERS_CC", CCViewportPointer=cc_viewport))
emit(p.pack("3DSTATE_VIEWPORT_STATE_POINTERS_SF_CLIP", SFClipViewportPointer=sf_clip))
emit(p.pack("3DSTATE_URB_VS", VSNumberofURBEntries=64, VSURBEntryAllocationSize=1, VSURBStartingAddress=4))
emit(p.pack("3DSTATE_URB_GS", GSURBStartingAddress=4))
emit(p.pack("3DSTATE_URB_HS", HSURBStartingAddress=4))
emit(p.pack("3DSTATE_URB_DS", DSURBStartingAddress=4))
emit(p.pack("3DSTATE_BLEND_STATE_POINTERS", BlendStatePointer=blend_state, BlendStatePointerValid=1))
emit(p.pack("3DSTATE_CC_STATE_POINTERS", ColorCalcStatePointer=cc_state, ColorCalcStatePointerValid=1))
emit(p.pack("3DSTATE_MULTISAMPLE"))
emit(p.pack("3DSTATE_SAMPLE_MASK", SampleMask=1))
emit(p.pack("3DSTATE_WM_HZ_OP"))
emit(p.pack("3DSTATE_CONSTANT_HS"))
emit(p.pack("3DSTATE_HS"))
emit(p.pack("3DSTATE_BINDING_TABLE_POINTERS_HS"))
emit(p.pack("3DSTATE_SAMPLER_STATE_POINTERS_HS"))
emit(p.pack("3DSTATE_TE"))
emit(p.pack("3DSTATE_CONSTANT_GS"))
emit(p.pack("3DSTATE_GS"))
emit(p.pack("3DSTATE_BINDING_TABLE_POINTERS_GS"))
emit(p.pack("3DSTATE_SAMPLER_STATE_POINTERS_GS"))
emit(p.pack("3DSTATE_CONSTANT_DS"))
emit(p.pack("3DSTATE_DS"))
emit(p.pack("3DSTATE_BINDING_TABLE_POINTERS_DS"))
emit(p.pack("3DSTATE_SAMPLER_STATE_POINTERS_DS"))
emit(p.pack("3DSTATE_CONSTANT_VS"))
emit(p.pack("3DSTATE_BINDING_TABLE_POINTERS_VS"))
emit(p.pack("3DSTATE_SAMPLER_STATE_POINTERS_VS"))
emit(p.pack("3DSTATE_VS"))
emit(p.pack("3DSTATE_STREAMOUT"))
emit(p.pack("3DSTATE_CLIP"))
emit(p.pack("3DSTATE_SBE", NumberofSFOutputAttributes=1, ForceVertexURBEntryReadLength=1, ForceVertexURBEntryReadOffset=1,
            VertexURBEntryReadLength=1, VertexURBEntryReadOffset=1, **{"0_AttributeActiveComponentFormat": 3}))
emit(p.pack("3DSTATE_SBE_SWIZ"))
emit(p.pack("3DSTATE_RASTER", FrontWinding=1, CullMode=1))
emit(p.pack("3DSTATE_SF"))
emit(p.pack("3DSTATE_WM", BarycentricInterpolationMode=1))
emit(p.pack("3DSTATE_CONSTANT_PS"))
emit(p.pack("3DSTATE_PS", KernelStartPointer0=kernel, BindingTableEntryCount=2, SamplerCount=1, **{"16PixelDispatchEnable": 1},
            MaximumNumberofThreadsPerPSD=62, DispatchGRFStartRegisterForConstantSetupData0=6))
emit(p.pack("3DSTATE_PS_BLEND", HasWriteableRT=1))
emit(p.pack("3DSTATE_PS_EXTRA", PixelShaderValid=1, AttributeEnable=1))
emit(p.pack("3DSTATE_BINDING_TABLE_POINTERS_PS", PointertoPSBindingTable=binding_at))
emit(p.pack("3DSTATE_SAMPLER_STATE_POINTERS_PS", PointertoPSSamplerState=sampler))
emit(p.pack("3DSTATE_SCISSOR_STATE_POINTERS", ScissorRectPointer=scissor))
emit(p.pack("3DSTATE_WM_DEPTH_STENCIL"))
emit(p.pack("3DSTATE_DEPTH_BUFFER"))
emit(p.pack("3DSTATE_HIER_DEPTH_BUFFER"))
emit(p.pack("3DSTATE_STENCIL_BUFFER"))
emit(p.pack("3DSTATE_CLEAR_PARAMS", DepthClearValueValid=1))
drawing_at = cmd_at
emit(p.pack("3DSTATE_DRAWING_RECTANGLE"))
vb_header = p.pack("3DSTATE_VERTEX_BUFFERS")
vb_header[0] = (vb_header[0] & ~0xFF) | (1 + p.length("VERTEX_BUFFER_STATE") - 2)
emit(vb_header)
vbs = p.pack("VERTEX_BUFFER_STATE", VertexBufferIndex=0, AddressModifyEnable=1, MOCS=0, BufferPitch=12, BufferStartingAddress=vertices, BufferSize=36)
emit(vbs, [(word_of("VERTEX_BUFFER_STATE", "BufferStartingAddress"), BATCH)])
ve_header = p.pack("3DSTATE_VERTEX_ELEMENTS")
ve_header[0] = (ve_header[0] & ~0xFF) | (1 + 3 * p.length("VERTEX_ELEMENT_STATE") - 2)
emit(ve_header)
emit(p.pack("VERTEX_ELEMENT_STATE", VertexBufferIndex=0, Valid=1, SourceElementFormat=R32G32B32A32_FLOAT, SourceElementOffset=0,
            Component0Control=2, Component1Control=2, Component2Control=2, Component3Control=2))
emit(p.pack("VERTEX_ELEMENT_STATE", VertexBufferIndex=0, Valid=1, SourceElementFormat=R16G16_SSCALED, SourceElementOffset=0,
            Component0Control=1, Component1Control=1, Component2Control=2, Component3Control=3))
emit(p.pack("VERTEX_ELEMENT_STATE", VertexBufferIndex=0, Valid=1, SourceElementFormat=R32G32_FLOAT, SourceElementOffset=4,
            Component0Control=1, Component1Control=1, Component2Control=2, Component3Control=3))
emit(p.pack("3DSTATE_VF_TOPOLOGY", PrimitiveTopologyType=15))
emit(p.pack("3DSTATE_VF"))
emit(p.pack("3DSTATE_VF_INSTANCING"))
emit(p.pack("3DPRIMITIVE", VertexCountPerInstance=3, InstanceCount=1))
emit(p.pack("MI_BATCH_BUFFER_END"))
assert cmd_at <= SPLIT, cmd_at

# Поверхности: ширина/высота/шаг — вписывает драйвер; здесь — шаблон без них
dst = p.pack("RENDER_SURFACE_STATE", **surface_common)
src = p.pack("RENDER_SURFACE_STATE", **surface_common)
for i, w in enumerate(dst):
    words[dst_ss // 4 + i] = w
for i, w in enumerate(src):
    words[src_ss // 4 + i] = w
base_word = word_of("RENDER_SURFACE_STATE", "SurfaceBaseAddress")
relocs.append((dst_ss // 4 + base_word, TARGET))
relocs.append((src_ss // 4 + base_word, TEXTURE))
size_word = word_of("RENDER_SURFACE_STATE", "Width")
pitch_word = word_of("RENDER_SURFACE_STATE", "SurfacePitch")
used = state_at
drawing_word = drawing_at // 4 + word_of("3DSTATE_DRAWING_RECTANGLE", "ClippedDrawingRectangleXMax")
start = p.pack("MI_BATCH_BUFFER_START")
before = p.pack("PIPE_CONTROL", CommandStreamerStallEnable=1, StateCacheInvalidationEnable=1, ConstantCacheInvalidationEnable=1,
                VFCacheInvalidationEnable=1, TextureCacheInvalidationEnable=1, InstructionCacheInvalidateEnable=1)
after = p.pack("PIPE_CONTROL", CommandStreamerStallEnable=1, RenderTargetCacheFlushEnable=1, DCFlushEnable=1)

lines = []
lines.append("-- intel_gpu/generated/rect — СГЕНЕРИРОВАНО tools/gen9/gen9_batch.py по igt")
lines.append("-- rendercopy_gen9.c и описаниям Mesa genxml (gen90.xml); руками не править.")
lines.append("-- Порция команд Gen9 «прямоугольник с текстурой»: команды с 0, состояние")
lines.append(f"-- с {SPLIT}; RELOCS — [слово, вид]: 1 — адрес порции, 2 — цели, 3 — текстуры.")
lines.append("-- Ширина, высота и шаг поверхностей (SIZE_WORD, PITCH_WORD от начала их")
lines.append("-- состояния: (высота−1)·65536 + (ширина−1); шаг−1) и вершины (VERTICES,")
lines.append("-- 9 слов: на вершину x | y·65536 и две доли текстуры float) и правый нижний")
lines.append("-- угол области рисования (DRAWING_WORD: (высота−1)·65536 + ширина−1) вписывает")
lines.append("-- драйвер. Кольцо: BEFORE (сброс кэшей), START и адрес порции, AFTER.")
lines.append("")
lines.append(f"BATCH_BYTES = {BATCH_BYTES}")
lines.append(f"USED = {used}")
lines.append(f"DESTINATION = {dst_ss}")
lines.append(f"SOURCE = {src_ss}")
lines.append(f"SIZE_WORD = {size_word}")
lines.append(f"PITCH_WORD = {pitch_word}")
lines.append(f"VERTICES = {vertices}")
lines.append(f"DRAWING_WORD = {drawing_word}")
lines.append(f"START = {start[0]}")
lines.append("BEFORE = [" + ", ".join(str(w) for w in before) + "]")
lines.append("AFTER = [" + ", ".join(str(w) for w in after) + "]")
lines.append("RELOCS = [" + ", ".join(f"[{a}, {k}]" for a, k in relocs) + "]")
top = max(i for i, w in enumerate(words) if w) + 1
lines.append("BATCH = [")
chunk = [str(w) for w in words[:top]]
for i in range(0, len(chunk), 12):
    lines.append("    " + ", ".join(chunk[i:i + 12]) + ("," if i + 12 < len(chunk) else ""))
lines.append("]")
print("\n".join(lines))
