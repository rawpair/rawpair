import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import http from 'node:http'
import { once } from 'node:events'
import WebSocket from 'ws'
import * as Y from 'yjs'
import { WebsocketProvider } from 'y-websocket'
import { createCollaborationServer } from './server.mjs'

const wait = async (condition, timeout = 5000) => {
  const end = Date.now() + timeout
  while (!condition()) {
    if (Date.now() > end) throw new Error('Timed out waiting for collaboration')
    await new Promise(resolve => setTimeout(resolve, 20))
  }
}

test('authenticated file rooms converge, remain independent, and persist reconnects', async () => {
  const secret = 'a'.repeat(64)
  const origin = 'https://rawpair.localhost'
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'rawpair-yjs-'))
  const auth = http.createServer(async (request, response) => {
    let body = ''
    for await (const chunk of request) body += chunk
    const data = JSON.parse(body)
    if (data.ticket !== 'member' || request.headers.authorization !== `Bearer ${secret}`) return response.writeHead(403).end()
    const [, file] = JSON.parse(Buffer.from(data.document, 'base64url').toString())
    response.setHeader('content-type', 'application/json')
    response.end(JSON.stringify({ authorized: true, contents: file === 'a.txt' ? 'alpha' : 'beta' }))
  }).listen(0, '127.0.0.1')
  await once(auth, 'listening')
  const service = createCollaborationServer({ secret, directory, origin, authUrl: `http://127.0.0.1:${auth.address().port}` })
  service.server.listen(0, '127.0.0.1')
  await once(service.server, 'listening')
  const base = `ws://127.0.0.1:${service.server.address().port}/collaboration`
  const room = file => Buffer.from(JSON.stringify([1, file, 0])).toString('base64url')
  const clients = []
  const connect = async (file, ticket = 'member') => {
    const doc = new Y.Doc()
    const provider = new WebsocketProvider(base, room(file), doc, {
      WebSocketPolyfill: class extends WebSocket {
        constructor(url, protocols) { super(url, protocols, { origin }) }
      },
      params: { ticket }, disableBc: true,
    })
    clients.push({ doc, provider })
    await wait(() => provider.synced)
    return { doc, provider }
  }
  try {
    const first = await connect('a.txt')
    const second = await connect('a.txt')
    const other = await connect('b.txt')
    assert.equal(first.doc.getText('monaco').toString(), 'alpha')
    first.doc.getText('monaco').insert(5, '!')
    second.doc.getText('monaco').insert(0, 'shared ')
    await wait(() => first.doc.getText('monaco').toString() === second.doc.getText('monaco').toString())
    assert.equal(other.doc.getText('monaco').toString(), 'beta')
    const reload = await fetch(`http://127.0.0.1:${service.server.address().port}/internal/documents/${room('a.txt')}`, {
      method: 'PUT', headers: { authorization: `Bearer ${secret}`, 'content-type': 'application/json' },
      body: JSON.stringify({ contents: 'changed by Git' }),
    })
    assert.equal(reload.status, 204)
    await wait(() => first.doc.getText('monaco').toString() === 'changed by Git' && second.doc.getText('monaco').toString() === 'changed by Git')
    assert.equal(other.doc.getText('monaco').toString(), 'beta')
    const saved = first.doc.getText('monaco').toString()
    first.provider.destroy(); second.provider.destroy()
    await new Promise(resolve => setTimeout(resolve, 100))
    const reconnected = await connect('a.txt')
    assert.equal(reconnected.doc.getText('monaco').toString(), saved)
    for (const [ticket, options] of [
      ['stranger', { origin }], ['member', {}], ['member', { origin: 'https://untrusted.example' }],
    ]) {
      const denied = new WebSocket(`${base}/${room('a.txt')}?ticket=${ticket}`, options)
      const status = await new Promise(resolve => {
        denied.on('unexpected-response', (_, response) => { response.resume(); resolve(response.statusCode) })
        denied.on('error', () => {})
      })
      denied.terminate()
      assert.equal(status, 403)
    }
    assert.equal(fs.readdirSync(directory).filter(name => name.endsWith('.bin')).length, 2)
    const reset = await fetch(`http://127.0.0.1:${service.server.address().port}/internal/workspaces/1/documents`, {
      method: 'DELETE', headers: { authorization: `Bearer ${secret}` },
    })
    assert.equal(reset.status, 204)
    await new Promise(resolve => setTimeout(resolve, 100))
    assert.equal(fs.readdirSync(directory).length, 0)
  } finally {
    for (const { doc, provider } of clients) { provider.destroy(); doc.destroy() }
    for (const socket of service.sockets.clients) socket.terminate()
    await new Promise(resolve => service.server.close(resolve))
    await new Promise(resolve => auth.close(resolve))
    fs.rmSync(directory, { recursive: true, force: true })
  }
})
