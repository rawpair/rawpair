import * as React from 'react'
import ReactDOM from 'react-dom/client'
import Editor from './editor/Editor'

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

    const slug = this.el.dataset.slug;

    this.root = ReactDOM.createRoot(this.el)
    this.root.render(<Editor slug={slug} />)
  },
  destroyed() {
    this.root?.unmount()
  }
}

export default EditorHook