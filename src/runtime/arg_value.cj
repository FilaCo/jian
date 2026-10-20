package jian.runtime

import std.convert.Parsable

/** Per-type CLI behavior, resolved statically even through type aliases. */
public interface ArgValue<T> {
    /** Whether an occurrence consumes a value; false for flags. */
    static func takesValue(): Bool

    /** Help placeholder, such as `INT`, `TEXT`, or `INT...`; empty for flags. */
    static func metavar(): String

    /**
     * Accepts one occurrence, appending for arrays and replacing other values.
     * `prev` is the accumulated value; `raw = None` denotes a bare flag.
     * Throws InvalidValueException for invalid input, UsageException for a missing value.
     */
    static func accept(prev: ?T, raw: ?String): T

    /** Value when omitted; outer `None` means the parameter is required. */
    static func whenAbsent(): ?T
}

/** Accepts one occurrence using T's CLI behavior; preserves its exceptions. */
public func acceptAs<T>(prev: ?T, raw: ?String): T where T <: ArgValue<T> {
    T.accept(prev, raw)
}

/** @throws UsageException if the occurrence has no value. */
func requiredValue(raw: ?String): String {
    raw ?? throw UsageException("missing argument value")
}

/** @throws InvalidValueException if parsing fails. */
func parseValue<T>(raw: ?String, expected: String): T where T <: Parsable<T> {
    let text = requiredValue(raw)
    try {
        T.tryParse(text) ?? throw InvalidValueException(text, expected)
    } catch (_: IllegalArgumentException) {
        // SDK parsers can also reject malformed UTF-8 by throwing.
        throw InvalidValueException(text, expected)
    }
}
