package jian.builders

import std.collection.ArrayList
import jian.parsing.ParsedArgs

/**
 * cjlint-ignore -start !G.OPR.01
 * TODO: add description
 */

/**
 *
 */
public struct Cmd {
    Cmd(private let _params: Array<Param>, private let _invoke: (ParsedArgs) -> Unit) {}

    public static func builder(name: String): CmdBuilder {
        CmdBuilder(name)
    }

    public operator func ()(args: ParsedArgs): Unit {
        _invoke(args)
    }
}

public class CmdBuilder {
    private let params = ArrayList<Param>()
    CmdBuilder(private var _name: String) {}

    public func build(): Cmd {
        throw UnsupportedException()
    }

    public func name(name: String): This {
        _name = name
        this
    }

    public func getName(): String {
        _name
    }
}

// cjlint-ignore -end
