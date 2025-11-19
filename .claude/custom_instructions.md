# Environment-Specific Tools

This system has modern CLI tools installed. Use these when executing commands:

## Available Tools

- **ripgrep (rg)**: Use instead of grep - faster, respects .gitignore
  - Example: `rg "pattern" --type js`

- **ast-grep**: Structural search and replace for code
  - Example: `ast-grep --pattern 'console.log($$$)'`

- **fd**: Use instead of find - faster, simpler syntax
  - Example: `fd pattern` or `fd '\.js$'`

- **bat**: Use instead of cat for viewing files - includes syntax highlighting
  - Example: `bat file.txt`

- **jq**: JSON processor for parsing and filtering JSON
  - Example: `curl api.com/data | jq '.items[]'`

- **sd**: Modern sed replacement for find-and-replace
  - Example: `sd 'old' 'new' file.txt`
  - Simpler syntax than sed, useful for refactoring

- **tokei**: Code statistics and line counting
  - Example: `tokei` to see lines of code by language

- **gh**: GitHub CLI for repo management
  - Example: `gh pr list`, `gh issue create`

- **procs**: Modern ps replacement for process listing
  - Example: `procs` or `procs name`

- **dust**: Modern du replacement for disk usage
  - Example: `dust` to see disk usage as tree

- **tldr**: Simplified man pages with examples
  - Example: `tldr tar` for practical examples instead of full man page

- **task**: Task runner available (Taskfile-based)
  - Use `task --list` to see available tasks

- **git**: Pre-configured with useful aliases
  - `git st` (status), `git co` (checkout), `git br` (branch), `git lg` (graph log)

- **go**: Go toolchain installed with GOPATH configured

## Guidelines

- Prefer rg over grep for text searching
- Prefer ast-grep for structural code searching (e.g., finding function calls, patterns)
- Prefer fd over find for file searching
- Prefer bat over cat when viewing file contents
- Prefer sd over sed for find-and-replace operations
- Prefer procs over ps for process listing
- Prefer dust over du for disk usage
- Use jq for JSON processing and filtering
- Use tokei for code statistics
- Use gh for GitHub operations
- Use tldr for quick command examples instead of man pages
- Use task for running project tasks when Taskfile exists
- Git shortcuts are available and preferred
