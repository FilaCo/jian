package jian.tests

import jian.builders.Pos
import jian.builders.Callback as JianCallback
import jian.builders.Command
import jian.builders.Param
import jian.builders.Invokable
import jian.builders.InvokableBuilder
import jian.macros.Command
import jian.macros.Callback

@Test
class MacroE2ETest {
    @TestCase
    func commandMacroGeneratesCmdFunction() {
        let cmd = no_defaults_cmd()
        @Expect(cmd.name, "no_defaults")
    }

    @TestCase
    func commandMacroBuildsParams() {
        let cmd = greet_cmd()
        @Expect(cmd.params.size, 2)
        @Expect(cmd.params[0].name, "name")
        @Expect(cmd.params[1].name, "greeting")
    }

    @TestCase
    func commandMacroParamsArePositional() {
        let cmd = greet_cmd()
        @Expect(cmd.params[0] is Pos)
        @Expect(cmd.params[1] is Pos)
    }

    @TestCase
    func callbackMacroGeneratesInvokable() {
        let cb = run_cb()
        @Expect(cb is JianCallback)
    }
}

@Command
func no_defaults(name: String) {
    println("Hello, ${name}!")
}

@Command
func greet(name: String, greeting: String) {
    println("Hello, ${name}, ${greeting}!")
}

@Callback
func run(name: String) {
    println("Hello, ${name}!")
}