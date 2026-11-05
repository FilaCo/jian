package jian.api_tests

import jian.*
import jian.api_tests.exported.exportedOutput
import std.io.{ByteBuffer, OutputStream}
import std.unittest.*
import std.unittest.testmacro.*

@JianCommand
func writeOutput(text: String, output!: JianOutput = JianCurrentOutput()): Int64 {
    output.stdout.write("command:${text};".toArray())
    output.stderr.write("command-error:${text};".toArray())
    7
}

@JianCallback
func configureOutput(output!: JianOutput = JianCurrentOutput(),
    invocation!: JianInvocation = JianCurrentInvocation(), stop!: Bool = false) {
    output.stdout.write("callback:${invocation.requestedSubcommand ?? "absent"};".toArray())
    output.stderr.write("callback-error;".toArray())
    if (stop) { JianCallbackResult.Exit(0) } else { JianCallbackResult.Continue }
}

@JianCommand
func contextOutput(output!: JianOutput = JianCurrentOutput(),
    trace!: ContextTrace = JianFromContext<TestContext>()) {
    trace.events += "command;"
    output.stdout.write("context-command;".toArray())
}

@JianCallback
func contextOutputCallback(trace!: ContextTrace = JianFromContext<TestContext>(),
    output!: JianOutput = JianCurrentOutput()) {
    trace.events += "callback;"
    output.stdout.write("context-callback;".toArray())
    JianCallbackResult.Continue
}

@JianCommand
func failingOutput(output!: JianOutput = JianCurrentOutput()): Unit {
    output.stdout.write("before-failure;".toArray())
    throw IllegalStateException("application failure")
}

@JianCallback
func failingOutputCallback(output!: JianOutput = JianCurrentOutput()): JianCallbackResult {
    output.stdout.write("before-callback-failure;".toArray())
    throw IllegalStateException("callback failure")
}

@JianCommand
func outputFiles(files: Array<String>, help!: JianOutput = JianCurrentOutput(),
    count!: Int64 = files.size) {
    help.stdout.write("${count}:${String.join(files, delimiter: ",")};".toArray())
}

class OutputReentry {
    public OutputReentry(public let nested: () -> Unit) {}
}

@JianContext
class OutputReentryContext {
    public OutputReentryContext(public let action: OutputReentry) {}
}

@JianCommand
func reentrantOutput(output!: JianOutput = JianCurrentOutput(),
    state!: OutputReentry = JianFromContext<OutputReentryContext>()) {
    output.stdout.write("before;".toArray())
    state.nested()
    output.stdout.write("after;".toArray())
}

class TrackedOutput <: OutputStream {
    let buffer = ByteBuffer()
    public var closes: Int64 = 0
    public prop isClosed: Bool { get() { closes > 0 } }
    public func close(): Unit { closes++ }
    public func flush(): Unit {}
    public func write(bytes: Array<Byte>): Unit { buffer.write(bytes) }
}

@Test
class OutputTest {
    @TestCase
    func rootCommandsUseDefaultsAndIndependentOverridesWithoutRetainingThem() {
        // arrange
        let defaults = ByteBuffer()
        let defaultErrors = ByteBuffer()
        let first = ByteBuffer()
        let second = ByteBuffer()
        let app = JianApp(stdout: defaults, stderr: defaultErrors).command(writeOutput)

        // act
        let initial = app.run(["default"])
        let overrideOut = app.run(["first"], stdout: first)
        let overrideErr = app.run(["second"], stderr: second)
        let again = app.run(["again"])

        // assert
        @Expect([initial, overrideOut, overrideErr, again], [7, 7, 7, 7])
        @Expect(String.fromUtf8(defaults.bytes()), "command:default;command:second;command:again;")
        @Expect(String.fromUtf8(defaultErrors.bytes()), "command-error:default;command-error:first;command-error:again;")
        @Expect(String.fromUtf8(first.bytes()), "command:first;")
        @Expect(String.fromUtf8(second.bytes()), "command-error:second;")
    }

    @TestCase
    func namedCommandCallbackHelpAndUsageSharePerRunStreams() {
        // arrange
        let defaults = ByteBuffer()
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let app = JianApp(name: "demo", stdout: defaults, stderr: defaults)
            .callback(configureOutput).add(writeOutput)

        // act
        let command = app.run(["write-output", "hello"], stdout: output, stderr: errors)
        let help = app.run(["--help"], stdout: output, stderr: errors)
        let usage = app.run(["write-output"], stdout: output, stderr: errors)
        let text = String.fromUtf8(output.bytes())
        let diagnostics = String.fromUtf8(errors.bytes())

        // assert
        @Expect(command, 7)
        @Expect(help, 0)
        @Expect(usage, 2)
        @Expect(text.startsWith("callback:write-output;command:hello;Usage: demo"), true)
        @Expect(text.endsWith("callback:write-output;"), true)
        @Expect(diagnostics.startsWith("callback-error;command-error:hello;callback-error;Error:"), true)
        @Expect(diagnostics.contains("missing argument 'TEXT'"), true)
        @Expect(defaults.bytes().isEmpty(), true)
    }

