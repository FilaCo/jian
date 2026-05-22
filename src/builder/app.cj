package jian.builder

import std.env.exit
import std.collection.{collectHashMap, map, HashMap}

/**
 * cjlint-ignore -start !G.OPR.01
 * TODO: add description
 */

/**
 *
 */
public struct App {
    App(private let _name: ?String, private let _help: ?String,
        private let _cmds: HashMap<String, Cmd>, private let _subApps: HashMap<String, App>) {}

    public static func builder(): AppBuilder {
        AppBuilder()
    }

    public operator func ()(argv: Array<String>): Nothing {
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
    private let _cmdBuilders = HashMap<String, CmdBuilder>()
    private let _subAppBuilders = HashMap<String, AppBuilder>()

    public func build(): App {
        let commands = _cmdBuilders |> map {
            item =>
                let (name, cmdBuilder) = item
                (name, cmdBuilder.build())
        } |> collectHashMap

        let subApps = _subAppBuilders |> map {
            item =>
                let (name, subAppBuilder) = item
                (name, subAppBuilder.build())
        } |> collectHashMap

        App(_name, _help, commands, subApps)
    }

    public func name(name: String): This {
        _name = name
        this
    }

    public func help(help: String): AppBuilder {
        _help = help
        this
    }

    /**
     * Adds sub application to the current application.
     *
     * throws IllegalArgumentException - if `name` and `builder.getName()` are both `None`
     */
    public func add(builder: AppBuilder, name!: ?String = None, help!: ?String = None): AppBuilder {
        ifSome(name, {n => builder.name(n)})
        ifSome(help, {h => builder.help(h)})

        let subAppName = builder._name ?? throw IllegalArgumentException(
            "Unable to bind the sub application without a name")
        _subAppBuilders.add(subAppName, builder)
        this
    }

    public func add(builder: CmdBuilder): AppBuilder {
        _cmdBuilders.add(builder.getName(), builder)
        this
    }

    public operator func ()(argv: Array<String>): Nothing {
        let app = build()
        app(argv)
    }
}

// cjlint-ignore -end
