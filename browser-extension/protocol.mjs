export function isReplayable(item, observed) {
  if (item.state !== 'in_progress' || item.paused || !/^https?:\/\//i.test(item.finalUrl || item.url)) return false;
  if (!observed || observed.method !== 'GET' || Date.now() - observed.time > 30000) return false;
  if (item.mime?.includes('text/html')) return false;
  return true;
}

export async function handoff(item, observed, api) {
  if (!isReplayable(item, observed)) return {ok: false, skipped: true};
  const requestId = api.uuid();
  const base = {protocolVersion: 1, requestId};
  let paused = false;
  let prepared = false;
  try {
    await api.remember(item.id, requestId);
    await api.pause(item.id);
    paused = true;
    const ready = await api.native({...base, action: 'prepare', method: 'GET',
      url: item.finalUrl || item.url, filename: item.filename.split(/[\\/]/).pop(), referer: item.referrer || ''});
    if (!ready.ok) throw new Error(ready.error || '下载器未接收任务');
    prepared = true;
    const started = await api.native({...base, action: 'commit'});
    if (!started.ok) throw new Error(started.error || '下载器未开始下载');
    await api.cancel(item.id);
    await api.forget(item.id);
    return started;
  } catch (error) {
    // Abort is idempotent and is also sent when a prepare reply was lost.
    try { await api.native({...base, action: 'abort'}); } catch { /* App may be unavailable. */ }
    if (paused) { try { await api.resume(item.id); } catch { /* Browser task may already have completed. */ } }
    await api.forget(item.id);
    return {ok: false, prepared, error: String(error.message || error)};
  }
}
