package jian.runtime

import std.env.{getStdErr, getStdOut}
import std.io.OutputStream

/**
 * The effective output streams of one invocation, shared by handlers, help and usage errors.
 * Streams belong to the caller; Jian never closes them or retains per-run overrides.
 */
public struct JianOutput {
    public let stdout: OutputStream
    public let stderr: OutputStream

    /** Creates explicit output for direct function or adapter calls; defaults to process streams. */
    public init(stdout!: OutputStream = getStdOut(), stderr!: OutputStream = getStdErr()) {
        this.stdout = stdout
        this.stderr = stderr
    }
}

/**
 * Injects effective streams into a named JianOutput parameter of @JianCommand or @JianCallback.
 * Creates no CLI input. Direct function callers must supply JianOutput explicitly.
 * Throws IllegalArgumentException if evaluated outside macro processing.
 */
public func JianCurrentOutput(): JianOutput {
    throw IllegalArgumentException("JianCurrentOutput must be a function parameter default in @JianCommand or @JianCallback")
}
