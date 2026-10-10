import { useEffect, useRef, useState } from 'react'
import * as monaco from 'monaco-editor/esm/vs/editor/editor.api'
import * as Y from 'yjs'
import { WebsocketProvider } from 'y-websocket'
import { MonacoBinding } from 'y-monaco'
import { detectLanguageFromFilename } from '../lib/file-extension-to-language'

type Document = { doc: Y.Doc; provider: WebsocketProvider; model: monaco.editor.ITextModel }

export function useCollaborativeEditor(containerRef: React.RefObject<HTMLDivElement | null>, slug: string, file?: string) {
  const editorRef = useRef<monaco.editor.IStandaloneCodeEditor | null>(null)
  const documents = useRef(new Map<string, Document>())
  const [status, setStatus] = useState('Select a file')
  const [ready, setReady] = useState(false)

  useEffect(() => {
    if (!containerRef.current) return
    editorRef.current = monaco.editor.create(containerRef.current, {
      model: null, theme: 'vs-dark', automaticLayout: true, readOnly: true,
    })
    return () => {
      editorRef.current?.dispose()
      editorRef.current = null
      for (const item of documents.current.values()) {
        item.provider.destroy(); item.model.dispose(); item.doc.destroy()
      }
      documents.current.clear()
    }
  }, [containerRef, slug])

  useEffect(() => {
    let cancelled = false
    let binding: MonacoBinding | undefined
    let current: Document | undefined
    const editor = editorRef.current
    setReady(false)
    editor?.updateOptions({ readOnly: true })
    editor?.setModel(null)
    if (!file || !editor) { setStatus('Select a file'); return }
    setStatus('Connecting…')
    const ticket = async () => {
      const response = await fetch(`/api/workspaces/${encodeURIComponent(slug)}/collaboration?path=${encodeURIComponent(file)}`)
      if (!response.ok) throw new Error('File unavailable or workspace access denied')
      return response.json() as Promise<{ document: string; ticket: string }>
    }
    const onSync = (synced: boolean) => {
      if (cancelled || !current) return
      const connected = current.provider.wsconnected && synced
      setReady(connected)
      editor.updateOptions({ readOnly: !connected })
      setStatus(connected ? 'Connected · shared changes preserved · Save writes to disk' : 'Reconnecting…')
    }
    const onStatus = ({ status }: { status: string }) => {
      if (cancelled || !current) return
      if (status !== 'connected') {
        onSync(false)
        // A fresh, file-scoped ticket is required on reconnect; old Y.Doc state
        // stays in memory and merges with the server after reconnection.
        ticket().then(data => { if (current) current.provider.params = { ticket: data.ticket } })
          .catch(error => { current?.provider.disconnect(); if (!cancelled) setStatus(error.message) })
      }
    }
    const open = async () => {
      current = documents.current.get(file)
      if (!current) {
        const credentials = await ticket()
        if (cancelled) return
        const doc = new Y.Doc()
        const protocol = location.protocol === 'https:' ? 'wss' : 'ws'
        const provider = new WebsocketProvider(`${protocol}://${location.host}/collaboration`, credentials.document, doc,
          { params: { ticket: credentials.ticket }, connect: false, disableBc: true })
        const model = monaco.editor.createModel('', detectLanguageFromFilename(file) ?? 'plaintext')
        current = { doc, provider, model }
        documents.current.set(file, current)
      } else {
        const credentials = await ticket()
        if (cancelled) return
        current.provider.params = { ticket: credentials.ticket }
      }
      editor.setModel(current.model)
      binding = new MonacoBinding(current.doc.getText('monaco'), current.model, new Set([editor]), current.provider.awareness)
      current.provider.on('sync', onSync)
      current.provider.on('status', onStatus)
      current.provider.connect()
      onSync(current.provider.synced)
    }
    open().catch(error => { if (!cancelled) setStatus(error.message) })
    return () => {
      cancelled = true
      binding?.destroy()
      if (current) {
        current.provider.off('sync', onSync)
        current.provider.off('status', onStatus)
        // Keep this file's model, Y.Doc and provider while another file is open.
        // Local pending updates are never replaced with fetched file text.
      }
    }
  }, [slug, file])

  return { editorRef, status, ready }
}
