protected package jian.core

import std.argopt.{ArgumentMode, ArgumentSpec}
import std.collection.{ArrayList, HashMap, ReadOnlyMap}

// protected func jianParseArguments(argv: Array<String>, specs: Array<ArgumentSpec>): JianParsedArguments {
//     Parser().parse(argv, specs)
// }

// struct Parser {
//     private let _byShort = HashMap<Rune, ArgumentSpec>()
//     private let _byLong = HashMap<String, ArgumentSpec>()

//     func parse(argv: Array<String>, specs: Array<ArgumentSpec>): JianParsedArguments {
//         warmupMappings(specs)
//         let options = HashMap<String, String>()
//         let nonOptions = ArrayList<String>()
//         var pos = 0
//         while (pos < argv.size) {
//             // match (argv[pos]) {
//             //     case "--" =>
//             //         nonOptions.add(all: argv[pos..argv.size])
//             //         return JianParsedArguments(options, nonOptions.toArray())

//             //     case "-" => throw UnsupportedException("stdin placeholder not supported yet")

//             //     case s where s.startsWith("--") =>
//             //         let name = s.removePrefix("--")
//             //         match (_byLong.get(name)) {
//             //             case Some(spec) => 
//             //                 let mode = spec.mode.getOrThrow() // ArgumentSpec.Long always has mode
//             //                 match(mode) {
//             //                     case RequiredValue
//             //                 }
//             //             case _ => nonOptions.add(s)
//             //         }

//             //     case s where s.startsWith("-") => shortOption()

//             //     case s => nonOption()
//             // }
//             pos++
//         }
//         JianParsedArguments(options, nonOptions.toArray())
//     }

//     private func longOption(s: String) {}

//     private func shortOption() {}

//     private func nonOption() {}

//     private func warmupMappings(specs: Array<ArgumentSpec>) {
//         for (spec in specs) {
//             match (spec) {
//                 case Short(name, _) => _byShort[name] = spec
//                 case Short(name, _, _) => _byShort[name] = spec
//                 case Long(name, _) => _byLong[name] = spec
//                 case Long(name, _, _) => _byLong[name] = spec
//                 case Full(longName, shortName, _) =>
//                     _byLong[longName] = spec
//                     _byShort[shortName] = spec
//                 case Full(longName, shortName, _, _) =>
//                     _byLong[longName] = spec
//                     _byShort[shortName] = spec
//                 case NonOptions(_) => throw UnsupportedException("non options not supported yet")
//             }
//         }
//     }
// }

// public struct JianParsedArguments {
//     JianParsedArguments(private let _options: HashMap<String, String>, private let _nonOptions: Array<String>) {}
// }

// extend ArgumentSpec {
//     prop mode: ?ArgumentMode {
//         get() {
//             match (this) {
//                 case Short(_, m) => m
//                 case Short(_, m, _) => m
//                 case Long(_, m) => m
//                 case Long(_, m, _) => m
//                 case Full(_, _, m) => m
//                 case Full(_, _, m, _) => m
//                 case NonOptions(_) => None
//             }
//         }
//     }
// }


