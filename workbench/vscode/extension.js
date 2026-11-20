// extension — переход к определению по Ctrl+щелчку (и F12) в файлах .saltic.
// Куда вести, решает Saltic: `lens goto файл:строка:столбец`
// (workbench/agent/lens/jump — тот же код, что у SalticIDE). Здесь только
// вызов и прыжок; файл берётся с диска, как сохранён. Нет lens — сообщение
// (собрать: just lens-serve).

const vscode = require("vscode");
const childProcess = require("child_process");
const fs = require("fs");
const path = require("path");

const LENS = ".cache/build/workbench/lens";

let warned = false;

function lens(root, spot) {
  return new Promise((resolve, reject) => {
    const binary = path.join(root, LENS);
    if (fs.existsSync(binary) === false) {
      reject(new Error(`нет ${LENS} — собери его: just lens-serve`));
      return;
    }
    childProcess.execFile(binary, ["goto", spot], { cwd: root, timeout: 5000 }, (problem, stdout) => {
      if (problem) {
        reject(new Error(`lens goto ${spot} упал: ${problem.message}`));
        return;
      }
      resolve(stdout);
    });
  });
}

async function provide(document, position) {
  const folder = vscode.workspace.getWorkspaceFolder(document.uri);
  if (folder === undefined) return null;
  const root = folder.uri.fsPath;
  const relative = path.relative(root, document.uri.fsPath);
  let output;
  try {
    output = await lens(root, `${relative}:${position.line + 1}:${position.character}`);
  } catch (problem) {
    if (warned === false) vscode.window.showErrorMessage(`Saltic: ${problem.message}`);
    warned = true;
    return null;
  }
  const places = [];
  for (const line of output.split("\n")) {
    const found = line.match(/^(.+):(\d+):(\d+)$/);
    if (found === null) continue;
    places.push(new vscode.Location(vscode.Uri.file(path.join(root, found[1])), new vscode.Position(Number(found[2]) - 1, Number(found[3]))));
  }
  return places;
}

function activate(context) {
  context.subscriptions.push(vscode.languages.registerDefinitionProvider({ language: "saltic" }, { provideDefinition: provide }));
}

module.exports = { activate };
