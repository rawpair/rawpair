// SPDX-License-Identifier: MPL-2.0

import * as React from 'react'
import { useCallback, useMemo } from "react"
import * as monaco from 'monaco-editor/esm/vs/editor/editor.api'
import 'monaco-editor/esm/vs/basic-languages/monaco.contribution';
import { cn } from '@/lib/utils';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';

type Props = {
  className?: string;
  value?: string;
  placeholder?: string;
  onChange: (value: string) => void;
}

export default function LanguageSelector({className, value, onChange}: Props) {
    const languages = useMemo(() => 
    monaco.languages.getLanguages().map(({id}) => id).sort((a, b) => a.localeCompare(b))
  , [])

  const languageOptions = useMemo(() => 
    languages.map(languageId => ({value: languageId, label: languageId}))
  , [languages])

  const handleOnChange = useCallback((value: string) => {
    onChange(value)
  }, [onChange])

  return (
    <Select onValueChange={handleOnChange} value={value}>
      <SelectTrigger className={cn(className)}>
        <SelectValue placeholder='Choose a language' />
      </SelectTrigger>
      <SelectContent>
        {languageOptions.map(({value, label}) => 
            (<SelectItem key={value} value={value}>{label}</SelectItem>)
        )}
      </SelectContent>
    </Select>
  )
}
