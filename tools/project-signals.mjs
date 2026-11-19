import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import zlib from 'node:zlib';

const outPath = process.argv.find((a) => a.startsWith('--out='))?.split('=')[1] || '';
const kb = path.join(os.homedir(), 'Downloads', 'ComfyUI相关');
const casesDir = path.join(kb, 'site', 'cases');
const now = new Date();
const projects = fs.existsSync(casesDir)
  ? fs.readdirSync(casesDir, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name)
  : [];

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
function textOf(content) {
  if (typeof content === 'string') return content;
  if (!Array.isArray(content)) return '';
  return content.filter((x) => x && x.type === 'text').map((x) => x.text || '').join('\n');
}
const positive = /不错|很好|满意|可以|推进|完成|喜欢|对|漂亮|有效|继续|赞/;
const negative = /不对|不行|难看|卡|慢|错|差|重做|失败|浪费时间|不满意|退回|问题/;
const byProject = Object.fromEntries(projects.map((p) => [p, { project: p, positive: 0, negative: 0, mentions: 0, samples: [] }]));

for (const file of walk(path.join(os.homedir(), '.dsh', 'sessions'))) {
  if (new Date(fs.statSync(file).mtimeMs).toDateString() !== now.toDateString()) continue;
  let events = [];
  try { events = decompress(file).split(/\r?\n/).filter(Boolean).map((l) => JSON.parse(l)); } catch { continue; }
  for (const e of events) {
    if (e.type !== 'user/message') continue;
    const d = e.data || {};
    if (d.source?.kind !== 'user') continue;
    const text = textOf(d.content);
    for (const p of projects) {
      const name = p.replace(/-/g, ' ');
      if (!text.includes(p) && !text.includes(name)) continue;
      const rec = byProject[p];
      rec.mentions++;
      if (negative.test(text)) rec.negative++;
      if (positive.test(text)) rec.positive++;
      if (rec.samples.length < 3) rec.samples.push(text.slice(0, 120));
    }
  }
}
const projectsOut = projects.map((p) => {
  const r = byProject[p];
  const raw = 60 + r.positive * 8 - r.negative * 10 + Math.min(10, r.mentions * 2);
  return { ...r, score: Math.max(0, Math.min(100, raw)) };
});
console.log(JSON.stringify({ day: now.toISOString().slice(0, 10), projects: projectsOut }));
if (outPath) fs.writeFileSync(outPath, JSON.stringify({ day: now.toISOString().slice(0, 10), projects: projectsOut }, null, 2), 'utf8');
