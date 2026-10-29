package jian.runtime

import std.collection.ArrayList
import std.env.{getStdErr, getStdOut}
import std.io.OutputStream
import std.sort.sort

/**
 * An application without injected context. Defaults to "app" in standalone usage.
 * Commands retain their names even when the application has only one command.
 */
public class JianApp {
    let core: AppCore<Unit>
    public let name: String
    public let help: String

    public init(name!: String = "app", help!: String = "",
        stderr!: OutputStream = getStdErr(), stdout!: OutputStream = getStdOut()) {
        this.name = name
        this.help = help
        core = AppCore<Unit>(help, stderr, stdout)
    }

    /** Registers a function annotated with @JianCommand. */
    public func add(factory: (JianCommandTag) -> JianCommand): JianApp {
        add(factory(JianCommandTag()))
    }

    /**
     * Registers a command adapter; duplicate names throw IllegalArgumentException.
     * @JianCommand[app] generates this registration automatically.
     */
    public func add(command: JianCommand): JianApp {
        core.add(PlainCommand<Unit>(command))
        this
    }

    /**
     * Mounts a child under name, optionally overriding its help for this path.
     * Duplicate names and cycles throw IllegalArgumentException. The child is shared.
     */
    public func add(app: JianApp, name!: String, help!: ?String = None): JianApp {
        core.mount(app.core, name, help ?? app.help, { _: Unit => () })
        this
    }

    /** Registers a function annotated with @JianCallback. */
    public func callback(factory: (JianCallbackTag) -> JianCallback): JianApp {
        callback(factory(JianCallbackTag()))
    }

    /**
     * Registers the single app callback; a second callback throws IllegalArgumentException.
     * @JianCallback[app] generates this registration automatically.
     */
    public func callback(value: JianCallback): JianApp {
        core.callback(PlainCallback<Unit>(value))
        this
    }

    /**
     * Runs argv excluding the executable name. Help returns 0; usage errors return 2.
     * Callback Exit(code) returns immediately, including Exit(0); Continue dispatches.
     * Other exceptions propagate. Ancestor callbacks may run before nested help.
     * Help and usage errors use the root streams, which remain open.
     */
    public func run(argv: Array<String>): Int64 { core.dispatch(argv, name, core.stdout, core.stderr, ()) }
}

/**
 * An application with a concrete context supplied on every run, without retaining it.
 * Child contexts are extracted after the parent callback, when entering the selected child.
 */
public class JianContextApp<C> {
    let core: AppCore<C>
    public let name: String
    public let help: String

    public init(name!: String = "app", help!: String = "",
        stderr!: OutputStream = getStdErr(), stdout!: OutputStream = getStdOut()) {
        this.name = name
        this.help = help
        core = AppCore<C>(help, stderr, stdout)
    }

    /** Registers a function requiring this context, annotated with @JianCommand. */
    public func add(factory: (JianContextCommandTag<C>) -> JianContextCommand<C>): JianContextApp<C> {
        add(factory(JianContextCommandTag<C>()))
    }

    /** Registers a function annotated with @JianCommand that ignores the context. */
    public func add(factory: (JianCommandTag) -> JianCommand): JianContextApp<C> {
        add(factory(JianCommandTag()))
    }

    /**
     * Registers an adapter requiring this context; duplicate names throw IllegalArgumentException.
     */
    public func add(command: JianContextCommand<C>): JianContextApp<C> {
        core.add(command)
        this
    }

    /**
     * Registers a command that ignores the context.
     */
    public func add(command: JianCommand): JianContextApp<C> { add(PlainCommand<C>(command)) }

    /**
     * Mounts a child sharing this run's context. Names and help belong to the mount.
     * Duplicate names and cycles throw IllegalArgumentException.
     */
    public func add(app: JianContextApp<C>, name!: String, help!: ?String = None): JianContextApp<C> {
        core.mount(app.core, name, help ?? app.help, { context: C => context })
        this
    }

    /**
     * Mounts a child that ignores the context, sharing the root streams.
     */
    public func add(app: JianApp, name!: String, help!: ?String = None): JianContextApp<C> {
        core.mount(app.core, name, help ?? app.help, { _: C => () })
        this
    }

    /**
     * Mounts a child with an explicit context projection, evaluated on entry to that child.
     * The overload without context selects typed extraction automatically.
     */
    public func add<D>(app: JianContextApp<D>, name!: String, help!: ?String = None,
        context!: (C) -> D): JianContextApp<C> {
        core.mount(app.core, name, help ?? app.help, context)
        this
    }

    /** Registers a function requiring this context, annotated with @JianCallback. */
    public func callback(factory: (JianContextCallbackTag<C>) -> JianContextCallback<C>): JianContextApp<C> {
        callback(factory(JianContextCallbackTag<C>()))
    }

