// Exercise the installed collaboration dependencies and real Phoenix authorization.
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { execFileSync } from 'node:child_process'
import { createRequire } from 'node:module'
const require = createRequire('/opt/rawpair-collaboration/package.json')
const WebSocket = require('ws')
const Y = require('yjs')
const { WebsocketProvider } = await import(require.resolve('y-websocket'))
const { tickets, terminal } = JSON.parse(fs.readFileSync('/var/lib/rawpair/collaboration-acceptance.json'))
const tlsOptions = {
  ca: fs.readFileSync(execFileSync('mkcert', ['-CAROOT'], { encoding: 'utf8' }).trim() + '/rootCA.pem'),
  lookup: (_, options, callback) => options.all ? callback(null, [{ address: '127.0.0.1', family: 4 }]) : callback(null, '127.0.0.1', 4),
}
const clients = tickets.map(({ document, ticket }) => {
  const doc = new Y.Doc()
  const provider = new WebsocketProvider('wss://rawpair.localhost/collaboration', document, doc, {
    params: { ticket }, disableBc: true,
    WebSocketPolyfill: class extends WebSocket {
      constructor(url, protocols) { super(url, protocols, tlsOptions) }
    },
  })
  return { doc, provider }
})
const wait = async condition => {
  const end = Date.now() + 10000
  while (!condition()) {
    if (Date.now() > end) throw new Error('Installed collaboration timed out')
    await new Promise(resolve => setTimeout(resolve, 50))
  }
}
try {
  await wait(() => clients.every(c => c.provider.synced))
  assert.equal(clients[0].doc.getText('monaco').toString(), 'shared package edit\n')
  clients[0].doc.getText('monaco').insert(0, 'both editors ')
  await wait(() => clients[1].doc.getText('monaco').toString() === clients[0].doc.getText('monaco').toString())
} finally {
  for (const { doc, provider } of clients) { provider.destroy(); doc.destroy() }
}

// Both authenticated ttyd WebSockets attach the same tmux session.
const terminals = terminal.cookies.map(cookie => {
  const socket = new WebSocket('wss://rawpair.localhost' + terminal.path + 'ws', 'tty', {
    ...tlsOptions, headers: { cookie, origin: 'https://rawpair.localhost' },
  })
  const client = { socket, output: '', ready: false, error: null }
  socket.on('open', () => {
    socket.send(JSON.stringify({ AuthToken: '', columns: 80, rows: 24 }))
    client.ready = true
  })
  socket.on('message', data => { client.output += data.toString() })
  socket.on('error', error => { client.error = error })
  return client
})
try {
  await wait(() => terminals.every(client => client.ready || client.error))
  assert.ok(terminals.every(client => !client.error))
  await new Promise(resolve => setTimeout(resolve, 300))
  terminals[0].socket.send(Buffer.from([0x30, 0x02, 0x63])) // ttyd input + tmux Ctrl-b c
  await new Promise(resolve => setTimeout(resolve, 300))
  terminals[0].socket.send(Buffer.from("0printf '%s%s\\n' package- shared-terminal-verified\r"))
  await wait(() => terminals.every(client => client.output.includes('package-shared-terminal-verified')))
} finally {
  for (const { socket } of terminals) socket.close()
}
