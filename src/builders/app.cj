package jian.builders

import std.env.exit
import std.collection.{ArrayList, map, collectArray, ReadOnlyMap}
import jian.parsing.{ArgSpec, parseArgs}

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
            throw UnsupportedException()
        }
        let firstArg = argv[0]
        if (firstArg.startsWith("-")) {
            throw UnsupportedException()
        }
        /**  
         * command or sub app call:
         * 1. lookup commands
         * 2. if not found then lookup sub apps
         * 3. if not found then give up
         */
        commands.get(firstArg).map {
            cmd: Command => cmd.invoke(parseArgs(argv[1..], cmd.params.toArgSpec()))
        } ?? subApps.get(firstArg).map {app => app.run(argv[1..])} ?? exit(1)

        exit(0)
    }
}

extend Array<Param> {
    func toArgSpec(): Array<ArgSpec> {
        map { it => it.toArgSpec() } |> collectArray
    }
}

public class AppBuilder {
    private var _name = None<String>
    private var _help = None<String>
    private let _commands = ArrayList<Command>()
    private let _subApps = ArrayList<() -> App>()
    private var _callback = None<Callback>

    public func build(): App {
        throw Exception()
        // App(name: getName(), help: getHelp(), commands: getCommands(), subApps: getSubApps())
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
