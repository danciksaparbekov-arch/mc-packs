#!/usr/bin/env node
// Синхронизация extras-пака с сервером Exaroton (запускается из GitHub Actions).
// Env: EXAROTON_TOKEN, EXAROTON_SERVER_ID, PACK_DIR (по умолчанию packs/prominence2-extras)
// Правила: ставим моды side=server|both в /mods, удаляем только то, что сами ставили раньше
// (список в /config/mc-packs-state.json) — база сборки не трогается. Перезапуск — только если игроков нет.
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const { EXAROTON_TOKEN: TOKEN, EXAROTON_SERVER_ID: SID } = process.env;
const PACK = process.env.PACK_DIR || "packs/prominence2-extras";
if (!TOKEN || !SID) throw new Error("Нужны EXAROTON_TOKEN и EXAROTON_SERVER_ID");
const BASE = `https://api.exaroton.com/v1/servers/${SID}`;
const H = { Authorization: `Bearer ${TOKEN}` };
const enc = (p) => p.split("/").map(encodeURIComponent).join("/");
const STATE = "config/mc-packs-state.json";

async function exa(p, opts = {}) {
  const r = await fetch(`${BASE}/${p}`, { ...opts, headers: { ...H, ...(opts.headers || {}) } });
  return r;
}
async function exaJson(p, opts) { const j = await (await exa(p, opts)).json(); if (!j.success) throw new Error(`${p}: ${j.error}`); return j.data; }

// ---- читаем мета-файлы пака ----
const wanted = [];
const modsDir = path.join(PACK, "mods");
for (const f of fs.existsSync(modsDir) ? fs.readdirSync(modsDir) : []) {
  if (!f.endsWith(".pw.toml")) continue;
  const t = fs.readFileSync(path.join(modsDir, f), "utf8");
  const g = (re) => (t.match(re) || [])[1];
  const m = { name: g(/^name = "(.*)"$/m), filename: g(/^filename = "(.*)"$/m), side: g(/^side = "(.*)"$/m) || "both", url: g(/^url = "(.*)"$/m), hash: g(/^hash = "(.*)"$/m), alg: g(/^hash-format = "(.*)"$/m) };
  if (m.side === "client") continue; // клиентские моды на сервер не нужны
  wanted.push(m);
}
console.log(`серверных модов в паке: ${wanted.length}`);

// ---- прежнее состояние ----
let prev = [];
const sr = await exa(`files/data/${enc(STATE)}`);
if (sr.ok) { try { const j = JSON.parse(await sr.text()); prev = j.files || []; } catch { /* нет состояния */ } }

const existing = new Set(((await exaJson("files/info/mods/")).children || []).map((c) => c.name));
const nowFiles = wanted.map((m) => m.filename);

let changed = 0, excludedNow = 0;

// ---- файлы базовой сборки, которые ломают сервер: удаляем (список в server-exclude.json) ----
const exclPath = path.join(PACK, "server-exclude.json");
const excluded = fs.existsSync(exclPath) ? JSON.parse(fs.readFileSync(exclPath, "utf8")).files || [] : [];
for (const f of excluded) {
  if (existing.has(f)) { await exaJson(`files/data/mods/${enc(f)}`, { method: "DELETE" }); existing.delete(f); console.log(`- (exclude) ${f}`); excludedNow++; }
}

// ---- удаляем устаревшее (то, что ставили сами) ----
for (const old of prev.filter((f) => !nowFiles.includes(f))) {
  if (existing.has(old)) { await exaJson(`files/data/mods/${enc(old)}`, { method: "DELETE" }); console.log(`- ${old}`); changed++; }
}
// ---- ставим новое ----
for (const m of wanted) {
  if (existing.has(m.filename)) continue;
  const r = await fetch(m.url);
  if (!r.ok) throw new Error(`скачивание ${m.name}: ${r.status}`);
  const buf = Buffer.from(await r.arrayBuffer());
  if (crypto.createHash(m.alg).update(buf).digest("hex") !== m.hash) throw new Error(`хэш не совпал: ${m.name}`);
  await exaJson(`files/data/mods/${enc(m.filename)}`, { method: "PUT", headers: { "Content-Type": "application/octet-stream" }, body: buf });
  console.log(`+ ${m.filename}`); changed++;
}
changed += excludedNow;
// ---- сохраняем состояние ----
await exaJson(`files/data/${enc(STATE)}`, { method: "PUT", headers: { "Content-Type": "application/octet-stream" }, body: JSON.stringify({ files: nowFiles }, null, 2) });

// ---- перезапуск только при пустом сервере ----
const srv = await exaJson("");
const note = [];
if (!changed) note.push("Изменений на сервере нет.");
else if (srv.status === 1 && srv.players.count === 0) { await exaJson("restart/"); note.push("Сервер был пуст — перезапущен."); }
else if (srv.status === 1) note.push(`Онлайн ${srv.players.count} игрок(ов) — перезапуск пропущен, моды применятся после следующего рестарта.`);
else note.push("Сервер выключен — моды применятся при запуске.");
console.log(note.join(" "));
if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, `### Sync Exaroton\nИзменений: ${changed}\n${note.join(" ")}\n`);
