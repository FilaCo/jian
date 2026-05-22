package jian.builders

sealed abstract class Param {
    protected Param() {}

    public static func builder(name: String): ParamBuilder {
        ParamBuilder(name)
    }
}

class Opt <: Param {}

class Pos <: Param {}

public class ParamBuilder {
    private var _short = None<Rune>
    private var _long = None<String>

    ParamBuilder(private var _name: String) {}

    public func build(): Param {
        throw Exception()
    }

    public func name(name: String): This {
        _name = name
        this
    }

    public func short(short: Rune): This {
        _short = short
        this
    }

    public func long(long: String): This {
        _long = long
        this
    }
}
