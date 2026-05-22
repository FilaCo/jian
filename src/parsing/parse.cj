protected package jian.parsing

import std.collection.{ArrayList, HashMap, ReadOnlyMap, collectArray}

protected func parse(argv: Array<String>, specs: Array<ArgSpec>): ParsedArgs {
    throw Exception()
}

sealed abstract class ArgSpec {}

class OptSpec <: ArgSpec {}

class PosSpec <: ArgSpec {}

public struct ParsedArgs {
    public func get(name: String): ?String {
        None
    }

    public func get<T>(name: String, _overloadMarker!: ?T = None): ?T where T <: JianParsable<T> {
        None
    }

    public func get<T>(name: String, parser: (String) -> T): ?T {
        None
    }
}

public interface JianParsable<T> {
    static func parse(value: String): T
}
