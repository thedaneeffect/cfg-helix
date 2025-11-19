# Environment-Specific Tools

This system has modern CLI tools installed. Prefer these in your suggestions and commands:

## Available Tools

- **ripgrep (rg)**: Use instead of grep - faster, respects .gitignore
  - Example: `rg "pattern" --type js`

- **bat**: Use instead of cat for viewing files - includes syntax highlighting
  - Example: `bat file.txt`

- **eza**: Use instead of ls for file listing
  - `eza`, `eza -l`, `eza -la`

- **task**: Task runner available (Taskfile-based)
  - Use `task --list` to see available tasks

- **git**: Pre-configured with useful aliases
  - `git st` (status), `git co` (checkout), `git br` (branch), `git lg` (graph log)

- **go**: Go toolchain installed with GOPATH configured

## Guidelines

- Prefer rg over grep for searching
- Prefer bat over cat when viewing file contents
- Prefer eza over ls for directory listings
- Use task for running project tasks when Taskfile exists
- Git shortcuts are available and preferred
