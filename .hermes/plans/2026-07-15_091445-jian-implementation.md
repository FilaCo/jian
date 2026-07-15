# Jian CLI Framework — Implementation Plan

> **Goal:** Build a Typer-inspired CLI framework for the Cangjie programming language with zero type erasure, driven by compile-time macros.

**Architecture:** Users declare CLI commands as plain Cangjie functions with `Optional(...)`/`Positional(...)` type annotations (like Typer). The `@Command`/`@Callback` macros read the AST at compile time, generate a typed args struct with a static `parse()` method, and register the command on a builder. No type erasure, no runtime casts — the compiler verifies all generated code.

**Tech Stack:** Cangjie 1.0.5, `std.ast` (macros), `std.collection`, `std.convert.Parsable`, `cjpm`

---

## Phase 1: Core Parsing

> Foundation — typed argument specs and the parser that converts raw string args into structured, typed values.

### Task 1.1: Complete ArgSpec hierarchy

**Files:**
- Modify: `src/parsing/parse_args.cj`

**What:** `OptSpec` and `PosSpec` need full metadata so the parser knows how to interpret each argument.

```
// Current (stub):
protected class OptSpec <: ArgSpec {}
protected class PosSpec <: ArgSpec {}

// Target:
sealed abstract class ArgSpec {
    public let name: String
    public let help: ?String
}

protected class OptSpec <: ArgSpec {
    public let short: ?Byte       // e.g. b'o'
    public let long: ?String      // e.g. "output"
    public let defaultValue: String  // pre-serialized default
    public let hasDefault: Bool
}

protected class PosSpec <: ArgSpec {
    public let defaultValue: String
    public let hasDefault: Bool
}
```

**Verification:** `cjpm build` passes.

---

### Task 1.2: Implement `parseArgs()`

**Files:**
- Modify: `src/parsing/parse_args.cj`

**What:** The core parser. Takes `Lexer` + `Array<ArgSpec>` → produces `ParsedArgs` with populated key-value store.

Algorithm:
1. Build lookup maps: `HashMap<String, OptSpec>` (by long name + by short char) and `ArrayList<PosSpec>` (ordered)
2. Iterate tokens from lexer:
   - `Dashed(flag)` or `DoubleDashed(flag)` → lookup `OptSpec`, consume next token as value (or set to `"true"` for bool)
   - `Value(v)` → assign to next positional from `ArrayList<PosSpec>`
   - `Eoi` → stop
   - `StdinPlaceholder` → assign to next positional
3. After iteration: apply defaults from specs for unset values
4. Return `ParsedArgs(store)`

**Verification:** Write tests in `src/parsing/parse_args_test.cj` covering:
- Positional only
- Options only (short and long)
- Mixed positionals + options
- `--` terminator
- Defaults applied
- Missing required args → error

---

### Task 1.3: Typed `ParsedArgs` access

**Files:**
- Modify: `src/parsing/parse_args.cj`

**What:** Make `ParsedArgs` return typed values via `Parsable<T>` constraint.

```
public struct ParsedArgs {
    private let store: HashMap<String, String>

    // Internal constructor
    init(store: HashMap<String, String>) { ... }

    // Must succeed — throws on missing key or parse failure
    public func get<T>(name: String): T where T <: Parsable<T> {
        let raw = store.get(name).getOrThrow(...)
        T.parse(raw)
    }

    // Returns default if missing, throws on parse failure
    public func getOr<T>(name: String, default: T): T where T <: Parsable<T> {
        store.get(name).map { raw => T.parse(raw) } ?? default
    }
}
```

**Verification:** Tests for `get` and `getOr` with `String`, `Int64`, `Bool`, `Float64`.

---

## Phase 2: Builder API

> The `commandLine()` entry point, `App` with subcommands, and typed `Command` registration — all working together with the parser.

### Task 2.1: `OptSpec`/`PosSpec` from `Param` builders

