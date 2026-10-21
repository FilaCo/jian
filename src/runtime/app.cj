package jian.runtime

import std.collection.ArrayList
import std.env.getStdErr
import std.io.OutputStream

/**
 * Explicitly registered commands and sub-apps, with optional app-level options.
 * `stderr` receives usage errors and is never closed by the app.
 * Nested apps use the root app's stream and report the full command path.
 */
public class App {
    private let commands = ArrayList<Command>()
    private let apps = ArrayList<App>()
    private var appCallback: ?Callback = None

    public App(public let name!: String, public let help!: String = "",
        private let stderr!: OutputStream = getStdErr()) {}

    /**
     * Registers a command and returns this app for chaining.
     *
     * throws IllegalArgumentException if a command or sub-app already has this name.
     */
    public func add(command: Command): App {
        requireAvailable(command.name)
        commands.add(command)
        this
    }

    /**
     * Registers a sub-app under its name and returns this app for chaining.
     *
     * throws IllegalArgumentException if a command or sub-app already has this name.
     */
    public func add(app: App): App {
        requireAvailable(app.name)
        apps.add(app)
        this
    }

    /**
     * Sets the callback that consumes app options before command dispatch,
     * replacing any previous callback. Returns this app for chaining.
     */
    public func callback(value: Callback): App {
        appCallback = Some(value)
        this
    }

    /**
     * Runs argv excluding the executable name and returns the command's exit code.
     * A nonzero callback code stops dispatch. A callback alone may run without a command.
     * UsageException prints an error and basic usage to stderr and returns 2;
     * other exceptions propagate to the caller.
     */
    public func run(argv: Array<String>): Int64 {
        dispatch(argv, name, stderr)
    }

    private func dispatch(argv: Array<String>, path: String, errors: OutputStream): Int64 {
        var usage = "Usage: ${path} [OPTIONS] COMMAND [ARGS]...\n"
        try {
            let shorts = match (appCallback) {
                case Some(value) => valueShorts(value.spec)
                case None => Array<Byte>()
            }
            let args = ArgCursor(argv, shortsTakingValue: shorts)
            if (let Some(value) <- appCallback) {
                let code = value.run(args)
                if (code != 0) {
                    return code
                }
            }
            let commandName = match (args.next()) {
                case Some(Arg.Operand(value)) => value
                case Some(Arg.Long(value)) =>
                    throw UsageException.unknownOption("--" + value)
                case Some(Arg.Long(value, _)) =>
                    throw UsageException.unknownOption("--" + value)
                case Some(Arg.Short(value)) =>
                    throw UsageException.unknownOption("-" + String.fromUtf8([value]))
                case Some(Arg.Short(value, _)) =>
                    throw UsageException.unknownOption("-" + String.fromUtf8([value]))
                case None =>
                    if (appCallback.isSome() && commands.isEmpty() && apps.isEmpty()) {
                        return 0
                    }
                    throw UsageException.missingArgument("COMMAND")
            }
            for (command in commands) {
                if (command.name == commandName) {
                    usage = "Usage: ${path} ${commandName} [ARGS]...\n"
                    return command.run(ArgCursor(args.remaining(), shortsTakingValue: valueShorts(command.spec)))
                }
            }
            for (app in apps) {
                if (app.name == commandName) {
                    // Nested failures use the full invocation and the root's injected stream.
                    return app.dispatch(args.remaining(), path + " " + commandName, errors)
                }
            }
            throw UsageException("unknown command '${commandName}'")
        } catch (error: UsageException) {
            errors.write(("Error: ${error.message}\n" + usage).toArray())
            errors.flush()
            2
        }
    }

    private func requireAvailable(value: String): Unit {
        for (command in commands) {
            if (command.name == value) {
                throw IllegalArgumentException("duplicate command '${value}'")
            }
        }
        for (app in apps) {
            if (app.name == value) {
                throw IllegalArgumentException("duplicate command '${value}'")
            }
        }
    }
}

private func valueShorts(spec: CommandSpec): Array<Byte> {
    let shorts = ArrayList<Byte>()
    for (param in spec.params) {
        if (param.kind == ParamKind.ValueOption) {
            if (let Some(value) <- param.short) {
                shorts.add(value)
            }
        }
    }
    shorts.toArray()
}
