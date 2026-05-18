protected package jian.macros.type_anno

/**
 * cjlint-ignore -start !G.NAM.04 !G.FUN.02
 * TODO: add description
 */

/**
 * TODO: add comments
 * throws UnsupportedException
 */
public func Optional<T>(shortName!: ?Rune = None, longName!: ?String = None, help!: ?String = None): T {
    throw UnsupportedException(
        "Optional can appear only as an argument default value of function modified by the @Command or @Callback macro.")
}

// cjlint-ignore -end