**Files:**
- Modify: `src/builders/param.cj`

**What:** `Opt.toArgSpec()` and `Pos.toArgSpec()` currently throw. Implement them to produce proper `OptSpec`/`PosSpec`.

```
// In Opt:
protected func toArgSpec(): OptSpec {
    OptSpec(name: name, help: help, short: short, long: long, ...)
}

// In Pos:
protected func toArgSpec(): PosSpec {
    PosSpec(name: name, help: help, ...)
}
```

**Verification:** Existing `ParamTest` tests pass.

---

### Task 2.2: `commandLine()` factory function

**Files:**
- Create: `src/builders/command_line.cj`
- Modify: `src/jian.cj` (add `public import`)

**What:** The public entry point.

```
package jian.builders

public func commandLine(): AppBuilder {
    AppBuilder()
}
```

Replaces direct `App.builder()` calls with a friendlier name, matching the cjdev example.

**Verification:** `cjpm build` passes.

---

### Task 2.3: Complete `AppBuilder.build()` and `App.run()`

**Files:**
- Modify: `src/builders/app.cj`

**What:**
- `AppBuilder.build()` — actually constructs `App` with commands map, subApps map, etc.
- `App.run(argv)` — dispatch: lookup command/subApp by first arg, call `parseArgs` + `invoke`
- Command invoke flow: `command.invoke(parseArgs(argv[1..], command.params.map(...)))`

**Verification:** Integration test that builds an App with a Command and calls `run(["cmd", "--flag", "val"])`.

---

### Task 2.4: `Invokable` stores typed `invoke`

**Files:**
- Modify: `src/builders/invokable.cj`

**What:** Current `invoke: (ParsedArgs) -> Unit` is correct — the macro-generated closure will handle typed extraction internally. No changes needed to the signature.

**Verification:** Builds.

---

## Phase 3: Macros (The Magic)

> This is where Jian becomes Typer. Macros read function declarations and generate typed args structs + command registration code.

### Task 3.1: Deep-dive into Cangjie AST nodes

**Files:**
- Reference: `std.ast` documentation

**What:** Before coding macros, understand the AST representation of:
- `FuncDecl` — function declaration with params, return type, body
- `FuncParam` — parameter with name, type, default value expression
- How to detect `Optional(...)` and `Positional(...)` in default expressions
- How to extract `!` suffix (named parameter marker)

Key insight: `funcParam.name` gives the parameter name. `funcParam.type` gives the type. `funcParam.default` gives the default expression — if it's a `CallExpr` to `Positional` or `Optional`, extract its arguments.

**Verification:** Write a throwaway macro that prints AST of a test function to confirm understanding.

---

### Task 3.2: Implement `@Command` macro

**Files:**
- Modify: `src/macros/command.cj`

**What:** The macro receives:
- `attrs`: `[SYNC_CLI, help: "Sync repos"]` — the builder + metadata in attributes
- `input`: The function declaration tokens

It generates:

```cangjie
// === Generated by @Command ===

// 1. Typed args struct
struct _<funcName>_args {
    // one field per parameter, exact type from AST
    public let <paramName>: <paramType>

    static func parse(raw: ParsedArgs): _<funcName>_args {
        _<funcName>_args(
            // positional → raw.get<T>("name").getOrThrow()
            // optional   → raw.getOr<T>("name", default)
        )
    }
}

// 2. Command registration on the builder
attrs[0].add(Command.builder("<funcName>")
    .help(attrs["help"])
    .params([...])  // one Param per function param
    .invoke({ raw: ParsedArgs =>
        let args = _<funcName>_args.parse(raw)
        <funcName>(args.<param1>, args.<param2>, ...)
    })
    .build())

// 3. Keep original function (it's called from invoke)
```

**Verification:** E2E test — define a function with `@Command`, build and run, verify CLI parses args and invokes correctly.

---

