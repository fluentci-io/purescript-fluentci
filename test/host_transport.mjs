import { test } from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import { requestImpl, parseEvents } from "../src/FluentCI/Host/Client.js";

async function server(handler) {
  const value = http.createServer(handler);
  await new Promise(resolve => value.listen(0, "127.0.0.1", resolve));
  return { value, baseUrl: `http://127.0.0.1:${value.address().port}`, close: () => new Promise(resolve => { value.close(resolve); value.closeAllConnections(); }) };
}
const config = baseUrl => ({ baseUrl, token: "must-not-leak", timeoutMs: 1000 });
const request = (cfg, path = "/") => new Promise((resolve, reject) => requestImpl(cfg)(false)("GET")(path)("")(reject, resolve));

test("request deadlines abort stalled HTTP responses without exposing credentials", async () => {
  const host = await server(() => {});
  try {
    await assert.rejects(request({ ...config(host.baseUrl), timeoutMs: 30 }), error => {
      assert.match(error.message, /timed out/);
      assert.ok(!error.message.includes("must-not-leak"));
      return true;
    });
  } finally { await host.close(); }
});

test("Aff canceler aborts the HTTP request and suppresses completion callbacks", async () => {
  let sawRequest;
  const seen = new Promise(resolve => { sawRequest = resolve; });
  let closed;
  const disconnected = new Promise(resolve => { closed = resolve; });
  const host = await server(req => { req.on("close", closed); sawRequest(); });
  let callbacks = 0;
  try {
    const cancel = requestImpl(config(host.baseUrl))(false)("GET")("/")("")(() => callbacks++, () => callbacks++);
    await seen;
    await new Promise((resolve, reject) => cancel(new Error("cancel"), reject, resolve));
    await disconnected;
    await new Promise(resolve => setTimeout(resolve, 10));
    assert.equal(callbacks, 0);
  } finally { await host.close(); }
});

test("redirects cannot forward bearer credentials to another endpoint", async () => {
  let requests = 0;
  const target = await server((_req, res) => { requests++; res.end("unexpected"); });
  const source = await server((_req, res) => { res.writeHead(307, { Location: target.baseUrl }); res.end(); });
  try {
    await assert.rejects(request(config(source.baseUrl)), /request failed/);
    assert.equal(requests, 0);
  } finally { await source.close(); await target.close(); }
});

test("malformed event journals become decoder errors", () => {
  const parse = parseEvents(error => ({ error }))(events => ({ events }));
  assert.deepEqual(parse('{"type":"run_finished"}\n'), { events: [{ type: "run_finished" }] });
  assert.deepEqual(parse("{broken}\n"), { error: "malformed event journal" });
});
