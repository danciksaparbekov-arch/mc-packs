#!/usr/bin/env node
// packgen — минимальный генератор packwiz-совместимых паков (без бинарника packwiz).
// Формат: pack.toml + index.toml + mods/<slug>.pw.toml. Моды — только ссылки на Modrinth CDN.
// Использование:
//   node packgen.mjs init    <dir> --name "<имя>" --mc 1.20.1 --loader fabric --loader-version 0.19.3
//   node packgen.mjs add     <dir> <modrinth-slug|url> [--side client|server|both] [--no-deps]
//   node packgen.mjs add-url <dir> <name> <url> [--side both]
//   node packgen.mjs remove  <dir> <slug>
//   node packgen.mjs refresh <dir>      (пересчитать хэши индекса)
//   node packgen.mjs list    <dir>
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const UA = { "User-Agent": "mc-pack-sync/0.1 (packgen)" };
const sha256 = (buf) => crypto.createHash("sha256").update(buf).digest("hex");
const q = (s) => JSON.stringify(String(s)); // строка в TOML = JSON-строка

async function api(p) {
  const r = await fetch(`https://api.modrinth.com/v2${p}`, { headers: UA });
  if (!r.ok) throw new Error(`Modrinth ${p}: ${r.status}`);
  return r.json();
}

// ---- pack.toml: читаем нужные поля простым разбором ----
function readPack(dir) {
  const t = fs.readFileSync(path.join(dir, "pack.toml"), "utf8");
  const g = (re) => (t.match(re) || [])[1];
  return { name: g(/^name = "(.*)"$/m), mc: g(/^minecraft = "(.*)"$/m), loaderName: ["fabric", "forge", "neoforge", "quilt"].find((l) => new RegExp(`^${l} = `, "m").test(t)), loaderVer: null, raw: t };
}

function refresh(dir) {
  const files = [];
  (function walk(d, rel = "") {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      const r = rel ? `${rel}/${e.name}` : e.name;
      if (e.isDirectory()) walk(path.join(d, e.name), r);
      else if (!["pack.toml", "index.toml", "base-projects.json", "server-exclude.json"].includes(r)) files.push(r);
    }
  })(dir);
  files.sort();
  let idx = 'hash-format = "sha256"\n';
  for (const f of files) {
    const h = sha256(fs.readFileSync(path.join(dir, f)));
    idx += `\n[[files]]\nfile = ${q(f)}\nhash = ${q(h)}\n${f.endsWith(".pw.toml") ? "metafile = true\n" : ""}`;
  }
  fs.writeFileSync(path.join(dir, "index.toml"), idx);
  const ih = sha256(Buffer.from(idx));
  const pack = fs.readFileSync(path.join(dir, "pack.toml"), "utf8").replace(/(\[index\][\s\S]*?hash = )".*"/, `$1"${ih}"`);
  fs.writeFileSync(path.join(dir, "pack.toml"), pack);
  console.log(`index: ${files.length} файл(ов), хэш ${ih.slice(0, 12)}…`);
}

function sideOf(project) {
  const c = project.client_side, s = project.server_side;
  if (s === "unsupported") return "client";
  if (c === "unsupported") return "server";
  return "both";
}

// ID проектов, уже входящих в базовую сборку (не дублируем и не добавляем как зависимости)
function baseIds(dir) {
  const p = path.join(dir, "base-projects.json");
  return fs.existsSync(p) ? new Set(JSON.parse(fs.readFileSync(p, "utf8")).ids) : new Set();
}

