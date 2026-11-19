import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import zlib from 'node:zlib';

const outPath = process.argv.find((a) => a.startsWith('--out='))?.split('=')[1] || '';
const root = path.join(os.homedir(), '.dsh', 'sessions');

function walk(dir) {
  const out = [];
  if (!fs.existsSync(dir)) return out;
  for (const n of fs.readdirSync(dir)) {
    const p = path.join(dir, n); const st = fs.statSync(p);
    if (st.isDirectory()) out.push(...walk(p));
    else if (/session\..*\.jsonl\.zstd$/i.test(n)) out.push(p);
  }
  return out;
}
function decompress(file) {
  const buf = fs.readFileSync(file);
  const magic = Buffer.from([0x28, 0xb5, 0x2f, 0xfd]);
  const offs = []; let p = 0;
  while ((p = buf.indexOf(magic, p)) >= 0) { offs.push(p); p += 4; }
  const parts = [];
  for (let i = 0; i < offs.length; i++) {
    const end = i + 1 < offs.length ? offs[i + 1] : buf.length;
    try { parts.push(zlib.zstdDecompressSync(buf.subarray(offs[i], end))); } catch {}
  }
  return Buffer.concat(parts).toString('utf8');
}
function dayOf(ms) {
  const d = new Date(ms);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

const daily = {};
const sessions = new Set();
for (const file of walk(root)) {
  let events = [];
  try { events = decompress(file).split(/\r?\n/).filter(Boolean).map((l) => JSON.parse(l)); } catch { continue; }
  const header = events.find((e) => e.type === 'session') || {};
  const sid = header.id || path.basename(path.dirname(file));
  sessions.add(sid);
  for (const e of events) {
    if (e.type !== 'assistant/message') continue;
    const d = e.data || {};
    const used = Number(d.usage?.totalTokens || 0);
    if (!used) continue;
    const t = e.time || d.time || fs.statSync(file).mtimeMs;
    const day = dayOf(t);
    if (!daily[day]) daily[day] = { tokens: 0, messages: 0, sessions: new Set() };
    daily[day].tokens += used;
    daily[day].messages += 1;
    daily[day].sessions.add(sid);
  }
}
const days = Object.keys(daily).sort();
const dailyOut = {};
for (const d of days) dailyOut[d] = { tokens: daily[d].tokens, messages: daily[d].messages, sessions: daily[d].sessions.size };
const now = new Date();
const today = dayOf(now.getTime());
const weekStart = new Date(now); weekStart.setDate(now.getDate() - 6);
const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
function sumFrom(start) {
  let tokens = 0, messages = 0;
  const set = new Set();
  for (const [d, v] of Object.entries(dailyOut)) {
    if (new Date(d + 'T00:00:00') >= start) { tokens += v.tokens; messages += v.messages; }
  }
  return { tokens, messages, sessions: sessions.size };
}
const out = {
  updated: now.toISOString(),
  today: dailyOut[today] || { tokens: 0, messages: 0, sessions: 0 },
  week: sumFrom(weekStart),
  month: sumFrom(monthStart),
  total: { tokens: Object.values(dailyOut).reduce((a, v) => a + v.tokens, 0), sessions: sessions.size },
  daily: dailyOut,
};
if (outPath) fs.writeFileSync(outPath, JSON.stringify(out, null, 2), 'utf8');
console.log(JSON.stringify({ today: out.today.tokens, week: out.week.tokens, month: out.month.tokens }));
