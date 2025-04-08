import { useEffect, useRef } from 'react'
import * as monaco from 'monaco-editor/esm/vs/editor/editor.api'
import * as Y from 'yjs'
import { WebsocketProvider } from 'y-websocket'
import { MonacoBinding } from 'y-monaco'

self.MonacoEnvironment = {
  getWorker: function (_, label) {
    // @ts-ignore
    const url = (path: string) => new URL(`monaco-editor/esm/${path}`, import.meta.url)
    switch (label) {
      case 'json': return new Worker(url('vs/language/json/json.worker'), { type: 'module' })
      case 'css': return new Worker(url('vs/language/css/css.worker'), { type: 'module' })
      case 'html': return new Worker(url('vs/language/html/html.worker'), { type: 'module' })
      case 'typescript':
      case 'javascript': return new Worker(url('vs/language/typescript/ts.worker'), { type: 'module' })
      default: return new Worker(url('vs/editor/editor.worker'), { type: 'module' })
    }
  }
}

export function useCollaborativeEditor(containerRef: any, slug: string) {
  const editorRef = useRef<monaco.editor.IStandaloneCodeEditor | null>(null)

  useEffect(() => {
    if (!containerRef?.current || editorRef.current) return

    const ydoc = new Y.Doc()
    const protocol = location.protocol === 'https:' ? 'wss' : 'ws'
    const provider = new WebsocketProvider(`${protocol}://${location.hostname}:1234`, slug, ydoc)
    const yText = ydoc.getText('monaco')

    const editor = monaco.editor.create(containerRef.current, {
      value: '',
      theme: 'vs-dark',
      automaticLayout: true,
    })

    const model = editor.getModel()
    if (model) {
      new MonacoBinding(yText, model, new Set([editor]), provider.awareness)
    }

    editorRef.current = editor

    return () => {
      editor.dispose()
      editorRef.current = null
    }
  }, [containerRef, slug])

  return editorRef
}

