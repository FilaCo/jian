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

@JianCallback[help: "Global settings"]
func configure(verbose!: Bool = false, jobs!: ?Int64, paths!: Array<String> = []): JianCallbackResult {
    callbackEvents += "callback:${verbose}:${jobs ?? -1}:${paths.size};"
    JianCallbackResult.Continue
}

@JianCommand
func launch(verbose!: Bool = false): Int64 {
    callbackEvents += "command:${verbose};"
    7
}

@JianCallback
func configuredDefault(first!: String = callbackDefault(), second!: String = callbackPrefix + first): JianCallbackResult {
    callbackEvents = second
    JianCallbackResult.Continue
}

@JianCallback
func callbackExit(code!: Int64): JianCallbackResult { JianCallbackResult.Exit(code) }

@JianCallback
func callbackFailure(): JianCallbackResult { throw IllegalStateException("callback failed") }

@JianCallback
func inferredCallback(complete!: Bool = false) {
    if (complete) { JianCallbackResult.Exit(0) } else { JianCallbackResult.Continue }
}

@JianCallback
func callbackPosition(workspace: String, count!: Int64 = 1): JianCallbackResult {
    callbackEvents = "${workspace}:${count}"
    JianCallbackResult.Continue
}

@JianCallback
func `empty_callback`(): JianCallbackResult { callbackEvents = "empty"; JianCallbackResult.Continue }

@Test
class CallbackMacroTest {
    @TestCase
    func inferredResultSupportsDirectCallsAndTypedRegistration() {
        // arrange
        let app = JianApp().callback(inferredCallback).add(launch)
        let action: (Bool) -> JianCallbackResult = inferredCallback

        // act
        let continued = app.run(["launch"])
        let completed = app.run(["--complete"])

        // assert
        @Expect(continued, 7)
        @Expect(completed, 0)
        @Expect(inferredCallback(), JianCallbackResult.Continue)
        @Expect(action(true), JianCallbackResult.Exit(0))
    }

    @TestCase
    func appRunsTypedCallbackBeforeCommandAndKeepsCommandOptions() {
        // arrange
        callbackEvents = ""
        let errors = ByteBuffer()
        let app = JianApp(name: "demo", stderr: errors)
            .callback(configure).add(launch)

        // act
        let code = app.run(["--verbose", "--jobs", "3", "--paths=a", "--paths", "b", "launch", "--verbose"])

        // assert
        @Expect(code, 7)
        @Expect(callbackEvents, "callback:true:3:2;command:true;")
        @Expect(errors.bytes().size, 0)
        @Expect(ConfigureCallback().spec.help, "Global settings")
        @Expect(ConfigureCallback().spec.inputs[0].kind, JianInputKind.Flag)
        @Expect(ConfigureCallback().spec.inputs[1].metavar, "INT")
        @Expect(ConfigureCallback().spec.inputs[2].repeatable, true)
    }

    @TestCase
    func optionsAfterCommandDoNotChangeCallbackDefaults() {
        // arrange
        callbackEvents = ""
        let app = JianApp(name: "demo").callback(configure).add(launch)

        // act
        let code = app.run(["launch", "--verbose"])

        // assert
        @Expect(code, 7)
        @Expect(callbackEvents, "callback:false:-1:0;command:true;")
    }

    @TestCase
    func callbackOnlyOptionsAreRejectedAfterTheCommand() {
        // arrange
        callbackEvents = ""
        let errors = ByteBuffer()
        let app = JianApp(name: "demo", stderr: errors).callback(configure).add(launch)

        // act
        let code = app.run(["launch", "--jobs=4"])

        // assert
        @Expect(code, 2)
        @Expect(callbackEvents, "callback:false:-1:0;")
        @Expect(String.fromUtf8(errors.bytes()).contains("unknown option '--jobs'"), true)
    }

