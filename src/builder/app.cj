package jian.builder

import std.argopt.{ArgumentParseException, parseArguments}
import std.env.exit
import std.collection.HashMap

/**
 * cjlint-ignore -start !G.OPR.01
 * TODO: add description
 */

/**
 *
 */
public struct App {
    App(private let _name: String, private let _help: ?String, private let _flags: AppFlags,
        private let _commands: HashMap<String, Command>, private let _subApps: HashMap<String, App>,
        private let _callback: ?Callback) {}

    prop noArgsIsHelp: Bool {
        get() {
            _flags.noArgsIsHelp
        }
    }

    public static func builder(): AppBuilder {
        AppBuilder()
    }

    public operator func ()(argv: Array<String>): Nothing {
        if (argv.size == 0) {
            if (noArgsIsHelp) {
                // TODO: render help
                exit(0)
            }

            // TODO: render error
            exit(1)
        }

        let nonOptions = _callback.map {
            cb => try {
                parseArguments(argv, cb.argSpecs).nonOptions
            } catch (e: ArgumentParseException) {
                // TODO: render error
                exit(1)
            }
        } ?? argv

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
    // private var _name = None<String>
    // private var _help = None<String>
    // private var _noArgsIsHelp = false
    // private var _invokeCallbackWithoutCommand = false
    // private var _callback = None<Callback>
    // private let _commandSpecs = HashMap<String, Command>()
    // private let _subApps = HashMap<String, App>()

    // public func build(): App {
    //     throw UnsupportedException()
    // }

    // public func name(v: String): AppBuilder
    //     _name = v
    //     this
    // }

    // public func getName(): ?String {
    //     _name
    // }

    // public func help(v: String): AppBuilder
    //     _help = v
    //     this
    // }

    // public func getHelp(): ?String {
    //     _help
    // }

    // public func noArgsIsHelp(v: Bool): AppBuilder
    //     _noArgsIsHelp = v
    //     this
    // }

    // public func getNoArgsIsHelp(): Bool {
    //     _noArgsIsHelp
    // }

    // /**
    //  * Adds sub application to the current application.
    //  *
    //  * throws IllegalArgumentException - if `name` and `builder.getName()` are both `None`
    //  */
    // public func add(builder: AppBuilder, name!: ?String = None, help!: ?String = None): AppBuilder
    //     ifSome(name, {n => builder.name(n)})
    //     ifSome(help, {h => builder.help(h)})

    //     let subAppName = builder.getName() ?? throw IllegalArgumentException(
    //         "Unable to bind the sub application without a name")
    //     _subApps.add(subAppName, builder.build())

    //     this
    // }

    // public func add(command: Command): AppBuilder
    //     _commandSpecs.add(command.name, command)
    //     this
    // }

    // public func callback(v: Callback): AppBuilder
    //     _callback = v
    //     this
    // }

    // public operator func ()(argv: Array<String>): Nothing {
    //     let app = build()
    //     app(argv)
    // }
}

// cjlint-ignore -end

struct AppFlags {
    protected static const NO_ARGS_IS_HELP_MASK: UInt8 = 1 << 0

    AppFlags(private let _packed: UInt8) {}

    prop noArgsIsHelp: Bool {
        get() {
            (_packed & NO_ARGS_IS_HELP_MASK) > 0
        }
    }
}

class AppFlagsBuilder {
    private var _packed: UInt8 = 0

    func build(): AppFlags {
        AppFlags(_packed)
    }

    func withNoArgsIsHelp(): This {
        _packed |= AppFlags.NO_ARGS_IS_HELP_MASK

        this
    }
}
