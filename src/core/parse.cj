protected package jian.core

import std.argopt.{ArgumentMode, ArgumentSpec, ParsedArguments}
import std.collection.{ArrayList, HashMap, ReadOnlyMap, collectArray}

protected func parse(argv: Array<String>, specs: Array<ArgumentSpec>): ParsedArguments {
    let byShort = HashMap<Rune, ArgumentSpec>()
    let byLong = HashMap<String, ArgumentSpec>()
    warmupMappings(specs, byShort, byLong)

    let options = HashMap<String, String>()
    let nonOptions = ArrayList<String>()
    let lexer = Lexer.make(argv)
    let tokens = lexer |> collectArray
    var pos = 0
    while (pos < tokens.size) {
        tokens.get(pos).map {
            tok: Token => match (tok) {
                case StdinPlaceholder => throw UnsupportedException("stdin placeholder not supported yet")
                case Dashed(name) => throw Exception()
                case Dashed(name, value) => throw Exception()
                case DoubleDashed(name) => throw Exception()
                case DoubleDashed(name, value) => throw Exception()
                case Value(name) => throw Exception()
                case _ => throw IllegalStateException("unexpected token: ${tok}")
            }
        }
    }
    throw Exception()
}

private func warmupMappings(specs: Array<ArgumentSpec>, byShort: HashMap<Rune, ArgumentSpec>,
    byLong: HashMap<String, ArgumentSpec>) {
    for (spec in specs) {
        match (spec) {
            case Short(name, _) => byShort[name] = spec
            case Short(name, _, _) => byShort[name] = spec
            case Long(name, _) => byLong[name] = spec
            case Long(name, _, _) => byLong[name] = spec
            case Full(longName, shortName, _) =>
                byLong[longName] = spec
                byShort[shortName] = spec
            case Full(longName, shortName, _, _) =>
                byLong[longName] = spec
                byShort[shortName] = spec
            case NonOptions(_) => throw UnsupportedException("non options not supported yet")
        }
    }
}
