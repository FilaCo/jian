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
public func Optional<T>(shortName!: ?Rune = None, longName!: ?String = None, help!: ?String = None): T {
    throw InvalidTypeAnnotationUsageException("Optional")
}

// cjlint-ignore -end
