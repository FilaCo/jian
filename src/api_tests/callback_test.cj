package jian.api_tests

import jian.*
import std.io.ByteBuffer
import std.unittest.*
import std.unittest.testmacro.*

private var callbackEvents = ""
private var callbackDefaultCalls = 0
private let callbackPrefix = "private:"

private func callbackDefault(): String {
    callbackDefaultCalls++
    "default"
}

@Callback[help: "Global settings"]
func configure(verbose!: Bool, jobs!: ?Int64, paths!: Array<String>): Unit {
    callbackEvents += "callback:${verbose}:${jobs ?? -1}:${paths.size};"
}

@Command
func launch(verbose!: Bool): Int64 {
    callbackEvents += "command:${verbose};"
    7
}

@Callback
func configuredDefault(first!: String = callbackDefault(), second!: String = callbackPrefix + first): Int64 {
    callbackEvents = second
    0
}

@Callback
func callbackExit(code!: Int64): Int64 { code }

@Callback
func callbackPosition(workspace: String, count!: Int64 = 1): Unit {
    callbackEvents = "${workspace}:${count}"
}

@Callback
func `empty_callback`() { callbackEvents = "empty" }

@Test
class CallbackMacroTest {
    @TestCase
    func app_runs_typed_callback_before_command_and_keeps_command_options() {
        // arrange
        callbackEvents = ""
        let errors = ByteBuffer()
        let app = App(name: "demo", stderr: errors)
            .callback(ConfigureCallback()).add(LaunchCommand())

        // act
        let code = app.run(["--verbose", "--jobs", "3", "--paths=a", "--paths", "b", "launch", "--verbose"])

        // assert
        @Expect(code, 7)
        @Expect(callbackEvents, "callback:true:3:2;command:true;")
        @Expect(errors.bytes().size, 0)
        @Expect(ConfigureCallback().spec.help, "Global settings")
        @Expect(ConfigureCallback().spec.params[0].kind, ParamKind.Flag)
        @Expect(ConfigureCallback().spec.params[1].metavar, "INT")
        @Expect(ConfigureCallback().spec.params[2].repeatable, true)
    }

    @TestCase
    func options_after_command_do_not_change_callback_defaults() {
        // arrange
        callbackEvents = ""
        let app = App(name: "demo").callback(ConfigureCallback()).add(LaunchCommand())

        // act
        let code = app.run(["launch", "--verbose"])

        // assert
        @Expect(code, 7)
        @Expect(callbackEvents, "callback:false:-1:0;command:true;")
    }

    @TestCase
    func callback_only_options_are_rejected_after_the_command() {
        // arrange
        callbackEvents = ""
        let errors = ByteBuffer()
        let app = App(name: "demo", stderr: errors).callback(ConfigureCallback()).add(LaunchCommand())

        // act
        let code = app.run(["launch", "--jobs=4"])

        // assert
        @Expect(code, 2)
        @Expect(callbackEvents, "callback:false:-1:0;")
        @Expect(String.fromUtf8(errors.bytes()).contains("unknown option '--jobs'"), true)
    }

    @TestCase
    func defaults_remain_lazy_and_keep_private_and_earlier_parameter_names() {
        // arrange
        callbackDefaultCalls = 0
        let callback = ConfiguredDefaultCallback()

        // act
        let metadata = callback.spec
        let explicit = callback.run(ArgCursor(["--first=given"]))

        // assert
        @Expect(metadata.params[0].defaultShown.isSome(), true)
        @Expect(callbackDefaultCalls, 0)
        @Expect(explicit, 0)
        @Expect(callbackEvents, "private:given")
        @Expect(callback.run(ArgCursor([])), 0)
        @Expect(callbackDefaultCalls, 1)
        @Expect(callbackEvents, "private:default")
    }

    @TestCase
    func nonzero_callback_result_prevents_command_dispatch() {
        // arrange
        callbackEvents = ""
        let app = App(name: "demo").callback(CallbackExitCallback()).add(LaunchCommand())

        // act
        let code = app.run(["--code=9", "launch"])

        // assert
        @Expect(code, 9)
        @Expect(callbackEvents, "")
    }

    @TestCase
    func positional_callback_parameters_leave_the_next_operand_for_dispatch() {
        // arrange
        let args = ArgCursor(["project", "--count=2", "launch", "--verbose"])

        // act
        let code = CallbackPositionCallback().run(args)

        // assert
        @Expect(code, 0)
        @Expect(callbackEvents, "project:2")
        @Expect(args.next(), Some(Arg.Operand("launch")))
        @Expect(args.next(), Some(Arg.Long("verbose")))
    }

    @TestCase
    func empty_callback_leaves_command_and_end_of_options_marker_intact() {
        // arrange
        let args = ArgCursor(["--", "launch", "--verbose"])

        // act
        let code = Empty_callbackCallback().run(args)

        // assert
        @Expect(code, 0)
        @Expect(callbackEvents, "empty")
        @Expect(args.remaining(), ["--", "launch", "--verbose"])
        @Expect(App(name: "demo").callback(Empty_callbackCallback()).run([]), 0)
    }

    @TestCase
    func malformed_callback_options_report_the_same_typed_errors_as_commands() {
        // arrange
        let callback = CallbackExitCallback()

        // act
        let missing = @AssertThrows[UsageException](callback.run(ArgCursor([])))
        let invalid = @AssertThrows[UsageException](callback.run(ArgCursor(["--code=bad"])))
        let unknown = @AssertThrows[UsageException](callback.run(ArgCursor(["--other"])))
        let missingValue = @AssertThrows[UsageException](callback.run(ArgCursor(["--code"])))

        // assert
        @Expect(missing.message, "missing argument '--code'")
        @Expect(invalid.message, "invalid value 'bad' for '--code': expected Int64")
        @Expect(unknown.message, "unknown option '--other'")
        @Expect(missingValue.message, "missing argument '--code'")
    }
}
