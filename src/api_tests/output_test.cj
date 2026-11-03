package jian.api_tests

import jian.*
import jian.api_tests.exported.exportedOutput
import std.io.ByteBuffer
import std.unittest.*
import std.unittest.testmacro.*

@JianCommand
func writeOutput(value: String, output!: JianOutput = JianCurrentOutput()): Int64 {
    output.stdout.write("command:${value};".toArray())
    output.stderr.write("diagnostic;".toArray())
    output.stdout.flush()
    output.stderr.flush()
    7
}

@JianCallback
func outputCallback(output!: JianOutput = JianCurrentOutput(), stop!: ?Int64 = None,
    invocation!: JianInvocation = JianCurrentInvocation()) {
    output.stdout.write("callback:${invocation.requestedSubcommand ?? "absent"};".toArray())
    if (let Some(code) <- stop) { return JianCallbackResult.Exit(code) }
    JianCallbackResult.Continue
}

@JianCommand
func contextualOutput(output!: JianOutput = JianCurrentOutput(),
    trace!: ContextTrace = JianFromContext<TestContext>()) {
    trace.events += "command;"
    output.stdout.write(trace.events.toArray())
}

@JianCallback
func contextualOutputCallback(trace!: ContextTrace = JianFromContext<TestContext>(),
    output!: JianOutput = JianCurrentOutput()) {
    trace.events += "callback;"
    output.stderr.write("context;".toArray())
    JianCallbackResult.Continue
}

@JianCommand
func outputFailure(output!: JianOutput = JianCurrentOutput()): Unit {
    output.stdout.write("before;".toArray())
    throw IllegalStateException("execution failure")
}

@JianCommand
func reenterOutput(output!: JianOutput = JianCurrentOutput()) {
    let inner = ByteBuffer()
    let innerErrors = ByteBuffer()
    let app = JianApp().command(writeOutput)
    let code = app.run(["inner"], stdout: inner, stderr: innerErrors)
    output.stdout.write("outer:${code}:${String.fromUtf8(inner.bytes())}".toArray())
    output.stderr.write("outer-error;".toArray())
}

@JianCommand
func outputBeforeVariadic(help!: JianOutput = JianCurrentOutput(),
    files!: Array<String> = JianArgument(default: []), output!: JianOutput = JianCurrentOutput(),
    count!: Int64 = files.size) {
    help.stdout.write("${count}:".toArray())
    output.stdout.write(String.join(files, delimiter: ",").toArray())
}

@Test
class OutputTest {
    @TestCase
    func namedAndRootCommandsUseDefaultAndOverriddenStreams() {
        // arrange
        let defaults = ByteBuffer()
        let defaultErrors = ByteBuffer()
        let override = ByteBuffer()
        let overrideErrors = ByteBuffer()
        let named = JianApp(stdout: defaults, stderr: defaultErrors).add(writeOutput)
        let root = JianApp(stdout: defaults, stderr: defaultErrors).command(writeOutput)
        // act
        let first = named.run(["write-output", "first"])
        let second = root.run(["second"], stdout: override, stderr: overrideErrors)
        let third = root.run(["third"])
        // assert
        @Expect(first, 7)
        @Expect(second, 7)
        @Expect(third, 7)
        @Expect(String.fromUtf8(defaults.bytes()), "command:first;command:third;")
        @Expect(String.fromUtf8(defaultErrors.bytes()), "diagnostic;diagnostic;")
        @Expect(String.fromUtf8(override.bytes()), "command:second;")
        @Expect(String.fromUtf8(overrideErrors.bytes()), "diagnostic;")
    }

    @TestCase
    func partialOverridesResolveEachStreamIndependently() {
        // arrange
        let defaults = ByteBuffer()
        let defaultErrors = ByteBuffer()
        let override = ByteBuffer()
        let overrideErrors = ByteBuffer()
        let app = JianApp(stdout: defaults, stderr: defaultErrors).command(writeOutput)
        // act
        let first = app.run(["one"], stdout: override)
        let second = app.run(["two"], stderr: overrideErrors)
        // assert
        @Expect(first, 7)
        @Expect(second, 7)
        @Expect(String.fromUtf8(defaults.bytes()), "command:two;")
        @Expect(String.fromUtf8(defaultErrors.bytes()), "diagnostic;")
        @Expect(String.fromUtf8(override.bytes()), "command:one;")
        @Expect(String.fromUtf8(overrideErrors.bytes()), "diagnostic;")
    }

