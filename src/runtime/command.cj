package jian.runtime

/**
 * A subcommand of an `App`: what `@Command` generates for a function.
 *
 * Part of the macro's API: generated code implements it, users add instances with
 * `App.add`. Tests implement it by hand.
 */
public interface Command {
    /** The name the command is called by on the command line, e.g. `sync-all`. */
    prop name: String

    /** Everything help and usage need to know about the command. */
    prop spec: CommandSpec

    /**
     * Parses the command's arguments from `args`, calls the function and returns its exit code.
     *
     * throws UsageException on a malformed command line.
     */
    func run(args: ArgCursor): Int64
}

/**
 * The app-level options of an `App`, run before its subcommand: what `@Callback` generates.
 *
 * `run` reads the options up to the subcommand's name and leaves the rest in `args`.
 */
public interface Callback {
    /** Everything help and usage need to know about the app-level options. */
    prop spec: CommandSpec

    /**
     * Parses the app-level options from `args`, calls the function and returns its exit code.
     *
     * throws UsageException on a malformed command line.
     */
    func run(args: ArgCursor): Int64
}