    @TestCase
    func nestedHandlersUseRootDefaultsAndOverridesInsteadOfChildDefaults() {
        // arrange
        let defaults = ByteBuffer()
        let errors = ByteBuffer()
        let childDefaults = ByteBuffer()
        let overrideOut = ByteBuffer()
        let overrideErr = ByteBuffer()
        let leaf = JianApp(stdout: childDefaults, stderr: childDefaults).command(writeOutput)
        let child = JianApp(stdout: childDefaults, stderr: childDefaults)
            .callback(configureOutput).add(leaf, name: "leaf").add(writeOutput)
        let app = JianApp(stdout: defaults, stderr: errors).callback(configureOutput).add(child, name: "child")

        // act
        let named = app.run(["child", "write-output", "default"])
        let root = app.run(["child", "leaf", "override"], stdout: overrideOut, stderr: overrideErr)
        let help = app.run(["help", "child", "leaf"], stdout: overrideOut, stderr: overrideErr)

        // assert
        @Expect(named, 7)
        @Expect(root, 7)
        @Expect(help, 0)
        @Expect(String.fromUtf8(defaults.bytes()), "callback:child;callback:write-output;command:default;")
        @Expect(String.fromUtf8(errors.bytes()), "callback-error;callback-error;command-error:default;")
        @Expect(String.fromUtf8(overrideOut.bytes()).startsWith("callback:child;callback:leaf;command:override;callback:child;callback:leaf;Usage:"), true)
        @Expect(String.fromUtf8(overrideErr.bytes()), "callback-error;callback-error;command-error:override;callback-error;callback-error;")
        @Expect(childDefaults.bytes().isEmpty(), true)
    }

    @TestCase
    func earlyExitSkipsCommandsAndDoesNotLeakStreamsIntoLaterRuns() {
        // arrange
        let defaults = ByteBuffer()
        let first = ByteBuffer()
        let app = JianApp(stdout: defaults, stderr: defaults).callback(configureOutput).add(writeOutput)

        // act
        let stopped = app.run(["--stop", "write-output"], stdout: first, stderr: first)
        let continued = app.run(["write-output", "later"])
        let callbackOnly = JianApp().callback(configureOutput).run(["--stop"], stdout: first, stderr: first)

        // assert
        @Expect(stopped, 0)
        @Expect(continued, 7)
        @Expect(callbackOnly, 0)
        @Expect(String.fromUtf8(first.bytes()), "callback:write-output;callback-error;callback:absent;callback-error;")
        @Expect(String.fromUtf8(defaults.bytes()), "callback:write-output;callback-error;command:later;command-error:later;")
    }

    @TestCase
    func injectedOutputCreatesNoInputsAndRejectsCliValues() {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let command = JianApp(stdout: output, stderr: errors).command(outputFiles)
        let callback = JianApp(stdout: output, stderr: errors).callback(configureOutput)

        // act
        let valid = command.run(["a", "b"])
        let invalidCommand = command.run(["--help=somewhere"])
        let invalidCallback = callback.run(["--output=somewhere"])
        let help = command.run(["--help"])

        // assert
        @Expect(valid, 0)
        @Expect(invalidCommand, 2)
        @Expect(invalidCallback, 2)
        @Expect(help, 0)
        @Expect(WriteOutputCommand().spec.inputs.size, 1)
        @Expect(ConfigureOutputCallback().spec.inputs.size, 1)
        @Expect(OutputFilesCommand().spec.inputs.size, 2)
        @Expect(String.fromUtf8(output.bytes()).startsWith("2:a,b;Usage:"), true)
        @Expect(String.fromUtf8(output.bytes()).contains("--output"), false)
        @Expect(String.fromUtf8(errors.bytes()).contains("unknown option '--output'"), true)
    }

    @TestCase
    func contextInjectionAndContextFreeChildrenShareInvocationOutput() {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let stale = ByteBuffer()
        let trace = ContextTrace()
        let parent = InvocationParent(TestContext(trace))
        let child = JianContextApp<TestContext>(stdout: stale, stderr: stale)
            .callback(contextOutputCallback).add(contextOutput)
            .add(JianApp(stdout: stale, stderr: stale).command(writeOutput), name: "plain")
        let app = JianContextApp<InvocationParent>(stdout: stale, stderr: stale).add(child, name: "child")

        // act
        let contextual = app.run(["child", "context-output"], context: parent, stdout: output, stderr: errors)
        let plain = app.run(["child", "plain", "hello"], context: parent, stdout: output, stderr: errors)
        let root = JianContextApp<TestContext>().command(contextOutput)
            .run([], context: parent.child, stdout: output, stderr: errors)
        let plainOnContext = JianContextApp<TestContext>().callback(configureOutput).add(writeOutput)
            .run(["write-output", "context"], context: parent.child, stdout: output, stderr: errors)

        // assert
        @Expect(contextual, 0)
        @Expect(plain, 7)
        @Expect(root, 0)
        @Expect(plainOnContext, 7)
        @Expect(trace.events, "callback;command;callback;command;")
        @Expect(String.fromUtf8(output.bytes()),
            "context-callback;context-command;context-callback;command:hello;context-command;callback:write-output;command:context;")
        @Expect(stale.bytes().isEmpty(), true)
    }

