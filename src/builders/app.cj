package jian.builders

import std.env.exit
import std.collection.{ArrayList, HashMap, ReadOnlyMap}
import jian.parsing.{parseArgs, ParsedArgs}

/**
 *
 */
public struct App {
    App(public let name!: ?String = None, public let help!: ?String = None,
        public let commands!: ReadOnlyMap<String, Command>, public let subApps!: ReadOnlyMap<String, App>,
        public let callback!: ?Callback = None) {}

    public static func builder(): AppBuilder {
        AppBuilder()
    }

    public func run(argv: Array<String>): Nothing {
        if (argv.size == 0) {
            let emptyArgs = ParsedArgs()
            if (let Some(cb) <- callback) {
                cb.invoke(emptyArgs)
            }
            exit(0)
        }

        let firstArg = argv[0]
        if (firstArg.startsWith("-")) {
            callback.map { cb => cb.invoke(parseArgs(argv, cb.params.map { it => it.toArgSpec() })) }
            exit(0)
        }

        // command or sub app dispatch:
        // 1. lookup commands
        // 2. if not found then lookup sub apps
        // 3. if not found then give up
        commands.get(firstArg).map { c => c.invoke(parseArgs(argv[1..], c.params.map { it => it.toArgSpec() })) } ??
            subApps.get(firstArg).map { app => app.run(argv[1..]) } ??
            exit(1)

        exit(0)
    }
}

public class AppBuilder {
    private var _name = None<String>
    private var _help = None<String>
    private let _commands = ArrayList<Command>()
    private let _subApps = ArrayList<() -> App>()
    private var _callback = None<Callback>

    public func build(): App {
        let cmdMap = HashMap<String, Command>()
        for (cmd in _commands) {
            cmdMap[cmd.name] = cmd
        }

        let subAppMap = HashMap<String, App>()
        for (factory in _subApps) {
            let app = factory()
            if (let Some(n) <- app.name) {
                subAppMap[n] = app
            }
        }

        App(name: getName(), help: getHelp(),
            commands: cmdMap, subApps: subAppMap,
            callback: getCallback())
    }

    public func name(name: String): This {
        _name = name
        this
    }

    public func getName(): ?String {
        _name
    }

    public func help(help: String): This {
        _help = help
        this
    }

    public func getHelp(): ?String {
        _help
    }

    public func add(builder: AppBuilder, name!: ?String = None, help!: ?String = None): This {
        ifSome(name, {n => builder.name(n)})
        ifSome(help, {h => builder.help(h)})
        _subApps.add({=> builder.build()})
        this
    }

    public func add(command: Command): This {
        _commands.add(command)
        this
    }

    public func callback(callback: Callback): This {
        _callback = callback
        this
    }

    public func getCallback(): ?Callback {
        _callback
    }

    public func buildAndRun(argv: Array<String>): Nothing {
        // TODO: try catch app build errors
        let app = build()
        app.run(argv)
    }
}
