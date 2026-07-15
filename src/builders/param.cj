package jian.builders

import jian.parsing.{ArgSpec, OptSpec, PosSpec, newOptSpec, newPosSpec}

sealed abstract class Param <: Equatable<Param> {
    Param(public let name!: String, public let help!: ?String = None) {}

    public static func builder(name: String): ParamBuilder {
        ParamBuilder(name)
    }

    public operator func ==(other: Param): Bool {
        name == other.name
    }

    protected func toArgSpec(): ArgSpec
}

public class Opt <: Param {
    Opt(name!: String, help!: ?String = None, public let short!: ?Byte = None, public let long!: ?String = None,
        public let defaultv!: ?String = None) {
        super(name: name, help: help)
    }

    protected func toArgSpec(): OptSpec {
        newOptSpec(this.name, this.help, this.short, this.long, this.defaultv)
    }
}

public class Pos <: Param {
    Pos(name!: String, help!: ?String = None, public let defaultv!: ?String = None) {
        super(name: name, help: help)
    }

    protected func toArgSpec(): PosSpec {
        newPosSpec(name, help, defaultv)
    }
}

public class ParamBuilder {
    private var _help = None<String>
    private var _short = None<Byte>
    private var _long = None<String>
    private var _default = None<String>

    ParamBuilder(private var _name: String) {}

    public func build(): Param {
        match ((_short, _long)) {
            case (Some(s), Some(l)) => Opt(name: getName(), help: getHelp(), short: s, long: l, defaultv: getDefaultVal())
            case (Some(s), None) => Opt(name: getName(), help: getHelp(), short: s, defaultv: getDefaultVal())
            case (None, Some(l)) => Opt(name: getName(), help: getHelp(), long: l, defaultv: getDefaultVal())
            case _ => Pos(name: getName(), help: getHelp(), defaultv: getDefaultVal())
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

    public func defaultVal(defaultVal: String): This {
        _default = defaultVal
        this
    }

    public func getDefaultVal(): ?String {
        _default
    }
}
