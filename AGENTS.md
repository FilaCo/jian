# jian - Cangjie CLI Library

A command-line argument parsing library for the Cangjie programming language.

## Build & Test

```bash
cjpm build          # Compile the library
cjpm build -l       # Build with linting
cjpm test           # Run unit tests
cjpm test src/foo   # Test specific package
```

## Project Structure

- `src/jian.cj` - Package entry, re-exports `jian.api.*`
- `src/api/` - Public API surface
- `src/core/` - Internal implementation (`protected package jian.core`)
- `src/command.cj` - `@Command` macro definition
- `src/callback.cj` - `@Callback` macro definition

## Dependencies

- `result_cj` - Git dependency from https://github.com/FilaCo/result_cj.git

## Conventions

- Conventional commits enforced via commitlint (husky pre-commit hook)
- Run `npm install` to set up git hooks after cloning