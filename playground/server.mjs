import { createServer } from "node:http"
import { readFile, rm, writeFile } from "node:fs/promises"
import { spawn } from "node:child_process"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import { mkdtemp } from "node:fs/promises"
import { tmpdir } from "node:os"

const here = dirname(fileURLToPath(import.meta.url))
const root = resolve(here, "..")
const host = "127.0.0.1"
const port = Number(process.env.SALTIC_PLAYGROUND_PORT ?? 4173)
const bodyLimit = 256 * 1024
const runTimeout = 60_000
const assets = new Map([
    ["/", ["index.html", "text/html; charset=utf-8"]],
    ["/real.js", ["real.js", "text/javascript; charset=utf-8"]],
    ["/app.jtml", ["app.jtml", "application/json; charset=utf-8"]],
])

function send(response, status, type, body) {
    response.writeHead(status, {
        "content-type": type,
        "cache-control": "no-store",
    })
    response.end(body)
}

function sendJson(response, status, value) {
    send(response, status, "application/json; charset=utf-8", JSON.stringify(value))
}

async function readJson(request) {
    const chunks = []
    let size = 0

    for await (const chunk of request) {
        size += chunk.length
        if (size > bodyLimit) throw new Error("Исходник больше 256 КБ")
        chunks.push(chunk)
    }

    return JSON.parse(Buffer.concat(chunks).toString("utf8"))
}

async function runSaltic(source) {
    const directory = await mkdtemp(join(tmpdir(), "saltic-playground-"))
    const sourcePath = join(directory, "main.saltic")
    const outputPath = join(directory, "program.elf")
    await writeFile(sourcePath, source, "utf8")

    const startedAt = performance.now()
    const output = []
    let timedOut = false

    try {
        const result = await new Promise((resolveRun) => {
            const child = spawn("just", ["run", sourcePath, outputPath], {
                cwd: root,
                env: process.env,
                stdio: ["ignore", "pipe", "pipe"],
            })

            child.stdout.on("data", (chunk) => output.push(chunk.toString("utf8")))
            child.stderr.on("data", (chunk) => output.push(chunk.toString("utf8")))
            child.on("error", (error) => resolveRun({ exitCode: null, error: error.message }))
            child.on("close", (exitCode) => resolveRun({ exitCode, error: null }))

            const timer = setTimeout(() => {
                timedOut = true
                child.kill("SIGTERM")
            }, runTimeout)
            child.on("close", () => clearTimeout(timer))
        })

        return {
            ok: result.exitCode === 0 && !timedOut,
            exitCode: result.exitCode,
            timedOut,
            durationMs: Math.round(performance.now() - startedAt),
            output: result.error ? `${output.join("")}\n${result.error}`.trim() : output.join("").trim(),
        }
    } finally {
        await rm(directory, { recursive: true, force: true })
    }
}

const server = createServer(async (request, response) => {
    try {
        if (request.method === "GET" && assets.has(request.url)) {
            const [file, type] = assets.get(request.url)
            send(response, 200, type, await readFile(join(here, file)))
            return
        }

        if (request.method === "GET" && request.url === "/favicon.ico") {
            response.writeHead(204)
            response.end()
            return
        }

        if (request.method === "POST" && request.url === "/api/run") {
            const body = await readJson(request)
            if (typeof body.source !== "string" || body.source.trim() === "") {
                sendJson(response, 400, { ok: false, error: "Пустой исходник" })
                return
            }

            sendJson(response, 200, await runSaltic(body.source))
            return
        }

        sendJson(response, 404, { ok: false, error: "Не найдено" })
    } catch (error) {
        sendJson(response, 500, { ok: false, error: error.message })
    }
})

server.listen(port, host, () => {
    console.log(`Saltic Playground: http://${host}:${port}`)
})
