package jian.builders

import std.env.exit
import std.collection.{ArrayList, HashMap, ReadOnlyMap}

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
        // let nonOptions = _callback.map {
        //     cb => try {
        //         parseArguments(argv, cb.argSpecs).nonOptions
        //     } catch (e: ArgumentParseException) {
        //         // TODO: render error
        //         exit(1)
        //     }
        // } ?? argv

        // let cmdOrApp = nonOptions[0]
        // /**  
        //  * command or sub app call:
        //  * 1. lookup commands
        //  * 2. if not found then lookup subapps
        //  * 3. if not found then give up
        //  */
        // match (_commands.get(cmdOrApp)) {
        //     case Some(cmd) =>
        //         ifSome(
        //             _callback,
        //             {
        //                 cb =>
        //                     let cbArgs = try {
        //                         parseArguments(argv, cb.argSpecs)
        //                     } catch (e: ArgumentParseException) {
        //                         // TODO: render error
        //                         exit(1)
        //                     }
        //                     cb(cbArgs)
        //             }
        //         )
        //         let cmdArgs = try {
        //             parseArguments(argv[1..], cmd.argSpecs)
        //         } catch (e: ArgumentParseException) {
        //             // TODO: render error
        //             exit(1)
        //         }
        //         cmd(cmdArgs)
        //     case _ => match (_subApps.get(cmdOrApp)) {
        //         case Some(app) =>
        //             ifSome(
        //                 _callback,
        //                 {
        //                     cb =>
        //                         let cbArgs = try {
        //                             parseArguments(argv, cb.argSpecs)
        //                         } catch (e: ArgumentParseException) {
        //                             // TODO: render error
        //                             exit(1)
        //                         }
        //                         cb(cbArgs)
        //                 }
        //             )
        //             app(argv[1..])

        //         case _ => match (_callback) {
        //             case Some(cb) where cb.invokeWithoutCommand =>
        //                 let cbArgs = try {
        //                     parseArguments(argv, cb.argSpecs)
        //                 } catch (e: ArgumentParseException) {
        //                     // TODO: render error
        //                     exit(1)
        //                 }
        //                 cb(cbArgs)

        //             case None | Some(cb) where !cb.invokeWithoutCommand => 
        //                 // TODO: render error
        //                 exit(1)

        //         }
        //     }
        // }

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
