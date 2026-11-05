package jian.runtime

import std.env.{getStdErr, getStdOut}
import std.io.OutputStream

/**
 * Borrowed output streams for one invocation, shared with help and usage errors.
 * Jian never closes these streams. Handlers choose what to write and when to flush.
 */
public struct JianOutput {
    public JianOutput(public let stdout!: OutputStream = getStdOut(),
        public let stderr!: OutputStream = getStdErr()) {}
}

/**
 * Injects effective invocation streams into a named JianOutput parameter of
 * @JianCommand or @JianCallback, without creating a CLI input.
 * Direct callers must supply JianOutput explicitly.
 * Throws IllegalArgumentException if evaluated outside macro processing.
 */
public func JianCurrentOutput(): JianOutput {
    throw IllegalArgumentException("JianCurrentOutput must be a function parameter default in @JianCommand or @JianCallback")
}
