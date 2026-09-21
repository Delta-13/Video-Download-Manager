const status = document.querySelector('#status');
const button = document.querySelector('#send');
const toggle = document.querySelector('#capture');
document.querySelector('#extensionId').textContent = chrome.runtime.id;
const saved = await chrome.storage.local.get(['capture', 'lastResult']);
toggle.checked = saved.capture === true;
if (saved.lastResult) status.textContent = saved.lastResult;
button.addEventListener('click', async () => {
  button.disabled = true; button.textContent = '正在发送…'; status.textContent = '正在连接本机下载器';
  try {
    const [tab] = await chrome.tabs.query({active: true, currentWindow: true});
    if (!tab?.url || !/^https?:\/\//.test(tab.url)) throw new Error('请在视频网页上使用此操作。');
    const result = await chrome.runtime.sendNativeMessage('io.vdm.bridge', {protocolVersion: 1, requestId: crypto.randomUUID(), action: 'send', url: tab.url});
    if (!result.ok) throw new Error(result.error || '发送失败');
    status.textContent = '任务已发送到 VDM 2'; await chrome.action.setBadgeText({text: ''});
  } catch (error) { status.textContent = error.message || '未连接，请先注册扩展 ID。'; }
  finally { button.disabled = false; button.textContent = '发送当前页面'; }
});
toggle.addEventListener('change', async () => {
  if (toggle.checked) {
    const allowed = await chrome.permissions.request({origins: ['http://*/*', 'https://*/*']});
    if (!allowed) toggle.checked = false;
  }
  await chrome.storage.local.set({capture: toggle.checked});
  status.textContent = toggle.checked ? '已开启普通文件下载接管' : '已关闭下载接管';
});
document.querySelector('#copy').addEventListener('click', async () => {
  await navigator.clipboard.writeText(chrome.runtime.id); status.textContent = '扩展 ID 已复制';
});
