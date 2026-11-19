import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import zlib from 'node:zlib';
import crypto from 'node:crypto';

const rootDir = path.join(os.homedir(), 'Downloads', 'ComfyUI相关', 'prompt-library');
const now = new Date();
const day = now.toISOString().slice(0, 10);

// 先建立完整分类骨架：美术 > 类别 > 风格
const artCats = ['character', 'scene', 'props', 'ui', 'icon', 'illustration', 'storyboard', 'keyframe'];
const artStyles = ['realistic', 'cartoon', 'anime', 'stylized'];
for (const cat of artCats) {
  for (const style of artStyles) {
    const d = path.join(rootDir, 'art', cat, style);
    fs.mkdirSync(d, { recursive: true });
    const keep = path.join(d, '.gitkeep');
    if (!fs.existsSync(keep)) fs.writeFileSync(keep, '', 'utf8');
  }
}
for (const d of ['task', 'vibcoding', 'video']) fs.mkdirSync(path.join(rootDir, d), { recursive: true });

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
function safe(s) { return String(s || 'untitled').replace(/[\\/:*?"<>|]/g, '_').replace(/\s+/g, ' ').slice(0, 70).trim(); }
function classify(t) {
  const low = t.toLowerCase();
  const artCat = /角色|立绘|人物|服装|三视图|character|portrait/.test(low) ? 'character'
    : /场景|地图|环境|建筑|scene|environment/.test(low) ? 'scene'
    : /道具|载具|武器|prop|vehicle/.test(low) ? 'props'
    : /界面|按钮|ui|hud/.test(low) ? 'ui'
    : /图标|icon/.test(low) ? 'icon'
    : /插画|kv|illustration/.test(low) ? 'illustration'
    : /分镜|storyboard/.test(low) ? 'storyboard'
    : /关键帧|keyframe|首帧|尾帧/.test(low) ? 'keyframe'
    : 'uncategorized';
  const style = /写实|realistic|photo/.test(low) ? 'realistic'
    : /卡通|cartoon|欧美/.test(low) ? 'cartoon'
    : /二次元|anime| manga/.test(low) ? 'anime'
    : /风格化|stylized|潮玩|pixar/.test(low) ? 'stylized'
    : 'unspecified';
  const isVideo = /视频|运镜|镜头|分镜|seedance|kling|wan|h3|ltx|video/.test(low);
  const isCode = /代码|脚本|api|bug|修复|函数|接口|vibecod|vibe cod|编程|测试/.test(low);
  const isArt = /画|美术|角色|场景|道具|图标|ui|kv|插画|分镜|关键帧|prompt|提示词/.test(low);
  if (isVideo && !isArt) return { top: 'video', parts: ['video'] };
  if (isCode) return { top: 'vibcoding', parts: ['vibcoding'] };
  if (isArt || artCat !== 'uncategorized') return { top: 'art', parts: ['art', artCat, style] };
  return { top: 'task', parts: ['task'] };
}

const sessions = walk(path.join(os.homedir(), '.dsh', 'sessions'))
  .filter((f) => new Date(fs.statSync(f).mtimeMs).toDateString() === now.toDateString());

const index = [];
const seen = new Set();
for (const file of sessions) {
  let events = [];
  try { events = decompress(file).split(/\r?\n/).filter(Boolean).map((l) => JSON.parse(l)); } catch { continue; }
  const header = events.find((e) => e.type === 'session') || {};
  const title = [...events].reverse().find((e) => e.type === 'session/title')?.data?.title || header.id || '';
  for (const e of events) {
    if (e.type !== 'user/message') continue;
    const d = e.data || {};
    if (d.source?.kind !== 'user') continue;
    const text = textOf(d.content).trim();
    if (text.length < 30 || text.includes('<system-reminder>') || text.includes('Current working directory')) continue;
    const hash = crypto.createHash('sha1').update(text).digest('hex').slice(0, 10);
    if (seen.has(hash)) continue;
    seen.add(hash);
    const c = classify(text);
    const dir = path.join(rootDir, ...c.parts);
    fs.mkdirSync(dir, { recursive: true });
    const name = `${day}_${safe(title)}_${hash}.md`;
    const p = path.join(dir, name);
    if (!fs.existsSync(p)) {
      fs.writeFileSync(p, `---\ndate: ${day}\nsession: ${header.id || ''}\ntitle: ${title}\ncategory: ${c.parts.join('/')}\n---\n\n# ${title}\n\n${text}\n`, 'utf8');
    }
    index.push({ date: day, title, session: header.id || '', category: c.parts.join('/'), file: path.relative(rootDir, p).replaceAll('\\', '/') });
  }
}
fs.mkdirSync(rootDir, { recursive: true });
fs.writeFileSync(path.join(rootDir, 'index.json'), JSON.stringify({ updated: now.toISOString(), items: index }, null, 2), 'utf8');
const md = ['# 提示词库', '', `> ${day} · ${index.length} 条`, '', '| 分类 | 标题 | 文件 |', '|---|---|---|',
  ...index.map((x) => `| ${x.category} | ${x.title.replace(/\|/g, '\\|')} | [${x.file}](${x.file}) |`), ''].join('\n');
fs.writeFileSync(path.join(rootDir, 'index.md'), md, 'utf8');
console.log(JSON.stringify({ sessions: sessions.length, prompts: index.length }));
