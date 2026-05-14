protected package jian.core

import std.convert.Parsable

sealed abstract class Argument<T> where T <: Parsable<T> {
    Argument(let default!: ?T = None, let help!: ?String = None) {}
}

class Positional<T> <: Argument<T> where T <: Parsable<T> {}

class Optional<T> <: Argument<T> where T <: Parsable<T> {
    Optional(default!: ?T = None, help!: ?String = None, let shortName!: ?Rune = None, let longName!: ?String = None) {
        super(default: default, help: help)
    }
}
