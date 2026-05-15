protected package jian.api

import jian.api.exceptions.InvalidTypeAnnotationUsageException

/**
 * cjlint-ignore -start !G.NAM.04 !G.FUN.02
 * TODO: add description
 */

/**
 * TODO: add comments
 * throws InvalidTypeAnnotationUsageException
 */
public func Positional<T>(help!: ?String = None): T {
    throw InvalidTypeAnnotationUsageException("Positional")
}

// cjlint-ignore -end
