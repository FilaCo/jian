package jian.runtime

/** A command written by hand against the contract, the way `App` is tested before `@Command` exists. */
class ExitWithCommand <: Command {
    ExitWithCommand(private let code: Int64) {}

    public prop name: String {
        get() {
            "exit-with"
        }
    }

    public prop spec: CommandSpec {
        get() {
            CommandSpec(
                help: "Exits with the given code.",
                params: [
                    ParamSpec("dry-run", kind: Flag, short: r'n', help: "Do nothing."),
                    ParamSpec("code", kind: Positional, metavar: "INT", required: true)
                ]
            )
        }
    }

    public func run(_: ArgCursor): Int64 {
        code
    }
}

@Test
class CommandTest {
    @TestCase
    func aHandWrittenCommandRunsThroughTheInterface() {
        // arrange
        let sut: Command = ExitWithCommand(3)

        // act
        let actual = sut.run(ArgCursor([]))

        // assert
        @Expect(actual, 3)
    }

    @TestCase
    func aHandWrittenCommandDescribesItsParameters() {
        // arrange
        let sut: Command = ExitWithCommand(0)

        // act
        let params = sut.spec.params

        // assert
        @Expect(sut.name, "exit-with")
        @Expect(params.size, 2)
        @Expect(params[0].short, r'n')
        @Expect(params[0].kind, Flag)
        @Expect(params[1].required)
        @Expect(params[1].defaultShown.isNone())
    }
}
