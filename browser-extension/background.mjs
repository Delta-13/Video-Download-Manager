import {handoff} from './protocol.mjs';

const HOST = 'io.vdm.bridge';
const observed = new Map();
const busy = new Set();
const native = message => chrome.runtime.sendNativeMessage(HOST, message);

chrome.runtime.onInstalled.addListener(async () => {
  await chrome.contextMenus.removeAll();
  chrome.contextMenus.create({id: 'vdm-link', title: '使用 VDM 2 下载链接', contexts: ['link']});
  chrome.contextMenus.create({id: 'vdm-page', title: '使用 VDM 2 下载此页面视频', contexts: ['page', 'video']});
  if ((await chrome.storage.local.get('capture')).capture === undefined) await chrome.storage.local.set({capture: false});
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  const url = info.menuItemId === 'vdm-link' ? info.linkUrl : info.pageUrl || tab?.url;
  try {
    const result = await native({protocolVersion: 1, requestId: crypto.randomUUID(), action: 'send', url});
    await chrome.storage.local.set({lastResult: result.ok ? '任务已发送到 VDM 2' : result.error});
    await chrome.action.setBadgeText({text: result.ok ? '' : '!'});
  } catch {
    await chrome.storage.local.set({lastResult: '未连接下载器，请在 VDM 设置中注册扩展 ID。'});
    await chrome.action.setBadgeText({text: '!'});
  }
});

chrome.webRequest.onBeforeRequest.addListener(details => {
  observed.set(details.url, {method: details.method, time: Date.now()});
  if (observed.size > 1000) {
    for (const [url, value] of observed) if (Date.now() - value.time > 30000) observed.delete(url);
  }
}, {urls: ['http://*/*', 'https://*/*']});

async function updatePending(id, value) {
  const key = `handoff-${id}`;
  if (value) await chrome.storage.session.set({[key]: value});
  else await chrome.storage.session.remove(key);
}

chrome.downloads.onCreated.addListener(async item => {
  if (!(await chrome.storage.local.get('capture')).capture || busy.has(item.id)) return;
  busy.add(item.id);
  try {
    const result = await handoff(item, observed.get(item.finalUrl || item.url), {
      uuid: () => crypto.randomUUID(), native,
      pause: id => chrome.downloads.pause(id), resume: id => chrome.downloads.resume(id),
      cancel: id => chrome.downloads.cancel(id), remember: updatePending,
      forget: id => updatePending(id, null),
    });
    if (!result.ok && !result.skipped) await chrome.storage.local.set({lastResult: '接管失败，已恢复浏览器下载。'});
  } finally { busy.delete(item.id); }
});

// Recover only downloads paused by this extension if its worker was interrupted.
async function recover() {
  const entries = await chrome.storage.session.get(null);
  for (const [key, requestId] of Object.entries(entries)) {
    if (!key.startsWith('handoff-')) continue;
    const id = Number(key.slice(8));
    try { await native({protocolVersion: 1, requestId, action: 'abort'}); } catch {}
    try { await chrome.downloads.resume(id); } catch {}
    await chrome.storage.session.remove(key);
  }
}
await recover();
