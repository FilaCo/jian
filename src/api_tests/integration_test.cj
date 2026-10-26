package jian.api_tests

import jian.*
import std.io.ByteBuffer
import std.unittest.*
import std.unittest.testmacro.*

private var integrationEvents = ""

@Callback[help: "Workspace options"]
func integrationGlobal(@Param[short: 'v', help: "Verbose workspace"] verbose!: Bool,
    @Param[short: 'j'] jobs!: Int64 = 1,
    @Param[short: 'p', hidden: true] paths!: Array<String>): Unit {
    integrationEvents += "global:${verbose}:${jobs}:${paths};"
}

@Command[help: "Process input paths"]
func integrationFiles(@Param[help: "Input paths"] paths: Array<String>,
    @Param[short: 'v'] verbose!: Bool, @Param[short: 't'] times!: Int64 = 1): Int64 {
    integrationEvents += "files:${paths}:${verbose}:${times};"
    paths.size * times
}

@Callback
func integrationArguments(@Param[help: "Arguments"] values: Array<String>): Unit {
    integrationEvents = values.toString()
}

@Test
class MacroIntegrationTest {
    @TestCase
    func short_tables_switch_at_command_boundary_and_variadic_operands_accumulate() {
        // arrange
        integrationEvents = ""
        let errors = ByteBuffer()
        let app = App(name: "test", stderr: errors)
            .callback(IntegrationGlobalCallback()).add(IntegrationFilesCommand())

        // act
        let code = app.run(["-vj3", "-pa", "-p", "b", "integration-files", "first", "-vt2", "second"])

        // assert
        @Expect(code, 4)
        @Expect(integrationEvents, "global:true:3:[a, b];files:[first, second]:true:2;")
        @Expect(errors.bytes().size, 0)
        @Expect(IntegrationGlobalCallback().spec.params[0].short, Some(b'v'))
        @Expect(IntegrationGlobalCallback().spec.params[0].help, "Verbose workspace")
        @Expect(IntegrationGlobalCallback().spec.params[2].hidden, true)
        @Expect(IntegrationFilesCommand().spec.params[0].repeatable, true)
        @Expect(IntegrationFilesCommand().spec.params[0].help, "Input paths")
    }

    @TestCase
    func callback_variadic_collects_all_operands_when_used_without_subcommands() {
        // arrange
        let app = App(name: "test").callback(IntegrationArgumentsCallback())

        // act
        let code = app.run(["first", "second", "--", "-third"])

        // assert
        @Expect(code, 0)
        @Expect(integrationEvents, "[first, second, -third]")
    }

    @TestCase
    func callback_short_value_can_equal_a_subcommand_name() {
        // arrange
        integrationEvents = ""
        let app = App(name: "test").callback(IntegrationGlobalCallback()).add(IntegrationFilesCommand())

        // act
        let code = app.run(["-p", "integration-files", "integration-files", "input"])

        // assert
        @Expect(code, 1)
        @Expect(integrationEvents, "global:false:1:[integration-files];files:[input]:false:1;")
    }
}