    @TestCase
    func directAndImportedCallsRequireAndAcceptTypedOutput() {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let streams = JianOutput(stdout: output, stderr: errors)
        let action: (String, JianOutput) -> Int64 = writeOutput

        // act
        let direct = action("direct", streams)
        let callback = configureOutput(output: streams, invocation: JianInvocation(), stop: true)
        exportedOutput(output: streams)
        let imported = JianApp().command(exportedOutput).run([], stdout: output, stderr: errors)
        let adapter = WriteOutputCommand().run(JianArgCursor(["adapter"]), output: streams)

        // assert
        @Expect(direct, 7)
        @Expect(callback, JianCallbackResult.Exit(0))
        @Expect(imported, 0)
        @Expect(adapter, 7)
        @Expect(String.fromUtf8(output.bytes()), "command:direct;callback:absent;exported;exported;command:adapter;")
    }

    @TestCase
    func reentrantInvocationsKeepTheirOwnStreams() {
        // arrange
        let outer = ByteBuffer()
        let inner = ByteBuffer()
        let errors = ByteBuffer()
        let app = JianContextApp<OutputReentryContext>().command(reentrantOutput)
        let innerState = OutputReentry({ => () })
        let outerState = OutputReentry({ =>
            let code = app.run([], context: OutputReentryContext(innerState), stdout: inner, stderr: errors)
            if (code != 0) { throw IllegalStateException("inner invocation failed") }
        })

        // act
        let code = app.run([], context: OutputReentryContext(outerState), stdout: outer, stderr: errors)

        // assert
        @Expect(code, 0)
        @Expect(String.fromUtf8(outer.bytes()), "before;after;")
        @Expect(String.fromUtf8(inner.bytes()), "before;after;")
        @Expect(errors.bytes().isEmpty(), true)
    }

    @TestCase
    func simultaneousInvocationsKeepStreamsSeparate() {
        // arrange
        let first = ByteBuffer()
        let second = ByteBuffer()
        let firstErrors = ByteBuffer()
        let secondErrors = ByteBuffer()
        let app = JianApp().command(writeOutput)

        // act
        let one = spawn { app.run(["one"], stdout: first, stderr: firstErrors) }
        let two = spawn { app.run(["two"], stdout: second, stderr: secondErrors) }
        let codes = [one.get(), two.get()]

        // assert
        @Expect(codes, [7, 7])
        @Expect(String.fromUtf8(first.bytes()), "command:one;")
        @Expect(String.fromUtf8(second.bytes()), "command:two;")
        @Expect(String.fromUtf8(firstErrors.bytes()), "command-error:one;")
        @Expect(String.fromUtf8(secondErrors.bytes()), "command-error:two;")
    }

    @TestCase
    func dispatchNeverClosesBorrowedStreamsOnAnyCompletionPath() {
        // arrange
        let output = TrackedOutput()
        let errors = TrackedOutput()
        let app = JianApp(stdout: output, stderr: errors).command(writeOutput)
        let callback = JianApp().callback(configureOutput)

        // act
        let command = app.run(["success"])
        let help = app.run(["--help"])
        let usage = app.run([])
        let exit = callback.run(["--stop"], stdout: output, stderr: errors)
        let failure = @AssertThrows[IllegalStateException](JianApp().command(failingOutput)
            .run([], stdout: output, stderr: errors))

        // assert
        @Expect([command, help, usage, exit], [7, 0, 2, 0])
        @Expect(failure.message, "application failure")
        @Expect(output.closes, 0)
        @Expect(errors.closes, 0)
    }

    @TestCase
    func applicationFailuresPropagateAndCallerStreamsStayWritable() {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let app = JianApp().command(failingOutput)
        let callback = JianApp().callback(failingOutputCallback)

        // act
        let failure = @AssertThrows[IllegalStateException](app.run([], stdout: output, stderr: errors))
        let callbackFailure = @AssertThrows[IllegalStateException](callback.run([], stdout: output, stderr: errors))
        output.write("still-open;".toArray())
        errors.write("caller-policy;".toArray())

        // assert
        @Expect(failure.message, "application failure")
        @Expect(callbackFailure.message, "callback failure")
        @Expect(String.fromUtf8(output.bytes()), "before-failure;before-callback-failure;still-open;")
        @Expect(String.fromUtf8(errors.bytes()), "caller-policy;")
    }
}
