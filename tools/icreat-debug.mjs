import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const tabs = await fetch('http://127.0.0.1:9222/json').then((r) => r.json());
const page = tabs.find((t) => t.type === 'page' && /icreat\.ai/i.test(t.url)) || tabs.find((t) => t.type === 'page');
if (!page) throw new Error('no page');
const ws = new WebSocket(page.webSocketDebuggerUrl);
let id = 0;
const pending = new Map();
const requests = [];
function call(method, params = {}) {
  return new Promise((resolve, reject) => {
    const n = ++id; pending.set(n, { resolve, reject });
    ws.send(JSON.stringify({ id: n, method, params }));
    setTimeout(() => { if (pending.has(n)) { pending.delete(n); reject(new Error('timeout ' + method)); } }, 10000);
  });
}
ws.addEventListener('message', (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) {
    const p = pending.get(m.id); pending.delete(m.id);
    if (m.error) p.reject(new Error(m.error.message)); else p.resolve(m.result);
  }
  if (m.method === 'Network.requestWillBeSent') {
    const r = m.params.request;
    if (/\/api\/nexus\//.test(r.url)) {
      requests.push({ url: r.url, method: r.method, headers: r.headers, postData: r.postData || '' });
    }
  }
});
await new Promise((res, rej) => { ws.addEventListener('open', res, { once: true }); ws.addEventListener('error', rej, { once: true }); });

await call('Network.enable');
await call('Page.enable');
await call('Page.reload', { ignoreCache: true });
await new Promise((r) => setTimeout(r, 6000));

const store = await call('Runtime.evaluate', {
  expression: `JSON.stringify({local:Object.fromEntries(Object.entries(localStorage).filter(([k])=>/token|auth|user|session|login/i.test(k))), session:Object.fromEntries(Object.entries(sessionStorage).filter(([k])=>/token|auth|user|session|login/i.test(k)))})`,
  returnByValue: true,
});

const dir = path.join(os.homedir(), '.icreat');
fs.mkdirSync(dir, { recursive: true });
fs.writeFileSync(path.join(dir, 'network.json'), JSON.stringify({ requests, storage: store.result.value }, null, 2), 'utf8');
console.log('captured requests=' + requests.length);
for (const r of requests) {
  const h = r.headers || {};
  const keys = Object.keys(h).filter((k) => /auth|cookie|token|session/i.test(k));
  console.log(r.method + ' ' + r.url.replace(/\?.*/, '') + ' headers=' + keys.join(',') + ' cookie=' + (h.Cookie || h.cookie ? 'yes' : 'no') + ' auth=' + (h.Authorization || h.authorization ? 'yes' : 'no'));
}
console.log('storage=' + store.result.value);
ws.close();