    /** Registers a function annotated with @JianCallback that ignores the context. */
    public func callback(factory: (JianCallbackTag) -> JianCallback): JianContextApp<C> {
        callback(factory(JianCallbackTag()))
    }

    /**
     * Registers the single callback; a second callback throws IllegalArgumentException.
     */
    public func callback(value: JianContextCallback<C>): JianContextApp<C> {
        core.callback(value)
        this
    }

    /**
     * Registers a callback that ignores the context.
     */
    public func callback(value: JianCallback): JianContextApp<C> { callback(PlainCallback<C>(value)) }

    /**
     * Runs argv excluding the executable name with this invocation's context.
     * Callbacks run root to leaf; Exit(code) stops dispatch, including Exit(0). Mutations are not rolled back.
     * Help returns 0 and skips its target; ancestor callbacks may already have run.
     * Usage errors return 2 on stderr; other exceptions propagate. Streams remain open.
     * The caller owns context resources and synchronization of shared mutable state.
     */
    public func run(argv: Array<String>, context!: C): Int64 {
        core.dispatch(argv, name, core.stdout, core.stderr, context)
    }
}

// A separate identity graph detects cycles across apps with different context types.
class AppNode {
    let children = ArrayList<AppNode>()

    func reaches(target: AppNode): Bool {
        refEq(this, target) || children.toArray().any({ child => child.reaches(target) })
    }
}

interface AppMount<C> {
    prop name: String
    prop help: String
    func dispatch(argv: Array<String>, path: String, output: OutputStream, errors: OutputStream, context: C): Int64
}

class ContextMount<P, C> <: AppMount<P> {
    ContextMount(private let child: AppCore<C>, private let mountName: String,
        private let mountHelp: String, private let convert: (P) -> C) {}
    public prop name: String { get() { mountName } }
    public prop help: String { get() { mountHelp } }

    public func dispatch(argv: Array<String>, path: String, output: OutputStream, errors: OutputStream, context: P): Int64 {
        child.dispatch(argv, path, output, errors, convert(context), help: help)
    }
}

class AppCore<C> {
    private let commands = ArrayList<JianContextCommand<C>>()
    private let apps = ArrayList<AppMount<C>>()
    private var appCallback: ?JianContextCallback<C> = None
    let node = AppNode()

    AppCore(let help: String, let stderr: OutputStream, let stdout: OutputStream) {}

    func add(command: JianContextCommand<C>): Unit {
        requireAvailable(command.name)
        commands.add(command)
    }

    func callback(value: JianContextCallback<C>): Unit {
        if (appCallback.isSome()) { throw IllegalArgumentException("duplicate callback") }
        appCallback = Some(value)
    }

    func mount<D>(child: AppCore<D>, name: String, help: String, convert: (C) -> D): Unit {
        requireAvailable(name)
        if (child.node.reaches(node)) { throw IllegalArgumentException("cyclic app mount '${name}'") }
        apps.add(ContextMount<C, D>(child, name, help, convert))
        node.children.add(child.node)
    }

    public func dispatch(argv: Array<String>, path: String, output: OutputStream, errors: OutputStream, context: C, help!: String = this.help): Int64 {
        let spec = match (appCallback) {
            case Some(value) => value.spec
            case None => JianCommandSpec()
        }
        let hasCommands = !commands.isEmpty() || !apps.isEmpty() || appCallback.isNone()
        var usage = usageLine(path, spec, commands: hasCommands)
        try {
            if (requestsHelp(argv, spec, app: true)) {
                output.write(appHelp(path, spec, hasCommands, help).toArray())
                output.flush()
                return 0
            }
            let args = JianArgCursor(argv, shortsTakingValue: valueShorts(spec))
            if (let Some(value) <- appCallback) {
                match (value.run(args, context)) {
                    case JianCallbackResult.Continue => ()
                    case JianCallbackResult.Exit(code) => return code
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

    private func appHelp(path: String, spec: JianCommandSpec, hasCommands: Bool, help: String): String {
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

class PlainCommand<C> <: JianContextCommand<C> {
    PlainCommand(private let command: JianCommand) {}
    public prop name: String { get() { command.name } }
    public prop spec: JianCommandSpec { get() { command.spec } }
    public func run(args: JianArgCursor, _: C): Int64 { command.run(args) }
}

class PlainCallback<C> <: JianContextCallback<C> {
    PlainCallback(private let callback: JianCallback) {}
    public prop spec: JianCommandSpec { get() { callback.spec } }
    public func run(args: JianArgCursor, _: C): JianCallbackResult { callback.run(args) }
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
