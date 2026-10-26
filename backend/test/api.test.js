const { test, before, after } = require('node:test');
const assert = require('node:assert');
const { once } = require('node:events');
const app = require('../server');

let server, base;
before(async () => {
  server = app.listen(0);                       // random free port
  await once(server, 'listening');
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());

test('health returns 200', async () => {
  assert.strictEqual((await fetch(`${base}/api/health`)).status, 200);
});
test('metrics are exposed', async () => {
  const res = await fetch(`${base}/metrics`);
  assert.match(await res.text(), /http_request_duration_seconds/);
});
test('real GET route works', async () => {
  assert.strictEqual((await fetch(`${base}/api/<REAL_GET_ROUTE>`)).status, 200);
});
test('protected route rejects missing API key', async () => {
  const res = await fetch(`${base}/api/<PROTECTED_ROUTE>`, { method: 'POST' });
  assert.strictEqual(res.status, 401);
});