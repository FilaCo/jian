package jian.parsing

import std.collection.{ArrayList, HashMap}
import std.convert.Parsable

// === ArgSpec hierarchy ===

sealed abstract class ArgSpec {
    ArgSpec(public let name!: String, public let help!: ?String = None) {}
}

public class OptSpec <: ArgSpec {
    OptSpec(name!: String, help!: ?String = None,
            public let short!: ?Byte = None,
            public let long!: ?String = None,
            public let defaultValue!: ?String = None) {
        super(name: name, help: help)
    }

    public func hasDefault(): Bool {
        defaultValue.isSome()
    }
}

public func newOptSpec(name: String, help: ?String, short: ?Byte, long: ?String, defaultValue: ?String): OptSpec {
    OptSpec(name: name, help: help, short: short, long: long, defaultValue: defaultValue)
}

public class PosSpec <: ArgSpec {
    PosSpec(name!: String, help!: ?String = None,
            public let defaultValue!: ?String = None) {
        super(name: name, help: help)
    }

    public func hasDefault(): Bool {
        defaultValue.isSome()
    }
}

public func newPosSpec(name: String, help: ?String, defaultValue: ?String): PosSpec {
    PosSpec(name: name, help: help, defaultValue: defaultValue)
}

// === ParsedArgs ===

public struct ParsedArgs {
    private let store: HashMap<String, String>

    init(store: HashMap<String, String>) {
        this.store = store
    }

    public func getRaw(name: String): ?String {
        store.get(name)
    }

    public func get<T>(name: String): T where T <: Parsable<T> {
        let raw = store.get(name).getOrThrow()
        T.parse(raw)
    }

    public func getOr<T>(name: String, defaultVal: T): T where T <: Parsable<T> {
        store.get(name).map { raw => T.parse(raw) } ?? defaultVal
    }
}

// === Parser ===

protected func parseArgs(argv: Array<String>, specs: Array<ArgSpec>): ParsedArgs {
    let lexer = Lexer.make(argv)
    let store = HashMap<String, String>()
    let optsByLong = HashMap<String, OptSpec>()
    let optsByShort = HashMap<Byte, OptSpec>()
    let posSpecs = ArrayList<PosSpec>()

    // --- Build lookup structures ---
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

    // --- Apply defaults for options ---
    for (spec in specs) {
        match (spec) {
            case opt: OptSpec =>
                if (opt.hasDefault()) {
                    store[opt.name] = opt.defaultValue.getOrThrow()
                }
            case _ => ()
        }
    }

    // --- Parse tokens ---
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

    // --- Apply defaults for positionals not set ---
    for (i in posIndex..posSpecs.size) {
        let pos = posSpecs[i]
        if (store.get(pos.name).isNone() && pos.hasDefault()) {
            store[pos.name] = pos.defaultValue.getOrThrow()
        }
    }

    ParsedArgs(store)
}
