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
func configure(verbose!: Bool = false, jobs!: ?Int64, paths!: Array<String> = []): Unit {
    callbackEvents += "callback:${verbose}:${jobs ?? -1}:${paths.size};"
}

@JianCommand
func launch(verbose!: Bool = false): Int64 {
    callbackEvents += "command:${verbose};"
    7
}

@JianCallback
func configuredDefault(first!: String = callbackDefault(), second!: String = callbackPrefix + first): Int64 {
    callbackEvents = second
    0
}

@JianCallback
func callbackExit(code!: Int64): Int64 { code }

@JianCallback
func callbackPosition(workspace: String, count!: Int64 = 1): Unit {
    callbackEvents = "${workspace}:${count}"
}

@JianCallback
func `empty_callback`() { callbackEvents = "empty" }

@Test
class CallbackMacroTest {
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
        @Expect(configure.spec.help, "Global settings")
        @Expect(configure.spec.inputs[0].kind, JianInputKind.Flag)
        @Expect(configure.spec.inputs[1].metavar, "INT")
        @Expect(configure.spec.inputs[2].repeatable, true)
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
        let callback = configuredDefault

        // act
        let metadata = callback.spec
        let explicit = callback.run(JianArgCursor(["--first=given"]))

        // assert
        @Expect(metadata.inputs[0].defaultShown.isSome(), true)
        @Expect(callbackDefaultCalls, 0)
        @Expect(explicit, 0)
        @Expect(callbackEvents, "private:given")
        @Expect(callback.run(JianArgCursor([])), 0)
        @Expect(callbackDefaultCalls, 1)
        @Expect(callbackEvents, "private:default")
    }

    @TestCase
    func nonzeroCallbackResultPreventsCommandDispatch() {
        // arrange
        callbackEvents = ""
        let app = JianApp(name: "demo").callback(callbackExit).add(launch)

        // act
        let code = app.run(["--code=9", "launch"])

        // assert
        @Expect(code, 9)
        @Expect(callbackEvents, "")
    }

    @TestCase
    func positionalCallbackArgumentsLeaveTheNextOperandForDispatch() {
        // arrange
        let args = JianArgCursor(["project", "--count=2", "launch", "--verbose"])

        // act
        let code = callbackPosition.run(args)

        // assert
        @Expect(code, 0)
        @Expect(callbackEvents, "project:2")
        @Expect(args.next(), Some(JianArg.Operand("launch")))
        @Expect(args.next(), Some(JianArg.Long("verbose")))
    }

    @TestCase
    func emptyCallbackLeavesCommandAndEndOfOptionsMarkerIntact() {
        // arrange
        let args = JianArgCursor(["--", "launch", "--verbose"])

        // act
        let code = `empty_callback`.run(args)

        // assert
        @Expect(code, 0)
        @Expect(callbackEvents, "empty")
        @Expect(args.remaining(), ["--", "launch", "--verbose"])
        @Expect(JianApp(name: "demo").callback(`empty_callback`).run([]), 0)
    }

    @TestCase
    func malformedCallbackOptionsReportTheSameTypedErrorsAsCommands() {
        // arrange
        let callback = callbackExit

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
