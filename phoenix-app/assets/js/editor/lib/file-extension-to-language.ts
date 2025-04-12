// SPDX-License-Identifier: MPL-2.0

export const fileExtensionToLanguageMapping = Object.freeze({
    ".abap": "abap",
    ".bat": "bat",
    ".cmd": "bat",
    ".bib": "bibtex",
    ".clj": "clojure",
    ".cljs": "clojure",
    ".cljc": "clojure",
    ".edn": "clojure",
    ".coffee": "coffeescript",
    ".c": "c",
    ".cpp": "cpp",
    ".cc": "cpp",
    ".cxx": "cpp",
    ".hpp": "cpp",
    ".hh": "cpp",
    ".hxx": "cpp",
    ".cs": "csharp",
    ".css": "css",
    "Dockerfile": "dockerfile",
    ".fs": "fsharp",
    ".fsi": "fsharp",
    ".fsx": "fsharp",
    ".go": "go",
    ".graphql": "graphql",
    ".gql": "graphql",
    ".h": "c",
    ".html": "html",
    ".htm": "html",
    ".xhtml": "html",
    ".ini": "ini",
    ".cfg": "ini",
    ".java": "java",
    ".js": "javascript",
    ".es6": "javascript",
    ".mjs": "javascript",
    ".json": "json",
    ".jl": "julia",
    ".kt": "kotlin",
    ".kts": "kotlin",
    ".lua": "lua",
    ".md": "markdown",
    ".m": "objective-c",
    ".mm": "objective-c",
    ".pl": "perl",
    ".pm": "perl",
    ".php": "php",
    ".php4": "php",
    ".php5": "php",
    ".txt": "plaintext",
    ".ps1": "powershell",
    ".psm1": "powershell",
    ".py": "python",
    ".pyw": "python",
    ".r": "r",
    ".rb": "ruby",
    ".rs": "rust",
    ".scala": "scala",
    ".sh": "shell",
    ".bash": "shell",
    ".sql": "sql",
    ".swift": "swift",
    ".ts": "typescript",
    ".tsx": "typescript",
    ".xml": "xml",
    ".yaml": "yaml",
    ".yml": "yaml"
} as Record<string, string>);

const specialFiles: Record<string, string> = {
    '.gitignore': 'plaintext',
    '.dockerignore': 'dockerfile',
    '.npmrc': 'ini',
    '.bashrc': 'shell',
    'Makefile': 'makefile',
    'Dockerfile': 'dockerfile',
    'CMakeLists.txt': 'cmake',
    'build.gradle': 'groovy',
};

export const detectLanguageFromFilename = (filename: string): string => {
    const base = filename.split('/').pop() || '';
    if (specialFiles[base]) return specialFiles[base];
  
    const ext = base.match(/(\.[^.]+)$/)?.[1];

    if (!ext) {
        return 'plaintext'
    }

    return fileExtensionToLanguageMapping[ext] ?? 'plaintext';
}
  