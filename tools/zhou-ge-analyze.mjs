import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import zlib from 'node:zlib';

const args = process.argv.slice(2);
const windowMinutes = Number(args.find((a) => a.startsWith('--minutes='))?.split('=')[1] || 15);
const outArg = args.find((a) => a.startsWith('--out='))?.split('=')[1] || '';
const rootArg = args.find((a) => a.startsWith('--root='))?.split('=')[1] || '';
const now = Date.now();
const cutoff = now - windowMinutes * 60 * 1000;

function walk(dir) {
  const out = [];
  if (!fs.existsSync(dir)) return out;
  for (const n of fs.readdirSync(dir)) {
    const p = path.join(dir, n);
    const st = fs.statSync(p);
    if (st.isDirectory()) out.push(...walk(p));
    else if (/session\..*\.jsonl\.zstd$/i.test(n)) out.push(p);
  }
  return out;
}

function decompress(file) {
  const buf = fs.readFileSync(file);
  const magic = Buffer.from([0x28, 0xb5, 0x2f, 0xfd]);
  const offs = [];
  let p = 0;
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

const root = rootArg || path.join(os.homedir(), '.dsh', 'sessions');
const files = walk(root).filter((f) => fs.statSync(f).mtimeMs >= cutoff);
const sessions = [];
const alerts = [];

for (const file of files) {
  let events = [];
  try {
    events = decompress(file).split(/\r?\n/).filter(Boolean).map((l) => JSON.parse(l));
  } catch { continue; }
  if (!events.length) continue;
  const header = events.find((e) => e.type === 'session') || {};
  const id = header.id || path.basename(path.dirname(file));
  const titleEvent = [...events].reverse().find((e) => e.type === 'session/title');
  const title = titleEvent?.data?.title || id;
  const last = events[events.length - 1];
  const lastTime = last?.time || last?.data?.time || 0;

  let turnStart = 0, turnEnd = 0, steps = 0;
  let tokens = 0, recentTokens = 0, retries = 0, subagents = 0, editCalls = 0, toolCalls30 = 0;
  let lastUser = '', lastAssistant = '';
  const callCounts = new Map();
  const openJobs = new Map();

  for (const e of events) {
    const d = e.data || {};
    const t = e.time || d.time || 0;
    if (e.type === 'turn/start') turnStart++;
    if (e.type === 'turn/end') turnEnd++;
    if (e.type === 'step/start') steps++;
    if (e.type === 'llm/retry' && t >= cutoff) retries++;
    if (e.type === 'subagent/descriptor') subagents++;
    if (e.type === 'assistant/message') {
      const used = Number(d.usage?.totalTokens || 0);
      tokens += used;
      if (t >= cutoff) recentTokens += used;
      const txt = textOf(d.message?.content);
      if (txt) lastAssistant = txt;
    }
    if (e.type === 'user/message' && (d.source?.kind === 'user')) {
      const txt = textOf(d.content);
      if (txt) lastUser = txt;
    }
    if (e.type === 'tool/call' && t >= cutoff) {
      const sig = `${d.name || ''}|${d.arguments || ''}`;
      callCounts.set(sig, (callCounts.get(sig) || 0) + 1);
      toolCalls30++;
      if (['write', 'edit', 'apply_patch'].includes(d.name)) editCalls++;
    }
    if (e.type === 'job/registered') {
      const jid = d.jobId || d.id || d.job?.id;
      if (jid) openJobs.set(jid, t);
    }
    if (e.type === 'job/settled') {
      const jid = d.jobId || d.id || d.job?.id;
      if (jid) openJobs.delete(jid);
    }
  }

  const activeTurn = turnStart > turnEnd;
  const repeated = [...callCounts.entries()]
    .filter(([, c]) => c >= 3)
    .map(([sig, count]) => ({ name: sig.split('|')[0], count, args: sig.split('|').slice(1).join('|') }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 3);

  const openJobList = [...openJobs.entries()].map(([jobId, start]) => ({ jobId, ageMin: Math.round((now - start * 1000) / 60000) }));
  const longJobs = openJobList.filter((j) => j.ageMin >= 30);

  sessions.push({ id, title, file, modified: fs.statSync(file).mtimeMs, activeTurn, steps, tokens, recentTokens, retries, subagents, editCalls, toolCalls30, repeated, openJobs: openJobList, lastUser: lastUser.slice(0, 200) });

  if (repeated.length) {
    const r = repeated[0];
    alerts.push({
      level: 'high',
      sessionId: id,
      title,
      key: `repeat:${id}:${r.name}`,
      message: `同一工具调用重复 ${r.count} 次：${r.name}`,
      advice: '先停 10 秒：这个调用是不是在轮询/重复读同一份内容？把结果缓存，合并成一次；如果是等待，改用 job 状态检查，不要连续重跑。',
    });
  }
  if (retries >= 3) {
    alerts.push({
      level: 'high', sessionId: id, title, key: `retry:${id}`,
      message: `30 分钟内模型重试 ${retries} 次`,
      advice: '重试不是进度。检查上下文是否过长、工具参数是否非法、模型是否不适合；缩小任务或换模型，别让 agent 原地烧 token。',
    });
  }
  if (longJobs.length) {
    alerts.push({
      level: 'high', sessionId: id, title, key: `job:${id}`,
      message: `有后台 job 超过 30 分钟未收尾（${longJobs.length} 个）`,
      advice: '先查 job 输出/进程，能结束就结束；不要让后台任务一直占算力。把长任务拆成可验收的小步。',
    });
  }
  if (recentTokens >= 1500000) {
    alerts.push({
      level: 'high', sessionId: id, title, key: `token:${id}`,
      message: `近 ${windowMinutes} 分钟消耗 ${Math.round(recentTokens / 1000)}k tokens`,
      advice: '算力消耗过高。先停掉无关工具调用，明确当前 turn 的验收标准；必要时开新会话，只带必要上下文，避免整个历史反复重跑。',
    });
  }
  if (activeTurn && steps >= 25 && editCalls === 0) {
    alerts.push({
      level: 'medium', sessionId: id, title, key: `noedit:${id}`,
      message: `仍在运行：${steps} 个 step，0 次落盘修改`,
      advice: '读/查/想得太多，产出太少。先写最小改动或最小复现，再继续；主程看的是可交付，不是工具调用数。',
    });
  }
}

// 同一目标并发跑多个会话，容易重复烧算力
const byGoal = new Map();
for (const s of sessions) {
  const k = (s.lastUser || '').replace(/\s+/g, ' ').slice(0, 60);
  if (!k) continue;
  if (!byGoal.has(k)) byGoal.set(k, []);
  byGoal.get(k).push(s);
}
for (const [goal, list] of byGoal) {
  if (list.length >= 2) {
    alerts.push({
      level: 'high',
      sessionId: list.map((x) => x.id).join(','),
      title: '并发重复目标',
      key: `dupe:${goal}`,
      message: `${list.length} 个活跃会话在做同一目标：${goal}`,
      advice: '停掉重复会话，只保留一个主会话；其余改成子任务或直接关闭，避免多 agent 同时烧算力。',
    });
  }
}

const report = {
  generatedAt: new Date().toISOString(),
  windowMinutes,
  activeSessions: sessions.length,
  sessions: sessions.sort((a, b) => b.modified - a.modified),
  alerts: alerts.sort((a, b) => (a.level === 'high' ? -1 : 1) - (b.level === 'high' ? -1 : 1)),
};

if (outArg) fs.writeFileSync(outArg, JSON.stringify(report, null, 2), 'utf8');
console.log(JSON.stringify({ activeSessions: report.activeSessions, alerts: report.alerts.length, high: report.alerts.filter((a) => a.level === 'high').length }));
