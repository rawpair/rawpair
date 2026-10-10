import http from 'node:http'
import fs from 'node:fs'
import path from 'node:path'
import { createHash, timingSafeEqual } from 'node:crypto'
import { fileURLToPath } from 'node:url'
import { WebSocketServer } from 'ws'
import * as Y from 'yjs'
import { docs, getYDoc, setPersistence, setupWSConnection } from '@y/websocket-server/utils'

export function createCollaborationServer({ authUrl, secret, directory, origin }) {
  if (!secret || secret.length < 32) throw new Error('Set RAWPAIR_COLLABORATION_TOKEN (32+ random bytes)')
  fs.mkdirSync(directory, { recursive: true, mode: 0o700 })
  const seeds = new Map()
  const discarded = new WeakSet()
  const filename = name => {
    const [workspace] = JSON.parse(Buffer.from(name, 'base64url').toString('utf8'))
    if (!Number.isSafeInteger(workspace) || workspace <= 0) throw new Error('Invalid document workspace')
    return path.join(directory, `${workspace}-${createHash('sha256').update(name).digest('hex')}.bin`)
  }
  const persist = (name, doc) => {
    if (discarded.has(doc)) return
    const state = Y.encodeStateAsUpdate(doc)
    if (state.length > 16 * 1024 * 1024) throw new Error('Collaborative document exceeds 16 MiB state limit')
    const target = filename(name)
    const fd = fs.openSync(target + '.new', 'w', 0o600)
    try { fs.writeFileSync(fd, state); fs.fsyncSync(fd) } finally { fs.closeSync(fd) }
    fs.renameSync(target + '.new', target)
  }
  setPersistence({
    provider: null,
    bindState(name, doc) {
      const target = filename(name)
      if (fs.existsSync(target)) Y.applyUpdate(doc, fs.readFileSync(target))
      else doc.getText('monaco').insert(0, seeds.get(name) ?? '')
      persist(name, doc)
      doc.on('update', () => {
        try { persist(name, doc) } catch (error) {
          console.error('Cannot persist collaborative document:', error.message)
          for (const connection of doc.conns.keys()) connection.close(1011, 'Document persistence failed')
        }
      })
    },
    async writeState(name, doc) { persist(name, doc) },
  })
  const authorize = async (ticket, document, connected = false) => {
    const response = await fetch(authUrl, {
      method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${secret}` },
      body: JSON.stringify({ ticket, document, connected }), signal: AbortSignal.timeout(10000),
    })
    if (!response.ok) throw new Error('Workspace authorization failed')
    const data = await response.json()
    if (!data.authorized) throw new Error('Workspace authorization failed')
    return data
  }
  const sameSecret = supplied => {
    if (typeof supplied !== 'string') return false
    const candidate = Buffer.from(supplied)
    const expected = Buffer.from(secret)
    return candidate.length === expected.length && timingSafeEqual(candidate, expected)
  }
  const server = http.createServer(async (request, response) => {
    const documentMatch = /^\/internal\/documents\/([A-Za-z0-9_-]{1,8192})$/.exec(request.url ?? '')
    if (request.method === 'PUT' && documentMatch && sameSecret(request.headers.authorization?.replace(/^Bearer /, ''))) {
      try {
        let body = ''
        for await (const chunk of request) {
          body += chunk
          if (body.length > 16 * 1024 * 1024) throw new Error('Request too large')
        }
        const { contents } = JSON.parse(body)
        if (typeof contents !== 'string' || Buffer.byteLength(contents) > 2 * 1024 * 1024) throw new Error('Invalid file content')
        const name = documentMatch[1]
        seeds.set(name, contents)
        let doc
        try { doc = getYDoc(name) } finally { seeds.delete(name) }
        doc.transact(() => { const text = doc.getText('monaco'); text.delete(0, text.length); text.insert(0, contents) })
        response.writeHead(204).end()
      } catch { response.writeHead(422).end('Unable to reload shared document') }
      return
    }
    const match = /^\/internal\/workspaces\/(\d+)\/documents$/.exec(request.url ?? '')
    if (request.method === 'DELETE' && match && sameSecret(request.headers.authorization?.replace(/^Bearer /, ''))) {
      const prefix = `${Number(match[1])}-`
      for (const [name, doc] of docs) {
        if (path.basename(filename(name)).startsWith(prefix)) {
          discarded.add(doc)
          for (const connection of doc.conns.keys()) connection.terminate()
        }
      }
      for (const file of fs.readdirSync(directory)) if (file.startsWith(prefix)) fs.unlinkSync(path.join(directory, file))
      response.writeHead(204).end()
    } else if (request.url === '/healthz') response.writeHead(200).end('ok')
    else response.writeHead(403).end('Forbidden')
  })
  const sockets = new WebSocketServer({ noServer: true, maxPayload: 3 * 1024 * 1024 })
  server.on('upgrade', async (request, socket, head) => {
    try {
      if (origin && request.headers.origin !== origin) throw new Error('Origin denied')
      const url = new URL(request.url, 'http://localhost')
      const match = /^\/collaboration\/([A-Za-z0-9_-]{1,8192})$/.exec(url.pathname)
      if (!match) throw new Error('Invalid document')
      const document = match[1]
      const ticket = url.searchParams.get('ticket')
      const data = await authorize(ticket, document)
      if (socket.destroyed) return
      seeds.set(document, data.contents)
      try { getYDoc(document) } finally { seeds.delete(document) }
      sockets.handleUpgrade(request, socket, head, connection => {
        setupWSConnection(connection, request, { docName: document })
        const recheck = setInterval(async () => {
          try { await authorize(ticket, document, true) }
          catch { connection.close(1008, 'Workspace access revoked') }
        }, 15000)
        connection.on('close', () => clearInterval(recheck))
      })
    } catch {
      if (!socket.destroyed) socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\nContent-Length: 0\r\n\r\n')
    }
  })
  return { server, sockets }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const service = createCollaborationServer({
    authUrl: process.env.RAWPAIR_AUTH_URL ?? 'http://127.0.0.1:4000/internal/collaboration/authorize',
    secret: process.env.RAWPAIR_COLLABORATION_TOKEN,
    directory: process.env.RAWPAIR_COLLABORATION_DIR ?? '/var/lib/rawpair-collaboration',
    origin: process.env.RAWPAIR_ORIGIN,
  })
  service.server.listen(Number(process.env.PORT ?? 1234), process.env.RAWPAIR_COLLABORATION_BIND ?? '127.0.0.1', () => console.log('RawPair collaboration listening'))
}
