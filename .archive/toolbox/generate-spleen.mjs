import { readFileSync, writeFileSync } from "node:fs"

const targetPath = process.argv[2]
const sourcePaths = process.argv.slice(3)

if (!targetPath || sourcePaths.length === 0) {
    throw new Error("usage: node toolbox/generate-spleen.mjs TARGET.saltic FONT.bdf...")
}

const wanted = [
    ...Array.from({ length: 95 }, (_, index) => 32 + index),
    1025,
    ...Array.from({ length: 64 }, (_, index) => 1040 + index),
    1105,
]

function readFont(sourcePath) {
    const glyphs = new Map()
    const lines = readFileSync(sourcePath, "utf8").split(/\r?\n/)
    const bounds = lines.find((line) => line.startsWith("FONTBOUNDINGBOX "))
    const [width, height] = bounds.slice(16).split(" ").map(Number)
    const shift = Math.ceil(width / 8) * 8 - width
    let encoding = -1
    let bitmap = null

    for (const line of lines) {
        if (line.startsWith("ENCODING ")) {
            encoding = Number(line.slice(9))
            continue
        }
        if (line === "BITMAP") {
            bitmap = []
            continue
        }
        if (line === "ENDCHAR") {
            if (encoding >= 0 && bitmap) glyphs.set(encoding, bitmap)
            encoding = -1
            bitmap = null
            continue
        }
        if (bitmap && /^[0-9A-F]+$/.test(line)) {
            bitmap.push(Number.parseInt(line, 16) / 2 ** shift)
        }
    }

    for (const codepoint of wanted) {
        const glyph = glyphs.get(codepoint)
        if (!glyph || glyph.length !== height) {
            throw new Error(`missing ${width}x${height} glyph U+${codepoint.toString(16).toUpperCase()}`)
        }
    }
    return { width, height, glyphs }
}

const blocks = sourcePaths.map((sourcePath) => {
    const font = readFont(sourcePath)
    const name = `GLYPHS_${font.width}X${font.height}`
    const rows = wanted.map((codepoint) => {
        let bitmap = font.glyphs.get(codepoint)
        if (font.width === 32) {
            bitmap = bitmap.flatMap((row) => [Math.floor(row / 65536), row % 65536])
        }
        return `    [${bitmap.join(", ")}]`
    })
    return `${name} = [\n${rows.join(",\n")}\n]`
})

writeFileSync(targetPath, `${blocks.join("\n\n")}\n`)
