protected package jian.api

import std.convert.Parsable
import jian.api.exceptions.InvalidTypeAnnotationUsageException

/**
 * cjlint-ignore -start !G.NAM.04 !G.FUN.02
 * TODO: add description
 */

/**
 * TODO: add comments
 * throws InvalidTypeAnnotationUsageException
 */
public func Positional<T>(default!: ?T = None, help!: ?String = None): T where T <: Parsable<T> {
    throw InvalidTypeAnnotationUsageException("Positional")
}

// cjlint-ignore -end