    @TestCase
    func defaultsRemainLazyAndKeepPrivateAndEarlierParameterNames() {
        // arrange
        callbackDefaultCalls = 0
        let callback = ConfiguredDefaultCallback()

        // act
        let metadata = callback.spec
        let explicit = callback.run(JianArgCursor(["--first=given"]))

        // assert
        @Expect(metadata.inputs[0].defaultShown.isSome(), true)
        @Expect(callbackDefaultCalls, 0)
        @Expect(explicit, JianCallbackResult.Continue)
        @Expect(callbackEvents, "private:given")
        @Expect(callback.run(JianArgCursor([])), JianCallbackResult.Continue)
        @Expect(callbackDefaultCalls, 1)
        @Expect(callbackEvents, "private:default")
    }

    @TestCase[exitCode in [0, 9]]
    func explicitCallbackExitPreventsCommandDispatch(exitCode: Int64) {
        // arrange
        callbackEvents = ""
        let app = JianApp(name: "demo").callback(callbackExit).add(launch)

        // act
        let code = app.run(["--code=${exitCode}", "launch"])

        // assert
        @Expect(code, exitCode)
        @Expect(callbackEvents, "")
    }

    @TestCase
    func successfulCallbackExitDoesNotRequireASubcommand() {
        // arrange
        let errors = ByteBuffer()
        let app = JianApp(name: "demo", stderr: errors).callback(callbackExit).add(launch)

        // act
        let code = app.run(["--code=0"])

        // assert
        @Expect(code, 0)
        @Expect(errors.bytes().isEmpty(), true)
        @Expect(callbackExit(code: 0), JianCallbackResult.Exit(0))
    }

    @TestCase
    func callbackExceptionsPropagateWithoutBecomingUsageErrors() {
        // arrange
        let errors = ByteBuffer()
        let app = JianApp(name: "demo", stderr: errors).callback(callbackFailure).add(launch)

        // act
        let error = @AssertThrows[IllegalStateException](app.run(["launch"]))

        // assert
        @Expect(error.message, "callback failed")
        @Expect(errors.bytes().isEmpty(), true)
    }

    @TestCase
    func positionalCallbackArgumentsLeaveTheNextOperandForDispatch() {
        // arrange
        let args = JianArgCursor(["project", "--count=2", "launch", "--verbose"])

        // act
        let code = CallbackPositionCallback().run(args)

        // assert
        @Expect(code, JianCallbackResult.Continue)
        @Expect(callbackEvents, "project:2")
        @Expect(args.next(), Some(JianArg.Operand("launch")))
        @Expect(args.next(), Some(JianArg.Long("verbose")))
    }

    @TestCase
    func emptyCallbackLeavesCommandAndEndOfOptionsMarkerIntact() {
        // arrange
        let args = JianArgCursor(["--", "launch", "--verbose"])

        // act
        let code = Empty_callbackCallback().run(args)

        // assert
        @Expect(code, JianCallbackResult.Continue)
        @Expect(callbackEvents, "empty")
        @Expect(args.remaining(), ["--", "launch", "--verbose"])
        @Expect(JianApp(name: "demo").callback(`empty_callback`).run([]), 0)
    }

    @TestCase
    func malformedCallbackOptionsReportTheSameTypedErrorsAsCommands() {
        // arrange
        let callback = CallbackExitCallback()

        // act
        let missing = @AssertThrows[JianUsageException](callback.run(JianArgCursor([])))
        let invalid = @AssertThrows[JianUsageException](callback.run(JianArgCursor(["--code=bad"])))
        let unknown = @AssertThrows[JianUsageException](callback.run(JianArgCursor(["--other"])))
        let missingValue = @AssertThrows[JianUsageException](callback.run(JianArgCursor(["--code"])))

        // assert
        @Expect(missing.message, "missing argument '--code'")
        @Expect(invalid.message, "invalid value 'bad' for '--code': expected Int64")
        @Expect(unknown.message, "unknown option '--other'")
        @Expect(missingValue.message, "missing argument '--code'")
    }
}
