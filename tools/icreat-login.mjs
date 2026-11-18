import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const tabs = await fetch('http://127.0.0.1:9222/json').then((r) => r.json());
const page = tabs.find((t) => t.type === 'page' && /icreat\.ai/i.test(t.url)) || tabs.find((t) => t.type === 'page');
if (!page) throw new Error('no Chrome page target');

const ws = new WebSocket(page.webSocketDebuggerUrl);
let nextId = 0;
const pending = new Map();
function call(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = ++nextId;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
    setTimeout(() => { if (pending.has(id)) { pending.delete(id); reject(new Error('CDP timeout: ' + method)); } }, 10000);
  });
}
ws.addEventListener('message', (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) {
    const p = pending.get(msg.id); pending.delete(msg.id);
    if (msg.error) p.reject(new Error(msg.error.message)); else p.resolve(msg.result);
  }
});
await new Promise((resolve, reject) => {
  ws.addEventListener('open', resolve, { once: true });
  ws.addEventListener('error', reject, { once: true });
});

const result = await call('Network.getAllCookies');
const cookies = (result.cookies || []).filter((c) => /(^|\.)icreat\.ai$/i.test(c.domain));
const header = cookies.map((c) => `${c.name}=${c.value}`).join('; ');
if (!header) throw new Error('no icreat.ai cookies');

const dir = path.join(os.homedir(), '.icreat');
fs.mkdirSync(dir, { recursive: true });
fs.writeFileSync(path.join(dir, 'session.txt'), header, 'utf8');
console.log(`saved ${cookies.length} cookies: ${cookies.map((c) => c.name).join(', ')}`);
console.log(`page=${page.url}`);
ws.close();
