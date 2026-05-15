protected package jian.core

sealed abstract class CallableSpec {
    CallableSpec(let help: String, protected let argSpecs: Array<ArgumentSpec>,
        protected let invoke: (ArgumentMatches) -> Unit) {}
}

public class CallbackSpec <: CallableSpec {
    CallbackSpec(help: String, argSpecs: Array<ArgumentSpec>, invoke: (ArgumentMatches) -> Unit) {
        super(help, argSpecs, invoke)
    }
}

public class CommandSpec <: CallableSpec {
    CommandSpec(help: String, argSpecs: Array<ArgumentSpec>, invoke: (ArgumentMatches) -> Unit, let name: String) {
        super(help, argSpecs, invoke)
    }
}
