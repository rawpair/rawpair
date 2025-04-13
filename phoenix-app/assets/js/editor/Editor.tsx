// SPDX-License-Identifier: MPL-2.0

import * as React from 'react'
import { clsx } from 'clsx';
import { useCallback, useRef, useState, useEffect, useMemo } from "react"
import * as monaco from 'monaco-editor/esm/vs/editor/editor.api'
import { NodeApi, NodeRendererProps, Tree } from 'react-arborist';
import { useCollaborativeEditor } from './hooks/useCollaborativeEditor'
import { Card } from "@/components/ui/card"
import { Button } from '@/components/ui/button'
import { cn, getCSRFToken } from '@/lib/utils'
import { FileTreeItem } from './types';
import { flatFileListToTreeItems } from './lib/tree-parse';
import LanguageSelector from './components/LanguageSelector';
import { detectLanguageFromFilename } from './lib/file-extension-to-language';

type Props = {
  slug: string;
  language: string;
}

function Node({ node, style, dragHandle }: NodeRendererProps<FileTreeItem>) {
  const handleClick = useCallback(() => {
    if (node.isInternal) {
      node.toggle()
    }
  }, [node]);

  return (
    <div 
      style={style} 
      className={clsx(node.state.isSelected && 'bg-white text-black')} 
      ref={dragHandle} 
      onClick={handleClick}
    >
      {node.isLeaf ? "📄" : "🗀"}
      {node.data.name}
    </div>
  );
}

export default function Editor({slug}: Props) {
  const [activeFile, setActiveFile] = useState<string>()
  const [files, setFiles] = useState<FileTreeItem[]>([]);
  const [language, setLanguage] = useState<string>('plaintext')

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

  const loadFiles = useCallback(() => {
    fetchFiles(slug).then((data) => {
      if (data) {
        setFiles(flatFileListToTreeItems(data.files.filter(filePath => filePath.trim())))
      }
    })
  }, [fetchFiles]);

  useEffect(() => {
    const interval = setInterval(() => {
      loadFiles()
    }, 5000);

    return () => clearInterval(interval)
  }, [loadFiles, slug]);

  useEffect(() => {
    loadFiles()
  }, [loadFiles, slug]);

  useEffect(() => {
    if (!activeFile) return

    fetchFileContents(slug, activeFile).then((data) => {
      if (data) {
        if (editor.current) {
          const model = editor.current.getModel()

          if (model) {
            model.setValue(data.contents)
          }
        }
      }
    })
  }, [fetchFileContents, activeFile]);

  const onChangeLanguage = useCallback((language: string) => {
    if (editor.current) {
      const model = editor.current.getModel()

      if (model) {
        monaco.editor.setModelLanguage(model, language);
      }
    }
  }, []);

  const handleSave = useCallback(() => {
    if (!activeFile || !editor.current) return

    saveFileContents(slug, activeFile || '', editor.current?.getValue() || '')
  }, [saveFileContents, slug, activeFile]);

  const handleSelectFileTreeItem = useCallback((selection: NodeApi<FileTreeItem>[]) => {
    if (selection.length === 1 && selection[0].children === null) {
      setActiveFile(selection[0].id);

      const matchedLanguage = detectLanguageFromFilename(selection[0].id);

      if (matchedLanguage) {
        setLanguage(matchedLanguage);
        onChangeLanguage(matchedLanguage);
      }
    }
  }, [onChangeLanguage]);

  return (
    <div className="h-full w-full flex flex-col bg-background text-foreground">
      <div className="flex">
        <div className="basis-4 p-2">
          <Tree 
            data={files} 
            className="" 
            openByDefault={false} 
            disableDrop 
            disableDrag 
            disableEdit
            disableMultiSelection
            onSelect={handleSelectFileTreeItem}
            selection={activeFile}
          >{Node}</Tree>
        </div>
        <div className="flex flex-col flex-1">
          <div className={"flex gap-4 w-full py-2 px-1"}>
            <LanguageSelector className="w-[180px]" value={language} onChange={onChangeLanguage} />

            <Button onClick={handleSave}>Save</Button>
          </div>
          <Card className="flex-1 rounded-none">
            <div ref={containerRef} className="w-full h-full" />
          </Card>
        </div>
      </div>
    </div>
  )
}
