protected package jian.parsing

import std.collection.{ArrayList, HashMap, ReadOnlyMap, collectArray}
import std.convert.Parsable

protected func parseArgs(argv: Array<String>, specs: Array<ArgSpec>): ParsedArgs {
    throw Exception()
}

sealed abstract class ArgSpec {}

protected class OptSpec <: ArgSpec {}

protected class PosSpec <: ArgSpec {}

public struct ParsedArgs {
    public func get(name: String): ?String {
        None
    }
}

public interface JianParsable<T> {
    static func parse(value: String): T
}
