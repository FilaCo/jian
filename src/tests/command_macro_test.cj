/** Tests of the macros, from a package that uses them the way users do. */
package jian.tests

import jian.*

@Command
func greet(name: String): String {
    "Hello, ${name}!"
}

@Command[help: "Greet loudly."]
func shout(name: String): String {
    "HELLO, ${name}!"
}

@Callback
func verbosity(level: Int64): Int64 {
    level
}

/** The runtime `Command` and the macro `@Command` under one `import jian.*`. */
class ShoutCommand <: Command {
    public prop name: String {
        get() {
            "shout"
        }
    }

    public prop spec: CommandSpec {
        get() {
            CommandSpec(help: "Greet loudly.")
        }
    }

    public func run(_: ArgCursor): Int64 {
        println(shout("jian"))
        0
    }
}

@Test
class CommandMacroTest {
    @TestCase
    func theCommandStubLeavesTheFunctionCallable() {
        // act
        let actual = greet("jian")

        // assert
        @Expect(actual, "Hello, jian!")
    }

    @TestCase
    func theCommandStubTakesAttributes() {
        // act
        let actual = shout("jian")

        // assert
        @Expect(actual, "HELLO, jian!")
    }

    @TestCase
    func theCommandInterfaceAndMacroShareOneImport() {
        // arrange
        let sut: Command = ShoutCommand()

        // act
        let actual = sut.run(ArgCursor([]))

        // assert
        @Expect(actual, 0)
        @Expect(sut.spec.help, "Greet loudly.")
    }

    @TestCase
    func theCallbackStubLeavesTheFunctionCallable() {
        // act
        let actual = verbosity(2)

        // assert
        @Expect(actual, 2)
    }

    @TestCase
    func oneImportBringsTheRuntimeToo() {
        // act
        let spec = CommandSpec(help: "Greet someone.")

        // assert
        @Expect(spec.help, "Greet someone.")
    }
}
