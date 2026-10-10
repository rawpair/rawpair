import * as React from 'react'
import { useCallback, useEffect, useRef, useState } from 'react'
import { useCollaborativeEditor } from './hooks/useCollaborativeEditor'
import { getCSRFToken } from '../lib/utils'

export default function Editor({ slug }: { slug: string }) {
  const [activeFile, setActiveFile] = useState<string>()
  const [files, setFiles] = useState<string[]>([])
  const [message, setMessage] = useState('')
  const containerRef = useRef<HTMLDivElement>(null)
  const { editorRef, ready, status } = useCollaborativeEditor(containerRef, slug, activeFile)
  const refresh = useCallback(async () => {
    try {
      const response = await fetch(`/api/workspaces/${encodeURIComponent(slug)}/files`)
      if (!response.ok) throw new Error('Unable to list project files')
      setFiles((await response.json()).files)
    } catch (error) { setMessage((error as Error).message) }
  }, [slug])
  useEffect(() => {
    refresh()
    const timer = setInterval(refresh, 10000)
    return () => clearInterval(timer)
  }, [refresh])
  const save = async () => {
    if (!activeFile || !ready || !editorRef.current) return
    const file = activeFile
    try {
      const response = await fetch(`/api/workspaces/${encodeURIComponent(slug)}/files/${file.split('/').map(encodeURIComponent).join('/')}`, {
        method: 'PUT', headers: { 'Content-Type': 'application/json', 'x-csrf-token': getCSRFToken() },
        body: JSON.stringify({ content: editorRef.current.getValue() }),
      })
      const data = await response.json()
      if (!response.ok) throw new Error(data.error ?? 'Save failed')
      setMessage(`Saved ${file}`)
    } catch (error) { setMessage((error as Error).message) }
  }
  const reloadFromDisk = async () => {
    if (!activeFile || !ready || !window.confirm('Replace this file’s shared editor contents with the disk version? This discards unsaved shared edits for every participant.')) return
    try {
      const response = await fetch(`/api/workspaces/${encodeURIComponent(slug)}/collaboration/reload`, {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'x-csrf-token': getCSRFToken() },
        body: JSON.stringify({ path: activeFile }),
      })
      const data = await response.json()
      if (!response.ok) throw new Error(data.error ?? 'Reload failed')
      setMessage(`Reloaded ${activeFile} from disk for all participants`)
    } catch (error) { setMessage((error as Error).message) }
  }
  return <div className="flex flex-col w-full h-full min-h-[400px]">
    <div className="flex gap-4 p-2 items-center">
      <select aria-label="Project file" value={activeFile ?? ''} onChange={event => setActiveFile(event.target.value || undefined)} className="border p-2 max-w-[50%]">
        <option value="">Select a file</option>
        {files.map(file => <option key={file} value={file}>{file}</option>)}
      </select>
      <button onClick={refresh}>Refresh files</button>
      <button disabled={!ready} onClick={save}>Save</button>
      <button disabled={!ready} onClick={reloadFromDisk}>Reload from disk</button>
    </div>
    <p className="px-2 text-sm" role="status">{status} {message && `· ${message}`}</p>
    <div ref={containerRef} className="w-full flex-1 min-h-[350px]" />
  </div>
}