### Task 3.3: Implement `@Callback` macro

**Files:**
- Modify: `src/macros/callback.cj`

**What:** Same as `@Command` but:
- Registers as the callback on the App builder (not a named subcommand)
- Usually has no positional params (just options like `--help`, `--version`)

**Verification:** E2E test with `@Callback`.

---

### Task 3.4: Multi-parameter test coverage

**Files:**
- Create: `src/macros/command_test.cj`
- Create: `src/macros/callback_test.cj`

**What:** Test macros with:
- No params
- One positional
- Multiple positionals
- Optional with `--long` flag
- Optional with `-s` short flag
- Optional with default value
- Mixed positionals + optionals
- Bool optionals (flag-like: presence = true)

**Verification:** `cjpm test` all green.

---

## Phase 4: Help & Polish

> Auto-generated help, validation, error messages, docs.

### Task 4.1: Auto-generated help text

**Files:**
- Create: `src/builders/help.cj`

**What:** `App.formatHelp(): String` and `Command.formatHelp(): String`. Format:

```
Usage: cjdev [COMMAND] [OPTIONS]

Cangjie SDK developer utils.

Commands:
  init     Initialize a new SDK module
  status   Show SDK status
  sync     Sync all projects to the upstream default branch

Options:
  --help, -h    Show this help message
```

**Verification:** Test that `app.formatHelp()` contains expected strings.

---

### Task 4.2: Validation and error messages

**Files:**
- Modify: `src/parsing/parse_args.cj`

**What:**
- Missing required positional → clear error with usage hint
- Unknown flag → `error: unrecognized option '--foo'`
- Type parse failure → `error: invalid value 'abc' for '--count': expected Int64`

**Verification:** Tests for each error case, asserting message format.

---

### Task 4.3: Documentation & examples

**Files:**
- Create: `README.md` (or update)
- Create: `examples/basic/main.cj`

**What:** Usage guide showing the full flow:
1. Create a command function
2. Annotate with `@Command`
3. Wire everything with `commandLine()`
4. Run

**Verification:** `README.md` is clear and the example compiles.

---

## Architecture Summary

```
User writes:
┌─────────────────────────────────────────────┐
│  let CLI = commandLine()                    │
│                                             │
│  @Command[CLI, help: "Greet someone."]      │
│  func greet(name: String) { ... }           │
│                                             │
│  @Callback[CLI]                             │
│  func main() { CLI.buildAndRun(env.args) }  │
└─────────────────────────────────────────────┘

@Command macro generates (compile-time):
┌─────────────────────────────────────────────┐
│  struct _greet_args {                       │
│    public let name: String                  │
│    static func parse(raw: ParsedArgs) { ... }│
│  }                                          │
│                                             │
│  CLI.add(Command.builder("greet")           │
│    .param(PosSpec("name"))                  │
│    .invoke({ raw => greet(_greet_args.parse(raw).name) })│
│    .build())                                │
└─────────────────────────────────────────────┘

Runtime flow:
  args = ["greet", "World"]
  → Lexer → Tokens
  → parseArgs(tokens, specs) → ParsedArgs
  → _greet_args.parse(parsedArgs) → typed struct
  → greet(struct.name)
```

## Key Design Decisions

1. **No type erasure:** Macro generates per-command struct with exact field types. Compiler verifies all type usage.
2. **`Parsable<T>` constraint:** All typed access goes through `std.convert.Parsable`, which Cangjie's stdlib already provides for `String`, `Int64`, `Bool`, `Float64`, etc.
3. **`!` suffix = named param:** Cangjie's `name!: Type` syntax maps naturally to CLI options.
4. **`Positional(...)` and `Optional(...)` as compile-time markers:** These throw `UnsupportedException` if called at runtime — they exist exclusively for the macro to read from the AST.
5. **Builder pattern for composition:** `commandLine().add(cmd).add(subCli)` — composable, testable.
