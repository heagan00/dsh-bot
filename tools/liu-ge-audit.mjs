import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const reportPath = args.find((a) => a.startsWith('--report='))?.split('=')[1] || '';
const outPath = args.find((a) => a.startsWith('--out='))?.split('=')[1] || '';
const memoryPath = args.find((a) => a.startsWith('--memory='))?.split('=')[1] || '';
if (!reportPath || !fs.existsSync(reportPath)) {
  console.error('missing report');
  process.exit(1);
}

const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
const sessions = new Map((report.sessions || []).map((s) => [s.id, s]));
const findings = [];
let memory = {};
if (memoryPath && fs.existsSync(memoryPath)) {
  try { memory = JSON.parse(fs.readFileSync(memoryPath, 'utf8')).entries || {}; } catch {}
}
function patternOf(key) { return String(key || '').split(':')[0]; }
function memoryInfo(key) {
  const p = patternOf(key);
  const e = memory[p];
  return e ? { pattern: p, repeatCount: Number(e.count || 0), agreed: !!e.agreed, last: e.last || '' } : { pattern: p, repeatCount: 0, agreed: false, last: '' };
}

function add(alert, problem, whyFine, advice) {
  const mem = memoryInfo(alert.key);
  findings.push({
    zhouKey: alert.key,
    sessionId: alert.sessionId,
    title: alert.title,
    zhouMessage: alert.message,
    verdict: 'false_positive',
    problem,
    whyFine,
    advice,
    pattern: mem.pattern,
    repeatCount: mem.repeatCount,
    severe: mem.repeatCount > 0 && mem.agreed,
  });
}

for (const a of report.alerts || []) {
  const ids = String(a.sessionId || '').split(',').map((x) => x.trim()).filter(Boolean);
  const s = ids.length === 1 ? sessions.get(ids[0]) : null;
  const key = String(a.key || '');
  const text = String(a.message || '');
  const lastUser = String(s?.lastUser || '');

  if (key.startsWith('token:')) {
    if (!s) {
      add(a, '周哥没有找到对应会话，仍按累计/缓存数据报警。', '会话已经结束或不在 30 分钟活跃窗口内，属于旧数据误报。', '周哥应先确认会话仍活跃，再判断 token；否则只写日报，不弹窗。');
      continue;
    }
    if (!s.activeTurn) {
      add(a, '周哥把已结束的会话当成正在运行。', '当前没有活跃 turn，token 是历史消耗，不会继续烧算力。', '先看 activeTurn；已结束的会话最多写日报。');
      continue;
    }
    if (s.editCalls > 0 && s.recentTokens < 5000000) {
      add(a, '周哥只看 token 数值，没有看实际产出。', `该会话近 30 分钟已落盘 ${s.editCalls} 次修改，属于大任务正常消耗，不是空转。`, 'token 告警应结合 edit/test/tool 产出；有落盘时降级为观察。');
      continue;
    }
    if (s.editCalls > 0) {
      add(a, '周哥把长上下文/缓存 token 当成纯浪费。', `会话有 ${s.editCalls} 次落盘，任务在推进；高 token 主要来自长历史与缓存，不等于 agent 原地打转。`, '先看 unit economics（每次有效产出的 token），不要只报绝对值。');
      continue;
    }
  }

  if (key.startsWith('repeat:')) {
    if (!s || !s.activeTurn) {
      add(a, '周哥在会话结束后仍报“重复调用”。', '会话已不活跃，重复记录不会继续消耗算力。', '先过滤 activeTurn，再谈重复。');
      continue;
    }
    const name = s.repeated?.[0]?.name || '';
    if (['read', 'grep', 'glob', 'search'].includes(name)) {
      add(a, '周哥把“重复读取/检索”直接当成浪费。', `重复的是 ${name}，通常用于交叉核对同一份内容；在审查/排错任务里是必要校验，不是空转。`, '重复调用要区分“读”和“重跑”：读可缓存，重跑才可能浪费。');
      continue;
    }
  }

  if (key.startsWith('retry:')) {
    if (!s || !s.activeTurn) {
      add(a, '周哥对已结束会话报重试。', '没有活跃 turn，重试不会继续发生。', '重试告警只在 activeTurn 内有效。');
      continue;
    }
  }

  if (key.startsWith('job:')) {
    if (!s || !s.activeTurn) {
      add(a, '周哥把历史 job 当成正在占用算力。', '会话已不活跃，job 记录可能是旧任务或已收尾但事件未完整解析。', '先核对 job 的 settled/进程状态，再报“未收尾”。');
      continue;
    }
  }

  if (key.startsWith('noedit:')) {
    if (/分析|解释|评估|审查|review|explain|方案|调研|对比/.test(lastUser)) {
      add(a, '周哥把“分析/审查任务”误判成“只读不产出”。', '用户要的是判断和方案，不是改代码；不落盘是任务性质决定的。', '先看用户意图：分析类任务不应以 edit 数量作为进度指标。');
      continue;
    }
  }

  if (key.startsWith('dupe:')) {
    const active = ids.map((id) => sessions.get(id)).filter((x) => x && x.activeTurn);
    if (active.length < 2) {
      add(a, '周哥把“相似目标”当成“并发重复”，但没有确认两边都还在跑。', `实际只有 ${active.length} 个活跃会话，另一个已结束/不在窗口内。`, '并发重复必须同时满足：都 active、同一目标、都在消耗；缺一不可。');
      continue;
    }
  }
}

const out = {
  generatedAt: new Date().toISOString(),
  sourceReport: reportPath,
  activeSessions: report.activeSessions,
  falsePositives: findings,
  note: findings.length ? '周哥本轮存在误报，刘哥已给出反证。' : '周哥本轮未发现明显误报。',
};
if (outPath) fs.writeFileSync(outPath, JSON.stringify(out, null, 2), 'utf8');
console.log(JSON.stringify({ falsePositives: findings.length, activeSessions: report.activeSessions }));
