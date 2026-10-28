package jian.runtime

import std.collection.ArrayList
import std.env.{getStdErr, getStdOut}
import std.io.OutputStream
import std.sort.sort

/**
 * Explicitly registered commands and sub-apps, with optional app-level options.
 * Nested apps use the root's streams and report the full command path.
 */
public class JianApp {
    private let core: AppCore<Unit>

    public let name: String
    public let help: String

    public init(name!: String, help!: String = "",
        stderr!: OutputStream = getStdErr(), stdout!: OutputStream = getStdOut()) {
        this.name = name
        this.help = help
        core = AppCore<Unit>(name: name, help: help, stderr: stderr, stdout: stdout)
    }

    /** Registers a command; throws IllegalArgumentException on a duplicate name. */
    public func add(command: JianCommand): JianApp {
        core.add(PlainCommand<Unit>(command))
        this
    }

    /** Registers a sub-app; throws IllegalArgumentException on a duplicate name. */
    public func add(app: JianApp): JianApp {
        core.add(app.core)
        this
    }

    /** Replaces the callback that consumes app options before dispatch. */
    public func callback(value: JianCallback): JianApp {
        core.callback(PlainCallback<Unit>(value))
        this
    }

    /**
     * Runs argv excluding the executable name. Help returns 0 without invoking the target;
     * ancestor callbacks still run before nested help. A nonzero callback stops dispatch.
     * JianUsageException prints an error and usage to stderr and returns 2;
     * other exceptions propagate. A callback-only app may run without a command.
     * Neither output stream is closed.
     */
    public func run(argv: Array<String>): Int64 { core.run(argv, ()) }
}

/**
 * A command tree sharing one concrete context type. Supply the context on each run;
 * this app never retains it. Sub-apps inherit that run's context and root streams.
 */
public class JianContextApp<C> {
    private let core: AppCore<C>

    public let name: String
    public let help: String

    public init(name!: String, help!: String = "",
        stderr!: OutputStream = getStdErr(), stdout!: OutputStream = getStdOut()) {
        this.name = name
        this.help = help
        core = AppCore<C>(name: name, help: help, stderr: stderr, stdout: stdout)
    }

    /** Registers a command requiring this app's context type. Duplicate names throw IllegalArgumentException. */
    public func add(command: JianContextCommand<C>): JianContextApp<C> {
        core.add(command)
        this
    }

    /** Registers an ordinary command, which ignores the context; duplicate names throw IllegalArgumentException. */
    public func add(command: JianCommand): JianContextApp<C> {
        core.add(PlainCommand<C>(command))
        this
    }

    /** Registers a sub-app with the same context type. Duplicate names throw IllegalArgumentException. */
    public func add(app: JianContextApp<C>): JianContextApp<C> {
        core.add(app.core)
        this
    }

    /** Replaces the callback that consumes app options before dispatch. */
    public func callback(value: JianContextCallback<C>): JianContextApp<C> {
        core.callback(value)
        this
    }

    /** Sets an ordinary callback, which ignores the context. */
    public func callback(value: JianCallback): JianContextApp<C> {
        core.callback(PlainCallback<C>(value))
        this
    }

    /**
     * Runs argv excluding the executable name with the supplied context.
     * Callbacks run from root to leaf, then the selected command. Class contexts share
     * object identity; value contexts follow normal value semantics. Help, exit codes,
     * streams and exceptions follow JianApp.run. Reusing a context preserves its mutations.
     */
    public func run(argv: Array<String>, context!: C): Int64 { core.run(argv, context) }
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

class AppCore<C> {
    private let commands = ArrayList<JianContextCommand<C>>()
    private let apps = ArrayList<AppCore<C>>()
    private var appCallback: ?JianContextCallback<C> = None

    AppCore(public let name!: String, public let help!: String = "",
        private let stderr!: OutputStream = getStdErr(),
        private let stdout!: OutputStream = getStdOut()) {}

    public func add(command: JianContextCommand<C>): AppCore<C> {
        requireAvailable(command.name)
        commands.add(command)
        this
    }

    public func add(app: AppCore<C>): AppCore<C> {
        requireAvailable(app.name)
        apps.add(app)
        this
    }

    public func callback(value: JianContextCallback<C>): AppCore<C> {
        appCallback = Some(value)
        this
    }

    public func run(argv: Array<String>, context: C): Int64 {
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
