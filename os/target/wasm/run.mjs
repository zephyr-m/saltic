// run — модуль Saltic под WASI в Node:
//   node os/target/wasm/run.mjs <модуль.wasm> [аргументы…]
// Каталог программы (fd 3) — текущий. Код выхода — код программы.
import { readFile } from "node:fs/promises";
import { WASI } from "node:wasi";

const [, , file, ...rest] = process.argv;
const wasi = new WASI({ version: "preview1", args: [file, ...rest], preopens: { ".": process.cwd() } });
const module = await WebAssembly.compile(await readFile(file));
const instance = await WebAssembly.instantiate(module, wasi.getImportObject());
process.exitCode = wasi.start(instance);