async function addMod(dir, ref, opts, seen = new Set()) {
  const slug = ref.replace(/^https?:\/\/modrinth\.com\/(mod|plugin|datapack)\//, "").split(/[/?#]/)[0];
  if (seen.has(slug)) return;
  seen.add(slug);
  const { mc, loaderName } = readPack(dir);
  const proj = await api(`/project/${slug}`);
  if (baseIds(dir).has(proj.id)) throw new Error(`${proj.title}: уже входит в базовую сборку`);
  if (proj.project_type !== "mod") throw new Error(`${slug}: это ${proj.project_type}, нужен mod`);
  const vers = await api(`/project/${proj.id}/version?loaders=${encodeURIComponent(JSON.stringify([loaderName]))}&game_versions=${encodeURIComponent(JSON.stringify([mc]))}`);
  if (!vers.length) throw new Error(`${proj.title}: нет версии под ${loaderName} ${mc}`);
  const v = vers.find((x) => x.version_type === "release") || vers[0];
  const f = v.files.find((x) => x.primary) || v.files[0];
  const side = opts.side || sideOf(proj);
  const toml = `name = ${q(proj.title)}\nfilename = ${q(f.filename)}\nside = ${q(side)}\n\n[download]\nurl = ${q(f.url)}\nhash-format = "sha512"\nhash = ${q(f.hashes.sha512)}\n\n[update]\n[update.modrinth]\nmod-id = ${q(proj.id)}\nversion = ${q(v.id)}\n`;
  fs.mkdirSync(path.join(dir, "mods"), { recursive: true });
  fs.writeFileSync(path.join(dir, "mods", `${proj.slug}.pw.toml`), toml);
  console.log(`+ ${proj.title} ${v.version_number} [${side}] (${f.filename})`);
  if (!opts.noDeps) {
    for (const d of v.dependencies.filter((x) => x.dependency_type === "required" && x.project_id)) {
      if (baseIds(dir).has(d.project_id)) { console.log(`  зависимость ${d.project_id}: уже в базе — пропуск`); continue; }
      const dp = await api(`/project/${d.project_id}`);
      console.log(`  зависимость: ${dp.slug}`);
      await addMod(dir, dp.slug, { ...opts, side: undefined }, seen);
    }
  }
}

// ---- CLI ----
const [cmd, dir, arg] = process.argv.slice(2);
const flag = (n) => { const i = process.argv.indexOf(`--${n}`); return i > 0 ? process.argv[i + 1] : undefined; };

try {
  if (cmd === "init") {
    fs.mkdirSync(dir, { recursive: true });
    const loader = flag("loader") || "fabric";
    fs.writeFileSync(path.join(dir, "pack.toml"), `name = ${q(flag("name") || "pack")}\npack-format = "packwiz:1.1.0"\n\n[index]\nfile = "index.toml"\nhash-format = "sha256"\nhash = ""\n\n[versions]\n${loader} = ${q(flag("loader-version") || "")}\nminecraft = ${q(flag("mc") || "1.20.1")}\n`);
    refresh(dir);
  } else if (cmd === "add") {
    await addMod(dir, arg, { side: flag("side"), noDeps: process.argv.includes("--no-deps") });
    refresh(dir);
  } else if (cmd === "add-url") {
    // add-url <dir> <name> <url> [--side both]: мод по прямой ссылке (хэш считаем при скачивании, сам файл не храним)
    const url = process.argv[5];
    if (!arg || !url) throw new Error("add-url <dir> <name> <url> [--side both]");
    const buf = Buffer.from(await (await fetch(url, { headers: UA })).arrayBuffer());
    if (buf.length < 1000) throw new Error("скачивание не удалось");
    const filename = decodeURIComponent(url.split("/").pop());
    const side = flag("side") || "both";
    const slug = arg.toLowerCase().replace(/[^a-z0-9_-]+/g, "-");
    const hash = crypto.createHash("sha512").update(buf).digest("hex");
    fs.mkdirSync(path.join(dir, "mods"), { recursive: true });
    fs.writeFileSync(path.join(dir, "mods", `${slug}.pw.toml`), `name = ${q(arg)}
filename = ${q(filename)}
side = ${q(side)}

[download]
url = ${q(url)}
hash-format = "sha512"
hash = ${q(hash)}
`);
    console.log(`+ ${arg} [${side}] (${filename}, ${Math.round(buf.length / 1024)} KB)`);
    refresh(dir);
  } else if (cmd === "remove") {
    fs.rmSync(path.join(dir, "mods", `${arg}.pw.toml`), { force: true });
    console.log(`- ${arg}`);
    refresh(dir);
  } else if (cmd === "refresh") refresh(dir);
  else if (cmd === "list") {
    for (const f of fs.existsSync(path.join(dir, "mods")) ? fs.readdirSync(path.join(dir, "mods")) : []) {
      const t = fs.readFileSync(path.join(dir, "mods", f), "utf8");
      console.log(f.replace(".pw.toml", ""), `[${(t.match(/^side = "(.*)"/m) || [])[1]}]`, (t.match(/^filename = "(.*)"/m) || [])[1]);
    }
  } else { console.log("Команды: init | add | remove | refresh | list — см. шапку файла"); process.exit(1); }
} catch (e) { console.error("Ошибка:", e.message); process.exit(1); }
