// Run: node --test tools/ai_proxy/server.test.mjs
import assert from 'node:assert/strict';
import http from 'node:http';
import { after, before, describe, test } from 'node:test';

import { createProxy, SYSTEM_PROMPT } from './server.mjs';

function listen(server) {
  return new Promise((resolve) =>
    server.listen(0, '127.0.0.1', () => resolve(server.address().port)),
  );
}

async function post(port, body, raw = false) {
  const response = await fetch(`http://127.0.0.1:${port}/explain`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: raw ? body : JSON.stringify(body),
  });
  return { status: response.status, json: await response.json() };
}

const valid = {
  question: 'Will I make my connection?',
  language: 'en',
  facts: { trains: [{ number: '90101', delayMinutes: 90 }] },
};

describe('ai proxy', () => {
  let upstreamRequests = [];
  let upstreamStatus = 200;
  let upstream;
  let upstreamPort;
  let proxy;
  let proxyPort;
  let unconfigured;
  let unconfiguredPort;

  before(async () => {
    upstream = http.createServer((request, response) => {
      let data = '';
      request.on('data', (chunk) => (data += chunk));
      request.on('end', () => {
        upstreamRequests.push({ headers: request.headers, body: JSON.parse(data) });
        response.writeHead(upstreamStatus, { 'content-type': 'application/json' });
        response.end(
          JSON.stringify({ content: [{ type: 'text', text: 'Train 90101 is late.' }] }),
        );
      });
    });
    upstreamPort = await listen(upstream);
    proxy = createProxy({
      apiKey: 'test-key',
      model: 'test-model',
      baseUrl: `http://127.0.0.1:${upstreamPort}`,
      perMinute: 1000,
    });
    proxyPort = await listen(proxy);
    unconfigured = createProxy({ apiKey: '' });
    unconfiguredPort = await listen(unconfigured);
  });

  after(() => {
    proxy.close();
    upstream.close();
    unconfigured.close();
  });

  test('returns the model text and sends the rules and facts', async () => {
    upstreamRequests = [];
    const { status, json } = await post(proxyPort, valid);
    assert.equal(status, 200);
    assert.deepEqual(json, { text: 'Train 90101 is late.' });

    const sent = upstreamRequests.at(-1);
    assert.equal(sent.headers['x-api-key'], 'test-key');
    assert.equal(sent.body.model, 'test-model');
    assert.equal(sent.body.system, SYSTEM_PROMPT);
    const user = JSON.parse(sent.body.messages[0].content);
    assert.equal(user.question, valid.question);
    assert.deepEqual(user.facts, valid.facts);
  });

  test('rejects a bad request without calling the model', async () => {
    upstreamRequests = [];
    for (const body of [
      { ...valid, question: '' },
      { ...valid, question: 'x'.repeat(501) },
      { ...valid, language: 'fr' },
      { ...valid, facts: 'nope' },
      { ...valid, facts: [] },
    ]) {
      const { status } = await post(proxyPort, body);
      assert.equal(status, 400);
    }
    const bad = await post(proxyPort, '{not json', true);
    assert.equal(bad.status, 400);
    assert.equal(upstreamRequests.length, 0);
  });

  test('hides provider failures from the app', async () => {
    upstreamStatus = 500;
    const { status, json } = await post(proxyPort, valid);
    upstreamStatus = 200;
    assert.equal(status, 502);
    assert.equal(json.error, 'AI service did not answer.');
  });

  test('says so when no key is configured', async () => {
    const { status, json } = await post(unconfiguredPort, valid);
    assert.equal(status, 503);
    assert.match(json.error, /not configured/);
  });

  test('the rules forbid promises and invented values', () => {
    assert.match(SYSTEM_PROMPT, /Never invent or guess/);
    assert.match(SYSTEM_PROMPT, /Never promise/);
    assert.match(SYSTEM_PROMPT, /isSimulatedDemoData/);
  });
});
