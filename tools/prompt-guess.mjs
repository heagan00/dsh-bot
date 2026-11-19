import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const args = process.argv.slice(2);
const text = args.find((a) => a.startsWith('--text='))?.split('=')[1] || '';
const root = path.join(os.homedir(), 'Downloads', 'ComfyUI相关', 'prompt-library');
const indexPath = path.join(root, 'index.json');

const D = {
  task: ['需求', '实现', '制作', '修复', '计划', '生成', '输出', '文件', '项目', '自动', '任务', '流程', '整理', '检查', '配置'],
  vibcoding: ['代码', '函数', 'api', '接口', '脚本', '调试', 'bug', '测试', '部署', 'git', '命令', '程序', '编译', '自动化'],
  video: ['视频', '运镜', '镜头', '时长', '帧率', '转场', '音效', '首帧', '尾帧', 'seedance', 'kling', 'wan', 'h3', 'ltx'],
  art: ['美术', '角色', '立绘', '场景', '道具', '界面', 'ui', 'icon', '图标', '插画', '分镜', '关键帧', '构图', '光影', '材质', '风格', '配色'],
  character: ['角色', '立绘', '人物', '服装', '三视图', 'npc', '怪物'],
  scene: ['场景', '地图', '环境', '建筑', '关卡'],
  props: ['道具', '武器', '载具', '宝箱', '装备'],
  ui: ['界面', '按钮', 'hud', '菜单', '面板'],
  icon: ['图标', 'icon', '徽章'],
  illustration: ['插画', 'kv', '主视觉', '海报'],
  storyboard: ['分镜', 'storyboard'],
  keyframe: ['关键帧', '首帧', '尾帧'],
};

let index = { keywords: [] };
if (fs.existsSync(indexPath)) {
  try { index = JSON.parse(fs.readFileSync(indexPath, 'utf8')); } catch {}
}
function score(t, terms) { let s = 0; for (const k of terms) if (t.includes(k)) s += 1; return s; }

if (!text) {
  console.log(JSON.stringify({ keywords: (index.keywords || []).slice(0, 20) }, null, 2));
  process.exit(0);
}
const low = text.toLowerCase();
const scored = Object.entries(D).map(([category, terms]) => ({ category, score: score(low, terms) }))
  .filter((x) => x.score > 0).sort((a, b) => b.score - a.score);
const top = scored[0]?.category || 'task';
const related = (index.keywords || []).filter((k) => k.term && (text.includes(k.term) || top.includes(k.term))).slice(0, 8);
const out = {
  input: text,
  guesses: scored.slice(0, 5),
  topCategory: top,
  keywords: related,
  hint: scored.length ? `先按 ${top} 收口；补 ${related.slice(0, 4).map((x) => x.term).join(' / ') || '主体、风格、构图'}` : '没有命中词库，先补主体/风格/用途',
};
console.log(JSON.stringify(out, null, 2));
