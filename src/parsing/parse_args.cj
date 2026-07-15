protected package jian.parsing

import std.collection.{ArrayList, HashMap}
import std.convert.Parsable

// === ArgSpec hierarchy ===

sealed abstract class ArgSpec {
    ArgSpec(public let name!: String, public let help!: ?String = None) {}
}

public class OptSpec <: ArgSpec {
    protected OptSpec(name!: String, help!: ?String = None,
            public let short!: ?Byte = None,
            public let long!: ?String = None,
            public let defaultValue!: ?String = None) {
        super(name: name, help: help)
    }

    public func hasDefault(): Bool {
        defaultValue.isSome()
    }
}

public class PosSpec <: ArgSpec {
    protected PosSpec(name!: String, help!: ?String = None,
            public let defaultValue!: ?String = None) {
        super(name: name, help: help)
    }

    public func hasDefault(): Bool {
        defaultValue.isSome()
    }
}

// === ParsedArgs ===

public struct ParsedArgs {
    ParsedArgs(private let store: HashMap<String, String>) {}

    public func getRaw(name: String): ?String {
        store.get(name)
    }

    public func get<T>(name: String): T where T <: Parsable<T> {
        let raw = store.get(name).getOrThrow()
        T.parse(raw)
    }

    public func getOr<T>(name: String, defaultValue: T): T where T <: Parsable<T> {
        store.get(name).map { raw => T.parse(raw) } ?? defaultValue
    }
}

// === Parser ===

protected func parseArgs(argv: Array<String>, specs: Array<ArgSpec>): ParsedArgs {
    let lexer = Lexer.make(argv)
    let store = HashMap<String, String>()
    let optsByLong = HashMap<String, OptSpec>()
    let optsByShort = HashMap<Byte, OptSpec>()
    let posSpecs = ArrayList<PosSpec>()

    for (spec in specs) {
        match (spec) {
            case opt: OptSpec =>
                if (let Some(l) <- opt.long) {
                    optsByLong[l] = opt
                }
                if (let Some(s) <- opt.short) {
                    optsByShort[s] = opt
                }
            case pos: PosSpec => posSpecs.add(pos)
            case _ => ()
        }
    }

    for (spec in specs) {
        match (spec) {
            case opt: OptSpec =>
                if (opt.hasDefault()) {
                    store[opt.name] = opt.defaultValue.getOrThrow()
                }
            case _ => ()
        }
    }

    var posIndex: Int64 = 0

    for (tok in lexer) {
        match (tok) {
            case Dashed(flag) =>
                let flagBytes = flag.toArray()
                if (flagBytes.size > 0) {
                    let opt = optsByShort.get(flagBytes[0])
                    if (let Some(o) <- opt) {
                        store[o.name] = "true"
                    }
                }
            case Dashed(flag, value) =>
                let flagBytes = flag.toArray()
                if (flagBytes.size > 0) {
                    let opt = optsByShort.get(flagBytes[0])
                    if (let Some(o) <- opt) {
                        store[o.name] = value
                    }
                }
            case DoubleDashed(flag) =>
                let opt = optsByLong.get(flag)
                if (let Some(o) <- opt) {
                    store[o.name] = "true"
                }
            case DoubleDashed(flag, value) =>
                let opt = optsByLong.get(flag)
                if (let Some(o) <- opt) {
                    store[o.name] = value
                }
            case Value(v) =>
                if (posIndex < posSpecs.size) {
                    let pos = posSpecs[posIndex]
                    store[pos.name] = v
                    posIndex = posIndex + 1
                }
            case StdinPlaceholder =>
                if (posIndex < posSpecs.size) {
                    let pos = posSpecs[posIndex]
                    store[pos.name] = "-"
                    posIndex = posIndex + 1
                }
            case Eoi => break
            case Dummy => ()
        }
    }

    for (i in posIndex..posSpecs.size) {
        let pos = posSpecs[i]
        if (store.get(pos.name).isNone() && pos.hasDefault()) {
            store[pos.name] = pos.defaultValue.getOrThrow()
        }
    }

    ParsedArgs(store)
}
