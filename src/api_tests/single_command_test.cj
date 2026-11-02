package jian.api_tests

import jian.*
import std.io.ByteBuffer
import std.unittest.*
import std.unittest.testmacro.*

private var singleResult = ""

@JianCommand[help: "Process files directly."]
func singleFiles(paths!: Array<String> = JianArgument(help: "Input paths"),
    count!: Int64 = JianOption(short: 'n', default: 1),
    labels!: Array<String> = JianOption(short: 'l', default: []), optional!: ?Int64): Int64 {
    singleResult = "${paths}:${count}:${labels}:${optional}"
    7
}

@JianCommand
func singleOptional(value!: ?String): Unit { singleResult = value ?? "absent" }

@JianCommand
func singleFailure(): Int64 { throw IllegalStateException("action failed") }

@Test
class SingleCommandTest {
    @TestCase
    func rootParsesTypedInputsRepeatsAndTerminatorWithoutSelectingACommand() {
        // arrange
        let app = JianApp(name: "demo").command(singleFiles)
        // act
        let code = app.run(["help", "-n3", "-la", "--labels", "b", "--optional", "4", "--", "-h"])
        // assert
        @Expect(code, 7)
        @Expect(singleResult, "[help, -h]:3:[a, b]:Some(4)")
    }

    @TestCase
    func noInputInvokesAnOptionalActionAndDefaultsArePreserved() {
        // arrange
        let app = JianApp().command(singleOptional)
        // act
        let code = app.run([])
        // assert
        @Expect(code, 0)
        @Expect(singleResult, "absent")
        @Expect(JianApp().command(singleFiles).run(["file"]), 7)
        @Expect(singleResult, "[file]:1:[]:None")
        @Expect(singleFiles(paths: ["direct"]), 7)
        @Expect(singleResult, "[direct]:1:[]:None")
    }

    @TestCase[input in [[], ["file", "--count", "bad"], ["file", "--unknown"]]]
    func usageErrorsReferToTheExecutableAndUseStderr(input: Array<String>) {
        // arrange
        let errors = ByteBuffer()
        let output = ByteBuffer()
        let app = JianApp(name: "demo", stderr: errors, stdout: output).command(singleFiles)
        // act
        let code = app.run(input)
        // assert
        @Expect(code, 2)
        @Expect(output.bytes().isEmpty(), true)
        let message = String.fromUtf8(errors.bytes())
        @Expect(message.contains("Error:"), true)
        @Expect(message.contains("Usage: demo [OPTIONS] PATHS..."), true)
        @Expect(message.contains("COMMAND"), false)
    }

    @TestCase[input in [["--help"], ["-h"]]]
    func rootHelpIncludesBothDescriptionsAndSkipsTheAction(input: Array<String>) {
        // arrange
        singleResult = "untouched"
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let app = JianApp(name: "demo", help: "Application description.", stdout: output, stderr: errors)
            .command(SingleFilesCommand())
        // act
        let code = app.run(input)
        // assert
        @Expect(code, 0)
        @Expect(singleResult, "untouched")
        @Expect(errors.bytes().isEmpty(), true)
        let message = String.fromUtf8(output.bytes())
        @Expect(message.startsWith("Usage: demo [OPTIONS] PATHS...\n"), true)
        @Expect(message.contains("Application description."), true)
        @Expect(message.contains("Process files directly."), true)
        @Expect(message.contains("--count"), true)
        @Expect(message.contains("COMMAND"), false)
        @Expect(message.contains("Commands:"), false)
    }

    @TestCase
    func unrelatedExceptionsPropagate() {
        // arrange
        let errors = ByteBuffer()
        let app = JianApp(stderr: errors).command(singleFailure)
        // act
        let error = @AssertThrows[IllegalStateException](app.run([]))
        // assert
        @Expect(error.message, "action failed")
        @Expect(errors.bytes().isEmpty(), true)
    }

    @TestCase
    func rootAndGroupConfigurationRejectEachOtherBeforeMutation() {
        // arrange
        let root = JianApp().command(singleOptional)
        let group = JianApp().add(singleOptional)
        let callback = JianApp().callback(integrationArguments)
        let mounted = JianApp().add(JianApp(), name: "child")
        // act / assert
        @AssertThrows[IllegalArgumentException](root.add(singleFiles))
        @AssertThrows[IllegalArgumentException](root.command(singleFiles))
        @AssertThrows[IllegalArgumentException](root.callback(integrationArguments))
        @AssertThrows[IllegalArgumentException](root.add(JianApp(), name: "child"))
        @AssertThrows[IllegalArgumentException](group.command(singleFiles))
        @AssertThrows[IllegalArgumentException](callback.command(singleFiles))
        @AssertThrows[IllegalArgumentException](mounted.command(singleFiles))
        @Expect(root.run([]), 0)
        @Expect(group.run(["single-optional"]), 0)
        @Expect(callback.run([]), 0)
    }

    @TestCase
    func typedAndContextFreeFactoriesAndAdaptersAcceptPerRunContext() {
        // arrange
        let trace = ContextTrace()
        let context = TestContext(trace)
        let typed = JianContextApp<TestContext>().command(recordContext)
        let adapter = JianContextApp<TestContext>().command(RecordContextCommand())
        let plain = JianContextApp<TestContext>().command(singleOptional)
        let plainAdapter = JianContextApp<TestContext>().command(SingleOptionalCommand())
        // act / assert
        @Expect(typed.run(["first"], context: context), 7)
        @Expect(adapter.run(["second"], context: context), 7)
        @Expect(trace.events, "first:false:-1;second:false:-1;")
        @Expect(plain.run([], context: context), 0)
        @Expect(plainAdapter.run([], context: context), 0)
        @AssertThrows[IllegalArgumentException](typed.add(recordContext))
        @AssertThrows[IllegalArgumentException](typed.callback(configureContext))
        @AssertThrows[IllegalArgumentException](typed.add(JianApp(), name: "child"))
    }

    @TestCase[input in [["files", "--help"], ["help", "files"]]]
    func mountedRootActionUsesTheMountPathAndRootStreams(input: Array<String>) {
        // arrange
        singleResult = "untouched"
        let output = ByteBuffer()
        let child = JianApp().command(singleFiles)
        let app = JianApp(name: "demo", stdout: output).add(child, name: "files", help: "Mounted action.")
        // act
        let code = app.run(input)
        // assert
        @Expect(code, 0)
        @Expect(singleResult, "untouched")
        let message = String.fromUtf8(output.bytes())
        @Expect(message.startsWith("Usage: demo files [OPTIONS] PATHS...\n"), true)
        @Expect(message.contains("Mounted action."), true)
        @Expect(app.run(["files", "help"]), 7)
        @Expect(singleResult, "[help]:1:[]:None")
    }

    @TestCase
    func helpTargetsCannotSelectCommandsWithinASoleAction() {
        // arrange
        singleResult = "untouched"
        let errors = ByteBuffer()
        let output = ByteBuffer()
        let child = JianApp().command(singleFiles)
        let app = JianApp(name: "demo", stderr: errors, stdout: output).add(child, name: "files")
        // act
        let code = app.run(["help", "files", "extra"])
        // assert
        @Expect(code, 2)
        @Expect(singleResult, "untouched")
        @Expect(output.bytes().isEmpty(), true)
        @Expect(String.fromUtf8(errors.bytes()).contains("unknown command 'extra'"), true)
    }

}
