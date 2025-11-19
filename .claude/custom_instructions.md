# Environment-Specific Tools

This system has modern CLI tools installed. Prefer these in your suggestions and commands:

## Available Tools

- **ripgrep (rg)**: Use instead of grep - faster, respects .gitignore
  - Example: `rg "pattern" --type js`

- **ast-grep**: Structural search and replace for code
  - Example: `ast-grep --pattern 'console.log($$$)'`

- **fd**: Use instead of find - faster, simpler syntax
  - Example: `fd pattern` or `fd '\.js$'`

- **bat**: Use instead of cat for viewing files - includes syntax highlighting
  - Example: `bat file.txt`

- **eza**: Use instead of ls for file listing
  - `eza`, `eza -l`, `eza -la`

- **jq**: JSON processor for parsing and filtering JSON
  - Example: `curl api.com/data | jq '.items[]'`

- **task**: Task runner available (Taskfile-based)
  - Use `task --list` to see available tasks

- **git**: Pre-configured with useful aliases and delta pager
  - `git st` (status), `git co` (checkout), `git br` (branch), `git lg` (graph log)
  - Diffs use delta for better syntax highlighting

- **go**: Go toolchain installed with GOPATH configured

## Guidelines

- Prefer rg over grep for text searching
- Prefer ast-grep for structural code searching (e.g., finding function calls, patterns)
- Prefer fd over find for file searching
- Prefer bat over cat when viewing file contents
- Prefer eza over ls for directory listings
- Use jq for JSON processing and filtering
- Use task for running project tasks when Taskfile exists
- Git shortcuts are available and preferred
