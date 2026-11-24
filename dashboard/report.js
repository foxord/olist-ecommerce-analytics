"use strict";

const byId = id => document.getElementById(id);
const number = (value, digits = 0) => value == null ? "—" : value.toLocaleString("ru-RU", {maximumFractionDigits: digits, minimumFractionDigits: digits});
const percent = value => value == null ? "—" : number(value * 100, 2) + " %";
const ratio = (total, count) => count ? total / count : null;
const money = cents => {
  if (cents == null) return "—";
  const reais = cents / 100;
  return reais >= 1e6 ? number(reais / 1e6, 2) + " млн" : number(reais, reais < 1000 ? 2 : 0);
};
const escapeHtml = value => String(value).replace(/[&<>"]/g, char => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"})[char]);
const pageInfo = {
  overview: ["Обзор продаж", "Как менялись продажи и какие штаты давали основной оборот?"],
  customers: ["Клиенты и удержание", "Сколько покупателей приходило впервые и сколько возвращалось за следующей покупкой?"],
  delivery: ["Логистика и отзывы", "Где заказы задерживались чаще и как покупатели оценивали доставку?"]
};
let orders, months, firstOrder;
function monthIndex(month) {
  const [year, value] = month.split("-").map(Number);
  return year * 12 + value - 1;
}
function monthRange(first, last) {
  const result = [];
  for (let i = monthIndex(first); i <= monthIndex(last); i++) {
    result.push(`${Math.floor(i / 12)}-${String(i % 12 + 1).padStart(2, "0")}`);
  }
  return result;
}
function monthName(month) {
  const [year, value] = month.split("-").map(Number);
  return new Date(year, value - 1, 1).toLocaleDateString("ru-RU", {month:"short", year:"numeric"}).replace(/ г\.$/, "");
}
function options(select, values, label, all) {
  if (all) select.add(new Option(all, ""));
  values.forEach(value => select.add(new Option(label(value), value)));
}
function card(title, caption, content, wide = false) {
  return `<article class="card ${wide ? "wide" : ""}"><h2>${title}</h2><p class="caption">${caption}</p>${content}</article>`;
}
function kpis(values) {
  return `<div class="kpis ${values.length === 4 ? "four" : ""}" style="--count:${values.length}">${values.map(([label, value, hint]) =>
    `<div class="kpi"><span class="label">${label}</span><strong>${value}</strong><div class="hint">${hint}</div></div>`).join("")}</div>`;
}
function dataTable(labels, rows) {
  return `<details><summary>Показать числа</summary><div class="scroll"><table><thead><tr>${labels.map(label => `<th>${label}</th>`).join("")}</tr></thead><tbody>${rows.map(row => `<tr>${row.map(value => `<td>${value}</td>`).join("")}</tr>`).join("")}</tbody></table></div></details>`;
}
function lineChart(series, label, color, format, compact = false) {
  const width = 650, height = compact ? 103 : 137;
  const left = 57, right = width - 22, bottom = height - 24, top = 14;
  const maximum = Math.max(...series.map(entry => entry.value), 1);
  const coords = series.map(({value}, i) => ({
    x: left + (right - left) * i / Math.max(series.length - 1, 1),
    y: bottom - (bottom - top) * value / maximum
  }));
  const points = coords.map(({x,y}) => `${x},${y}`).join(" ");
  const labelIndexes = new Set(Array.from({length: Math.min(series.length, 5)}, (_, i) => Math.round(i * (series.length - 1) / Math.max(1, Math.min(series.length, 5) - 1))));
  const gridlines = [0, 0.5, 1].map(fraction => {
    const y = bottom - (bottom - top) * fraction;
    return `<path d="M${left} ${y} H${right}" stroke="#dde5e9"/><text x="${left-8}" y="${y+4}" text-anchor="end">${format(maximum * fraction)}</text>`;
  }).join("");
  const dots = coords.map(({x,y}, i) => `<circle cx="${x}" cy="${y}" r="${series.length < 3 ? 5 : 3}" fill="${color}"><title>${monthName(series[i].month)} · ${label} · ${format(series[i].value)}</title></circle>`).join("");
  const labels = [...labelIndexes].map(i => `<text x="${coords[i].x}" y="${height-4}" text-anchor="middle">${monthName(series[i].month)}</text>`).join("");
  return `<div class="series ${color === "#087a76" ? "teal" : ""}">${label}</div><svg class="plot" role="img" aria-label="${label}. Значения по месяцам доступны в таблице." viewBox="0 0 ${width} ${height}">${gridlines}<polygon points="${coords[0].x},${bottom} ${points} ${coords.at(-1).x},${bottom}" fill="${color}" opacity=".09"/><polyline points="${points}" fill="none" stroke="${color}" stroke-width="2.6"/>${dots}${labels}</svg>`;
}
function bars(entries, format, teal = false) {
  if (!entries.length) return '<p class="meta">В этом срезе недостаточно наблюдений.</p>';
  const max = Math.max(...entries.map(entry => entry.value), 0.00001);
  return `<div class="bars ${teal ? "teal" : ""}">${entries.map(({label,value,tip}) =>
    `<div title="${escapeHtml(tip || "")}"><div class="bar-title"><span>${escapeHtml(label)}</span><b>${format(value)}</b></div><div class="bar-track"><div class="bar-fill" style="width:${value/max*100}%"></div></div></div>`).join("")}</div>`;
}
function blankStats() {
  return {orders:0, cents:0, known:0, late:0, scored:0, scores:0, dayCount:0, days:0};
}
function addOrder(stats, row, cents) {
  stats.orders += 1;
  stats.cents += cents;
  if (row.late != null) {
    stats.known += 1;
    stats.late += Number(row.late);
  }
  if (row.score != null) {
    stats.scored += 1;
    stats.scores += row.score;
  }
  if (row.days != null) {
    stats.dayCount += 1;
    stats.days += row.days;
  }
}
function inMarket(row, state, category) {
  return (!state || state === row.state) && (!category || Object.hasOwn(row.categories, category));
}
function summarize(start, end, state, category) {
  const result = {
    all: blankStats(), byMonth: new Map(monthRange(start, end).map(month => [month, blankStats()])),
    byState: new Map(), buyers: new Map(), segments: new Map(), scores: [blankStats(), blankStats()]
  };
  for (const row of orders) {
    if (row.month < start || row.month > end || !inMarket(row, state, category)) continue;
    const cents = category ? row.categories[category] : row.cents;
    if (!result.byState.has(row.state)) result.byState.set(row.state, blankStats());
    for (const total of [result.all, result.byMonth.get(row.month), result.byState.get(row.state)]) addOrder(total, row, cents);
    if (row.late != null) addOrder(result.scores[Number(row.late)], row, cents);
    if (!result.buyers.has(row.buyer)) result.segments.set(row.segment, (result.segments.get(row.segment) || 0) + 1);
    result.buyers.set(row.buyer, (result.buyers.get(row.buyer) || 0) + 1);
  }
  return result;
}
function overview(data) {
  const total = data.all;
  const cards = kpis([
    ["Товарный оборот", money(total.cents), "R$ без доставки"],
    ["Заказы", number(total.orders), "доставленные"],
    ["Средний чек", money(ratio(total.cents,total.orders)), "R$ за заказ"],
    ["Покупатели", number(data.buyers.size), "уникальные клиенты"],
    ["С опозданием", percent(ratio(total.late,total.known)), "среди заказов с датами"],
    ["Средняя оценка", number(ratio(total.scores,total.scored),2), "из 5, заказы с отзывом"]
  ]);
  const timeline = [...data.byMonth].map(([month, group]) => ({month, cents:group.cents, orders:group.orders}));
  const series = key => timeline.map(row => ({month:row.month, value:row[key]}));
  const chart = lineChart(series("cents"), "Товарный оборот, млн R$", "#244ece", value => number(value / 1e8, 2), true)
    + lineChart(series("orders"), "Доставленные заказы, шт.", "#087a76", value => number(value), true)
    + dataTable(["Месяц","Оборот, R$","Заказы"], timeline.map(row => [monthName(row.month),number(row.cents/100,2),number(row.orders)]));
  const states = [...data.byState].map(([label, group]) => ({label,value:group.cents,tip:`${number(group.orders)} заказов · ${percent(ratio(group.cents,total.cents))} оборота`}));
  states.sort((a,b) => b.value-a.value);
  return cards + '<div class="grid">' + card("Продажи по месяцам", "Календарный месяц покупки · две отдельные шкалы", chart)
    + card("Штаты по обороту", "Семь крупнейших по стоимости товаров, R$", bars(states.slice(0,7), money)) + "</div>";
}
function acquisition(start, end, state, category) {
  const cohorts = new Map(monthRange(start, end).map(month => [month, {size:0, ages:Array.from({length:12}, () => new Set())}]));
  for (const row of firstOrder.values()) {
    if (cohorts.has(row.month) && inMarket(row, state, category)) cohorts.get(row.month).size += 1;
  }
  for (const row of orders) {
    if (row.month > end) break;
    const first = firstOrder.get(row.buyer);
    const cohort = cohorts.get(first.month);
    if (!cohort || !inMarket(first, state, category)) continue;
    const age = monthIndex(row.month) - monthIndex(first.month);
    if (age < 12) cohort.ages[age].add(row.buyer);
  }
  return cohorts;
}
function retentionTable(cohorts, end) {
  const ages = Array.from({length:12}, (_,i) => i);
  const rows = [...cohorts].filter(([,group]) => group.size).map(([month,group]) => {
    const ageMax = monthIndex(end) - monthIndex(month);
    const cells = ages.map(age => {
      if (age > ageMax) return '<td class="future" title="Месяц вне наблюдения">—</td>';
      const count = group.ages[age].size;
      const share = count/group.size;
      const color = age === 0 ? "#b6d9d6" : `rgba(8,122,118,${Math.min(.65, .05 + share * 18)})`;
      return `<td title="${number(count)} из ${number(group.size)} покупателей" style="background:${color}">${number(share*100,1)}</td>`;
    }).join("");
    return `<tr><th>${monthName(month)}</th><td>${number(group.size)}</td>${cells}</tr>`;
  }).join("");
  return `<div class="scroll"><table class="heat"><thead><tr><th>Когорта</th><th>Люди</th>${ages.map(age => `<th>M${age}</th>`).join("")}</tr></thead><tbody>${rows}</tbody></table></div>
    <p class="note">M0 — месяц первой покупки. Штат и категория относятся к первой корзине, повторные покупки учитываются в любом штате и категории. Прочерк означает, что месяц ещё не наблюдался.</p>`;
}
function customers(data, start, end, state, category) {
  const cohorts = acquisition(start, end, state, category);
  const timeline = [...cohorts].map(([month,group]) => ({month,value:group.size}));
  const newBuyers = timeline.reduce((sum,row) => sum + row.value, 0);
  const repeat = [...data.buyers.values()].filter(count => count > 1).length;
  const cards = kpis([
    ["Покупатели", number(data.buyers.size), "в выбранном срезе"],
    ["Новые покупатели", number(newBuyers), "первая покупка в срезе"],
    ["Купили повторно", number(repeat), "от двух заказов в срезе"],
    ["Доля повторных", percent(ratio(repeat,data.buyers.size)), "среди покупателей среза"]
  ]);
  const segments = [...data.segments].map(([label,value]) => ({label,value,tip:percent(ratio(value,data.buyers.size))}));
  segments.sort((a,b) => b.value - a.value);
  return cards + '<div class="grid">' + card("Новые покупатели по месяцам","Месяц первой доставленной покупки за всю историю",
    lineChart(timeline,"Покупатели, чел.","#244ece",value => number(value)) + dataTable(["Месяц","Новые покупатели"], timeline.map(row => [monthName(row.month),number(row.value)])))
    + card("RFM-сегменты", "Покупатели среза · сегмент на конец наблюдения", bars(segments,number,true))
    + card("Удержание по когортам", "Доля покупателей, совершивших покупку в указанном месяце, % · первые 12 месяцев", retentionTable(cohorts,end),true) + "</div>";
}
function delivery(data) {
  const total = data.all;
  const cards = kpis([
    ["Срок доставки", number(ratio(total.days,total.dayCount),1), "дней в среднем"],
    ["С опозданием", percent(ratio(total.late,total.known)), "доля с известными датами"],
    ["Опоздавшие заказы", number(total.late), `из ${number(total.known)} с датами`],
    ["Средняя оценка", number(ratio(total.scores,total.scored),2), `из 5 · ${number(total.scored)} с отзывом`]
  ]);
  const states = [...data.byState].filter(([,group]) => group.known >= 100).map(([label,group]) => ({label,value:group.late/group.known,tip:`${number(group.late)} из ${number(group.known)} с датами`}));
  states.sort((a,b) => b.value - a.value);
  const labels = ["В срок","С опозданием"];
  const scoreRows = data.scores.map((group,i) => {
    const mean = ratio(group.scores,group.scored);
    return `<div class="score"><span>${labels[i]}</span><div class="bar-track"><div class="bar-fill" style="width:${(mean||0)*20}%"></div></div><strong>${number(mean,2)}</strong></div><div class="meta">${number(group.scored)} заказов с оценкой</div>`;
  }).join("");
  return cards + '<div class="grid">' + card("Где чаще опаздывали", "Доля опозданий по штату покупателя · минимум 100 заказов с датами", bars(states.slice(0,10),percent,true))
    + card("Оценка заказа и срок", "Последняя оценка на заказ · шкала от 1 до 5", scoreRows + '<p class="note">Заказ опоздал, если календарная дата вручения позже обещанной. Сравнение групп показывает связь и само по себе не устанавливает причину.</p>') + "</div>";
}
function render() {
  const page = Object.hasOwn(pageInfo, location.hash.slice(1)) ? location.hash.slice(1) : "overview";
  const [title,question] = pageInfo[page];
  byId("page-title").textContent = title;
  byId("question").textContent = question;
  document.querySelectorAll("nav a").forEach(link => {
    if (link.hash === "#" + page) link.setAttribute("aria-current", "page");
    else link.removeAttribute("aria-current");
  });
  const start = byId("start").value, end = byId("end").value;
  const state = byId("state").value, category = byId("category").value;
  const data = summarize(start,end,state,category);
  if (!data.all.orders) {
    byId("report").innerHTML = '<p class="empty">В выбранном срезе нет доставленных заказов. Измените период или сбросьте фильтры.</p>';
    return;
  }
  const pages = {overview: () => overview(data), customers: () => customers(data,start,end,state,category), delivery: () => delivery(data)};
  byId("report").innerHTML = pages[page]() + (category && page === "overview" ? '<p class="note">В оборот включены только позиции выбранной категории. Заказ с несколькими такими позициями учитывается один раз.</p>' : "");
}
async function init() {
  const bytes = Uint8Array.from(atob(window.olistExtract), char => char.charCodeAt(0));
  const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("gzip"));
  orders = await new Response(stream).json();
  firstOrder = new Map();
  const categories = new Set();
  const states = new Set();
  for (const row of orders) {
    if (!firstOrder.has(row.buyer)) firstOrder.set(row.buyer,row);
    states.add(row.state);
    Object.keys(row.categories).forEach(name => categories.add(name));
  }
  months = monthRange(orders[0].month,orders.at(-1).month);
  options(byId("start"),months,monthName);
  options(byId("end"),months,monthName);
  byId("end").value = months.at(-1);
  options(byId("state"),[...states].sort(), value => value,"Все штаты");
  options(byId("category"),[...categories].sort(), value => value.replaceAll("_"," "),"Все категории");
  const form = document.querySelector("form");
  form.addEventListener("change", event => {
    if (byId("start").value > byId("end").value) {
      if (event.target.id === "start") byId("end").value = byId("start").value;
      else byId("start").value = byId("end").value;
    }
    render();
  });
  form.addEventListener("reset", event => {
    event.preventDefault();
    byId("start").value = months[0];
    byId("end").value = months.at(-1);
    byId("state").value = "";
    byId("category").value = "";
    render();
  });
  window.addEventListener("hashchange", render);
  render();
}
init().catch(error => {
  byId("report").textContent = "Не удалось прочитать extract.js. Откройте папку дашборда целиком в современном Chrome, Edge или Firefox. Для пересборки модели запустите dashboard/export.py.";
  console.error(error);
});
