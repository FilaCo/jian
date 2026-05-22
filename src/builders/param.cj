package jian.builders

sealed abstract class Param <: Equatable<Param> {
    Param(public let name!: String, public let help!: ?String = None) {}

    public static func builder(name: String): ParamBuilder {
        ParamBuilder(name)
    }

    public operator func ==(other: Param): Bool {
        name == other.name
    }
}

class Opt <: Param {
    Opt(name!: String, help!: ?String = None, public let short!: ?Byte = None, public let long!: ?String = None) {
        super(name: name, help: help)
    }
}

class Pos <: Param {
    Pos(name!: String, help!: ?String = None) {
        super(name: name, help: help)
    }
}

public class ParamBuilder {
    private var _help = None<String>
    private var _short = None<Byte>
    private var _long = None<String>

    ParamBuilder(private var _name: String) {}

    public func build(): Param {
        match ((_short, _long)) {
            case (Some(s), Some(l)) => Opt(name: getName(), help: getHelp(), short: s, long: l)
            case (Some(s), None) => Opt(name: getName(), help: getHelp(), short: s)
            case (None, Some(l)) => Opt(name: getName(), help: getHelp(), long: l)
            case _ => Pos(name: getName(), help: getHelp())
        }
    }

    public func name(name: String): This {
        _name = name
        this
    }

    public func getName(): String {
        _name
    }

    public func help(help: String): This {
        _help = help
        this
    }

    public func getHelp(): ?String {
        _help
    }

    public func short(short: Byte): This {
        _short = short
        this
    }

    public func getShort(): ?Byte {
        _short
    }

    public func long(long: String): This {
        _long = long
        this
    }

    public func getLong(): ?String {
        _long
    }
}