    @TestCase
    func nestedCallbacksAndCommandsReceiveRootStreamsInsteadOfChildDefaults() {
        // arrange
        let childOutput = ByteBuffer()
        let childErrors = ByteBuffer()
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let child = JianApp(stdout: childOutput, stderr: childErrors)
            .callback(outputCallback).add(writeOutput)
        let app = JianApp().callback(outputCallback).add(child, name: "child")
        // act
        let code = app.run(["child", "write-output", "nested"], stdout: output, stderr: errors)
        // assert
        @Expect(code, 7)
        @Expect(String.fromUtf8(output.bytes()), "callback:child;callback:write-output;command:nested;")
        @Expect(String.fromUtf8(errors.bytes()), "diagnostic;")
        @Expect(childOutput.bytes().isEmpty(), true)
        @Expect(childErrors.bytes().isEmpty(), true)
    }

    @TestCase
    func mountedRootCommandAlsoReceivesRootStreams() {
        // arrange
        let stale = ByteBuffer()
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let child = JianApp(stdout: stale, stderr: stale).command(writeOutput)
        let app = JianApp().add(child, name: "child")
        // act
        let code = app.run(["child", "root"], stdout: output, stderr: errors)
        // assert
        @Expect(code, 7)
        @Expect(String.fromUtf8(output.bytes()), "command:root;")
        @Expect(String.fromUtf8(errors.bytes()), "diagnostic;")
        @Expect(stale.bytes().isEmpty(), true)
    }

    @TestCase[stop in [0, 9]]
    func callbackEarlyExitUsesInvocationOutputAndSkipsTheCommand(stop: Int64) {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let app = JianApp().callback(outputCallback).add(writeOutput)
        // act
        let code = app.run(["--stop=${stop}", "write-output", "unused"], stdout: output, stderr: errors)
        // assert
        @Expect(code, stop)
        @Expect(String.fromUtf8(output.bytes()), "callback:write-output;")
        @Expect(errors.bytes().isEmpty(), true)
    }

    @TestCase
    func callbackOnlyAppsUseDefaultsAndDoNotRetainOverrides() {
        // arrange
        let defaults = ByteBuffer()
        let override = ByteBuffer()
        let app = JianApp(stdout: defaults).callback(outputCallback)
        // act
        let first = app.run([], stdout: override)
        let second = app.run([])
        // assert
        @Expect(first, 0)
        @Expect(second, 0)
        @Expect(String.fromUtf8(defaults.bytes()), "callback:absent;")
        @Expect(String.fromUtf8(override.bytes()), "callback:absent;")
    }

    @TestCase
    func helpAndUsageErrorsShareTheHandlersEffectiveStreams() {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let app = JianApp(name: "demo").callback(outputCallback).add(writeOutput)
        // act
        let help = app.run(["write-output", "--help"], stdout: output, stderr: errors)
        let invalid = app.run(["write-output"], stdout: output, stderr: errors)
        let text = String.fromUtf8(output.bytes())
        // assert
        @Expect(help, 0)
        @Expect(invalid, 2)
        @Expect(text.startsWith("callback:write-output;Usage: demo write-output [OPTIONS] VALUE"), true)
        @Expect(text.endsWith("callback:write-output;"), true)
        @Expect(text.contains("--output"), false)
        @Expect(text.contains("JianOutput"), false)
        @Expect(String.fromUtf8(errors.bytes()).startsWith("Error: missing argument 'VALUE'"), true)
        @Expect(WriteOutputCommand().spec.inputs.size, 1)
        @Expect(OutputCallbackCallback().spec.inputs.size, 1)
    }

    @TestCase
    func injectionDoesNotConsumeVariadicOperandsOrReserveHelpNames() {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let app = JianApp().command(outputBeforeVariadic)
        // act
        let valid = app.run(["one", "two"], stdout: output, stderr: errors)
        let invalid = app.run(["--output=bad"], stdout: output, stderr: errors)
        // assert
        @Expect(valid, 0)
        @Expect(invalid, 2)
        @Expect(String.fromUtf8(output.bytes()), "2:one,two")
        @Expect(String.fromUtf8(errors.bytes()).contains("unknown option '--output'"), true)
        @Expect(OutputBeforeVariadicCommand().spec.inputs.size, 2)
    }

