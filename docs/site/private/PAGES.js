// Страницы пульта — одно меню на всех страницах: прибито к низу экрана, всегда на одном месте,
// не прыгает и не уезжает. Подключается последним скриптом; текущая страница — по имени файла.
// У каждой плитки своя весточка: видно, что где, не заходя внутрь.
const PAGES = [
  ["CONSOLE-LOOK.html", "Пульт", "колесо, Acer, суть"],
  ["CHECK-LOOK.html", "Проверка", "14.11: <span class=\"fine\">24 884 ✓</span>, провалов 0"],
  [null, "Тарантул", "страница скоро"],
  [null, "IDE", "SalticIDE · страница скоро"]
];
(() => {
  const here = location.pathname.split("/").pop();
  const css = document.createElement("style");
  css.textContent = `
.dock { position: fixed; left: 50%; bottom: 12px; transform: translateX(-50%); z-index: 20; width: min(880px, calc(100% - 32px));
  display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; padding: 8px; box-sizing: border-box;
  background: rgba(14, 18, 26, .92); backdrop-filter: blur(10px); border: 1px solid #232b38; border-radius: 16px;
  box-shadow: 0 18px 50px rgba(0, 0, 0, .55); font-family: "Onest", system-ui, sans-serif; }
.dock .pg { display: grid; grid-template-columns: auto 1fr; gap: 1px 10px; align-items: center; padding: 8px 12px; border-radius: 11px;
  border: 1px solid transparent; background: #161c28; color: #eef1f6; text-decoration: none; min-width: 0; transition: border-color .2s, background .2s; }
.dock a.pg:hover { border-color: #46c8ff; background: #18202c; }
.dock .pg i { grid-row: span 2; font: 700 20px/1 "JetBrains Mono", monospace; font-style: normal; color: #5d6675; }
.dock .pg b { font: 600 14px "Onest", system-ui, sans-serif; }
.dock .pg small { font: 400 11px "JetBrains Mono", monospace; color: #8b94a4; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.dock .pg[aria-current="page"] { border-color: #46c8ff; background: #46c8ff; }
.dock .pg[aria-current="page"] i, .dock .pg[aria-current="page"] b, .dock .pg[aria-current="page"] small { color: #06121a; }
.dock .pg .fine { color: #6dff9a; }
.dock .pg[aria-current="page"] .fine { color: #06121a; font-weight: 600; }
.dock .pg.soon { opacity: .5; }
@media (max-width: 760px) { .dock { grid-template-columns: repeat(2, 1fr); } .dock .pg small { display: none; } }`;
  document.head.appendChild(css);
  const dock = document.createElement("nav"); dock.className = "dock"; dock.setAttribute("aria-label", "Страницы пульта");
  dock.innerHTML = PAGES.map(([file, name, note], k) => {
    const inner = `<i>${k + 1}</i><b>${name}</b><small>${note}</small>`;
    if (file == null) return `<div class="pg soon">${inner}</div>`;
    return `<a class="pg" href="${file}"${file == here ? ' aria-current="page"' : ""}>${inner}</a>`;
  }).join("");
  document.body.appendChild(dock);
})();
