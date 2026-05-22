package jian.builders

import std.collection.ArrayList
import jian.parsing.ParsedArgs

sealed abstract class Invokable {
    Invokable(public let params!: Array<Param> = [], public let invoke!: (ParsedArgs) -> Unit,
        public let help!: ?String = None) {}

    public static func builder(): InvokableBuilder {
        InvokableBuilder()
    }
}

public class Callback <: Invokable {
    Callback(params!: Array<Param> = [], invoke!: (ParsedArgs) -> Unit, help!: ?String = None) {
        super(params: params, invoke: invoke, help: help)
    }
}

/**
 *
 */
public class Command <: Invokable & Equatable<Command> {
    Command(params!: Array<Param> = [], invoke!: (ParsedArgs) -> Unit, help!: ?String = None, public let name!: String) {
        super(params: params, invoke: invoke, help: help)
    }

    public static func builder(name: String): InvokableBuilder {
        InvokableBuilder().name(name)
    }

    public operator func ==(other: Command): Bool {
        name == other.name
    }
}

public class InvokableBuilder {
    private let _params = ArrayList<Param>()
    private var _invoke = None<(ParsedArgs) -> Unit>
    private var _help = None<String>
    private var _name = None<String>

    public func build(): Invokable {
        match ((_name, _invoke)) {
            case (Some(name), Some(invoke)) => Command(params: getParams(), invoke: invoke, help: getHelp(), name: name)
            case (_, Some(invoke)) => Callback(params: getParams(), invoke: invoke, help: getHelp())
            case (_, None) => throw IllegalArgumentException("Invokable must have the `invoke` field")
        }
    }

    public func add(param: Param): This {
        _params.add(param)
        this
    }

    public func getParams(): Array<Param> {
        _params.toArray()
    }

    public func invoke(invoke: (ParsedArgs) -> Unit): This {
        _invoke = invoke
        this
    }

    public func getInvoke(): ?(ParsedArgs) -> Unit {
        _invoke
    }

    public func help(help: String): This {
        _help = help
        this
    }

    public func getHelp(): ?String {
        _help
    }

    public func name(name: String): This {
        _name = name
        this
    }

    public func getName(): ?String {
        _name
    }
}
