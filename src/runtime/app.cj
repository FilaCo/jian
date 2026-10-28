package jian.runtime

import std.collection.ArrayList
import std.env.{getStdErr, getStdOut}
import std.io.OutputStream
import std.sort.sort

/** Context type for apps without injected dependencies; an alias for Unit. */
public type JianNoContext = Unit

/**
 * A command tree sharing one concrete context type; use JianApp<JianNoContext> without injection.
 * Supply context on each run. Nested apps inherit that run's context and root output streams.
 */
public class JianApp<C> {
    private let commands = ArrayList<JianContextCommand<C>>()
    private let apps = ArrayList<JianApp<C>>()
    private var appCallback: ?JianContextCallback<C> = None

    public JianApp(public let name!: String, public let help!: String = "",
        private let stderr!: OutputStream = getStdErr(),
        private let stdout!: OutputStream = getStdOut()) {}

    /** Registers a typed command; duplicate names throw IllegalArgumentException. */
    public func add(command: JianContextCommand<C>): JianApp<C> {
        requireAvailable(command.name)
        commands.add(command)
        this
    }

    /** Registers an ordinary command, which ignores the context. */
    public func add(command: JianCommand): JianApp<C> { add(PlainCommand<C>(command)) }

    /** Registers a sub-app of the same context type; duplicate names throw IllegalArgumentException. */
    public func add(app: JianApp<C>): JianApp<C> {
        requireAvailable(app.name)
        apps.add(app)
        this
    }

    /** Replaces the callback that consumes app inputs before command dispatch. */
    public func callback(value: JianContextCallback<C>): JianApp<C> {
        appCallback = Some(value)
        this
    }

    /** Sets an ordinary callback, which ignores the context. */
    public func callback(value: JianCallback): JianApp<C> { callback(PlainCallback<C>(value)) }

    /**
     * Runs argv excluding the executable name with the supplied context, without retaining it.
     * Callbacks run from root to leaf, then the command. A nonzero callback stops dispatch;
     * a callback-only app may run without a command. Reusing a class context preserves mutations.
     * Help returns 0 without invoking the target; ancestor callbacks still run before nested help.
     * JianUsageException prints an error and usage to stderr and returns 2; other exceptions propagate.
     * stdout receives help and stderr receives usage errors; neither stream is closed.
     */
    public func run(argv: Array<String>, context!: C): Int64 {
        dispatch(argv, name, stdout, stderr, context)
    }

    private func dispatch(argv: Array<String>, path: String, output: OutputStream, errors: OutputStream, context: C): Int64 {
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
                let code = value.run(args, context)
                if (code != 0) {
                    return code
                }
            }
            let commandName = match (args.next()) {
                case Some(JianArg.Operand(value)) => value
                case Some(JianArg.Long(value)) =>
                    throw JianUsageException.unknownOption("--${value}")
                case Some(JianArg.Long(value, _)) =>
                    throw JianUsageException.unknownOption("--${value}")
                case Some(JianArg.Short(value)) =>
                    throw JianUsageException.unknownOption("-${String.fromUtf8([value])}")
                case Some(JianArg.Short(value, _)) =>
                    throw JianUsageException.unknownOption("-${String.fromUtf8([value])}")
                case None =>
                    if (appCallback.isSome() && commands.isEmpty() && apps.isEmpty()) {
                        return 0
                    }
                    throw JianUsageException.missingArgument("COMMAND")
            }
            for (command in commands) {
                if (command.name == commandName) {
                    let commandSpec = command.spec
                    let commandPath = "${path} ${commandName}"
                    usage = usageLine(commandPath, commandSpec)
                    let remaining = args.remaining()
                    if (requestsHelp(remaining, commandSpec)) {
                        output.write(commandHelp(commandPath, commandSpec).toArray())
                        output.flush()
                        return 0
                    }
                    return command.run(JianArgCursor(remaining, shortsTakingValue: valueShorts(commandSpec)), context)
                }
            }
            for (app in apps) {
                if (app.name == commandName) {
                    // Nested help and failures use the full invocation and the root's streams.
                    return app.dispatch(args.remaining(), "${path} ${commandName}", output, errors, context)
                }
            }
            throw JianUsageException("unknown command '${commandName}'")
        } catch (error: JianUsageException) {
            errors.write("Error: ${error.message}\n${usage}".toArray())
            errors.flush()
            2
        }
    }

    private func appHelp(path: String, spec: JianCommandSpec, hasCommands: Bool): String {
        var text = usageLine(path, spec, commands: hasCommands)
        if (!help.isEmpty()) { text += "\n${help}\n" }
        if (!spec.help.isEmpty()) { text += "\n${spec.help}\n" }
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

/** Context-free apps can run without explicitly supplying context. */
extend JianApp<JianNoContext> {
    /** Runs argv excluding the executable name; help, errors and exit codes follow JianApp.run. */
    public func run(argv: Array<String>): Int64 { run(argv, context: ()) }
}

class PlainCommand<C> <: JianContextCommand<C> {
    PlainCommand(private let command: JianCommand) {}
    public prop name: String { get() { command.name } }
    public prop spec: JianCommandSpec { get() { command.spec } }
    public func run(args: JianArgCursor, _: C): Int64 { command.run(args) }
}

class PlainCallback<C> <: JianContextCallback<C> {
    PlainCallback(private let callback: JianCallback) {}
    public prop spec: JianCommandSpec { get() { callback.spec } }
    public func run(args: JianArgCursor, _: C): Int64 { callback.run(args) }
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
