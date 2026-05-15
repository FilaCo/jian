protected package jian.core

sealed abstract class ArgumentSpec {
    ArgumentSpec(let help!: ?String = None) {}
}

class PositionalSpec <: ArgumentSpec {
    PositionalSpec(help!: ?String = None) {
        super(help: help)
    }
}

class OptionalSpec <: ArgumentSpec  {
    OptionalSpec(help!: ?String = None, let shortName!: ?Rune = None, let longName!: ?String = None) {
        super(help: help)
    }
}
