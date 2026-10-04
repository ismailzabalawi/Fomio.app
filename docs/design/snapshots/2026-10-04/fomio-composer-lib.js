// Fomio composer prototype helpers: fixture content and a small Markdown <-> rich-text bridge.
// Simulation only. Production keeps Discourse's composer model, editor, drafts and upload pipeline.
(function () {
const esc = (s) => String(s == null ? "" : s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const inl = (s) => esc(s)
  .replace(/`([^`]+)`/g, "<code>$1</code>")
  .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
  .replace(/(^|[^*])\*([^*\s][^*]*?)\*/g, "$1<em>$2</em>")
  .replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, '<a href="$2">$1</a>')
  .replace(/(^|\s)(https?:\/\/[^\s<]+)/g, '$1<a href="$2">$2</a>');
const PHOTOS = [
  { code: "u7f1g", name: "IMG_2041.jpeg", src: "assets/photos/ph-fig.jpg", alt: "Fig tree growing in a large container outdoors" },
  { code: "u2wln", name: "IMG_2040.jpeg", src: "assets/photos/ph-walnut.jpg", alt: "Close-up of a solid walnut table top" },
  { code: "u9scp", name: "IMG_2038.jpeg", src: "assets/photos/ph-scope.jpg", alt: "Rigol oscilloscope and function generator on a bench" },
];
const photoByCode = (c) => PHOTOS.find((p) => p.code === c);
const photoByName = (n) => PHOTOS.find((p) => p.name === n);
const imgMd = (p) => `![${p.name.replace(/\.\w+$/, "")}|690x460](upload://${p.code}.jpeg)`;
const upMd = (name) => `[Uploading: ${name}…]()`;
const USERS = {
  jun: { name: "Jun Okada", initial: "J", color: "#56708A" },
  ravi: { name: "Ravi Patel", initial: "R", color: "#6A7F2E" },
  maya: { name: "Maya Chen", initial: "M", color: "#A0527A" },
};
const CATS = [
  { id: "open", parent: "General", name: "Open Discussions", color: "#56708A", desc: "Anything that does not fit elsewhere." },
  { id: "q", parent: "General", name: "Questions", color: "#B07A1E", desc: "Ask one clear question. Say what you have tried.", template: "What are you trying to do?\n\nWhat have you tried so far?" },
  { id: "craft", parent: "Craft", name: "Writing workshop", color: "#6A7F2E", desc: "Share drafts and ask for feedback." },
  { id: "lounge", parent: null, name: "Members lounge for regulars and long-time readers", color: "#A0527A", restricted: true, desc: "For members of the Regulars group." },
  { id: "desk", parent: null, name: "Editors’ desk", color: "#8A5A2E", restricted: true, desc: "Planning notes for the editing team." },
];
const cat = (id) => CATS.find((c) => c.id === id) || CATS[0];
const catPath = (c) => (c.parent ? c.parent + " › " + c.name : c.name);
const OB = { "https://example.org/slow-mornings": { title: "Slow mornings: notes from a year of quieter starts", desc: "What changed when I stopped reaching for my phone first thing." } };
const host = (u) => { try { return new URL(u).hostname; } catch (e) { return u; } };
const ce = (o) => (o.edit ? ' contenteditable="false"' : "");
const fig = (o, kind, md, inner, extra) => `<figure${ce(o)} data-kind="${kind}" data-md="${esc(md)}" style="margin:0 0 14px;${extra || ""}">${inner}</figure>`;
function atom(md, o) {
  let icon = "i-code", label;
  if (/^\[poll/.test(md)) {
    const opts = (md.match(/^\* (.*)$/gm) || []).map((x) => x.slice(2));
    if (!o.edit) return `<div style="margin:0 0 14px;padding:12px 14px;border:1px solid var(--content-border-color);border-radius:8px;display:flex;flex-direction:column;gap:8px">${opts.map((x) => `<span style="display:flex;align-items:center;gap:10px"><span style="width:16px;height:16px;border-radius:50%;border:2px solid var(--primary-400);flex:none"></span>${esc(x)}</span>`).join("")}<span style="font-size:14px;color:var(--primary-medium)">0 voters</span></div>`;
    icon = "i-poll"; label = "Poll · " + opts.length + " option" + (opts.length === 1 ? "" : "s") + (/type=multiple/.test(md) ? ", multiple choice" : "");
  } else if (/^\[details/.test(md)) {
    const m = md.match(/^\[details="([^"]*)"\]\n?([\s\S]*?)\n?\[\/details\]/);
    if (!o.edit) return `<details style="margin:0 0 14px"><summary style="cursor:pointer;font-weight:600">${esc(m ? m[1] : "Summary")}</summary><p>${esc(m ? m[2] : "")}</p></details>`;
    icon = "i-eye"; label = "Hidden details · " + (m ? m[1] : "");
  } else if (/^\[spoiler/.test(md)) {
    const t = (md.match(/^\[spoiler\]([\s\S]*)\[\/spoiler\]/) || [])[1] || "";
    if (!o.edit) return `<p><span style="filter:blur(5px)">${esc(t)}</span></p>`;
    icon = "i-eye"; label = "Blurred spoiler";
  } else if (/^\[date=/.test(md)) {
    const d = md.match(/date=(\d{4}-\d\d-\d\d)/), t = md.match(/time=(\d\d:\d\d)/);
    icon = "i-cal"; label = (d ? d[1] : "") + (t ? " " + t[1] : "");
    if (!o.edit) return `<p><span style="padding:2px 8px;border-radius:6px;background:var(--primary-low)">${esc(label)}</span></p>`;
    label = "Date · " + label;
  } else if (/^\|/.test(md)) {
    const rows = md.split("\n").filter((l) => /^\|/.test(l) && !/^\|\s*-/.test(l)).map((l) => l.split("|").slice(1, -1).map((x) => x.trim()));
    if (!o.edit) return `<table style="margin:0 0 14px;border-collapse:collapse">${rows.map((r, i) => "<tr>" + r.map((c) => `<${i ? "td" : "th"} style="padding:6px 10px;border-bottom:1px solid var(--content-border-color);text-align:start">${esc(c)}</${i ? "td" : "th"}>`).join("") + "</tr>").join("")}</table>`;
    icon = "i-table"; label = "Table · " + (rows[0] || []).length + " columns, " + Math.max(0, rows.length - 1) + " rows";
  } else {
    const lines = md.split("\n"); const code = lines.slice(1, -1).join("\n");
    if (!o.edit) return `<pre style="margin:0 0 14px;padding:12px 14px;border-radius:8px;background:var(--primary-very-low);overflow:auto;font:14px/1.5 var(--mono)">${esc(code)}</pre>`;
    label = "Preformatted text · " + Math.max(1, lines.length - 2) + " line" + (lines.length === 3 ? "" : "s");
  }
  return fig(o, "atom", md, `<svg width="18" height="18" aria-hidden="true" style="flex:none;color:var(--primary-medium)"><use href="#${icon}"></use></svg><span style="overflow-wrap:anywhere">${esc(label)}</span>`, "display:flex;align-items:center;gap:10px;padding:12px 14px;border-radius:8px;border:1px solid var(--content-border-color);background:var(--primary-very-low);font-weight:600;font-size:15px");
}
function quote(user, text, md, o) {
  const u = USERS[user] || { name: user, initial: user[0].toUpperCase(), color: "#56708A" };
  return fig(o, "quote", md, `<span style="display:flex;align-items:center;gap:8px;margin-bottom:6px;font-weight:700;font-size:14px;color:var(--primary-high)"><span style="width:22px;height:22px;border-radius:50%;background:${u.color};color:#fff;font-size:11px;line-height:22px;text-align:center">${u.initial}</span>${esc(u.name)}:</span><span style="display:block;color:var(--primary-high);unicode-bidi:plaintext">${esc(text)}</span>`, "padding:10px 14px 12px;border-radius:8px;background:var(--primary-very-low);border-inline-start:3px solid var(--primary-low-mid)");
}
function mdToHtml(md, o) {
  o = o || {};
  const L = (md || "").replace(/\r/g, "").split("\n"); const out = []; let para = [], i = 0, m;
  const flush = () => { if (para.length) { out.push("<p>" + para.map(inl).join("<br>") + "</p>"); para = []; } };
  while (i < L.length) {
    const l = L[i], t = l.trim();
    if (!t) { flush(); i++; continue; }
    if ((m = t.match(/^\[Uploading: (.+?)…\]\(\)$/))) {
      flush();
      out.push(fig(o, "up", t, `<span style="width:18px;height:18px;border-radius:50%;border:2px solid var(--primary-low);border-top-color:var(--tertiary);animation:fcspin 800ms linear infinite;flex:none"></span><span style="min-width:0;overflow-wrap:anywhere">Uploading ${esc(m[1])}…</span>`, "display:flex;align-items:center;gap:10px;padding:14px;border-radius:8px;border:1px dashed var(--primary-low-mid);color:var(--primary-medium);font-size:15px").replace("<figure", `<figure data-name="${esc(m[1])}"`));
      i++; continue;
    }
    if ((m = t.match(/^!\[([^|\]]*)(?:\|[^\]]*)?\]\(upload:\/\/(\w+)\.\w+\)$/))) {
      flush(); const p = photoByCode(m[2]) || PHOTOS[0];
      out.push(fig(o, "img", t, `<img src="${p.src}" alt="${esc(p.alt)}" style="display:block;width:100%;max-width:520px;max-height:300px;object-fit:cover;border-radius:8px">`));
      i++; continue;
    }
    if (/^https?:\/\/\S+$/.test(t) && !para.length) {
      flush(); const ob = OB[t];
      if (ob && !o.obFail) out.push(fig(o, "ob", t, `<span style="display:flex;align-items:center;gap:6px;font-size:13px;color:var(--primary-medium)">${esc(host(t))}</span><span style="font-weight:700;font-size:16px;color:var(--tertiary)">${esc(ob.title)}</span><span style="font-size:14px;color:var(--primary-high)">${esc(ob.desc)}</span>`, "display:flex;flex-direction:column;gap:4px;padding:12px 14px;border-radius:8px;border:1px solid var(--content-border-color)"));
      else out.push(`<p><a href="${esc(t)}">${esc(t)}</a></p>`);
      i++; continue;
    }
    if ((m = t.match(/^\[quote="(\w+), post:(\d+), topic:(\d+)"\]/))) {
      flush(); const buf = []; i++;
      while (i < L.length && !/^\[\/quote\]/.test(L[i])) { buf.push(L[i]); i++; }
      i++; const text = buf.join("\n");
      out.push(quote(m[1], text, `[quote="${m[1]}, post:${m[2]}, topic:${m[3]}"]\n${text}\n[/quote]`, o)); continue;
    }
    if (/^\[(poll|details|spoiler)/.test(t)) {
      flush(); const tag = t.match(/^\[(\w+)/)[1]; const buf = [l]; i++;
      if (!l.includes("[/" + tag + "]")) { while (i < L.length && !L[i - 1].includes("[/" + tag + "]")) { buf.push(L[i]); i++; } }
      out.push(atom(buf.join("\n"), o)); continue;
    }
    if (/^\[date=/.test(t)) { flush(); out.push(atom(t, o)); i++; continue; }
    if (/^\|/.test(t)) { flush(); const buf = []; while (i < L.length && /^\|/.test(L[i])) { buf.push(L[i]); i++; } out.push(atom(buf.join("\n"), o)); continue; }
    if (/^```/.test(t)) { flush(); const buf = [l]; i++; while (i < L.length && !/^```/.test(L[i])) { buf.push(L[i]); i++; } if (i < L.length) { buf.push(L[i]); i++; } out.push(atom(buf.join("\n"), o)); continue; }
    if ((m = l.match(/^(#{1,3}) (.*)/))) { flush(); const n = Math.max(2, m[1].length); out.push(`<h${n}>${inl(m[2])}</h${n}>`); i++; continue; }
    if (/^> ?/.test(l)) { flush(); const buf = []; while (i < L.length && /^> ?/.test(L[i])) { buf.push(L[i].replace(/^> ?/, "")); i++; } out.push("<blockquote><p>" + buf.map(inl).join("<br>") + "</p></blockquote>"); continue; }
    if (/^[-*] /.test(l)) { flush(); const buf = []; while (i < L.length && /^[-*] /.test(L[i])) { buf.push("<li>" + inl(L[i].slice(2)) + "</li>"); i++; } out.push("<ul>" + buf.join("") + "</ul>"); continue; }
    if (/^\d+\. /.test(l)) { flush(); const buf = []; while (i < L.length && /^\d+\. /.test(L[i])) { buf.push("<li>" + inl(L[i].replace(/^\d+\. /, "")) + "</li>"); i++; } out.push("<ol>" + buf.join("") + "</ol>"); continue; }
    para.push(l); i++;
  }
  flush();
  let html = out.join("");
  if (o.edit && /<\/figure>$/.test(html)) html += "<p><br></p>";
  return html;
}
function htmlToMd(html) {
  const d = document.createElement("div"); d.innerHTML = html || "";
  const inline = (n) => {
    let s = "";
    n.childNodes.forEach((c) => {
      if (c.nodeType === 3) { s += c.textContent; return; }
      if (c.nodeType !== 1) return;
      const t = c.tagName, v = inline(c);
      if (t === "STRONG" || t === "B") s += v.trim() ? `**${v}**` : v;
      else if (t === "EM" || t === "I") s += v.trim() ? `*${v}*` : v;
      else if (t === "CODE") s += v ? "`" + v + "`" : "";
      else if (t === "A") { const h = c.getAttribute("href") || ""; s += v === h ? h : `[${v}](${h})`; }
      else if (t === "BR") s += "\n";
      else if (t === "FIGURE") s += c.dataset.md || "";
      else s += v;
    });
    return s;
  };
  const blocks = [];
  const walk = (n) => n.childNodes.forEach((c) => {
    if (c.nodeType === 3) { if (c.textContent.trim()) blocks.push(c.textContent.trim()); return; }
    if (c.nodeType !== 1) return; const t = c.tagName;
    if (t === "FIGURE") { if (c.dataset.md) blocks.push(c.dataset.md); return; }
    if (t === "H1" || t === "H2") blocks.push("## " + inline(c).trim());
    else if (t === "H3" || t === "H4") blocks.push("### " + inline(c).trim());
    else if (t === "UL") blocks.push([...c.children].map((li) => "- " + inline(li).trim()).join("\n"));
    else if (t === "OL") blocks.push([...c.children].map((li, j) => j + 1 + ". " + inline(li).trim()).join("\n"));
    else if (t === "BLOCKQUOTE") { const inner = c.querySelector("p,div") ? [...c.children].map((x) => inline(x).trim()).join("\n") : inline(c).trim(); blocks.push(inner.split("\n").map((x) => "> " + x).join("\n")); }
    else if (c.querySelector("figure,ul,ol,blockquote,p,h2,h3,div")) walk(c);
    else { const v = inline(c).replace(/\u00a0/g, " ").replace(/\n$/, "").trim(); if (v) blocks.push(v); }
  });
  walk(d);
  return blocks.join("\n\n");
}
const THREAD = {
  id: 4127, title: "What small habit made your mornings easier?", cat: "open",
  posts: [
    { id: 1, n: 1, user: "jun", when: "1d", md: "What small habit made your mornings easier? Mine is leaving the kettle filled the night before, so the first thing I do is quiet." },
    { id: 2, n: 2, user: "ravi", when: "20h", md: "I keep the curtains open. Two minutes of daylight, but it feels like the morning has already started." },
    { id: 3, n: 3, user: "maya", when: "6h", md: "A paper list by the door. If it is not on the list, it waits until after breakfast." },
    { id: 4, n: 4, user: "jun", when: "3h", md: "The charger lives in the hallway now. I read on paper until breakfast." },
  ],
};
const FEED = [
  { title: "Recommend a notebook that survives a bag", meta: "Craft › Writing workshop · 2h" },
  { title: "What are you reading this week?", meta: "General › Open Discussions · 5h" },
  { title: THREAD.title, meta: "General › Open Discussions · 1d", thread: true },
];
const SIMILAR = [
  { t: THREAD.title, m: "General › Open Discussions · 3 replies" },
  { t: "Morning routines that actually stuck", m: "General › Open Discussions · 24 replies" },
  { t: "How do you start the day without the news?", m: "General › Questions · 9 replies" },
];
const EMOJI = ["🙂", "😄", "🙏", "👍", "❤️", "☕", "🌅", "📚", "✍️", "🌱", "🎉", "🤔"];
const NEW_TITLE = "A paper notebook by the kettle changed my mornings";
const NEW_MD = "I keep a small paper notebook next to the kettle. While the water heats, I write **one line** about the day ahead.\n\n" + imgMd(PHOTOS[1]) + "\n\nWhat I tried before it stuck:\n\n- Phone notes, which turned into scrolling\n- A planner, which felt like homework\n- One line on paper, which lasted\n\n> Two minutes, no screen.\n\nI found the idea in this piece:\n\nhttps://example.org/slow-mornings";
const LONG_TITLE = "A slightly embarrassing question about mornings: does anyone else plan the whole day in bed, then forget all of it by the time the coffee is ready, and how do you stop that happening?";
const AR_TITLE = "ما العادة الصغيرة التي جعلت صباحك أسهل؟";
const AR_MD = "توقفت عن تفقد هاتفي قبل أن يغلي الماء. تبدو خطوة صغيرة، لكن الدقائق العشر الأولى أصبحت أهدأ.\n\nأكتب سطرًا واحدًا في دفتر صغير بجانب الإبريق.";
window.FMC = { esc, PHOTOS, photoByName, imgMd, upMd, USERS, CATS, cat, catPath, mdToHtml, htmlToMd, THREAD, FEED, SIMILAR, EMOJI, NEW_TITLE, NEW_MD, LONG_TITLE, AR_TITLE, AR_MD, URL1: "https://example.org/slow-mornings" };
})();