    @TestCase
    func typedContextAndOutputComposeInCallbacksRootAndNamedCommands() {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let context = TestContext(ContextTrace())
        let app = JianContextApp<TestContext>().callback(contextualOutputCallback).add(contextualOutput)
        let root = JianContextApp<TestContext>().command(contextualOutput)
        // act
        let named = app.run(["contextual-output"], context: context, stdout: output, stderr: errors)
        let directRoot = root.run([], context: context, stdout: output, stderr: errors)
        // assert
        @Expect(named, 0)
        @Expect(directRoot, 0)
        @Expect(String.fromUtf8(output.bytes()), "callback;command;callback;command;command;")
        @Expect(String.fromUtf8(errors.bytes()), "context;")
    }

    @TestCase
    func contextProjectionAndContextFreeChildrenKeepEffectiveOutput() {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let context = TestContext(ContextTrace())
        let typed = JianContextApp<TestContext>().callback(contextualOutputCallback).add(contextualOutput)
        let plain = JianApp().callback(outputCallback).add(writeOutput)
        let app = JianContextApp<InvocationParent>()
            .add(typed, name: "typed", context: { parent: InvocationParent => parent.child })
            .add(plain, name: "plain")
        // act
        let projected = app.run(["typed", "contextual-output"], context: InvocationParent(context),
            stdout: output, stderr: errors)
        let contextFree = app.run(["plain", "write-output", "child"], context: InvocationParent(context),
            stdout: output, stderr: errors)
        // assert
        @Expect(projected, 0)
        @Expect(contextFree, 7)
        @Expect(String.fromUtf8(output.bytes()), "callback;command;callback:write-output;command:child;")
        @Expect(String.fromUtf8(errors.bytes()), "context;diagnostic;")
    }

    @TestCase
    func directFunctionsAndExportedConsumersTakeExplicitTypedOutput() {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let streams = JianOutput(stdout: output, stderr: errors)
        // act
        let command = writeOutput("direct", output: streams)
        let callback = outputCallback(output: streams, invocation: JianInvocation(), stop: Some(0))
        exportedOutput(output: streams)
        let adapter = WriteOutputCommand().run(JianArgCursor(["adapter"]), streams)
        // assert
        @Expect(command, 7)
        @Expect(callback, JianCallbackResult.Exit(0))
        @Expect(adapter, 7)
        @Expect(String.fromUtf8(output.bytes()), "command:direct;callback:absent;exported;command:adapter;")
        @Expect(String.fromUtf8(errors.bytes()), "diagnostic;diagnostic;")
    }

    @TestCase
    func nestedInvocationCannotOverwriteOuterOutput() {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let app = JianApp().command(reenterOutput)
        // act
        let code = app.run([], stdout: output, stderr: errors)
        // assert
        @Expect(code, 0)
        @Expect(String.fromUtf8(output.bytes()), "outer:7:command:inner;")
        @Expect(String.fromUtf8(errors.bytes()), "outer-error;")
    }

    @TestCase
    func simultaneousRunsOfOneAppKeepTheirOwnStreams() {
        // arrange
        let firstOutput = ByteBuffer()
        let firstErrors = ByteBuffer()
        let secondOutput = ByteBuffer()
        let secondErrors = ByteBuffer()
        let app = JianApp().callback(outputCallback).add(writeOutput)
        // act
        let first = spawn { app.run(["write-output", "first"], stdout: firstOutput, stderr: firstErrors) }
        let second = spawn { app.run(["write-output", "second"], stdout: secondOutput, stderr: secondErrors) }
        let firstCode = first.get()
        let secondCode = second.get()
        // assert
        @Expect(firstCode, 7)
        @Expect(secondCode, 7)
        @Expect(String.fromUtf8(firstOutput.bytes()), "callback:write-output;command:first;")
        @Expect(String.fromUtf8(secondOutput.bytes()), "callback:write-output;command:second;")
        @Expect(String.fromUtf8(firstErrors.bytes()), "diagnostic;")
        @Expect(String.fromUtf8(secondErrors.bytes()), "diagnostic;")
    }

    @TestCase
    func executionFailuresPropagateAndCallerStreamsRemainWritable() {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let app = JianApp().command(outputFailure)
        // act
        let failure = @AssertThrows[IllegalStateException](app.run([], stdout: output, stderr: errors))
        output.write("after;".toArray())
        errors.write("caller;".toArray())
        // assert
        @Expect(failure.message, "execution failure")
        @Expect(String.fromUtf8(output.bytes()), "before;after;")
        @Expect(String.fromUtf8(errors.bytes()), "caller;")
    }
}
