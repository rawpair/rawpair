// SPDX-License-Identifier: MPL-2.0

import * as React from 'react'
import { clsx } from 'clsx';
import { useCallback, useMemo } from "react"
import * as monaco from 'monaco-editor/esm/vs/editor/editor.api'
import 'monaco-editor/esm/vs/basic-languages/monaco.contribution';

type Props = {
  className?: string;
  value?: string;
  onChange: (value: string) => void;
}

export default function LanguageSelector({className, value, onChange}: Props) {
    const languages = useMemo(() => 
    monaco.languages.getLanguages().map(({id}) => id).sort((a, b) => a.localeCompare(b))
  , [])

  const languageOptions = useMemo(() => 
    languages.map(languageId => ({value: languageId, label: languageId}))
  , [languages])

  const handleOnChange = useCallback((event: React.ChangeEvent<HTMLSelectElement>) => {
    onChange(event.target.value)
  }, [onChange])

  return (
    <select className={clsx(className)} value={value} onChange={handleOnChange}>
        {languageOptions.map(({value, label}) => 
            (<option key={value} value={value}>{label}</option>)
        )}
    </select>
  )
}
