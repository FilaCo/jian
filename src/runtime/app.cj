package jian.runtime

import std.collection.ArrayList
import std.env.getStdErr
import std.io.OutputStream

/**
 * Explicitly registered commands and sub-apps, with optional app-level options.
 * `stderr` receives usage errors and is never closed by the app.
 * During run, nested apps use this app's stream and report the full command path.
 */
public class JianApp {
    private let commands = ArrayList<JianCommand>()
    private let apps = ArrayList<JianApp>()
    private var appCallback: ?JianCallback = None

    public JianApp(public let name!: String, public let help!: String = "",
        private let stderr!: OutputStream = getStdErr()) {}

    /**
     * Registers a command and returns this app for chaining.
     *
     * throws IllegalArgumentException if a command or sub-app already has this name.
     */
    public func add(command: JianCommand): JianApp {
        requireAvailable(command.name)
        commands.add(command)
        this
    }

    /**
     * Registers a sub-app under its name and returns this app for chaining.
     *
     * throws IllegalArgumentException if a command or sub-app already has this name.
     */
    public func add(app: JianApp): JianApp {
        requireAvailable(app.name)
        apps.add(app)
        this
    }

    /**
     * Sets the callback that consumes app options before command dispatch,
     * replacing any previous callback. Returns this app for chaining.
     */
    public func callback(value: JianCallback): JianApp {
        appCallback = Some(value)
        this
    }

    /**
     * Runs argv excluding the executable name and returns the command's exit code.
     * A nonzero callback code stops dispatch. A callback alone may run without a command.
     * JianUsageException prints an error and basic usage to stderr and returns 2;
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
            let args = JianArgCursor(argv, shortsTakingValue: shorts)
            if (let Some(value) <- appCallback) {
                let code = value.run(args)
                if (code != 0) {
                    return code
                }
            }
            let commandName = match (args.next()) {
                case Some(JianArg.Operand(value)) => value
                case Some(JianArg.Long(value)) =>
                    throw JianUsageException.unknownOption("--" + value)
                case Some(JianArg.Long(value, _)) =>
                    throw JianUsageException.unknownOption("--" + value)
                case Some(JianArg.Short(value)) =>
                    throw JianUsageException.unknownOption("-" + String.fromUtf8([value]))
                case Some(JianArg.Short(value, _)) =>
                    throw JianUsageException.unknownOption("-" + String.fromUtf8([value]))
                case None =>
                    if (appCallback.isSome() && commands.isEmpty() && apps.isEmpty()) {
                        return 0
                    }
                    throw JianUsageException.missingArgument("COMMAND")
            }
            for (command in commands) {
                if (command.name == commandName) {
                    usage = "Usage: ${path} ${commandName} [ARGS]...\n"
                    return command.run(JianArgCursor(args.remaining(), shortsTakingValue: valueShorts(command.spec)))
                }
            }
            for (app in apps) {
                if (app.name == commandName) {
                    // Nested failures use the full invocation and the root's injected stream.
                    return app.dispatch(args.remaining(), path + " " + commandName, errors)
                }
            }
            throw JianUsageException("unknown command '${commandName}'")
        } catch (error: JianUsageException) {
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

private func valueShorts(spec: JianCommandSpec): Array<Byte> {
    let shorts = ArrayList<Byte>()
    for (param in spec.params) {
        if (param.kind == JianParamKind.ValueOption) {
            if (let Some(value) <- param.short) {
                shorts.add(value)
            }
        }
    }
    shorts.toArray()
}
