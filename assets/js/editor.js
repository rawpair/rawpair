import * as monaco from 'monaco-editor/esm/vs/editor/editor.api'
import * as Y from 'yjs'
import { WebsocketProvider } from 'y-websocket'
import { MonacoBinding } from 'y-monaco'

self.MonacoEnvironment = {
  getWorker: function (moduleId, label) {
    if (label === 'json') {
      return new Worker(new URL('monaco-editor/esm/vs/language/json/json.worker', import.meta.url), { type: 'module' })
    }
    if (label === 'css') {
      return new Worker(new URL('monaco-editor/esm/vs/language/css/css.worker', import.meta.url), { type: 'module' })
    }
    if (label === 'html') {
      return new Worker(new URL('monaco-editor/esm/vs/language/html/html.worker', import.meta.url), { type: 'module' })
    }
    if (label === 'typescript' || label === 'javascript') {
      return new Worker(new URL('monaco-editor/esm/vs/language/typescript/ts.worker', import.meta.url), { type: 'module' })
    }
    return new Worker(new URL('monaco-editor/esm/vs/editor/editor.worker', import.meta.url), { type: 'module' })
  }
}

const EditorHook = {
  mounted() {
    if (this.initialized) return

    this.initialized = true

    const slug = this.el.dataset.slug || 'default-room'
    const ydoc = new Y.Doc()

    const provider = new WebsocketProvider('ws://localhost:1234', slug, ydoc)
    const yText = ydoc.getText('monaco')

    const editor = monaco.editor.create(this.el, {
      value: '',
      language: 'elixir',
      theme: 'vs-dark',
      automaticLayout: true
    })

    new MonacoBinding(yText, editor.getModel(), new Set([editor]), provider.awareness)
  }
}

export default EditorHook