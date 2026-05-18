package jian.builder

import std.argopt.{ArgumentSpec, ParsedArguments}

/**
 * cjlint-ignore -start !G.OPR.01
 * TODO: add description
 */

/**
 *
 */
public struct Callback {
    Callback(protected let argSpecs: Array<ArgumentSpec>, private let _flags: CallbackFlags,
        private let _invoke: (ParsedArguments) -> Unit) {}

    protected prop invokeWithoutCommand: Bool {
        get() {
            _flags.invokeWithoutCommand
        }
    }

    protected operator func ()(args: ParsedArguments): Unit {
        _invoke(args)
    }
}

public class CallbackBuilder {}

struct CallbackFlags {
    protected static const INVOKE_WITHOUT_COMMAND_MASK: UInt8 = 1 << 0

    CallbackFlags(private let _packed: UInt8) {}

    prop invokeWithoutCommand: Bool {
        get() {
            (_packed & INVOKE_WITHOUT_COMMAND_MASK) > 0
        }
    }
}

class CallbackFlagsBuilder {
    private var _packed: UInt8 = 0

    func build(): CallbackFlags {
        CallbackFlags(_packed)
    }

    func withInvokeWithoutCommand(): This {
        _packed |= CallbackFlags.INVOKE_WITHOUT_COMMAND_MASK

        this
    }
}

// cjlint-ignore -end
