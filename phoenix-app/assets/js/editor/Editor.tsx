import * as React from 'react'
import { useCallback, useRef, useState, useEffect } from "react"
import { useCollaborativeEditor } from './hooks/useCollaborativeEditor'
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Card } from "@/components/ui/card"
import { Button } from '@/components/ui/button'
import { getCSRFToken } from '@/lib/utils'

type Props = {
  slug: string;
  language: string;
}

export default function Editor({slug}: Props) {
  const [activeFile, setActiveFile] = useState<string>()
  const [files, setFiles] = useState<string[]>([]);

  const containerRef = useRef(null)
  const editor = useCollaborativeEditor(containerRef, slug)

  const fetchFiles = useCallback(async (slug: string): Promise<{files: string[]}> => {
    const response = await fetch(`/api/workspaces/${slug}/files`);
    if (response.ok) {
      return response.json()
    }

    return {files:[]};
  }, []);

  const fetchFileContents = useCallback(async (slug: string, filePath: string): Promise<{contents: string}> => {
    const response = await fetch(`/api/workspaces/${slug}/files/${encodeURIComponent(filePath)}`);
    if (response.ok) {
      return response.json()
    }

    return {contents:''};
  }, []);

  const saveFileContents = useCallback(async (slug: string, filePath: string, content: string) => {
    fetch(`/api/workspaces/${slug}/files/${encodeURIComponent(filePath)}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'x-csrf-token': getCSRFToken()
      },
      body: JSON.stringify({ content })
    })
      .then(res => res.json())
      .then(data => console.log("Saved!", data))
      .catch(err => console.error("Save failed", err))
    
  }, []);

  useEffect(() => {
    const interval = setInterval(() => {
      fetchFiles(slug).then((data) => {
        if (data) {
          setFiles(data.files.sort())
        }
      })
    }, 5000);

    return () => clearInterval(interval)
  }, [slug]);

  useEffect(() => {
    fetchFiles(slug).then((data) => {
      if (data) {
        setFiles(data.files.sort())
      }
    })
  }, [fetchFiles, slug]);

  useEffect(() => {
    if (!activeFile && files.length > 0) {
      setActiveFile(files[0])
    }
  }, [setActiveFile, files, activeFile]);

  useEffect(() => {
    if (!activeFile) return

    fetchFileContents(slug, activeFile).then((data) => {
      if (data) {
        console.log(data);

        if (editor.current) {
          const model = editor.current.getModel()

          if (model) {
            model.setValue(data.contents)
          }
        }
      }
    }    )
  }, [fetchFileContents, activeFile]);

  const handleSave = useCallback(() => {
    if (!activeFile || !editor.current) return

    saveFileContents(slug, activeFile || '', editor.current?.getValue() || '')
  }, [saveFileContents, slug, activeFile]);

  return (
    <div className="h-full w-full flex flex-col bg-zinc-900 text-white">
      <div className="flex">
        <Button onClick={handleSave}>Save</Button>
        <Tabs value={activeFile} onValueChange={setActiveFile} className="flex-1">
          <TabsList className="flex space-x-1 p-2 bg-zinc-800 border-b border-zinc-700">
            {files.map((filename) => (
              <TabsTrigger
                key={filename}
                value={filename}
                className="text-sm px-3 py-1 rounded-t bg-zinc-700 text-white data-[state=active]:bg-zinc-900"
              >
                {filename}
              </TabsTrigger>
            ))}
          </TabsList>
        </Tabs>
      </div>

      <Card className="flex-1 bg-black rounded-none">
        <div ref={containerRef} className="w-full h-full bg-black" />
      </Card>
    </div>
  )
}
