// Шапка и подвал одни на все страницы. Текущая страница — по имени файла.
// Ещё здесь общее поведение: вкладки, бургер, формы, которые никуда не шлют.
const NAV = [
  ["solutions.html", "Решения"],
  ["devices.html", "Устройства"],
  ["ai.html", "Нейросети"],
  ["pricing.html", "Цены"],
  ["developers.html", "Разработчикам"],
  ["company.html", "Компания"],
  ["support.html", "Поддержка"]
];
const LOGO = '<svg viewBox="0 0 56 40" aria-hidden="true"><path d="M20 6 L6 20 L20 34" fill="none" stroke="var(--coral)" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/><path d="M36 6 L50 20 L36 34" fill="none" stroke="var(--teal)" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/></svg>';

(() => {
  const here = location.pathname.split("/").pop() || "index.html";
  const nav = NAV.map(([f, t]) => `<a href="${f}"${f == here ? ' aria-current="page"' : ""}>${t}</a>`).join("");
  const top = document.createElement("header");
  top.className = "top";
  top.innerHTML = `<div class="wrap"><a class="logo" href="index.html">${LOGO}Saltic</a><nav class="nav" aria-label="Разделы">${nav}</nav>
    <div class="actions"><a class="btn outline sm" href="support.html">Войти</a><a class="btn primary sm" href="index.html#calc">Получить расчёт</a>
    <button class="btn ghost sm burger" aria-label="Меню" aria-expanded="false">☰</button></div></div>`;
  document.body.prepend(top);
  const burger = top.querySelector(".burger"), menu = top.querySelector(".nav");
  burger.addEventListener("click", () => burger.setAttribute("aria-expanded", menu.classList.toggle("open")));

  const foot = document.createElement("footer");
  foot.className = "foot";
  foot.innerHTML = `<div class="wrap">
    <div><a class="logo" href="index.html">${LOGO}Saltic</a><p class="motto">Человек не раб компьютера.</p>
      <p>Сделано в Казахстане.</p><span class="badge coral vision">образ 2036 · не для публикации</span></div>
    <div><h4>Продукты</h4><ul><li><a href="devices.html">Устройства</a></li><li><a href="ai.html">Нейросети</a></li><li><a href="pricing.html">Цены</a></li></ul></div>
    <div><h4>Решения</h4><ul><li><a href="solutions.html">Офис</a></li><li><a href="solutions.html#all">Склад и производство</a></li><li><a href="solutions.html#all">Торговля</a></li><li><a href="solutions.html#all">Школы</a></li></ul></div>
    <div><h4>Разработчикам</h4><ul><li><a href="developers.html">Начать</a></li><li><a href="developers.html#store">Магазин программ</a></li><li><a href="support.html#security">Безопасность</a></li></ul></div>
    <div><h4>Компания</h4><ul><li><a href="company.html">О нас</a></li><li><a href="company.html#jobs">Вакансии</a></li><li><a href="support.html">Поддержка</a></li><li><a href="support.html#status">Статус систем</a></li></ul></div>
  </div>`;
  document.body.append(foot);

  // Вкладки: кнопки с data-tab, панели с data-panel внутри одного [data-tabs].
  document.querySelectorAll("[data-tabs]").forEach(box => {
    const buttons = box.querySelectorAll("[data-tab]");
    buttons.forEach(b => b.addEventListener("click", () => {
      buttons.forEach(x => x.setAttribute("aria-selected", x == b));
      box.querySelectorAll("[data-panel]").forEach(p => p.hidden = p.dataset.panel != b.dataset.tab);
    }));
  });

  // Это образ сайта: заявки никуда не уходят — так и говорим.
  document.querySelectorAll("form.form").forEach(f => f.addEventListener("submit", e => {
    e.preventDefault();
    const note = f.querySelector(".note");
    if (note) note.textContent = "Это образ сайта через 10 лет — заявки пока никуда не уходят.";
  }));
})();
