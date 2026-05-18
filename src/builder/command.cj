package jian.builder

import std.argopt.{ArgumentSpec, ParsedArguments}

/**
 * cjlint-ignore -start !G.OPR.01
 * TODO: add description
 */

/**
 *
 */
public struct Command {
    Command(protected let argSpecs: Array<ArgumentSpec>, private let _invoke: (ParsedArguments) -> Unit) {}

    protected operator func ()(args: ParsedArguments): Unit {
        _invoke(args)
    }
}

public class CommandBuilder {}

// cjlint-ignore -end
