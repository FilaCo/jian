package jian.runtime

import std.collection.ArrayList
import std.env.{getStdErr, getStdOut}
import std.io.OutputStream
import std.sort.sort

/**
 * Explicitly registered commands and sub-apps, with optional app-level options.
 * `stdout` receives help and `stderr` receives usage errors; neither stream is closed.
 * During run, nested apps use this app's streams and report the full command path.
 */
public class JianApp {
    private let commands = ArrayList<JianCommand>()
    private let apps = ArrayList<JianApp>()
    private var appCallback: ?JianCallback = None

    public JianApp(public let name!: String, public let help!: String = "",
        private let stderr!: OutputStream = getStdErr(),
        private let stdout!: OutputStream = getStdOut()) {}

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
     * `--help` or `-h` prints help to stdout and returns 0 without invoking the target.
     * Ancestor callbacks still run before help for a nested target.
     * JianUsageException prints an error and usage to stderr and returns 2;
     * other exceptions propagate to the caller.
     */
    public func run(argv: Array<String>): Int64 {
        dispatch(argv, name, stdout, stderr)
    }

    private func dispatch(argv: Array<String>, path: String, output: OutputStream, errors: OutputStream): Int64 {
        let spec = match (appCallback) {
            case Some(value) => value.spec
            case None => JianCommandSpec()
        }
        let hasCommands = !commands.isEmpty() || !apps.isEmpty() || appCallback.isNone()
        var usage = usageLine(path, spec, commands: hasCommands)
        try {
            if (requestsHelp(argv, spec, app: true)) {
                output.write(appHelp(path, spec, hasCommands).toArray())
                output.flush()
                return 0
            }
            let args = JianArgCursor(argv, shortsTakingValue: valueShorts(spec))
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
                    let commandSpec = command.spec
                    let commandPath = path + " " + commandName
                    usage = usageLine(commandPath, commandSpec)
                    let remaining = args.remaining()
                    if (requestsHelp(remaining, commandSpec)) {
                        output.write(commandHelp(commandPath, commandSpec).toArray())
                        output.flush()
                        return 0
                    }
                    return command.run(JianArgCursor(remaining, shortsTakingValue: valueShorts(commandSpec)))
                }
            }
            for (app in apps) {
                if (app.name == commandName) {
                    // Nested help and failures use the full invocation and the root's streams.
                    return app.dispatch(args.remaining(), path + " " + commandName, output, errors)
                }
            }
            throw JianUsageException("unknown command '${commandName}'")
        } catch (error: JianUsageException) {
            errors.write(("Error: ${error.message}\n" + usage).toArray())
            errors.flush()
            2
        }
    }

    private func appHelp(path: String, spec: JianCommandSpec, hasCommands: Bool): String {
        var text = usageLine(path, spec, commands: hasCommands)
        if (!help.isEmpty()) { text += "\n" + help + "\n" }
        if (!spec.help.isEmpty()) { text += "\n" + spec.help + "\n" }
        text += parameterHelp(spec)
        let names = commands.toArray().map({ command => command.name }).concat(apps.toArray().map({ app => app.name }))
        sort(names)
        if (!names.isEmpty()) { text += "\nCommands:\n" }
        for (entry in names) {
            for (command in commands) {
                if (command.name == entry) { text += helpRow(entry, command.spec.help) }
            }
            for (app in apps) {
                if (app.name == entry) { text += helpRow(entry, app.help) }
            }
        }
        text
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

func valueShorts(spec: JianCommandSpec): Array<Byte> {
    let shorts = ArrayList<Byte>()
    for (input in spec.inputs) {
        if (input.kind == JianInputKind.ValueOption) {
            if (let Some(value) <- input.short) {
                shorts.add(value)
            }
        }
    }
    shorts.toArray()
}
