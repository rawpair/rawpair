import * as Y from 'yjs'
import { WebsocketProvider } from 'y-websocket'
import * as monaco from 'monaco-editor'

let editor = null

const EditorHook = {
  mounted() {
    const roomSlug = this.el.dataset.slug
    const ydoc = new Y.Doc()

    // Connect to y-websocket server (assumes it's running on port 1234)
    const provider = new WebsocketProvider('ws://localhost:1234', roomSlug, ydoc)
    const yText = ydoc.getText('monaco')

    // Monaco editor setup
    editor = monaco.editor.create(this.el, {
      value: '',
      language: 'javascript', // or any other supported language
      theme: 'vs-dark',
      automaticLayout: true
    })

    // Bind Monaco <-> Yjs
    const monacoBinding = new window.Y.MonacoBinding(
      yText,
      editor.getModel(),
      new Set([editor]),
      provider.awareness
    )

    // Save editor instance in hook
    this.editor = editor
  },

  destroyed() {
    this.editor?.dispose()
  }
}

export default EditorHook
