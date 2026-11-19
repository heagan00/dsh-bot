import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import zlib from 'node:zlib';
import crypto from 'node:crypto';

const rootDir = path.join(os.homedir(), 'Downloads', 'ComfyUI相关', 'prompt-library');
const now = new Date();
const day = now.toISOString().slice(0, 10);

const ART_CATS = ['character', 'scene', 'props', 'ui', 'icon', 'illustration', 'storyboard', 'keyframe'];
const ART_STYLES = ['realistic', 'cartoon', 'anime', 'stylized'];

const D = {
  art: ['美术', '原画', '角色', '立绘', '场景', '道具', '武器', '载具', '插画', 'kv', '分镜', '关键帧', '构图', '光影', '材质', '氛围', '配色', '笔触', '概念图', '三视图', '设定图'],
  character: ['角色', '立绘', '人物', '服装', '三视图', 'character', 'portrait', 'npc', '主角', '怪物', 'boss'],
  scene: ['场景', '地图', '环境', '建筑', '关卡', 'scene', 'environment', 'landscape', '室内', '室外'],
  props: ['道具', '武器', '载具', '宝箱', '装备', 'prop', 'vehicle', 'weapon'],
  ui: ['界面', '按钮', 'ui', 'hud', '菜单', '面板', '弹窗'],
  icon: ['图标', 'icon', '徽章', '技能图标', '道具图标'],
  illustration: ['插画', 'kv', '主视觉', 'illustration', '海报', '宣传图'],
  storyboard: ['分镜', 'storyboard', '镜头脚本'],
  keyframe: ['关键帧', '首帧', '尾帧', 'keyframe', '起始帧', '结束帧'],
  video: ['视频', '运镜', '镜头', '时长', '帧率', '转场', '音效', '音频', '动画', 'seedance', 'kling', 'wan', 'h3', 'ltx', 'video', '首帧', '尾帧', '动作'],
  vibcoding: ['代码', '函数', 'api', '接口', '脚本', '调试', 'bug', '测试', '部署', '仓库', 'git', '命令', '程序', '编译', '自动化', 'vibecod', 'vibe cod', 'typescript', 'python', 'powershell', '弹窗', '按钮', '日志', '报告', '缓存', '备份', '巡检', '定时'],
  task: ['需求', '实现', '制作', '完成', '修复', '计划', '帮我', '需要', '生成', '输出', '文件', '项目', '自动', '任务', '流程', '整理', '检查', '配置', '设计', '提示词', '规则', '优化'],
};

for (const cat of ART_CATS) {
  for (const style of ART_STYLES) {
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
function score(text, terms) { let s = 0; for (const t of terms) if (text.includes(t)) s += 2; return s; }

function classify(text) {
  const low = text.toLowerCase();
  const scores = {
    task: 1 + score(low, D.task),
    vibcoding: score(low, D.vibcoding),
    video: score(low, D.video),
    art: score(low, D.art),
  };
  if (text.includes('@阿美')) scores.art += 10;
  if (text.includes('@阿威')) scores.video += 10;
  if (text.includes('@阿秃')) scores.vibcoding += 10;

  const catScores = Object.fromEntries(ART_CATS.map((c) => [c, score(low, D[c])]));
  const bestCat = Object.entries(catScores).sort((a, b) => b[1] - a[1])[0];
  scores.art += bestCat[1] * 0.7;
  const artCore = ['美术', '原画', '角色', '立绘', '场景', '道具', '插画', '分镜', '关键帧', '构图', '光影', '配色', '概念图', '三视图', '设定图'];
  scores.art += score(low, artCore) * 1.5;

  const top = Object.entries(scores).sort((a, b) => b[1] - a[1])[0];
  if (top[0] === 'art') {
    const styleScores = {
      realistic: /写实|realistic|photo/.test(low) ? 4 : 0,
      cartoon: /卡通|cartoon|欧美/.test(low) ? 4 : 0,
      anime: /二次元|anime|manga/.test(low) ? 4 : 0,
      stylized: /风格化|stylized|潮玩|pixar/.test(low) ? 4 : 0,
    };
    const bestStyle = Object.entries(styleScores).sort((a, b) => b[1] - a[1])[0][0] || 'unspecified';
    const cat = bestCat[0] === 'character' && bestCat[1] === 0 ? 'uncategorized' : bestCat[0];
    return { top: 'art', parts: ['art', cat, bestStyle], score: top[1] };
  }
  return { top: top[0], parts: [top[0]], score: top[1] };
}

const sessions = walk(path.join(os.homedir(), '.dsh', 'sessions'))
  .filter((f) => new Date(fs.statSync(f).mtimeMs).toDateString() === now.toDateString());

const index = [];
const seen = new Set();
const catCount = {};
const termCount = {};
const allTerms = new Set([...D.art, ...D.video, ...D.vibcoding, ...D.task, ...ART_CATS.flatMap((c) => D[c])]);

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
    const p = path.join(dir, `${day}_${safe(title)}_${hash}.md`);
    if (!fs.existsSync(p)) {
      fs.writeFileSync(p, `---\ndate: ${day}\nsession: ${header.id || ''}\ntitle: ${title}\ncategory: ${c.parts.join('/')}\nscore: ${c.score}\n---\n\n# ${title}\n\n${text}\n`, 'utf8');
    }
    const cat = c.parts.join('/');
    catCount[cat] = (catCount[cat] || 0) + 1;
    for (const term of allTerms) {
      if (text.includes(term)) termCount[term] = (termCount[term] || 0) + 1;
    }
    index.push({ date: day, title, session: header.id || '', category: cat, score: c.score, file: path.relative(rootDir, p).replaceAll('\\', '/') });
  }
}

const keywords = Object.entries(termCount).sort((a, b) => b[1] - a[1]).slice(0, 30).map(([term, count]) => ({ term, count }));
fs.writeFileSync(path.join(rootDir, 'index.json'), JSON.stringify({
  updated: now.toISOString(), day, total: index.length,
  categories: catCount, keywords, items: index,
}, null, 2), 'utf8');

const md = [
  '# 提示词库索引', '',
  `> ${day} · ${index.length} 条 · 自动分类`, '',
  '## 分类统计', '',
  '| 分类 | 数量 |', '|---|---:|',
  ...Object.entries(catCount).sort((a, b) => b[1] - a[1]).map(([k, v]) => `| ${k} | ${v} |`), '',
  '## 高频词（猜词）', '',
  '| 词 | 次数 |', '|---|---:|',
  ...keywords.slice(0, 15).map((k) => `| ${k.term} | ${k.count} |`), '',
  '## 最近入库', '',
  '| 分类 | 标题 | 文件 |', '|---|---|---|',
  ...index.slice(-20).reverse().map((x) => `| ${x.category} | ${x.title.replace(/\|/g, '\\|')} | [${x.file}](${x.file}) |`), '',
].join('\n');
fs.writeFileSync(path.join(rootDir, 'index.md'), md, 'utf8');
console.log(JSON.stringify({ sessions: sessions.length, prompts: index.length, categories: Object.keys(catCount).length }));
