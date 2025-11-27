# Environment-Specific Tools

This system has modern CLI tools installed. Use these when executing commands:

## Available Tools

- **ripgrep (rg)**: Use instead of grep - faster, respects .gitignore
  - Example: `rg "pattern" --type js`

- **ast-grep**: Structural search and replace for code
  - Example: `ast-grep --pattern 'console.log($$$)'`

- **fd**: Use instead of find - faster, simpler syntax
  - Example: `fd pattern` or `fd '\.js$'`

- **eza**: Modern ls replacement with built-in tree view
  - IMPORTANT: `ls` is aliased to `eza` on this system
  - Example: `eza -l` (detailed list), `eza --tree` (tree view)
  - Additional aliases: `ll` (eza -l), `la` (eza -la), `tree` (eza --tree)

- **bat**: Use instead of cat for viewing files - includes syntax highlighting
  - Example: `bat file.txt`
  - For multiple files in one output: `bat dir/*` or `bat dir/*.ext`
  - Prefer over: `for file in ...; do echo "=== $file ==="; cat "$file"; done`

- **jq**: JSON processor for parsing and filtering JSON
  - Example: `curl api.com/data | jq '.items[]'`

- **yq**: YAML processor for parsing and filtering YAML (like jq for YAML)
  - Example: `yq '.services.web.ports' docker-compose.yml`
  - Can read/write YAML, JSON, XML, and convert between formats

- **sd**: Modern sed replacement for find-and-replace
  - Example: `sd 'old' 'new' file.txt`
  - Simpler syntax than sed, useful for refactoring

- **glow**: Terminal markdown renderer for beautiful markdown viewing
  - Example: `glow README.md`
  - Can render markdown files with formatting and syntax highlighting

- **grex**: Generate regular expressions from test cases
  - Example: `grex 'foo123' 'bar456' 'baz789'` generates regex pattern
  - Useful for creating regex patterns from examples

- **tokei**: Code statistics and line counting
  - Example: `tokei` to see lines of code by language

- **gh**: GitHub CLI for repo management
  - Example: `gh pr list`, `gh issue create`

- **procs**: Modern ps replacement for process listing
  - Example: `procs` or `procs name`

- **dust**: Modern du replacement for disk usage
  - Example: `dust` to see disk usage as tree

- **usql**: Universal SQL client for databases
  - Example: `usql postgres://user:pass@localhost/dbname`
  - Supports PostgreSQL and SQLite

- **tldr**: Simplified man pages with examples
  - Example: `tldr tar` for practical examples instead of full man page

- **git**: Pre-configured with useful aliases
  - Basic: `git st` (status), `git co` (checkout), `git br` (branch), `git lg` (graph log)
  - Commit: `git cm` (commit -m), `git amend` (amend without edit)
  - Undo: `git uncommit` (soft reset HEAD~1), `git unstage` (reset HEAD)
  - Info: `git last` (last commit), `git branches` (all branches), `git remotes`, `git contributors`
  - Enhanced aliases: `gcob` (fuzzy branch checkout), `glf` (fuzzy log viewer)
  - Utilities: `ports` (show listening ports), `myip` (get public IP)

- **go**: Go toolchain installed with GOPATH configured
  - **mise**: Unified tool version manager (replaces goenv)
  - **air**: Live reload for Go development (`air` to watch and reload)

- **bun**: Fast JavaScript runtime and package manager
  - Modern alternative to npm/yarn/node
  - Example: `bun install`, `bun run dev`, `bun test`
  - Generally faster than npm for package management

- **mise**: Unified tool version manager
  - Replaces goenv, manages all development tools
  - Example: `mise install` to install all tools
  - Example: `mise upgrade --bump` to update tools
  - Example: `mise use go@1.23` to switch Go versions
  - Example: `mise run <task>` to run tasks (replaces task runner)
  - All tool versions defined in `.mise.toml`

## Environment & Development

- **helix (hx)**: Configured as default editor
  - Set as $EDITOR and git editor
  - Example: `hx file.txt` or just use git commands (will use helix automatically)

- **direnv**: Automatic environment management
  - Auto-loads `.envrc` files when entering directories
  - Can affect commands based on current directory context
  - Already hooked into shell - no manual activation needed

## Guidelines

- Prefer rg over grep for text searching
- Prefer ast-grep for structural code searching (e.g., finding function calls, patterns)
- Prefer fd over find for file searching
- Prefer eza over ls for directory listing (note: `ls` is already aliased to `eza`)
- Prefer bat over cat when viewing file contents
  - Use `bat path/*` to view multiple files in one output instead of loops with cat
- Prefer glow for rendering markdown files in terminal
- Prefer sd over sed for find-and-replace operations
- Prefer procs over ps for process listing
- Prefer dust over du for disk usage
- Use jq for JSON processing and filtering
- Use yq for YAML processing and filtering
- Use grex to generate regex patterns from examples
- Use bun instead of npm/yarn when working with JavaScript projects (faster)
- Use tokei for code statistics
- Use gh for GitHub operations
- Use usql for database queries across different database types
- Use tldr for quick command examples instead of man pages
- Use mise for tool version management (replaces goenv, task runner)
- Use `mise run <task>` for running project tasks (see .mise.toml tasks section)
- Use air for Go live reload development
- Git shortcuts are available and preferred
- Be aware that direnv is active - .envrc files affect environment automatically
- Prefer mise over manual tool installation - check `.mise.toml` for available tools
