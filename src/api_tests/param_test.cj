package jian.api_tests

import jian.*
import std.deriving.*
import std.unittest.*
import std.unittest.testmacro.*

@Derive[Equatable]
private struct ParamResult {
    ParamResult(let verbose: Bool, let quiet: Bool, let times: Int64) {}
}

private var paramResult = ParamResult(false, false, 0)

@Command
func paramOptions(@Param[short: 'v', help: "Verbose output"] verbose!: Bool,
    @Param[short: 'q', hidden: true] quiet!: Bool,
    @Param[short: 't', help: "Repetitions"] times!: Int64 = 1): Int64 {
    paramResult = ParamResult(verbose, quiet, times)
    times
}

@Command
func paramOperand(@Param[help: "Input path", hidden: true] path: String): Int64 { path.size }

@Command
func paramDefault(@Param count!: Int64 = 2): Int64 { count }

@Test
class ParamMacroTest {
    @TestCase
    func carries_parameter_metadata_in_declaration_order() {
        // arrange
        let command = ParamOptionsCommand()

        // act
        let params = command.spec.params

        // assert
        @Expect(params[0].short, Some(b'v'))
        @Expect(params[0].help, "Verbose output")
        @Expect(params[0].hidden, false)
        @Expect(params[1].short, Some(b'q'))
        @Expect(params[1].hidden, true)
        @Expect(params[2].short, Some(b't'))
        @Expect(params[2].help, "Repetitions")
        @Expect(ParamOperandCommand().spec.params[0].help, "Input path")
        @Expect(ParamOperandCommand().spec.params[0].hidden, true)
        @Expect(ParamDefaultCommand().run(ArgCursor([])), 2)
        @Expect(ParamDefaultCommand().spec.params[0].short, None)
    }

    @TestCase
    func parses_flags_and_attached_values_from_short_clusters() {
        // arrange
        let app = App(name: "test").add(ParamOptionsCommand())

        // act
        let code = app.run(["param-options", "-vqt3"])

        // assert
        @Expect(code, 3)
        @Expect(paramResult, ParamResult(true, true, 3))
        @Expect(app.run(["param-options", "-t=4", "-v"]), 4)
        @Expect(paramResult, ParamResult(true, false, 4))
        @Expect(app.run(["param-options", "-t", "5", "--quiet"]), 5)
        @Expect(paramResult, ParamResult(false, true, 5))
    }
}
