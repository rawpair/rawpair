import * as React from 'react'
import ReactDOM from 'react-dom/client'
import Editor from './editor/Editor'

self.MonacoEnvironment = {
  getWorker() { return new Worker('/assets/editor.worker.js', { type: 'module' }) }
}

export default {
  mounted() {
    this.root = ReactDOM.createRoot(this.el)
    this.root.render(<Editor slug={this.el.dataset.slug} />)
  },
  destroyed() { this.root?.unmount() }
}
