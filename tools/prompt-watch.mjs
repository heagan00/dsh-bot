import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import zlib from 'node:zlib';
import crypto from 'node:crypto';

const outPath = process.argv.find((a) => a.startsWith('--out='))?.split('=')[1] || '';
const now = Date.now();
const cutoff = now - 30 * 60 * 1000;

function walk(dir) {
  const out = [];
  if (!fs.existsSync(dir)) return out;
  for (const n of fs.readdirSync(dir)) {
    const p = path.join(dir, n);
    const st = fs.statSync(p);
    if (st.isDirectory()) out.push(...walk(p));
    else if (/session\..*\.jsonl\.zstd$/i.test(n) && st.mtimeMs >= cutoff) out.push(p);
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
function textOf(content) {
  if (typeof content === 'string') return content;
  if (!Array.isArray(content)) return '';
  return content.filter((x) => x && x.type === 'text').map((x) => x.text || '').join('\n');
}
function isNoise(t) {
  return t.includes('<system-reminder>') || t.includes('Current working directory') ||
    t.startsWith('You are an AI agent') || t.includes('<available_skills>') ||
    t.startsWith('The following workspace instructions');
}

const items = [];
for (const file of walk(path.join(os.homedir(), '.dsh', 'sessions'))) {
  let events = [];
  try { events = decompress(file).split(/\r?\n/).filter(Boolean).map((l) => JSON.parse(l)); } catch { continue; }
  const header = events.find((e) => e.type === 'session') || {};
  const title = [...events].reverse().find((e) => e.type === 'session/title')?.data?.title || header.id || '';
  for (const e of events) {
    if (e.type !== 'user/message') continue;
    const d = e.data || {};
    if (d.source?.kind !== 'user') continue;
    const text = textOf(d.content).trim();
    if (text.length < 100 || isNoise(text)) continue;
    const t = e.time || d.time || 0;
    if (t && t < cutoff) continue;
    const id = d.id || ('h' + crypto.createHash('sha1').update(text).digest('hex').slice(0, 12));
    items.push({
      id,
      sessionId: header.id || path.basename(path.dirname(file)),
      title,
      text,
      mention: /@阿皮/.test(text),
      time: t || Date.now(),
    });
  }
}
const seen = new Set();
const alerts = items.filter((x) => { if (seen.has(x.id)) return false; seen.add(x.id); return true; })
  .sort((a, b) => b.time - a.time)
  .slice(0, 5);
const report = { generatedAt: new Date().toISOString(), alerts };
if (outPath) fs.writeFileSync(outPath, JSON.stringify(report, null, 2), 'utf8');
console.log(JSON.stringify({ alerts: alerts.length, mention: alerts.filter((a) => a.mention).length }));
