import test from 'node:test';
import assert from 'node:assert/strict';
import {handoff, isReplayable} from './protocol.mjs';
const item = {id: 1, url: 'https://example.com/file.zip', state: 'in_progress', filename: 'C:\\Downloads\\file.zip'};
const observed = () => ({method: 'GET', time: Date.now()});
function fixture(failure) {
  const log = [];
  const api = {uuid: () => 'test-request-123', remember: async () => log.push('remember'), forget: async () => log.push('forget')};
  for (const key of ['pause', 'resume', 'cancel']) api[key] = async () => log.push(key);
  api.native = async m => { log.push(m.action); if (failure === m.action) throw new Error('unavailable'); return {ok: true, taskId: 'task'}; };
  return {api, log};
}
test('reject POST, unknown method, blob and user-paused downloads', () => {
  assert.equal(isReplayable(item, {method: 'POST', time: Date.now()}), false);
  assert.equal(isReplayable(item, undefined), false);
  assert.equal(isReplayable({...item, url: 'blob:https://example.com/id'}, observed()), false);
  assert.equal(isReplayable({...item, paused: true}, observed()), false);
});
test('cancel browser only after durable app acceptance and first byte', async () => {
  const {api, log} = fixture(); assert.equal((await handoff(item, observed(), api)).ok, true);
  assert.deepEqual(log, ['remember', 'pause', 'prepare', 'commit', 'cancel', 'forget']);
});
for (const step of ['prepare', 'commit']) test(`${step} failure aborts app and resumes browser`, async () => {
  const {api, log} = fixture(step); assert.equal((await handoff(item, observed(), api)).ok, false);
  assert.ok(!log.includes('cancel')); assert.deepEqual(log.slice(-3), ['abort', 'resume', 'forget']);
});
