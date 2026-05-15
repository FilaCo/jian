protected package jian.api

import std.collection.HashMap
import jian.core.{CallbackSpec, CommandSpec, parse}
import result_cj.Result

public func commandLine(noArgsIsHelp!: Bool = false): AppBuilder {
    AppBuilder()
}

/**
 * cjlint-ignore -start !G.OPR.01
 * TODO: add description
 */
public class App {
    App(private let commandSpecs!: HashMap<String, CommandSpec> = HashMap(),
        private let subApps!: HashMap<String, App> = HashMap(), private let callback!: ?CallbackSpec = None) {}

    prop noArgsIsHelp: Bool {
        get() {
            // TODO: implementation
            false
        }
    }

    public operator func ()(argv: Array<String>): Unit {
        if (argv.size == 0) {
            if (noArgsIsHelp) {
                // TODO: render help
                return
            }

            // TODO: render error
            throw Exception()
        }

        ifSome(
            callback,
            {
                cb => parse(argv, cb.argSpecs).map {matches => cb.invoke(matches)}.unwrap() // TODO: error handling
            }
        )

        let firstArg = argv[0]
        if (firstArg.startsWith("-")) {
            match (callback) {
                // callback was called before, just exit
                case Some(_) => return
                // callback doesn't exist, exit with error
                case None => throw Exception() // TODO: render command not found error
            }
        }
        /**  
         * command or sub app call:
         * 1. lookup commands
         * 2. if not found then lookup subapps
         * 3. if not found then give up
         */
        match (commandSpecs.get(firstArg)) {
            case Some(cmdSpec) => parse(argv[1..], cmdSpec.argSpecs).map {matches => cmdSpec.invoke(matches)}.unwrap() // TODO: error handling
            case _ => subApps.get(firstArg).map {app => app(argv[1..])} ?? throw Exception()
        }
    }
}

public class AppBuilder {
    AppBuilder() {
    }

    public func build(): Result<App, BuildAppError> {
        Ok(App())
    }

    public func add(builder: AppBuilder, name!: ?String = None, help!: ?String = None): This {
        this
    }

    public func add(command: CommandSpec): This {
        this
    }

    public func callback(callback: CallbackSpec): This {
        this
    }

    public operator func ()(argv: Array<String>): Unit {
        build().map {app => app(argv)}.unwrap()
    }
}

// cjlint-ignore -end

type BuildAppError = String
