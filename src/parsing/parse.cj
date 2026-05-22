protected package jian.parsing

import std.collection.{ArrayList, HashMap, ReadOnlyMap, collectArray}

protected func parse(argv: Array<String>, specs: Array<ArgSpec>): ParsedArgs {
    throw Exception()
}

abstract sealed class ArgSpec {}

class OptSpec <: ArgSpec {}

class PosSpec <: ArgSpec {}

public struct ParsedArgs {}

